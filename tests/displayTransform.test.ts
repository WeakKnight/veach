import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { BUILTIN_LUTS } from '../src/render/color/BuiltinLUTs';
import { encodeFLog2, evaluateDisplayTransform, parseCubeLUT, parseLUT3D, sampleLUT3D, snapshotDisplayTransform, type LUT3D, type LUTDisplayTransform } from '../src/render/color/LUT';
import provenance from '../src/render/color/looks/provenance.json';
import { defaultRenderSettings, LocalExposureMethod } from '../src/render/Renderer';
import { Tonemapper } from '../src/render/GpuLayout';

function identity(): LUT3D {
	const values = new Float32Array(24);
	for (let i = 0; i < 8; i++) values.set([i & 1, (i >> 1) & 1, (i >> 2) & 1], i * 3);
	return { size: 2, values, domainMin: [0, 0, 0], domainMax: [1, 1, 1] };
}
const transform = (lut = identity()): LUTDisplayTransform => ({ type: 'lut', lut, input: { primaries: 'rec709', transfer: 'linear' }, output: { primaries: 'rec709', transfer: 'linear' } });

describe('display LUT parsing and sampling', () => {
	it('reads explicit little-endian RGB binary without swapping axes', () => {
		const lut = identity();
		const bytes = new ArrayBuffer(96), view = new DataView(bytes);
		lut.values.forEach((v, i) => view.setFloat32(i * 4, v, true));
		const parsed = parseLUT3D(bytes, { format: 'float32-le', size: 2, layout: 'rgb-r-fastest' });
		sampleLUT3D(parsed, [0.2, 0.4, 0.8]).forEach((v, c) => expect(v).toBeCloseTo([0.2, 0.4, 0.8][c], 12));
		expect(sampleLUT3D(parsed, [-1, 0.4, 3])).toEqual([0, 0.4, 1]);
	});
	it('reads .cube domains and preserves HDR/negative output values', () => {
		const data = Array.from({ length: 8 }, (_, i) => `${(i & 1) * 4 - 1} ${((i >> 1) & 1) * 4 - 1} ${((i >> 2) & 1) * 4 - 1}`).join('\n');
		const lut = parseCubeLUT(`TITLE "test"\nLUT_3D_SIZE 2\nDOMAIN_MIN -1 -1 -1\nDOMAIN_MAX 3 3 3\n${data}`);
		expect(sampleLUT3D(lut, [0.2, 1, 2])[0]).toBeCloseTo(0.2);
		expect(sampleLUT3D(lut, [0.2, 1, 2])[2]).toBeCloseTo(2);
	});
	it('rejects malformed, ambiguous, unsupported and non-finite data', () => {
		for (const text of ['LUT_1D_SIZE 2', 'LUT_3D_SIZE 2\n0 0 0', 'LUT_3D_SIZE 1', 'LUT_3D_SIZE 2\nLUT_3D_INPUT_RANGE 0 1', 'LUT_3D_SIZE 2\n0 NaN 0']) expect(() => parseCubeLUT(text)).toThrow();
		expect(() => parseLUT3D(new ArrayBuffer(12), { format: 'float32-le', layout: 'rgb-r-fastest', size: 33 })).toThrow();
		const bad = transform(); bad.lut.values[0] = Infinity;
		expect(() => snapshotDisplayTransform(bad)).toThrow();
		const domain = transform(); domain.lut.domainMax[0] = 0;
		expect(() => snapshotDisplayTransform(domain)).toThrow();
	});
	it('snapshots user data and rejects unsupported color encodings', () => {
		const source = transform(), copy = snapshotDisplayTransform(source);
		source.lut.values[0] = 99; source.lut.domainMax[0] = 42;
		expect(copy.lut.values[0]).toBe(0); expect(copy.lut.domainMax[0]).toBe(1);
		expect(() => snapshotDisplayTransform({ ...copy, output: { primaries: 'rec709', transfer: { type: 'gamma', exponent: 0 } } })).toThrow();
	});
});

describe('display LUT color pipeline', () => {
	it('keeps ACES2 and its existing local exposure defaults', () => {
		expect(defaultRenderSettings().tonemapper).toBe(Tonemapper.ACES2);
		expect(defaultRenderSettings().localExposureMethod).toBe(LocalExposureMethod.Fusion);
	});
	it('matches F-Log2 reference codes and preserves input above 1', () => {
		expect(encodeFLog2(0)).toBeCloseTo(0.092864, 8);
		expect(encodeFLog2(0.18)).toBeCloseTo(0.3910072419, 8);
		expect(encodeFLog2(1)).toBeCloseTo(0.5682193704, 8);
		expect(encodeFLog2(10)).toBeCloseTo(0.8123887461, 8);
		expect(encodeFLog2(-0.001)).toBeLessThan(encodeFLog2(0));
	});
	it('decodes gamma output rather than treating it as linear or applying sRGB twice', () => {
		const desc = transform(); desc.output.transfer = { type: 'gamma', exponent: 2.2 };
		expect(evaluateDisplayTransform(desc, [0.5, 0.5, 0.5])[0]).toBeCloseTo(0.2176376408, 8);
		desc.input.transfer = 'srgb'; desc.output.transfer = 'srgb';
		evaluateDisplayTransform(desc, [0.001, 0.18, 0.8]).forEach((v, c) => expect(v).toBeCloseTo([0.001, 0.18, 0.8][c], 7));
	});
	it('round trips D65 primary conversion with an identity LUT', () => {
		const desc = transform(); desc.input.primaries = desc.output.primaries = 'rec2020';
		evaluateDisplayTransform(desc, [0.1, 0.4, 0.8]).forEach((v, c) => expect(v).toBeCloseTo([0.1, 0.4, 0.8][c], 6));
	});
	it.each(BUILTIN_LUTS)('$name payload is intact and usable', ({ id }) => {
		const bytes = readFileSync(new URL(`../src/render/color/looks/${id}.lut`, import.meta.url));
		expect(bytes.length).toBe(431244);
		expect(createHash('sha256').update(bytes).digest('hex')).toBe(provenance.find(p => p.id === id)!.payloadSha256);
		const lut = parseLUT3D(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer, { format: 'float32-le', size: 33, layout: 'rgb-r-fastest' });
		const desc: LUTDisplayTransform = { type: 'lut', lut, input: { primaries: 'rec2020', transfer: 'f-log2' }, output: { primaries: 'rec709', transfer: { type: 'gamma', exponent: 2.2 } } };
		for (const input of [[-0.01, 0.1, 0.2], [0.18, 0.18, 0.18], [1, 10, 100]] as [number, number, number][]) expect(evaluateDisplayTransform(desc, input).every(Number.isFinite)).toBe(true);
		if (id === 'astia') {
			// Recorded from light-lab's original trilinear F-Log2 path, before gamma decode.
			const expected = [0.465019, 0.469496, 0.468973].map(v => v ** 2.2);
			evaluateDisplayTransform(desc, [0.18, 0.18, 0.18]).forEach((v, c) => expect(v).toBeCloseTo(expected[c], 5));
		}
	});
});
