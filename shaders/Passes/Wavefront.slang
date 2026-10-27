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
import Materials.MaterialSample;
import Materials.MaterialProgram;
import Materials.BSDF.BSDF;
import Materials.VirtualTexture;
import Lights.Lights;

struct WavefrontUniforms
{
	uint tileStart;
	uint pathCount;
	uint bounce;
	uint capacity;
	uint tailThreshold;
};
[[vk::binding(2, 1)]] ConstantBuffer<WavefrontUniforms> gWavefront;

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
uint ShadowQueueBase() { return MainQueueBase() + (gWavefront.capacity + 3u) / 4u; }
uint QueueIndex(uint base, uint index) { return asuint(gAccum[base + index / 4u][index & 3u]); }

uint2 WorkPixel(uint index)
{
	// Match the megakernel's 8x8 spatial grouping before paths diverge/compact.
	uint work = gWavefront.tileStart + index;
	uint block = work / 64u, lane = work & 63u;
	uint blocksX = (gFrame.frame.x + 7u) / 8u;
	return uint2((block % blocksX) * 8u + (lane & 7u), (block / blocksX) * 8u + lane / 8u);
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

WavefrontPath LoadPath(uint base)
{
	WavefrontPath s;
	float4 a = gAccum[base], b = gAccum[Field(base, 1u)], c = gAccum[Field(base, 2u)];
	float4 d = gAccum[Field(base, 3u)], e = gAccum[Field(base, 4u)], f = gAccum[Field(base, 5u)];
	s.path.radiance = a.xyz; s.active = asuint(a.w);
	s.path.throughput = b.xyz; s.randomSeed = asuint(b.w);
	s.path.origin = c.xyz; s.path.scatterPdf = c.w;
	s.path.direction = d.xyz; s.path.lightsSampled = asuint(d.w) != 0u;
	s.path.absorption = e.xyz; s.path.coneWidth = e.w;
	s.albedo = f.xyz; s.path.coneSpread = f.w;
	s.normal = gAccum[Field(base, 6u)].xyz;
	s.path.lobe = 0u; // last-lobe identity is already encoded in cone spread / NEE state
	return s;
}

void StorePath(uint base, WavefrontPath s)
{
	gAccum[base] = float4(s.path.radiance, asfloat(s.active));
	gAccum[Field(base, 1u)] = float4(s.path.throughput, asfloat(s.randomSeed));
	gAccum[Field(base, 2u)] = float4(s.path.origin, s.path.scatterPdf);
	gAccum[Field(base, 3u)] = float4(s.path.direction, asfloat(uint(s.path.lightsSampled)));
	gAccum[Field(base, 4u)] = float4(s.path.absorption, s.path.coneWidth);
	gAccum[Field(base, 5u)] = float4(s.albedo, s.path.coneSpread);
	gAccum[Field(base, 6u)] = float4(s.normal, 0.0);
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
	s.randomSeed = rng.seed;
	s.albedo = float3(0.0);
	s.normal = float3(0.0);
	uint base = WorkBase(index);
	StorePath(base, s);
	gAccum[Field(base, 11u)] = float4(0.0);
	if ((index & 3u) == 0u) gAccum[MainQueueBase() + index / 4u] = asfloat(uint4(index, index + 1u, index + 2u, index + 3u));
	if (index == 0u)
	{
		gAccum[HeaderBase()] = asfloat(uint4(gWavefront.pathCount, 0u, 0u, 0u));
		gAccum[HeaderBase() + 1u] = asfloat(uint4((gWavefront.pathCount + 63u) / 64u, 1u, 1u, 0u));
		gAccum[HeaderBase() + 2u] = asfloat(uint4(0u, 1u, 1u, 0u));
	}
	InitVirtualTextureFeedback(pixel);
	StoreFeedbackState(base);
}

HitRecord IntersectPath<let ALPHA : bool>(inout WavefrontPath s, uint bounce)
{
	gRayCone = float2(s.path.coneWidth, s.path.coneSpread);
	Ray ray = Ray(s.path.origin, s.path.direction);
	HitRecord hit = TraceClosest<ALPHA>(ray);
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

void IntersectImpl<let ALPHA : bool>(uint3 tid)
{
	if (tid.x >= asuint(gAccum[HeaderBase()].x)) return;
	uint index = QueueIndex(MainQueueBase(), tid.x);
	uint base = WorkBase(index);
	WavefrontPath s = LoadPath(base);
	if (s.active == 0u) return;
	if (ALPHA) LoadFeedbackState(base);
	HitRecord hit = IntersectPath<ALPHA>(s, gWavefront.bounce);
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

void QueueDirectLighting(uint base, SurfaceInteraction si, BSDF bsdf, float2 cone, float3 throughput, uint bounce, inout RandomSequence rng)
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
			ls = SampleEmissive(si.position, cone, rng);
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
			gAccum[Field(base, offset + 1u)] = float4(dir, asfloat(uint(shadow)));
			gAccum[Field(base, offset + 2u)] = float4(weight * ls.radiance * f / ls.solidAnglePdf, 0.0);
			mask |= 1u << source;
		}
	}
	// Clamp the sum of direct contributions, matching the megakernel exactly.
	gAccum[Field(base, 10u)] = float4(throughput, bounce > 0u ? gFrame.envParams.w / gFrame.envParams.z : 0.0);
	gAccum[Field(base, 11u)] = float4(cone, asfloat(mask), 0.0);
}

