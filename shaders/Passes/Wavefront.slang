// Staged reference implementation. Work records share the accumulation binding (eight
// storage buffers total). Bounded tiles keep scratch memory independent of image size.
// The megakernel's helpers define the camera, ray offsets, BSDF and sampling conventions.
import Passes.PathTracing;
import Common.Math;
import Common.Random;
import Scene.SceneTypes;
import Scene.SceneBindings;
import Scene.SceneAccess;
import RayTracing.Traversal;
import Materials.AlphaTest;
import Materials.MaterialSample;
import Materials.MaterialProgram;
import Materials.BSDF.BSDF;
import Materials.VirtualTexture;
import Lights.Lights;
import Passes.Sharc;
import Passes.SharcCommon;

struct WavefrontUniforms
{
	uint tileStart;
	uint pathCount;
	uint bounce;
	uint capacity;
	uint tailThreshold;
	uint packetStages;
	uint sortGroupSize;
};
[[vk::binding(2, 1)]] ConstantBuffer<WavefrontUniforms> gWavefront;
[[vk::binding(3, 1)]] Texture2D<uint2> gPrimaryVisibility;

// float4 field arrays (SoA): path 0..7, hit 8..9, shadow metadata 10..11,
// three shadows 12..20. Every field has gWavefront.capacity entries.
static const uint WAVEFRONT_STRIDE = 21u;

struct WavefrontPath
{
	PathState path;
	uint active;
	uint randomSeed;
	float3 albedo;
	float3 normal;
};

uint WorkBase(uint index)
{
	return gFrame.frame.x * gFrame.frame.y * 3u + 3u + index;
}

uint Field(uint base, uint field) { return base + field * gWavefront.capacity; }

uint HeaderBase() { return gFrame.frame.x * gFrame.frame.y * 3u; }
uint MainQueueBase() { return HeaderBase() + 3u + gWavefront.capacity * WAVEFRONT_STRIDE; }
uint ShadeQueueBase() { return MainQueueBase() + (gWavefront.capacity + 3u) / 4u; }
uint ShadowQueueBase() { return MainQueueBase() + 2u * ((gWavefront.capacity + 3u) / 4u); }
uint BucketMetadataBase() { return ShadowQueueBase() + (gWavefront.capacity + 3u) / 4u; }
// Extra SoA records follow the existing queues and 262 metadata records.
uint LightWorkBase(uint index) { return BucketMetadataBase() + 262u + index; }
uint QueueIndex(uint base, uint index) { return asuint(gAccum[base + index / 4u][index & 3u]); }

uint2 WorkPixel(uint index)
{
	// Match the megakernel's 8x8 spatial grouping before paths diverge/compact.
	uint work = gWavefront.tileStart + index;
	uint block = work / 64u, lane = work & 63u;
	uint blocksX = (gFrame.frame.x + 7u) / 8u;
	return uint2((block % blocksX) * 8u + (lane & 7u), (block / blocksX) * 8u + lane / 8u);
}

// NRD split (Nrd.md), active when gFrame.envInfo.w (float4 offset of NRD_STRIDE float4 per pixel) is nonzero.
// During tracing: (bypass radiance, packed indirect diffuse fraction), (primary direct diffuse, first
// bounce hit distance), (primary direct specular, packed roughness/metalness or -1 without a surface),
// (luminance-weighted direct diffuse directions, primary sample direction octahedral x),
// (luminance-weighted direct specular directions, octahedral y).
// Finalize rewrites them pre-exposed as (diffuse, hit distance), (specular, roughness/metalness),
// (bypass, surface), (mean diffuse direction, 0), (mean specular direction, 0). A mean direction
// shorter than one encodes angular spread for REBLUR's SH mode.
static const uint NRD_STRIDE = 5u;
static const float NRD_MISS_DISTANCE = 65504.0;
bool NrdEnabled() { return gFrame.envInfo.w != 0u; }
uint NrdBase(uint base)
{
	uint2 pixel = WorkPixel(base - WorkBase(0u));
	return gFrame.envInfo.w + (pixel.y * gFrame.frame.x + pixel.x) * NRD_STRIDE;
}
float2 NrdOctEncode(float3 v)
{
	float2 p = v.xy / (abs(v.x) + abs(v.y) + abs(v.z));
	return v.z >= 0.0 ? p : (1.0 - abs(p.yx)) * select(p >= 0.0, float2(1.0), float2(-1.0));
}
float3 NrdOctDecode(float2 p)
{
	float3 v = float3(p, 1.0 - abs(p.x) - abs(p.y));
	if (v.z < 0.0) v.xy = (1.0 - abs(v.yx)) * select(v.xy >= 0.0, float2(1.0), float2(-1.0));
	return normalize(v);
}
// Roughness in [0, 1] plus metalness quantized to 8 bits in the integer part (even numbers).
float NrdPackSurface(float roughness, float metalness) { return saturate(roughness) * 0.99 + 2.0 * round(saturate(metalness) * 255.0); }
// Three 9-bit diffuse fractions; shadow flags keep the low three bits.
uint NrdPackFraction(float3 f)
{
	uint3 q = uint3(round(saturate(f) * 511.0));
	return q.x | (q.y << 9u) | (q.z << 18u);
}
float3 NrdUnpackFraction(uint v) { return float3(float(v & 511u), float((v >> 9u) & 511u), float((v >> 18u) & 511u)) / 511.0; }
float3 NrdDiffuseFraction(DiffuseSpecular v)
{
	float3 total = v.diffuse + v.specular;
	return float3(total.x > 0.0 ? v.diffuse.x / total.x : 0.5, total.y > 0.0 ? v.diffuse.y / total.y : 0.5, total.z > 0.0 ? v.diffuse.z / total.z : 0.5);
}
// Shadow flags: bit 0 tests visibility, bit 1 marks a primary NRD vertex, bit 2 bypasses NRD
// (sun: a single sample is nearly noise-free and REBLUR would soften its shadows), bits 3.. hold the diffuse fraction.
uint ShadowFlags(bool shadow, bool primary, bool bypass, DiffuseSpecular eval)
{
	return uint(shadow) | (primary && NrdEnabled() ? 2u | (bypass ? 4u : 0u) | (NrdPackFraction(NrdDiffuseFraction(eval)) << 3u) : 0u);
}
// Per source split of visible primary direct light (unclamped): (diffuse, specular, bypass).
void NrdSplitDirect(uint flags, float3 contribution, out float3 diffuse, out float3 specular, out float3 bypass)
{
	bool skip = (flags & 4u) != 0u;
	diffuse = skip ? float3(0.0) : contribution * NrdUnpackFraction(flags >> 3u);
	specular = skip ? float3(0.0) : contribution - diffuse;
	bypass = skip ? contribution : float3(0.0);
}
void NrdAddDirect(uint base, uint flags, float3 contribution, float3 direction)
{
	if ((flags & 2u) == 0u) return;
	float3 diffuse, specular, bypass;
	NrdSplitDirect(flags, contribution, diffuse, specular, bypass);
	uint r = NrdBase(base);
	gAccum[r].xyz += bypass;
	gAccum[r + 1u].xyz += diffuse;
	gAccum[r + 2u].xyz += specular;
	gAccum[r + 3u].xyz += Luminance(diffuse) * direction;
	gAccum[r + 4u].xyz += Luminance(specular) * direction;
}

