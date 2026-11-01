// Two-level ray traversal. gNodes is addressed in float4 blocks.
//
// The TLAS (tinybvh BVH_GPU, Aila & Laine: 4 blocks per node, child bounds in the parent) starts at gFrame.envInfo.z
// and is built over instance world bounds; its leaves reference instances through gIndices[tlasPrimOffset + i].
// Each instance points at a BLAS (gNodes + blasNodeOffset), a tinybvh BVH8_CWBVH ("Efficient Incoherent Ray Traversal
// on GPUs Through Compressed Wide BVHs", Ylitie et al. 2017: 5 blocks per node, 8 child boxes quantized to 8 bits),
// whose leaves reference triangles in gTris as (v0 | asfloat(primIdx), e1, e2).
// Rays are transformed into object space without renormalizing, so t is shared by both levels.
import Common.Math;
import Scene.SceneTypes;
import Scene.SceneBindings;
import Scene.SceneAccess;
import Materials.AlphaTest;

static const uint INVALID_INDEX = 0xFFFFFFFFu;
static const uint BVH_LEAF_BIT = 0x80000000u;
// TLAS node references and CWBVH node groups (at most one per BLAS level). A module-scope stack: WGSL zero-initializes
// array variables where they are declared, so a function-scope one would be cleared for every ray.
static const uint TRAVERSAL_STACK_SIZE = 32u;
static uint2 gTraversalStack[TRAVERSAL_STACK_SIZE];

struct Ray
{
	float3 origin;
	float tMin;
	float3 direction;
	float tMax;

	__init(float3 o, float3 d, float tmax = FLT_LARGE)
	{
		origin = o;
		direction = d;
		tMin = 0.0;
		tMax = tmax;
	}
};

struct HitRecord
{
	float t;
	float2 barycentrics; // weights of v1 and v2
	uint instanceIndex;
	uint primitiveIndex;

	bool IsHit()
	{
		return instanceIndex != INVALID_INDEX;
	}
};

// Node visits + triangle tests of the current invocation; feeds the traversal heat map.
static uint gTraversalCost = 0u;

float3 SafeRcp(float3 d)
{
	float3 s = select(d < 0.0, float3(-1e-20), float3(1e-20));
	return rcp(select(abs(d) < 1e-20, s, d));
}

// Entry distance of a child box, or FLT_LARGE on a miss.
float IntersectBox(float3 bmin, float3 bmax, float3 o, float3 rD, float tMin, float tMax)
{
	float3 t1 = (bmin - o) * rD;
	float3 t2 = (bmax - o) * rD;
	float3 tn = min(t1, t2);
	float3 tf = max(t1, t2);
	float tNear = max(max(tn.x, tn.y), max(tn.z, tMin));
	float tFar = min(min(tf.x, tf.y), min(tf.z, tMax));
	return tNear <= tFar ? tNear : FLT_LARGE;
}

// Moller-Trumbore on tinybvh's (v0, e1, e2) representation.
bool IntersectTriangle(float3 o, float3 d, float3 v0, float3 e1, float3 e2, float tMin, float tMax, out float t, out float2 bary)
{
	t = 0.0;
	bary = float2(0.0);
	float3 h = cross(d, e2);
	float a = dot(e1, h);
	if (a == 0.0)
	{
		return false;
	}
	float f = rcp(a);
	float3 s = o - v0;
	float u = f * dot(s, h);
	if (u < 0.0 || u > 1.0)
	{
		return false;
	}
	float3 q = cross(s, e1);
	float v = f * dot(d, q);
	if (v < 0.0 || u + v > 1.0)
	{
		return false;
	}
	t = f * dot(e2, q);
	bary = float2(u, v);
	return t > tMin && t < tMax;
}

// The sign of every byte, spread over the byte (prmt.b32 with 0xBA98 in Ylitie et al.'s CUDA).
uint SignExtendS8x4(uint i)
{
	return ((i >> 7u) & 0x01010101u) * 0xFFu;
}

