// Two-level ray traversal over tinybvh BVH_GPU (Aila & Laine) trees.
//
// gNodes[0..] holds the TLAS, built over instance world bounds; its leaves reference instances
// through gIndices[tlasPrimOffset + i]. Each instance points at a BLAS (gNodes + blasNodeOffset)
// whose leaves reference BVH-ordered triangles in gTris as (v0 | asfloat(primIdx), e1, e2).
// Rays are transformed into object space without renormalizing, so t is shared by both levels.
import Common.Math;
import Scene.SceneTypes;
import Scene.SceneBindings;
import Scene.SceneAccess;
import Materials.AlphaTest;

static const uint INVALID_INDEX = 0xFFFFFFFFu;
static const uint BVH_LEAF_BIT = 0x80000000u;
static const uint TLAS_STACK_SIZE = 32u;
static const uint BLAS_STACK_SIZE = 48u;

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

// Batch shadow candidates in the reference BVH encounter order. A continuation replays
// traversal and skips already shaded candidates, preserving stochastic alpha/VT state.
static const uint SHADOW_BATCH_SIZE = 4u;
static HitRecord gShadowBatch[SHADOW_BATCH_SIZE] = {};
static uint gShadowBatchCount = 0u;
static uint gShadowBatchSkip = 0u;
static bool gShadowBatchComplete = false;

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

// Closest hit (anyHit = false) or first accepted hit (anyHit = true) within one BLAS.
bool TraverseBLAS<let ALPHA : bool, let COLLECT : bool = false, let SKIP : bool = false>(uint instanceIndex, Instance inst, float3 o, float3 d, float tMin, bool anyHit, inout HitRecord hit)
{
	float3 rD = SafeRcp(d);
	bool alphaTested = ALPHA && (inst.flags & INSTANCE_FLAG_ALPHA_TESTED) != 0u;
	uint stack[BLAS_STACK_SIZE];
	uint stackPtr = 0u;
	uint nodeRef = 0u;
	bool found = false;

	while (true)
	{
		if ((nodeRef & BVH_LEAF_BIT) != 0u)
		{
			uint count = (nodeRef >> 24u) & 127u;
			uint first = nodeRef & 0xFFFFFFu;
			for (uint i = 0u; i < count; i++)
			{
				gTraversalCost++;
				uint base = (inst.blasTriOffset + first + i) * 3u;
				float4 v0 = gTris[base];
				float t;
				float2 bary;
				if (!IntersectTriangle(o, d, v0.xyz, gTris[base + 1u].xyz, gTris[base + 2u].xyz, tMin, hit.t, t, bary))
				{
					continue;
				}
				uint primitiveIndex = asuint(v0.w);
				if ((COLLECT || SKIP) && gShadowBatchSkip > 0u)
				{
					gShadowBatchSkip--;
					continue;
				}
				if (COLLECT)
				{
					HitRecord candidate;
					candidate.t = t;
					candidate.barycentrics = bary;
					candidate.instanceIndex = instanceIndex;
					candidate.primitiveIndex = primitiveIndex;
					gShadowBatch[gShadowBatchCount++] = candidate;
					gShadowBatchComplete = (inst.flags & INSTANCE_FLAG_ALPHA_TESTED) == 0u;
					if (gShadowBatchComplete || gShadowBatchCount == SHADOW_BATCH_SIZE) return true;
					continue;
				}
				if (alphaTested && AlphaTestRejects(inst, primitiveIndex, bary, t))
				{
					continue;
				}
				hit.t = t;
				hit.barycentrics = bary;
				hit.instanceIndex = instanceIndex;
				hit.primitiveIndex = primitiveIndex;
				found = true;
				if (anyHit)
				{
					return true;
				}
			}
			if (stackPtr == 0u)
			{
				break;
			}
			nodeRef = stack[--stackPtr];
			continue;
		}

		gTraversalCost++;
		BVHNode node = gNodes[inst.blasNodeOffset + nodeRef];
		float dist1 = IntersectBox(node.lmin, node.lmax, o, rD, tMin, hit.t);
		float dist2 = IntersectBox(node.rmin, node.rmax, o, rD, tMin, hit.t);
		uint near = node.left;
		uint far = node.right;
		if (dist1 > dist2)
		{
			float td = dist1;
			dist1 = dist2;
			dist2 = td;
			uint ti = near;
			near = far;
			far = ti;
		}
		if (dist1 == FLT_LARGE)
		{
			if (stackPtr == 0u)
			{
				break;
			}
			nodeRef = stack[--stackPtr];
		}
		else
		{
			nodeRef = near;
			if (dist2 != FLT_LARGE && stackPtr < BLAS_STACK_SIZE)
			{
				stack[stackPtr++] = far;
			}
		}
	}
	return found;
}

