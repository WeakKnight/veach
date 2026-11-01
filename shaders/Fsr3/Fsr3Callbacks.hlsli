// Veach resource callbacks for the AMD FidelityFX FSR 3.1.4 upscaler shaders (docs/Fsr3.md).
// Mirrors ThirdParty/FidelityFX/gpu/fsr3upscaler/ffx_fsr3upscaler_callbacks_hlsl.h (FFX_HALF = 0): a pass defines
// the FSR3UPSCALER_BIND_* flags of FidelityFX's DX12 pass wrapper (ThirdParty/FidelityFX/hlsl) and gets exactly those
// resources, at the fixed WebGPU bindings below (group 0; Fsr3Upscaler.ts creates them). Differences:
// - storage formats are core WebGPU formats at least as precise as FidelityFX's (r8/r16 -> r32float, rg16 -> rg32float,
//   r16_snorm Lanczos LUT -> r32float); only new locks (r32float) is read_write;
// - the reconstructed previous nearest depth is a storage buffer of atomics (WGSL has no texture atomics);
// - FrameInfo is a storage buffer of one float4 (read before written in the luma pyramid);
// - the SPD global atomic is unused: the luma pyramid runs its last-workgroup tail as a separate dispatch.
#include "ffx_core.h"
#include "WriteOnlyTexture.hlsli"

#ifndef FFX_PREFER_WAVE64
#define FFX_PREFER_WAVE64
#endif

#if defined(FSR3UPSCALER_BIND_CB_FSR3UPSCALER)
// cbFSR3Upscaler, in FidelityFX's order (Fsr3UpscalerConstants in ffx_fsr3upscaler_private.h, 152 bytes).
struct Fsr3UpscalerConstants
{
	FfxInt32x2 iRenderSize;
	FfxInt32x2 iPreviousFrameRenderSize;
	FfxInt32x2 iUpscaleSize;
	FfxInt32x2 iPreviousFrameUpscaleSize;
	FfxInt32x2 iMaxRenderSize;
	FfxInt32x2 iMaxUpscaleSize;
	FfxFloat32x4 fDeviceToViewDepth;
	FfxFloat32x2 fJitter;
	FfxFloat32x2 fPreviousFrameJitter;
	FfxFloat32x2 fMotionVectorScale;
	FfxFloat32x2 fDownscaleFactor;
	FfxFloat32x2 fMotionVectorJitterCancellation;
	FfxFloat32 fTanHalfFOV;
	FfxFloat32 fJitterSequenceLength;
	FfxFloat32 fDeltaTime;
	FfxFloat32 fDeltaPreExposure;
	FfxFloat32 fViewSpaceToMetersFactor;
	FfxFloat32 fFrameIndex;
	FfxFloat32 fVelocityFactor;
	FfxFloat32 fReactivenessScale;
	FfxFloat32 fShadingChangeScale;
	FfxFloat32 fAccumulationAddedPerFrame;
	FfxFloat32 fMinDisocclusionAccumulation;
};
[[vk::binding(0, 0)]] ConstantBuffer<Fsr3UpscalerConstants> gFsr3;

FfxInt32x2 RenderSize() { return gFsr3.iRenderSize; }
FfxInt32x2 PreviousFrameRenderSize() { return gFsr3.iPreviousFrameRenderSize; }
FfxInt32x2 MaxRenderSize() { return gFsr3.iMaxRenderSize; }
FfxInt32x2 UpscaleSize() { return gFsr3.iUpscaleSize; }
FfxInt32x2 PreviousFrameUpscaleSize() { return gFsr3.iPreviousFrameUpscaleSize; }
FfxInt32x2 MaxUpscaleSize() { return gFsr3.iMaxUpscaleSize; }
FfxFloat32x2 Jitter() { return gFsr3.fJitter; }
FfxFloat32x2 PreviousFrameJitter() { return gFsr3.fPreviousFrameJitter; }
FfxFloat32x4 DeviceToViewSpaceTransformFactors() { return gFsr3.fDeviceToViewDepth; }
FfxFloat32x2 MotionVectorScale() { return gFsr3.fMotionVectorScale; }
FfxFloat32x2 DownscaleFactor() { return gFsr3.fDownscaleFactor; }
FfxFloat32x2 MotionVectorJitterCancellation() { return gFsr3.fMotionVectorJitterCancellation; }
FfxFloat32 TanHalfFoV() { return gFsr3.fTanHalfFOV; }
FfxFloat32 JitterSequenceLength() { return gFsr3.fJitterSequenceLength; }
FfxFloat32 DeltaTime() { return gFsr3.fDeltaTime; }
FfxFloat32 DeltaPreExposure() { return gFsr3.fDeltaPreExposure; }
FfxFloat32 ViewSpaceToMetersFactor() { return gFsr3.fViewSpaceToMetersFactor; }
FfxFloat32 FrameIndex() { return gFsr3.fFrameIndex; }
FfxFloat32 VelocityFactor() { return gFsr3.fVelocityFactor; }
FfxFloat32 AccumulationAddedPerFrame() { return gFsr3.fAccumulationAddedPerFrame; }
FfxFloat32 MinDisocclusionAccumulation() { return gFsr3.fMinDisocclusionAccumulation; }
#endif

