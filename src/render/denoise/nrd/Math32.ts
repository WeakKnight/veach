// The MathLib (ThirdParty/MathLib) operations NRD's common settings use, in float32 as the wasm build
// computes them: Emscripten maps the SSE intrinsics onto IEEE wasm SIMD (_mm_rcp_ps is 1 / x, _mm_rsqrt_ps
// is 1 / sqrt(x)), MathLib's FMA emulation multiplies and adds separately, and the Newton-Raphson
// refinements of rcp/rsqrt still apply. Every + - * / sqrt is rounded with Math.fround, which equals
// float32 arithmetic (a double holds 2 * 24 + 2 bits). Lane order and signed zeros follow the intrinsics.
const f = Math.fround;

/** SSE register: four float32 lanes. */
export type V4 = [number, number, number, number];
/** float4x4: four columns. */
export type M4 = [V4, V4, V4, V4];

export const v4 = (x: number, y: number, z: number, w: number): V4 => [f(x), f(y), f(z), f(w)];
export const add = (a: V4, b: V4): V4 => [f(a[0] + b[0]), f(a[1] + b[1]), f(a[2] + b[2]), f(a[3] + b[3])];
export const sub = (a: V4, b: V4): V4 => [f(a[0] - b[0]), f(a[1] - b[1]), f(a[2] - b[2]), f(a[3] - b[3])];
export const mul = (a: V4, b: V4): V4 => [f(a[0] * b[0]), f(a[1] * b[1]), f(a[2] * b[2]), f(a[3] * b[3])];
export const mulScalar = (a: V4, s: number): V4 => [f(a[0] * s), f(a[1] * s), f(a[2] * s), f(a[3] * s)];
export const divScalar = (a: V4, s: number): V4 => [f(a[0] / s), f(a[1] / s), f(a[2] / s), f(a[3] / s)];
/** v4f_negate: flips the sign bit (0 becomes -0). */
export const negate = (a: V4): V4 => [-a[0], -a[1], -a[2], -a[3]];
/** v4f_setw0 / v4f_setw1: and/or masks, so w becomes +0 or exactly 1. */
export const setw0 = (a: V4): V4 => [a[0], a[1], a[2], 0];
export const setw1 = (a: V4): V4 => [a[0], a[1], a[2], 1];
const splat = (s: number): V4 => [s, s, s, s];
/** _mm_fmadd_ps / _mm_fnmadd_ps / _mm_fmsub_ps without FMA hardware. */
const fmadd = (a: V4, b: V4, c: V4) => add(mul(a, b), c);
const fnmadd = (a: V4, b: V4, c: V4) => sub(c, mul(a, b));
const fmsub = (a: V4, b: V4, c: V4) => sub(mul(a, b), c);
/** v4f_swizzle(v, x, y, z, w) and v4f_shuffle(a, b, i0, j0, i1, j1) = (a[i0], a[j0], b[i1], b[j1]). */
const swizzle = (v: V4, x: number, y: number, z: number, w: number): V4 => [v[x], v[y], v[z], v[w]];
const shuffle = (a: V4, b: V4, i0: number, j0: number, i1: number, j1: number): V4 => [a[i0], a[j0], b[i1], b[j1]];

/** _mm_dp_ps as Emscripten emulates it: (t0 + t1) + (t2 + t3), masked lanes zero. */
export function dot44(a: V4, b: V4): number {
	const t = mul(a, b);
	return f(f(t[0] + t[1]) + f(t[2] + t[3]));
}
export function dot33(a: V4, b: V4): number {
	const t = mul(a, b);
	return f(f(t[0] + t[1]) + f(t[2] + 0));
}
export const length3 = (a: V4) => f(Math.sqrt(dot33(a, a)));

/** v4f_rcp with ML_NEWTONRAPHSON_APROXIMATION. */
export function rcp(x: number): number {
	const c = f(1 / x), a = f(c * x), b = f(c + c);
	return f(b - f(a * c));
}

/** v4f_cross (lane w follows the swizzles). */
export function cross(x: V4, y: V4): V4 {
	const a = swizzle(x, 1, 2, 0, 3), b = swizzle(y, 2, 0, 1, 3);
	const c = mul(swizzle(x, 2, 0, 1, 3), swizzle(y, 1, 2, 0, 3));
	return fmsub(a, b, c);
}

