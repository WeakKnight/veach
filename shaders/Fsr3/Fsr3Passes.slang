// AMD FidelityFX FSR 3.1.4 upscaler passes and Veach's input/output passes (docs/Fsr3.md). Built by
// scripts/build-fsr3.mjs: one WGSL module per FSR3_PASS value, entry point main. The FidelityFX passes define the bind
// flags of FidelityFX's DX12 pass wrappers (ThirdParty/FidelityFX/hlsl) and include the unmodified FidelityFX headers
// with Veach's callbacks (Fsr3Callbacks.hlsli).
#define FSR3_PASS_PREPARE_INPUTS 1
#define FSR3_PASS_LUMA_PYRAMID 2
#define FSR3_PASS_LUMA_PYRAMID_TAIL 3
#define FSR3_PASS_SHADING_CHANGE_PYRAMID 4
#define FSR3_PASS_SHADING_CHANGE 5
#define FSR3_PASS_PREPARE_REACTIVITY 6
#define FSR3_PASS_LUMA_INSTABILITY 7
#define FSR3_PASS_ACCUMULATE 8
#define FSR3_PASS_ACCUMULATE_SHARPEN 9
#define FSR3_PASS_RCAS 10
#define FSR3_PASS_VEACH_INPUTS 11
#define FSR3_PASS_VEACH_OUTPUT 12

// The first part of ffx_spd.h SpdDownsample (mips 0..5 of one 64x64 tile), without the last-workgroup election:
// WGSL rejects its barriers after the non-uniform early exit, which the separate tail dispatch replaces.
#define SpdDownsampleTiles(workGroupID, localInvocationIndex, mips) 	{ 		FfxUInt32x2 sub_xy = ffxRemapForWaveReduction((localInvocationIndex) % 64); 		FfxUInt32 x = sub_xy.x + 8 * (((localInvocationIndex) >> 6) % 2); 		FfxUInt32 y = sub_xy.y + 8 * (((localInvocationIndex) >> 7)); 		SpdDownsampleMips_0_1(x, y, workGroupID, localInvocationIndex, mips, 0); 		SpdDownsampleNextFour(x, y, workGroupID, localInvocationIndex, 2, mips, 0); 	}

#if FSR3_PASS == FSR3_PASS_PREPARE_INPUTS
#define FSR3UPSCALER_BIND_SRV_INPUT_MOTION_VECTORS 1
#define FSR3UPSCALER_BIND_SRV_INPUT_DEPTH 1
#define FSR3UPSCALER_BIND_SRV_INPUT_COLOR 1
#define FSR3UPSCALER_BIND_UAV_DILATED_MOTION_VECTORS 1
#define FSR3UPSCALER_BIND_UAV_DILATED_DEPTH 1
#define FSR3UPSCALER_BIND_UAV_RECONSTRUCTED_PREV_NEAREST_DEPTH 1
#define FSR3UPSCALER_BIND_UAV_FARTHEST_DEPTH 1
#define FSR3UPSCALER_BIND_UAV_CURRENT_LUMA 1
#define FSR3UPSCALER_BIND_CB_FSR3UPSCALER 1
#include "Fsr3Callbacks.hlsli"
#include "fsr3upscaler/ffx_fsr3upscaler_common.h"
#include "fsr3upscaler/ffx_fsr3upscaler_prepare_inputs.h"

FFX_PREFER_WAVE64
[numthreads(8, 8, 1)]
void main(int2 iDispatchThreadId : SV_DispatchThreadID)
{
	PrepareInputs(iDispatchThreadId);
}

#elif FSR3_PASS == FSR3_PASS_LUMA_PYRAMID || FSR3_PASS == FSR3_PASS_LUMA_PYRAMID_TAIL
#define FSR3UPSCALER_BIND_SRV_CURRENT_LUMA 1
#define FSR3UPSCALER_BIND_SRV_FARTHEST_DEPTH 1
#define FSR3UPSCALER_BIND_UAV_FRAME_INFO 1
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_0 1
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_1 1
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_2 1
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_3 1
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_4 1
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_5 1
#define FSR3UPSCALER_BIND_UAV_FARTHEST_DEPTH_MIP1 1
#define FSR3UPSCALER_BIND_CB_FSR3UPSCALER 1
#define FSR3UPSCALER_BIND_CB_SPD 1
#define FFX_SPD_NO_WAVE_OPERATIONS 1
#if FSR3_PASS == FSR3_PASS_LUMA_PYRAMID_TAIL
#define FSR3_VEACH_SPD_TAIL 1
#endif
#include "Fsr3Callbacks.hlsli"
#include "fsr3upscaler/ffx_fsr3upscaler_common.h"
#include "fsr3upscaler/ffx_fsr3upscaler_luma_pyramid.h"

