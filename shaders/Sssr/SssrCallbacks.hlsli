// Veach resource callbacks for the FidelityFX SSSR 1.5 and reflection denoiser 1.3 shaders (docs/Sssr.md).
// Mirrors ThirdParty/FidelityFX/gpu/{sssr/ffx_sssr,denoiser/ffx_denoiser_reflections}_callbacks_hlsl.h
// (FFX_HALF = 0 paths): a pass defines the same SSSR_BIND_* / DENOISER_BIND_* flags as FidelityFX's DX12
// pass wrapper and gets exactly those resources, at the fixed WebGPU bindings below (group 0). Differences:
// - one constant buffer serves both components;
// - material parameters come from Veach's buffers; the input color is the previous frame's linear scene color
//   (ping-pong, written by Apply) at the reprojected hit, falling back to this frame's color;
// - the ray counter is Atomic<uint> (WGSL atomics need atomic<T> storage);
// - the environment fallback is Veach's equirect environment with a box-filtered mip chain;
// - every storage texture is write-only in a core WebGPU format.
#include "ffx_core.h"
#include "WriteOnlyTexture.hlsli"

#ifndef FFX_PREFER_WAVE64
#define FFX_PREFER_WAVE64
#endif

// Constants (SssrConstants in src/render/sssr/SssrConfig.ts): FidelityFX's cbSSSR and cbDenoiserReflections
// fields, booleans as uint, plus Veach's environment rotation and NRD region offset.
struct SssrConstants
{
	float4x4 invViewProjection;
	float4x4 projection;
	float4x4 invProjection;
	float4x4 viewMatrix;
	float4x4 invView;
	float4x4 prevViewProjection;
	uint2 renderSize;
	float2 inverseRenderSize;
	float2 motionVectorScale;
	float normalsUnpackMul;
	float normalsUnpackAdd;
	uint roughnessChannel;
	uint isRoughnessPerceptual;
	float iblFactor;
	float temporalStabilityFactor;
	float depthBufferThickness;
	float roughnessThreshold;
	float varianceThreshold;
	uint frameIndex;
	uint maxTraversalIntersections;
	uint minTraversalOccupancy;
	uint mostDetailedMip;
	uint samplesPerQuad;
	uint temporalVarianceGuidedTracingEnabled;
	uint region; // float4 offset of the NRD split region in gAccum (NRD_STRIDE float4 per pixel)
	float envRotation;
	uint debug; // Apply: 0 final, 1 reflections only, 2 color input only, 3 camera reconstruction error
	float nearPlane; // Prepare: depth = nearPlane / viewZ
	float preExposure; // of this frame; the scene color history is scene-linear
	uint sceneColorHistory; // 1 when gSceneColorHistory holds the previous frame's scene color
	uint radianceCache; // 1: misses and rough surfaces fall back to the radiance cache, then the environment
	float2 jitterDelta; // current minus previous film jitter, pixels (TemporalAA.slang history addressing)
	float2 padding1;
};
[[vk::binding(0, 0)]] ConstantBuffer<SssrConstants> gSssr;

FfxFloat32Mat4 InvViewProjection() { return gSssr.invViewProjection; }
FfxFloat32Mat4 Projection() { return gSssr.projection; }
FfxFloat32Mat4 InvProjection() { return gSssr.invProjection; }
FfxFloat32Mat4 ViewMatrix() { return gSssr.viewMatrix; }
FfxFloat32Mat4 InvView() { return gSssr.invView; }
FfxFloat32Mat4 PrevViewProjection() { return gSssr.prevViewProjection; }
FfxFloat32 NormalsUnpackMul() { return gSssr.normalsUnpackMul; }
FfxFloat32 NormalsUnpackAdd() { return gSssr.normalsUnpackAdd; }
FfxUInt32 RoughnessChannel() { return gSssr.roughnessChannel; }
FfxBoolean IsRoughnessPerceptual() { return gSssr.isRoughnessPerceptual != 0u; }
FfxUInt32x2 RenderSize() { return gSssr.renderSize; }
FfxFloat32x2 InverseRenderSize() { return gSssr.inverseRenderSize; }
FfxFloat32x2 MotionVectorScale() { return gSssr.motionVectorScale; }
FfxFloat32 IBLFactor() { return gSssr.iblFactor; }
FfxFloat32 TemporalStabilityFactor() { return gSssr.temporalStabilityFactor; }
FfxFloat32 DepthBufferThickness() { return gSssr.depthBufferThickness; }
FfxFloat32 RoughnessThreshold() { return gSssr.roughnessThreshold; }
FfxFloat32 VarianceThreshold() { return gSssr.varianceThreshold; }
FfxUInt32 FrameIndex() { return gSssr.frameIndex; }
FfxUInt32 MaxTraversalIntersections() { return gSssr.maxTraversalIntersections; }
FfxUInt32 MinTraversalOccupancy() { return gSssr.minTraversalOccupancy; }
FfxUInt32 MostDetailedMip() { return gSssr.mostDetailedMip; }
FfxUInt32 SamplesPerQuad() { return gSssr.samplesPerQuad; }
FfxBoolean TemporalVarianceGuidedTracingEnabled() { return gSssr.temporalVarianceGuidedTracingEnabled != 0u; }

