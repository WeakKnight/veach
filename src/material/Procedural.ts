// Blender's procedural textures (Cycles kernel/svm: noise.h, fractal_noise.h, noisetex.h, magic.h,
// checker.h), 3D only. Mirrored by shaders/Materials/Procedural.slang.
import type { Vec3 } from '../math/Math';

const f32 = new Float32Array(1);
const u32 = new Uint32Array(f32.buffer);

function floatBits(x: number): number {
	f32[0] = x;
	return u32[0];
}

const rot = (x: number, k: number) => ((x << k) | (x >>> (32 - k))) >>> 0;

// Bob Jenkins' lookup3 final(a, b, c); returns c.
function final(a: number, b: number, c: number): number {
	c = ((c ^ b) - rot(b, 14)) >>> 0;
	a = ((a ^ c) - rot(c, 11)) >>> 0;
	b = ((b ^ a) - rot(a, 25)) >>> 0;
	c = ((c ^ b) - rot(b, 16)) >>> 0;
	a = ((a ^ c) - rot(c, 4)) >>> 0;
	b = ((b ^ a) - rot(a, 14)) >>> 0;
	c = ((c ^ b) - rot(b, 24)) >>> 0;
	return c;
}

export function hashUint2(kx: number, ky: number): number {
	const init = (0xdeadbeef + (2 << 2) + 13) >>> 0;
	return final((init + kx) >>> 0, (init + ky) >>> 0, init);
}

export function hashUint3(kx: number, ky: number, kz: number): number {
	const init = (0xdeadbeef + (3 << 2) + 13) >>> 0;
	return final((init + kx) >>> 0, (init + ky) >>> 0, (init + kz) >>> 0);
}

// hash_float2_to_float
function hashFloat2(x: number, y: number): number {
	return hashUint2(floatBits(x), floatBits(y)) / 0xffffffff;
}

// random_float3_offset: components in [100, 200].
export function randomOffset3(seed: number): Vec3 {
	return [100 + hashFloat2(seed, 0) * 100, 100 + hashFloat2(seed, 1) * 100, 100 + hashFloat2(seed, 2) * 100];
}

const fade = (t: number) => t * t * t * (t * (t * 6 - 15) + 10);

function grad3(hash: number, x: number, y: number, z: number): number {
	const h = hash & 15;
	const u = h < 8 ? x : y;
	const v = h < 4 ? y : h === 12 || h === 14 ? x : z;
	return (h & 1 ? -u : u) + (h & 2 ? -v : v);
}

function perlin3(x: number, y: number, z: number): number {
	const X = Math.floor(x);
	const Y = Math.floor(y);
	const Z = Math.floor(z);
	const fx = x - X;
	const fy = y - Y;
	const fz = z - Z;
	const u = fade(fx);
	const v = fade(fy);
	const w = fade(fz);
	const h = (i: number, j: number, k: number) => hashUint3((X + i) >>> 0, (Y + j) >>> 0, (Z + k) >>> 0);
	const lerp = (a: number, b: number, t: number) => (1 - t) * a + t * b;
	const x00 = lerp(grad3(h(0, 0, 0), fx, fy, fz), grad3(h(1, 0, 0), fx - 1, fy, fz), u);
	const x10 = lerp(grad3(h(0, 1, 0), fx, fy - 1, fz), grad3(h(1, 1, 0), fx - 1, fy - 1, fz), u);
	const x01 = lerp(grad3(h(0, 0, 1), fx, fy, fz - 1), grad3(h(1, 0, 1), fx - 1, fy, fz - 1), u);
	const x11 = lerp(grad3(h(0, 1, 1), fx, fy - 1, fz - 1), grad3(h(1, 1, 1), fx - 1, fy - 1, fz - 1), u);
	return lerp(lerp(x00, x10, v), lerp(x01, x11, v), w);
}

// Signed noise in about [-1, 1], repeating every 100000 units.
export function snoise3(p: readonly number[]): number {
	const wrap = (x: number) => (x % 100000) + (Math.abs(x) >= 1000000 ? 0.5 : 0);
	return 0.982 * perlin3(wrap(p[0]), wrap(p[1]), wrap(p[2]));
}

