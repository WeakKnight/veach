// Megakernel path tracer (ported from Legacy/Source/XPU/Private/PathTracing.cpp).
// MIS between BSDF sampling and explicit sampling of the environment, emissive triangles and
// analytic lights (spheres, spots, rectangles, ellipses; point lights without radius are NEE only);
// the sun is a small cone sampled with NEE only, except after near-specular vertices, which skip NEE.
// Interior media only absorb (Beer-Lambert).
// Output is accumulated progressively.
import Common.Math;
import Common.Random;
import Scene.SceneTypes;
import Scene.SceneBindings;
import RayTracing.Traversal;
import Materials.MaterialSample;
import Materials.MaterialProgram;
import Materials.BSDF.BSDF;
import Lights.Lights;
import Materials.Textures;
import Materials.VirtualTexture;

// Per pixel: [0] radiance * pre-exposure, [1] albedo, [2] shading normal; running averages.
[[vk::binding(0, 1)]] RWStructuredBuffer<float4> gAccum;
// Virtual texture feedback: one request (page index + 1, 0 = none) per feedback tile.
[[vk::binding(1, 1)]] [format("r32ui")] WTexture2D<uint> gVTFeedback;

struct PathState
{
	float3 radiance;
	float3 throughput;
	float3 origin;
	float3 direction;
	float scatterPdf; // pdf of the last BSDF sample, for MIS
	uint lobe;
	float coneWidth;  // ray cone width at origin
	float coneSpread; // ray cone spread angle
	float3 absorption; // absorption coefficient of the medium the ray travels in (0 outside)
	bool lightsSampled; // NEE ran at the last vertex, so lights hit by this ray are MIS-weighted
};

// Below this GGX alpha (roughness ~0.03) light samples essentially never land in the lobe: NEE is
// skipped and lights, including the sun disc, are found by BSDF sampling alone.
static const float NEAR_SPECULAR_ALPHA = 1e-3;

// Ray cone widening after a scattering event. Glossy and diffuse lobes have no well-defined cone;
// widen with the lobe's roughness so secondary hits fetch coarser mips (fewer page requests).
float ScatterConeSpread(uint lobe, float roughness)
{
	if ((lobe & LOBE_DIFFUSE) != 0u)
	{
		return 0.5;
	}
	return 0.5 * roughness * roughness;
}

float3 ShadowOrigin(SurfaceInteraction si, float3 dir)
{
	return ComputeOffsetOrigin(si.position, dot(si.faceNormal, dir) >= 0.0 ? si.faceNormal : -si.faceNormal);
}

// cone: ray cone (width, spread) at the shading point.
// One sample per light source (environment, emissive, sun) in a loop, sharing one BSDF evaluation
// and one shadow ray, so their code (and the traversal with alpha testing) is instantiated once.
float3 NextEventEstimation(SurfaceInteraction si, BSDF bsdf, float2 cone, inout RandomSequence rng)
{
	float3 result = float3(0.0);
	gRayCone = cone;

	[loop]
	for (uint source = 0u; source < 3u; ++source)
	{
		LightSample ls;
		float3 origin;
		float3 dir;
		float maxDistance = FLT_LARGE;
		bool shadow = true;
		bool mis = true;
		if (source == 0u)
		{
			if (!EnvironmentEnabled())
			{
				continue;
			}
			ls = SampleEnvironment(rng);
			if (!(any(ls.radiance > 0.0) && ls.solidAnglePdf > 0.0))
			{
				continue;
			}
			dir = -ls.normal;
			origin = ShadowOrigin(si, dir);
		}
		else if (source == 1u)
		{
			if (LightCount() == 0u)
			{
				continue;
			}
			ls = SampleEmissive(si.position, cone, rng);
			if (!(any(ls.radiance > 0.0) && ls.solidAnglePdf > 0.0))
			{
				continue;
			}
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
			if (!SunEnabled())
			{
				continue;
			}
			ls = SampleSun(rng);
			dir = -ls.normal;
			origin = ShadowOrigin(si, dir);
			mis = false;
		}

		DiffuseSpecular eval;
		float bsdfPdf;
		bsdf.EvalPdf(dir, eval, bsdfPdf);
		float3 f = eval.diffuse + eval.specular;
		if (any(f > 0.0) && (!shadow || !TraceOcclusion(Ray(origin, dir, maxDistance))))
		{
			float weight = mis ? EvalMISRobust(ls.solidAnglePdf, bsdfPdf) : 1.0;
			result += weight * ls.radiance * f / ls.solidAnglePdf;
		}
	}

	return result;
}

