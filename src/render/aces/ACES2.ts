// ACES 2.0 Output Transform, ported from the Academy reference CTL (aces-core v2.0 lib:
// Lib.Academy.OutputTransform / Tonescale / DisplayEncoding / Utilities, Apache-2.0,
// Copyright Contributors to the ACES Project). Runs on the CPU to bake the display LUT.
//
// Conventions follow the CTL: matrices are row-major 3x3 and apply to row vectors (v * M).

export type Vec3 = [number, number, number];
export type Mat3 = number[]; // 9 entries, row-major

export interface Chromaticities {
	red: [number, number];
	green: [number, number];
	blue: [number, number];
	white: [number, number];
}

export const AP0: Chromaticities = { red: [0.7347, 0.2653], green: [0.0, 1.0], blue: [0.0001, -0.077], white: [0.32168, 0.33767] };
export const AP1: Chromaticities = { red: [0.713, 0.293], green: [0.165, 0.83], blue: [0.128, 0.044], white: [0.32168, 0.33767] };
export const REC709: Chromaticities = { red: [0.64, 0.33], green: [0.3, 0.6], blue: [0.15, 0.06], white: [0.3127, 0.329] };
export const P3_D65: Chromaticities = { red: [0.68, 0.32], green: [0.265, 0.69], blue: [0.15, 0.06], white: [0.3127, 0.329] };
export const REC2020: Chromaticities = { red: [0.708, 0.292], green: [0.17, 0.797], blue: [0.131, 0.046], white: [0.3127, 0.329] };
const CAM16_PRI: Chromaticities = { red: [0.8336, 0.1735], green: [2.3854, -1.4659], blue: [0.087, -0.125], white: [0.333, 0.333] };

// ---- Utilities ----

export function mulVM(v: Vec3, m: Mat3): Vec3 {
	return [
		v[0] * m[0] + v[1] * m[3] + v[2] * m[6],
		v[0] * m[1] + v[1] * m[4] + v[2] * m[7],
		v[0] * m[2] + v[1] * m[5] + v[2] * m[8],
	];
}

export function mulMM(a: Mat3, b: Mat3): Mat3 {
	const r = new Array<number>(9);
	for (let i = 0; i < 3; i++) {
		for (let j = 0; j < 3; j++) {
			r[i * 3 + j] = a[i * 3] * b[j] + a[i * 3 + 1] * b[3 + j] + a[i * 3 + 2] * b[6 + j];
		}
	}
	return r;
}

export function invert3(m: Mat3): Mat3 {
	const [a, b, c, d, e, f, g, h, i] = m;
	const A = e * i - f * h, B = -(d * i - f * g), C = d * h - e * g;
	const det = a * A + b * B + c * C;
	const s = 1 / det;
	return [
		A * s, -(b * i - c * h) * s, (b * f - c * e) * s,
		B * s, (a * i - c * g) * s, -(a * f - c * d) * s,
		C * s, -(a * h - b * g) * s, (a * e - b * d) * s,
	];
}

const scaleM = (s: number, m: Mat3): Mat3 => m.map((x) => x * s);
const diag = (v: Vec3): Mat3 => [v[0], 0, 0, 0, v[1], 0, 0, 0, v[2]];
const IDENTITY: Mat3 = [1, 0, 0, 0, 1, 0, 0, 0, 1];

// CTL sign(): 0 for 0.
const copysign = (x: number, y: number): number => Math.sign(y) * Math.abs(x);
const lerp = (a: number, b: number, t: number): number => a + t * (b - a);
const ctlRound = (x: number): number => Math.trunc(x < 0 ? x - 0.5 : x + 0.5);
const degToRad = (d: number): number => (d / 180) * Math.PI;
const radToDeg = (r: number): number => (r * 180) / Math.PI;

export function rgbToXYZ(c: Chromaticities, Y = 1): Mat3 {
	const X = (c.white[0] * Y) / c.white[1];
	const Z = ((1 - c.white[0] - c.white[1]) * Y) / c.white[1];
	const d = c.red[0] * (c.blue[1] - c.green[1]) + c.blue[0] * (c.green[1] - c.red[1]) + c.green[0] * (c.red[1] - c.blue[1]);
	const Sr = (X * (c.blue[1] - c.green[1]) - c.green[0] * (Y * (c.blue[1] - 1) + c.blue[1] * (X + Z)) + c.blue[0] * (Y * (c.green[1] - 1) + c.green[1] * (X + Z))) / d;
	const Sg = (X * (c.red[1] - c.blue[1]) + c.red[0] * (Y * (c.blue[1] - 1) + c.blue[1] * (X + Z)) - c.blue[0] * (Y * (c.red[1] - 1) + c.red[1] * (X + Z))) / d;
	const Sb = (X * (c.green[1] - c.red[1]) - c.red[0] * (Y * (c.green[1] - 1) + c.green[1] * (X + Z)) + c.green[0] * (Y * (c.red[1] - 1) + c.red[1] * (X + Z))) / d;
	return [
		Sr * c.red[0], Sr * c.red[1], Sr * (1 - c.red[0] - c.red[1]),
		Sg * c.green[0], Sg * c.green[1], Sg * (1 - c.green[0] - c.green[1]),
		Sb * c.blue[0], Sb * c.blue[1], Sb * (1 - c.blue[0] - c.blue[1]),
	];
}

export const xyzToRGB = (c: Chromaticities, Y = 1): Mat3 => invert3(rgbToXYZ(c, Y));

export const CONE_RESP_BRADFORD: Mat3 = [0.8951, -0.7502, 0.0389, 0.2664, 1.7135, -0.0685, -0.1614, 0.0367, 1.0296];
export const CONE_RESP_CAT02: Mat3 = [0.7328, -0.7036, 0.003, 0.4296, 1.6975, 0.0136, -0.1624, 0.0061, 0.9834];

