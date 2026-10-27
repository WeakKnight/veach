import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { materialStackVariants } from '../src/generated/shaders/MaterialStackVariants';
import { materialStackCapacity, specializeMaterialShader, type MaterialStackCapacity } from '../src/render/MaterialShaderVariants';

describe('compiled material stack variants', () => {
	for (const program of ['PathTracing', 'Wavefront'] as const) {
		const source = readFileSync(new URL(`../src/generated/shaders/${program}.wgsl`, import.meta.url), 'utf8');
		for (const capacity of [0, 1, 2, 4, 8] as MaterialStackCapacity[]) {
			it(`reconstructs the independent Slang ${program}/${capacity} output exactly`, () => {
				const generated = specializeMaterialShader(source, program, capacity);
				expect(createHash('sha256').update(generated).digest('hex')).toBe(materialStackVariants[program].variants[capacity].sha256);
				const windowsSource = source.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');
				expect(specializeMaterialShader(windowsSource, program, capacity)).toBe(generated);
			});
		}
		it(`rejects stale generated edits for ${program}`, () => {
			expect(() => specializeMaterialShader(source + '\n// source changed', program, 1)).toThrow('Stale');
		});
		it(`preserves the full ${program} fallback`, () => {
			expect(specializeMaterialShader(source, program, 16)).toBe(source.replaceAll('\r\n', '\n'));
		});
	}

	it('rounds compiler bounds up without exceeding the bytecode limit', () => {
		const cases = [[0, 0], [1, 1], [2, 2], [3, 4], [4, 4], [5, 8], [8, 8], [9, 16], [16, 16]];
		for (const [required, capacity] of cases) expect(materialStackCapacity(required)).toBe(capacity);
		for (const required of [-1, 0.5, 17, Number.NaN]) expect(() => materialStackCapacity(required)).toThrow('Invalid');
	});
});
