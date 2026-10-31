// NRD settings shared by scripts/build-nrd.mjs, NrdDenoiser.ts and the TypeScript planner (docs/Nrd.md). The
// build bakes storage formats into the generated WGSL from the dispatches these settings produce.

// Same register shifts as NRD's SPIR-V build: samplers 0+, constants 2, storage textures 3+, textures 20+.
export const SHIFT = { sampler: 0, constant: 2, storage: 3, texture: 20 };
// nrd::Denoiser values per instance; identifiers are indices. SH mode uses separate diffuse and specular
// denoisers: the combined REBLUR_DIFFUSE_SPECULAR_SH temporal accumulation writes 9 storage textures,
// WebGPU allows at most 8. 'diffuse-sh' (REBLUR_DIFFUSE_SH only) serves SSSR frames, whose reflections
// come from FidelityFX SSSR instead (docs/Sssr.md).
export const DENOISERS = { radiance: [6], sh: [2, 5], 'diffuse-sh': [2] };

export const DESCRIPTOR_TEXTURE = 0;
export const IN_MV = 0, IN_NORMAL_ROUGHNESS = 1, IN_VIEWZ = 2, IN_DIFF = 6, IN_SPEC = 7, IN_DIFF_SH0 = 11, IN_DIFF_SH1 = 12, IN_SPEC_SH0 = 13, IN_SPEC_SH1 = 14;
export const OUT_DIFF = 18, OUT_SPEC = 19, OUT_DIFF_SH0 = 20, OUT_DIFF_SH1 = 21, OUT_SPEC_SH0 = 22, OUT_SPEC_SH1 = 23, OUT_VALIDATION = 29, TRANSIENT_POOL = 30, PERMANENT_POOL = 31;
export const ACCUMULATION_CONTINUE = 0, ACCUMULATION_CLEAR_AND_RESTART = 2;
// Sky and other surfaceless pixels are written beyond the denoising range (NrdPasses.slang).
export const DENOISING_RANGE = 1e6;
export const HIT_DISTANCE = [3, 0.1, 20]; // REBLUR defaults (A, B, C), shared with Prepare

// nrd::Format -> [texture-formats-tier1 format, core WebGPU storage fallback]. Fallbacks only widen precision;
// normalized formats without a WebGPU storage equivalent are stored as floats (NRD writes values in range).
export const FORMATS = {
	0: ['r8unorm', 'rgba8unorm'], 1: ['r8snorm', 'r32float'], 2: ['r8uint', 'r32uint'], 3: ['r8sint', 'r32sint'],
	4: ['rg8unorm', 'rgba8unorm'], 5: ['rg8snorm', 'rg32float'], 6: ['rg8uint', 'rg32uint'], 7: ['rg8sint', 'rg32sint'],
	8: ['rgba8unorm', 'rgba8unorm'], 9: ['rgba8snorm', 'rgba8snorm'], 10: ['rgba8uint', 'rgba8uint'], 11: ['rgba8sint', 'rgba8sint'], 12: ['rgba8unorm', 'rgba8unorm'],
	13: ['r16float', 'r32float'], 14: ['r16float', 'r32float'], 15: ['r16uint', 'r32uint'], 16: ['r16sint', 'r32sint'], 17: ['r16float', 'r32float'],
	18: ['rg16float', 'rg32float'], 19: ['rg16float', 'rg32float'], 20: ['rg16uint', 'rg32uint'], 21: ['rg16sint', 'rg32sint'], 22: ['rg16float', 'rgba16float'],
	23: ['rgba32float', 'rgba32float'], 24: ['rgba32float', 'rgba32float'], 25: ['rgba16uint', 'rgba16uint'], 26: ['rgba16sint', 'rgba16sint'], 27: ['rgba16float', 'rgba16float'],
	28: ['r32uint', 'r32uint'], 29: ['r32sint', 'r32sint'], 30: ['r32float', 'r32float'],
	31: ['rg32uint', 'rg32uint'], 32: ['rg32sint', 'rg32sint'], 33: ['rg32float', 'rg32float'],
	37: ['rgba32uint', 'rgba32uint'], 38: ['rgba32sint', 'rgba32sint'], 39: ['rgba32float', 'rgba32float'],
	40: ['rgb10a2unorm', 'rgba16float'], 41: ['rgb10a2uint', 'rgba32uint'], 42: ['rg11b10ufloat', 'rgba16float'], 43: ['rgba16float', 'rgba16float'],
};
const USER_FORMAT = { [IN_VIEWZ]: 'r32float', [OUT_VALIDATION]: 'rgba8unorm' };
export const userFormat = type => USER_FORMAT[type] ?? 'rgba16float';

export function poolFormat(nrd, tier1) {
	const pair = FORMATS[nrd];
	if (!pair) throw new Error(`NRD texture format ${nrd} has no WebGPU mapping`);
	return pair[tier1 ? 0 : 1];
}

// Veach's REBLUR settings in nrd_set_reblur order (wasm/nrd_wasm.cpp): hit distance A B C,
// fastHistoryClampingSigmaScale, diffuse/specular prepass radius, min/max blur radius, lobeAngleFraction,
// roughnessFraction, planeDistanceSensitivity; maxAccumulatedFrameNum, maxFastAccumulatedFrameNum,
// maxStabilizedFrameNum, historyFixFrameNum, checkerboardMode, hitDistanceReconstructionMode, enableAntiFirefly.
export const REBLUR_FLOATS = [...HIT_DISTANCE, 2, 30, 50, 1, 30, 0.15, 0.15, 0.02];
export const REBLUR_INTS = [30, 6, 63, 3, 0, 0, 1];

/** WebGPU format of a dispatch resource (pool textures by nrd::Format, user textures fixed). */
export function resourceFormat(desc, resource, tier1) {
	if (resource.type === PERMANENT_POOL) return poolFormat(desc.permanentPool[resource.index][0], tier1);
	if (resource.type === TRANSIENT_POOL) return poolFormat(desc.transientPool[resource.index][0], tier1);
	return userFormat(resource.type);
}

/** Generated shader variant for the storage texture formats a dispatch binds, in binding order. */
export const nrdVariantKey = formats => formats.join(',');