void StoreFeedbackState(uint base)
{
	gAccum[Field(base, 7u)] = asfloat(uint4(gVTRequest, gVTRequestCount, gVTRandom, 0u));
}

void LoadFeedbackState(uint base)
{
	uint4 state = asuint(gAccum[Field(base, 7u)]);
	gVTRequest = state.x;
	gVTRequestCount = state.y;
	gVTRandom = state.z;
}

WavefrontPath LoadPath<let AOV : bool = true>(uint base)
{
	WavefrontPath s;
	float4 a = gAccum[base], b = gAccum[Field(base, 1u)], c = gAccum[Field(base, 2u)];
	float4 d = gAccum[Field(base, 3u)], e = gAccum[Field(base, 4u)], f = gAccum[Field(base, 5u)];
	s.path.radiance = a.xyz; s.active = asuint(a.w);
	s.path.throughput = b.xyz; s.randomSeed = asuint(b.w);
	s.path.origin = c.xyz; s.path.scatterPdf = c.w;
	s.path.direction = d.xyz; s.path.lightsSampled = asuint(d.w) != 0u;
	s.path.absorption = e.xyz; s.path.coneWidth = e.w;
	s.albedo = AOV ? f.xyz : float3(0.0); s.path.coneSpread = f.w;
	s.normal = AOV ? gAccum[Field(base, 6u)].xyz : float3(0.0);
	s.path.lobe = 0u; // last-lobe identity is already encoded in cone spread / NEE state
	return s;
}

// Material evaluation needs only the incoming direction and texture footprint.
WavefrontPath LoadShadingPath(uint base)
{
	WavefrontPath s = {};
	s.active = asuint(gAccum[base].w);
	s.path.direction = gAccum[Field(base, 3u)].xyz;
	s.path.coneWidth = gAccum[Field(base, 4u)].w;
	s.path.coneSpread = gAccum[Field(base, 5u)].w;
	return s;
}

