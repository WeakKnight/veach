// Host side of the fused fine-residual Fusion local exposure (github.com/litianyu LocalExposure,
// zcurve.py and fusion_lookup.py): a monotone Z curve fitted to the neutral response of the active
// tone mapper, its inverse lightness LUT, and the forward tables of the three exposure brackets.
// All of it is rebuilt only when the tone mapper or the bracket settings change.
import { REC709_TO_AP0 } from './aces/ToneLUT';
import { OutputTransform, SDR_REC709_SRGB, mulVM } from './aces/ACES2';
import { Tonemapper } from './GpuLayout';

export const Z_MAX_INPUT = 65535;
export const INVERSE_LUT_SIZE = 1024;
export const FORWARD_LUT_SIZE = 2048;
export const FORWARD_LOG_MIN = -40; // log2 luminance covered by the forward tables
export const FORWARD_LOG_MAX = 40;
const INVERSE_WARP_EPSILON = 1e-5;
const REC709_LUMA = [0.2126, 0.7152, 0.0722] as const;

// contrast, shoulder, b, c: f(L) = L^contrast / (b * L^(contrast * shoulder) + c)
export type ZParameters = [number, number, number, number];

export function evaluateZCurve(luminance: number, [a, d, b, c]: ZParameters): number {
	const z = Math.pow(Math.max(luminance, 0), a);
	return z / (b * Math.pow(z, d) + c);
}

const srgbDecode = (v: number) => (v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4));

// Display-linear luminance of the tone mapper for neutral scene-linear input, as Present.slang
// evaluates it (ACES 2.0 through its PQ-indexed LUT, which clamps at 10000 nits).
export function neutralToneResponse(tonemapper: Tonemapper): (luminance: number) => number {
	if (tonemapper === Tonemapper.ACES2) {
		const odt = new OutputTransform(SDR_REC709_SRGB);
		return (x) => {
			const v = Math.min(x, 100);
			const cv = odt.apply(mulVM([v, v, v], REC709_TO_AP0));
			return REC709_LUMA[0] * srgbDecode(cv[0]) + REC709_LUMA[1] * srgbDecode(cv[1]) + REC709_LUMA[2] * srgbDecode(cv[2]);
		};
	}
	if (tonemapper === Tonemapper.ACESFilmic) {
		return (x) => {
			const c = x * 0.6;
			return Math.min(Math.max((c * (2.51 * c + 0.03)) / (c * (2.43 * c + 0.59) + 0.14), 0), 1);
		};
	}
	return (x) => Math.min(Math.max(x, 0), 1);
}

function solve4(m: number[], v: number[]): number[] | null {
	const a = [0, 1, 2, 3].map((r) => [m[r * 4], m[r * 4 + 1], m[r * 4 + 2], m[r * 4 + 3], v[r]]);
	for (let col = 0; col < 4; col++) {
		let pivot = col;
		for (let r = col + 1; r < 4; r++) if (Math.abs(a[r][col]) > Math.abs(a[pivot][col])) pivot = r;
		if (Math.abs(a[pivot][col]) < 1e-30) return null;
		[a[col], a[pivot]] = [a[pivot], a[col]];
		for (let r = 0; r < 4; r++) {
			if (r === col) continue;
			const f = a[r][col] / a[col][col];
			for (let k = col; k < 5; k++) a[r][k] -= f * a[col][k];
		}
	}
	return a.map((row, i) => row[4] / a[i][i]);
}

