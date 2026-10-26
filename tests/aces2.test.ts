import { describe, expect, it } from 'vitest';
import reference from './fixtures/aces2-reference.json';
import { OutputTransform, SDR_REC709_SRGB, type Vec3 } from '../src/render/aces/ACES2';
import { mulVM } from '../src/render/aces/ACES2';
import { REC709_TO_AP0, bakeToneLUT, sampleToneLUT } from '../src/render/aces/ToneLUT';

interface Sample {
	in: Vec3;
	out: Vec3;
}

function maxError(samples: Sample[], fn: (v: Vec3) => Vec3): { err: number; at: Sample | null } {
	let err = 0;
	let at: Sample | null = null;
	for (const s of samples) {
		const o = fn(s.in);
		for (let c = 0; c < 3; c++) {
			const e = Math.abs(o[c] - s.out[c]);
			if (e > err) {
				err = e;
				at = s;
			}
		}
	}
	return { err, at };
}

describe('ACES 2.0 output transform', () => {
	const odt = new OutputTransform(SDR_REC709_SRGB);

	it('matches OpenColorIO for ACES2065-1 input', () => {
		const { err, at } = maxError(reference.aces2065 as Sample[], (v) => odt.apply(v));
		expect(err, JSON.stringify(at)).toBeLessThan(2e-3);
	});

	it('matches OpenColorIO for linear Rec.709 input', () => {
		const { err, at } = maxError(reference.linearRec709 as Sample[], (v) => odt.apply(mulVM(v, REC709_TO_AP0)));
		expect(err, JSON.stringify(at)).toBeLessThan(2e-3);
	});

	it('maps 18% grey to 10 nits', () => {
		const g = odt.apply([0.18, 0.18, 0.18]);
		expect(g[0]).toBeCloseTo(0.3492, 3);
	});

	it('round-trips the working-space to AP0 matrix with OCIO', () => {
		const ocio = reference.rec709ToAP0Columns.flat();
		REC709_TO_AP0.forEach((v, i) => expect(v).toBeCloseTo(ocio[i], 5));
	});
});

describe('ACES 2.0 tone LUT', () => {
	const t0 = performance.now();
	const lut = bakeToneLUT();
	const bakeMs = performance.now() - t0;

	it('bakes a 64^3 PQ-indexed LUT', () => {
		expect(lut.values.length).toBe(64 * 64 * 64 * 3);
		console.log(`ACES 2.0 LUT bake: ${bakeMs.toFixed(0)} ms`);
	});

	it('reproduces OpenColorIO through the LUT', () => {
		const samples = (reference.linearRec709 as Sample[]).filter((s) => Math.max(...s.in) <= 100);
		const errors: number[] = [];
		for (const s of samples) {
			const o = sampleToneLUT(lut, s.in);
			for (let c = 0; c < 3; c++) errors.push(Math.abs(o[c] - s.out[c]));
		}
		errors.sort((a, b) => a - b);
		const p99 = errors[Math.floor(errors.length * 0.99)];
		const max = errors[errors.length - 1];
		console.log(`LUT vs OCIO: p99 ${p99.toFixed(5)} max ${max.toFixed(5)}`);
		// Saturated cube edges (e.g. pure blue) curve sharply under gamut compression.
		expect(p99).toBeLessThan(1 / 255);
		expect(max).toBeLessThan(0.03);
	});

	it('is monotonic along the neutral axis', () => {
		let prev = -1;
		for (let i = 0; i < 1000; i++) {
			const v = 1e-4 * Math.pow(1e6, i / 999);
			const g = sampleToneLUT(lut, [v, v, v])[1];
			expect(g).toBeGreaterThanOrEqual(prev - 1e-6);
			prev = g;
		}
	});
});