// Hits of four children of a CWBVH node as bits of the node group's hit mask (tinybvh traverse_cwbvh). meta4: their
// meta bytes; lo, hi: the quantized near and far planes per axis, already swapped for the ray's direction signs.
uint CwbvhChildHits(uint meta4, uint3 lo, uint3 hi, float3 scale, float3 origin, float tMin, float tMax, uint octinv)
{
	uint isInner4 = (meta4 & (meta4 << 1u)) & 0x10101010u;
	uint innerMask4 = SignExtendS8x4(isInner4 << 3u);
	uint bitIndex4 = (meta4 ^ (octinv & innerMask4)) & 0x1F1F1F1Fu;
	uint childBits4 = (meta4 >> 5u) & 0x07070707u;
	uint hitmask = 0u;
	[unroll]
	for (uint i = 0u; i < 4u; i++)
	{
		uint shift = i * 8u;
		float3 tNear = float3((lo >> shift) & 0xFFu) * scale + origin;
		float3 tFar = float3((hi >> shift) & 0xFFu) * scale + origin;
		float cmin = max(max(max(tNear.x, tNear.y), tNear.z), tMin);
		float cmax = min(min(min(tFar.x, tFar.y), tFar.z), tMax);
		if (cmin <= cmax) hitmask |= ((childBits4 >> shift) & 0xFFu) << ((bitIndex4 >> shift) & 0xFFu);
	}
	return hitmask;
}

// One BLAS triangle slot: Moller-Trumbore, then the alpha test; true when it becomes the hit. Only the alpha test
// reads the whole instance, so traversal keeps just its BLAS offsets live. Triangles of a merged BLAS
// (INSTANCE_FLAG_MERGED) carry their instance in e1.w and their alpha test flag in e2.w.
bool IntersectSlot<let ALPHA : bool>(uint slot, uint instanceIndex, uint blasTriOffset, bool merged, bool alphaTested, float3 o, float3 d, float tMin, inout HitRecord hit)
{
	gTraversalCost++;
	uint base = (blasTriOffset + slot) * 3u;
	float4 v0 = gTris[base], e1 = gTris[base + 1u], e2 = gTris[base + 2u];
	float t;
	float2 bary;
	if (!IntersectTriangle(o, d, v0.xyz, e1.xyz, e2.xyz, tMin, hit.t, t, bary)) return false;
	uint primitiveIndex = asuint(v0.w);
	if (merged)
	{
		instanceIndex = asuint(e1.w);
		alphaTested = ALPHA && asuint(e2.w) != 0u;
	}
	if (ALPHA && alphaTested && AlphaTestRejects(gInstances[instanceIndex], primitiveIndex, bary, t)) return false;
	hit.t = t;
	hit.barycentrics = bary;
	hit.instanceIndex = instanceIndex;
	hit.primitiveIndex = primitiveIndex;
	return true;
}

