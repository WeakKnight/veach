import { describe, expect, it } from 'vitest';
import { balancedMeasurementOrder } from '../scripts/benchmark-order.mjs';

describe('paired measurement positions', () => {
	for (const size of [2, 3, 4, 7, 8]) {
		it(`balances all ${size} variants in both forward and reverse cycles`, () => {
			const variants = Object.freeze(Array.from({ length: size }, (_, id) => ({ id })));
			for (let cycle = 0; cycle < 2; cycle++) {
				const counts = Array.from({ length: size }, () => Array(size).fill(0));
				for (let round = 0; round < size; round++) {
					const order = balancedMeasurementOrder(variants, cycle * size + round);
					expect(new Set(order).size).toBe(size);
					for (const [position, variant] of order.entries()) {
						expect(variant).toBe(variants[variant.id]);
						counts[variant.id][position]++;
					}
					if (cycle === 1) expect(order).toEqual(balancedMeasurementOrder(variants, round).reverse());
				}
				expect(counts.flat().every(count => count === 1)).toBe(true);
			}
		});
	}
	it('rejects invalid round indices and empty schedules', () => {
		for (const round of [-1, 0.5, Number.NaN, Number.POSITIVE_INFINITY]) {
			expect(() => balancedMeasurementOrder(['a'], round)).toThrow('Invalid');
		}
		expect(() => balancedMeasurementOrder([], 0)).toThrow('Invalid');
	});
});