function xyToXYZ(xy: [number, number]): Vec3 {
	return [xy[0] / Math.max(xy[1], 1e-10), 1, (1 - xy[0] - xy[1]) / Math.max(xy[1], 1e-10)];
}

export function catMatrix(srcWhite: [number, number], dstWhite: [number, number], cone: Mat3 = CONE_RESP_BRADFORD): Mat3 {
	const s = mulVM(xyToXYZ(srcWhite), cone);
	const d = mulVM(xyToXYZ(dstWhite), cone);
	return mulMM(cone, mulMM(diag([d[0] / s[0], d[1] / s[1], d[2] / s[2]]), invert3(cone)));
}

// RGB (row vector) in `src` primaries to RGB in `dst` primaries, with white adaptation.
export function rgbToRGB(src: Chromaticities, dst: Chromaticities, cone: Mat3 = CONE_RESP_BRADFORD): Mat3 {
	return mulMM(rgbToXYZ(src), mulMM(catMatrix(src.white, dst.white, cone), xyzToRGB(dst)));
}

// ---- Tonescale (Lib.Academy.Tonescale) ----

export interface TSParams {
	n: number;
	n_r: number;
	g: number;
	t_1: number;
	c_t: number;
	s_2: number;
	u_2: number;
	m_2: number;
	forward_limit: number;
	inverse_limit: number;
	log_peak: number;
}

export function initTSParams(peakLuminance: number): TSParams {
	const n = peakLuminance;
	const n_r = 100.0, g = 1.15, c = 0.18, c_d = 10.013, w_g = 0.14, t_1 = 0.04, r_hit_min = 128, r_hit_max = 896;
	const r_hit = r_hit_min + (r_hit_max - r_hit_min) * (Math.log(n / n_r) / Math.log(10000 / 100));
	const m_0 = n / n_r;
	const m_1 = 0.5 * (m_0 + Math.sqrt(m_0 * (m_0 + 4 * t_1)));
	const u = Math.pow(r_hit / m_1 / (r_hit / m_1 + 1), g);
	const m = m_1 / u;
	const w_i = Math.log(n / 100) / Math.log(2);
	const c_t = (c_d / n_r) * (1 + w_i * w_g);
	const g_ip = 0.5 * (c_t + Math.sqrt(c_t * (c_t + 4 * t_1)));
	const g_ipp2 = -(m_1 * Math.pow(g_ip / m, 1 / g)) / (Math.pow(g_ip / m, 1 / g) - 1);
	const w_2 = c / g_ipp2;
	const s_2 = w_2 * m_1;
	const u_2 = Math.pow(r_hit / m_1 / (r_hit / m_1 + w_2), g);
	const m_2 = m_1 / u_2;
	return { n, n_r, g, t_1, c_t, s_2, u_2, m_2, forward_limit: 8 * r_hit, inverse_limit: n / (u_2 * n_r), log_peak: Math.log10(n / n_r) };
}

export function tonescaleFwd(x: number, p: TSParams): number {
	const f = p.m_2 * Math.pow(Math.max(0, x) / (x + p.s_2), p.g);
	const h = Math.max(0, (f * f) / (f + p.t_1));
	return h * p.n_r;
}

// ---- Output transform (Lib.Academy.OutputTransform) ----

const TABLE_SIZE = 360;
const TOTAL_TABLE_SIZE = TABLE_SIZE + 2;
const BASE_INDEX = 1;
const HUE_LIMIT = 360;
const CUSP_CORNER_COUNT = 6;
const TOTAL_CORNER_COUNT = CUSP_CORNER_COUNT + 2;
const MAX_SORTED_CORNERS = 2 * CUSP_CORNER_COUNT;
const REACH_CUSP_TOLERANCE = 1e-3;
const DISPLAY_CUSP_TOLERANCE = 1e-7;
const GAMMA_MINIMUM = 0.0;
const GAMMA_MAXIMUM = 5.0;
const GAMMA_SEARCH_STEP = 0.4;
const GAMMA_ACCURACY = 1e-5;

export const REF_LUMINANCE = 100;
const L_A = 100;
const Y_B = 20;
const SURROUND: Vec3 = [0.9, 0.59, 0.9]; // dim
const J_SCALE = 100;
const CAM_NL_OFFSET = 0.2713 * 100;
const CAM_NL_SCALE = 4 * 100;
const MODEL_GAMMA = SURROUND[1] * (1.48 + Math.sqrt(Y_B / REF_LUMINANCE));

const CHROMA_COMPRESS = 2.4;
const CHROMA_COMPRESS_FACT = 3.3;
const CHROMA_EXPAND = 1.3;
const CHROMA_EXPAND_FACT = 0.69;
const CHROMA_EXPAND_THR = 0.5;

const SMOOTH_CUSPS = 0.12;
const SMOOTH_M = 0.27;
const CUSP_MID_BLEND = 1.3;
const FOCUS_GAIN_BLEND = 0.3;
const FOCUS_DISTANCE = 1.35;
const FOCUS_DISTANCE_SCALING = 1.75;
const COMPRESSION_THRESHOLD = 0.75;

const AP0_TO_AP1 = mulMM(rgbToXYZ(AP0), xyzToRGB(AP1));
const AP1_TO_AP0 = mulMM(rgbToXYZ(AP1), xyzToRGB(AP0));

export interface JMhParams {
	rgbToCam16c: Mat3;
	cam16cToRgb: Mat3;
	coneToAab: Mat3;
	aabToCone: Mat3;
	F_L_n: number;
	cz: number;
	inv_cz: number;
	A_w_J: number;
	inv_A_w_J: number;
}