// Bounded Levenberg-Marquardt on the lightness residual sqrt(f) - sqrt(y), with the same
// parameterization, bounds and starting points as zcurve.fit_curve (a, b, c > 0 and
// 0 < shoulder <= 1 keep the curve monotone).
export function fitZCurve(x: ArrayLike<number>, y: ArrayLike<number>): ZParameters {
	const lo = [Math.log(0.1), 0.1, Math.log(0.001), Math.log(1e-6)];
	const hi = [Math.log(4), 1, Math.log(100), Math.log(1000)];
	const decode = (q: number[]): ZParameters => [Math.exp(q[0]), q[1], Math.exp(q[2]), Math.exp(q[3])];
	const target = Array.from(y, (v) => Math.sqrt(Math.max(v, 0)));
	const residuals = (q: number[]) => {
		const p = decode(q);
		return Array.from(x, (v, i) => Math.sqrt(evaluateZCurve(v, p)) - target[i]);
	};
	const cost = (r: number[]) => r.reduce((s, v) => s + v * v, 0);
	const clampQ = (q: number[]) => q.map((v, i) => Math.min(Math.max(v, lo[i]), hi[i]));

	let best: { q: number[]; cost: number } | null = null;
	for (const [a, d] of [
		[1, 0.8],
		[2, 0.95],
		[0.5, 0.5],
	]) {
		let q = clampQ([Math.log(a), d, 0, Math.log(0.2)]);
		let r = residuals(q);
		let c = cost(r);
		let lambda = 1e-3;
		for (let iter = 0; iter < 300 && lambda < 1e12; iter++) {
			const jacobian = q.map((_, k) => {
				const h = 1e-6 * Math.max(1, Math.abs(q[k]));
				const qp = q.slice();
				const qm = q.slice();
				qp[k] = Math.min(q[k] + h, hi[k]);
				qm[k] = Math.max(q[k] - h, lo[k]);
				const rp = residuals(qp);
				const rm = residuals(qm);
				return rp.map((v, i) => (v - rm[i]) / (qp[k] - qm[k]));
			});
			const jtj = new Array<number>(16).fill(0);
			const jtr = new Array<number>(4).fill(0);
			for (let i = 0; i < r.length; i++) {
				for (let m = 0; m < 4; m++) {
					jtr[m] += jacobian[m][i] * r[i];
					for (let n = 0; n < 4; n++) jtj[m * 4 + n] += jacobian[m][i] * jacobian[n][i];
				}
			}
			let improved = false;
			while (lambda < 1e12) {
				const damped = jtj.slice();
				for (let m = 0; m < 4; m++) damped[m * 5] += lambda * Math.max(jtj[m * 5], 1e-12);
				const step = solve4(damped, jtr.map((v) => -v));
				if (!step) {
					lambda *= 4;
					continue;
				}
				const candidate = clampQ(q.map((v, k) => v + step[k]));
				const cr = residuals(candidate);
				const cc = cost(cr);
				if (Number.isFinite(cc) && cc < c) {
					const converged = (c - cc) / Math.max(c, 1e-30) < 1e-12;
					q = candidate;
					r = cr;
					c = cc;
					lambda = Math.max(lambda / 3, 1e-9);
					improved = !converged;
					break;
				}
				lambda *= 4;
			}
			if (!improved) break;
		}
		if (!best || c < best.cost) best = { q, cost: c };
	}
	const p = decode(best!.q);
	if (!p.every(Number.isFinite)) throw new Error('Z-curve fit did not converge');
	return p.map((v) => Math.fround(v)) as ZParameters;
}

export interface ZCurve {
	parameters: ZParameters;
	maxInput: number;
	maxLightness: number;
	warpEpsilon: number;
	warpSpan: number;
	inverse: Float32Array<ArrayBuffer>; // log2 luminance at logit-spaced lightness, INVERSE_LUT_SIZE entries
	maxLightnessError: number; // sampled fit quality
}

// Fits the curve to a neutral tone response and bakes the inverse lightness LUT (zcurve.ZCurve).
export function calibrateZCurve(response: (luminance: number) => number, maxInput = Z_MAX_INPUT): ZCurve {
	const geom = (from: number, to: number, n: number) => Array.from({ length: n }, (_, i) => from * Math.pow(to / from, i / (n - 1)));
	const x = [0, ...geom(1e-8, maxInput, 1024)];
	const y = x.map(response);
	if (!y.every((v) => Number.isFinite(v) && v >= 0 && v <= 1.00001)) throw new Error('Tone operator must return finite SDR values');
	if (y[0] > 1e-5) throw new Error('Z curve requires a black-preserving neutral response');
	for (let i = 1; i < y.length; i++) if (y[i] < y[i - 1] - 2e-5) throw new Error('Neutral tone response is not monotone');
	const parameters = fitZCurve(x, y);
	const maxLightness = Math.fround(Math.sqrt(evaluateZCurve(maxInput, parameters)));

	const check = [0, ...geom(1.013e-8, maxInput, 2047)];
	let maxLightnessError = 0;
	for (const v of check) maxLightnessError = Math.max(maxLightnessError, Math.abs(Math.sqrt(evaluateZCurve(v, parameters)) - Math.sqrt(response(v))));

	const warpEpsilon = INVERSE_WARP_EPSILON;
	const warpSpan = Math.log2((1 + warpEpsilon) / warpEpsilon);
	const inverse = new Float32Array(INVERSE_LUT_SIZE);
	const logMax = Math.log2(maxInput);
	for (let i = 0; i < INVERSE_LUT_SIZE; i++) {
		const q = Math.pow(2, (2 * (i / (INVERSE_LUT_SIZE - 1)) - 1) * warpSpan);
		const t = Math.min(Math.max((q * (1 + warpEpsilon) - warpEpsilon) / (1 + q), 0), 1);
		const target = (t * maxLightness) ** 2;
		let lo = FORWARD_LOG_MIN;
		let hi = logMax;
		for (let k = 0; k < 72; k++) {
			const mid = (lo + hi) * 0.5;
			if (evaluateZCurve(Math.pow(2, mid), parameters) < target) lo = mid;
			else hi = mid;
		}
		inverse[i] = (lo + hi) * 0.5;
	}
	inverse[0] = FORWARD_LOG_MIN;
	inverse[INVERSE_LUT_SIZE - 1] = logMax;
	return { parameters, maxInput, maxLightness, warpEpsilon, warpSpan, inverse, maxLightnessError };
}

