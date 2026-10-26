// Minimal vector / matrix helpers. Matrices are column-major Float32Array(16), as in glTF.

export type Vec3 = [number, number, number];
export type Mat4 = Float32Array;

export const vec3 = {
	add: (a: Vec3, b: Vec3): Vec3 => [a[0] + b[0], a[1] + b[1], a[2] + b[2]],
	sub: (a: Vec3, b: Vec3): Vec3 => [a[0] - b[0], a[1] - b[1], a[2] - b[2]],
	scale: (a: Vec3, s: number): Vec3 => [a[0] * s, a[1] * s, a[2] * s],
	dot: (a: Vec3, b: Vec3): number => a[0] * b[0] + a[1] * b[1] + a[2] * b[2],
	cross: (a: Vec3, b: Vec3): Vec3 => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]],
	length: (a: Vec3): number => Math.hypot(a[0], a[1], a[2]),
	normalize: (a: Vec3): Vec3 => {
		const len = Math.hypot(a[0], a[1], a[2]);
		return len > 0 ? [a[0] / len, a[1] / len, a[2] / len] : [0, 0, 0];
	},
	min: (a: Vec3, b: Vec3): Vec3 => [Math.min(a[0], b[0]), Math.min(a[1], b[1]), Math.min(a[2], b[2])],
	max: (a: Vec3, b: Vec3): Vec3 => [Math.max(a[0], b[0]), Math.max(a[1], b[1]), Math.max(a[2], b[2])],
	lerp: (a: Vec3, b: Vec3, t: number): Vec3 => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t],
};

