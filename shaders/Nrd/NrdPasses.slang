// NRD front-end (Prepare) and back-end (Composite) for the real-time path (docs/Nrd.md).
// Built by scripts/build-nrd.mjs, which provides NRD.hlsli from the NRD SDK. NRD_PASS_SH = 1 targets
// REBLUR_DIFFUSE_SPECULAR_SH: SG inputs from the dominant light directions, SG resolve and re-jittering.
#include "NRD.hlsli"
import Scene.SceneTypes;

struct NrdParams
{
	float4 hitDistance; // REBLUR hit distance parameters A, B, C; denoising range
	uint4 control; // NRD region float4 offset, debug view, history valid, re-jitter (SH)
};
[[vk::binding(0, 0)]] ConstantBuffer<FrameUniforms> gFrame;
[[vk::binding(1, 0)]] ConstantBuffer<NrdParams> gNrd;
// Accumulation image (three float4 per pixel) and the NRD region written by Wavefront Finalize.
[[vk::binding(2, 0)]] StructuredBuffer<float4> gAccum;
[[vk::binding(3, 0)]] StructuredBuffer<float4> gMotion;
[[vk::binding(4, 0)]] RWTexture2D<float4> gOutMv;
[[vk::binding(5, 0)]] RWTexture2D<float4> gOutNormalRoughness;
[[vk::binding(6, 0)]] RWTexture2D<float> gOutViewZ;
[[vk::binding(7, 0)]] RWTexture2D<float4> gOutDiff;
[[vk::binding(8, 0)]] RWTexture2D<float4> gOutSpec;
[[vk::binding(9, 0)]] Texture2D<float4> gDiff;
[[vk::binding(10, 0)]] Texture2D<float4> gSpec;
[[vk::binding(11, 0)]] RWStructuredBuffer<float4> gComposite;
#if NRD_PASS_SH
// SH mode: gOutDiff/gOutSpec/gDiff/gSpec hold SH0; these hold SH1.
[[vk::binding(12, 0)]] RWTexture2D<float4> gOutDiffSh1;
[[vk::binding(13, 0)]] RWTexture2D<float4> gOutSpecSh1;
[[vk::binding(14, 0)]] Texture2D<float4> gDiffSh1;
[[vk::binding(15, 0)]] Texture2D<float4> gSpecSh1;
#endif
static const uint NRD_STRIDE = 5u; // float4 per pixel in the region, see Wavefront.slang

struct NrdSurface
{
	bool valid;
	float3 diffuse, specular, bypass; // pre-exposed
	float hitDistance, roughness, viewZ;
	float3 normal, view, diffFactor, specFactor;
	float3 diffuseDirection, specularDirection; // mean light directions, length = directionality
};

// Linear view depth of the jittered primary hit, beyond the denoising range without a surface.
float ViewZ(uint2 pixel, out float3 direction)
{
	uint2 size = gFrame.frame.xy;
	uint index = pixel.y * size.x + pixel.x;
	float2 ndc = (float2(pixel) + gFrame.temporal.xy) / float2(size) * float2(2.0, -2.0) + float2(-1.0, 1.0);
	direction = normalize(gFrame.cameraForward.xyz + ndc.x * gFrame.cameraRight.xyz + ndc.y * gFrame.cameraUp.xyz);
	float3 axis = normalize(cross(gFrame.cameraUp.xyz, gFrame.cameraRight.xyz));
	bool valid = gAccum[gNrd.control.x + index * NRD_STRIDE + 2u].w > 0.0;
	return valid ? gAccum[index * 3u + 1u].w * dot(direction, axis) : gNrd.hitDistance.w * 2.0;
}

NrdSurface LoadSurface(uint2 pixel)
{
	uint2 size = gFrame.frame.xy;
	uint index = pixel.y * size.x + pixel.x, base = index * 3u, r = gNrd.control.x + index * NRD_STRIDE;
	float4 a = gAccum[r], b = gAccum[r + 1u], c = gAccum[r + 2u];
	NrdSurface s;
	s.valid = c.w > 0.0;
	s.diffuse = a.xyz; s.hitDistance = a.w;
	s.specular = b.xyz;
	float metalness = floor(max(b.w, 0.0) * 0.5);
	s.roughness = saturate((max(b.w, 0.0) - 2.0 * metalness) / 0.99);
	metalness /= 255.0;
	s.bypass = c.xyz;
	s.normal = gAccum[base + 2u].xyz;
	s.diffuseDirection = gAccum[r + 3u].xyz;
	s.specularDirection = gAccum[r + 4u].xyz;
	float3 albedo = gAccum[base + 1u].xyz;
	// Same jittered camera ray as the primary hit; distance is along the normalized ray.
	float3 direction;
	s.viewZ = ViewZ(pixel, direction);
	s.view = -direction;
	// Approximate metallic workflow factors; (de)modulation only needs to be consistent and smooth.
	float3 f0 = lerp(float3(0.04, 0.04, 0.04), albedo, metalness);
	NRD_MaterialFactors(s.normal, s.view, albedo * (1.0 - metalness), f0, s.roughness, s.diffFactor, s.specFactor);
	return s;
}