#if defined(FSR3UPSCALER_BIND_CB_RCAS)
struct Fsr3RcasConstants { FfxUInt32x4 rcasConfig; };
[[vk::binding(1, 0)]] ConstantBuffer<Fsr3RcasConstants> gRcas;
FfxUInt32x4 RCASConfig() { return gRcas.rcasConfig; }
#endif

#if defined(FSR3UPSCALER_BIND_CB_SPD)
struct Fsr3SpdConstants { FfxUInt32 mips; FfxUInt32 numWorkGroups; FfxUInt32x2 workGroupOffset; FfxUInt32x2 renderSize; };
[[vk::binding(1, 0)]] ConstantBuffer<Fsr3SpdConstants> gSpd;
FfxUInt32 MipCount() { return gSpd.mips; }
FfxUInt32 NumWorkGroups() { return gSpd.numWorkGroups; }
FfxUInt32x2 WorkGroupOffset() { return gSpd.workGroupOffset; }
FfxUInt32x2 SPD_RenderSize() { return gSpd.renderSize; }
#endif

[[vk::binding(2, 0)]] SamplerState s_PointClamp;
[[vk::binding(3, 0)]] SamplerState s_LinearClamp;

// ---- Buffers ----

#if defined(FSR3UPSCALER_BIND_UAV_FRAME_INFO)
[[vk::binding(4, 0)]] RWStructuredBuffer<FfxFloat32x4> rw_frame_info;
FfxFloat32x4 LoadFrameInfo() { return rw_frame_info[0]; }
void StoreFrameInfo(FfxFloat32x4 fInfo) { rw_frame_info[0] = fInfo; }
#elif defined(FSR3UPSCALER_BIND_SRV_FRAME_INFO) || defined(FSR3UPSCALER_BIND_SRV_INPUT_EXPOSURE)
[[vk::binding(4, 0)]] StructuredBuffer<FfxFloat32x4> r_frame_info;
#endif
#if defined(FSR3UPSCALER_BIND_SRV_FRAME_INFO)
FfxFloat32x4 FrameInfo() { return r_frame_info[0]; }
#endif
#if defined(FSR3UPSCALER_BIND_SRV_INPUT_EXPOSURE)
// FFX_FSR3UPSCALER_ENABLE_AUTO_EXPOSURE: the input exposure is FrameInfo (exposure in x).
FfxFloat32 Exposure()
{
	FfxFloat32 exposure = r_frame_info[0].x;
	if (exposure == 0.0f) exposure = 1.0f;
	return exposure;
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_RECONSTRUCTED_PREV_NEAREST_DEPTH)
[[vk::binding(5, 0)]] RWStructuredBuffer<Atomic<FfxUInt32> > rw_reconstructed_previous_nearest_depth;
void StoreReconstructedDepth(FfxUInt32x2 iPxSample, FfxFloat32 fDepth)
{
	FfxUInt32 uDepth = asuint(fDepth);
	FfxUInt32 index = iPxSample.y * FfxUInt32(MaxRenderSize().x) + iPxSample.x;
#if FFX_FSR3UPSCALER_OPTION_INVERTED_DEPTH
	rw_reconstructed_previous_nearest_depth[index].max(uDepth);
#else
	rw_reconstructed_previous_nearest_depth[index].min(uDepth); // min for standard, max for inverted depth
#endif
}
void SetReconstructedDepth(FfxUInt32x2 iPxSample, const FfxUInt32 uValue)
{
	rw_reconstructed_previous_nearest_depth[iPxSample.y * FfxUInt32(MaxRenderSize().x) + iPxSample.x].store(uValue);
}
#endif
#if defined(FSR3UPSCALER_BIND_SRV_RECONSTRUCTED_PREV_NEAREST_DEPTH)
[[vk::binding(5, 0)]] StructuredBuffer<FfxUInt32> r_reconstructed_previous_nearest_depth;
FfxFloat32 LoadReconstructedPrevDepth(FfxUInt32x2 iPxPos)
{
	return asfloat(r_reconstructed_previous_nearest_depth[iPxPos.y * FfxUInt32(MaxRenderSize().x) + iPxPos.x]);
}
#endif