float3 HashColor(uint id)
{
	uint h = StrongIntegerHash(id + 1u);
	return float3(float(h & 255u), float((h >> 8u) & 255u), float((h >> 16u) & 255u)) / 255.0;
}

float3 HeatMap(float t)
{
	t = saturate(t);
	return saturate(float3(1.5 - abs(4.0 * t - 3.0), 1.5 - abs(4.0 * t - 2.0), 1.5 - abs(4.0 * t - 1.0)));
}

Ray GenerateCameraRay(uint2 pixel, inout RandomSequence rng)
{
	float2 resolution = float2(gFrame.frame.xy);
	float2 film = (float2(pixel) + rng.Next2D()) / resolution;
	float2 ndc = float2(film.x * 2.0 - 1.0, 1.0 - film.y * 2.0);
	float3 forward = gFrame.cameraForward.xyz;
	float3 dir = normalize(forward + gFrame.cameraRight.xyz * ndc.x + gFrame.cameraUp.xyz * ndc.y);
	float3 origin = gFrame.cameraPosition.xyz;

	float lensRadius = gFrame.cameraPosition.w;
	if (lensRadius > 0.0)
	{
		float focusDistance = gFrame.cameraRight.w;
		float3 focusPoint = origin + dir * (focusDistance / dot(dir, forward));
		float2 lens = SampleDisk(rng.Next2D()) * lensRadius;
		origin += normalize(gFrame.cameraRight.xyz) * lens.x + normalize(gFrame.cameraUp.xyz) * lens.y;
		dir = normalize(focusPoint - origin);
	}
	return Ray(origin, dir);
}