static const uint SSSR_NRD_STRIDE = 5u; // float4 per pixel in the NRD region, see Wavefront.slang

// Buffers.
#if defined(SSSR_BIND_SRV_INPUT_MATERIAL_PARAMETERS) || defined(SSSR_VEACH_ACCUM)
[[vk::binding(2, 0)]] StructuredBuffer<float4> gAccum; // accumulation image (three float4 per pixel) and NRD region
#endif
#if defined(DENOISER_BIND_SRV_INPUT_MOTION_VECTORS) || defined(SSSR_BIND_SRV_INPUT_COLOR)
[[vk::binding(3, 0)]] StructuredBuffer<float4> gMotion; // TAA motion: two float4 per pixel, pixels, previous minus current
#endif
#if defined(SSSR_BIND_SRV_INPUT_COLOR) || defined(SSSR_VEACH_COLOR)
[[vk::binding(4, 0)]] StructuredBuffer<float4> gColor; // NRD composite: three float4 per pixel, radiance first
#endif
#if defined(SSSR_BIND_SRV_INPUT_COLOR)
[[vk::binding(41, 0)]] Texture2D<FfxFloat32x4> gSceneColorHistory; // previous frame's scene color / pre-exposure (Apply)
[[vk::binding(10, 0)]] SamplerState gSceneColorSampler; // linear, clamp
#endif
#if defined(SSSR_BIND_UAV_RAY_LIST)
[[vk::binding(5, 0)]] RWStructuredBuffer<FfxUInt32> rw_ray_list;
#endif
#if defined(SSSR_BIND_UAV_DENOISER_TILE_LIST) || defined(DENOISER_BIND_UAV_DENOISER_TILE_LIST)
[[vk::binding(6, 0)]] RWStructuredBuffer<FfxUInt32> rw_denoiser_tile_list;
#endif
#if defined(SSSR_BIND_UAV_RAY_COUNTER)
[[vk::binding(7, 0)]] RWStructuredBuffer<Atomic<FfxUInt32> > rw_ray_counter;
#endif
#if defined(SSSR_BIND_UAV_INTERSECTION_PASS_INDIRECT_ARGS)
[[vk::binding(8, 0)]] RWStructuredBuffer<FfxUInt32> rw_intersection_pass_indirect_args;
#endif

// Samplers: FidelityFX's static samplers (denoiser: linear, clamp; environment: linear, wrap U for the equirect map).
#if defined(DENOISER_BIND_CB_DENOISER)
[[vk::binding(10, 0)]] SamplerState s_LinearSampler;
#endif
#if defined(SSSR_BIND_SRV_INPUT_ENVIRONMENT_MAP)
[[vk::binding(11, 0)]] SamplerState s_EnvironmentMapSampler;
#endif

