import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { opaqueMaterialShader } from '../src/render/OpaqueMaterialShader';
import { opaqueMaterialStackVariants } from '../src/generated/shaders/OpaqueMaterialStackVariants';
import { restoreMaterialShaderVariant, type MaterialStackCapacity } from '../src/render/MaterialShaderVariants';

describe('opaque traversal shader variants', () => {
	const source = readFileSync(new URL('../src/generated/shaders/PathTracingOpaque.wgsl', import.meta.url), 'utf8');
	for (const capacity of [0, 1, 2, 4, 8] as MaterialStackCapacity[]) {
		it(`matches independent Slang output at capacity ${capacity}`, () => {
			const code = opaqueMaterialShader(capacity);
			expect(createHash('sha256').update(code).digest('hex')).toBe(opaqueMaterialStackVariants.variants[capacity].sha256);
			expect(restoreMaterialShaderVariant(source.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n'), capacity, opaqueMaterialStackVariants)).toBe(code);
		});
	}
	it('preserves capacity16 and rejects stale sources', () => {
		expect(opaqueMaterialShader(16)).toBe(source.replaceAll('\r\n', '\n'));
		expect(() => restoreMaterialShaderVariant(source + '\n// stale', 1, opaqueMaterialStackVariants)).toThrow('Stale');
	});
});