[shader("compute")]
[numthreads(8, 8, 1)]
void main(uint3 tid: SV_DispatchThreadID)
{
	uint2 pixel = tid.xy;
	if (pixel.x >= gFrame.frame.x || pixel.y >= gFrame.frame.y)
	{
		return;
	}

	uint frameIndex = gFrame.frame.z;
	uint maxBounces = gFrame.settings.x;
	uint debugMode = gFrame.settings.y;
	RandomSequence rng = RandomSequence(pixel, gFrame.frame.w);
	InitVirtualTextureFeedback(pixel);

	Ray cameraRay = GenerateCameraRay(pixel, rng);
	PathState path;
	path.radiance = float3(0.0);
	path.throughput = float3(1.0);
	path.origin = cameraRay.origin;
	path.direction = cameraRay.direction;
	path.scatterPdf = 1.0;
	path.lobe = 0u;
	path.coneWidth = 0.0;
	path.coneSpread = gFrame.vtParams.y;
	path.absorption = float3(0.0);
	path.lightsSampled = false;

	float3 albedoOut = float3(0.0);
	float3 normalOut = float3(0.0);
	float3 debugOut = float3(0.0);
	// the clamp is in pre-exposed units, so it follows the exposure
	float preExposure = gFrame.envParams.z;
	float fireflyClamp = gFrame.envParams.w * rcp(preExposure);

	for (uint bounce = 0u; bounce <= maxBounces; bounce++)
	{
		Ray ray = Ray(path.origin, path.direction);
		gRayCone = float2(path.coneWidth, path.coneSpread);
		HitRecord hit = TraceClosest(ray);

		if (bounce == 0u && debugMode == DEBUG_TRAVERSAL)
		{
			debugOut = HeatMap(float(gTraversalCost) / 256.0);
			break;
		}

		// analytic lights do not occlude: add the one in front of the hit and keep going
		if (AnalyticLightCount() > 0u)
		{
			float3 lightRadiance;
			float lightPdf;
			if (IntersectAnalyticLights(ray.origin, ray.direction, hit.IsHit() ? hit.t : FLT_LARGE, bounce == 0u, lightRadiance, lightPdf))
			{
				float mis = bounce > 0u && path.lightsSampled ? EvalMISRobust(path.scatterPdf, lightPdf) : 1.0;
				float3 contribution = path.throughput * mis * lightRadiance;
				if (fireflyClamp > 0.0 && bounce > 0u)
				{
					contribution = min(contribution, float3(fireflyClamp));
				}
				path.radiance += contribution;
			}
		}

		if (!hit.IsHit())
		{
			if (bounce == 0u)
			{
				bool visible = (gFrame.settings.z & FRAME_FLAG_ENV_VISIBLE) != 0u;
				path.radiance += visible ? EvalEnvironment(ray.direction) : gFrame.background.rgb;
				if (visible && HitsSun(ray.direction))
				{
					path.radiance += gFrame.sunRadiance.rgb;
				}
			}
			else
			{
				float mis = path.lightsSampled ? EvalMISRobust(path.scatterPdf, EnvironmentPdf(ray.direction)) : 1.0;
				float3 contribution = path.throughput * mis * EvalEnvironment(ray.direction);
				if (!path.lightsSampled && SunEnabled() && HitsSun(ray.direction))
				{
					contribution += path.throughput * gFrame.sunRadiance.rgb;
				}
				if (fireflyClamp > 0.0)
				{
					contribution = min(contribution, float3(fireflyClamp));
				}
				path.radiance += contribution;
			}
			break;
		}

		if (any(path.absorption > 0.0))
		{
			path.throughput *= exp(path.absorption * -hit.t);
		}

		float hitConeWidth = path.coneWidth + path.coneSpread * hit.t;
		SurfaceInteraction si = GetSurfaceInteraction(ray.direction, hit, hitConeWidth);
		float3 V = -ray.direction;
		gVTLastMappedLevel = 0u;
		gVTLastRequestedLevel = 0u;
		MaterialSample ms = EvalMaterial(si, V);

		BSDF bsdf = BSDF(ms.inputs, V, path.throughput, BSDF_RGB_WAVELENGTHS, 1.0);
		float3 facingNormal = si.frontFacing ? ms.inputs.basis.n : -ms.inputs.basis.n;

		if (bounce == 0u)
		{
			albedoOut = ms.albedo;
			normalOut = facingNormal;
			if (debugMode != DEBUG_NONE)
			{
				switch (debugMode)
				{
				case DEBUG_ALBEDO:
					debugOut = ms.albedo;
					break;
				case DEBUG_SHADING_NORMAL:
					debugOut = facingNormal * 0.5 + 0.5;
					break;
				case DEBUG_GEOMETRY_NORMAL:
					debugOut = si.faceNormal * 0.5 + 0.5;
					break;
				case DEBUG_UV:
					debugOut = float3(frac(si.tex.uv0), 0.0);
					break;
				case DEBUG_VIRTUAL_TEXTURE:
				{
					MaterialHeader material = LoadMaterialHeader(si.materialIndex);
					TextureRef baseColor;
					baseColor.flags = 0u;
					if (material.debugTexture != PROGRAM_NONE)
					{
						baseColor = LoadTextureRef(material, material.debugTexture);
					}
					if (HasTexture(baseColor))
					{
						SampleTexture(baseColor, si.tex);
						debugOut = HeatMap(float(gVTLastMappedLevel) / 6.0);
						if (gVTLastMappedLevel > gVTLastRequestedLevel)
						{
							debugOut = lerp(debugOut, float3(1.0, 0.0, 0.0), 0.6);
						}
					}
					else
					{
						debugOut = float3(0.2);
					}
					break;
				}
				case DEBUG_INSTANCE:
					debugOut = HashColor(si.instanceIndex);
					break;
				case DEBUG_MATERIAL:
					debugOut = HashColor(si.materialIndex);
					break;
				default:
					debugOut = bsdf.emission;
					break;
				}
				break;
			}
		}

		// single-sided surfaces seen from behind are opaque black, unless light can pass through
		if (!si.frontFacing && !ms.doubleSided && ms.inputs.transmissionWeight <= 0.0)
		{
			break;
		}

		// emission, MIS-weighted against light sampling
		if (any(bsdf.emission > 0.0))
		{
			float mis = 1.0;
			if (bounce > 0u && path.lightsSampled)
			{
				Instance inst = gInstances[si.instanceIndex];
				float lightPdf = EmissiveHitPdf(inst, si.primitiveIndex, ray.origin, si.position);
				mis = EvalMISRobust(path.scatterPdf, lightPdf);
			}
			float3 contribution = path.throughput * mis * bsdf.emission;
			if (fireflyClamp > 0.0 && bounce > 0u)
			{
				contribution = min(contribution, float3(fireflyClamp));
			}
			path.radiance += contribution;
		}

		if (bounce == maxBounces)
		{
			break;
		}

		path.lightsSampled = bsdf.MaxActiveAlpha() >= NEAR_SPECULAR_ALPHA;
		if (path.lightsSampled)
		{
			float3 direct = path.throughput * NextEventEstimation(si, bsdf, float2(hitConeWidth, path.coneSpread), rng);
			if (fireflyClamp > 0.0 && bounce > 0u)
			{
				direct = min(direct, float3(fireflyClamp));
			}
			path.radiance += direct;
		}

		float2 u = rng.Next2D();
		LobeSample bs = bsdf.Sample(float3(u, rng.Next()));
		float3 weight = bs.weight.diffuse + bs.weight.specular;
		if (!bs.valid || bs.pdf <= 0.0 || all(weight <= 0.0))
		{
			break;
		}

		float3 newThroughput = path.throughput * weight;
		// Russian roulette on the throughput change
		float continuation = sqrt(saturate(MaxComponent(newThroughput) / max(MaxComponent(path.throughput), 1e-12)));
		if (continuation < 1.0)
		{
			if (rng.Next() >= continuation)
			{
				break;
			}
			newThroughput /= continuation;
		}
		path.throughput = newThroughput;
		path.direction = bs.wi;
		path.scatterPdf = bs.pdf;
		bool crossesSurface = (dot(bs.wi, si.faceNormal) > 0.0) != si.frontFacing;
		path.origin = si.ComputeRayOrigin(!crossesSurface);
		// crossing a closed surface enters (front) or leaves (back) its medium
		if (crossesSurface && !ms.thinWalled)
		{
			path.absorption = si.frontFacing ? bsdf.volume.Absorption() : float3(0.0);
		}
		path.lobe = bs.type;
		path.coneWidth = hitConeWidth;
		path.coneSpread += ScatterConeSpread(bs.type, ms.roughness);
	}

	if (IsFeedbackPixel(pixel))
	{
		gVTFeedback.Store(pixel >> gFrame.vtInfo.w, gVTRequest);
	}

	float3 radiance = debugMode != DEBUG_NONE ? debugOut : path.radiance * preExposure;
	if (!all(isfinite(radiance)))
	{
		radiance = float3(0.0);
	}

	uint base = (pixel.y * gFrame.frame.x + pixel.x) * 3u;
	if (frameIndex == 0u)
	{
		gAccum[base + 0u] = float4(radiance, 1.0);
		gAccum[base + 1u] = float4(albedoOut, 1.0);
		gAccum[base + 2u] = float4(normalOut, 1.0);
	}
	else
	{
		float w = 1.0 / float(frameIndex + 1u);
		gAccum[base + 0u] = float4(lerp(gAccum[base + 0u].rgb, radiance, w), 1.0);
		gAccum[base + 1u] = float4(lerp(gAccum[base + 1u].rgb, albedoOut, w), 1.0);
		gAccum[base + 2u] = float4(lerp(gAccum[base + 2u].rgb, normalOut, w), 1.0);
	}
}