// ---- Sampled textures ----

#if defined(FSR3UPSCALER_BIND_SRV_SPD_MIPS)
[[vk::binding(10, 0)]] Texture2D<FfxFloat32x2> r_spd_mips;
FfxInt32x2 GetSPDMipDimensions(FfxUInt32 uMipLevel)
{
	FfxUInt32 uWidth; FfxUInt32 uHeight; FfxUInt32 uLevels;
	r_spd_mips.GetDimensions(uMipLevel, uWidth, uHeight, uLevels);
	return FfxInt32x2(uWidth, uHeight);
}
FfxFloat32x2 SampleSPDMipLevel(FfxFloat32x2 fUV, FfxUInt32 mipLevel) { return r_spd_mips.SampleLevel(s_LinearClamp, fUV, mipLevel); }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_INPUT_DEPTH)
[[vk::binding(11, 0)]] Texture2D<FfxFloat32> r_input_depth;
FfxFloat32 LoadInputDepth(FfxUInt32x2 iPxPos) { return r_input_depth.Load(FfxInt32x3(iPxPos, 0)); }
FfxFloat32 SampleInputDepth(FfxFloat32x2 fUV) { return r_input_depth.SampleLevel(s_LinearClamp, fUV, 0).x; }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_REACTIVE_MASK)
[[vk::binding(12, 0)]] Texture2D<FfxFloat32> r_reactive_mask;
FfxFloat32 LoadReactiveMask(FfxUInt32x2 iPxPos) { return r_reactive_mask.Load(FfxInt32x3(iPxPos, 0)) * gFsr3.fReactivenessScale; }
FfxInt32x2 GetReactiveMaskResourceDimensions() { FfxUInt32 uWidth; FfxUInt32 uHeight; r_reactive_mask.GetDimensions(uWidth, uHeight); return FfxInt32x2(uWidth, uHeight); }
FfxFloat32 SampleReactiveMask(FfxFloat32x2 fUV) { return r_reactive_mask.SampleLevel(s_LinearClamp, fUV, 0).x * gFsr3.fReactivenessScale; }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_TRANSPARENCY_AND_COMPOSITION_MASK)
[[vk::binding(13, 0)]] Texture2D<FfxFloat32> r_transparency_and_composition_mask;
FfxFloat32 LoadTransparencyAndCompositionMask(FfxUInt32x2 iPxPos) { return r_transparency_and_composition_mask.Load(FfxInt32x3(iPxPos, 0)); }
FfxInt32x2 GetTransparencyAndCompositionMaskResourceDimensions() { FfxUInt32 uWidth; FfxUInt32 uHeight; r_transparency_and_composition_mask.GetDimensions(uWidth, uHeight); return FfxInt32x2(uWidth, uHeight); }
FfxFloat32 SampleTransparencyAndCompositionMask(FfxFloat32x2 fUV) { return r_transparency_and_composition_mask.SampleLevel(s_LinearClamp, fUV, 0).x; }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_INPUT_COLOR)
[[vk::binding(14, 0)]] Texture2D<FfxFloat32x4> r_input_color_jittered;
FfxFloat32x3 LoadInputColor(FfxUInt32x2 iPxPos) { return r_input_color_jittered.Load(FfxInt32x3(iPxPos, 0)).rgb; }
FfxFloat32x3 SampleInputColor(FfxFloat32x2 fUV) { return r_input_color_jittered.SampleLevel(s_LinearClamp, fUV, 0).rgb; }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_INPUT_MOTION_VECTORS)
[[vk::binding(15, 0)]] Texture2D<FfxFloat32x4> r_input_motion_vectors;
FfxFloat32x2 LoadInputMotionVector(FfxUInt32x2 iPxDilatedMotionVectorPos)
{
	FfxFloat32x2 fSrcMotionVector = r_input_motion_vectors.Load(FfxInt32x3(iPxDilatedMotionVectorPos, 0)).xy;
	FfxFloat32x2 fUvMotionVector = fSrcMotionVector * MotionVectorScale();
#if FFX_FSR3UPSCALER_OPTION_JITTERED_MOTION_VECTORS
	fUvMotionVector -= MotionVectorJitterCancellation();
#endif
	return fUvMotionVector;
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_INTERNAL_UPSCALED)
[[vk::binding(16, 0)]] Texture2D<FfxFloat32x4> r_internal_upscaled_color;
FfxFloat32x4 LoadHistory(FfxUInt32x2 iPxHistory) { return r_internal_upscaled_color.Load(FfxInt32x3(iPxHistory, 0)); }
FfxFloat32x4 SampleHistory(FfxFloat32x2 fUV) { return r_internal_upscaled_color.SampleLevel(s_LinearClamp, fUV, 0); }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_LUMA_HISTORY)
[[vk::binding(17, 0)]] Texture2D<FfxFloat32x4> r_luma_history;
FfxFloat32x4 LoadLumaHistory(FfxInt32x2 iPxPos) { return r_luma_history.Load(FfxInt32x3(iPxPos, 0)); }
FfxFloat32x4 SampleLumaHistory(FfxFloat32x2 fUV) { return r_luma_history.SampleLevel(s_LinearClamp, fUV, 0); }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_RCAS_INPUT)
[[vk::binding(18, 0)]] Texture2D<FfxFloat32x4> r_rcas_input;
FfxFloat32x4 LoadRCAS_Input(FfxInt32x2 iPxPos) { return r_rcas_input.Load(FfxInt32x3(iPxPos, 0)); }
FfxFloat32x3 SampleRCAS_Input(FfxFloat32x2 fUV) { return r_rcas_input.SampleLevel(s_LinearClamp, fUV, 0).rgb; }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_ACCUMULATION)
[[vk::binding(19, 0)]] Texture2D<FfxFloat32> r_accumulation;
FfxFloat32 SampleAccumulation(FfxFloat32x2 fUV) { return r_accumulation.SampleLevel(s_LinearClamp, fUV, 0); }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_SHADING_CHANGE)
[[vk::binding(20, 0)]] Texture2D<FfxFloat32> r_shading_change;
FfxFloat32 LoadShadingChange(FfxUInt32x2 iPxPos) { return r_shading_change.Load(FfxInt32x3(iPxPos, 0)) * gFsr3.fShadingChangeScale; }
FfxFloat32 SampleShadingChange(FfxFloat32x2 fUV) { return r_shading_change.SampleLevel(s_LinearClamp, fUV, 0) * gFsr3.fShadingChangeScale; }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_FARTHEST_DEPTH)
[[vk::binding(21, 0)]] Texture2D<FfxFloat32> r_farthest_depth;
FfxInt32x2 GetFarthestDepthResourceDimensions() { FfxUInt32 uWidth; FfxUInt32 uHeight; r_farthest_depth.GetDimensions(uWidth, uHeight); return FfxInt32x2(uWidth, uHeight); }
FfxFloat32 LoadFarthestDepth(FfxUInt32x2 iPxPos) { return r_farthest_depth.Load(FfxInt32x3(iPxPos, 0)); }
FfxFloat32 SampleFarthestDepth(FfxFloat32x2 fUV) { return r_farthest_depth.SampleLevel(s_LinearClamp, fUV, 0); }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_FARTHEST_DEPTH_MIP1)
[[vk::binding(22, 0)]] Texture2D<FfxFloat32> r_farthest_depth_mip1;
FfxInt32x2 GetFarthestDepthMip1ResourceDimensions() { FfxUInt32 uWidth; FfxUInt32 uHeight; r_farthest_depth_mip1.GetDimensions(uWidth, uHeight); return FfxInt32x2(uWidth, uHeight); }
FfxFloat32 LoadFarthestDepthMip1(FfxUInt32x2 iPxPos) { return r_farthest_depth_mip1.Load(FfxInt32x3(iPxPos, 0)); }
FfxFloat32 SampleFarthestDepthMip1(FfxFloat32x2 fUV) { return r_farthest_depth_mip1.SampleLevel(s_LinearClamp, fUV, 0); }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_CURRENT_LUMA)
[[vk::binding(23, 0)]] Texture2D<FfxFloat32> r_current_luma;
FfxFloat32 LoadCurrentLuma(FfxUInt32x2 iPxPos) { return r_current_luma.Load(FfxInt32x3(iPxPos, 0)); }
FfxFloat32 SampleCurrentLuma(FfxFloat32x2 uv) { return r_current_luma.SampleLevel(s_LinearClamp, uv, 0); }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_LUMA_INSTABILITY)
[[vk::binding(24, 0)]] Texture2D<FfxFloat32> r_luma_instability;
FfxFloat32 SampleLumaInstability(FfxFloat32x2 uv) { return r_luma_instability.SampleLevel(s_LinearClamp, uv, 0); }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_PREVIOUS_LUMA)
[[vk::binding(25, 0)]] Texture2D<FfxFloat32> r_previous_luma;
FfxFloat32 LoadPreviousLuma(FfxUInt32x2 iPxPos) { return r_previous_luma.Load(FfxInt32x3(iPxPos, 0)); }
FfxFloat32 SamplePreviousLuma(FfxFloat32x2 uv) { return r_previous_luma.SampleLevel(s_LinearClamp, uv, 0); }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_NEW_LOCKS)
[[vk::binding(26, 0)]] Texture2D<FfxFloat32> r_new_locks;
FfxFloat32 LoadNewLocks(FfxUInt32x2 iPxPos) { return r_new_locks.Load(FfxInt32x3(iPxPos, 0)); }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_DILATED_MOTION_VECTORS)
[[vk::binding(27, 0)]] Texture2D<FfxFloat32x2> r_dilated_motion_vectors;
FfxFloat32x2 LoadDilatedMotionVector(FfxUInt32x2 iPxInput) { return r_dilated_motion_vectors.Load(FfxInt32x3(iPxInput, 0)); }
FfxFloat32x2 SampleDilatedMotionVector(FfxFloat32x2 fUV) { return r_dilated_motion_vectors.SampleLevel(s_LinearClamp, fUV, 0); }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_DILATED_DEPTH)
[[vk::binding(28, 0)]] Texture2D<FfxFloat32> r_dilated_depth;
FfxFloat32 LoadDilatedDepth(FfxUInt32x2 iPxInput) { return r_dilated_depth.Load(FfxInt32x3(iPxInput, 0)); }
FfxFloat32 SampleDilatedDepth(FfxFloat32x2 fUV) { return r_dilated_depth.SampleLevel(s_LinearClamp, fUV, 0); }
#endif