export const identity = (): M4 => [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]];
/** float4x4 from 16 column-major floats (float4(m), float4(m + 4), ...). */
export const fromColumns = (m: ArrayLike<number>): M4 => [0, 1, 2, 3].map(c => v4(m[c * 4], m[c * 4 + 1], m[c * 4 + 2], m[c * 4 + 3])) as M4;
export const clone = (m: M4): M4 => m.map(c => [...c]) as M4;
export const transpose = (m: M4): M4 => [0, 1, 2, 3].map(r => [m[0][r], m[1][r], m[2][r], m[3][r]]) as M4;

/** float4x4 * float4. */
export function mulVector(m: M4, v: V4): V4 {
	let r = mul(splat(v[0]), m[0]);
	r = fmadd(splat(v[1]), m[1], r);
	r = fmadd(splat(v[2]), m[2], r);
	return fmadd(splat(v[3]), m[3], r);
}

/** float4x4 * float4x4 (each column of b through a). */
export const mulMatrix = (a: M4, b: M4): M4 => b.map(column => mulVector(a, column)) as M4;

/** Rotate(m, v): the upper 3x3 applied to v.xyz, w = +0. */
export function rotate(m: M4, v: V4): V4 {
	let r = mul(splat(v[0]), m[0]);
	r = fmadd(splat(v[1]), m[1], r);
	r = fmadd(splat(v[2]), m[2], r);
	return setw0(r);
}

/** float4x4::InvertOrtho. */
export function invertOrtho(m: M4): M4 {
	// Transpose3x4: rows 0..2 become columns 0..2; column 3 keeps the translation.
	const t: M4 = [[m[0][0], m[1][0], m[2][0], m[3][0]], [m[0][1], m[1][1], m[2][1], m[3][1]], [m[0][2], m[1][2], m[2][2], m[3][2]], m[3]];
	const translation = negate(rotate(t, t[3]));
	return [setw0(t[0]), setw0(t[1]), setw0(t[2]), setw1(translation)];
}

/** float4x4::Invert (http://forum.devmaster.net/t/sse-mat4-inverse/16799), lane for lane. */
export function invert(m: M4): M4 {
	const [c0, c1, c2, c3] = m;
	const factor = (i: number, j: number, k: number) => {
		const swp0a = shuffle(c3, c2, i, i, i, i), swp0b = shuffle(c3, c2, j, j, j, j);
		const swp00 = shuffle(c2, c1, j, j, j, j), swp01 = swizzle(swp0a, 0, 0, 0, 2);
		const swp02 = swizzle(swp0b, 0, 0, 0, 2), swp03 = shuffle(c2, c1, k, k, k, k);
		return fnmadd(swp02, swp03, mul(swp00, swp01));
	};
	const fac0 = factor(3, 2, 3), fac1 = factor(3, 1, 3), fac2 = factor(2, 1, 2);
	const fac3 = factor(3, 0, 3), fac4 = factor(2, 0, 2), fac5 = factor(1, 0, 1);
	const signA: V4 = [-1, 1, -1, 1], signB: V4 = [1, -1, 1, -1]; // _mm_set_ps lists w first
	const vec = (i: number) => swizzle(shuffle(c1, c0, i, i, i, i), 0, 2, 2, 2);
	const vec0 = vec(0), vec1 = vec(1), vec2 = vec(2), vec3 = vec(3);
	const inv0 = mul(signB, fmadd(vec3, fac2, fnmadd(vec2, fac1, mul(vec1, fac0))));
	const inv1 = mul(signA, fmadd(vec3, fac4, fnmadd(vec2, fac3, mul(vec0, fac0))));
	const inv2 = mul(signB, fmadd(vec3, fac5, fnmadd(vec1, fac3, mul(vec0, fac1))));
	const inv3 = mul(signA, fmadd(vec2, fac5, fnmadd(vec1, fac4, mul(vec0, fac2))));
	const row2 = shuffle(shuffle(inv0, inv1, 0, 0, 0, 0), shuffle(inv2, inv3, 0, 0, 0, 0), 0, 2, 0, 2);
	const rcp0 = splat(rcp(dot44(c0, row2)));
	return [mul(inv0, rcp0), mul(inv1, rcp0), mul(inv2, rcp0), mul(inv3, rcp0)];
}

