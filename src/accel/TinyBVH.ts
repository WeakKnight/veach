// tinybvh compiled to WebAssembly (wasm/tinybvh_wasm.cpp). Builds CWBVH BLASes and a BVH_GPU TLAS and copies them
// out of the WASM heap in the exact layout consumed by shaders/RayTracing/Traversal.slang.
import createTinyBVHModule, { type TinyBVHModule } from '../generated/tinybvh/tinybvh.mjs';
import type { Vec3 } from '../math/Math';

// Node buffers are addressed in float4 blocks: 4 per BVH_GPU node (TLAS), 5 per CWBVH node (BLAS).
export const BVH_NODE_BYTES = 16;
export const TLAS_NODE_BLOCKS = 4;
export const BLAS_NODE_BLOCKS = 5;
export const BVH_TRI_FLOATS = 12; // 3 x float4: v0 | asfloat(primIdx), e1, e2

export enum BuildQuality {
	Fast = 0, // binned SAH
	High = 1, // SBVH with spatial splits
}

export interface BLASData {
	nodes: ArrayBuffer; // nodeBlocks * 16 bytes: CWBVH nodes (Ylitie et al. 2017), 80 bytes each, root first
	nodeBlocks: number;
	nodeCount: number;
	tris: Float32Array; // primRefCount * 12 floats, in CWBVH triangle slot order
	primRefCount: number;
	boundsMin: Vec3;
	boundsMax: Vec3;
}

export interface TLASData {
	nodes: ArrayBuffer; // nodeBlocks * 16 bytes: BVH_GPU nodes, 64 bytes each
	nodeBlocks: number;
	nodeCount: number;
	primIndices: Uint32Array; // leaf offset -> instance index
}

export class TinyBVH {
	private constructor(private readonly module: TinyBVHModule) {}

	static async create(): Promise<TinyBVH> {
		return new TinyBVH(await createTinyBVHModule());
	}

	get version(): string {
		const v = this.module._tb_version();
		return `${Math.floor(v / 10000)}.${Math.floor(v / 100) % 100}.${v % 100}`;
	}

	// positions: xyz per vertex; indices: 3 per triangle.
	buildBLAS(positions: Float32Array, indices: Uint32Array, quality = BuildQuality.Fast): BLASData {
		const m = this.module;
		const vertexCount = positions.length / 3;
		const triCount = indices.length / 3;
		const vertPtr = m._tb_malloc(vertexCount * 16);
		const idxPtr = m._tb_malloc(indices.byteLength);
		const boundsPtr = m._tb_malloc(24);
		try {
			const heapF32 = m.HEAPF32;
			const base = vertPtr >> 2;
			for (let i = 0; i < vertexCount; i++) {
				heapF32[base + i * 4 + 0] = positions[i * 3 + 0];
				heapF32[base + i * 4 + 1] = positions[i * 3 + 1];
				heapF32[base + i * 4 + 2] = positions[i * 3 + 2];
				heapF32[base + i * 4 + 3] = 0;
			}
			m.HEAPU32.set(indices, idxPtr >> 2);

			const handle = m._tb_build_blas(vertPtr, vertexCount, idxPtr, triCount, quality);
			if (!handle) {
				throw new Error('tinybvh: BLAS build failed');
			}
			try {
				const nodeBlocks = m._tb_node_blocks(handle);
				const primRefCount = m._tb_prim_ref_count(handle);
				// heap views may have been replaced by memory growth during the build
				const nodes = m.HEAPU8.slice(m._tb_nodes(handle), m._tb_nodes(handle) + nodeBlocks * BVH_NODE_BYTES).buffer;
				const trisPtr = m._tb_ordered_tris(handle) >> 2;
				const tris = m.HEAPF32.slice(trisPtr, trisPtr + primRefCount * BVH_TRI_FLOATS);
				m._tb_bounds(handle, boundsPtr);
				const b = m.HEAPF32.subarray(boundsPtr >> 2, (boundsPtr >> 2) + 6);
				return { nodes, nodeBlocks, nodeCount: nodeBlocks / BLAS_NODE_BLOCKS, tris, primRefCount, boundsMin: [b[0], b[1], b[2]], boundsMax: [b[3], b[4], b[5]] };
			} finally {
				m._tb_destroy(handle);
			}
		} finally {
			m._tb_free(vertPtr);
			m._tb_free(idxPtr);
			m._tb_free(boundsPtr);
		}
	}

	// aabbs: count * 8 floats (min.xyz, pad, max.xyz, pad).
	buildTLAS(aabbs: Float32Array): TLASData {
		const m = this.module;
		const count = aabbs.length / 8;
		const ptr = m._tb_malloc(aabbs.byteLength);
		try {
			m.HEAPF32.set(aabbs, ptr >> 2);
			const handle = m._tb_build_tlas(ptr, count);
			if (!handle) {
				throw new Error('tinybvh: TLAS build failed');
			}
			try {
				const nodeBlocks = m._tb_node_blocks(handle);
				const nodesPtr = m._tb_nodes(handle);
				const nodes = m.HEAPU8.slice(nodesPtr, nodesPtr + nodeBlocks * BVH_NODE_BYTES).buffer;
				const primPtr = m._tb_prim_indices(handle) >> 2;
				const primIndices = m.HEAPU32.slice(primPtr, primPtr + m._tb_prim_ref_count(handle));
				return { nodes, nodeBlocks, nodeCount: nodeBlocks / TLAS_NODE_BLOCKS, primIndices };
			} finally {
				m._tb_destroy(handle);
			}
		} finally {
			m._tb_free(ptr);
		}
	}
}