export interface ODTParams {
	peakLuminance: number;
	input: JMhParams;
	reach: JMhParams;
	limit: JMhParams;
	ts: TSParams;
	limitJMax: number;
	modelGammaInv: number;
	reachM: Float64Array;
	sat: number;
	satThr: number;
	compr: number;
	chromaCompressScale: number;
	midJ: number;
	focusDist: number;
	lowerHullGammaInv: number;
	hues: Float64Array;
	cusps: Float64Array; // [J, M, h] per entry
	upperHullGamma: Float64Array; // stores 1 / gamma
	hueSearchRange: [number, number];
}

const wrapTo360 = (h: number): number => {
	const y = h % 360;
	return y < 0 ? y + 360 : y;
};
const huePositionInUniformTable = (h: number, size: number): number => Math.trunc((wrapTo360(h) / HUE_LIMIT) * size);
const baseHueForPosition = (i: number, size: number): number => (i * HUE_LIMIT) / size;

function panlrcFwdAbs(Rc: number): number {
	const F_L_Y = Math.pow(Rc, 0.42);
	return F_L_Y / (CAM_NL_OFFSET + F_L_Y);
}
function panlrcInvAbs(Ra: number): number {
	const Ra_lim = Math.min(Ra, 0.99);
	const F_L_Y = (CAM_NL_OFFSET * Ra_lim) / (1 - Ra_lim);
	return Math.pow(F_L_Y, 1 / 0.42);
}
const panlrcFwd = (v: number): number => copysign(panlrcFwdAbs(Math.abs(v)), v);
const panlrcInv = (v: number): number => copysign(panlrcInvAbs(Math.abs(v)), v);

const achromaticToJ = (A: number, cz: number): number => J_SCALE * Math.pow(A, cz);
const jToAchromatic = (J: number, inv_cz: number): number => Math.pow(J * (1 / J_SCALE), inv_cz);

export function jToY(J: number, p: JMhParams): number {
	const A = jToAchromatic(Math.abs(J), p.inv_cz);
	return panlrcInvAbs(p.A_w_J * A) / p.F_L_n;
}

export function yToJ(Y: number, p: JMhParams): number {
	const Ra = panlrcFwdAbs(Math.abs(Y) * p.F_L_n);
	return copysign(achromaticToJ(Ra * p.inv_A_w_J, p.cz), Y);
}

function rgbToAab(rgb: Vec3, p: JMhParams): Vec3 {
	const m = mulVM(rgb, p.rgbToCam16c);
	return mulVM([panlrcFwd(m[0]), panlrcFwd(m[1]), panlrcFwd(m[2])], p.coneToAab);
}

function aabToJMh(Aab: Vec3, p: JMhParams): Vec3 {
	if (Aab[0] <= 0) return [0, 0, 0];
	const J = achromaticToJ(Aab[0], p.cz);
	const M = Math.sqrt(Aab[1] * Aab[1] + Aab[2] * Aab[2]);
	const h = wrapTo360(radToDeg(Math.atan2(Aab[2], Aab[1])));
	return [J, M, h];
}

export const rgbToJMh = (rgb: Vec3, p: JMhParams): Vec3 => aabToJMh(rgbToAab(rgb, p), p);

export function jmhToRGB(JMh: Vec3, p: JMhParams): Vec3 {
	const hr = degToRad(JMh[2]);
	const A = jToAchromatic(JMh[0], p.inv_cz);
	const a = mulVM([A, JMh[1] * Math.cos(hr), JMh[1] * Math.sin(hr)], p.aabToCone);
	return mulVM([panlrcInv(a[0]), panlrcInv(a[1]), panlrcInv(a[2])], p.cam16cToRgb);
}

function clampAP0ToAP1(aces: Vec3, lo: number, hi: number): Vec3 {
	const ap1 = mulVM(aces, AP0_TO_AP1);
	const c: Vec3 = [Math.min(Math.max(ap1[0], lo), hi), Math.min(Math.max(ap1[1], lo), hi), Math.min(Math.max(ap1[2], lo), hi)];
	return mulVM(c, AP1_TO_AP0);
}

function reachMFromTable(h: number, table: Float64Array): number {
	const base = huePositionInUniformTable(h, TABLE_SIZE);
	const t = h - base;
	const i = base + BASE_INDEX;
	return lerp(table[i], table[i + 1], t);
}

function reinhardRemap(scale: number, nd: number): number {
	return (scale * nd) / (1 + nd);
}

function toe(x: number, limit: number, k1In: number, k2In: number): number {
	if (x > limit) return x;
	const k2 = Math.max(k2In, 0.001);
	const k1 = Math.sqrt(k1In * k1In + k2 * k2);
	const k3 = (limit + k1) / (limit + k2);
	const minusB = k3 * x - k1;
	const minusC = k2 * k3 * x;
	return 0.5 * (minusB + Math.sqrt(minusB * minusB + 4 * minusC));
}

function chromaCompressNorm(h: number, scale: number): number {
	const hr = degToRad(h);
	const a = Math.cos(hr), b = Math.sin(hr);
	const cos2 = a * a - b * b, sin2 = 2 * a * b;
	const cos3 = 4 * a * a * a - 3 * a, sin3 = 3 * b - 4 * b * b * b;
	const M = 11.34072 * a + 16.46899 * cos2 + 7.8838 * cos3 + 14.66441 * b + -6.37224 * sin2 + 9.19364 * sin3 + 77.12896;
	return M * scale;
}