void ShadePath<let DEFERRED : bool, let ALPHA : bool>(uint base, inout WavefrontPath s, HitRecord hit, uint bounce)
{
	if (any(s.path.absorption > 0.0)) s.path.throughput *= exp(s.path.absorption * -hit.t);
	float hitConeWidth = s.path.coneWidth + s.path.coneSpread * hit.t;
	SurfaceInteraction si = GetSurfaceInteraction(s.path.direction, hit, hitConeWidth);
	float3 V = -s.path.direction;
	MaterialSample ms = EvalMaterial(si, V);
	BSDF bsdf = BSDF(ms.inputs, V, s.path.throughput, BSDF_RGB_WAVELENGTHS, 1.0);
	if (bounce == 0u)
	{
		s.albedo = ms.albedo;
		s.normal = si.frontFacing ? ms.inputs.basis.n : -ms.inputs.basis.n;
	}
	s.active = 0u;
	if (!si.frontFacing && !ms.doubleSided && ms.inputs.transmissionWeight <= 0.0) return;
	if (any(bsdf.emission > 0.0))
	{
		float mis = 1.0;
		if (bounce > 0u && s.path.lightsSampled)
		{
			Instance inst = gInstances[si.instanceIndex];
			float pdf = EmissiveHitPdf(inst, si.primitiveIndex, s.path.origin, si.position);
			mis = EvalMISRobust(s.path.scatterPdf, pdf);
		}
		float3 contribution = s.path.throughput * mis * bsdf.emission;
		float clampValue = gFrame.envParams.w / gFrame.envParams.z;
		if (clampValue > 0.0 && bounce > 0u) contribution = min(contribution, float3(clampValue));
		s.path.radiance += contribution;
	}
	if (bounce == gFrame.settings.x) return;
	RandomSequence rng = RandomSequence(0u, 0u);
	rng.seed = s.randomSeed;
	s.path.lightsSampled = bsdf.MaxActiveAlpha() >= NEAR_SPECULAR_ALPHA;
	if (s.path.lightsSampled)
	{
		if (DEFERRED)
		{
			QueueDirectLighting(base, si, bsdf, float2(hitConeWidth, s.path.coneSpread), s.path.throughput, bounce, rng);
		}
		else
		{
			float3 direct = s.path.throughput * NextEventEstimation<ALPHA>(si, bsdf, float2(hitConeWidth, s.path.coneSpread), rng);
			float clampValue = gFrame.envParams.w / gFrame.envParams.z;
			if (clampValue > 0.0 && bounce > 0u) direct = min(direct, float3(clampValue));
			s.path.radiance += direct;
		}
	}
	float2 u = rng.Next2D();
	LobeSample bs = bsdf.Sample(float3(u, rng.Next()));
	float3 weight = bs.weight.diffuse + bs.weight.specular;
	if (!bs.valid || bs.pdf <= 0.0 || all(weight <= 0.0)) return;
	float3 throughput = s.path.throughput * weight;
	float continuation = sqrt(saturate(MaxComponent(throughput) / max(MaxComponent(s.path.throughput), 1e-12)));
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
}