export function inverseLightness(curve: ZCurve, lightness: number): number {
	if (lightness <= 0) return 0;
	if (lightness >= curve.maxLightness) return curve.maxInput;
	const t = Math.min(Math.max(lightness / curve.maxLightness, 0), 1);
	const u = 0.5 + Math.log2((t + curve.warpEpsilon) / (1 - t + curve.warpEpsilon)) / (2 * curve.warpSpan);
	const pos = Math.min(Math.max(u, 0), 1) * (INVERSE_LUT_SIZE - 1);
	const i = Math.min(Math.floor(pos), INVERSE_LUT_SIZE - 2);
	const f = pos - i;
	return Math.min(Math.pow(2, curve.inverse[i] * (1 - f) + curve.inverse[i + 1] * f), curve.maxInput);
}

export interface FusionBrackets {
	highlightEV: number; // darker exposure, stops below the base
	shadowEV: number; // brighter exposure, stops above the base
	sigma: number; // well-exposedness width (Unreal: 0.2)
	targetLightness: number; // well-exposedness center (r.LocalExposure.ExposureFusion.TargetLuminance, 0.5)
}

// fusion_lookup.bake_tables, indexed by log2 luminance over [FORWARD_LOG_MIN, FORWARD_LOG_MAX]:
// forward = (weighted lightness, darker weight, brighter weight, 0),
// reduced = (darker - base lightness, brighter - base lightness, base lightness, 0).
export function bakeFusionTables(curve: ZCurve, b: FusionBrackets): { forward: Float32Array<ArrayBuffer>; reduced: Float32Array<ArrayBuffer> } {
	if (![b.highlightEV, b.shadowEV, b.sigma, b.targetLightness].every(Number.isFinite) || b.sigma <= 0) {
		throw new Error('Finite exposure brackets and positive sigma required');
	}
	const forward = new Float32Array(FORWARD_LUT_SIZE * 4);
	const reduced = new Float32Array(FORWARD_LUT_SIZE * 4);
	const scales = [Math.pow(2, -b.highlightEV), 1, Math.pow(2, b.shadowEV)];
	for (let i = 0; i < FORWARD_LUT_SIZE; i++) {
		const luminance = Math.pow(2, FORWARD_LOG_MIN + ((FORWARD_LOG_MAX - FORWARD_LOG_MIN) * i) / (FORWARD_LUT_SIZE - 1));
		const y = scales.map((s) => Math.min(Math.sqrt(evaluateZCurve(Math.min(luminance * s, curve.maxInput), curve.parameters)), curve.maxLightness));
		const logW = y.map((v) => -((v - b.targetLightness) ** 2) / (2 * b.sigma * b.sigma));
		const maxLogW = Math.max(...logW);
		const w = logW.map((v) => Math.pow(2, v - maxLogW));
		const sum = w[0] + w[1] + w[2];
		forward.set([(y[0] * w[0] + y[1] * w[1] + y[2] * w[2]) / sum, w[0] / sum, w[2] / sum, 0], i * 4);
		reduced.set([y[0] - y[1], y[2] - y[1], y[1], 0], i * 4);
	}
	return { forward, reduced };
}

// Unreal's Fusion bracket from a contrast scale: 1 = no bracket, 0 = six stops.
export function contrastScaleToEV(scale: number): number {
	return 6 * (1 - Math.min(Math.max(scale, 0), 1));
}

// Piecewise-linear curve over [x, y] keys, clamped at the ends (UCurveFloat with linear keys).
export type CurveKeys = readonly (readonly [number, number])[];
export function evaluateCurve(keys: CurveKeys, x: number): number {
	if (keys.length === 0) return 1;
	const sorted = [...keys].sort((p, q) => p[0] - q[0]);
	if (x <= sorted[0][0]) return sorted[0][1];
	for (let i = 1; i < sorted.length; i++) {
		if (x <= sorted[i][0]) {
			const [x0, y0] = sorted[i - 1];
			const [x1, y1] = sorted[i];
			return x1 > x0 ? y0 + ((y1 - y0) * (x - x0)) / (x1 - x0) : y1;
		}
	}
	return sorted[sorted.length - 1][1];
}
