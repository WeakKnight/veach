import { describe, expect, it } from 'vitest';
import { Tonemapper } from '../src/render/GpuLayout';
import { fusionLevelCount } from '../src/render/LocalExposure';
import {
	FORWARD_LOG_MAX,
	FORWARD_LOG_MIN,
	FORWARD_LUT_SIZE,
	bakeFusionTables,
	calibrateZCurve,
	contrastScaleToEV,
	evaluateCurve,
	evaluateZCurve,
	inverseLightness,
	neutralToneResponse,
} from '../src/render/LocalExposureCurve';

describe('local exposure Z curve', () => {
	it('reproduces the reference ACES filmic fit', () => {
		// LocalExposure/docs/implementation.md fits its acesFilmic (no 0.6 prescale):
		// contrast 1.52577, shoulder 0.999449, b 1.00612, c 0.210214
		const acesFilmic = (x: number) => Math.min(Math.max((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0), 1);
		const curve = calibrateZCurve(acesFilmic);
		const [a, d, b, c] = curve.parameters;
		expect(a).toBeCloseTo(1.52577, 2);
		expect(d).toBeCloseTo(0.999449, 2);
		expect(b).toBeCloseTo(1.00612, 1);
		expect(c).toBeCloseTo(0.210214, 2);
		expect(curve.maxLightnessError).toBeLessThan(0.02);
	});

	it('fits the ACES 2.0 output transform and inverts it', () => {
		const start = performance.now();
		const curve = calibrateZCurve(neutralToneResponse(Tonemapper.ACES2));
		console.log(`[localExposure] ACES2 fit ${curve.parameters.map((v) => v.toFixed(5)).join(', ')}, max lightness error ${curve.maxLightnessError.toFixed(4)}, ${(performance.now() - start).toFixed(0)} ms`);
		expect(curve.maxLightnessError).toBeLessThan(0.05);
		let maxEV = 0;
		for (let l = -20; l <= Math.log2(curve.maxInput) - 0.1; l += 0.37) {
			const x = Math.pow(2, l);
			const y = Math.sqrt(evaluateZCurve(x, curve.parameters));
			maxEV = Math.max(maxEV, Math.abs(Math.log2(inverseLightness(curve, y) / x)));
		}
		expect(maxEV).toBeLessThan(0.02);
	});

	it('bakes normalized bracket tables with an identity middle exposure', () => {
		const curve = calibrateZCurve(neutralToneResponse(Tonemapper.ACESFilmic));
		const { forward, reduced } = bakeFusionTables(curve, { highlightEV: 1.2, shadowEV: 1.2, sigma: 0.2, targetLightness: 0.5 });
		for (let i = 0; i < FORWARD_LUT_SIZE; i += 97) {
			const w0 = forward[i * 4 + 1];
			const w2 = forward[i * 4 + 2];
			expect(w0 + w2).toBeLessThanOrEqual(1 + 1e-6);
			const base = reduced[i * 4 + 2];
			const fused = base + w0 * reduced[i * 4] + w2 * reduced[i * 4 + 1];
			expect(fused).toBeCloseTo(forward[i * 4], 5);
			const luminance = Math.pow(2, FORWARD_LOG_MIN + ((FORWARD_LOG_MAX - FORWARD_LOG_MIN) * i) / (FORWARD_LUT_SIZE - 1));
			expect(base).toBeCloseTo(Math.min(Math.sqrt(evaluateZCurve(Math.min(luminance, curve.maxInput), curve.parameters)), curve.maxLightness), 5);
		}
	});

	it('maps contrast scales and curves like Unreal', () => {
		expect(contrastScaleToEV(1)).toBe(0);
		expect(contrastScaleToEV(0)).toBe(6);
		expect(contrastScaleToEV(0.8)).toBeCloseTo(1.2, 6);
		const keys = [
			[-2, 1],
			[6, 0.5],
		] as const;
		expect(evaluateCurve(keys, -5)).toBe(1);
		expect(evaluateCurve(keys, 2)).toBeCloseTo(0.75, 6);
		expect(evaluateCurve(keys, 10)).toBe(0.5);
		expect(evaluateCurve([], 3)).toBe(1);
	});

	it('fits every tone mapper closely enough to enable fusion', () => {
		const error = (t: Tonemapper) => calibrateZCurve(neutralToneResponse(t)).maxLightnessError;
		expect(error(Tonemapper.ACES2)).toBeLessThan(0.03);
		expect(error(Tonemapper.ACESFilmic)).toBeLessThan(0.03);
		// a hard clip is only approximated by the smooth Z curve (Renderer accepts up to 0.2)
		expect(error(Tonemapper.None)).toBeLessThan(0.2);
	});

	it('counts pyramid levels like the reference', () => {
		expect(fusionLevelCount(480, 270)).toBe(9);
		expect(fusionLevelCount(1, 1)).toBe(1);
		expect(fusionLevelCount(1 << 20, 1 << 20)).toBe(16);
	});
});
