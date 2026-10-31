// Phase 2 of the TypeScript NRD planner migration: per-frame dispatches and constant buffers match the
// wasm runtime frame by frame.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { DENOISERS, type Dispatch } from '../../src/render/denoise/NrdConfig.mjs';
import { NrdPlanner } from '../../src/render/denoise/nrd/Planner';
import createNRDModule from '../generated/nrd/nrd.mjs';
import { recordTs, recordWasm, type Recording } from './oracle';
import { PLAN_SCRATCH_BYTES, createInstance, planDispatches } from './wasm';
import { drive, scenarios, type Scenario } from './scenarios';

// Constant buffer member names by 32-bit word, from the vendored REBLUR_SHARED_CONSTANTS and ClearConstants.
const SIZES: Record<string, number> = { float4x4: 16, float4: 4, float2: 2, int2: 2, uint2: 2, float: 1, int: 1, uint: 1 };
function words(block: string): string[] {
	return [...block.matchAll(/NRD_CONSTANT\(\s*(\w+)\s*,\s*(\w+)\s*\)/g)].flatMap(([, type, name]) => Array.from({ length: SIZES[type] }, (_, i) => `${name}[${i}]`));
}
const shaders = join(__dirname, '../../ThirdParty/NRD/Shaders');
const read = (file: string) => readFileSync(join(shaders, file), 'utf8').replaceAll('\r\n', '\n');
const SHARED = words(read('REBLUR_Config.hlsli').match(/#define REBLUR_SHARED_CONSTANTS \\\n([\s\S]*?)\n\n/)![1]);
const CLEAR = words(read('Clear.resources.hlsli').match(/NRD_CONSTANTS_START\(\s*ClearConstants\s*\)([\s\S]*?)NRD_CONSTANTS_END/)![1]);
// cosf / sinf (musl) versus Math.cos / Math.sin rounded to float32 may differ by one unit in the last place.
const LIBM = /^gRotator(Pre|Post)?\[/;

// Distance in float32 units in the last place (sign-magnitude ordered).
const ulps = (a: number, b: number) => { const o = (u: number) => (u & 0x80000000 ? 0x80000000 - u : u + 0x80000000); return Math.abs(o(a) - o(b)); };

/** Every difference between two recordings, in readable form; empty when equal. */
function differences(expected: Recording, actual: Recording, limit = 20): string[] {
	const out: string[] = [];
	if (actual.frames.length !== expected.frames.length) return [`frame count ${actual.frames.length} != ${expected.frames.length}`];
	expected.frames.forEach((frame, i) => {
		const other = actual.frames[i];
		if (other.length !== frame.length) { out.push(`frame ${i}: ${other.length} dispatches, expected ${frame.length}: ${other.map(d => d.name).join(', ')}`); return; }
		frame.forEach((d: Dispatch, j) => {
			const o = other[j], at = `frame ${i} dispatch ${j} (${d.name})`;
			const { constants: _a, ...shape } = d, { constants: _b, ...otherShape } = o;
			if (JSON.stringify(shape) !== JSON.stringify(otherShape)) out.push(`${at}: ${JSON.stringify(otherShape)} != ${JSON.stringify(shape)}`);
			if (o.constants.length !== d.constants.length) { out.push(`${at}: ${o.constants.length} constant bytes, expected ${d.constants.length}`); return; }
			const names = d.name.startsWith('Clear') ? CLEAR : SHARED;
			const a = new Uint32Array(d.constants.buffer, d.constants.byteOffset, d.constants.length / 4);
			const b = new Uint32Array(o.constants.buffer, o.constants.byteOffset, o.constants.length / 4);
			for (let w = 0; w < a.length; w++) {
				if (a[w] === b[w]) continue;
				const name = names[w] ?? `word ${w}`;
				if (LIBM.test(name) && ulps(a[w], b[w]) <= 1) continue;
				const fa = new Float32Array(Uint32Array.of(a[w]).buffer)[0], fb = new Float32Array(Uint32Array.of(b[w]).buffer)[0];
				out.push(`${at} ${name}: ${fb} (0x${b[w].toString(16)}) != ${fa} (0x${a[w].toString(16)}), ${ulps(a[w], b[w])} ulp`);
			}
		});
		if (out.length > limit) out.length = limit;
	});
	return out;
}

describe('NRD TypeScript planner', () => {
	afterEach(() => { vi.restoreAllMocks(); });

	for (const scenario of scenarios()) {
		it(`matches the wasm dispatches and constants: ${scenario.mode} ${scenario.name}`, async () => {
			const wasm = await recordWasm(scenario);
			const ts = recordTs(scenario);
			expect(ts.desc).toEqual(wasm.desc);
			expect(differences(wasm, ts)).toEqual([]);
		});
	}

	// Production passes timeDelta 0: NRD then measures frame times with its timer (Date.now through Emscripten).
	for (const mode of ['radiance', 'sh', 'diffuse-sh'] as const) {
		it(`measures frame times like the wasm timer: ${mode}`, async () => {
			const base = scenarios().find(s => s.mode === mode && s.name === 'motion')!;
			const scenario: Scenario = { ...base, frames: base.frames.map(frame => ({ ...frame, timeDelta: 0 })) };
			const clock = () => { let t = 1_793_400_000_000, step = 0; return () => (t += [7, 16, 17, 33, 0, 250][step++ % 6]); };
			let now = clock();
			vi.spyOn(Date, 'now').mockImplementation(() => now());
			const wasm = await recordWasm(scenario);
			now = clock();
			const ts = recordTs(scenario);
			expect(differences(wasm, ts)).toEqual([]);
		});
	}

	it('rejects the same invalid common settings', async () => {
		const valid = [...drive(scenarios()[0])][0];
		const invalid = [
			{ ...valid, ints: [0, ...valid.ints.slice(1)] }, // zero width
			{ ...valid, params: [...valid.params.slice(0, 3), 0.75, ...valid.params.slice(4)] }, // jitter outside [-0.5, 0.5]
			{ ...valid, params: [...valid.params.slice(0, 9), 0, valid.params[10]] }, // viewZScale 0
		];
		for (const c of invalid) {
			// The wasm build keeps NRD's asserts, which abort the module: use a fresh one each time.
			const m = await createNRDModule(), { context } = createInstance(m, 'radiance'), scratch = m._nrd_malloc(PLAN_SCRATCH_BYTES);
			expect(() => planDispatches(m, context, scratch, c.matrices, c.params, c.ints)).toThrow();
			expect(() => new NrdPlanner(DENOISERS.radiance).plan(c.matrices, c.params, c.ints)).toThrow('NRD common settings rejected');
		}
	});
});