#if defined(FSR3UPSCALER_BIND_SRV_LANCZOS_LUT)
[[vk::binding(29, 0)]] Texture2D<FfxFloat32> r_lanczos_lut;
#endif
FfxFloat32 SampleLanczos2Weight(FfxFloat32 x)
{
#if defined(FSR3UPSCALER_BIND_SRV_LANCZOS_LUT)
	return r_lanczos_lut.SampleLevel(s_LinearClamp, FfxFloat32x2(x / 2, 0.5f), 0);
#else
	return 0.f;
#endif
}

#if defined(FSR3UPSCALER_BIND_SRV_DILATED_REACTIVE_MASKS)
[[vk::binding(30, 0)]] Texture2D<FfxFloat32x4> r_dilated_reactive_masks;
FfxFloat32x4 SampleDilatedReactiveMasks(FfxFloat32x2 fUV) { return r_dilated_reactive_masks.SampleLevel(s_LinearClamp, fUV, 0); }
#endif

// ---- Storage textures ----

#if defined(FSR3UPSCALER_BIND_UAV_LUMA_HISTORY)
[[vk::binding(40, 0)]] [format("rgba16f")] WTexture2D<FfxFloat32x4> rw_luma_history;
void StoreLumaHistory(FfxUInt32x2 iPxPos, FfxFloat32x4 fLumaHistory) { rw_luma_history[iPxPos] = fLumaHistory; }
#endif