void StorePath<let AOV : bool = true>(uint base, WavefrontPath s)
{
	gAccum[base] = float4(s.path.radiance, asfloat(s.active));
	gAccum[Field(base, 1u)] = float4(s.path.throughput, asfloat(s.randomSeed));
	gAccum[Field(base, 2u)] = float4(s.path.origin, s.path.scatterPdf);
	gAccum[Field(base, 3u)] = float4(s.path.direction, asfloat(uint(s.path.lightsSampled)));
	gAccum[Field(base, 4u)] = float4(s.path.absorption, s.path.coneWidth);
	if (AOV)
	{
		gAccum[Field(base, 5u)] = float4(s.albedo, s.path.coneSpread);
		gAccum[Field(base, 6u)] = float4(s.normal, gAccum[Field(base, 6u)].w);
	}
	else gAccum[Field(base, 5u)].w = s.path.coneSpread;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void Initialize(uint3 tid : SV_DispatchThreadID)
{
	uint index = tid.x;
	if (index >= gWavefront.pathCount) return;
	uint2 pixel = WorkPixel(index);
	RandomSequence rng = RandomSequence(pixel, gFrame.frame.w);
	Ray ray = GenerateCameraRay(pixel, rng);
	WavefrontPath s;
	s.path.radiance = float3(0.0);
	s.path.throughput = float3(1.0);
	s.path.origin = ray.origin;
	s.path.direction = ray.direction;
	s.path.scatterPdf = 1.0;
	s.path.lobe = 0u;
	s.path.coneWidth = 0.0;
	s.path.coneSpread = gFrame.vtParams.y;
	s.path.absorption = float3(0.0);
	s.path.lightsSampled = false;
	s.active = uint(all(pixel < gFrame.frame.xy));
	if (gFrame.temporal.z != 0.0 && s.active != 0u)
	{
		uint output = (pixel.y * gFrame.frame.x + pixel.x) * 3u;
		gAccum[output + 1u].w = 0.0; gAccum[output + 2u].w = 0.0;
	}
	if (NrdEnabled() && s.active != 0u)
	{
		uint r = gFrame.envInfo.w + (pixel.y * gFrame.frame.x + pixel.x) * NRD_STRIDE;
		gAccum[r] = float4(0.0); gAccum[r + 1u] = float4(0.0); gAccum[r + 2u] = float4(0.0, 0.0, 0.0, -1.0);
		gAccum[r + 3u] = float4(0.0); gAccum[r + 4u] = float4(0.0);
	}
	s.randomSeed = rng.seed;
	s.albedo = float3(0.0);
	s.normal = float3(0.0);
	uint base = WorkBase(index);
	StorePath(base, s);
	gAccum[Field(base, 6u)].w = asfloat(SharcEnabled() && s.active != 0u ? 1u | (SharcUpdatePath(index, gWavefront.tileStart) ? 512u : 0u) : 0u);
	gAccum[Field(base, 11u)] = float4(0.0);
	if ((index & 3u) == 0u) gAccum[MainQueueBase() + index / 4u] = asfloat(uint4(index, index + 1u, index + 2u, index + 3u));
	if (index == 0u)
	{
		uint sortGroups = gWavefront.sortGroupSize == 256u ? (gWavefront.pathCount + 255u) / 256u : 0u;
		gAccum[HeaderBase()] = asfloat(uint4(gWavefront.pathCount, 0u, 0u, sortGroups));
		gAccum[HeaderBase() + 1u] = asfloat(uint4((gWavefront.pathCount + 63u) / 64u, 1u, 1u, 0u));
		gAccum[HeaderBase() + 2u] = asfloat(uint4(0u, 1u, 1u, 0u));
	}
	InitVirtualTextureFeedback(pixel);
	StoreFeedbackState(base);
}

HitRecord CompleteIntersection(inout WavefrontPath s, uint bounce, HitRecord hit)
{
	Ray ray = Ray(s.path.origin, s.path.direction);
	float clampValue = gFrame.envParams.w / gFrame.envParams.z;
	if (AnalyticLightCount() > 0u)
	{
		float3 radiance; float pdf;
		if (IntersectAnalyticLights(ray.origin, ray.direction, hit.IsHit() ? hit.t : FLT_LARGE, bounce == 0u, radiance, pdf))
		{
			float mis = bounce > 0u && s.path.lightsSampled ? EvalMISRobust(s.path.scatterPdf, pdf) : 1.0;
			float3 contribution = s.path.throughput * mis * radiance;
			if (clampValue > 0.0 && bounce > 0u) contribution = min(contribution, float3(clampValue));
			s.path.radiance += contribution;
		}
	}
	if (!hit.IsHit())
	{
		if (bounce == 0u)
		{
			bool visible = (gFrame.settings.z & FRAME_FLAG_ENV_VISIBLE) != 0u;
			s.path.radiance += visible ? EvalEnvironment(ray.direction) : gFrame.background.rgb;
			if (visible && HitsSun(ray.direction)) s.path.radiance += gFrame.sunRadiance.rgb;
		}
		else
		{
			float mis = s.path.lightsSampled ? EvalMISRobust(s.path.scatterPdf, EnvironmentPdf(ray.direction)) : 1.0;
			float3 contribution = s.path.throughput * mis * EvalEnvironment(ray.direction);
			if (!s.path.lightsSampled && SunEnabled() && HitsSun(ray.direction)) contribution += s.path.throughput * gFrame.sunRadiance.rgb;
			if (clampValue > 0.0) contribution = min(contribution, float3(clampValue));
			s.path.radiance += contribution;
		}
		s.active = 0u;
	}
	return hit;
}

HitRecord IntersectPath<let ALPHA : bool>(inout WavefrontPath s, uint bounce)
{
	gRayCone = float2(s.path.coneWidth, s.path.coneSpread);
	return CompleteIntersection(s, bounce, TraceClosest<ALPHA>(Ray(s.path.origin, s.path.direction)));
}

void StorePrimaryHit(uint base, inout WavefrontPath s, HitRecord hit)
{
	hit = CompleteIntersection(s, 0u, hit);
	gAccum[Field(base, 8u)] = float4(hit.t, hit.barycentrics, asfloat(hit.instanceIndex));
	gAccum[Field(base, 9u)] = asfloat(uint4(hit.primitiveIndex, 0u, 0u, 0u));
	gAccum[base] = float4(s.path.radiance, asfloat(s.active));
}

[shader("compute")]
[numthreads(64, 1, 1)]
void ResolvePrimaryVisibility(uint3 tid : SV_DispatchThreadID)
{
	if (tid.x >= gWavefront.pathCount) return;
	uint base = WorkBase(tid.x);
	gAccum[Field(base, 9u)] = float4(0.0);
	WavefrontPath s = LoadPath(base);
	if (s.active == 0u) return;
	uint2 ids = gPrimaryVisibility.Load(int3(WorkPixel(tid.x), 0));
	uint pending = asuint(gAccum[gFrame.primaryVisibility.x / 4u].y) != 0u ? 3u : 0u;
	HitRecord hit;
	hit.t = FLT_LARGE; hit.barycentrics = float2(0.0);
	hit.instanceIndex = INVALID_INDEX; hit.primitiveIndex = INVALID_INDEX;
	if (pending == 0u && ids.x == INVALID_INDEX && ids.y != INVALID_INDEX) pending = 2u;
	if (pending == 0u && ids.x != INVALID_INDEX)
	{
		if (ids.x >= gFrame.primaryVisibility.w) pending = 2u;
		else
		{
			Instance inst = gInstances[ids.x];
			if (ids.y >= inst.triCount) pending = 2u;
			else if ((inst.flags & INSTANCE_FLAG_ALPHA_TESTED) != 0u) pending = 1u;
			else
			{
				uint3 tri = LoadTriangleIndices(inst, ids.y);
				float3 p = gVertices[tri.x].positionU.xyz;
				float3 e1 = gVertices[tri.y].positionU.xyz - p, e2 = gVertices[tri.z].positionU.xyz - p;
				bool valid = IntersectTriangle(InverseTransformPoint(inst, s.path.origin), InverseTransformVector(inst, s.path.direction),
					p, e1, e2, 0.0, FLT_LARGE, hit.t, hit.barycentrics);
				if (!valid || !isfinite(hit.t) || !all(isfinite(hit.barycentrics))) pending = 2u;
				else { hit.instanceIndex = ids.x; hit.primitiveIndex = ids.y; }
			}
		}
	}
	if (pending != 0u) gAccum[Field(base, 9u)] = asfloat(uint4(0u, pending, 0u, 0u));
	else StorePrimaryHit(base, s, hit);
}

void PrimaryTraceFallbackImpl<let ALPHA : bool>(uint3 tid)
{
	if (tid.x >= asuint(gAccum[HeaderBase()].y)) return;
	uint index = QueueIndex(ShadeQueueBase(), tid.x), base = WorkBase(index);
	WavefrontPath s = LoadPath(base);
	if (ALPHA) LoadFeedbackState(base);
	gRayCone = float2(s.path.coneWidth, s.path.coneSpread);
	HitRecord hit = TraceClosest<ALPHA>(Ray(s.path.origin, s.path.direction));
	StorePrimaryHit(base, s, hit);
	if (ALPHA) StoreFeedbackState(base);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void PrimaryTraceFallback(uint3 tid : SV_DispatchThreadID) { PrimaryTraceFallbackImpl<true>(tid); }
[shader("compute")]
[numthreads(64, 1, 1)]
void PrimaryTraceFallbackOpaque(uint3 tid : SV_DispatchThreadID) { PrimaryTraceFallbackImpl<false>(tid); }

// Tiny fallback queues need work on more SMs, not a single divergent 64-ray group.
[shader("compute")]
[numthreads(1, 1, 1)]
void PrimaryTraceFallbackSparse(uint3 tid : SV_DispatchThreadID) { PrimaryTraceFallbackImpl<true>(tid); }
[shader("compute")]
[numthreads(1, 1, 1)]
void PrimaryTraceFallbackSparseOpaque(uint3 tid : SV_DispatchThreadID) { PrimaryTraceFallbackImpl<false>(tid); }

void IntersectImpl<let ALPHA : bool, let DIRECT : bool>(uint3 tid)
{
	uint count = DIRECT ? gWavefront.pathCount : asuint(gAccum[HeaderBase()].x);
	if (tid.x >= count) return;
	uint index = DIRECT ? tid.x : QueueIndex(MainQueueBase(), tid.x);
	uint base = WorkBase(index);
	WavefrontPath s = LoadPath(base);
	if (s.active == 0u) return;
	if (ALPHA) LoadFeedbackState(base);
	HitRecord hit = IntersectPath<ALPHA>(s, gWavefront.bounce);
	// NRD hit distance: the first segment after the primary surface only.
	if (gWavefront.bounce == 1u && NrdEnabled()) gAccum[NrdBase(base) + 1u].w = hit.IsHit() ? hit.t : NRD_MISS_DISTANCE;
	if (hit.IsHit())
	{
		gAccum[Field(base, 8u)] = float4(hit.t, hit.barycentrics, asfloat(hit.instanceIndex));
		gAccum[Field(base, 9u)] = asfloat(uint4(hit.primitiveIndex, 0u, 0u, 0u));
	}
	// Intersection only changes radiance and liveness. Do not keep every other field
	// live across traversal just to write it back unchanged.
	gAccum[base] = float4(s.path.radiance, asfloat(s.active));
	if (ALPHA) StoreFeedbackState(base);
}

void QueueDirectLighting<let SEPARATE_LIGHT : bool>(uint base, SurfaceInteraction si, BSDF bsdf, float2 cone, float3 throughput, bool primary, inout RandomSequence rng)
{
	uint mask = 0u;
	gRayCone = cone;
	[loop]
	for (uint source = 0u; source < 3u; ++source)
	{
		LightSample ls;
		float3 origin; float3 dir;
		float maxDistance = FLT_LARGE;
		bool shadow = true, mis = true;
		bool pendingLight = false;
		if (source == 0u)
		{
			if (!EnvironmentEnabled()) continue;
			ls = SampleEnvironment(rng);
			if (!(any(ls.radiance > 0.0) && ls.solidAnglePdf > 0.0)) continue;
			dir = -ls.normal;
			origin = ShadowOrigin(si, dir);
		}
		else if (source == 1u)
		{
			if (LightCount() == 0u) continue;
			if (SEPARATE_LIGHT)
			{
				uint lightIndex; float3 bary;
				ls = SampleEmissiveGeometry(si.position, rng, lightIndex, bary);
				EmissiveTriangle light = gLights[lightIndex];
				pendingLight = (AnalyticFlags(light) & LIGHT_ANALYTIC) == 0u &&
					((LoadMaterialHeader(asuint(light.n.w)).flags >> 26u) & 31u) != 0u;
				if (pendingLight)
				{
					uint lightBase = LightWorkBase(base - WorkBase(0u));
					gAccum[lightBase] = float4(bary, asfloat(lightIndex));
					gAccum[Field(lightBase, 1u)] = float4(si.position, ls.solidAnglePdf);
					// Keep the evaluation even if BSDF/PDF later rejects the sample:
					// its VT feedback and random stream are part of the reference state.
					mask |= 8u;
				}
			}
			else ls = SampleEmissive(si.position, cone, rng);
			if (!(any(ls.radiance > 0.0) && ls.solidAnglePdf > 0.0)) continue;
			float3 lightPos = ComputeOffsetOrigin(ls.position, ls.normal);
			origin = ShadowOrigin(si, lightPos - si.position);
			dir = lightPos - origin;
			maxDistance = length(dir);
			dir /= maxDistance;
			shadow = ls.shadow;
			mis = !ls.delta;
		}
		else
		{
			if (!SunEnabled()) continue;
			ls = SampleSun(rng);
			dir = -ls.normal;
			origin = ShadowOrigin(si, dir);
			mis = false;
		}
		DiffuseSpecular eval; float pdf;
		bsdf.EvalPdf(dir, eval, pdf);
		float3 f = eval.diffuse + eval.specular;
		if (any(f > 0.0))
		{
			float weight = mis ? EvalMISRobust(ls.solidAnglePdf, pdf) : 1.0;
			uint offset = 12u + source * 3u;
			gAccum[Field(base, offset)] = float4(origin, maxDistance);
			gAccum[Field(base, offset + 1u)] = float4(dir, asfloat(ShadowFlags(shadow, primary, source == 2u, eval)));
			gAccum[Field(base, offset + 2u)] = pendingLight ? float4(f, weight)
				: float4(weight * ls.radiance * f / ls.solidAnglePdf, 0.0);
			mask |= 1u << source;
		}
	}
	// Clamp the sum of direct contributions, matching the megakernel exactly.
	gAccum[Field(base, 10u)] = float4(throughput, primary ? 0.0 : gFrame.envParams.w / gFrame.envParams.z);
	gAccum[Field(base, 11u)] = float4(cone, asfloat(mask), 0.0);
}

// PHASE: dynamic 0, primary 1, continuation 2. Tail retains the dynamic reference.
void ShadePath<let DEFERRED : bool, let ALPHA : bool, let PHASE : uint = 0u, let LATE_PATH : bool = false, let SEPARATE_LIGHT : bool = false>(uint base, inout WavefrontPath s, HitRecord hit, uint bounce)
{
	if (!LATE_PATH && any(s.path.absorption > 0.0)) s.path.throughput *= exp(s.path.absorption * -hit.t);
	float hitConeWidth = s.path.coneWidth + s.path.coneSpread * hit.t;
	SurfaceInteraction si = GetSurfaceInteraction(s.path.direction, hit, hitConeWidth);
	float3 V = -s.path.direction;
	MaterialSample ms = EvalMaterial(si, V);
	if (LATE_PATH)
	{
		// EvalMaterial does not mutate path storage; no other lane owns this path.
		s = LoadPath<PHASE != 2u>(base);
		if (any(s.path.absorption > 0.0)) s.path.throughput *= exp(s.path.absorption * -hit.t);
	}
	BSDF bsdf = BSDF(ms.inputs, V, s.path.throughput, BSDF_RGB_WAVELENGTHS, 1.0);
	bool primary = PHASE == 1u || (PHASE == 0u && bounce == 0u);
	if (primary)
	{
		s.albedo = ms.albedo;
		s.normal = si.frontFacing ? ms.inputs.basis.n : -ms.inputs.basis.n;
		if (gFrame.temporal.z != 0.0)
		{
			uint2 pixel = WorkPixel(base - WorkBase(0u));
			uint output = (pixel.y * gFrame.frame.x + pixel.x) * 3u;
			gAccum[output + 1u].w = hit.t; gAccum[output + 2u].w = float(hit.instanceIndex + 1u);
		}
		if (NrdEnabled())
		{
			uint r = NrdBase(base);
			gAccum[r] = float4(s.path.radiance, asfloat(NrdPackFraction(float3(0.5))));
			gAccum[r + 1u] = float4(0.0);
			gAccum[r + 2u] = float4(0.0, 0.0, 0.0, NrdPackSurface(ms.roughness, ms.inputs.baseMetalness));
		}
	}
	s.active = 0u;
	if (!si.frontFacing && !ms.doubleSided && ms.inputs.transmissionWeight <= 0.0) return;
	if (any(bsdf.emission > 0.0))
	{
		float mis = 1.0;
		if (!primary && s.path.lightsSampled)
		{
			Instance inst = gInstances[si.instanceIndex];
			float pdf = EmissiveHitPdf(inst, si.primitiveIndex, s.path.origin, si.position);
			mis = EvalMISRobust(s.path.scatterPdf, pdf);
		}
		float3 contribution = s.path.throughput * mis * bsdf.emission;
		float clampValue = gFrame.envParams.w / gFrame.envParams.z;
		if (clampValue > 0.0 && !primary) contribution = min(contribution, float3(clampValue));
		s.path.radiance += contribution;
	}
	if (primary && NrdEnabled()) gAccum[NrdBase(base)].xyz = s.path.radiance;
	if (bounce == gFrame.settings.x) return;
	if (SharcEnabled() && !primary && SharcSurface(ms))
	{
		SharcKey key; float voxelSize;
		float3 normal = si.frontFacing ? si.faceNormal : -si.faceNormal;
		uint index = base - WorkBase(0u);
		if (SharcMakeKey(si.position, normal, V, si.materialIndex, si.instanceIndex, key, voxelSize))
		{
			if (SharcUpdatePath(index, gWavefront.tileStart)) SharcRecord(index, bounce, key, s.path.radiance, s.path.throughput);
			else if (hit.t > voxelSize * sqrt(3.0) && hitConeWidth > voxelSize && s.path.coneSpread >= 0.05)
			{
				uint state = asuint(gAccum[Field(base, 6u)].w) + 65536u;
				float3 cached;
				bool found = SharcQuery(key, cached);
				gAccum[Field(base, 6u)].w = asfloat(state | (found ? 256u : 0u));
				if (found) { s.path.radiance += s.path.throughput * cached; return; }
			}
		}
	}
	RandomSequence rng = RandomSequence(0u, 0u);
	rng.seed = s.randomSeed;
	s.path.lightsSampled = bsdf.MaxActiveAlpha() >= NEAR_SPECULAR_ALPHA;
	if (s.path.lightsSampled)
	{
		if (DEFERRED)
		{
			QueueDirectLighting<SEPARATE_LIGHT>(base, si, bsdf, float2(hitConeWidth, s.path.coneSpread), s.path.throughput, primary, rng);
		}
		else
		{
			float3 direct = s.path.throughput * NextEventEstimation<ALPHA>(si, bsdf, float2(hitConeWidth, s.path.coneSpread), rng);
			float clampValue = gFrame.envParams.w / gFrame.envParams.z;
			if (clampValue > 0.0 && !primary) direct = min(direct, float3(clampValue));
			s.path.radiance += direct;
		}
	}
	float2 u = rng.Next2D();
	LobeSample bs = bsdf.Sample(float3(u, rng.Next()));
	float3 weight = bs.weight.diffuse + bs.weight.specular;
	if (!bs.valid || bs.pdf <= 0.0 || all(weight <= 0.0)) return;
	if (primary && NrdEnabled())
	{
		uint r = NrdBase(base);
		float2 oct = NrdOctEncode(bs.wi);
		gAccum[r].w = asfloat(NrdPackFraction(NrdDiffuseFraction(bs.weight)));
		gAccum[r + 3u].w = oct.x; gAccum[r + 4u].w = oct.y;
	}
	float3 throughput = s.path.throughput * weight;
	// As in Remix, active SHARC preserves the first continuation for both update and query paths.
	// Invalid BSDF samples and the bounce limit still terminate normally; later bounces retain RR.
	float continuation = SharcEnabled() && primary ? 1.0
		: sqrt(saturate(MaxComponent(throughput) / max(MaxComponent(s.path.throughput), 1e-12)));
	if (continuation < 1.0)
	{
		if (rng.Next() >= continuation) return;
		throughput /= continuation;
	}
	s.path.throughput = throughput;
	s.path.direction = bs.wi;
	s.path.scatterPdf = bs.pdf;
	bool crossesSurface = (dot(bs.wi, si.faceNormal) > 0.0) != si.frontFacing;
	s.path.origin = si.ComputeRayOrigin(!crossesSurface);
	if (crossesSurface && !ms.thinWalled) s.path.absorption = si.frontFacing ? bsdf.volume.Absorption() : float3(0.0);
	s.path.coneWidth = hitConeWidth;
	s.path.coneSpread += ScatterConeSpread(bs.type, ms.roughness);
	s.randomSeed = rng.seed;
	s.active = 1u;
	if (SharcEnabled()) gAccum[Field(base, 6u)].w = asfloat(asuint(gAccum[Field(base, 6u)].w) + 1u);
}

void ShadeImpl<let DIRECT : bool, let PHASE : uint = 0u, let LATE_PATH : bool = false, let BUCKET : bool = false, let COMPACT_BUCKET : bool = false, let SEPARATE_LIGHT : bool = false>(uint3 tid)
{
	uint count = DIRECT ? gWavefront.pathCount : asuint(gAccum[HeaderBase()].z);
	uint bucket = MATERIAL_STACK_SIZE == 0u ? 0u : countbits(MATERIAL_STACK_SIZE - 1u) + 1u;
	if (COMPACT_BUCKET) count = asuint(gAccum[BucketMetadataBase() + bucket].x);
	if (tid.x >= count) return;
	uint index = DIRECT ? tid.x : QueueIndex(ShadeQueueBase(), tid.x);
	if (COMPACT_BUCKET) index = QueueIndex(ShadowQueueBase(), asuint(gAccum[BucketMetadataBase() + bucket].y) + tid.x);
	uint base = WorkBase(index);
	if (BUCKET)
	{
		// Dead slots can contain invalid hits. Nonmatching passes must not clear shadows
		// emitted by a prior bucket, including paths that terminated after NEE.
		if (asuint(gAccum[base].w) == 0u) return;
		uint instance = asuint(gAccum[Field(base, 8u)].w);
		uint material = gInstances[instance].materialIndex;
		uint capacity = (gMaterialData[material * 2u].w >> (SEPARATE_LIGHT ? 21u : 16u)) & 31u;
		if (capacity != MATERIAL_STACK_SIZE) return;
	}
	gAccum[Field(base, 11u)] = float4(0.0);
	WavefrontPath s;
	if (LATE_PATH) s = LoadShadingPath(base);
	else s = LoadPath<PHASE != 2u>(base);
	if (s.active == 0u) return;
	LoadFeedbackState(base);
	float4 h = gAccum[Field(base, 8u)];
	HitRecord hit;
	hit.t = h.x; hit.barycentrics = h.yz; hit.instanceIndex = asuint(h.w);
	hit.primitiveIndex = asuint(gAccum[Field(base, 9u)].x);
	ShadePath<true, true, PHASE, LATE_PATH, SEPARATE_LIGHT>(base, s, hit, PHASE == 1u ? 0u : gWavefront.bounce);
	StorePath<PHASE != 2u>(base, s);
	StoreFeedbackState(base);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void Shade(uint3 tid : SV_DispatchThreadID) { ShadeImpl<false>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadeDirect(uint3 tid : SV_DispatchThreadID) { ShadeImpl<true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadeSurface(uint3 tid : SV_DispatchThreadID) { ShadeImpl<false, 0u, false, false, false, true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadeSurfaceDirect(uint3 tid : SV_DispatchThreadID) { ShadeImpl<true, 0u, false, false, false, true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadeSurfaceBucket(uint3 tid : SV_DispatchThreadID) { ShadeImpl<false, 0u, false, true, false, true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadeSurfaceCompact(uint3 tid : SV_DispatchThreadID) { ShadeImpl<false, 0u, false, false, true, true>(tid); }

void ShadeLightImpl<let DIRECT : bool>(uint3 tid)
{
	uint count = DIRECT ? gWavefront.pathCount : asuint(gAccum[HeaderBase()].y);
	if (tid.x >= count) return;
	uint index = DIRECT ? tid.x : QueueIndex(ShadowQueueBase(), tid.x);
	uint base = WorkBase(index);
	uint mask = asuint(gAccum[Field(base, 11u)].z);
	if ((mask & 8u) == 0u) return;
	uint lightBase = LightWorkBase(index);
	float4 sample = gAccum[lightBase], viewer = gAccum[Field(lightBase, 1u)];
	LoadFeedbackState(base);
	float3 radiance = EvalSampledEmission(asuint(sample.w), sample.xyz, viewer.xyz, gAccum[Field(base, 11u)].xy);
	if ((mask & 2u) != 0u)
	{
		float4 coefficient = gAccum[Field(base, 17u)];
		// Preserve the reference's multiplication/division order.
		gAccum[Field(base, 17u)] = float4(coefficient.w * radiance * coefficient.xyz / viewer.w, 0.0);
		if (!any(radiance > 0.0)) mask &= ~2u;
	}
	gAccum[Field(base, 11u)].z = asfloat(mask & ~8u);
	StoreFeedbackState(base);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadeLight(uint3 tid : SV_DispatchThreadID) { ShadeLightImpl<false>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadeLightDirect(uint3 tid : SV_DispatchThreadID) { ShadeLightImpl<true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadeBucket(uint3 tid : SV_DispatchThreadID) { ShadeImpl<false, 0u, false, true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadeBucketDirect(uint3 tid : SV_DispatchThreadID) { ShadeImpl<true, 0u, false, true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadeBucketCompact(uint3 tid : SV_DispatchThreadID) { ShadeImpl<false, 0u, false, false, true>(tid); }

#define SHADE_ENTRY(NAME, DIRECT, PHASE, LATE) \
[shader("compute")] \
[numthreads(64, 1, 1)] \
void NAME(uint3 tid : SV_DispatchThreadID) { ShadeImpl<DIRECT, PHASE, LATE>(tid); }

SHADE_ENTRY(ShadePrimary, false, 1u, false)
SHADE_ENTRY(ShadeSecondary, false, 2u, false)
SHADE_ENTRY(ShadeLate, false, 0u, true)
SHADE_ENTRY(ShadePrimaryLate, false, 1u, true)
SHADE_ENTRY(ShadeSecondaryLate, false, 2u, true)
SHADE_ENTRY(ShadePrimaryDirect, true, 1u, false)
SHADE_ENTRY(ShadeSecondaryDirect, true, 2u, false)
SHADE_ENTRY(ShadeLateDirect, true, 0u, true)
SHADE_ENTRY(ShadePrimaryLateDirect, true, 1u, true)
SHADE_ENTRY(ShadeSecondaryLateDirect, true, 2u, true)
#undef SHADE_ENTRY

// Finish sparse tail paths without repeatedly materializing state and launching stages.
// The shared intersection/shading helpers preserve the staged estimator and random sequence.
void TailImpl<let ALPHA : bool>(uint3 tid)
{
	uint count = asuint(gAccum[HeaderBase()].x);
	if (tid.x >= count || (gWavefront.tailThreshold != 0u && count > gWavefront.tailThreshold)) return;
	uint base = WorkBase(QueueIndex(MainQueueBase(), tid.x));
	WavefrontPath s = LoadPath(base);
	if (s.active == 0u) return;
	LoadFeedbackState(base);
	for (uint bounce = gWavefront.bounce; bounce <= gFrame.settings.x; bounce++)
	{
		HitRecord hit = IntersectPath<ALPHA>(s, bounce);
		if (s.active == 0u) break;
		ShadePath<false, ALPHA>(base, s, hit, bounce);
		if (s.active == 0u) break;
	}
	StorePath(base, s);
	StoreFeedbackState(base);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void Tail(uint3 tid : SV_DispatchThreadID) { TailImpl<true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void TailOpaque(uint3 tid : SV_DispatchThreadID) { TailImpl<false>(tid); }

void ShadowImpl<let ALPHA : bool, let DIRECT : bool>(uint3 tid)
{
	uint count = DIRECT ? gWavefront.pathCount : asuint(gAccum[HeaderBase()].y);
	if (tid.x >= count) return;
	uint index = DIRECT ? tid.x : QueueIndex(ShadowQueueBase(), tid.x);
	uint base = WorkBase(index);
	float4 info = gAccum[Field(base, 11u)];
	uint mask = asuint(info.z);
	if (mask == 0u) return;
	if (ALPHA) LoadFeedbackState(base);
	gRayCone = info.xy;
	float3 sum = float3(0.0);
	float4 throughput = gAccum[Field(base, 10u)];
	[loop]
	for (uint source = 0u; source < 3u; source++)
	{
		if ((mask & (1u << source)) == 0u) continue;
		uint offset = 12u + source * 3u;
		float4 origin = gAccum[Field(base, offset)], direction = gAccum[Field(base, offset + 1u)];
		uint flags = asuint(direction.w);
		if ((flags & 1u) == 0u || !TraceOcclusion<ALPHA>(Ray(origin.xyz, direction.xyz, origin.w)))
		{
			float3 value = gAccum[Field(base, offset + 2u)].xyz;
			sum += value;
			NrdAddDirect(base, flags, throughput.xyz * value, direction.xyz);
		}
	}
	float3 contribution = throughput.xyz * sum;
	if (throughput.w > 0.0) contribution = min(contribution, float3(throughput.w));
	float4 path = gAccum[base];
	path.xyz += contribution;
	gAccum[base] = path;
	gAccum[Field(base, 11u)] = float4(0.0);
	if (ALPHA) StoreFeedbackState(base);
}

// Resolve in source order so the sum, throughput multiplication and clamp match Shadow.
void ResolveShadowVisibility(uint base, uint mask)
{
	float3 sum = float3(0.0);
	float4 throughput = gAccum[Field(base, 10u)];
	for (uint source = 0u; source < 3u; source++)
	{
		if ((mask & (1u << source)) == 0u) continue;
		float3 value = gAccum[Field(base, 14u + source * 3u)].xyz;
		sum += value;
		float4 direction = gAccum[Field(base, 13u + source * 3u)];
		NrdAddDirect(base, asuint(direction.w), throughput.xyz * value, direction.xyz);
	}
	float3 contribution = throughput.xyz * sum;
	if (throughput.w > 0.0) contribution = min(contribution, float3(throughput.w));
	float4 path = gAccum[base];
	path.xyz += contribution;
	gAccum[base] = path;
	gAccum[Field(base, 11u)] = float4(0.0);
}

// First geometric candidate, including alpha geometry. No material or VT work is
// reachable here. An alpha candidate is unresolved, never an accepted occluder.
void ShadowClassifyImpl<let DIRECT : bool>(uint3 tid)
{
	uint count = DIRECT ? gWavefront.pathCount : asuint(gAccum[HeaderBase()].y);
	if (tid.x >= count) return;
	uint index = DIRECT ? tid.x : QueueIndex(ShadowQueueBase(), tid.x);
	uint base = WorkBase(index);
	float4 info = gAccum[Field(base, 11u)];
	uint mask = asuint(info.z), pending = 0u;
	if (mask == 0u) return;
	for (uint source = 0u; source < 3u; source++)
	{
		uint bit = 1u << source;
		if ((mask & bit) == 0u) continue;
		uint offset = 12u + source * 3u;
		float4 origin = gAccum[Field(base, offset)], direction = gAccum[Field(base, offset + 1u)];
		HitRecord hit;
		if ((asuint(direction.w) & 1u) != 0u && TraceScene<false>(Ray(origin.xyz, direction.xyz, origin.w), true, hit))
		{
			if ((gInstances[hit.instanceIndex].flags & INSTANCE_FLAG_ALPHA_TESTED) != 0u) pending |= bit;
			else mask &= ~bit;
		}
	}
	if (pending == 0u) ResolveShadowVisibility(base, mask);
	else gAccum[Field(base, 11u)] = float4(info.xy, asfloat(mask), asfloat(pending));
}

// Queue B is free after CompactShade. Only pending paths reach this kernel;
// only their alpha-marked sources are retraced, in environment/emitter/sun order.
[shader("compute")]
[numthreads(64, 1, 1)]
void ShadowAlpha(uint3 tid : SV_DispatchThreadID)
{
	if (tid.x >= asuint(gAccum[HeaderBase()].z)) return;
	uint base = WorkBase(QueueIndex(ShadeQueueBase(), tid.x));
	float4 info = gAccum[Field(base, 11u)];
	uint mask = asuint(info.z), pending = asuint(info.w);
	LoadFeedbackState(base);
	gRayCone = info.xy;
	for (uint source = 0u; source < 3u; source++)
	{
		uint bit = 1u << source;
		if ((pending & bit) == 0u) continue;
		uint offset = 12u + source * 3u;
		float4 origin = gAccum[Field(base, offset)], direction = gAccum[Field(base, offset + 1u)];
		// Restart the original interval to preserve BVH/VT order. The first
		// geometric candidate need not be nearest, so advancing tMin is unsafe.
		if (TraceOcclusion<true>(Ray(origin.xyz, direction.xyz, origin.w))) mask &= ~bit;
	}
	ResolveShadowVisibility(base, mask);
	StoreFeedbackState(base);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadowClassify(uint3 tid : SV_DispatchThreadID) { ShadowClassifyImpl<false>(tid); }
[shader("compute")]
[numthreads(64, 1, 1)]
void ShadowClassifyDirect(uint3 tid : SV_DispatchThreadID) { ShadowClassifyImpl<true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void Intersect(uint3 tid : SV_DispatchThreadID) { IntersectImpl<true, false>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void IntersectOpaque(uint3 tid : SV_DispatchThreadID) { IntersectImpl<false, false>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void Shadow(uint3 tid : SV_DispatchThreadID) { ShadowImpl<true, false>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadowOpaque(uint3 tid : SV_DispatchThreadID) { ShadowImpl<false, false>(tid); }

// Direct-slot dispatch preserves the original pixel groups instead of packing live paths.
// Separate entry points let the compiler remove queue addressing and count loads entirely.
[shader("compute")]
[numthreads(64, 1, 1)]
void IntersectDirect(uint3 tid : SV_DispatchThreadID) { IntersectImpl<true, true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void IntersectOpaqueDirect(uint3 tid : SV_DispatchThreadID) { IntersectImpl<false, true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadowDirect(uint3 tid : SV_DispatchThreadID) { ShadowImpl<true, true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadowOpaqueDirect(uint3 tid : SV_DispatchThreadID) { ShadowImpl<false, true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void Finalize(uint3 tid : SV_DispatchThreadID)
{
	uint index = tid.x;
	if (index >= gWavefront.pathCount) return;
	uint base = WorkBase(index);
	WavefrontPath s = LoadPath(base);
	uint2 pixel = WorkPixel(index);
	if (any(pixel >= gFrame.frame.xy)) return;
	if (SharcEnabled() && SharcUpdatePath(index, gWavefront.tileStart)) SharcFinishUpdate(index, s.path.radiance);
	LoadFeedbackState(base);
	if (IsFeedbackPixel(pixel)) gVTFeedback.Store(pixel >> gFrame.vtInfo.w, gVTRequest);
	float3 radiance = s.path.radiance * gFrame.envParams.z;
	if (!all(isfinite(radiance))) radiance = float3(0.0);
	uint output = (pixel.y * gFrame.frame.x + pixel.x) * 3u;
	float2 primaryGuide = float2(gAccum[output + 1u].w, gAccum[output + 2u].w);
	if (gFrame.frame.z == 0u)
	{
		gAccum[output] = float4(radiance, 1.0);
		gAccum[output + 1u] = float4(s.albedo, 1.0);
		gAccum[output + 2u] = float4(s.normal, 1.0);
	}
	else
	{
		float w = 1.0 / float(gFrame.frame.z + 1u);
		gAccum[output] = float4(lerp(gAccum[output].xyz, radiance, w), 1.0);
		gAccum[output + 1u] = float4(lerp(gAccum[output + 1u].xyz, s.albedo, w), 1.0);
		gAccum[output + 2u] = float4(lerp(gAccum[output + 2u].xyz, s.normal, w), 1.0);
	}
	if (gFrame.temporal.z != 0.0) { gAccum[output + 1u].w = primaryGuide.x; gAccum[output + 2u].w = primaryGuide.y; }
	if (NrdEnabled())
	{
		uint r = NrdBase(base);
		float4 bypass = gAccum[r], diffuse = gAccum[r + 1u], specular = gAccum[r + 2u];
		float4 diffuseDirection = gAccum[r + 3u], specularDirection = gAccum[r + 4u];
		bool surface = specular.w >= 0.0;
		// Everything after primary direct light is indirect, split by the primary BSDF sample weight.
		float3 indirect = max(s.path.radiance - bypass.xyz - diffuse.xyz - specular.xyz, 0.0);
		float3 fraction = NrdUnpackFraction(asuint(bypass.w));
		float3 indirectDiffuse = indirect * fraction, indirectSpecular = indirect - indirectDiffuse;
		// Luminance is linear, so the direction weights of each signal sum to its luminance.
		float3 wi = any(indirect > 0.0) ? NrdOctDecode(float2(diffuseDirection.w, specularDirection.w)) : float3(0.0);
		float3 dDirection = (diffuseDirection.xyz + Luminance(indirectDiffuse) * wi) / max(Luminance(diffuse.xyz + indirectDiffuse), 1e-12);
		float3 sDirection = (specularDirection.xyz + Luminance(indirectSpecular) * wi) / max(Luminance(specular.xyz + indirectSpecular), 1e-12);
		float3 d = (diffuse.xyz + indirectDiffuse) * gFrame.envParams.z;
		float3 sp = (specular.xyz + indirectSpecular) * gFrame.envParams.z;
		bool valid = surface && all(isfinite(d)) && all(isfinite(sp));
		gAccum[r] = float4(valid ? d : float3(0.0), diffuse.w);
		gAccum[r + 1u] = float4(valid ? sp : float3(0.0), specular.w);
		gAccum[r + 2u] = float4(valid ? max(radiance - d - sp, 0.0) : radiance, valid ? 1.0 : 0.0);
		gAccum[r + 3u] = float4(valid && all(isfinite(dDirection)) ? dDirection : float3(0.0), 0.0);
		gAccum[r + 4u] = float4(valid && all(isfinite(sDirection)) ? sDirection : float3(0.0), 0.0);
	}
}
