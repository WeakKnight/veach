import { createHash } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { encodeVariant } from '../scripts/material-stack-variants.mjs';

function check(base: string, variant: string) {
	const encoded = encodeVariant(base, variant);
	let cursor = 0, restored = '';
	for (const [offset, oldLength, newText] of encoded.edits) {
		expect(offset).toBeGreaterThanOrEqual(cursor);
		expect(oldLength).toBeGreaterThanOrEqual(0);
		expect(offset + oldLength).toBeLessThanOrEqual(base.length);
		restored += base.slice(cursor, offset) + newText;
		cursor = offset + oldLength;
	}
	expect(restored + base.slice(cursor)).toBe(variant);
	expect(encoded.sha256).toBe(createHash('sha256').update(variant).digest('hex'));
}

describe('lossless shader variant encoding', () => {
	it('preserves EOF and empty-line changes', () => {
		for (const a of ['', '\n', 'a', 'a\n', 'a\n\n', '\na\nb'])
			for (const b of ['', '\n', 'a', 'a\n', 'a\n\n', '\na\nb']) check(a, b);
	});

	it('reuses unchanged functions across insertion, deletion and reordering', () => {
		const a = 'fn a() {\n    return 1;\n}\n';
		const b = 'fn b() {\n    return 2;\n}\n';
		const c = 'fn c() {\n    return 3;\n}\n';
		for (const variant of [a + c, c + a, b + c + a, a + b + c]) check(a + b, variant);
	});

	it('round-trips deterministic edits with repeated shader-like lines', () => {
		let seed = 12345;
		const random = (n: number) => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed % n; };
		for (let trial = 0; trial < 1000; trial++) {
			const a = Array.from({ length: random(100) }, () => ['}', '{', `unique-${random(500)}`, '', 'same'][random(5)]);
			const b = [...a];
			for (let i = 0; i < 20; i++) b.splice(random(b.length + 1), random(4), ...Array.from({ length: random(4) }, () => String(random(20))));
			check(a.join('\n'), b.join('\n'));
		}
	});
});