#if FSR3_PASS == FSR3_PASS_LUMA_PYRAMID
// SPD mips 0..5 per 64x64 tile: the part of SpdDownsample before its global atomic. The FrameInfo store at mip
// MipCount() - 1 happens here when the pyramid has at most 6 mips, else in the tail.
FFX_PREFER_WAVE64
[numthreads(256, 1, 1)]
void main(uint3 WorkGroupId : SV_GroupID, uint LocalThreadIndex : SV_GroupIndex)
{
	SpdDownsampleTiles(WorkGroupId.xy + WorkGroupOffset(), LocalThreadIndex, MipCount());
}
#else
// The last-workgroup part of SpdDownsample (mips 6..), one workgroup, after every tile wrote mip 5.
FFX_PREFER_WAVE64
[numthreads(256, 1, 1)]
void main(uint LocalThreadIndex : SV_GroupIndex)
{
	FfxUInt32 mips = MipCount();
	if (mips <= 6) return;
	FfxUInt32x2 sub_xy = ffxRemapForWaveReduction(LocalThreadIndex % 64);
	FfxUInt32 x = sub_xy.x + 8 * ((LocalThreadIndex >> 6) % 2);
	FfxUInt32 y = sub_xy.y + 8 * ((LocalThreadIndex >> 7));
	SpdDownsampleMips_6_7(x, y, mips, 0);
	SpdDownsampleNextFour(x, y, FfxUInt32x2(0, 0), LocalThreadIndex, 8, mips, 0);
}
#endif

#elif FSR3_PASS == FSR3_PASS_SHADING_CHANGE_PYRAMID
#define FSR3UPSCALER_BIND_SRV_CURRENT_LUMA 1
#define FSR3UPSCALER_BIND_SRV_PREVIOUS_LUMA 1
#define FSR3UPSCALER_BIND_SRV_DILATED_MOTION_VECTORS 1
#define FSR3UPSCALER_BIND_SRV_INPUT_EXPOSURE 1
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_0 1
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_1 1
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_2 1
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_3 1
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_4 1
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_5 1
#define FSR3UPSCALER_BIND_CB_FSR3UPSCALER 1
#define FSR3UPSCALER_BIND_CB_SPD 1
#define FFX_SPD_NO_WAVE_OPERATIONS 1
#include "Fsr3Callbacks.hlsli"
#include "fsr3upscaler/ffx_fsr3upscaler_common.h"
#include "fsr3upscaler/ffx_fsr3upscaler_shading_change_pyramid.h"

// Only mips 0..5 are stored (StorePyramid), so the last-workgroup tail has no effect and is skipped.
FFX_PREFER_WAVE64
[numthreads(256, 1, 1)]
void main(uint3 WorkGroupId : SV_GroupID, uint LocalThreadIndex : SV_GroupIndex)
{
	SpdDownsampleTiles(WorkGroupId.xy + WorkGroupOffset(), LocalThreadIndex, MipCount());
}

#elif FSR3_PASS == FSR3_PASS_SHADING_CHANGE
#define FSR3UPSCALER_BIND_SRV_SPD_MIPS 1
#define FSR3UPSCALER_BIND_UAV_SHADING_CHANGE 1
#define FSR3UPSCALER_BIND_CB_FSR3UPSCALER 1
#include "Fsr3Callbacks.hlsli"
#include "fsr3upscaler/ffx_fsr3upscaler_common.h"
#include "fsr3upscaler/ffx_fsr3upscaler_shading_change.h"

FFX_PREFER_WAVE64
[numthreads(8, 8, 1)]
void main(int2 iDispatchThreadId : SV_DispatchThreadID)
{
	ShadingChange(iDispatchThreadId);
}

#elif FSR3_PASS == FSR3_PASS_PREPARE_REACTIVITY
#define FSR3UPSCALER_BIND_SRV_RECONSTRUCTED_PREV_NEAREST_DEPTH 1
#define FSR3UPSCALER_BIND_SRV_DILATED_MOTION_VECTORS 1
#define FSR3UPSCALER_BIND_SRV_DILATED_DEPTH 1
#define FSR3UPSCALER_BIND_SRV_REACTIVE_MASK 1
#define FSR3UPSCALER_BIND_SRV_TRANSPARENCY_AND_COMPOSITION_MASK 1
#define FSR3UPSCALER_BIND_SRV_ACCUMULATION 1
#define FSR3UPSCALER_BIND_SRV_SHADING_CHANGE 1
#define FSR3UPSCALER_BIND_SRV_CURRENT_LUMA 1
#define FSR3UPSCALER_BIND_SRV_INPUT_EXPOSURE 1
#define FSR3UPSCALER_BIND_UAV_DILATED_REACTIVE_MASKS 1
#define FSR3UPSCALER_BIND_UAV_NEW_LOCKS 1
#define FSR3UPSCALER_BIND_UAV_ACCUMULATION 1
#define FSR3UPSCALER_BIND_CB_FSR3UPSCALER 1
#include "Fsr3Callbacks.hlsli"
#include "fsr3upscaler/ffx_fsr3upscaler_common.h"
#include "fsr3upscaler/ffx_fsr3upscaler_prepare_reactivity.h"

