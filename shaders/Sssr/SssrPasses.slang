// FidelityFX SSSR + reflection denoiser passes and Veach's input/output passes (docs/Sssr.md). Built by
// scripts/build-sssr.mjs: one WGSL module per SSSR_PASS value, entry point main. The FidelityFX passes
// define the bind flags of FidelityFX's DX12 pass wrappers (ThirdParty/FidelityFX/hlsl) and include the
// unmodified FidelityFX headers with Veach's callbacks (SssrCallbacks.hlsli).
#define SSSR_PASS_PREPARE 1
#define SSSR_PASS_DOWNSAMPLE 2
#define SSSR_PASS_CLASSIFY_TILES 3
#define SSSR_PASS_PREPARE_BLUE_NOISE 4
#define SSSR_PASS_PREPARE_INDIRECT_ARGS 5
#define SSSR_PASS_INTERSECT 6
#define SSSR_PASS_REPROJECT 7
#define SSSR_PASS_PREFILTER 8
#define SSSR_PASS_RESOLVE_TEMPORAL 9
#define SSSR_PASS_APPLY 10
#define SSSR_PASS_ENVIRONMENT_DOWNSAMPLE 11

#if SSSR_PASS == SSSR_PASS_CLASSIFY_TILES
#define SSSR_BIND_SRV_INPUT_NORMAL 1
#define SSSR_BIND_SRV_INPUT_MATERIAL_PARAMETERS 1
#define SSSR_BIND_SRV_INPUT_ENVIRONMENT_MAP 1
#define SSSR_BIND_SRV_DEPTH_HIERARCHY 1
#define SSSR_BIND_SRV_VARIANCE 1
#define SSSR_BIND_UAV_RADIANCE 1
#define SSSR_BIND_UAV_RAY_LIST 1
#define SSSR_BIND_UAV_DENOISER_TILE_LIST 1
#define SSSR_BIND_UAV_RAY_COUNTER 1
#define SSSR_BIND_UAV_EXTRACTED_ROUGHNESS 1
#define SSSR_BIND_CB_SSSR 1
#include "SssrCallbacks.hlsli"
#include "sssr/ffx_sssr_classify_tiles.h"

FFX_PREFER_WAVE64
[numthreads(64, 1, 1)]
void main(FfxUInt32 LocalThreadIndex : SV_GroupIndex, FfxUInt32x3 WorkGroupId : SV_GroupID)
{
	FfxUInt32x2 group_thread_id = ffxRemapForWaveReduction(LocalThreadIndex);
	FfxUInt32x2 dispatch_thread_id = WorkGroupId.xy * 8 + group_thread_id;
	FfxFloat32 roughness = LoadRoughnessFromMaterialParametersInput(FfxInt32x3(dispatch_thread_id, 0));
	ClassifyTiles(dispatch_thread_id, group_thread_id, roughness);
	// Extract only the channel containing the roughness to avoid loading all 4 channels in the follow up passes.
	StoreExtractedRoughness(dispatch_thread_id, roughness);
}

#elif SSSR_PASS == SSSR_PASS_PREPARE_BLUE_NOISE
#define SSSR_BIND_SRV_SOBOL_BUFFER 1
#define SSSR_BIND_SRV_SCRAMBLING_TILE_BUFFER 1
#define SSSR_BIND_UAV_BLUE_NOISE_TEXTURE 1
#define SSSR_BIND_CB_SSSR 1
#include "SssrCallbacks.hlsli"
#include "sssr/ffx_sssr_prepare_blue_noise_texture.h"

FFX_PREFER_WAVE64
[numthreads(8, 8, 1)]
void main(FfxInt32x2 DispatchThreadId : SV_DispatchThreadID)
{
	PrepareBlueNoiseTexture(DispatchThreadId);
}

#elif SSSR_PASS == SSSR_PASS_PREPARE_INDIRECT_ARGS
#define SSSR_BIND_UAV_RAY_COUNTER 1
#define SSSR_BIND_UAV_INTERSECTION_PASS_INDIRECT_ARGS 1
#define SSSR_BIND_CB_SSSR 1
#include "SssrCallbacks.hlsli"
#include "sssr/ffx_sssr_prepare_indirect_args.h"

FFX_PREFER_WAVE64
[numthreads(1, 1, 1)]
void main()
{
	PrepareIndirectArgs();
}