function chromaCompressFwd(JMh: Vec3, tonemappedJ: number, p: ODTParams): Vec3 {
	const [J, M, h] = JMh;
	let Mc = M;
	if (M !== 0) {
		const nJ = tonemappedJ / p.limitJMax;
		const snJ = Math.max(0, 1 - nJ);
		const Mnorm = chromaCompressNorm(h, p.chromaCompressScale);
		const limit = (Math.pow(nJ, p.modelGammaInv) * reachMFromTable(h, p.reachM)) / Mnorm;
		Mc = M * Math.pow(tonemappedJ / J, p.modelGammaInv);
		Mc = Mc / Mnorm;
		Mc = limit - toe(limit - Mc, limit - 0.001, snJ * p.sat, Math.sqrt(nJ * nJ + p.satThr), );
		Mc = toe(Mc, limit, nJ * p.compr, snJ);
		Mc = Mc * Mnorm;
	}
	return [tonemappedJ, Mc, h];
}

function tonemapAndCompressFwd(JMh: Vec3, p: ODTParams): Vec3 {
	const linear = jToY(JMh[0], p.input) / REF_LUMINANCE;
	const tonemappedY = tonescaleFwd(linear, p.ts);
	const Jts = yToJ(tonemappedY, p.input);
	return chromaCompressFwd(JMh, Jts, p);
}

function compressionVectorSlope(intersectJ: number, focusJ: number, limitJMax: number, slopeGain: number): number {
	const dir = intersectJ < focusJ ? intersectJ : limitJMax - intersectJ;
	return (dir * (intersectJ - focusJ)) / (focusJ * slopeGain);
}

function solveJIntersect(J: number, M: number, focusJ: number, maxJ: number, slopeGain: number): number {
	const Ms = M / slopeGain;
	const a = Ms / focusJ;
	if (J < focusJ) {
		const b = 1 - Ms;
		const c = -J;
		const root = Math.sqrt(b * b - 4 * a * c);
		return (-2 * c) / (b + root);
	}
	const b = -(1 + Ms + maxJ * a);
	const c = maxJ * Ms + J;
	const root = Math.sqrt(b * b - 4 * a * c);
	return (-2 * c) / (b - root);
}

function sminScaled(a: number, b: number, ref: number): number {
	const s = SMOOTH_CUSPS * ref;
	const h = Math.max(s - Math.abs(a - b), 0) / s;
	return Math.min(a, b) - h * h * h * s * (1 / 6);
}

function lineBoundaryIntersectionM(JAxis: number, slope: number, invGamma: number, JMax: number, MMax: number, JRef: number): number {
	const shifted = JRef * Math.pow(JAxis / JRef, invGamma);
	return (shifted * MMax) / (JMax - slope * MMax);
}

function gamutBoundaryIntersection(cuspJ: number, cuspM: number, JMax: number, gammaTopInv: number, gammaBottomInv: number, JIntersectSource: number, slope: number, JIntersectCusp: number): number {
	const lower = lineBoundaryIntersectionM(JIntersectSource, slope, gammaBottomInv, cuspJ, cuspM, JIntersectCusp);
	const upper = lineBoundaryIntersectionM(JMax - JIntersectSource, -slope, gammaTopInv, JMax - cuspJ, cuspM, JMax - JIntersectCusp);
	return sminScaled(lower, upper, cuspM);
}

function focusGain(J: number, threshold: number, limitJMax: number, focusDist: number): number {
	let gain = limitJMax * focusDist;
	if (J > threshold) {
		let adj = Math.log10((limitJMax - threshold) / Math.max(0.0001, limitJMax - J));
		adj = adj * adj + 1;
		gain *= adj;
	}
	return gain;
}

function remapM(M: number, gamutBoundaryM: number, reachBoundaryM: number): number {
	const proportion = Math.max(gamutBoundaryM / reachBoundaryM, COMPRESSION_THRESHOLD);
	const threshold = proportion * gamutBoundaryM;
	if (M <= threshold || proportion >= 1) return M;
	const mOffset = M - threshold;
	const gamutOffset = gamutBoundaryM - threshold;
	const reachOffset = reachBoundaryM - threshold;
	const scale = reachOffset / (reachOffset / gamutOffset - 1);
	return threshold + reinhardRemap(scale, mOffset / scale);
}

const computeFocusJ = (cuspJ: number, midJ: number, limitJMax: number): number => lerp(cuspJ, midJ, Math.min(1, CUSP_MID_BLEND - cuspJ / limitJMax));

function cuspFromTable(h: number, table: Float64Array): [number, number] {
	let lo = 0;
	let hi = BASE_INDEX + TABLE_SIZE;
	let i = huePositionInUniformTable(h, TABLE_SIZE) + BASE_INDEX;
	while (lo + 1 < hi) {
		if (h > table[i * 3 + 2]) lo = i;
		else hi = i;
		i = Math.trunc((lo + hi) / 2);
	}
	const a = (hi - 1) * 3, b = hi * 3;
	const t = (h - table[a + 2]) / (table[b + 2] - table[a + 2]);
	return [lerp(table[a], table[b], t), lerp(table[a + 1], table[b + 1], t)];
}

function lookupHueInterval(h: number, hues: Float64Array, range: [number, number]): number {
	let i = BASE_INDEX + huePositionInUniformTable(h, TOTAL_TABLE_SIZE);
	let lo = Math.max(BASE_INDEX, i + range[0]);
	let hi = Math.min(BASE_INDEX + TABLE_SIZE, i + range[1]);
	while (lo + 1 < hi) {
		if (h > hues[i]) lo = i;
		else hi = i;
		i = Math.trunc((lo + hi) / 2);
	}
	return Math.max(1, hi);
}