#if defined(FSR3UPSCALER_BIND_UAV_INTERNAL_UPSCALED)
[[vk::binding(41, 0)]] [format("rgba16f")] WTexture2D<FfxFloat32x4> rw_internal_upscaled_color;
void StoreReprojectedHistory(FfxUInt32x2 iPxHistory, FfxFloat32x4 fHistory) { rw_internal_upscaled_color[iPxHistory] = fHistory; }
void StoreInternalColorAndWeight(FfxUInt32x2 iPxPos, FfxFloat32x4 fColorAndWeight) { rw_internal_upscaled_color[iPxPos] = fColorAndWeight; }
#endif

#if defined(FSR3UPSCALER_BIND_UAV_UPSCALED_OUTPUT)
[[vk::binding(42, 0)]] [format("rgba16f")] WTexture2D<FfxFloat32x4> rw_upscaled_output;
void StoreUpscaledOutput(FfxUInt32x2 iPxPos, FfxFloat32x3 fColor) { rw_upscaled_output[iPxPos] = FfxFloat32x4(fColor, 1.f); }
#endif

#if defined(FSR3UPSCALER_BIND_UAV_ACCUMULATION)
[[vk::binding(43, 0)]] [format("r32f")] WTexture2D<FfxFloat32> rw_accumulation;
void StoreAccumulation(FfxUInt32x2 iPxPos, FfxFloat32 fAccumulation) { rw_accumulation[iPxPos] = fAccumulation; }
#endif