// Sampled textures.
#if defined(SSSR_BIND_SRV_DEPTH_HIERARCHY) || defined(DENOISER_BIND_SRV_INPUT_DEPTH_HIERARCHY)
[[vk::binding(12, 0)]] Texture2D<FfxFloat32> r_depth_hierarchy;
#endif
#if defined(SSSR_BIND_SRV_INPUT_NORMAL) || defined(DENOISER_BIND_SRV_INPUT_NORMAL)
[[vk::binding(13, 0)]] Texture2D<FfxFloat32x4> r_input_normal;
#endif
#if defined(SSSR_BIND_SRV_RADIANCE) || defined(DENOISER_BIND_SRV_RADIANCE)
[[vk::binding(14, 0)]] Texture2D<FfxFloat32x4> r_radiance;
#endif
#if defined(SSSR_BIND_SRV_RADIANCE_HISTORY) || defined(DENOISER_BIND_SRV_RADIANCE_HISTORY)
[[vk::binding(15, 0)]] Texture2D<FfxFloat32x4> r_radiance_history;
#endif
#if defined(SSSR_BIND_SRV_VARIANCE) || defined(DENOISER_BIND_SRV_VARIANCE)
[[vk::binding(16, 0)]] Texture2D<FfxFloat32> r_variance;
#endif
#if defined(SSSR_BIND_SRV_EXTRACTED_ROUGHNESS) || defined(DENOISER_BIND_SRV_EXTRACTED_ROUGHNESS)
[[vk::binding(17, 0)]] Texture2D<FfxFloat32> r_extracted_roughness;
#endif
#if defined(SSSR_BIND_SRV_SOBOL_BUFFER)
[[vk::binding(18, 0)]] Texture2D<FfxUInt32> r_sobol_buffer;
#endif
#if defined(SSSR_BIND_SRV_SCRAMBLING_TILE_BUFFER)
[[vk::binding(19, 0)]] Texture2D<FfxUInt32> r_scrambling_tile_buffer;
#endif
#if defined(SSSR_BIND_SRV_BLUE_NOISE_TEXTURE)
[[vk::binding(20, 0)]] Texture2D<FfxFloat32x4> r_blue_noise_texture;
#endif
#if defined(DENOISER_BIND_SRV_SAMPLE_COUNT)
[[vk::binding(21, 0)]] Texture2D<FfxFloat32> r_sample_count;
#endif
#if defined(DENOISER_BIND_SRV_AVERAGE_RADIANCE)
[[vk::binding(22, 0)]] Texture2D<FfxFloat32x4> r_average_radiance;
#endif
#if defined(DENOISER_BIND_SRV_REPROJECTED_RADIANCE)
[[vk::binding(23, 0)]] Texture2D<FfxFloat32x4> r_reprojected_radiance;
#endif
#if defined(DENOISER_BIND_SRV_DEPTH_HISTORY)
[[vk::binding(24, 0)]] Texture2D<FfxFloat32> r_depth_history;
#endif
#if defined(DENOISER_BIND_SRV_NORMAL_HISTORY)
[[vk::binding(25, 0)]] Texture2D<FfxFloat32x4> r_normal_history;
#endif
#if defined(DENOISER_BIND_SRV_ROUGHNESS_HISTORY)
[[vk::binding(26, 0)]] Texture2D<FfxFloat32> r_roughness_history;
#endif
#if defined(SSSR_BIND_SRV_INPUT_ENVIRONMENT_MAP)
[[vk::binding(27, 0)]] Texture2D<FfxFloat32x4> r_input_environment_map; // equirect, box-filtered mips
#endif

// Storage textures (write-only; formats as SssrReflections creates them).
#if defined(SSSR_BIND_UAV_RADIANCE) || defined(DENOISER_BIND_UAV_RADIANCE)
[[vk::binding(30, 0)]] [format("rgba16f")] WTexture2D<FfxFloat32x4> rw_radiance;
#endif
#if defined(SSSR_BIND_UAV_VARIANCE) || defined(DENOISER_BIND_UAV_VARIANCE)
[[vk::binding(31, 0)]] [format("r32f")] WTexture2D<FfxFloat32> rw_variance;
#endif
#if defined(SSSR_BIND_UAV_EXTRACTED_ROUGHNESS)
[[vk::binding(32, 0)]] [format("r32f")] WTexture2D<FfxFloat32> rw_extracted_roughness;
#endif
#if defined(SSSR_BIND_UAV_BLUE_NOISE_TEXTURE)
[[vk::binding(33, 0)]] [format("rgba8")] WTexture2D<FfxFloat32x4> rw_blue_noise_texture;
#endif
#if defined(DENOISER_BIND_UAV_SAMPLE_COUNT)
[[vk::binding(34, 0)]] [format("r32f")] WTexture2D<FfxFloat32> rw_sample_count;
#endif
#if defined(DENOISER_BIND_UAV_AVERAGE_RADIANCE)
[[vk::binding(35, 0)]] [format("rgba16f")] WTexture2D<FfxFloat32x4> rw_average_radiance;
#endif
#if defined(DENOISER_BIND_UAV_REPROJECTED_RADIANCE)
[[vk::binding(36, 0)]] [format("rgba16f")] WTexture2D<FfxFloat32x4> rw_reprojected_radiance;
#endif

// ---- SSSR callbacks ----