bool TraceScene<let ALPHA : bool, let COLLECT : bool = false, let SKIP : bool = false>(Ray ray, bool anyHit, inout HitRecord hit)
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
	float3 rD = SafeRcp(ray.direction);
	uint stack[TLAS_STACK_SIZE];
	uint stackPtr = 0u;
	uint nodeRef = 0u;
	bool found = false;

	while (true)
	{
		if ((nodeRef & BVH_LEAF_BIT) != 0u)
		{
			uint count = (nodeRef >> 24u) & 127u;
			uint first = nodeRef & 0xFFFFFFu;
			for (uint i = 0u; i < count; i++)
			{
				uint instanceIndex = gIndices[tlasPrimOffset + first + i];
				Instance inst = gInstances[instanceIndex];
				float3 o = InverseTransformPoint(inst, ray.origin);
				float3 d = InverseTransformVector(inst, ray.direction);
				if (TraverseBLAS<ALPHA, COLLECT, SKIP>(instanceIndex, inst, o, d, ray.tMin, anyHit, hit))
				{
					found = true;
					if (anyHit)
					{
						return true;
					}
				}
			}
			if (stackPtr == 0u)
			{
				break;
			}
			nodeRef = stack[--stackPtr];
			continue;
		}

		gTraversalCost++;
		BVHNode node = gNodes[nodeRef];
		float dist1 = IntersectBox(node.lmin, node.lmax, ray.origin, rD, ray.tMin, hit.t);
		float dist2 = IntersectBox(node.rmin, node.rmax, ray.origin, rD, ray.tMin, hit.t);
		uint near = node.left;
		uint far = node.right;
		if (dist1 > dist2)
		{
			float td = dist1;
			dist1 = dist2;
			dist2 = td;
			uint ti = near;
			near = far;
			far = ti;
		}
		if (dist1 == FLT_LARGE)
		{
			if (stackPtr == 0u)
			{
				break;
			}
			nodeRef = stack[--stackPtr];
		}
		else
		{
			nodeRef = near;
			if (dist2 != FLT_LARGE && stackPtr < TLAS_STACK_SIZE)
			{
				stack[stackPtr++] = far;
			}
		}
	}
	return found;
}

HitRecord TraceClosest<let ALPHA : bool = true>(Ray ray)
{
	HitRecord hit;
	TraceScene<ALPHA>(ray, false, hit);
	return hit;
}

bool TraceOcclusion<let ALPHA : bool = true>(Ray ray)
{
	HitRecord hit;
	return TraceScene<ALPHA>(ray, true, hit);
}

void TraceShadowBatch(Ray ray, uint skipped)
{
	gShadowBatchCount = 0u;
	gShadowBatchSkip = skipped;
	gShadowBatchComplete = false;
	HitRecord hit;
	if (!TraceScene<false, true>(ray, true, hit)) gShadowBatchComplete = true;
}

bool TraceOcclusionResume(Ray ray, uint skipped)
{
	gShadowBatchSkip = skipped;
	HitRecord hit;
	return TraceScene<true, false, true>(ray, true, hit);
}