function gamutCompressFwd(JMh: Vec3, p: ODTParams): Vec3 {
	const [J, M, h] = JMh;
	if (J <= 0) return [0, 0, h];
	if (M < 0 || J > p.limitJMax) return [J, 0, h];

	const iHi = lookupHueInterval(h, p.hues, p.hueSearchRange);
	const t = h - p.hues[iHi - 1];
	const [cuspJ, cuspM] = cuspFromTable(h, p.cusps);
	const gammaTopInv = lerp(p.upperHullGamma[iHi - 1], p.upperHullGamma[iHi], t);
	const focusJ = computeFocusJ(cuspJ, p.midJ, p.limitJMax);
	const threshold = lerp(cuspJ, p.limitJMax, FOCUS_GAIN_BLEND);

	const slopeGain = focusGain(J, threshold, p.limitJMax, p.focusDist);
	const JIntersectSource = solveJIntersect(J, M, focusJ, p.limitJMax, slopeGain);
	const slope = compressionVectorSlope(JIntersectSource, focusJ, p.limitJMax, slopeGain);
	const JIntersectCusp = solveJIntersect(cuspJ, cuspM, focusJ, p.limitJMax, slopeGain);
	const gamutBoundaryM = gamutBoundaryIntersection(cuspJ, cuspM, p.limitJMax, gammaTopInv, p.lowerHullGammaInv, JIntersectSource, slope, JIntersectCusp);
	if (gamutBoundaryM <= 0) return [J, 0, h];

	const reachMaxM = reachMFromTable(h, p.reachM);
	const reachBoundaryM = lineBoundaryIntersectionM(JIntersectSource, slope, p.modelGammaInv, p.limitJMax, reachMaxM, p.limitJMax);
	const remapped = remapM(M, gamutBoundaryM, reachBoundaryM);
	return [JIntersectSource + remapped * slope, remapped, h];
}

// ---- Table construction ----

export function initJMhParams(prims: Chromaticities): JMhParams {
	const M16 = xyzToRGB(CAM16_PRI, 1);
	const baseConeToAab: Mat3 = [2, 1, 1 / 9, 1, -12 / 11, 1 / 9, 1 / 20, 1 / 11, -2 / 9];
	const toXYZ = rgbToXYZ(prims, 1);
	const XYZ_w = mulVM([REF_LUMINANCE, REF_LUMINANCE, REF_LUMINANCE], toXYZ);
	const Y_w = XYZ_w[1];
	const RGB_w = mulVM(XYZ_w, M16);

	const k = 1 / (5 * L_A + 1);
	const k4 = k * k * k * k;
	const F_L = 0.2 * k4 * (5 * L_A) + 0.1 * Math.pow(1 - k4, 2) * Math.pow(5 * L_A, 1 / 3);
	const F_L_n = F_L / REF_LUMINANCE;
	const cz = MODEL_GAMMA;

	const D_RGB: Vec3 = [(F_L_n * Y_w) / RGB_w[0], (F_L_n * Y_w) / RGB_w[1], (F_L_n * Y_w) / RGB_w[2]];
	const RGB_Aw: Vec3 = [panlrcFwd(D_RGB[0] * RGB_w[0]), panlrcFwd(D_RGB[1] * RGB_w[1]), panlrcFwd(D_RGB[2] * RGB_w[2])];

	const cr = mulMM(scaleM(CAM_NL_SCALE, IDENTITY), baseConeToAab);
	const A_w = cr[0] * RGB_Aw[0] + cr[3] * RGB_Aw[1] + cr[6] * RGB_Aw[2];
	const A_w_J = panlrcFwdAbs(F_L);

	const rgbToCam16 = mulMM(mulMM(toXYZ, M16), scaleM(REF_LUMINANCE, IDENTITY));
	const rgbToCam16c = mulMM(rgbToCam16, diag(D_RGB));
	const s = 43 * SURROUND[2];
	const coneToAab: Mat3 = [cr[0] / A_w, cr[1] * s, cr[2] * s, cr[3] / A_w, cr[4] * s, cr[5] * s, cr[6] / A_w, cr[7] * s, cr[8] * s];

	return { rgbToCam16c, cam16cToRgb: invert3(rgbToCam16c), coneToAab, aabToCone: invert3(coneToAab), F_L_n, cz, inv_cz: 1 / cz, A_w_J, inv_A_w_J: 1 / A_w_J };
}

function unitCubeCuspCorner(corner: number): Vec3 {
	// R, Y, G, C, B, M so hues rotate in order
	return [(corner + 1) % CUSP_CORNER_COUNT < 3 ? 1 : 0, (corner + 5) % CUSP_CORNER_COUNT < 3 ? 1 : 0, (corner + 3) % CUSP_CORNER_COUNT < 3 ? 1 : 0];
}

// Rotates corners so the lowest hue sits at [1], with wrapped copies at [0] and [count + 1].
function cycleCorners<T extends Vec3>(rgb: T[] | null, jmh: Vec3[]): { rgb: Vec3[]; jmh: Vec3[] } {
	let minIndex = 0;
	for (let i = 0; i < CUSP_CORNER_COUNT; i++) if (jmh[i][2] < jmh[minIndex][2]) minIndex = i;
	const outRGB: Vec3[] = new Array(TOTAL_CORNER_COUNT);
	const outJMh: Vec3[] = new Array(TOTAL_CORNER_COUNT);
	for (let i = 0; i < CUSP_CORNER_COUNT; i++) {
		const k = (i + minIndex) % CUSP_CORNER_COUNT;
		outRGB[i + 1] = rgb ? [...rgb[k]] : [0, 0, 0];
		outJMh[i + 1] = [...jmh[k]];
	}
	outRGB[0] = [...outRGB[CUSP_CORNER_COUNT]];
	outRGB[CUSP_CORNER_COUNT + 1] = [...outRGB[1]];
	outJMh[0] = [...outJMh[CUSP_CORNER_COUNT]];
	outJMh[CUSP_CORNER_COUNT + 1] = [...outJMh[1]];
	outJMh[0][2] -= HUE_LIMIT;
	outJMh[CUSP_CORNER_COUNT + 1][2] += HUE_LIMIT;
	return { rgb: outRGB, jmh: outJMh };
}