#if defined(SSSR_BIND_SRV_INPUT_NORMAL)
FfxFloat32x3 FFX_SSSR_LoadWorldSpaceNormal(FfxInt32x2 pixel_coordinate)
{
	return normalize(NormalsUnpackMul() * r_input_normal.Load(FfxInt32x3(pixel_coordinate, 0)).xyz + NormalsUnpackAdd());
}
#endif

#if defined(SSSR_BIND_SRV_DEPTH_HIERARCHY)
FfxFloat32 FFX_SSSR_LoadDepth(FfxInt32x2 pixel_coordinate, FfxInt32 mip)
{
	return r_depth_hierarchy.Load(FfxInt32x3(pixel_coordinate, mip));
}
#endif

#if defined(SSSR_BIND_SRV_BLUE_NOISE_TEXTURE)
FfxFloat32x2 FFX_SSSR_SampleRandomVector2D(FfxUInt32x2 pixel)
{
	return r_blue_noise_texture.Load(FfxInt32x3(pixel.xy % 128, 0)).xy;
}
#endif

#if defined(SSSR_BIND_SRV_INPUT_ENVIRONMENT_MAP)
// FidelityFX's mip selection (perceptual roughness * max mip) on the equirect map, rotated like EvalEnvironment.
FfxFloat32x3 FFX_SSSR_SampleEnvironmentMap(FfxFloat32x3 direction, FfxFloat32 preceptualRoughness)
{
	FfxFloat32 Width; FfxFloat32 Height; FfxFloat32 Levels;
	r_input_environment_map.GetDimensions(0, Width, Height, Levels);
	FfxFloat32 mip = clamp(preceptualRoughness * (Levels - 1.0), 0.0, Levels - 1.0);
	FfxFloat32 c = cos(-gSssr.envRotation), s = sin(-gSssr.envRotation);
	FfxFloat32x3 d = normalize(FfxFloat32x3(c * direction.x + s * direction.z, direction.y, -s * direction.x + c * direction.z));
	// DirectionToEquirectUV (Common/Math.slang); the sampler repeats U.
	const FfxFloat32 INV_PI = 0.31830988618379067;
	FfxFloat32 azimuth = abs(d.y) < 1.0 ? atan2(d.z, d.x) : 0.0;
	FfxFloat32x2 uv = FfxFloat32x2(azimuth * (0.5 * INV_PI) - 0.25, 0.5 - asin(clamp(d.y, -1.0, 1.0)) * INV_PI);
	return r_input_environment_map.SampleLevel(s_EnvironmentMapSampler, uv, mip).xyz * IBLFactor();
}

// Radiance cache lookups (shaders/RadianceCache, docs/RadianceCache.md) for the environment fallback.
#define RADIANCE_CACHE_GROUP 0
#define RADIANCE_CACHE_BINDING_CONSTANTS 43
#define RADIANCE_CACHE_BINDING_PROBES 44
#define RADIANCE_CACHE_PROBES_RW 0
#include "../RadianceCache/RadianceCacheCommon.hlsli"

// The fallback of a reflection ray that leaves the screen (or of a surface too rough to trace): incoming radiance at
// the pixel's surface from the radiance cache, else the environment. screenUv is FidelityFX's (uv, depth) of the pixel.
FfxFloat32x3 FFX_SSSR_SampleFallback(FfxInt32x2 pixel, FfxFloat32x3 screenUv, FfxFloat32x3 direction, FfxFloat32 perceptualRoughness)
{
	if (gSssr.radianceCache != 0u)
	{
		FfxFloat32x4 world = FFX_MATRIX_MULTIPLY(InvViewProjection(), FfxFloat32x4(screenUv.x * 2.0 - 1.0, 1.0 - screenUv.y * 2.0, screenUv.z, 1.0));
		FfxFloat32x3 radiance;
		if (RadianceCacheSample(world.xyz / world.w, FFX_SSSR_LoadWorldSpaceNormal(pixel), normalize(direction), radiance))
			return radiance * gSssr.preExposure;
	}
	return FFX_SSSR_SampleEnvironmentMap(direction, perceptualRoughness);
}
#endif

#if defined(SSSR_BIND_UAV_RAY_COUNTER)
void IncrementRayCounter(FfxUInt32 value, FFX_PARAMETER_OUT FfxUInt32 original_value)
{
	original_value = rw_ray_counter[0].add(value);
}

void IncrementDenoiserTileCounter(FFX_PARAMETER_OUT FfxUInt32 original_value)
{
	original_value = rw_ray_counter[2].add(1u);
}
#endif

