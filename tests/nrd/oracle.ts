// The NRD runtime compiled to WebAssembly, recorded as the reference for the TypeScript planner, and the
// TypeScript planner recorded the same way.
import createNRDModule, { type NRDModule } from '../../src/generated/nrd/nrd.mjs';
import { DENOISERS, PLAN_SCRATCH_BYTES, REBLUR_FLOATS, REBLUR_INTS, createInstance, planDispatches, type Dispatch, type InstanceDesc } from '../../src/render/denoise/NrdConfig.mjs';
import { NrdPlanner } from '../../src/render/denoise/nrd/Planner';
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

/** The same scenario through the TypeScript planner. */
export function recordTs(scenario: Scenario, now?: () => number): Recording {
	const planner = new NrdPlanner(DENOISERS[scenario.mode], now);
	planner.setReblur(REBLUR_FLOATS, REBLUR_INTS);
	return { desc: planner.desc, frames: [...drive(scenario)].map(c => planner.plan(c.matrices, c.params, c.ints)) };
}
