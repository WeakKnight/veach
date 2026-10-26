// CPU-side texture data for the virtual texture system: a power-of-two RGBA8 mip chain down to
// the tail level, and extraction of bordered physical pages from it.
import { WrapMode } from '../../scene/Scene';
import { VT_BORDER, VT_PAGE_SIZE, VT_PITCH } from './VirtualTextureLayout';

export interface MipLevel {
	width: number;
	height: number;
	data: Uint8Array; // rgba8
}

const SRGB_TO_LINEAR = new Float32Array(256);
for (let i = 0; i < 256; i++) {
	const c = i / 255;
	SRGB_TO_LINEAR[i] = c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}
const LINEAR_TO_SRGB_STEPS = 4096;
const LINEAR_TO_SRGB = new Uint8Array(LINEAR_TO_SRGB_STEPS + 1);
for (let i = 0; i <= LINEAR_TO_SRGB_STEPS; i++) {
	const c = i / LINEAR_TO_SRGB_STEPS;
	const s = c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
	LINEAR_TO_SRGB[i] = Math.round(Math.min(Math.max(s, 0), 1) * 255);
}

function downsample(src: MipLevel, srgb: boolean): MipLevel {
	const width = Math.max(src.width >> 1, 1);
	const height = Math.max(src.height >> 1, 1);
	const sx = src.width > 1 ? 2 : 1;
	const sy = src.height > 1 ? 2 : 1;
	const inv = 1 / (sx * sy);
	const data = new Uint8Array(width * height * 4);
	const s = src.data;
	for (let y = 0; y < height; y++) {
		for (let x = 0; x < width; x++) {
			let r = 0, g = 0, b = 0, a = 0;
			for (let dy = 0; dy < sy; dy++) {
				let i = ((y * sy + dy) * src.width + x * sx) * 4;
				for (let dx = 0; dx < sx; dx++, i += 4) {
					if (srgb) {
						r += SRGB_TO_LINEAR[s[i]];
						g += SRGB_TO_LINEAR[s[i + 1]];
						b += SRGB_TO_LINEAR[s[i + 2]];
					} else {
						r += s[i];
						g += s[i + 1];
						b += s[i + 2];
					}
					a += s[i + 3];
				}
			}
			const o = (y * width + x) * 4;
			if (srgb) {
				data[o] = LINEAR_TO_SRGB[Math.round(r * inv * LINEAR_TO_SRGB_STEPS)];
				data[o + 1] = LINEAR_TO_SRGB[Math.round(g * inv * LINEAR_TO_SRGB_STEPS)];
				data[o + 2] = LINEAR_TO_SRGB[Math.round(b * inv * LINEAR_TO_SRGB_STEPS)];
			} else {
				data[o] = Math.round(r * inv);
				data[o + 1] = Math.round(g * inv);
				data[o + 2] = Math.round(b * inv);
			}
			data[o + 3] = Math.round(a * inv);
		}
	}
	return { width, height, data };
}

// width / height must be powers of two.
export function buildMipChain(base: MipLevel, levels: number, srgb: boolean): MipLevel[] {
	const chain = [base];
	for (let l = 1; l < levels; l++) {
		chain.push(downsample(chain[l - 1], srgb));
	}
	return chain;
}

function wrapIndex(i: number, n: number, mode: WrapMode): number {
	switch (mode) {
		case WrapMode.Clamp:
			return Math.min(Math.max(i, 0), n - 1);
		case WrapMode.Mirror: {
			const t = ((i % (2 * n)) + 2 * n) % (2 * n);
			return t < n ? t : 2 * n - 1 - t;
		}
		default:
			return ((i % n) + n) % n;
	}
}

// One physical page: VT_PITCH^2 texels, content texel (0,0) of the page at (VT_BORDER, VT_BORDER).
// Texels outside the mip (borders, and partially covered pages) follow the wrap mode.
export function extractTile(level: MipLevel, px: number, py: number, wrapS: WrapMode, wrapT: WrapMode, out = new Uint8Array(VT_PITCH * VT_PITCH * 4)): Uint8Array {
	const src = new Uint32Array(level.data.buffer, level.data.byteOffset, level.width * level.height);
	const dst = new Uint32Array(out.buffer, out.byteOffset, VT_PITCH * VT_PITCH);
	const xs = new Int32Array(VT_PITCH);
	for (let x = 0; x < VT_PITCH; x++) {
		xs[x] = wrapIndex(px * VT_PAGE_SIZE + x - VT_BORDER, level.width, wrapS);
	}
	for (let y = 0; y < VT_PITCH; y++) {
		const row = wrapIndex(py * VT_PAGE_SIZE + y - VT_BORDER, level.height, wrapT) * level.width;
		const o = y * VT_PITCH;
		for (let x = 0; x < VT_PITCH; x++) {
			dst[o + x] = src[row + xs[x]];
		}
	}
	return out;
}

// Nearest-neighbour CPU sampling (used to estimate emissive power on the host).
export class CpuTexture {
	constructor(private readonly level: MipLevel) {}

	sample(u: number, v: number, srgb: boolean): [number, number, number] {
		const { width, height, data } = this.level;
		const x = ((Math.floor(u * width) % width) + width) % width;
		const y = ((Math.floor(v * height) % height) + height) % height;
		const i = (y * width + x) * 4;
		const decode = (c: number) => (srgb ? SRGB_TO_LINEAR[c] : c / 255);
		return [decode(data[i]), decode(data[i + 1]), decode(data[i + 2])];
	}
}