FfxUInt32 PackRayCoords(FfxUInt32x2 ray_coord, FfxBoolean copy_horizontal, FfxBoolean copy_vertical, FfxBoolean copy_diagonal)
{
	FfxUInt32 ray_x_15bit = ray_coord.x & 0x7fffu;
	FfxUInt32 ray_y_14bit = ray_coord.y & 0x3fffu;
	FfxUInt32 copy_horizontal_1bit = copy_horizontal ? 1u : 0u;
	FfxUInt32 copy_vertical_1bit = copy_vertical ? 1u : 0u;
	FfxUInt32 copy_diagonal_1bit = copy_diagonal ? 1u : 0u;
	return (copy_diagonal_1bit << 31) | (copy_vertical_1bit << 30) | (copy_horizontal_1bit << 29) | (ray_y_14bit << 15) | (ray_x_15bit << 0);
}

#if defined(SSSR_BIND_UAV_RAY_LIST)
void StoreRay(FfxInt32 index, FfxUInt32x2 ray_coord, FfxBoolean copy_horizontal, FfxBoolean copy_vertical, FfxBoolean copy_diagonal)
{
	rw_ray_list[index] = PackRayCoords(ray_coord, copy_horizontal, copy_vertical, copy_diagonal);
}
#endif

#if defined(SSSR_BIND_UAV_DENOISER_TILE_LIST)
void StoreDenoiserTile(FfxInt32 index, FfxUInt32x2 tile_coord)
{
	rw_denoiser_tile_list[index] = ((tile_coord.y & 0xffffu) << 16) | ((tile_coord.x & 0xffffu) << 0);
}
#endif

#if defined(SSSR_BIND_SRV_DEPTH_HIERARCHY)
FfxBoolean IsReflectiveSurface(FfxInt32x2 pixel_coordinate, FfxFloat32 roughness)
{
#if FFX_SSSR_OPTION_INVERTED_DEPTH
	const FfxFloat32 far_plane = 0.0f;
	return r_depth_hierarchy.Load(FfxInt32x3(pixel_coordinate, 0)) > far_plane;
#else
	const FfxFloat32 far_plane = 1.0f;
	return r_depth_hierarchy.Load(FfxInt32x3(pixel_coordinate, 0)) < far_plane;
#endif
}
#endif

#if defined(SSSR_BIND_UAV_EXTRACTED_ROUGHNESS)
void StoreExtractedRoughness(FfxUInt32x2 coordinate, FfxFloat32 roughness)
{
	rw_extracted_roughness[coordinate] = roughness;
}
#endif

#if defined(SSSR_BIND_SRV_INPUT_MATERIAL_PARAMETERS)
// Perceptual roughness of the primary surface from the NRD region (NrdPackSurface: roughness * 0.99 + 2 * metalness8).
FfxFloat32 LoadRoughnessFromMaterialParametersInput(FfxUInt32x3 coordinate)
{
	FfxUInt32x2 size = RenderSize();
	if (any(coordinate.xy >= size)) return 1.0;
	FfxUInt32 r = gSssr.region + (coordinate.y * size.x + coordinate.x) * SSSR_NRD_STRIDE;
	FfxFloat32 packed = max(gAccum[r + 1u].w, 0.0);
	FfxFloat32 rawRoughness = saturate((packed - 2.0 * floor(packed * 0.5)) / 0.99);
	if (IsRoughnessPerceptual())
	{
		rawRoughness *= rawRoughness;
	}
	return rawRoughness;
}
#endif

#if defined(SSSR_BIND_UAV_RAY_COUNTER)
FfxBoolean IsRayIndexValid(FfxUInt32 ray_index)
{
	return ray_index < rw_ray_counter[1].load();
}
#endif

#if defined(SSSR_BIND_UAV_RAY_LIST)
FfxUInt32 GetRaylist(FfxUInt32 ray_index)
{
	return rw_ray_list[ray_index];
}
#endif

#if defined(SSSR_BIND_UAV_BLUE_NOISE_TEXTURE)
void FFX_SSSR_StoreBlueNoiseSample(FfxUInt32x2 coordinate, FfxFloat32x2 blue_noise_sample)
{
	rw_blue_noise_texture[coordinate] = FfxFloat32x4(blue_noise_sample, 0.0, 0.0);
}
#endif

#if defined(SSSR_BIND_SRV_VARIANCE)
FfxFloat32 FFX_SSSR_LoadVarianceHistory(FfxInt32x3 coordinate)
{
	return r_variance.Load(coordinate).x;
}
#endif