#if defined(FSR3UPSCALER_BIND_UAV_SHADING_CHANGE)
[[vk::binding(44, 0)]] [format("r32f")] WTexture2D<FfxFloat32> rw_shading_change;
void StoreShadingChange(FfxUInt32x2 iPxPos, FfxFloat32 fShadingChange) { rw_shading_change[iPxPos] = fShadingChange; }
#endif

#if defined(FSR3UPSCALER_BIND_UAV_FARTHEST_DEPTH)
[[vk::binding(45, 0)]] [format("r32f")] WTexture2D<FfxFloat32> rw_farthest_depth;
void StoreFarthestDepth(FfxUInt32x2 iPxPos, FfxFloat32 fDepth) { rw_farthest_depth[iPxPos] = fDepth; }
#endif

#if defined(FSR3UPSCALER_BIND_UAV_FARTHEST_DEPTH_MIP1)
[[vk::binding(46, 0)]] [format("r32f")] WTexture2D<FfxFloat32> rw_farthest_depth_mip1;
void StoreFarthestDepthMip1(FfxUInt32x2 iPxPos, FfxFloat32 fDepth) { rw_farthest_depth_mip1[iPxPos] = fDepth; }
#endif

#if defined(FSR3UPSCALER_BIND_UAV_CURRENT_LUMA)
[[vk::binding(47, 0)]] [format("r32f")] WTexture2D<FfxFloat32> rw_current_luma;
void StoreCurrentLuma(FfxUInt32x2 iPxPos, FfxFloat32 fLuma) { rw_current_luma[iPxPos] = fLuma; }
#endif

#if defined(FSR3UPSCALER_BIND_UAV_LUMA_INSTABILITY)
[[vk::binding(48, 0)]] [format("r32f")] WTexture2D<FfxFloat32> rw_luma_instability;
void StoreLumaInstability(FfxUInt32x2 iPxPos, FfxFloat32 fLumaInstability) { rw_luma_instability[iPxPos] = fLumaInstability; }
#endif

#if defined(FSR3UPSCALER_BIND_UAV_NEW_LOCKS)
// Accumulate reads and clears the locks prepare reactivity wrote: r32float is read_write in core WebGPU.
[[vk::binding(49, 0)]] [format("r32f")] RWTexture2D<FfxFloat32> rw_new_locks;
FfxFloat32 LoadRwNewLocks(FfxUInt32x2 iPxPos) { return rw_new_locks.Load(FfxInt32x2(iPxPos)); }
void StoreNewLocks(FfxUInt32x2 iPxPos, FfxFloat32 newLock) { rw_new_locks[iPxPos] = newLock; }
#endif

