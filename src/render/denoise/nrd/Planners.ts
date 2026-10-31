// NRD dispatch planners behind one interface (docs/Nrd.md): the NRD runtime compiled to WebAssembly, its
// TypeScript port (Planner.ts), or both, checking each frame of the port against the runtime.
import { DENOISERS, PLAN_SCRATCH_BYTES, REBLUR_FLOATS, REBLUR_INTS, createInstance, planDispatches, type Dispatch, type InstanceDesc, type NrdMode } from '../NrdConfig.mjs';
import type { NRDModule } from '../../../generated/nrd/nrd.mjs';
import { NrdPlanner } from './Planner';

export type NrdPlannerKind = 'wasm' | 'ts' | 'both';
export interface Planner {
	readonly kind: NrdPlannerKind;
	readonly desc: InstanceDesc;
	/** planDispatches' common settings layout (NrdConfig.mjs). */
	plan(matrices: ArrayLike<number>, params: ArrayLike<number>, ints: ArrayLike<number>): Dispatch[];
	destroy(): void;
}

async function loadWasm(): Promise<NRDModule> {
	const { default: createNRDModule } = await import('../../../generated/nrd/nrd.mjs');
	return createNRDModule();
}

function wasmPlanner(module: NRDModule, mode: NrdMode): Planner {
	const { context, desc } = createInstance(module, mode);
	const scratch = module._nrd_malloc(PLAN_SCRATCH_BYTES);
	return {
		kind: 'wasm', desc,
		plan: (matrices, params, ints) => planDispatches(module, context, scratch, matrices, params, ints),
		destroy: () => { module._nrd_free(scratch); module._nrd_destroy(context); },
	};
}

function tsPlanner(mode: NrdMode, now?: () => number): Planner {
	const planner = new NrdPlanner(DENOISERS[mode], now);
	planner.setReblur(REBLUR_FLOATS, REBLUR_INTS);
	return { kind: 'ts', desc: planner.desc, plan: (m, p, i) => planner.plan(m, p, i), destroy: () => {} };
}

/** Records the Date.now values a call reads (the wasm timer), for the TypeScript timer to read in turn. */
class ReplayClock {
	private readonly values: number[] = [];
	record<T>(call: () => T): T {
		const now = Date.now;
		Date.now = () => { const value = now(); this.values.push(value); return value; };
		try { return call(); } finally { Date.now = now; }
	}
	readonly now = () => this.values.shift() ?? Date.now();
}

// gRotatorPre / gRotator / gRotatorPost: cosf / sinf versus Math.cos / Math.sin may differ by one ulp.
const ROTATOR_WORDS = [96, 108] as const;
const ulps = (a: number, b: number) => { const o = (u: number) => (u & 0x80000000 ? 0x80000000 - u : u + 0x80000000); return Math.abs(o(a) - o(b)); };

/** First difference between two frames of dispatches, or null. */
export function planDifference(expected: Dispatch[], actual: Dispatch[]): string | null {
	if (actual.length !== expected.length) return `${actual.length} dispatches, expected ${expected.length}`;
	for (let i = 0; i < expected.length; i++) {
		const a = expected[i], b = actual[i];
		if (a.pipeline !== b.pipeline || a.width !== b.width || a.height !== b.height || a.name !== b.name || JSON.stringify(a.resources) !== JSON.stringify(b.resources))
			return `dispatch ${i} (${a.name}) differs`;
		if (a.constants.length !== b.constants.length) return `dispatch ${i} (${a.name}): ${b.constants.length} constant bytes, expected ${a.constants.length}`;
		const wa = new Uint32Array(a.constants.buffer, a.constants.byteOffset, a.constants.length >> 2);
		const wb = new Uint32Array(b.constants.buffer, b.constants.byteOffset, b.constants.length >> 2);
		for (let w = 0; w < wa.length; w++) {
			if (wa[w] === wb[w] || (!a.name.startsWith('Clear') && w >= ROTATOR_WORDS[0] && w < ROTATOR_WORDS[1] && ulps(wa[w], wb[w]) <= 1)) continue;
			return `dispatch ${i} (${a.name}) constant word ${w}: 0x${wb[w].toString(16)}, expected 0x${wa[w].toString(16)}`;
		}
	}
	return null;
}

/** Plans with the wasm runtime and checks the TypeScript port against it every frame (console.error on divergence). */
async function checkedPlanner(mode: NrdMode): Promise<Planner> {
	const clock = new ReplayClock(), module = await loadWasm();
	const wasm = clock.record(() => wasmPlanner(module, mode)); // NRD's timer starts with the instance
	const ts = tsPlanner(mode, clock.now);
	if (JSON.stringify(ts.desc) !== JSON.stringify(wasm.desc)) console.error('NRD TypeScript planner: instance description differs from the wasm runtime');
	let frame = 0, reported = 0;
	return {
		kind: 'both', desc: wasm.desc,
		plan: (matrices, params, ints) => {
			const expected = clock.record(() => wasm.plan(matrices, params, ints));
			const difference = planDifference(expected, ts.plan(matrices, params, ints));
			if (difference && reported++ < 8) console.error(`NRD TypeScript planner differs from the wasm runtime at frame ${frame}: ${difference}`);
			frame++;
			return expected;
		},
		destroy: () => { wasm.destroy(); ts.destroy(); },
	};
}

export async function createPlanner(kind: NrdPlannerKind, mode: NrdMode): Promise<Planner> {
	if (kind === 'ts') return tsPlanner(mode);
	if (kind === 'both') return checkedPlanner(mode);
	return wasmPlanner(await loadWasm(), mode);
}