#if defined(SSSR_BIND_UAV_RADIANCE)
void FFX_SSSR_StoreRadiance(FfxUInt32x2 coordinate, FfxFloat32x4 radiance)
{
	rw_radiance[coordinate] = radiance;
}
#endif

#if defined(SSSR_BIND_SRV_SOBOL_BUFFER)
FfxUInt32 FFX_SSSR_GetSobolSample(FfxUInt32x3 coordinate)
{
	return r_sobol_buffer.Load(FfxInt32x3(coordinate));
}
#endif

#if defined(SSSR_BIND_SRV_SCRAMBLING_TILE_BUFFER)
FfxUInt32 FFX_SSSR_GetScramblingTile(FfxUInt32x3 coordinate)
{
	return r_scrambling_tile_buffer.Load(FfxInt32x3(coordinate));
}
#endif

#if defined(SSSR_BIND_UAV_INTERSECTION_PASS_INDIRECT_ARGS)
void FFX_SSSR_WriteIntersectIndirectArgs(FfxUInt32 index, FfxUInt32 data)
{
	rw_intersection_pass_indirect_args[index] = data;
}
#endif

#if defined(SSSR_BIND_UAV_RAY_COUNTER)
void FFX_SSSR_WriteRayCounter(FfxUInt32 index, FfxUInt32 data)
{
	rw_ray_counter[index].store(data);
}

FfxUInt32 FFX_SSSR_GetRayCounter(FfxUInt32 index)
{
	return rw_ray_counter[index].load();
}
#endif

#if defined(SSSR_BIND_SRV_INPUT_COLOR)
// Lit color at a hit: the previous frame's final scene color (reflections included, so they bounce) at the
// reprojected pixel, addressed like TAA history; this frame's color (bypass + denoised diffuse) without history.
FfxFloat32x3 FFX_SSSR_LoadInputColor(FfxInt32x3 coordinate)
{
	FfxUInt32x2 size = RenderSize();
	FfxUInt32x2 p = FfxUInt32x2(clamp(coordinate.xy, FfxInt32x2(0, 0), FfxInt32x2(size) - 1));
	uint index = p.y * size.x + p.x;
	float4 motion = gMotion[index * 2u];
	if (gSssr.sceneColorHistory != 0u && motion.w != 0.0)
	{
		FfxFloat32x2 previous = FfxFloat32x2(p) + motion.xy + gSssr.jitterDelta;
		if (all(previous >= -0.5) && all(previous <= FfxFloat32x2(size) - 0.5))
			return gSceneColorHistory.SampleLevel(gSceneColorSampler, (previous + 0.5) * InverseRenderSize(), 0.0).xyz * gSssr.preExposure;
	}
	return gColor[index * 3u].xyz;
}
#endif

#if defined(SSSR_BIND_SRV_EXTRACTED_ROUGHNESS)
FfxFloat32 FFX_SSSR_LoadExtractedRoughness(FfxInt32x3 coordinate)
{
	return r_extracted_roughness.Load(coordinate).x;
}
#endif

// ---- Reflection denoiser callbacks ----

#if defined(DENOISER_BIND_SRV_RADIANCE)
FfxFloat32x3 LoadRadiance(FfxInt32x3 coordinate)
{
	return r_radiance.Load(coordinate).xyz;
}
#endif

#if defined(DENOISER_BIND_SRV_VARIANCE)
FfxFloat32 LoadVariance(FfxInt32x3 coordinate)
{
	return r_variance.Load(coordinate).x;
}
#endif

#if defined(DENOISER_BIND_SRV_INPUT_NORMAL)
FfxFloat32x3 FFX_DENOISER_LoadWorldSpaceNormal(FfxInt32x2 pixel_coordinate)
{
	return normalize(NormalsUnpackMul() * r_input_normal.Load(FfxInt32x3(pixel_coordinate, 0)).xyz + NormalsUnpackAdd());
}
#endif

#if defined(DENOISER_BIND_SRV_EXTRACTED_ROUGHNESS)
FfxFloat32 FFX_DNSR_Reflections_LoadRoughness(FfxInt32x2 pixel_coordinate)
{
	FfxFloat32 rawRoughness = r_extracted_roughness.Load(FfxInt32x3(pixel_coordinate, 0)).x;
	if (IsRoughnessPerceptual())
	{
		rawRoughness *= rawRoughness;
	}
	return rawRoughness;
}
#endif

#if defined(DENOISER_BIND_UAV_RADIANCE)
void StoreRadiance(FfxInt32x2 coordinate, FfxFloat32x4 radiance)
{
	rw_radiance[coordinate] = radiance;
}
#endif