#elif SSSR_PASS == SSSR_PASS_INTERSECT
#define SSSR_BIND_SRV_INPUT_COLOR 1
#define SSSR_BIND_SRV_INPUT_NORMAL 1
#define SSSR_BIND_SRV_INPUT_ENVIRONMENT_MAP 1
#define SSSR_BIND_SRV_DEPTH_HIERARCHY 1
#define SSSR_BIND_SRV_EXTRACTED_ROUGHNESS 1
#define SSSR_BIND_SRV_BLUE_NOISE_TEXTURE 1
#define SSSR_BIND_UAV_RADIANCE 1
#define SSSR_BIND_UAV_RAY_LIST 1
#define SSSR_BIND_UAV_RAY_COUNTER 1
#define SSSR_BIND_CB_SSSR 1
#include "SssrCallbacks.hlsli"
#include "sssr/ffx_sssr_intersect.h"

FFX_PREFER_WAVE64
[numthreads(8, 8, 1)]
void main(FfxUInt32 LocalThreadIndex : SV_GroupIndex, FfxUInt32 WorkGroupId : SV_GroupID)
{
	Intersect(LocalThreadIndex, WorkGroupId);
}

#elif SSSR_PASS == SSSR_PASS_REPROJECT
#define DENOISER_BIND_SRV_INPUT_DEPTH_HIERARCHY 1
#define DENOISER_BIND_SRV_INPUT_MOTION_VECTORS 1
#define DENOISER_BIND_SRV_INPUT_NORMAL 1
#define DENOISER_BIND_SRV_RADIANCE 1
#define DENOISER_BIND_SRV_RADIANCE_HISTORY 1
#define DENOISER_BIND_SRV_VARIANCE 1
#define DENOISER_BIND_SRV_SAMPLE_COUNT 1
#define DENOISER_BIND_SRV_EXTRACTED_ROUGHNESS 1
#define DENOISER_BIND_SRV_DEPTH_HISTORY 1
#define DENOISER_BIND_SRV_NORMAL_HISTORY 1
#define DENOISER_BIND_SRV_ROUGHNESS_HISTORY 1
#define DENOISER_BIND_UAV_VARIANCE 1
#define DENOISER_BIND_UAV_SAMPLE_COUNT 1
#define DENOISER_BIND_UAV_AVERAGE_RADIANCE 1
#define DENOISER_BIND_UAV_DENOISER_TILE_LIST 1
#define DENOISER_BIND_UAV_REPROJECTED_RADIANCE 1
#define DENOISER_BIND_CB_DENOISER 1
#include "SssrCallbacks.hlsli"
#include "denoiser/ffx_denoiser_reflections_reproject.h"

FFX_PREFER_WAVE64
[numthreads(8, 8, 1)]
void main(FfxUInt32 LocalThreadIndex : SV_GroupIndex, FfxUInt32 WorkGroupId : SV_GroupID, FfxInt32x2 GroupThreadId : SV_GroupThreadID)
{
	Reproject(LocalThreadIndex, WorkGroupId, GroupThreadId);
}

#elif SSSR_PASS == SSSR_PASS_PREFILTER
#define DENOISER_BIND_SRV_INPUT_DEPTH_HIERARCHY 1
#define DENOISER_BIND_SRV_INPUT_NORMAL 1
#define DENOISER_BIND_SRV_RADIANCE 1
#define DENOISER_BIND_SRV_VARIANCE 1
#define DENOISER_BIND_SRV_AVERAGE_RADIANCE 1
#define DENOISER_BIND_SRV_EXTRACTED_ROUGHNESS 1
#define DENOISER_BIND_UAV_RADIANCE 1
#define DENOISER_BIND_UAV_VARIANCE 1
#define DENOISER_BIND_UAV_DENOISER_TILE_LIST 1
#define DENOISER_BIND_CB_DENOISER 1
#include "SssrCallbacks.hlsli"
#include "denoiser/ffx_denoiser_reflections_prefilter.h"

FFX_PREFER_WAVE64
[numthreads(8, 8, 1)]
void main(FfxUInt32 LocalThreadIndex : SV_GroupIndex, FfxUInt32 WorkGroupId : SV_GroupID, FfxInt32x2 GroupThreadId : SV_GroupThreadID)
{
	Prefilter(LocalThreadIndex, WorkGroupId, GroupThreadId);
}

