// The NRD runtime compiled to WebAssembly (tests/generated/nrd, built by build:nrd): the reference the
// TypeScript planner is tested against. Not part of the renderer.
import { DENOISERS, REBLUR_FLOATS, REBLUR_INTS, type Dispatch, type InstanceDesc, type NrdMode } from '../../src/render/denoise/NrdConfig.mjs';
import type { NRDModule } from '../generated/nrd/nrd.mjs';

/** Creates an instance of the mode's denoisers with Veach's REBLUR settings. */
export function createInstance(module: NRDModule, mode: NrdMode): { context: number; desc: InstanceDesc } {
	const denoisers = DENOISERS[mode];
	const list = module._nrd_malloc(denoisers.length * 4);
	module.HEAPU32.set(denoisers, list >> 2);
	const context = module._nrd_create(list, denoisers.length);
	module._nrd_free(list);
	if (!context) throw new Error('NRD instance creation failed');
	const reblur = module._nrd_malloc(4 * 18);
	module.HEAPF32.set(REBLUR_FLOATS, reblur >> 2);
	module.HEAPU32.set(REBLUR_INTS, (reblur >> 2) + 11);
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
export function planDispatches(module: NRDModule, context: number, scratch: number, matrices: ArrayLike<number>, params: ArrayLike<number>, ints: ArrayLike<number>): Dispatch[] {
	const base = scratch >> 2;
	module.HEAPF32.set(Array.from(matrices), base);
	module.HEAPF32.set(Array.from(params), base + 64);
	module.HEAPU32.set(Array.from(ints), base + 75);
	if (module._nrd_set_common(context, scratch, scratch + 256, scratch + 300) !== 0) throw new Error('NRD common settings rejected');
	const pointer = module._nrd_dispatches(context);
	if (!pointer) throw new Error('NRD GetComputeDispatches failed');
	const words = module.HEAPU32, bytes = module.HEAPU8;
	let at = pointer >> 2;
	const count = words[at++];
	const dispatches: Dispatch[] = [];
	for (let i = 0; i < count; i++) {
		const [pipeline, width, height, resourceCount, constantBytes, name] = words.subarray(at, at + 6);
		at += 6;
		const constants = bytes.slice(at * 4, at * 4 + constantBytes);
		at += Math.ceil(constantBytes / 4);
		const resources: Dispatch['resources'] = [];
		for (let r = 0; r < resourceCount; r++, at += 3) resources.push({ descriptor: words[at], type: words[at + 1], index: words[at + 2] });
		dispatches.push({ pipeline, width, height, constants, resources, name: name ? module.UTF8ToString(name) : `nrd${pipeline}` });
	}
	return dispatches;
}
