import type { Vec3 } from '../../math/Math';

/** RGB triplets, red axis fastest: ((b * size + g) * size + r) * 3. */
export interface LUT3D {
	size: number;
	values: Float32Array<ArrayBuffer>;
	domainMin: Vec3;
	domainMax: Vec3;
}

export interface BinaryLUTOptions {
	format: 'float32-le';
	size: number;
	layout: 'rgb-r-fastest';
	domainMin?: Vec3;
	domainMax?: Vec3;
}

export type ColorPrimaries = 'rec709' | 'rec2020'; // D65
export type DisplayTransfer = 'linear' | 'srgb' | { type: 'gamma'; exponent: number };
export type InputTransfer = DisplayTransfer | 'f-log2';

export interface LUTDisplayTransform {
	type: 'lut';
	lut: LUT3D;
	input: { primaries: ColorPrimaries; transfer: InputTransfer };
	output: { primaries: ColorPrimaries; transfer: DisplayTransfer };
	interpolation?: 'trilinear';
	outOfDomain?: 'clamp';
	/** Custom LUT local-exposure calibration is not supported yet. */
	localExposure?: 'off';
}

export function validateLUT3D(lut: LUT3D): void {
	if (!Number.isInteger(lut.size) || lut.size < 2 || lut.size > 128) throw new Error('LUT size must be an integer from 2 to 128');
	if (!(lut.values instanceof Float32Array) || lut.values.length !== lut.size ** 3 * 3) throw new Error('LUT must contain size³ RGB float32 triplets');
	for (const value of lut.values) if (!Number.isFinite(value)) throw new Error('LUT contains NaN or Infinity');
	for (const domain of [lut.domainMin, lut.domainMax]) {
		if (!Array.isArray(domain) || domain.length !== 3 || !domain.every(Number.isFinite)) throw new Error('LUT domain must contain three finite values');
	}
	if (lut.domainMin.some((v, c) => v >= lut.domainMax[c])) throw new Error('LUT domain maximum must exceed minimum on every axis');
}

export function parseLUT3D(buffer: ArrayBuffer, options: BinaryLUTOptions): LUT3D {
	if (options.format !== 'float32-le' || options.layout !== 'rgb-r-fastest') throw new Error('Unsupported binary LUT format or layout');
	if (!Number.isInteger(options.size) || options.size < 2 || options.size > 128 || buffer.byteLength !== options.size ** 3 * 12) throw new Error('Invalid binary LUT size or byte length');
	const view = new DataView(buffer);
	const values = new Float32Array(buffer.byteLength / 4);
	for (let i = 0; i < values.length; i++) values[i] = view.getFloat32(i * 4, true);
	const lut: LUT3D = { size: options.size, values, domainMin: [...(options.domainMin ?? [0, 0, 0])], domainMax: [...(options.domainMax ?? [1, 1, 1])] };
	validateLUT3D(lut);
	return lut;
}