#if defined(DENOISER_BIND_UAV_VARIANCE)
void StoreVariance(FfxInt32x2 coordinate, FfxFloat32 variance)
{
	rw_variance[coordinate] = variance;
}
#endif

#if defined(DENOISER_BIND_UAV_RADIANCE) && defined(DENOISER_BIND_UAV_VARIANCE)
void FFX_DNSR_Reflections_StorePrefilteredReflections(FfxInt32x2 pixel_coordinate, FfxFloat32x3 radiance, FfxFloat32 variance)
{
	StoreRadiance(pixel_coordinate, radiance.xyzz);
	StoreVariance(pixel_coordinate, variance.x);
}

void FFX_DNSR_Reflections_StoreTemporalAccumulation(FfxInt32x2 pixel_coordinate, FfxFloat32x3 radiance, FfxFloat32 variance)
{
	StoreRadiance(pixel_coordinate, radiance.xyzz);
	StoreVariance(pixel_coordinate, variance.x);
}
#endif

#if defined(DENOISER_BIND_SRV_AVERAGE_RADIANCE)
FfxFloat32x3 FFX_DNSR_Reflections_SampleAverageRadiance(FfxFloat32x2 uv)
{
	return r_average_radiance.SampleLevel(s_LinearSampler, uv, 0.0f).xyz;
}
#endif

#if defined(DENOISER_BIND_SRV_RADIANCE_HISTORY)
FfxFloat32x3 FFX_DNSR_Reflections_LoadRadianceHistory(FfxInt32x2 pixel_coordinate)
{
	return r_radiance_history.Load(FfxInt32x3(pixel_coordinate, 0)).xyz;
}

FfxFloat32x3 FFX_DNSR_Reflections_SampleRadianceHistory(FfxFloat32x2 uv)
{
	return r_radiance_history.SampleLevel(s_LinearSampler, uv, 0.0f).xyz;
}
#endif

#if defined(DENOISER_BIND_SRV_VARIANCE)
FfxFloat32 FFX_DNSR_Reflections_SampleVarianceHistory(FfxFloat32x2 uv)
{
	return r_variance.SampleLevel(s_LinearSampler, uv, 0.0f).x;
}
#endif

#if defined(DENOISER_BIND_SRV_SAMPLE_COUNT)
FfxFloat32 FFX_DNSR_Reflections_SampleNumSamplesHistory(FfxFloat32x2 uv)
{
	return r_sample_count.SampleLevel(s_LinearSampler, uv, 0.0f).x;
}
#endif

#if defined(DENOISER_BIND_UAV_REPROJECTED_RADIANCE)
void FFX_DNSR_Reflections_StoreRadianceReprojected(FfxInt32x2 pixel_coordinate, FfxFloat32x3 value)
{
	rw_reprojected_radiance[pixel_coordinate] = FfxFloat32x4(value, 0.0);
}
#endif

#if defined(DENOISER_BIND_UAV_AVERAGE_RADIANCE)
void FFX_DNSR_Reflections_StoreAverageRadiance(FfxInt32x2 pixel_coordinate, FfxFloat32x3 value)
{
	rw_average_radiance[pixel_coordinate] = FfxFloat32x4(value, 0.0);
}
#endif

#if defined(DENOISER_BIND_SRV_INPUT_NORMAL)
FfxFloat32x3 FFX_DNSR_Reflections_LoadWorldSpaceNormal(FfxInt32x2 pixel_coordinate)
{
	return FFX_DENOISER_LoadWorldSpaceNormal(pixel_coordinate);
}
#endif

#if defined(DENOISER_BIND_SRV_ROUGHNESS_HISTORY)
FfxFloat32 FFX_DNSR_Reflections_SampleRoughnessHistory(FfxFloat32x2 uv)
{
	FfxFloat32 rawRoughness = r_roughness_history.SampleLevel(s_LinearSampler, uv, 0.0f).x;
	if (IsRoughnessPerceptual())
	{
		rawRoughness *= rawRoughness;
	}
	return rawRoughness;
}
#endif

#if defined(DENOISER_BIND_SRV_NORMAL_HISTORY)
FfxFloat32x3 FFX_DNSR_Reflections_LoadWorldSpaceNormalHistory(FfxInt32x2 pixel_coordinate)
{
	return normalize(NormalsUnpackMul() * r_normal_history.Load(FfxInt32x3(pixel_coordinate, 0)).xyz + NormalsUnpackAdd());
}

