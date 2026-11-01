// Radiance cache probe trace (docs/RadianceCache.md): one workgroup per probe slot in the frame's update list, one
// path per octahedral texel (P x P = 64). Paths use the megakernel's traversal, materials and next event estimation;
// the first segment starts at the probe, so it is not MIS weighted and does not see the sun disc or analytic lights
// (realtime frames light their highlights directly). Results blend into the probe's history; a probe whose rays mostly
// hit back faces is inside geometry and flagged, which lookups skip.
import Common.Math;
import Common.Random;
import Scene.SceneTypes;
import Scene.SceneBindings;
import RayTracing.Traversal;
import Materials.MaterialSample;
import Materials.MaterialProgram;
import Materials.BSDF.BSDF;
import Lights.Lights;
import Materials.VirtualTexture;
import Passes.PathTracing;

#define RADIANCE_CACHE_GROUP 1
#define RADIANCE_CACHE_BINDING_CONSTANTS 2
#define RADIANCE_CACHE_BINDING_PROBES 3
#define RADIANCE_CACHE_PROBES_RW 1
#include "../RadianceCache/RadianceCacheCommon.hlsli"

static const uint PROBE_RESOLUTION = 8u; // grid.y
static const uint MAX_UPDATES = 1024u;
struct RadianceCacheUpdates { uint4 slots[MAX_UPDATES / 4u]; };
[[vk::binding(4, 1)]] ConstantBuffer<RadianceCacheUpdates> gUpdates;

groupshared Atomic<uint> gBackfaces;

// Radiance arriving at the probe from `direction`; hitDistance is the first segment's length (miss: MISS_DISTANCE).
float3 TraceProbeRay(float3 origin, float3 direction, inout RandomSequence rng, out float hitDistance, out bool backface)
{
	PathState path;
	path.radiance = float3(0.0);
	path.throughput = float3(1.0);
	path.origin = origin;
	path.direction = direction;
	path.scatterPdf = 1.0;
	path.lobe = 0u;
	path.coneWidth = 0.0;
	path.coneSpread = 2.0 * PI / float(PROBE_RESOLUTION * PROBE_RESOLUTION); // the texel's solid angle, roughly
	path.absorption = float3(0.0);
	path.lightsSampled = false;
	hitDistance = RADIANCE_CACHE_MISS_DISTANCE;
	backface = false;
	uint maxBounces = gRadianceCache.frame.z;
	float maxRadiance = gRadianceCache.params.y;
	for (uint bounce = 0u; bounce <= maxBounces; bounce++)
	{
		Ray ray = Ray(path.origin, path.direction);
		gRayCone = float2(path.coneWidth, path.coneSpread);
		HitRecord hit = TraceClosest<true, true>(ray);
		if (bounce > 0u && AnalyticLightCount() > 0u)
		{
			float3 lightRadiance;
			float lightPdf;
			if (IntersectAnalyticLights(ray.origin, ray.direction, hit.IsHit() ? hit.t : FLT_LARGE, false, lightRadiance, lightPdf))
			{
				float mis = path.lightsSampled ? EvalMISRobust(path.scatterPdf, lightPdf) : 1.0;
				path.radiance += min(path.throughput * mis * lightRadiance, float3(maxRadiance));
			}
		}
		if (!hit.IsHit())
		{
			// The environment without the sun disc, which NEE samples at later vertices.
			float mis = bounce > 0u && path.lightsSampled ? EvalMISRobust(path.scatterPdf, EnvironmentPdf(ray.direction)) : 1.0;
			path.radiance += min(path.throughput * mis * EvalEnvironment(ray.direction), float3(maxRadiance));
			break;
		}
		if (bounce == 0u) hitDistance = hit.t;
		if (any(path.absorption > 0.0)) path.throughput *= exp(path.absorption * -hit.t);
		float hitConeWidth = path.coneWidth + path.coneSpread * hit.t;
		SurfaceInteraction si = GetSurfaceInteraction(ray.direction, hit, hitConeWidth);
		float3 V = -ray.direction;
		MaterialSample ms = EvalMaterial(si, V);
		BSDF bsdf = BSDF(ms.inputs, V, path.throughput, BSDF_RGB_WAVELENGTHS, 1.0);
		if (!si.frontFacing && !ms.doubleSided && ms.inputs.transmissionWeight <= 0.0)
		{
			if (bounce == 0u) backface = true;
			break;
		}
		if (any(bsdf.emission > 0.0))
		{
			float mis = 1.0;
			if (bounce > 0u && path.lightsSampled)
			{
				Instance inst = gInstances[si.instanceIndex];
				mis = EvalMISRobust(path.scatterPdf, EmissiveHitPdf(inst, si.primitiveIndex, ray.origin, si.position));
			}
			path.radiance += min(path.throughput * mis * bsdf.emission, float3(maxRadiance));
		}
		if (bounce == maxBounces) break;
		path.lightsSampled = bsdf.MaxActiveAlpha() >= NEAR_SPECULAR_ALPHA;
		if (path.lightsSampled)
			path.radiance += min(path.throughput * NextEventEstimation<true, true>(si, bsdf, float2(hitConeWidth, path.coneSpread), rng), float3(maxRadiance));
		float2 u = rng.Next2D();
		LobeSample bs = bsdf.Sample(float3(u, rng.Next()));
		float3 weight = bs.weight.diffuse + bs.weight.specular;
		if (!bs.valid || bs.pdf <= 0.0 || all(weight <= 0.0)) break;
		float3 throughput = path.throughput * weight;
		float continuation = sqrt(saturate(MaxComponent(throughput) / max(MaxComponent(path.throughput), 1e-12)));
		if (continuation < 1.0)
		{
			if (rng.Next() >= continuation) break;
			throughput /= continuation;
		}
		path.throughput = throughput;
		path.direction = bs.wi;
		path.scatterPdf = bs.pdf;
		bool crossesSurface = (dot(bs.wi, si.faceNormal) > 0.0) != si.frontFacing;
		path.origin = si.ComputeRayOrigin(!crossesSurface);
		if (crossesSurface && !ms.thinWalled) path.absorption = si.frontFacing ? bsdf.volume.Absorption() : float3(0.0);
		path.lobe = bs.type;
		path.coneWidth = hitConeWidth;
		path.coneSpread += ScatterConeSpread(bs.type, ms.roughness);
	}
	return all(isfinite(path.radiance)) ? path.radiance : float3(0.0);
}