FFX_PREFER_WAVE64
[numthreads(8, 8, 1)]
void main(int2 iDispatchThreadId : SV_DispatchThreadID)
{
	PrepareReactivity(iDispatchThreadId);
}

#elif FSR3_PASS == FSR3_PASS_LUMA_INSTABILITY
#define FSR3UPSCALER_BIND_SRV_INPUT_EXPOSURE 1
#define FSR3UPSCALER_BIND_SRV_DILATED_REACTIVE_MASKS 1
#define FSR3UPSCALER_BIND_SRV_DILATED_MOTION_VECTORS 1
#define FSR3UPSCALER_BIND_SRV_FRAME_INFO 1
#define FSR3UPSCALER_BIND_SRV_LUMA_HISTORY 1
#define FSR3UPSCALER_BIND_SRV_FARTHEST_DEPTH_MIP1 1
#define FSR3UPSCALER_BIND_SRV_CURRENT_LUMA 1
#define FSR3UPSCALER_BIND_UAV_LUMA_HISTORY 1
#define FSR3UPSCALER_BIND_UAV_LUMA_INSTABILITY 1
#define FSR3UPSCALER_BIND_CB_FSR3UPSCALER 1
#include "Fsr3Callbacks.hlsli"
#include "fsr3upscaler/ffx_fsr3upscaler_common.h"
#include "fsr3upscaler/ffx_fsr3upscaler_luma_instability.h"

FFX_PREFER_WAVE64
[numthreads(8, 8, 1)]
void main(int2 iDispatchThreadId : SV_DispatchThreadID)
{
	LumaInstability(iDispatchThreadId);
}

#elif FSR3_PASS == FSR3_PASS_ACCUMULATE || FSR3_PASS == FSR3_PASS_ACCUMULATE_SHARPEN
#define FSR3UPSCALER_BIND_SRV_INPUT_EXPOSURE 1
#define FSR3UPSCALER_BIND_SRV_DILATED_REACTIVE_MASKS 1
#define FSR3UPSCALER_BIND_SRV_DILATED_MOTION_VECTORS 1
#define FSR3UPSCALER_BIND_SRV_INPUT_MOTION_VECTORS 1
#define FSR3UPSCALER_BIND_SRV_INTERNAL_UPSCALED 1
#define FSR3UPSCALER_BIND_SRV_LANCZOS_LUT 1
#define FSR3UPSCALER_BIND_SRV_FARTHEST_DEPTH_MIP1 1
#define FSR3UPSCALER_BIND_SRV_CURRENT_LUMA 1
#define FSR3UPSCALER_BIND_SRV_LUMA_INSTABILITY 1
#define FSR3UPSCALER_BIND_SRV_INPUT_COLOR 1
#define FSR3UPSCALER_BIND_UAV_INTERNAL_UPSCALED 1
#define FSR3UPSCALER_BIND_UAV_UPSCALED_OUTPUT 1
#define FSR3UPSCALER_BIND_UAV_NEW_LOCKS 1
#define FSR3UPSCALER_BIND_CB_FSR3UPSCALER 1
#if FSR3_PASS == FSR3_PASS_ACCUMULATE_SHARPEN
#define FFX_FSR3UPSCALER_OPTION_APPLY_SHARPENING 1
#endif
#include "Fsr3Callbacks.hlsli"
#include "fsr3upscaler/ffx_fsr3upscaler_common.h"
#include "fsr3upscaler/ffx_fsr3upscaler_sample.h"
#include "fsr3upscaler/ffx_fsr3upscaler_upsample.h"
#include "fsr3upscaler/ffx_fsr3upscaler_reproject.h"
#include "fsr3upscaler/ffx_fsr3upscaler_accumulate.h"

FFX_PREFER_WAVE64
[numthreads(8, 8, 1)]
void main(int2 iDispatchThreadId : SV_DispatchThreadID)
{
	Accumulate(iDispatchThreadId);
}

