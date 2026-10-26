// Bakes the ACES 2.0 display transform into a 3D LUT, following Unreal's
// PostProcessCombineLUTs: the LUT is indexed by the ST.2084 (PQ) encoding of scene-linear
// color scaled to nits (1.0 = 100 nits, clamped to 10000), which spreads samples
// perceptually across the full HDR range. Each texel stores display code values.
import { floatToHalf } from '../Environment';
import { AP0, CONE_RESP_BRADFORD, OutputTransform, REC709, SDR_REC709_SRGB, mulVM, rgbToRGB, st2084ToY, yToST2084, type OutputTransformDesc, type Vec3 } from './ACES2';

export const TONE_LUT_SIZE = 64;
export const LINEAR_TO_NITS = 100;

// Working space (linear Rec.709 / sRGB primaries, D65) to ACES2065-1, matching the
// OCIO ACES studio config's "Linear Rec.709 (sRGB)" (Bradford adaptation).
export const REC709_TO_AP0 = rgbToRGB(REC709, AP0, CONE_RESP_BRADFORD);

export function lutEncode(linear: number): number {
	return yToST2084(Math.min(Math.max(linear * LINEAR_TO_NITS, 0), 10000));
}

export function lutDecode(encoded: number): number {
	return st2084ToY(encoded) / LINEAR_TO_NITS;
}

export interface ToneLUT {
	size: number;
	// rgb texels, x = red, y = green, z = blue
	values: Float32Array<ArrayBuffer>;
}

export function bakeToneLUT(desc: OutputTransformDesc = SDR_REC709_SRGB, size = TONE_LUT_SIZE): ToneLUT {
	const odt = new OutputTransform(desc);
	const values = new Float32Array(size * size * size * 3);
	const axis = new Float64Array(size);
	for (let i = 0; i < size; i++) axis[i] = lutDecode(i / (size - 1));
	let o = 0;
	for (let b = 0; b < size; b++) {
		for (let g = 0; g < size; g++) {
			for (let r = 0; r < size; r++) {
				const cv = odt.apply(mulVM([axis[r], axis[g], axis[b]], REC709_TO_AP0));
				values[o++] = cv[0];
				values[o++] = cv[1];
				values[o++] = cv[2];
			}
		}
	}
	return { size, values };
}

// rgba16float texel data for a 3D texture.
export function packToneLUT(lut: ToneLUT): Uint16Array<ArrayBuffer> {
	const count = lut.values.length / 3;
	const data = new Uint16Array(count * 4);
	const one = floatToHalf(1);
	for (let i = 0; i < count; i++) {
		data[i * 4] = floatToHalf(lut.values[i * 3]);
		data[i * 4 + 1] = floatToHalf(lut.values[i * 3 + 1]);
		data[i * 4 + 2] = floatToHalf(lut.values[i * 3 + 2]);
		data[i * 4 + 3] = one;
	}
	return data;
}

let defaultTexels: Uint16Array<ArrayBuffer> | null = null;

// The SDR sRGB LUT shared by every renderer on the page (bakes in ~0.2 s on first use).
export function defaultToneLUTTexels(): Uint16Array<ArrayBuffer> {
	defaultTexels ??= packToneLUT(bakeToneLUT());
	return defaultTexels;
}

export function createToneLUTTexture(device: GPUDevice, texels = defaultToneLUTTexels(), size = TONE_LUT_SIZE): GPUTexture {
	const texture = device.createTexture({
		label: 'aces2ToneLUT',
		dimension: '3d',
		size: [size, size, size],
		format: 'rgba16float',
		usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
	});
	device.queue.writeTexture({ texture }, texels, { bytesPerRow: size * 8, rowsPerImage: size }, [size, size, size]);
	return texture;
}

// CPU reference of the shader lookup (trilinear between texel centers).
export function sampleToneLUT(lut: ToneLUT, linear: Vec3): Vec3 {
	const n = lut.size;
	const p = linear.map((c) => lutEncode(c) * (n - 1)) as Vec3;
	const i0 = p.map((x) => Math.min(Math.floor(x), n - 2));
	const f = p.map((x, k) => x - i0[k]);
	const out: Vec3 = [0, 0, 0];
	for (let corner = 0; corner < 8; corner++) {
		const dx = corner & 1, dy = (corner >> 1) & 1, dz = corner >> 2;
		const w = (dx ? f[0] : 1 - f[0]) * (dy ? f[1] : 1 - f[1]) * (dz ? f[2] : 1 - f[2]);
		const idx = (((i0[2] + dz) * n + i0[1] + dy) * n + i0[0] + dx) * 3;
		out[0] += w * lut.values[idx];
		out[1] += w * lut.values[idx + 1];
		out[2] += w * lut.values[idx + 2];
	}
	return out;
}