[shader("compute")]
[numthreads(64, 1, 1)]
void Shade(uint3 tid : SV_DispatchThreadID)
{
	if (tid.x >= asuint(gAccum[HeaderBase()].x)) return;
	uint index = QueueIndex(MainQueueBase(), tid.x);
	uint base = WorkBase(index);
	gAccum[Field(base, 11u)] = float4(0.0);
	WavefrontPath s = LoadPath(base);
	if (s.active == 0u) return;
	LoadFeedbackState(base);
	float4 h = gAccum[Field(base, 8u)];
	HitRecord hit;
	hit.t = h.x; hit.barycentrics = h.yz; hit.instanceIndex = asuint(h.w);
	hit.primitiveIndex = asuint(gAccum[Field(base, 9u)].x);
	ShadePath<true, true>(base, s, hit, gWavefront.bounce);
	StorePath(base, s);
	StoreFeedbackState(base);
}

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

void ShadowImpl<let ALPHA : bool>(uint3 tid)
{
	if (tid.x >= asuint(gAccum[HeaderBase()].y)) return;
	uint index = QueueIndex(ShadowQueueBase(), tid.x);
	uint base = WorkBase(index);
	float4 info = gAccum[Field(base, 11u)];
	uint mask = asuint(info.z);
	if (mask == 0u) return;
	if (ALPHA) LoadFeedbackState(base);
	gRayCone = info.xy;
	float3 sum = float3(0.0);
	[loop]
	for (uint source = 0u; source < 3u; source++)
	{
		if ((mask & (1u << source)) == 0u) continue;
		uint offset = 12u + source * 3u;
		float4 origin = gAccum[Field(base, offset)], direction = gAccum[Field(base, offset + 1u)];
		if (asuint(direction.w) == 0u || !TraceOcclusion<ALPHA>(Ray(origin.xyz, direction.xyz, origin.w))) sum += gAccum[Field(base, offset + 2u)].xyz;
	}
	float4 throughput = gAccum[Field(base, 10u)];
	float3 contribution = throughput.xyz * sum;
	if (throughput.w > 0.0) contribution = min(contribution, float3(throughput.w));
	float4 path = gAccum[base];
	path.xyz += contribution;
	gAccum[base] = path;
	gAccum[Field(base, 11u)] = float4(0.0);
	if (ALPHA) StoreFeedbackState(base);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void Intersect(uint3 tid : SV_DispatchThreadID) { IntersectImpl<true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void IntersectOpaque(uint3 tid : SV_DispatchThreadID) { IntersectImpl<false>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void Shadow(uint3 tid : SV_DispatchThreadID) { ShadowImpl<true>(tid); }

[shader("compute")]
[numthreads(64, 1, 1)]
void ShadowOpaque(uint3 tid : SV_DispatchThreadID) { ShadowImpl<false>(tid); }

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
	LoadFeedbackState(base);
	if (IsFeedbackPixel(pixel)) gVTFeedback.Store(pixel >> gFrame.vtInfo.w, gVTRequest);
	float3 radiance = s.path.radiance * gFrame.envParams.z;
	if (!all(isfinite(radiance))) radiance = float3(0.0);
	uint output = (pixel.y * gFrame.frame.x + pixel.x) * 3u;
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
}