// Closest hit (anyHit = false) or first accepted hit (anyHit = true). TLAS and BLAS steps share one loop and one
// stack, so lanes of a warp entering different numbers of instances keep stepping instead of waiting for each
// other's BLAS walks. BLAS steps follow Ylitie et al. as in tinybvh's traverse_cwbvh kernel: a node group (x: first
// child node, y: hit bits 24..31 by octant-ordered slot, plus the node's imask in bits 0..7) or a triangle group (x:
// first triangle slot in float4 units of tinybvh's compressed layout, y: hit bits 0..23) per step; partly processed
// node groups go on the stack. TLAS entries on the stack have y = 0: popping one leaves the BLAS.
// TRIANGLE_STEPS tests one triangle per loop iteration instead of a triangle group in an inner loop: faster in the
// register-bound megakernel, slower in the wavefront kernels.
bool TraceScene<let ALPHA : bool, let TRIANGLE_STEPS : bool = false>(Ray ray, bool anyHit, inout HitRecord hit)
{
	hit.t = ray.tMax;
	hit.barycentrics = float2(0.0);
	hit.instanceIndex = INVALID_INDEX;
	hit.primitiveIndex = INVALID_INDEX;
	if (gFrame.counts.x == 0u)
	{
		return false;
	}

	uint tlasPrimOffset = gFrame.counts.z;
	float3 worldRD = SafeRcp(ray.direction);
	uint stackPtr = 0u;
	uint nodeRef = 0u; // TLAS
	bool found = false;
	// The BLAS being walked, in object space.
	bool inBlas = false;
	uint instanceIndex = 0u, blasNodeOffset = 0u, blasTriOffset = 0u;
	bool alphaTested = false, merged = false;
	float3 o = ray.origin, d = ray.direction, rD = worldRD;
	uint octinv = 0u;
	uint2 nodeGroup = uint2(0u), triGroup = uint2(0u);

	while (true)
	{
		bool pop = false;
		if (TRIANGLE_STEPS && inBlas && triGroup.y != 0u)
		{
			uint triangleBit = firstbithigh(triGroup.y);
			triGroup.y &= ~(1u << triangleBit);
			if (IntersectSlot<ALPHA>((triGroup.x >> 2u) + triangleBit, instanceIndex, blasTriOffset, merged, alphaTested, o, d, ray.tMin, hit))
			{
				found = true;
				if (anyHit) return true;
			}
			pop = triGroup.y == 0u && nodeGroup.y <= 0x00FFFFFFu;
		}
		else if (inBlas)
		{
			if (nodeGroup.y > 0x00FFFFFFu)
			{
				uint hits = nodeGroup.y;
				uint childBit = firstbithigh(hits);
				nodeGroup.y &= ~(1u << childBit);
				if (nodeGroup.y > 0x00FFFFFFu && stackPtr < TRAVERSAL_STACK_SIZE) gTraversalStack[stackPtr++] = nodeGroup;
				uint slot = (childBit - 24u) ^ (octinv & 0xFFu);
				uint relative = countbits(hits & ~(0xFFFFFFFFu << slot));
				uint node = blasNodeOffset + (nodeGroup.x + relative) * 5u;
				gTraversalCost++;
				float4 n0 = gNodes[node], n1 = gNodes[node + 1u], n2 = gNodes[node + 2u], n3 = gNodes[node + 3u], n4 = gNodes[node + 4u];
				// n0: node origin, w: three 127-biased quantization exponents and the imask.
				uint e4 = asuint(n0.w);
				float3 scale = float3(asfloat((e4 & 0xFFu) << 23u), asfloat(((e4 >> 8u) & 0xFFu) << 23u), asfloat(((e4 >> 16u) & 0xFFu) << 23u)) * rD;
				float3 origin = (n0.xyz - o) * rD;
				bool3 negative = rD < 0.0;
				uint3 lo0 = uint3(asuint(negative.x ? n3.z : n2.x), asuint(negative.y ? n4.x : n2.z), asuint(negative.z ? n4.z : n3.x));
				uint3 hi0 = uint3(asuint(negative.x ? n2.x : n3.z), asuint(negative.y ? n2.z : n4.x), asuint(negative.z ? n3.x : n4.z));
				uint3 lo1 = uint3(asuint(negative.x ? n3.w : n2.y), asuint(negative.y ? n4.y : n2.w), asuint(negative.z ? n4.w : n3.y));
				uint3 hi1 = uint3(asuint(negative.x ? n2.y : n3.w), asuint(negative.y ? n2.w : n4.y), asuint(negative.z ? n3.y : n4.w));
				uint hitmask = CwbvhChildHits(asuint(n1.z), lo0, hi0, scale, origin, ray.tMin, hit.t, octinv)
					| CwbvhChildHits(asuint(n1.w), lo1, hi1, scale, origin, ray.tMin, hit.t, octinv);
				nodeGroup = uint2(asuint(n1.x), (hitmask & 0xFF000000u) | (e4 >> 24u));
				triGroup = uint2(asuint(n1.y), hitmask & 0x00FFFFFFu);
			}
			else
			{
				triGroup = nodeGroup;
				nodeGroup = uint2(0u);
			}
			while (!TRIANGLE_STEPS && triGroup.y != 0u)
			{
				uint triangleBit = firstbithigh(triGroup.y);
				triGroup.y &= ~(1u << triangleBit);
				if (IntersectSlot<ALPHA>((triGroup.x >> 2u) + triangleBit, instanceIndex, blasTriOffset, merged, alphaTested, o, d, ray.tMin, hit))
				{
					found = true;
					if (anyHit) return true;
				}
			}
			pop = triGroup.y == 0u && nodeGroup.y <= 0x00FFFFFFu;
		}
		else if ((nodeRef & BVH_LEAF_BIT) != 0u)
		{
			// TLAS leaf: walk its first instance; the rest of the leaf goes on the stack as a smaller leaf.
			uint count = (nodeRef >> 24u) & 127u;
			uint first = nodeRef & 0xFFFFFFu;
			if (count == 0u) pop = true;
			else
			{
				if (count > 1u && stackPtr < TRAVERSAL_STACK_SIZE) gTraversalStack[stackPtr++] = uint2(BVH_LEAF_BIT | ((count - 1u) << 24u) | (first + 1u), 0u);
				instanceIndex = gIndices[tlasPrimOffset + first];
				Instance inst = gInstances[instanceIndex];
				blasNodeOffset = inst.blasNodeOffset;
				blasTriOffset = inst.blasTriOffset;
				o = InverseTransformPoint(inst, ray.origin);
				d = InverseTransformVector(inst, ray.direction);
				rD = SafeRcp(d);
				alphaTested = ALPHA && (inst.flags & INSTANCE_FLAG_ALPHA_TESTED) != 0u;
				merged = (inst.flags & INSTANCE_FLAG_MERGED) != 0u;
				octinv = (7u - ((d.x < 0.0 ? 4u : 0u) | (d.y < 0.0 ? 2u : 0u) | (d.z < 0.0 ? 1u : 0u))) * 0x01010101u;
				nodeGroup = uint2(0u, 0x80000000u); // the root, as the only child of a virtual parent
				inBlas = true;
			}
		}
		else
		{
			gTraversalCost++;
			uint node = gFrame.envInfo.z + nodeRef * 4u;
			float4 left = gNodes[node], leftMax = gNodes[node + 1u];
			float dist1 = IntersectBox(left.xyz, leftMax.xyz, ray.origin, worldRD, ray.tMin, hit.t);
			float dist2 = IntersectBox(gNodes[node + 2u].xyz, gNodes[node + 3u].xyz, ray.origin, worldRD, ray.tMin, hit.t);
			uint near = asuint(left.w);
			uint far = asuint(leftMax.w);
			if (dist1 > dist2)
			{
				float td = dist1;
				dist1 = dist2;
				dist2 = td;
				uint ti = near;
				near = far;
				far = ti;
			}
			if (dist1 == FLT_LARGE) pop = true;
			else
			{
				nodeRef = near;
				if (dist2 != FLT_LARGE && stackPtr < TRAVERSAL_STACK_SIZE) gTraversalStack[stackPtr++] = uint2(far, 0u);
			}
		}
		if (pop)
		{
			if (stackPtr == 0u) break;
			uint2 entry = gTraversalStack[--stackPtr];
			if (entry.y == 0u)
			{
				nodeRef = entry.x;
				inBlas = false;
			}
			else nodeGroup = entry;
		}
	}
	return found;
}

HitRecord TraceClosest<let ALPHA : bool = true, let TRIANGLE_STEPS : bool = false>(Ray ray)
{
	HitRecord hit;
	TraceScene<ALPHA, TRIANGLE_STEPS>(ray, false, hit);
	return hit;
}

bool TraceOcclusion<let ALPHA : bool = true, let TRIANGLE_STEPS : bool = false>(Ray ray)
{
	HitRecord hit;
	return TraceScene<ALPHA, TRIANGLE_STEPS>(ray, true, hit);
}