export function noiseFbm(p: readonly number[], detail: number, roughness: number, lacunarity: number, normalize: boolean): number {
	let fscale = 1;
	let amp = 1;
	let maxamp = 0;
	let sum = 0;
	const octaves = Math.trunc(detail);
	for (let i = 0; i <= octaves; i++) {
		sum += snoise3([fscale * p[0], fscale * p[1], fscale * p[2]]) * amp;
		maxamp += amp;
		amp *= roughness;
		fscale *= lacunarity;
	}
	const rmd = detail - Math.floor(detail);
	if (rmd !== 0) {
		const sum2 = sum + snoise3([fscale * p[0], fscale * p[1], fscale * p[2]]) * amp;
		const a = normalize ? (0.5 * sum) / maxamp + 0.5 : sum;
		const b = normalize ? (0.5 * sum2) / (maxamp + amp) + 0.5 : sum2;
		return a + (b - a) * rmd;
	}
	return normalize ? (0.5 * sum) / maxamp + 0.5 : sum;
}

const add3 = (p: readonly number[], o: Vec3): Vec3 => [p[0] + o[0], p[1] + o[1], p[2] + o[2]];

// Noise Texture (fBM, 3D) at scaled coordinates. params: detail, roughness, lacunarity,
// distortion. Returns (fac, color.g, color.b); color.r is fac.
export function blenderNoise(co: readonly number[], params: readonly number[], normalize: boolean, color: boolean): Vec3 {
	const detail = Math.min(Math.max(params[0], 0), 15);
	const roughness = Math.max(params[1], 0);
	const lacunarity = params[2];
	const distortion = params[3];
	let p: Vec3 = [co[0], co[1], co[2]];
	if (distortion !== 0) {
		p = [
			p[0] + snoise3(add3(p, randomOffset3(0))) * distortion,
			p[1] + snoise3(add3(p, randomOffset3(1))) * distortion,
			p[2] + snoise3(add3(p, randomOffset3(2))) * distortion,
		];
	}
	const value = noiseFbm(p, detail, roughness, lacunarity, normalize);
	if (!color) {
		return [value, value, value];
	}
	return [value, noiseFbm(add3(p, randomOffset3(3)), detail, roughness, lacunarity, normalize), noiseFbm(add3(p, randomOffset3(4)), detail, roughness, lacunarity, normalize)];
}

// Magic Texture at unscaled coordinates times scale (applied by the caller). Returns rgb.
export function blenderMagic(p: readonly number[], depth: number, distortion: number): Vec3 {
	const TWO_PI = 2 * Math.PI;
	const px = p[0] % TWO_PI;
	const py = p[1] % TWO_PI;
	const pz = p[2] % TWO_PI;
	let x = Math.sin((px + py + pz) * 5);
	let y = Math.cos((-px + py - pz) * 5);
	let z = -Math.cos((-px - py + pz) * 5);
	const d = distortion;
	if (depth > 0) {
		x *= d;
		y *= d;
		z *= d;
		y = -Math.cos(x - y + z) * d;
		if (depth > 1) {
			x = Math.cos(x - y - z) * d;
			if (depth > 2) {
				z = Math.sin(-x - y - z) * d;
				if (depth > 3) {
					x = -Math.cos(-x + y - z) * d;
					if (depth > 4) {
						y = -Math.sin(-x + y + z) * d;
						if (depth > 5) {
							y = -Math.cos(-x + y + z) * d;
							if (depth > 6) {
								x = Math.cos(x + y + z) * d;
								if (depth > 7) {
									z = Math.sin(x + y - z) * d;
									if (depth > 8) {
										x = -Math.cos(-x - y + z) * d;
										if (depth > 9) {
											y = -Math.sin(x - y + z) * d;
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
	if (d !== 0) {
		x /= 2 * d;
		y /= 2 * d;
		z /= 2 * d;
	}
	return [0.5 - x, 0.5 - y, 0.5 - z];
}

// Checker Texture factor (1 = Color1) at scaled coordinates.
export function blenderChecker(p: readonly number[]): number {
	const cell = (x: number) => Math.abs(Math.floor((x + 0.000001) * 0.999999)) % 2;
	const xi = cell(p[0]);
	const yi = cell(p[1]);
	const zi = cell(p[2]);
	return (xi === yi) === (zi === 1) ? 1 : 0;
}
