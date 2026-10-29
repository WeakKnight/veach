// Geometry-only raster clusters. Primitive identities stay in the original mesh order.
export const VISIBILITY_CLUSTER_TRIANGLES = 64;
export interface VisibilityClusters { words: Uint32Array; count: number }

export function buildVisibilityClusters(positions: Float32Array, indices: Uint32Array): VisibilityClusters {
	const count = indices.length / 3, clusters = Math.ceil(count / VISIBILITY_CLUSTER_TRIANGLES);
	const centroids = new Float64Array(count * 3), lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
	for (let t = 0; t < count; t++) for (let a = 0; a < 3; a++) {
		const c = (positions[indices[t * 3] * 3 + a] + positions[indices[t * 3 + 1] * 3 + a] + positions[indices[t * 3 + 2] * 3 + a]) / 3;
		centroids[t * 3 + a] = c; lo[a] = Math.min(lo[a], c); hi[a] = Math.max(hi[a], c);
	}
	const spread = (x: number) => {
		x = (x | (x << 16)) & 0x030000ff; x = (x | (x << 8)) & 0x0300f00f;
		x = (x | (x << 4)) & 0x030c30c3; return (x | (x << 2)) & 0x09249249;
	};
	const keys = new Uint32Array(count);
	for (let t = 0; t < count; t++) for (let a = 0; a < 3; a++)
		keys[t] |= spread(Math.min(1023, Math.max(0, Math.floor((centroids[t * 3 + a] - lo[a]) / (hi[a] - lo[a] || 1) * 1023)))) << a;
	const order = Array.from({ length: count }, (_, i) => i).sort((a, b) => keys[a] - keys[b] || a - b);
	// Eight words per descriptor: min.xyz, relative primitive-list offset, max.xyz, count.
	const words = new Uint32Array(clusters * 8 + count), floats = new Float32Array(words.buffer);
	for (let c = 0; c < clusters; c++) {
		const begin = c * 64, end = Math.min(begin + 64, count), base = c * 8;
		floats.set([Infinity, Infinity, Infinity], base); floats.set([-Infinity, -Infinity, -Infinity], base + 4);
		words[base + 3] = clusters * 8 + begin; words[base + 7] = end - begin;
		for (let i = begin; i < end; i++) {
			const t = order[i]; words[clusters * 8 + i] = t;
			for (let v = 0; v < 3; v++) for (let a = 0; a < 3; a++) {
				const p = positions[indices[t * 3 + v] * 3 + a];
				floats[base + a] = Math.min(floats[base + a], p); floats[base + 4 + a] = Math.max(floats[base + 4 + a], p);
			}
		}
	}
	return { words, count: clusters };
}

// Relocate primitive-list offsets when placing a shared geometry block in gIndices.
export function relocateVisibilityClusters(clusters: VisibilityClusters, wordOffset: number): Uint32Array {
	const words = clusters.words.slice();
	for (let c = 0; c < clusters.count; c++) words[c * 8 + 3] += wordOffset;
	return words;
}