export const PROJ_ORTHO = 1, PROJ_REVERSED_Z = 2, PROJ_LEFT_HANDED = 4;

/**
 * DecomposeProjection(STYLE_D3D, STYLE_D3D, proj, ...) with MvpToPlanes: flags, the frustum
 * (view-space ray from screen uv) and the projection scales.
 */
export function decomposeProjection(proj: M4): { flags: number; frustum: V4; project: [number, number, number] } {
	const eps = f(1e-7);
	const mt = transpose(proj);
	let l = add(mt[3], mt[0]), r = sub(mt[3], mt[0]), b = add(mt[3], mt[1]), t = sub(mt[3], mt[1]);
	let far = sub(mt[3], mt[2]), near = mt[2];
	const rsqrt = (x: number) => f(1 / f(Math.sqrt(x)));
	l = mulScalar(l, rsqrt(dot33(l, l)));
	r = mulScalar(r, rsqrt(dot33(r, r)));
	b = mulScalar(b, rsqrt(dot33(b, b)));
	t = mulScalar(t, rsqrt(dot33(t, t)));
	near = divScalar(near, Math.max(length3(near), eps));
	far = divScalar(far, Math.max(length3(far), eps));
	const reversed = Math.abs(near[3]) > Math.abs(far[3]);
	if (reversed) [near, far] = [far, near];
	if (length3(far) < eps) far = [-near[0], -near[1], -near[2], far[3]];

	const ortho = proj[3][3] === 1;
	const nearZ = -near[3];
	let x0: number, x1: number, y0: number, y1: number;
	if (ortho) {
		x0 = -l[3]; x1 = r[3]; y0 = -b[3]; y1 = t[3];
		if (proj[1][1] < 0) [y0, y1] = [y1, y0];
	} else {
		x0 = f(l[2] / l[0]); x1 = f(r[2] / r[0]); y0 = f(b[2] / b[1]); y1 = f(t[2] / t[1]);
	}
	const clip = mulVector(proj, [0, 0, nearZ, 1]);
	const col2: V4 = ortho ? mulScalar(setw0(proj[2]), reversed ? -1 : 1) : [0, 0, clip[3] > 0 ? 1 : -1, 0];
	const cmp = dot33(cross(proj[0], proj[1]), col2) > 0;
	const leftHanded = proj[1][1] > 0 ? cmp : !cmp;
	const flags = (ortho ? PROJ_ORTHO : 0) | (reversed ? PROJ_REVERSED_Z : 0) | (leftHanded ? PROJ_LEFT_HANDED : 0);
	const frustum: V4 = [-x0, -y1, f(x0 - x1), f(y1 - y0)];
	const project: [number, number, number] = [Math.abs(f(2 / f(x1 - x0))), Math.abs(f(2 / f(y1 - y0))), ortho ? 1 : 0];
	return { flags, frustum, project };
}

/** ml::Sequence::Weyl1D: frac(p + float(n * 10368889) / 2^24), with uint32 multiplication. */
export function weyl1D(p: number, n: number): number {
	const x = f(p + f(f((Math.imul(n, 10368889) >>> 0)) / 16777216));
	return f(x - Math.floor(x));
}

/** ml::Geometry::GetRotator(angle) = (cos, sin, -sin, cos) through cosf / sinf. */
export function rotator(angle: number): V4 {
	const c = f(Math.cos(angle)), s = f(Math.sin(angle));
	return [c, s, -s, c];
}

/** ml::radians in float: x * (Pi(1) / 180). */
export const radians = (x: number) => f(x * f(f(Math.PI) / 180));
export const lerp = (a: number, b: number, x: number) => f(a + f(f(b - a) * x));
export const clamp = (x: number, a: number, b: number) => x < a ? a : x > b ? b : x;
export const saturate = (x: number) => clamp(x, 0, 1);
