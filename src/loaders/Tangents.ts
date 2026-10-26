// Per-vertex tangent generation (Lengyel) for meshes with normal maps but no TANGENT attribute.
export function generateTangents(positions: Float32Array, normals: Float32Array, uvs: Float32Array, indices: Uint32Array): Float32Array {
	const vertexCount = positions.length / 3;
	const tan = new Float64Array(vertexCount * 3);
	const bit = new Float64Array(vertexCount * 3);

	for (let t = 0; t < indices.length; t += 3) {
		const i0 = indices[t], i1 = indices[t + 1], i2 = indices[t + 2];
		const e1x = positions[i1 * 3] - positions[i0 * 3];
		const e1y = positions[i1 * 3 + 1] - positions[i0 * 3 + 1];
		const e1z = positions[i1 * 3 + 2] - positions[i0 * 3 + 2];
		const e2x = positions[i2 * 3] - positions[i0 * 3];
		const e2y = positions[i2 * 3 + 1] - positions[i0 * 3 + 1];
		const e2z = positions[i2 * 3 + 2] - positions[i0 * 3 + 2];
		const du1 = uvs[i1 * 2] - uvs[i0 * 2];
		const dv1 = uvs[i1 * 2 + 1] - uvs[i0 * 2 + 1];
		const du2 = uvs[i2 * 2] - uvs[i0 * 2];
		const dv2 = uvs[i2 * 2 + 1] - uvs[i0 * 2 + 1];
		const det = du1 * dv2 - du2 * dv1;
		if (Math.abs(det) < 1e-20) {
			continue;
		}
		const r = 1 / det;
		const tx = (e1x * dv2 - e2x * dv1) * r;
		const ty = (e1y * dv2 - e2y * dv1) * r;
		const tz = (e1z * dv2 - e2z * dv1) * r;
		const bx = (e2x * du1 - e1x * du2) * r;
		const by = (e2y * du1 - e1y * du2) * r;
		const bz = (e2z * du1 - e1z * du2) * r;
		for (const i of [i0, i1, i2]) {
			tan[i * 3] += tx;
			tan[i * 3 + 1] += ty;
			tan[i * 3 + 2] += tz;
			bit[i * 3] += bx;
			bit[i * 3 + 1] += by;
			bit[i * 3 + 2] += bz;
		}
	}

	const out = new Float32Array(vertexCount * 4);
	for (let i = 0; i < vertexCount; i++) {
		const nx = normals[i * 3], ny = normals[i * 3 + 1], nz = normals[i * 3 + 2];
		let tx = tan[i * 3], ty = tan[i * 3 + 1], tz = tan[i * 3 + 2];
		// Gram-Schmidt against the normal
		const d = nx * tx + ny * ty + nz * tz;
		tx -= nx * d;
		ty -= ny * d;
		tz -= nz * d;
		const len = Math.hypot(tx, ty, tz);
		if (len < 1e-12) {
			continue; // w = 0: the shader falls back to an arbitrary frame
		}
		tx /= len;
		ty /= len;
		tz /= len;
		// handedness: sign(dot(cross(n, t), b))
		const cx = ny * tz - nz * ty, cy = nz * tx - nx * tz, cz = nx * ty - ny * tx;
		const w = cx * bit[i * 3] + cy * bit[i * 3 + 1] + cz * bit[i * 3 + 2] < 0 ? -1 : 1;
		out.set([tx, ty, tz, w], i * 4);
	}
	return out;
}
