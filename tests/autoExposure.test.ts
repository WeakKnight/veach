import { describe, expect, it } from 'vitest';
import { AutoExposureMethod, EYE_ADAPTATION_PARAMS_BYTES, LuminanceMethod, exponentialAdaptationM, packEyeAdaptationParams, type EyeAdaptationInput } from '../src/render/AutoExposure';

const input = (overrides: Partial<EyeAdaptationInput> = {}): EyeAdaptationInput => ({
	method: AutoExposureMethod.Histogram,
	exposureCompensation: 0,
	minBrightness: -10,
	maxBrightness: 20,
	histogramLogMin: -10,
	histogramLogMax: 20,
	lowPercent: 10,
	highPercent: 90,
	speedUp: 3,
	speedDown: 1,
	deltaTime: 1 / 60,
	forceTarget: false,
	luminanceMethod: LuminanceMethod.Uniform,
	...overrides,
});

const pack = (p: EyeAdaptationInput) => {
	const out = new Float32Array(EYE_ADAPTATION_PARAMS_BYTES / 4);
	packEyeAdaptationParams(out, p);
	return out;
};

describe('auto exposure parameters', () => {
	it('maps the histogram range to [0, 1]', () => {
		const p = pack(input({ histogramLogMin: -8, histogramLogMax: 4 }));
		const position = (log2: number) => log2 * p[0] + p[1];
		expect(position(-8)).toBeCloseTo(0, 6);
		expect(position(4)).toBeCloseTo(1, 6);
		expect([p[2], p[3]]).toEqual([expect.closeTo(0.1, 6), expect.closeTo(0.9, 6)]);
	});

	it('clamps percents and the histogram range like Unreal', () => {
		const p = pack(input({ lowPercent: 0, highPercent: 100, histogramLogMin: 5, histogramLogMax: 4 }));
		expect([p[2], p[3]]).toEqual([expect.closeTo(0.01, 6), expect.closeTo(0.99, 6)]);
		expect(-p[1] / p[0]).toBeCloseTo(3, 5); // Histogram Log Min <= Max - 1
		const crossed = pack(input({ lowPercent: 95, highPercent: 50 }));
		expect(crossed[2]).toBeCloseTo(crossed[3], 6);
	});

	it('clamps the average luminance in EV and applies the compensation', () => {
		const p = pack(input({ minBrightness: -2, maxBrightness: 3, exposureCompensation: 1 }));
		expect(p[4]).toBeCloseTo(0.25 * 0.18, 6);
		expect(p[5]).toBeCloseTo(8 * 0.18, 5);
		expect(p[6]).toBeCloseTo(2, 6);
	});

	it('pins the white point and forces the target in manual mode', () => {
		const p = pack(input({ method: AutoExposureMethod.Manual, exposureCompensation: -1 }));
		expect(p[4]).toBeCloseTo(0.18, 6);
		expect(p[5]).toBeCloseTo(0.18, 6);
		expect(p[6]).toBeCloseTo(0.5, 6);
		expect(p[14]).toBe(1);
		expect(pack(input({ forceTarget: true }))[14]).toBe(1);
		expect(pack(input())[14]).toBe(0);
		// Min Brightness = Max Brightness disables adaptation
		expect(pack(input({ minBrightness: 2, maxBrightness: 2 }))[14]).toBe(1);
	});

	it('matches the exponential and linear adaptation rates at the start distance', () => {
		const startDistance = 1.5;
		const dt = 1 / 60;
		for (const speed of [0.5, 1, 3, 10]) {
			const exponentialStep = startDistance * (1 - Math.pow(2, -dt * speed)) * exponentialAdaptationM(speed);
			expect(exponentialStep).toBeCloseTo(speed * dt, 6);
		}
	});

	it('packs the shared luminance weights', () => {
		const ntsc = pack(input({ luminanceMethod: LuminanceMethod.NTSC }));
		expect(Array.from(ntsc.subarray(16, 19))).toEqual([0.3, 0.59, 0.11].map(Math.fround));
		const uniform = pack(input());
		expect(uniform[16] + uniform[17] + uniform[18]).toBeCloseTo(1, 6);
	});
});
