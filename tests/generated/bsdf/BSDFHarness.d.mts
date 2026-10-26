// Type declarations for the Emscripten module produced by scripts/build-bsdf-harness.mjs.
export interface BSDFHarnessModule {
	HEAPF32: Float32Array;
	_malloc(bytes: number): number;
	_free(ptr: number): void;
	_RunReference(cases: number, results: number, count: number): void;
	_RunPort(cases: number, results: number, count: number, tables: number): void;
}

export default function createBSDFHarness(options?: Record<string, unknown>): Promise<BSDFHarnessModule>;
