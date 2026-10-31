// Phase 3 of the TypeScript NRD planner migration: the switchable planners NrdDenoiser uses.
import { afterEach, describe, expect, it, vi } from 'vitest';
import { createPlanner, planDifference } from '../../src/render/denoise/nrd/Planners';
import { drive, scenarios } from './scenarios';

describe('NRD planners', () => {
	afterEach(() => { vi.restoreAllMocks(); });

	for (const mode of ['radiance', 'sh'] as const) {
		it(`'both' reports no divergence on the real clock: ${mode}`, async () => {
			const error = vi.spyOn(console, 'error').mockImplementation(() => {});
			const planner = await createPlanner('both', mode);
			const base = scenarios().find(s => s.mode === mode && s.name === 'resets')!;
			// timeDelta 0: both timers measure Date.now, as in production.
			for (const c of drive({ ...base, frames: base.frames.map(frame => ({ ...frame, timeDelta: 0 })) })) {
				planner.plan(c.matrices, c.params, c.ints);
				await new Promise(resolve => setTimeout(resolve, 3));
			}
			planner.destroy();
			expect(error).not.toHaveBeenCalled();
		});
	}

	it('finds a one-bit constant difference', async () => {
		const wasm = await createPlanner('wasm', 'radiance');
		const c = [...drive(scenarios()[0])][0];
		const expected = wasm.plan(c.matrices, c.params, c.ints);
		wasm.destroy();
		const actual = expected.map(d => ({ ...d, constants: d.constants.slice() }));
		expect(planDifference(expected, actual)).toBeNull();
		const last = actual[actual.length - 1];
		last.constants[200] ^= 1;
		expect(planDifference(expected, actual)).toMatch(/constant word 50/);
	});

	it("'ts' plans without the wasm runtime", async () => {
		const planner = await createPlanner('ts', 'sh');
		expect(planner.kind).toBe('ts');
		const c = [...drive(scenarios().find(s => s.mode === 'sh')!)][0];
		expect(planner.plan(c.matrices, c.params, c.ints).length).toBeGreaterThan(0);
	});
});