export const mat4 = {
	identity(): Mat4 {
		const m = new Float32Array(16);
		m[0] = m[5] = m[10] = m[15] = 1;
		return m;
	},

	multiply(a: Mat4, b: Mat4): Mat4 {
		const out = new Float32Array(16);
		for (let c = 0; c < 4; c++) {
			for (let r = 0; r < 4; r++) {
				let sum = 0;
				for (let k = 0; k < 4; k++) {
					sum += a[k * 4 + r] * b[c * 4 + k];
				}
				out[c * 4 + r] = sum;
			}
		}
		return out;
	},

	// translation * rotation(quaternion xyzw) * scale
	fromTRS(t: ArrayLike<number>, q: ArrayLike<number>, s: ArrayLike<number>): Mat4 {
		const [x, y, z, w] = [q[0], q[1], q[2], q[3]];
		const xx = x * x, yy = y * y, zz = z * z;
		const xy = x * y, xz = x * z, yz = y * z;
		const wx = w * x, wy = w * y, wz = w * z;
		const m = new Float32Array(16);
		m[0] = (1 - 2 * (yy + zz)) * s[0];
		m[1] = 2 * (xy + wz) * s[0];
		m[2] = 2 * (xz - wy) * s[0];
		m[4] = 2 * (xy - wz) * s[1];
		m[5] = (1 - 2 * (xx + zz)) * s[1];
		m[6] = 2 * (yz + wx) * s[1];
		m[8] = 2 * (xz + wy) * s[2];
		m[9] = 2 * (yz - wx) * s[2];
		m[10] = (1 - 2 * (xx + yy)) * s[2];
		m[12] = t[0];
		m[13] = t[1];
		m[14] = t[2];
		m[15] = 1;
		return m;
	},

	invert(m: Mat4): Mat4 | null {
		const a00 = m[0], a01 = m[1], a02 = m[2], a03 = m[3];
		const a10 = m[4], a11 = m[5], a12 = m[6], a13 = m[7];
		const a20 = m[8], a21 = m[9], a22 = m[10], a23 = m[11];
		const a30 = m[12], a31 = m[13], a32 = m[14], a33 = m[15];
		const b00 = a00 * a11 - a01 * a10;
		const b01 = a00 * a12 - a02 * a10;
		const b02 = a00 * a13 - a03 * a10;
		const b03 = a01 * a12 - a02 * a11;
		const b04 = a01 * a13 - a03 * a11;
		const b05 = a02 * a13 - a03 * a12;
		const b06 = a20 * a31 - a21 * a30;
		const b07 = a20 * a32 - a22 * a30;
		const b08 = a20 * a33 - a23 * a30;
		const b09 = a21 * a32 - a22 * a31;
		const b10 = a21 * a33 - a23 * a31;
		const b11 = a22 * a33 - a23 * a32;
		const det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;
		if (!det) {
			return null;
		}
		const inv = 1 / det;
		const out = new Float32Array(16);
		out[0] = (a11 * b11 - a12 * b10 + a13 * b09) * inv;
		out[1] = (a02 * b10 - a01 * b11 - a03 * b09) * inv;
		out[2] = (a31 * b05 - a32 * b04 + a33 * b03) * inv;
		out[3] = (a22 * b04 - a21 * b05 - a23 * b03) * inv;
		out[4] = (a12 * b08 - a10 * b11 - a13 * b07) * inv;
		out[5] = (a00 * b11 - a02 * b08 + a03 * b07) * inv;
		out[6] = (a32 * b02 - a30 * b05 - a33 * b01) * inv;
		out[7] = (a20 * b05 - a22 * b02 + a23 * b01) * inv;
		out[8] = (a10 * b10 - a11 * b08 + a13 * b06) * inv;
		out[9] = (a01 * b08 - a00 * b10 - a03 * b06) * inv;
		out[10] = (a30 * b04 - a31 * b02 + a33 * b00) * inv;
		out[11] = (a21 * b02 - a20 * b04 - a23 * b00) * inv;
		out[12] = (a11 * b07 - a10 * b09 - a12 * b06) * inv;
		out[13] = (a00 * b09 - a01 * b07 + a02 * b06) * inv;
		out[14] = (a31 * b01 - a30 * b03 - a32 * b00) * inv;
		out[15] = (a20 * b03 - a21 * b01 + a22 * b00) * inv;
		return out;
	},

	transformPoint(m: Mat4, p: ArrayLike<number>): Vec3 {
		return [
			m[0] * p[0] + m[4] * p[1] + m[8] * p[2] + m[12],
			m[1] * p[0] + m[5] * p[1] + m[9] * p[2] + m[13],
			m[2] * p[0] + m[6] * p[1] + m[10] * p[2] + m[14],
		];
	},

	transformVector(m: Mat4, v: ArrayLike<number>): Vec3 {
		return [
			m[0] * v[0] + m[4] * v[1] + m[8] * v[2],
			m[1] * v[0] + m[5] * v[1] + m[9] * v[2],
			m[2] * v[0] + m[6] * v[1] + m[10] * v[2],
		];
	},

	// Normals transform with the inverse transpose; pass the inverse matrix.
	transformNormal(inverse: Mat4, n: ArrayLike<number>): Vec3 {
		return [
			inverse[0] * n[0] + inverse[1] * n[1] + inverse[2] * n[2],
			inverse[4] * n[0] + inverse[5] * n[1] + inverse[6] * n[2],
			inverse[8] * n[0] + inverse[9] * n[1] + inverse[10] * n[2],
		];
	},

	transformAABB(m: Mat4, min: Vec3, max: Vec3): { min: Vec3; max: Vec3 } {
		let outMin: Vec3 = [Infinity, Infinity, Infinity];
		let outMax: Vec3 = [-Infinity, -Infinity, -Infinity];
		for (let i = 0; i < 8; i++) {
			const p = mat4.transformPoint(m, [i & 1 ? max[0] : min[0], i & 2 ? max[1] : min[1], i & 4 ? max[2] : min[2]]);
			outMin = vec3.min(outMin, p);
			outMax = vec3.max(outMax, p);
		}
		return { min: outMin, max: outMax };
	},
};

export function luminance(r: number, g: number, b: number): number {
	return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

export function nextPowerOfTwo(x: number): number {
	return 2 ** Math.ceil(Math.log2(Math.max(1, x)));
}