function limitingCuspCorners(params: JMhParams, peakLuminance: number): { rgb: Vec3[]; jmh: Vec3[] } {
	const rgb: Vec3[] = [];
	const jmh: Vec3[] = [];
	for (let i = 0; i < CUSP_CORNER_COUNT; i++) {
		const c = unitCubeCuspCorner(i).map((v) => (v * peakLuminance) / REF_LUMINANCE) as Vec3;
		rgb.push(c);
		jmh.push(rgbToJMh(c, params));
	}
	return cycleCorners(rgb, jmh);
}

function reachCorners(reach: JMhParams, limitJMax: number, forwardLimit: number): Vec3[] {
	const limitA = jToAchromatic(limitJMax, reach.inv_cz);
	const jmh: Vec3[] = [];
	for (let i = 0; i < CUSP_CORNER_COUNT; i++) {
		const v = unitCubeCuspCorner(i);
		let lower = 0;
		let upper = forwardLimit;
		while (upper - lower > REACH_CUSP_TOLERANCE) {
			const test = (lower + upper) / 2;
			if (rgbToAab([test * v[0], test * v[1], test * v[2]], reach)[0] < limitA) lower = test;
			else upper = test;
		}
		jmh.push(rgbToJMh([upper * v[0], upper * v[1], upper * v[2]], reach));
	}
	return cycleCorners(null, jmh).jmh;
}

function sortedCubeHues(reach: Vec3[], limit: Vec3[]): number[] {
	const sorted: number[] = [];
	let r = 1, l = 1;
	while (r < CUSP_CORNER_COUNT + 1 || l < CUSP_CORNER_COUNT + 1) {
		const rh = reach[r][2];
		const lh = limit[l][2];
		if (rh === lh) {
			sorted.push(rh);
			r++;
			l++;
		} else if (rh < lh) {
			sorted.push(rh);
			r++;
		} else {
			sorted.push(lh);
			l++;
		}
	}
	while (sorted.length < MAX_SORTED_CORNERS) sorted.push(0);
	return sorted;
}

function buildHueTable(sortedHues: number[]): Float64Array {
	const table = new Float64Array(TOTAL_TABLE_SIZE);
	const idealSpacing = TABLE_SIZE / HUE_LIMIT;
	const samples = new Array<number>(2 * CUSP_CORNER_COUNT + 2).fill(0);
	let lastIdx = -1;
	let minIndex = sortedHues[0] === 0 ? 0 : 1;
	for (let k = 0; k < MAX_SORTED_CORNERS; k++) {
		let nominal = Math.min(Math.max(ctlRound(sortedHues[k] * idealSpacing), minIndex), TABLE_SIZE - 1);
		if (lastIdx === nominal) {
			if (k > 1 && samples[k - 2] !== samples[k - 1] - 1) samples[k - 1] -= 1;
			else nominal += 1;
		}
		samples[k] = Math.min(nominal, TABLE_SIZE - 1);
		minIndex = nominal;
		lastIdx = minIndex;
	}
	const fill = (count: number, lower: number, upper: number, base: number) => {
		const delta = (upper - lower) / count;
		for (let i = 0; i < count; i++) table[base + i] = lower + i * delta;
	};
	let total = 0;
	fill(samples[0], 0, sortedHues[0], total + 1);
	total += samples[0];
	for (let k = 1; k < MAX_SORTED_CORNERS; k++) {
		const n = samples[k] - samples[k - 1];
		fill(n, sortedHues[k - 1], sortedHues[k], total + 1);
		total += n;
	}
	fill(TABLE_SIZE - total, sortedHues[MAX_SORTED_CORNERS - 1], HUE_LIMIT, total + 1);
	table[0] = table[BASE_INDEX + TABLE_SIZE - 1] - HUE_LIMIT;
	table[BASE_INDEX + TABLE_SIZE] = table[BASE_INDEX] + HUE_LIMIT;
	return table;
}

function displayCuspForHue(hue: number, rgbCorners: Vec3[], jmhCorners: Vec3[], params: JMhParams): [number, number] {
	let upper = 1;
	for (let i = 1; i < TOTAL_CORNER_COUNT; i++) {
		if (jmhCorners[i][2] > hue) {
			upper = i;
			break;
		}
	}
	const lower = upper - 1;
	if (jmhCorners[lower][2] === hue) return [jmhCorners[lower][0], jmhCorners[lower][1]];

	const lo = rgbCorners[lower];
	const hi = rgbCorners[upper];
	const sample = (t: number): Vec3 => rgbToJMh([lerp(lo[0], hi[0], t), lerp(lo[1], hi[1], t), lerp(lo[2], hi[2], t)], params);
	let lowerT = 0;
	let upperT = 1;
	while (upperT - lowerT > DISPLAY_CUSP_TOLERANCE) {
		const t = (lowerT + upperT) / 2;
		const h = sample(t)[2];
		if (h < jmhCorners[lower][2]) upperT = t;
		else if (h >= jmhCorners[upper][2]) lowerT = t;
		else if (h > hue) upperT = t;
		else lowerT = t;
	}
	const JMh = sample((lowerT + upperT) / 2);
	return [JMh[0], JMh[1]];
}

