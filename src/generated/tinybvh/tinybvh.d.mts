// Type declarations for the Emscripten module produced by scripts/build-wasm.mjs.
export interface TinyBVHModule {
	HEAPU8: Uint8Array;
	HEAPF32: Float32Array;
	HEAPU32: Uint32Array;
	_tb_malloc(bytes: number): number;
	_tb_free(ptr: number): void;
	_tb_version(): number;
	_tb_build_blas(vertices: number, vertexCount: number, indices: number, triCount: number, quality: number): number;
	_tb_build_tlas(aabbs: number, count: number): number;
	_tb_destroy(handle: number): void;
	_tb_node_count(handle: number): number;
	_tb_nodes(handle: number): number;
	_tb_prim_ref_count(handle: number): number;
	_tb_ordered_tris(handle: number): number;
	_tb_prim_indices(handle: number): number;
	_tb_sah_cost(handle: number): number;
	_tb_bounds(handle: number, out: number): void;
}

export default function createTinyBVHModule(options?: Record<string, unknown>): Promise<TinyBVHModule>;