#elif SSSR_PASS == SSSR_PASS_RESOLVE_TEMPORAL
#define DENOISER_BIND_SRV_RADIANCE 1
#define DENOISER_BIND_SRV_RADIANCE_HISTORY 1
#define DENOISER_BIND_SRV_VARIANCE 1
#define DENOISER_BIND_SRV_SAMPLE_COUNT 1
#define DENOISER_BIND_SRV_AVERAGE_RADIANCE 1
#define DENOISER_BIND_SRV_EXTRACTED_ROUGHNESS 1
#define DENOISER_BIND_SRV_REPROJECTED_RADIANCE 1
#define DENOISER_BIND_UAV_RADIANCE 1
#define DENOISER_BIND_UAV_VARIANCE 1
#define DENOISER_BIND_UAV_DENOISER_TILE_LIST 1
#define DENOISER_BIND_CB_DENOISER 1
#include "SssrCallbacks.hlsli"
#include "denoiser/ffx_denoiser_reflections_resolve_temporal.h"

FFX_PREFER_WAVE64
[numthreads(8, 8, 1)]
void main(FfxUInt32 LocalThreadIndex : SV_GroupIndex, FfxUInt32 WorkGroupId : SV_GroupID, FfxInt32x2 GroupThreadId : SV_GroupThreadID)
{
	ResolveTemporal(LocalThreadIndex, WorkGroupId, GroupThreadId);
}

#else
// ---- Veach passes ----
import Scene.SceneTypes;

#if SSSR_PASS == SSSR_PASS_PREPARE || SSSR_PASS == SSSR_PASS_APPLY
#define SSSR_VEACH_ACCUM 1
#endif
#if SSSR_PASS == SSSR_PASS_APPLY
#define SSSR_VEACH_COLOR 1
#define SSSR_BIND_SRV_RADIANCE 1
#endif
#include "SssrCallbacks.hlsli"

[[vk::binding(1, 0)]] ConstantBuffer<FrameUniforms> gFrame;
// Prepare: depth hierarchy mip 0 and world normals. Downsample: the next hierarchy mip.
[[vk::binding(29, 0)]] Texture2D<float> gSource; // previous mip (Downsample, EnvironmentDownsample: float4)
[[vk::binding(37, 0)]] [format("r32f")] WTexture2D<float> gOutDepth;
[[vk::binding(38, 0)]] [format("rgba16f")] WTexture2D<float4> gOutNormal;
[[vk::binding(39, 0)]] Texture2D<float4> gSourceColor;
[[vk::binding(40, 0)]] [format("rgba16f")] WTexture2D<float4> gOutColor;
[[vk::binding(9, 0)]] RWStructuredBuffer<float4> gOutput;
[[vk::binding(28, 0)]] Texture2D<float4> gBrdfLut; // split-sum GGX scale (x) and bias (y) by (N.V, perceptual roughness)
[[vk::binding(10, 0)]] SamplerState gLinearClamp;

#if defined(SSSR_VEACH_ACCUM)
// Same jittered camera ray and validity as NrdPasses.slang ViewZ.
bool PrimaryViewZ(uint2 pixel, out float viewZ, out float3 direction)
{
	uint2 size = gFrame.frame.xy;
	uint index = pixel.y * size.x + pixel.x;
	float2 ndc = (float2(pixel) + gFrame.temporal.xy) / float2(size) * float2(2.0, -2.0) + float2(-1.0, 1.0);
	direction = normalize(gFrame.cameraForward.xyz + ndc.x * gFrame.cameraRight.xyz + ndc.y * gFrame.cameraUp.xyz);
	float3 axis = normalize(cross(gFrame.cameraUp.xyz, gFrame.cameraRight.xyz));
	bool valid = gAccum[gSssr.region + index * SSSR_NRD_STRIDE + 2u].w > 0.0;
	viewZ = gAccum[index * 3u + 1u].w * dot(direction, axis);
	return valid && viewZ > 0.0;
}
#endif

#if SSSR_PASS == SSSR_PASS_PREPARE
// Inverted infinite projection: depth = near / viewZ, 0 without a surface (SssrConfig.ts sssrMatrices).
[shader("compute")]
[numthreads(8, 8, 1)]
void main(uint3 tid : SV_DispatchThreadID)
{
	uint2 pixel = tid.xy, size = gFrame.frame.xy;
	if (any(pixel >= size)) return;
	float viewZ; float3 direction;
	bool valid = PrimaryViewZ(pixel, viewZ, direction);
	gOutDepth[pixel] = valid ? gSssr.nearPlane / viewZ : 0.0;
	float3 n = gAccum[(pixel.y * size.x + pixel.x) * 3u + 2u].xyz;
	gOutNormal[pixel] = float4(valid && dot(n, n) > 0.0 ? normalize(n) : float3(0.0, 0.0, 1.0), 0.0);
}