function buildCuspTable(hues: Float64Array, rgbCorners: Vec3[], jmhCorners: Vec3[], params: JMhParams): Float64Array {
	const out = new Float64Array(TOTAL_TABLE_SIZE * 3);
	for (let i = BASE_INDEX; i < TOTAL_TABLE_SIZE; i++) {
		const [J, M] = displayCuspForHue(hues[i], rgbCorners, jmhCorners, params);
		out[i * 3] = J;
		out[i * 3 + 1] = M * (1 + SMOOTH_M * SMOOTH_CUSPS);
		out[i * 3 + 2] = hues[i];
	}
	out[0] = out[TABLE_SIZE * 3];
	out[1] = out[TABLE_SIZE * 3 + 1];
	out[2] = hues[0];
	const last = (BASE_INDEX + TABLE_SIZE) * 3;
	out[last] = out[BASE_INDEX * 3];
	out[last + 1] = out[BASE_INDEX * 3 + 1];
	out[last + 2] = hues[BASE_INDEX + TABLE_SIZE];
	return out;
}

function makeReachMTable(params: JMhParams, limitJMax: number): Float64Array {
	const table = new Float64Array(TOTAL_TABLE_SIZE);
	const outside = (M: number, hue: number) => {
		const rgb = jmhToRGB([limitJMax, M, hue], params);
		return rgb[0] < 0 || rgb[1] < 0 || rgb[2] < 0;
	};
	for (let i = 0; i < TABLE_SIZE; i++) {
		const hue = baseHueForPosition(i, TABLE_SIZE);
		let low = 0;
		let high = 50;
		let out = false;
		while (!out && high < 1300) {
			out = outside(high, hue);
			if (!out) {
				low = high;
				high += 50;
			}
		}
		while (high - low > 1e-2) {
			const m = (high + low) / 2;
			if (outside(m, hue)) high = m;
			else low = m;
		}
		table[i + BASE_INDEX] = high;
	}
	table[0] = table[TABLE_SIZE];
	table[BASE_INDEX + TABLE_SIZE] = table[BASE_INDEX];
	return table;
}

const TEST_POSITIONS = [0.01, 0.1, 0.5, 0.8, 0.99];

function makeUpperHullGammaTable(cusps: Float64Array, p: Omit<ODTParams, 'upperHullGamma' | 'hueSearchRange'>): Float64Array {
	const out = new Float64Array(TOTAL_TABLE_SIZE);
	const luminanceLimit = p.peakLuminance / REF_LUMINANCE;
	for (let i = BASE_INDEX; i < BASE_INDEX + TABLE_SIZE; i++) {
		const cuspJ = cusps[i * 3], cuspM = cusps[i * 3 + 1], hue = cusps[i * 3 + 2];
		const threshold = lerp(cuspJ, p.limitJMax, FOCUS_GAIN_BLEND);
		const focusJ = computeFocusJ(cuspJ, p.midJ, p.limitJMax);
		const tests = TEST_POSITIONS.map((pos) => {
			const J = lerp(cuspJ, p.limitJMax, pos);
			const slopeGain = focusGain(J, threshold, p.limitJMax, p.focusDist);
			const JIntersect = solveJIntersect(J, cuspM, focusJ, p.limitJMax, slopeGain);
			return {
				JIntersect,
				slope: compressionVectorSlope(JIntersect, focusJ, p.limitJMax, slopeGain),
				JCusp: solveJIntersect(cuspJ, cuspM, focusJ, p.limitJMax, slopeGain),
			};
		});
		const fits = (topGammaInv: number): boolean => {
			for (const t of tests) {
				const M = gamutBoundaryIntersection(cuspJ, cuspM, p.limitJMax, topGammaInv, p.lowerHullGammaInv, t.JIntersect, t.slope, t.JCusp);
				const rgb = jmhToRGB([t.JIntersect + t.slope * M, M, hue], p.limit);
				if (!(rgb[0] > luminanceLimit || rgb[1] > luminanceLimit || rgb[2] > luminanceLimit)) return false;
			}
			return true;
		};
		let low = GAMMA_MINIMUM;
		let high = low + GAMMA_SEARCH_STEP;
		let found = false;
		while (!found && high < GAMMA_MAXIMUM) {
			if (!fits(1 / high)) {
				low = high;
				high += GAMMA_SEARCH_STEP;
			} else {
				found = true;
			}
		}
		while (high - low > GAMMA_ACCURACY) {
			const g = (high + low) / 2;
			if (fits(1 / g)) high = g;
			else low = g;
		}
		out[i] = 1 / high;
	}
	out[0] = out[TABLE_SIZE];
	out[TABLE_SIZE + BASE_INDEX] = out[BASE_INDEX];
	return out;
}

function hueLinearitySearchRange(hues: Float64Array): [number, number] {
	const range: [number, number] = [0, 1];
	for (let i = BASE_INDEX; i < BASE_INDEX + TABLE_SIZE; i++) {
		const delta = i - huePositionInUniformTable(hues[i], TOTAL_TABLE_SIZE);
		range[0] = Math.min(range[0], delta);
		range[1] = Math.max(range[1], delta + 1);
	}
	return range;
}

