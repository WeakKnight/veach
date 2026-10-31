// NRD settings shared by scripts/build-nrd.mjs and NrdDenoiser.ts (docs/Nrd.md). The build bakes storage
// formats into the generated WGSL from the dispatches these settings produce, so both must agree.

// Same register shifts as NRD's SPIR-V build: samplers 0+, constants 2, storage textures 3+, textures 20+.
export const SHIFT = { sampler: 0, constant: 2, storage: 3, texture: 20 };
// nrd::Denoiser values per instance; identifiers are indices. SH mode uses separate diffuse and specular
// denoisers: the combined REBLUR_DIFFUSE_SPECULAR_SH temporal accumulation writes 9 storage textures,
// WebGPU allows at most 8.
export const DENOISERS = { radiance: [6], sh: [2, 5] };

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

/** Creates an instance of the mode's denoisers with Veach's REBLUR settings. */
export function createInstance(module, mode) {
	const denoisers = DENOISERS[mode];
	const list = module._nrd_malloc(denoisers.length * 4);
	module.HEAPU32.set(denoisers, list >> 2);
	const context = module._nrd_create(list, denoisers.length);
	module._nrd_free(list);
	if (!context) throw new Error('NRD instance creation failed');
	const reblur = module._nrd_malloc(4 * 18);
	module.HEAPF32.set([...HIT_DISTANCE, 2, 30, 50, 1, 30, 0.15, 0.15, 0.02], reblur >> 2);
	module.HEAPU32.set([30, 6, 63, 3, 0, 0, 1], (reblur >> 2) + 11);
	const status = module._nrd_set_reblur(context, reblur, reblur + 44);
	module._nrd_free(reblur);
	if (status !== 0) throw new Error('NRD REBLUR settings rejected');
	return { context, desc: JSON.parse(module.UTF8ToString(module._nrd_instance_desc(context))) };
}

/** Bytes of the scratch block `planDispatches` writes: 4 matrices, 11 float and 7 integer parameters. */
export const PLAN_SCRATCH_BYTES = 4 * (64 + 11 + 7);

/**
 * Sets the common settings and returns this frame's dispatches (wasm/nrd_wasm.cpp layout).
 * `matrices` holds viewToClip, viewToClipPrev, worldToView, worldToViewPrev (column-major).
 */
export function planDispatches(module, context, scratch, matrices, params, ints) {
	const base = scratch >> 2;
	module.HEAPF32.set(matrices, base);
	module.HEAPF32.set(params, base + 64);
	module.HEAPU32.set(ints, base + 75);
	if (module._nrd_set_common(context, scratch, scratch + 256, scratch + 300) !== 0) throw new Error('NRD common settings rejected');
	const pointer = module._nrd_dispatches(context);
	if (!pointer) throw new Error('NRD GetComputeDispatches failed');
	const words = module.HEAPU32, bytes = module.HEAPU8;
	let at = pointer >> 2;
	const count = words[at++];
	const dispatches = [];
	for (let i = 0; i < count; i++) {
		const [pipeline, width, height, resourceCount, constantBytes, name] = words.subarray(at, at + 6);
		at += 6;
		const constants = bytes.slice(at * 4, at * 4 + constantBytes);
		at += Math.ceil(constantBytes / 4);
		const resources = [];
		for (let r = 0; r < resourceCount; r++, at += 3) resources.push({ descriptor: words[at], type: words[at + 1], index: words[at + 2] });
		dispatches.push({ pipeline, width, height, constants, resources, name: name ? module.UTF8ToString(name) : `nrd${pipeline}` });
	}
	return dispatches;
}

/** WebGPU format of a dispatch resource (pool textures by nrd::Format, user textures fixed). */
export function resourceFormat(desc, resource, tier1) {
	if (resource.type === PERMANENT_POOL) return poolFormat(desc.permanentPool[resource.index][0], tier1);
	if (resource.type === TRANSIENT_POOL) return poolFormat(desc.transientPool[resource.index][0], tier1);
	return userFormat(resource.type);
}

/** Generated shader variant for the storage texture formats a dispatch binds, in binding order. */
export const nrdVariantKey = formats => formats.join(',');