FfxFloat32x3 FFX_DNSR_Reflections_SampleWorldSpaceNormalHistory(FfxFloat32x2 uv)
{
	return normalize(NormalsUnpackMul() * r_normal_history.SampleLevel(s_LinearSampler, uv, 0.0f).xyz + NormalsUnpackAdd());
}
#endif

#if defined(DENOISER_BIND_SRV_RADIANCE)
FfxFloat32 FFX_DNSR_Reflections_LoadRayLength(FfxInt32x2 pixel_coordinate)
{
	return r_radiance.Load(FfxInt32x3(pixel_coordinate, 0)).w;
}
#endif

#if defined(DENOISER_BIND_UAV_VARIANCE)
void FFX_DNSR_Reflections_StoreVariance(FfxInt32x2 pixel_coordinate, FfxFloat32 value)
{
	StoreVariance(pixel_coordinate, value);
}
#endif

#if defined(DENOISER_BIND_UAV_SAMPLE_COUNT)
void FFX_DNSR_Reflections_StoreNumSamples(FfxInt32x2 pixel_coordinate, FfxFloat32 value)
{
	rw_sample_count[pixel_coordinate] = value;
}
#endif

#if defined(DENOISER_BIND_SRV_RADIANCE)
FfxFloat32x3 FFX_DNSR_Reflections_LoadRadiance(FfxInt32x2 pixel_coordinate)
{
	return LoadRadiance(FfxInt32x3(pixel_coordinate, 0));
}
#endif

#if defined(DENOISER_BIND_SRV_REPROJECTED_RADIANCE)
FfxFloat32x3 FFX_DNSR_Reflections_LoadRadianceReprojected(FfxInt32x2 pixel_coordinate)
{
	return r_reprojected_radiance.Load(FfxInt32x3(pixel_coordinate, 0)).xyz;
}
#endif

#if defined(DENOISER_BIND_SRV_VARIANCE)
FfxFloat32 FFX_DNSR_Reflections_LoadVariance(FfxInt32x2 pixel_coordinate)
{
	return LoadVariance(FfxInt32x3(pixel_coordinate, 0));
}
#endif

#if defined(DENOISER_BIND_SRV_SAMPLE_COUNT)
FfxFloat32 FFX_DNSR_Reflections_LoadNumSamples(FfxInt32x2 pixel_coordinate)
{
	return r_sample_count.Load(FfxInt32x3(pixel_coordinate, 0)).x;
}
#endif

#if defined(DENOISER_BIND_SRV_INPUT_DEPTH_HIERARCHY)
FfxFloat32 FFX_DENOISER_LoadDepth(FfxInt32x2 pixel_coordinate, FfxInt32 mip)
{
	return r_depth_hierarchy.Load(FfxInt32x3(pixel_coordinate, mip));
}

FfxFloat32 FFX_DNSR_Reflections_LoadDepth(FfxInt32x2 pixel_coordinate)
{
	return FFX_DENOISER_LoadDepth(pixel_coordinate, 0);
}
#endif

#if defined(DENOISER_BIND_UAV_DENOISER_TILE_LIST)
FfxUInt32 GetDenoiserTile(FfxUInt32 group_id)
{
	return rw_denoiser_tile_list[group_id];
}
#endif

#if defined(DENOISER_BIND_SRV_INPUT_MOTION_VECTORS)
// Veach motion is in pixels; MotionVectorScale is 1 / render size. Pixels without a previous projection reproject in place.
FfxFloat32x2 FFX_DNSR_Reflections_LoadMotionVector(FfxInt32x2 pixel_coordinate)
{
	FfxUInt32x2 size = RenderSize();
	float4 motion = gMotion[(FfxUInt32(pixel_coordinate.y) * size.x + FfxUInt32(pixel_coordinate.x)) * 2u];
	return MotionVectorScale() * (motion.w != 0.0 ? motion.xy : FfxFloat32x2(0.0, 0.0));
}
#endif

#if defined(DENOISER_BIND_SRV_DEPTH_HISTORY)
FfxFloat32 FFX_DNSR_Reflections_LoadDepthHistory(FfxInt32x2 pixel_coordinate)
{
	return r_depth_history.Load(FfxInt32x3(pixel_coordinate, 0));
}

FfxFloat32 FFX_DNSR_Reflections_SampleDepthHistory(FfxFloat32x2 uv)
{
	return r_depth_history.SampleLevel(s_LinearSampler, uv, 0.0f);
}
#endif