export function initODTParams(peakLuminance: number, limitingPrimaries: Chromaticities): ODTParams {
	const input = initJMhParams(AP0);
	const reach = initJMhParams(AP1);
	const limit = initJMhParams(limitingPrimaries);
	const ts = initTSParams(peakLuminance);
	const limitJMax = yToJ(peakLuminance, input);
	const base = {
		peakLuminance,
		input,
		reach,
		limit,
		ts,
		limitJMax,
		modelGammaInv: 1 / MODEL_GAMMA,
		reachM: makeReachMTable(reach, limitJMax),
		sat: Math.max(0.2, CHROMA_EXPAND - CHROMA_EXPAND * CHROMA_EXPAND_FACT * ts.log_peak),
		satThr: CHROMA_EXPAND_THR / peakLuminance,
		compr: CHROMA_COMPRESS + CHROMA_COMPRESS * CHROMA_COMPRESS_FACT * ts.log_peak,
		chromaCompressScale: Math.pow(0.03379 * peakLuminance, 0.30596) - 0.45135,
		midJ: yToJ(ts.c_t * REF_LUMINANCE, input),
		focusDist: FOCUS_DISTANCE + FOCUS_DISTANCE * FOCUS_DISTANCE_SCALING * ts.log_peak,
		lowerHullGammaInv: 1 / (1.14 + 0.07 * ts.log_peak),
	};
	const corners = limitingCuspCorners(limit, peakLuminance);
	const hueTable = buildHueTable(sortedCubeHues(reachCorners(reach, limitJMax, ts.forward_limit), corners.jmh));
	const cusps = buildCuspTable(hueTable, corners.rgb, corners.jmh, limit);
	const hues = new Float64Array(TOTAL_TABLE_SIZE);
	for (let i = 0; i < TOTAL_TABLE_SIZE; i++) hues[i] = cusps[i * 3 + 2];
	const withTables = { ...base, hues, cusps };
	return { ...withTables, upperHullGamma: makeUpperHullGammaTable(cusps, withTables), hueSearchRange: hueLinearitySearchRange(hues) };
}

// ACES2065-1 -> limiting-primaries display linear (1.0 = 100 nits).
export function outputTransformFwd(aces: Vec3, p: ODTParams): Vec3 {
	const clamped = clampAP0ToAP1(aces, 0, p.ts.forward_limit);
	const JMh = rgbToJMh(clamped, p.input);
	const tonemapped = tonemapAndCompressFwd(JMh, p);
	const compressed = gamutCompressFwd(tonemapped, p);
	return jmhToRGB(compressed, p.limit);
}

// ---- Display encoding (Lib.Academy.DisplayEncoding) ----

export enum EOTF {
	Linear = 0,
	ST2084 = 1,
	Gamma2_6 = 3,
	BT1886 = 4,
	Gamma2_2 = 5,
	sRGB = 6,
}

const PQ_M1 = 0.1593017578125, PQ_M2 = 78.84375, PQ_C1 = 0.8359375, PQ_C2 = 18.8515625, PQ_C3 = 18.6875, PQ_C = 10000;

export function yToST2084(C: number): number {
	const Lm = Math.pow(C / PQ_C, PQ_M1);
	return Math.pow((PQ_C1 + PQ_C2 * Lm) / (1 + PQ_C3 * Lm), PQ_M2);
}

export function st2084ToY(N: number): number {
	const Np = Math.pow(N, 1 / PQ_M2);
	const L = Math.max(Np - PQ_C1, 0) / (PQ_C2 - PQ_C3 * Np);
	return Math.pow(L, 1 / PQ_M1) * PQ_C;
}

function moncurveInv(y: number, gamma: number, offs: number): number {
	const yb = Math.pow((offs * gamma) / ((gamma - 1) * (1 + offs)), gamma);
	const rs = Math.pow((gamma - 1) / offs, gamma - 1) * Math.pow((1 + offs) / gamma, gamma);
	return y >= yb ? (1 + offs) * Math.pow(y, 1 / gamma) - offs : y * rs;
}

export function eotfInv(v: number, eotf: EOTF): number {
	const x = Math.max(0, v);
	switch (eotf) {
		case EOTF.Linear:
			return x;
		case EOTF.ST2084:
			return yToST2084(REF_LUMINANCE * x);
		case EOTF.Gamma2_6:
			return Math.pow(x, 1 / 2.6);
		case EOTF.BT1886:
			return Math.pow(x, 1 / 2.4);
		case EOTF.Gamma2_2:
			return Math.pow(x, 1 / 2.2);
		default:
			return moncurveInv(x, 2.4, 0.055);
	}
}

export interface OutputTransformDesc {
	peakLuminance: number; // nits
	limitingPrimaries: Chromaticities;
	encodingPrimaries: Chromaticities;
	eotf: EOTF;
	scaleWhite: boolean;
}

export const SDR_REC709_SRGB: OutputTransformDesc = {
	peakLuminance: 100,
	limitingPrimaries: REC709,
	encodingPrimaries: REC709,
	eotf: EOTF.sRGB,
	scaleWhite: false,
};

// Complete Output.Academy.* transform: ACES2065-1 in, display code values out.
export class OutputTransform {
	readonly params: ODTParams;
	private readonly limitToDisplay: Mat3;
	private readonly whiteScale: number;

	constructor(readonly desc: OutputTransformDesc) {
		this.params = initODTParams(desc.peakLuminance, desc.limitingPrimaries);
		this.limitToDisplay = mulMM(rgbToXYZ(desc.limitingPrimaries), xyzToRGB(desc.encodingPrimaries));
		const w = mulVM([1, 1, 1], this.limitToDisplay);
		this.whiteScale = 1 / Math.max(w[0], w[1], w[2]);
	}

	apply(aces: Vec3): Vec3 {
		const peak = this.desc.peakLuminance / REF_LUMINANCE;
		let rgb = outputTransformFwd(aces, this.params);
		rgb = [Math.min(Math.max(rgb[0], 0), peak), Math.min(Math.max(rgb[1], 0), peak), Math.min(Math.max(rgb[2], 0), peak)];
		if (this.desc.scaleWhite) rgb = [rgb[0] * this.whiteScale, rgb[1] * this.whiteScale, rgb[2] * this.whiteScale];
		const d = mulVM(rgb, this.limitToDisplay);
		return [eotfInv(d[0], this.desc.eotf), eotfInv(d[1], this.desc.eotf), eotfInv(d[2], this.desc.eotf)];
	}
}
