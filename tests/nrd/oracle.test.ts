// Phase 0 of the TypeScript NRD planner migration: the wasm reference is reproducible and its recordings
// cover the paths the host reaches (docs/Nrd.md).
import { describe, expect, it } from 'vitest';
import { DESCRIPTOR_TEXTURE, PERMANENT_POOL } from '../../src/render/denoise/NrdConfig.mjs';
import { recordWasm } from './oracle';
import { scenarios } from './scenarios';

describe('NRD wasm reference', () => {
	for (const scenario of scenarios()) {
		it(`is deterministic with a fixed time delta: ${scenario.mode} ${scenario.name}`, async () => {
			const [a, b] = [await recordWasm(scenario), await recordWasm(scenario)];
			expect(b).toEqual(a);
			expect(a.frames).toHaveLength(scenario.frames.length);
			for (const frame of a.frames) expect(frame.length).toBeGreaterThan(0);
		});
	}

	it('covers resets, steady frames and ping-pong swaps', async () => {
		for (const mode of ['radiance', 'sh', 'diffuse-sh'] as const) {
			const { frames } = await recordWasm(scenarios().find(s => s.mode === mode && s.name === 'steady')!);
			// Resets prepend clears of every storage texture; steady frames have the denoiser passes only.
			expect(frames[0].length).toBeGreaterThan(frames[1].length);
			expect(new Set(frames.slice(1).map(f => f.length)).size).toBe(1);
			// Permanent ping-pong histories alternate between frames.
			const permanent = (f: typeof frames[0]) => f.flatMap(d => d.resources.filter(r => r.type === PERMANENT_POOL && r.descriptor !== DESCRIPTOR_TEXTURE).map(r => r.index));
			expect(permanent(frames[1])).not.toEqual(permanent(frames[2]));
			expect(permanent(frames[1])).toEqual(permanent(frames[3]));
		}
	});
});