#elif FSR3_PASS == FSR3_PASS_RCAS
#define FSR3UPSCALER_BIND_SRV_INPUT_EXPOSURE 1
#define FSR3UPSCALER_BIND_SRV_RCAS_INPUT 1
#define FSR3UPSCALER_BIND_UAV_UPSCALED_OUTPUT 1
#define FSR3UPSCALER_BIND_CB_FSR3UPSCALER 1
#define FSR3UPSCALER_BIND_CB_RCAS 1
#include "Fsr3Callbacks.hlsli"
#include "fsr3upscaler/ffx_fsr3upscaler_common.h"
#include "fsr3upscaler/ffx_fsr3upscaler_rcas.h"

FFX_PREFER_WAVE64
[numthreads(64, 1, 1)]
void main(uint3 LocalThreadId : SV_GroupThreadID, uint3 WorkGroupId : SV_GroupID, uint3 Dtid : SV_DispatchThreadID)
{
	RCAS(LocalThreadId, WorkGroupId, Dtid);
}

#else
// ---- Veach passes ----
import Scene.SceneTypes;
#include "WriteOnlyTexture.hlsli"

[[vk::binding(0, 0)]] ConstantBuffer<FrameUniforms> gFrame;
struct VeachFsr3Params
{
	float nearPlane; // FSR input depth = nearPlane / viewZ (inverted, infinite), 0 without a surface
	uint3 padding;
};
[[vk::binding(1, 0)]] ConstantBuffer<VeachFsr3Params> gParams;

#if FSR3_PASS == FSR3_PASS_VEACH_INPUTS
// The TAA input layout (three float4 per pixel: radiance, albedo / hit distance, normal / instance + 1) and the TAA
// motion buffer (two float4 per pixel: previous - current pixels, valid in w) -> FSR's color, depth and motion inputs.
[[vk::binding(2, 0)]] StructuredBuffer<float4> gColor;
[[vk::binding(3, 0)]] StructuredBuffer<float4> gMotion;
[[vk::binding(4, 0)]] [format("rgba16f")] WTexture2D<float4> gOutColor;
[[vk::binding(5, 0)]] [format("r32f")] WTexture2D<float> gOutDepth;
[[vk::binding(6, 0)]] [format("rg32f")] WTexture2D<float2> gOutMotion;

[shader("compute")]
[numthreads(8, 8, 1)]
void main(uint3 tid : SV_DispatchThreadID)
{
	uint2 pixel = tid.xy, size = gFrame.frame.xy;
	if (any(pixel >= size)) return;
	uint index = pixel.y * size.x + pixel.x, base = index * 3u;
	float3 color = gColor[base].xyz;
	gOutColor[pixel] = float4(all(isfinite(color)) ? max(color, 0.0) : float3(0.0), 1.0);
	// Same jittered camera ray as the primary hit; distance is along the normalized ray.
	float2 ndc = (float2(pixel) + gFrame.temporal.xy) / float2(size) * float2(2.0, -2.0) + float2(-1.0, 1.0);
	float3 direction = normalize(gFrame.cameraForward.xyz + ndc.x * gFrame.cameraRight.xyz + ndc.y * gFrame.cameraUp.xyz);
	float3 axis = normalize(cross(gFrame.cameraUp.xyz, gFrame.cameraRight.xyz));
	float viewZ = gColor[base + 1u].w * dot(direction, axis);
	bool surface = gColor[base + 2u].w > 0.0 && viewZ > 0.0;
	gOutDepth[pixel] = surface ? gParams.nearPlane / viewZ : 0.0;
	float4 motion = gMotion[index * 2u];
	gOutMotion[pixel] = motion.w != 0.0 ? motion.xy : float2(0.0);
}

#elif FSR3_PASS == FSR3_PASS_VEACH_OUTPUT
// FSR's output texture -> the presentation layout (three float4 per pixel, radiance first) at the upscaled size.
[[vk::binding(2, 0)]] Texture2D<float4> gUpscaled;
[[vk::binding(3, 0)]] RWStructuredBuffer<float4> gPresentation;

[shader("compute")]
[numthreads(8, 8, 1)]
void main(uint3 tid : SV_DispatchThreadID)
{
	uint width, height;
	gUpscaled.GetDimensions(width, height);
	uint2 pixel = tid.xy;
	if (pixel.x >= width || pixel.y >= height) return;
	gPresentation[(pixel.y * width + pixel.x) * 3u] = float4(gUpscaled.Load(int3(int2(pixel), 0)).xyz, 1.0);
}
#endif
#endif
