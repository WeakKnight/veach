// The NRD runtime compiled to WebAssembly, recorded as the reference for the TypeScript planner.
import createNRDModule, { type NRDModule } from '../../src/generated/nrd/nrd.mjs';
import { PLAN_SCRATCH_BYTES, createInstance, planDispatches, type Dispatch, type InstanceDesc } from '../../src/render/denoise/NrdConfig.mjs';
import { drive, type Scenario } from './scenarios';

export interface Recording { desc: InstanceDesc; frames: Dispatch[][] }

let module: Promise<NRDModule> | null = null;
export const wasmModule = () => (module ??= createNRDModule());

/** Plans every frame of the scenario with a fresh wasm instance. */
export async function recordWasm(scenario: Scenario): Promise<Recording> {
	const m = await wasmModule();
	const { context, desc } = createInstance(m, scenario.mode);
	const scratch = m._nrd_malloc(PLAN_SCRATCH_BYTES);
	try {
		const frames = [...drive(scenario)].map(c => planDispatches(m, context, scratch, c.matrices, c.params, c.ints));
		return { desc, frames };
	} finally {
		m._nrd_free(scratch);
		m._nrd_destroy(context);
	}
}