[shader("compute")]
[numthreads(8, 8, 1)]
void Prepare(uint3 tid : SV_DispatchThreadID)
{
	uint2 pixel = tid.xy, size = gFrame.frame.xy;
	if (any(pixel >= size)) return;
	NrdSurface s = LoadSurface(pixel);
	uint index = pixel.y * size.x + pixel.x;
	float4 motion = gMotion[index * 2u];
	// Pixels; NRD scales by 1 / size. Previous minus current, matching NRD's pixelUv + mv.
	gOutMv[pixel] = float4(motion.w != 0.0 ? motion.xy : float2(0.0), 0.0, 0.0);
	gOutViewZ[pixel] = s.viewZ;
	gOutNormalRoughness[pixel] = NRD_FrontEnd_PackNormalAndRoughness(s.valid ? s.normal : float3(0.0, 0.0, 1.0), s.roughness, 0.0);
	float3 params = gNrd.hitDistance.xyz;
	float diffHit = REBLUR_FrontEnd_GetNormHitDist(s.hitDistance, s.viewZ, params, 1.0);
	float specHit = REBLUR_FrontEnd_GetNormHitDist(s.hitDistance, s.viewZ, params, s.roughness);
	float3 diffuse = s.valid ? s.diffuse / s.diffFactor : float3(0.0), specular = s.valid ? s.specular / s.specFactor : float3(0.0);
#if NRD_PASS_SH
	float4 diffSh1, specSh1;
	gOutDiff[pixel] = REBLUR_FrontEnd_PackSh(diffuse, diffHit, s.diffuseDirection, diffSh1, true);
	gOutSpec[pixel] = REBLUR_FrontEnd_PackSh(specular, specHit, s.specularDirection, specSh1, true);
	gOutDiffSh1[pixel] = diffSh1;
	gOutSpecSh1[pixel] = specSh1;
#else
	gOutDiff[pixel] = REBLUR_FrontEnd_PackRadianceAndNormHitDist(diffuse, diffHit, true);
	gOutSpec[pixel] = REBLUR_FrontEnd_PackRadianceAndNormHitDist(specular, specHit, true);
#endif
}

#if NRD_PASS_SH
// NRD_SG_ReJitter with the four direct neighbors; edges clamp to the center pixel.
float2 ReJitter(uint2 pixel, NrdSurface s, NRD_SG diffSg, NRD_SG specSg)
{
	int2 size = int2(gFrame.frame.xy);
	const int2 offsets[4] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1) };
	float Z[4]; float3 N[4];
	for (int i = 0; i < 4; i++)
	{
		uint2 p = uint2(clamp(int2(pixel) + offsets[i], int2(0), size - 1));
		float3 unused;
		Z[i] = ViewZ(p, unused);
		N[i] = gAccum[(p.y * uint(size.x) + p.x) * 3u + 2u].xyz;
	}
	return NRD_SG_ReJitter(diffSg, specSg, s.view, s.roughness, s.viewZ, Z[0], Z[1], Z[2], Z[3], s.normal, N[0], N[1], N[2], N[3]);
}
#endif

// Writes the TAA input layout: radiance, then the unchanged albedo/distance and normal/instance guides.
[shader("compute")]
[numthreads(8, 8, 1)]
void Composite(uint3 tid : SV_DispatchThreadID)
{
	uint2 pixel = tid.xy, size = gFrame.frame.xy;
	if (any(pixel >= size)) return;
	NrdSurface s = LoadSurface(pixel);
	uint base = (pixel.y * size.x + pixel.x) * 3u;
	float3 result = gAccum[base].xyz;
	uint debug = gNrd.control.y;
	if (s.valid)
	{
		float3 diffuse = s.diffuse, specular = s.specular;
		if (debug != 1u && gNrd.control.z != 0u)
		{
#if NRD_PASS_SH
			NRD_SG diffSg = REBLUR_BackEnd_UnpackSh(gDiff.Load(int3(pixel, 0)), gDiffSh1.Load(int3(pixel, 0)).xyz);
			NRD_SG specSg = REBLUR_BackEnd_UnpackSh(gSpec.Load(int3(pixel, 0)), gSpecSh1.Load(int3(pixel, 0)).xyz);
			// Macro details from the SG resolve, micro details / per-frame jitter from re-jittering.
			float2 scale = gNrd.control.w != 0u ? ReJitter(pixel, s, diffSg, specSg) : float2(1.0);
			float3 d = NRD_SG_ResolveDiffuse(diffSg, s.normal, s.view, s.roughness) * scale.x * s.diffFactor;
			float3 sp = NRD_SG_ResolveSpecular(specSg, s.normal, s.view, s.roughness) * scale.y * s.specFactor;
			if (debug == 5u) { gComposite[base] = float4(float3(saturate(0.5 + 0.5 * log2(scale)), 0.5) * gFrame.envParams.z, 1.0); gComposite[base + 1u] = gAccum[base + 1u]; gComposite[base + 2u] = gAccum[base + 2u]; return; }
#else
			float3 d = REBLUR_BackEnd_UnpackRadianceAndNormHitDist(gDiff.Load(int3(pixel, 0))).xyz * s.diffFactor;
			float3 sp = REBLUR_BackEnd_UnpackRadianceAndNormHitDist(gSpec.Load(int3(pixel, 0))).xyz * s.specFactor;
#endif
			if (all(isfinite(d)) && all(isfinite(sp))) { diffuse = max(d, 0.0); specular = max(sp, 0.0); }
		}
		result = debug == 2u ? diffuse : debug == 3u ? specular : s.bypass + diffuse + specular;
	}
	else if (debug == 2u || debug == 3u) result = float3(0.0);
	// 5 (SH only, surfaces): re-jitter scale, log2 mapped to [0, 1]: R diffuse, G specular, 0.5 = unchanged.
	if (debug == 5u) result = float3(0.5, 0.5, 0.5) * gFrame.envParams.z;
	if (debug == 4u) result = float3(saturate(s.hitDistance / max(s.viewZ, 1e-3)), s.roughness, s.valid ? 1.0 : 0.0) * gFrame.envParams.z;
	gComposite[base] = float4(result, 1.0);
	gComposite[base + 1u] = gAccum[base + 1u];
	gComposite[base + 2u] = gAccum[base + 2u];
}