[shader("compute")]
[numthreads(8, 8, 1)]
void TraceProbes(uint3 group : SV_GroupID, uint3 local : SV_GroupThreadID, uint index : SV_GroupIndex)
{
	if (index == 0u) gBackfaces.store(0u);
	GroupMemoryBarrierWithGroupSync();
	uint update = group.x;
	uint slot = gUpdates.slots[update / 4u][update % 4u];
	uint R = gRadianceCache.grid.x;
	uint perClipmap = R * R * R;
	uint clipmap = slot / perClipmap;
	uint local3 = slot - clipmap * perClipmap;
	int3 s = int3(int(local3 % R), int((local3 / R) % R), int(local3 / (R * R)));
	// The window's world cell that maps to this slot.
	int3 o = gRadianceCache.origins[clipmap].xyz;
	int3 cell = o + int3(RadianceCachePosMod(s.x - o.x, int(R)), RadianceCachePosMod(s.y - o.y, int(R)), RadianceCachePosMod(s.z - o.z, int(R)));
	uint base = RadianceCacheProbeBase(slot);
	uint tag = RadianceCacheCellTag(cell);
	uint state = gRadianceCacheProbes[base];
	bool history = (state & RADIANCE_CACHE_STATE_VALID) != 0u && (state & 0xffffffu) == tag;
	uint samples = history ? gRadianceCacheProbes[base + 1u] : 0u;

	RandomSequence rng = RandomSequence(uint2(slot, index), gRadianceCache.frame.x);
	float2 jitter = rng.Next2D();
	float2 p = (float2(local.xy) + jitter) / float(PROBE_RESOLUTION) * 2.0 - 1.0;
	float3 direction = RadianceCacheOctDecode(p);
	float hitDistance;
	bool backface;
	float3 radiance = TraceProbeRay(RadianceCacheProbePosition(clipmap, cell), direction, rng, hitDistance, backface);
	if (backface) gBackfaces.add(1u);
	GroupMemoryBarrierWithGroupSync();

	// Running average over up to 16 traces, then an exponential window: lighting changes settle in ~16 updates.
	uint texel = base + RADIANCE_CACHE_HEADER_WORDS + (local.y * PROBE_RESOLUTION + local.x) * 2u;
	float alpha = 1.0 / float(min(samples, 15u) + 1u);
	if (samples > 0u)
	{
		uint a = gRadianceCacheProbes[texel], b = gRadianceCacheProbes[texel + 1u];
		float3 old = float3(f16tof32(a & 0xffffu), f16tof32(a >> 16u), f16tof32(b & 0xffffu));
		radiance = lerp(old, radiance, alpha);
		hitDistance = lerp(f16tof32(b >> 16u), hitDistance, alpha);
	}
	radiance = min(radiance, float3(65000.0));
	gRadianceCacheProbes[texel] = f32tof16(radiance.x) | (f32tof16(radiance.y) << 16u);
	gRadianceCacheProbes[texel + 1u] = f32tof16(radiance.z) | (f32tof16(min(hitDistance, RADIANCE_CACHE_MISS_DISTANCE)) << 16u);
	if (index == 0u)
	{
		// More than a quarter of the rays leave through back faces: the probe sits inside geometry.
		bool inside = gBackfaces.load() * 4u > PROBE_RESOLUTION * PROBE_RESOLUTION;
		gRadianceCacheProbes[base] = tag | RADIANCE_CACHE_STATE_VALID | (inside ? RADIANCE_CACHE_STATE_INSIDE : 0u);
		gRadianceCacheProbes[base + 1u] = samples + 1u;
	}
}