#if defined(FSR3UPSCALER_BIND_UAV_DILATED_DEPTH)
[[vk::binding(50, 0)]] [format("r32f")] WTexture2D<FfxFloat32> rw_dilated_depth;
void StoreDilatedDepth(FFX_PARAMETER_IN FfxUInt32x2 iPxPos, FFX_PARAMETER_IN FfxFloat32 fDepth) { rw_dilated_depth[iPxPos] = fDepth; }
#endif

#if defined(FSR3UPSCALER_BIND_UAV_DILATED_MOTION_VECTORS)
[[vk::binding(51, 0)]] [format("rg32f")] WTexture2D<FfxFloat32x2> rw_dilated_motion_vectors;
void StoreDilatedMotionVector(FFX_PARAMETER_IN FfxUInt32x2 iPxPos, FFX_PARAMETER_IN FfxFloat32x2 fMotionVector) { rw_dilated_motion_vectors[iPxPos] = fMotionVector; }
#endif

#if defined(FSR3UPSCALER_BIND_UAV_DILATED_REACTIVE_MASKS)
[[vk::binding(52, 0)]] [format("rgba8")] WTexture2D<FfxFloat32x4> rw_dilated_reactive_masks;
void StoreDilatedReactiveMasks(FFX_PARAMETER_IN FfxUInt32x2 iPxPos, FFX_PARAMETER_IN FfxFloat32x4 fDilatedReactiveMasks) { rw_dilated_reactive_masks[iPxPos] = fDilatedReactiveMasks; }
#endif

#if defined(FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_0)
// SPD mips 0..5 (storage views of one rg32float texture). Mip 5 is read only by the luma pyramid tail, which binds it
// as a sampled texture (FSR3_VEACH_SPD_TAIL) instead of relying on globallycoherent cross-workgroup visibility.
[[vk::binding(53, 0)]] [format("rg32f")] WTexture2D<FfxFloat32x2> rw_spd_mip0;
[[vk::binding(54, 0)]] [format("rg32f")] WTexture2D<FfxFloat32x2> rw_spd_mip1;
[[vk::binding(55, 0)]] [format("rg32f")] WTexture2D<FfxFloat32x2> rw_spd_mip2;
[[vk::binding(56, 0)]] [format("rg32f")] WTexture2D<FfxFloat32x2> rw_spd_mip3;
[[vk::binding(57, 0)]] [format("rg32f")] WTexture2D<FfxFloat32x2> rw_spd_mip4;
#if !defined(FSR3_VEACH_SPD_TAIL)
[[vk::binding(58, 0)]] [format("rg32f")] WTexture2D<FfxFloat32x2> rw_spd_mip5;
#else
[[vk::binding(31, 0)]] Texture2D<FfxFloat32x2> r_spd_mip5;
#endif

FfxFloat32x2 RWLoadPyramid(FFX_PARAMETER_IN FfxInt32x2 iPxPos, FFX_PARAMETER_IN FfxUInt32 index)
{
#if defined(FSR3_VEACH_SPD_TAIL)
	if (index == 5) return r_spd_mip5.Load(FfxInt32x3(iPxPos, 0));
#endif
	return FfxFloat32x2(0, 0);
}

void StorePyramid(FFX_PARAMETER_IN FfxInt32x2 iPxPos, FFX_PARAMETER_IN FfxFloat32x2 outValue, FFX_PARAMETER_IN FfxUInt32 index)
{
	if (index == 0) rw_spd_mip0[iPxPos] = outValue;
	if (index == 1) rw_spd_mip1[iPxPos] = outValue;
	if (index == 2) rw_spd_mip2[iPxPos] = outValue;
	if (index == 3) rw_spd_mip3[iPxPos] = outValue;
	if (index == 4) rw_spd_mip4[iPxPos] = outValue;
#if !defined(FSR3_VEACH_SPD_TAIL)
	if (index == 5) rw_spd_mip5[iPxPos] = outValue;
#endif
}
#endif

// The SPD global atomic is not bound: the tail dispatch replaces the last-workgroup election.
void SPD_IncreaseAtomicCounter(inout FfxUInt32 spdCounter) { spdCounter = 0u; }
void SPD_ResetAtomicCounter() {}