#elif SSSR_PASS == SSSR_PASS_DOWNSAMPLE
// Closest depth (max with inverted depth) of the 2x2 footprint, plus the extra row/column of odd sizes.
[shader("compute")]
[numthreads(8, 8, 1)]
void main(uint3 tid : SV_DispatchThreadID)
{
	uint width, height, srcWidth, srcHeight;
	gOutDepth.GetDimensions(width, height);
	gSource.GetDimensions(srcWidth, srcHeight);
	uint2 pixel = tid.xy;
	if (pixel.x >= width || pixel.y >= height) return;
	uint2 last = uint2(srcWidth, srcHeight) - 1u;
	uint2 end = uint2(pixel.x == width - 1u && (srcWidth & 1u) != 0u ? 2u : 1u, pixel.y == height - 1u && (srcHeight & 1u) != 0u ? 2u : 1u);
	float depth = 0.0;
	for (uint y = 0u; y <= end.y; y++)
		for (uint x = 0u; x <= end.x; x++)
			depth = max(depth, gSource.Load(int3(int2(min(pixel * 2u + uint2(x, y), last)), 0)));
	gOutDepth[pixel] = depth;
}

#elif SSSR_PASS == SSSR_PASS_ENVIRONMENT_DOWNSAMPLE
// Box-filtered mip of the equirect environment: the 2x2 footprint, wrapping in U.
[shader("compute")]
[numthreads(8, 8, 1)]
void main(uint3 tid : SV_DispatchThreadID)
{
	uint width, height, srcWidth, srcHeight;
	gOutColor.GetDimensions(width, height);
	gSourceColor.GetDimensions(srcWidth, srcHeight);
	uint2 pixel = tid.xy;
	if (pixel.x >= width || pixel.y >= height) return;
	float4 sum = float4(0.0);
	for (uint y = 0u; y < 2u; y++)
		for (uint x = 0u; x < 2u; x++)
			sum += gSourceColor.Load(int3(int((pixel.x * 2u + x) % srcWidth), int(min(pixel.y * 2u + y, srcHeight - 1u)), 0));
	gOutColor[pixel] = sum * 0.25;
}

#elif SSSR_PASS == SSSR_PASS_APPLY
// Writes the TAA input layout: color + denoised reflections * split-sum specular, then the unchanged guides.
// The specular F0 approximation matches NrdPasses.slang LoadSurface. Debug: 1 reflections only, 2 color input only.
[shader("compute")]
[numthreads(8, 8, 1)]
void main(uint3 tid : SV_DispatchThreadID)
{
	uint2 pixel = tid.xy, size = gFrame.frame.xy;
	if (any(pixel >= size)) return;
	uint base = (pixel.y * size.x + pixel.x) * 3u, r = gSssr.region + (pixel.y * size.x + pixel.x) * SSSR_NRD_STRIDE;
	float3 color = gColor[base].xyz;
	float viewZ; float3 direction;
	float3 specular = float3(0.0);
	if (PrimaryViewZ(pixel, viewZ, direction))
	{
		float packed = max(gAccum[r + 1u].w, 0.0);
		float metalness = floor(packed * 0.5);
		float roughness = saturate((packed - 2.0 * metalness) / 0.99);
		metalness /= 255.0;
		float3 albedo = gAccum[base + 1u].xyz;
		float3 n = normalize(gAccum[base + 2u].xyz);
		float nv = saturate(dot(n, -direction));
		float2 ab = gBrdfLut.SampleLevel(gLinearClamp, float2(nv, roughness), 0.0).xy;
		float3 f0 = lerp(float3(0.04, 0.04, 0.04), albedo, metalness);
		float3 reflection = max(r_radiance.Load(int3(pixel, 0)).xyz, 0.0);
		if (all(isfinite(reflection))) specular = reflection * (f0 * ab.x + ab.y);
	}
	uint debug = gSssr.debug;
	float3 result = debug == 1u ? specular : debug == 2u ? color : color + specular;
	gOutput[base] = float4(result, 1.0);
	gOutput[base + 1u] = gAccum[base + 1u];
	gOutput[base + 2u] = gAccum[base + 2u];
}
#endif
#endif
