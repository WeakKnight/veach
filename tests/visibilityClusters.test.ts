import { describe, expect, it } from 'vitest';
import { buildVisibilityClusters, relocateVisibilityClusters } from '../src/render/VisibilityClusters';

describe('visibility geometry clusters', () => {
	it('preserves every primitive identity exactly once and encloses all referenced vertices', () => {
		const positions = new Float32Array(137 * 9), indices = Uint32Array.from({ length: 137 * 3 }, (_, i) => i);
		for (let t = 0; t < 137; t++) positions.set([t % 7, t % 13, t, t % 7 + 1, t % 13, t, t % 7, t % 13 + 1, t], t * 9);
		const original = indices.slice(), c = buildVisibilityClusters(positions, indices), words = relocateVisibilityClusters(c, 113);
		const floats = new Float32Array(words.buffer), seen: number[] = [];
		expect(c.count).toBe(3); expect(indices).toEqual(original);
		for (let cluster = 0; cluster < c.count; cluster++) {
			const base = cluster * 8, count = words[base + 7], begin = words[base + 3] - 113;
			expect(count).toBeGreaterThan(0); expect(count).toBeLessThanOrEqual(64);
			for (let i = 0; i < count; i++) {
				const primitive = words[begin + i]; seen.push(primitive);
				for (let v = 0; v < 3; v++) for (let axis = 0; axis < 3; axis++) {
					const value = positions[indices[primitive * 3 + v] * 3 + axis];
					expect(value).toBeGreaterThanOrEqual(floats[base + axis]); expect(value).toBeLessThanOrEqual(floats[base + 4 + axis]);
				}
			}
		}
		expect(seen.sort((a, b) => a - b)).toEqual(Array.from({ length: 137 }, (_, i) => i));
		expect(buildVisibilityClusters(positions, indices)).toEqual(c);
	});
	it('handles empty and degenerate geometry without invalid offsets', () => {
		expect(buildVisibilityClusters(new Float32Array(), new Uint32Array()).count).toBe(0);
		const c = buildVisibilityClusters(new Float32Array([1, 1, 1]), new Uint32Array([0, 0, 0]));
		expect(c.count).toBe(1); expect(c.words[3]).toBe(8); expect(c.words[7]).toBe(1); expect(c.words[8]).toBe(0);
	});
});
