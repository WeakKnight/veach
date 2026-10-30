export interface NRDModule {
	_nrd_version(...args: number[]): number;
	_nrd_create(...args: number[]): number;
	_nrd_destroy(...args: number[]): number;
	_nrd_instance_desc(...args: number[]): number;
	_nrd_set_common(...args: number[]): number;
	_nrd_set_reblur(...args: number[]): number;
	_nrd_dispatches(...args: number[]): number;
	_nrd_malloc(...args: number[]): number;
	_nrd_free(...args: number[]): number;
	HEAPU8: Uint8Array;
	HEAPF32: Float32Array;
	HEAPU32: Uint32Array;
	UTF8ToString(pointer: number): string;
}
export default function createNRDModule(options?: object): Promise<NRDModule>;
