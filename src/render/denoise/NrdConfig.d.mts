import type { NRDModule } from '../../generated/nrd/nrd.mjs';

export type NrdMode = 'radiance' | 'sh';
export interface InstanceDesc {
	constantBufferMaxDataSize: number;
	resourcesSpace: number;
	samplers: number[];
	permanentPool: [number, number][];
	transientPool: [number, number][];
	pipelines: { shader: string; hasConstantData: boolean; ranges: [number, number][] }[];
}
export interface Resource { descriptor: number; type: number; index: number }
export interface Dispatch { pipeline: number; width: number; height: number; constants: Uint8Array; resources: Resource[]; name: string }

export const SHIFT: { sampler: number; constant: number; storage: number; texture: number };
export const DENOISERS: Record<NrdMode, number[]>;
export const DESCRIPTOR_TEXTURE: number;
export const IN_MV: number, IN_NORMAL_ROUGHNESS: number, IN_VIEWZ: number, IN_DIFF: number, IN_SPEC: number,
	IN_DIFF_SH0: number, IN_DIFF_SH1: number, IN_SPEC_SH0: number, IN_SPEC_SH1: number;
export const OUT_DIFF: number, OUT_SPEC: number, OUT_DIFF_SH0: number, OUT_DIFF_SH1: number, OUT_SPEC_SH0: number, OUT_SPEC_SH1: number,
	OUT_VALIDATION: number, TRANSIENT_POOL: number, PERMANENT_POOL: number;
export const ACCUMULATION_CONTINUE: number, ACCUMULATION_CLEAR_AND_RESTART: number;
export const DENOISING_RANGE: number;
export const HIT_DISTANCE: readonly [number, number, number];
export const REBLUR_FLOATS: readonly number[];
export const REBLUR_INTS: readonly number[];
export const FORMATS: Record<number, [GPUTextureFormat, GPUTextureFormat]>;
export function userFormat(type: number): GPUTextureFormat;
export function poolFormat(nrd: number, tier1: boolean): GPUTextureFormat;
export function createInstance(module: NRDModule, mode: NrdMode): { context: number; desc: InstanceDesc };
export const PLAN_SCRATCH_BYTES: number;
export function planDispatches(module: NRDModule, context: number, scratch: number, matrices: ArrayLike<number>, params: ArrayLike<number>, ints: ArrayLike<number>): Dispatch[];
export function resourceFormat(desc: InstanceDesc, resource: Resource, tier1: boolean): GPUTextureFormat;
export function nrdVariantKey(formats: readonly string[]): string;