/** Strict 3D .cube subset; 1D shapers and vendor range directives are rejected, never ignored. */
export function parseCubeLUT(text: string): LUT3D {
	let size = 0;
	let domainMin: Vec3 = [0, 0, 0], domainMax: Vec3 = [1, 1, 1];
	const seen = new Set<string>();
	const values: number[] = [];
	for (const raw of text.replace(/^\uFEFF/, '').split(/\r?\n/)) {
		const line = raw.replace(/#.*/, '').trim();
		if (!line) continue;
		const tokens = line.split(/\s+/);
		const key = tokens[0];
		if (key === 'TITLE') continue;
		if (['LUT_3D_SIZE', 'DOMAIN_MIN', 'DOMAIN_MAX'].includes(key)) {
			if (seen.has(key) || values.length) throw new Error(`Duplicate or misplaced ${key}`);
			seen.add(key);
			if (key === 'LUT_3D_SIZE') {
				size = Number(tokens[1]);
				if (tokens.length !== 2 || !Number.isInteger(size) || size < 2 || size > 128) throw new Error('Invalid LUT_3D_SIZE');
			} else {
				const domain = tokens.slice(1).map(Number);
				if (domain.length !== 3 || !domain.every(Number.isFinite)) throw new Error(`Invalid ${key}`);
				if (key === 'DOMAIN_MIN') domainMin = domain as Vec3; else domainMax = domain as Vec3;
			}
			continue;
		}
		const row = tokens.map(Number);
		if (tokens.length !== 3 || !row.every(Number.isFinite)) throw new Error(`Unsupported .cube directive or data: ${key}`);
		if (!size || values.length + 3 > size ** 3 * 3) throw new Error('Missing LUT_3D_SIZE or excess LUT data');
		values.push(...row);
	}
	const lut: LUT3D = { size, values: new Float32Array(values), domainMin, domainMax };
	validateLUT3D(lut);
	return lut;
}

function validateTransfer(transfer: InputTransfer, input: boolean): void {
	if (transfer === 'linear' || transfer === 'srgb' || (input && transfer === 'f-log2')) return;
	if (typeof transfer === 'object' && transfer !== null && transfer.type === 'gamma' && Number.isFinite(transfer.exponent) && transfer.exponent > 0 && transfer.exponent <= 10) return;
	throw new Error('Unsupported color transfer; gamma exponent must be in (0, 10]');
}

/** Validate and snapshot caller-owned data before any asynchronous GPU work. */
export function snapshotDisplayTransform(desc: LUTDisplayTransform): LUTDisplayTransform {
	if (desc.type !== 'lut' || (desc.interpolation !== undefined && desc.interpolation !== 'trilinear') ||
		(desc.outOfDomain !== undefined && desc.outOfDomain !== 'clamp') || (desc.localExposure !== undefined && desc.localExposure !== 'off')) throw new Error('Unsupported LUT transform options');
	validateLUT3D(desc.lut);
	for (const encoding of [desc.input, desc.output]) if (!encoding || !['rec709', 'rec2020'].includes(encoding.primaries)) throw new Error('Unsupported color primaries');
	validateTransfer(desc.input.transfer, true);
	validateTransfer(desc.output.transfer, false);
	return {
		...desc, input: structuredClone(desc.input), output: structuredClone(desc.output),
		lut: { ...desc.lut, values: new Float32Array(desc.lut.values), domainMin: [...desc.lut.domainMin], domainMax: [...desc.lut.domainMax] },
	};
}

export function encodeFLog2(x: number): number {
	return x < 0.000889 ? 8.799461 * x + 0.092864 : 0.245281 * Math.log10(5.555556 * x + 0.064829) + 0.384316;
}

function encode(x: number, transfer: InputTransfer): number {
	if (transfer === 'linear') return x;
	if (transfer === 'f-log2') return encodeFLog2(x);
	if (transfer === 'srgb') return x <= 0.0031308 ? x * 12.92 : 1.055 * Math.pow(x, 1 / 2.4) - 0.055;
	return Math.pow(Math.max(x, 0), 1 / transfer.exponent);
}

function decode(x: number, transfer: DisplayTransfer): number {
	if (transfer === 'linear') return x;
	if (transfer === 'srgb') return x <= 0.04045 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
	return Math.pow(Math.max(x, 0), transfer.exponent);
}

// Row-major D65 matrices. Keep in sync with Passes/Present.slang.
const TO_2020 = [0.62740390, 0.32928304, 0.04331307, 0.06909729, 0.91954040, 0.01136232, 0.01639144, 0.08801331, 0.89559525];
const TO_709 = [1.66049100, -0.58764114, -0.07284986, -0.12455047, 1.13289990, -0.00834942, -0.01815076, -0.10057890, 1.11872966];
const mul = (m: number[], v: Vec3): Vec3 => [0, 1, 2].map(r => m[r * 3] * v[0] + m[r * 3 + 1] * v[1] + m[r * 3 + 2] * v[2]) as Vec3;

/** Sample encoded LUT coordinates (not scene-linear RGB). Values outside the domain clamp. */
export function sampleLUT3D(lut: LUT3D, encoded: Vec3): Vec3 {
	const p = encoded.map((v, c) => Math.min(1, Math.max(0, (v - lut.domainMin[c]) / (lut.domainMax[c] - lut.domainMin[c]))) * (lut.size - 1));
	const a = p.map(v => Math.min(Math.floor(v), lut.size - 2));
	const f = p.map((v, c) => v - a[c]);
	const out: Vec3 = [0, 0, 0];
	for (let k = 0; k < 8; k++) {
		const x = k & 1, y = (k >> 1) & 1, z = (k >> 2) & 1;
		const w = (x ? f[0] : 1 - f[0]) * (y ? f[1] : 1 - f[1]) * (z ? f[2] : 1 - f[2]);
		const i = (((a[2] + z) * lut.size + a[1] + y) * lut.size + a[0] + x) * 3;
		for (let c = 0; c < 3; c++) out[c] += w * lut.values[i + c];
	}
	return out;
}

/** CPU reference: exposed scene-linear Rec.709 -> display-linear Rec.709, before output clipping. */
export function evaluateDisplayTransform(desc: LUTDisplayTransform, linear: Vec3): Vec3 {
	const input = desc.input.primaries === 'rec2020' ? mul(TO_2020, linear) : linear;
	const rgb = sampleLUT3D(desc.lut, input.map(v => encode(v, desc.input.transfer)) as Vec3);
	const display = rgb.map(v => decode(v, desc.output.transfer)) as Vec3;
	return desc.output.primaries === 'rec2020' ? mul(TO_709, display) : display;
}

// Four float4s, read only by the present pass; no scene/compute buffer layout changes.
export function displayTransformUniforms(desc: LUTDisplayTransform | null): Float32Array<ArrayBuffer> {
	const data = new Float32Array(16);
	if (!desc) return data;
	const transferId = (t: InputTransfer) => t === 'linear' ? 0 : t === 'srgb' ? 1 : t === 'f-log2' ? 2 : 3;
	data.set([1, desc.input.primaries === 'rec2020' ? 1 : 0, transferId(desc.input.transfer), desc.output.primaries === 'rec2020' ? 1 : 0]);
	data.set([typeof desc.input.transfer === 'object' ? desc.input.transfer.exponent : 1, transferId(desc.output.transfer), typeof desc.output.transfer === 'object' ? desc.output.transfer.exponent : 1, 0], 4);
	data.set(desc.lut.domainMin, 8);
	data.set(desc.lut.domainMax, 12);
	return data;
}
