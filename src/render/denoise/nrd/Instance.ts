// NRD instance creation in TypeScript: pipelines, texture pools, resource bindings and ping-pongs of the
// REBLUR denoisers Veach uses. A line-by-line port of InstanceImpl::Create, AddInternalDispatch, PushTexture,
// AddTextureToTransientPool and PrepareDesc (ThirdParty/NRD/Source/InstanceImpl.cpp) and of
// Add_ReblurDiffuseSpecular / Add_ReblurDiffuseSh / Add_ReblurSpecularSh (Source/Denoisers), keeping their
// call order: pipeline, dispatch and pool indices must equal the wasm runtime's (tests/nrd).
import type { InstanceDesc } from '../NrdConfig.mjs';

// nrd::Denoiser
export const REBLUR_DIFFUSE_SH = 2, REBLUR_SPECULAR_SH = 5, REBLUR_DIFFUSE_SPECULAR = 6;
// nrd::DescriptorType
export const TEXTURE = 0, STORAGE_TEXTURE = 1;
// nrd::ResourceType
export const IN_MV = 0, IN_NORMAL_ROUGHNESS = 1, IN_VIEWZ = 2, IN_DIFF_CONFIDENCE = 3, IN_SPEC_CONFIDENCE = 4, IN_DISOCCLUSION_THRESHOLD_MIX = 5,
	IN_DIFF_RADIANCE_HITDIST = 6, IN_SPEC_RADIANCE_HITDIST = 7, IN_DIFF_SH0 = 11, IN_DIFF_SH1 = 12, IN_SPEC_SH0 = 13, IN_SPEC_SH1 = 14, IN_SIGNAL = 17,
	OUT_DIFF_RADIANCE_HITDIST = 18, OUT_SPEC_RADIANCE_HITDIST = 19, OUT_DIFF_SH0 = 20, OUT_DIFF_SH1 = 21, OUT_SPEC_SH0 = 22, OUT_SPEC_SH1 = 23,
	OUT_VALIDATION = 29, TRANSIENT_POOL = 30, PERMANENT_POOL = 31;
// nrd::Format
const R8_UNORM = 0, R8_UINT = 2, RG8_UNORM = 4, R16_UINT = 15, R16_SFLOAT = 17, RGBA16_SFLOAT = 27, R32_UINT = 28, R32_SFLOAT = 30;
// g_IsIntegerFormat (nrd::Format -> integer storage)
const INTEGER_FORMATS = new Set([2, 6, 10, 15, 20, 25, 28, 31, 34, 37, 41]);

// REBLUR_Config / NRDConfig.hlsli as built (NRD_NORMAL_ENCODING = 4, NRD_ROUGHNESS_ENCODING = 1).
const REBLUR_FORMAT = RGBA16_SFLOAT, REBLUR_FORMAT_FAST_HISTORY = R16_SFLOAT, REBLUR_FORMAT_PREV_VIEWZ = R32_SFLOAT,
	REBLUR_FORMAT_PREV_INTERNAL_DATA = R16_UINT, REBLUR_FORMAT_TILES = R8_UNORM, REBLUR_FORMAT_PREV_NORMAL_ROUGHNESS = RGBA16_SFLOAT,
	REBLUR_FORMAT_HITDIST_FOR_TRACKING = R16_SFLOAT;
const NORMAL_ENCODING = 4, ROUGHNESS_ENCODING = 1;
const REBLUR_DUMMY = IN_VIEWZ;
const REBLUR_HITDIST_RECONSTRUCTION_PERMUTATION_NUM = 4, REBLUR_PREPASS_PERMUTATION_NUM = 2,
	REBLUR_TEMPORAL_ACCUMULATION_PERMUTATION_NUM = 8, REBLUR_POST_BLUR_PERMUTATION_NUM = 2;
const PERMANENT_POOL_START = 1000, TRANSIENT_POOL_START = 2000;
const NO_SWAP = 0xffff;

// Shader blob -> [numthreads x, y, constant struct bytes] (<blob>.resources.hlsli; struct sizes as in C++,
// 16-byte aligned: REBLUR_SHARED_CONSTANTS is 892 bytes, Validation adds two uints, Clear has 28).
export const REBLUR_CONSTANTS_BYTES = 896, VALIDATION_CONSTANTS_BYTES = 912, CLEAR_CONSTANTS_BYTES = 32;
export const BLOBS: Record<string, [number, number, number]> = {
	Clear: [16, 16, CLEAR_CONSTANTS_BYTES],
	REBLUR_ClassifyTiles: [16, 16, REBLUR_CONSTANTS_BYTES],
	REBLUR_HitDistReconstruction: [8, 16, REBLUR_CONSTANTS_BYTES],
	REBLUR_PrePass: [16, 16, REBLUR_CONSTANTS_BYTES],
	REBLUR_TemporalAccumulation: [8, 16, REBLUR_CONSTANTS_BYTES],
	REBLUR_HistoryFix: [8, 16, REBLUR_CONSTANTS_BYTES],
	REBLUR_Blur: [8, 16, REBLUR_CONSTANTS_BYTES],
	REBLUR_PostBlur: [8, 16, REBLUR_CONSTANTS_BYTES],
	REBLUR_TemporalStabilization: [8, 16, REBLUR_CONSTANTS_BYTES],
	REBLUR_SplitScreen: [8, 16, REBLUR_CONSTANTS_BYTES],
	REBLUR_Validation: [8, 16, VALIDATION_CONSTANTS_BYTES],
};

/** A bound texture; `index` of pool resources is swapped in place by ping-pongs (UpdatePingPong). */
export interface ResourceDesc { descriptor: number; type: number; index: number }
export interface InternalDispatch {
	name: string; pipeline: number; downsampleFactor: number; constantBytes: number;
	resourceOffset: number; resourceCount: number; numThreads: [number, number];
}
export interface PingPong { resource: number; swapWith: number }
export interface DenoiserData { denoiser: number; identifier: number; dispatchOffset: number; pingPongOffset: number; pingPongCount: number }
export interface ClearResource { identifier: number; resource: ResourceDesc; downsampleFactor: number; isInteger: boolean }

type Define = [string, string];
const shaderIdentifier = (blob: string, defines: readonly Define[]) => `${blob}.cs.hlsl${defines.map(([n, v]) => `|${n}=${v}`).join('')}`;

export class NrdInstance {
	readonly permanentPool: [number, number][] = [];
	readonly transientPool: [number, number][] = [];
	readonly resources: ResourceDesc[] = [];
	readonly clearResources: ClearResource[] = [];
	readonly pingPongs: PingPong[] = [];
	readonly pipelines: InstanceDesc['pipelines'] = [];
	readonly dispatches: InternalDispatch[] = [];
	readonly denoisers: DenoiserData[] = [];
	readonly clearDispatch: [number, number] = [0, 0];
	readonly desc: InstanceDesc;
	private indexRemap: number[] = [];
	private permanentPoolOffset = 0;
	private transientPoolOffset = 0;
	private passName = '';
	private resourceOffset = 0;

	/** `denoisers` are nrd::Denoiser values; identifiers are their indices (wasm/nrd_wasm.cpp). */
	constructor(denoisers: readonly number[]) {
		denoisers.forEach((denoiser, identifier) => {
			this.permanentPoolOffset = this.permanentPool.length;
			this.transientPoolOffset = this.transientPool.length;
			this.indexRemap = [];
			const data: DenoiserData = { denoiser, identifier, dispatchOffset: this.dispatches.length, pingPongOffset: this.pingPongs.length, pingPongCount: 0 };
			const resourceOffset = this.resources.length;
			if (denoiser === REBLUR_DIFFUSE_SPECULAR) this.addReblurDiffuseSpecular();
			else if (denoiser === REBLUR_DIFFUSE_SH) this.addReblurDiffuseSh();
			else if (denoiser === REBLUR_SPECULAR_SH) this.addReblurSpecularSh();
			else throw new Error(`NRD denoiser ${denoiser} is not ported to TypeScript`);
			data.pingPongCount = this.pingPongs.length - data.pingPongOffset;

			// Storage resources to clear on history reset (PING, then its PONG), unique, without OUT_VALIDATION.
			for (let r = resourceOffset; r < this.resources.length; r++) {
				const resource = this.resources[r];
				if (resource.descriptor !== STORAGE_TEXTURE || resource.type === OUT_VALIDATION) continue;
				if (this.clearResources.some(c => c.resource.descriptor === resource.descriptor && c.resource.type === resource.type && c.resource.index === resource.index)) continue;
				let isInteger = false, downsampleFactor = 1;
				if (resource.type === PERMANENT_POOL || resource.type === TRANSIENT_POOL) {
					const [format, downsample] = (resource.type === PERMANENT_POOL ? this.permanentPool : this.transientPool)[resource.index];
					isInteger = INTEGER_FORMATS.has(format);
					downsampleFactor = downsample;
				}
				this.clearResources.push({ identifier, resource: { ...resource }, downsampleFactor, isInteger });
				for (let p = 0; p < data.pingPongCount; p++) {
					const pingPong = this.pingPongs[data.pingPongOffset + p];
					if (pingPong.resource === r) {
						this.clearResources.push({ identifier, resource: { descriptor: resource.descriptor, type: resource.type, index: pingPong.swapWith }, downsampleFactor, isInteger });
						break;
					}
				}
			}
			this.denoisers.push(data);
		});

		this.clearDispatch[0] = this.dispatches.length;
		this.pushPass('Clear (f)');
		this.pushOutput(0);
		this.addDispatch('Clear', [['FLOAT', '1']]);
		this.clearDispatch[1] = this.dispatches.length;
		this.pushPass('Clear (ui)');
		this.pushOutput(0);
		this.addDispatch('Clear', [['FLOAT', '0']]);

		this.desc = {
			normalEncoding: NORMAL_ENCODING, roughnessEncoding: ROUGHNESS_ENCODING,
			// Only unique pass names count; every REBLUR pass name is shared by its permutations.
			constantBufferMaxDataSize: Math.max(0, ...this.dispatches.map(d => d.constantBytes)),
			constantBufferSpace: 1, resourcesSpace: 0, constantBufferRegister: 0,
			samplers: [0, 1], // NEAREST_CLAMP, LINEAR_CLAMP
			permanentPool: this.permanentPool.map(p => [...p] as [number, number]),
			transientPool: this.transientPool.map(p => [...p] as [number, number]),
			pipelines: this.pipelines,
		} as InstanceDesc;
	}

	private pushPass(name: string): void {
		this.passName = name;
		this.resourceOffset = this.resources.length;
	}

	private pushTexture(descriptor: number, localIndex: number, indexToSwapWith = NO_SWAP): void {
		let type = localIndex, index = 0;
		if (localIndex >= TRANSIENT_POOL_START) {
			type = TRANSIENT_POOL;
			index = this.indexRemap[localIndex - TRANSIENT_POOL_START];
			if (indexToSwapWith !== NO_SWAP) this.pingPongs.push({ resource: this.resources.length, swapWith: this.indexRemap[indexToSwapWith - TRANSIENT_POOL_START] });
		} else if (localIndex >= PERMANENT_POOL_START) {
			type = PERMANENT_POOL;
			index = this.permanentPoolOffset + localIndex - PERMANENT_POOL_START;
			if (indexToSwapWith !== NO_SWAP) this.pingPongs.push({ resource: this.resources.length, swapWith: this.permanentPoolOffset + indexToSwapWith - PERMANENT_POOL_START });
		}
		this.resources.push({ descriptor, type, index });
	}

	private pushInput(localIndex: number, indexToSwapWith?: number): void { this.pushTexture(TEXTURE, localIndex, indexToSwapWith); }
	private pushOutput(localIndex: number, indexToSwapWith?: number): void { this.pushTexture(STORAGE_TEXTURE, localIndex, indexToSwapWith); }
	private addPermanent(format: number, downsampleFactor: number): void { this.permanentPool.push([format, downsampleFactor]); }

	// Reuses a transient texture of an earlier denoiser with the same format and size, unless already in use.
	private addTransient(format: number, downsampleFactor: number): void {
		for (let i = 0; i < this.transientPoolOffset; i++) {
			const [f, d] = this.transientPool[i];
			if (f === format && d === downsampleFactor && !this.indexRemap.includes(i)) {
				this.indexRemap.push(i);
				return;
			}
		}
		this.indexRemap.push(this.transientPool.length);
		this.transientPool.push([format, downsampleFactor]);
	}

	// Without embedded shader blobs, AddInternalDispatch's de-duplication never matches: one pipeline per call.
	private addDispatch(blob: string, defines: readonly Define[]): void {
		const [x, y, constantBytes] = BLOBS[blob];
		const ranges: [number, number][] = [];
		for (const descriptor of [TEXTURE, STORAGE_TEXTURE]) {
			let count = 0;
			for (let i = this.resourceOffset; i < this.resources.length; i++) if (this.resources[i].descriptor === descriptor) count++;
			if (count) ranges.push([descriptor, count]);
		}
		this.pipelines.push({ shader: shaderIdentifier(blob, defines), hasConstantData: constantBytes !== 0, ranges });
		this.dispatches.push({ name: this.passName, pipeline: this.pipelines.length - 1, downsampleFactor: 1, constantBytes,
			resourceOffset: this.resourceOffset, resourceCount: this.resources.length - this.resourceOffset, numThreads: [x, y] });
	}

	private addValidation(name: string, data2: number, diff: number, spec: number, data1: number): void {
		this.pushPass(`${name} - Validation`);
		this.pushInput(IN_NORMAL_ROUGHNESS);
		this.pushInput(IN_VIEWZ);
		this.pushInput(IN_MV);
		this.pushInput(data1);
		this.pushInput(data2);
		this.pushInput(diff);
		this.pushInput(spec);
		this.pushOutput(OUT_VALIDATION);
		this.addDispatch('REBLUR_Validation', []);
	}

	private addReblurDiffuseSpecular(): void {
		const NAME = 'REBLUR_DiffuseSpecular';
		const pass = (n: string) => this.pushPass(`${NAME} - ${n}`);
		const P = PERMANENT_POOL_START, PREV_VIEWZ = P, PREV_NORMAL_ROUGHNESS = P + 1, PREV_INTERNAL_DATA = P + 2, DIFF_HISTORY = P + 3,
			DIFF_FAST_HISTORY_P = P + 4, DIFF_HISTORY_STABILIZED_PING = P + 5, DIFF_HISTORY_STABILIZED_PONG = P + 6, SPEC_HISTORY = P + 7,
			SPEC_FAST_HISTORY_P = P + 8, SPEC_HISTORY_STABILIZED_PING = P + 9, SPEC_HISTORY_STABILIZED_PONG = P + 10,
			SPEC_HITDIST_FOR_TRACKING_PING = P + 11, SPEC_HITDIST_FOR_TRACKING_PONG = P + 12;
		this.addPermanent(REBLUR_FORMAT_PREV_VIEWZ, 1);
		this.addPermanent(REBLUR_FORMAT_PREV_NORMAL_ROUGHNESS, 1);
		this.addPermanent(REBLUR_FORMAT_PREV_INTERNAL_DATA, 1);
		this.addPermanent(REBLUR_FORMAT, 1);
		this.addPermanent(REBLUR_FORMAT_FAST_HISTORY, 1);
		this.addPermanent(R16_SFLOAT, 1);
		this.addPermanent(R16_SFLOAT, 1);
		this.addPermanent(REBLUR_FORMAT, 1);
		this.addPermanent(REBLUR_FORMAT_FAST_HISTORY, 1);
		this.addPermanent(R16_SFLOAT, 1);
		this.addPermanent(R16_SFLOAT, 1);
		this.addPermanent(REBLUR_FORMAT_HITDIST_FOR_TRACKING, 1);
		this.addPermanent(REBLUR_FORMAT_HITDIST_FOR_TRACKING, 1);

		const T = TRANSIENT_POOL_START, DATA1 = T, DATA2 = T + 1, SPEC_HITDIST_FOR_TRACKING = T + 2, DIFF_TMP2 = T + 3,
			DIFF_FAST_HISTORY_T = T + 4, SPEC_TMP2 = T + 5, SPEC_FAST_HISTORY_T = T + 6, TILES = T + 7;
		this.addTransient(RG8_UNORM, 1);
		this.addTransient(R32_UINT, 1);
		this.addTransient(REBLUR_FORMAT_HITDIST_FOR_TRACKING, 1);
		this.addTransient(REBLUR_FORMAT, 1);
		this.addTransient(REBLUR_FORMAT_FAST_HISTORY, 1);
		this.addTransient(REBLUR_FORMAT, 1);
		this.addTransient(REBLUR_FORMAT_FAST_HISTORY, 1);
		this.addTransient(REBLUR_FORMAT_TILES, 16);

		const DIFF_TEMP1 = OUT_DIFF_RADIANCE_HITDIST, DIFF_TEMP2 = DIFF_TMP2, SPEC_TEMP1 = OUT_SPEC_RADIANCE_HITDIST, SPEC_TEMP2 = SPEC_TMP2;
		const common: Define[] = [['NRD_SIGNAL', 'NRD_SIGNAL_BOTH'], ['NRD_MODE', 'NRD_MODE_RADIANCE']];

		pass('Classify tiles');
		this.pushInput(IN_VIEWZ);
		this.pushOutput(TILES);
		this.addDispatch('REBLUR_ClassifyTiles', []);

		for (let i = 0; i < REBLUR_HITDIST_RECONSTRUCTION_PERMUTATION_NUM; i++) {
			const is5x5 = ((i >> 1) & 1) !== 0, isPrepassEnabled = (i & 1) !== 0;
			pass('Hit distance reconstruction');
			this.pushInput(TILES);
			this.pushInput(IN_NORMAL_ROUGHNESS);
			this.pushInput(IN_VIEWZ);
			this.pushInput(IN_DIFF_RADIANCE_HITDIST);
			this.pushInput(IN_SPEC_RADIANCE_HITDIST);
			this.pushOutput(isPrepassEnabled ? DIFF_TEMP2 : DIFF_TEMP1);
			this.pushOutput(isPrepassEnabled ? SPEC_TEMP2 : SPEC_TEMP1);
			this.addDispatch('REBLUR_HitDistReconstruction', [common[0], common[1], ['MODE_5X5', is5x5 ? '1' : '0']]);
		}

		for (let i = 0; i < REBLUR_PREPASS_PERMUTATION_NUM; i++) {
			const isAfterReconstruction = (i & 1) !== 0;
			pass('Pre-pass');
			this.pushInput(TILES);
			this.pushInput(IN_NORMAL_ROUGHNESS);
			this.pushInput(IN_VIEWZ);
			this.pushInput(isAfterReconstruction ? DIFF_TEMP2 : IN_DIFF_RADIANCE_HITDIST);
			this.pushInput(isAfterReconstruction ? SPEC_TEMP2 : IN_SPEC_RADIANCE_HITDIST);
			this.pushOutput(DIFF_TEMP1);
			this.pushOutput(SPEC_TEMP1);
			this.pushOutput(SPEC_HITDIST_FOR_TRACKING);
			this.addDispatch('REBLUR_PrePass', common);
		}

		for (let i = 0; i < REBLUR_TEMPORAL_ACCUMULATION_PERMUTATION_NUM; i++) {
			const hasDisocclusionThresholdMix = ((i >> 2) & 1) !== 0, hasConfidenceInputs = ((i >> 1) & 1) !== 0, isAfterPrepass = (i & 1) !== 0;
			pass('Temporal accumulation');
			this.pushInput(TILES);
			this.pushInput(IN_NORMAL_ROUGHNESS);
			this.pushInput(IN_VIEWZ);
			this.pushInput(IN_MV);
			this.pushInput(PREV_VIEWZ);
			this.pushInput(PREV_NORMAL_ROUGHNESS);
			this.pushInput(PREV_INTERNAL_DATA);
			this.pushInput(hasDisocclusionThresholdMix ? IN_DISOCCLUSION_THRESHOLD_MIX : REBLUR_DUMMY);
			this.pushInput(hasConfidenceInputs ? IN_DIFF_CONFIDENCE : REBLUR_DUMMY);
			this.pushInput(hasConfidenceInputs ? IN_SPEC_CONFIDENCE : REBLUR_DUMMY);
			this.pushInput(isAfterPrepass ? DIFF_TEMP1 : IN_DIFF_RADIANCE_HITDIST);
			this.pushInput(isAfterPrepass ? SPEC_TEMP1 : IN_SPEC_RADIANCE_HITDIST);
			this.pushInput(DIFF_HISTORY);
			this.pushInput(SPEC_HISTORY);
			this.pushInput(DIFF_FAST_HISTORY_P);
			this.pushInput(SPEC_FAST_HISTORY_P);
			this.pushInput(SPEC_HITDIST_FOR_TRACKING_PING, SPEC_HITDIST_FOR_TRACKING_PONG);
			this.pushInput(SPEC_HITDIST_FOR_TRACKING);
			this.pushOutput(DATA1);
			this.pushOutput(DIFF_TEMP2);
			this.pushOutput(SPEC_TEMP2);
			this.pushOutput(DIFF_FAST_HISTORY_T);
			this.pushOutput(SPEC_FAST_HISTORY_T);
			this.pushOutput(SPEC_HITDIST_FOR_TRACKING_PONG, SPEC_HITDIST_FOR_TRACKING_PING);
			this.pushOutput(DATA2);
			this.addDispatch('REBLUR_TemporalAccumulation', common);
		}

		pass('History fix');
		this.pushInput(TILES);
		this.pushInput(IN_NORMAL_ROUGHNESS);
		this.pushInput(DATA1);
		this.pushInput(IN_VIEWZ);
		this.pushInput(DIFF_TEMP2);
		this.pushInput(SPEC_TEMP2);
		this.pushInput(DIFF_FAST_HISTORY_T);
		this.pushInput(SPEC_FAST_HISTORY_T);
		this.pushInput(SPEC_HITDIST_FOR_TRACKING_PONG, SPEC_HITDIST_FOR_TRACKING_PING);
		this.pushOutput(DIFF_TEMP1);
		this.pushOutput(SPEC_TEMP1);
		this.pushOutput(DIFF_FAST_HISTORY_P);
		this.pushOutput(SPEC_FAST_HISTORY_P);
		this.addDispatch('REBLUR_HistoryFix', common);

		pass('Blur');
		this.pushInput(TILES);
		this.pushInput(IN_NORMAL_ROUGHNESS);
		this.pushInput(IN_VIEWZ);
		this.pushInput(DATA1);
		this.pushInput(DIFF_TEMP1);
		this.pushInput(SPEC_TEMP1);
		this.pushOutput(PREV_VIEWZ);
		this.pushOutput(DIFF_TEMP2);
		this.pushOutput(SPEC_TEMP2);
		this.addDispatch('REBLUR_Blur', common);

		for (let i = 0; i < REBLUR_POST_BLUR_PERMUTATION_NUM; i++) {
			const isTemporalStabilization = (i & 1) !== 0;
			pass('Post-blur');
			this.pushInput(TILES);
			this.pushInput(IN_NORMAL_ROUGHNESS);
			this.pushInput(DATA1);
			this.pushInput(PREV_VIEWZ);
			this.pushInput(DIFF_TEMP2);
			this.pushInput(SPEC_TEMP2);
			this.pushOutput(PREV_NORMAL_ROUGHNESS);
			this.pushOutput(DIFF_HISTORY);
			this.pushOutput(SPEC_HISTORY);
			if (!isTemporalStabilization) {
				this.pushOutput(PREV_INTERNAL_DATA);
				this.pushOutput(OUT_DIFF_RADIANCE_HITDIST);
				this.pushOutput(OUT_SPEC_RADIANCE_HITDIST);
			}
			this.addDispatch('REBLUR_PostBlur', [common[0], common[1], ['TEMPORAL_STABILIZATION', isTemporalStabilization ? '1' : '0']]);
		}

		pass('Temporal stabilization');
		this.pushInput(TILES);
		this.pushInput(IN_NORMAL_ROUGHNESS);
		this.pushInput(PREV_VIEWZ);
		this.pushInput(DATA1);
		this.pushInput(DATA2);
		this.pushInput(SPEC_HITDIST_FOR_TRACKING_PONG, SPEC_HITDIST_FOR_TRACKING_PING);
		this.pushInput(DIFF_HISTORY);
		this.pushInput(SPEC_HISTORY);
		this.pushInput(DIFF_HISTORY_STABILIZED_PING, DIFF_HISTORY_STABILIZED_PONG);
		this.pushInput(SPEC_HISTORY_STABILIZED_PING, SPEC_HISTORY_STABILIZED_PONG);
		this.pushOutput(IN_MV);
		this.pushOutput(PREV_INTERNAL_DATA);
		this.pushOutput(OUT_DIFF_RADIANCE_HITDIST);
		this.pushOutput(OUT_SPEC_RADIANCE_HITDIST);
		this.pushOutput(DIFF_HISTORY_STABILIZED_PONG, DIFF_HISTORY_STABILIZED_PING);
		this.pushOutput(SPEC_HISTORY_STABILIZED_PONG, SPEC_HISTORY_STABILIZED_PING);
		this.addDispatch('REBLUR_TemporalStabilization', common);

		pass('Split screen');
		this.pushInput(IN_VIEWZ);
		this.pushInput(IN_DIFF_RADIANCE_HITDIST);
		this.pushInput(IN_SPEC_RADIANCE_HITDIST);
		this.pushOutput(OUT_DIFF_RADIANCE_HITDIST);
		this.pushOutput(OUT_SPEC_RADIANCE_HITDIST);
		this.addDispatch('REBLUR_SplitScreen', common);

		this.addValidation(NAME, DATA2, IN_DIFF_RADIANCE_HITDIST, IN_SPEC_RADIANCE_HITDIST, DATA1);
	}

	private addReblurDiffuseSh(): void {
		// Reblur_DiffuseSh.hpp does not define DENOISER_NAME, so PushPass stringifies the macro name.
		const NAME = 'DENOISER_NAME';
		const pass = (n: string) => this.pushPass(`${NAME} - ${n}`);
		const P = PERMANENT_POOL_START, PREV_VIEWZ = P, PREV_NORMAL_ROUGHNESS = P + 1, PREV_INTERNAL_DATA = P + 2, DIFF_HISTORY = P + 3,
			DIFF_FAST_HISTORY_P = P + 4, DIFF_HISTORY_STABILIZED_PING = P + 5, DIFF_HISTORY_STABILIZED_PONG = P + 6, DIFF_SH_HISTORY = P + 7;
		this.addPermanent(REBLUR_FORMAT_PREV_VIEWZ, 1);
		this.addPermanent(REBLUR_FORMAT_PREV_NORMAL_ROUGHNESS, 1);
		this.addPermanent(REBLUR_FORMAT_PREV_INTERNAL_DATA, 1);
		this.addPermanent(REBLUR_FORMAT, 1);
		this.addPermanent(REBLUR_FORMAT_FAST_HISTORY, 1);
		this.addPermanent(R16_SFLOAT, 1);
		this.addPermanent(R16_SFLOAT, 1);
		this.addPermanent(REBLUR_FORMAT, 1);

		const T = TRANSIENT_POOL_START, DATA1 = T, DATA2 = T + 1, DIFF_TMP2 = T + 2, DIFF_FAST_HISTORY_T = T + 3, DIFF_SH_TMP2 = T + 4, TILES = T + 5;
		this.addTransient(R8_UNORM, 1);
		this.addTransient(R8_UINT, 1);
		this.addTransient(REBLUR_FORMAT, 1);
		this.addTransient(REBLUR_FORMAT_FAST_HISTORY, 1);
		this.addTransient(REBLUR_FORMAT, 1);
		this.addTransient(REBLUR_FORMAT_TILES, 16);

		const DIFF_TEMP1 = OUT_DIFF_SH0, DIFF_TEMP2 = DIFF_TMP2, DIFF_SH_TEMP1 = OUT_DIFF_SH1, DIFF_SH_TEMP2 = DIFF_SH_TMP2;
		const common: Define[] = [['NRD_SIGNAL', 'NRD_SIGNAL_DIFF'], ['NRD_MODE', 'NRD_MODE_SH']];

		pass('Classify tiles');
		this.pushInput(IN_VIEWZ);
		this.pushOutput(TILES);
		this.addDispatch('REBLUR_ClassifyTiles', []);

		for (let i = 0; i < REBLUR_HITDIST_RECONSTRUCTION_PERMUTATION_NUM; i++) {
			const is5x5 = ((i >> 1) & 1) !== 0, isPrepassEnabled = (i & 1) !== 0;
			pass('Hit distance reconstruction');
			this.pushInput(TILES);
			this.pushInput(IN_NORMAL_ROUGHNESS);
			this.pushInput(IN_VIEWZ);
			this.pushInput(IN_DIFF_SH0);
			this.pushOutput(isPrepassEnabled ? DIFF_TEMP2 : DIFF_TEMP1);
			this.addDispatch('REBLUR_HitDistReconstruction', [common[0], ['NRD_MODE', 'NRD_MODE_RADIANCE'], ['MODE_5X5', is5x5 ? '1' : '0']]);
		}

		for (let i = 0; i < REBLUR_PREPASS_PERMUTATION_NUM; i++) {
			const isAfterReconstruction = (i & 1) !== 0;
			pass('Pre-pass');
			this.pushInput(TILES);
			this.pushInput(IN_NORMAL_ROUGHNESS);
			this.pushInput(IN_VIEWZ);
			this.pushInput(isAfterReconstruction ? DIFF_TEMP2 : IN_DIFF_SH0);
			this.pushInput(IN_DIFF_SH1);
			this.pushOutput(DIFF_TEMP1);
			this.pushOutput(DIFF_SH_TEMP1);
			this.addDispatch('REBLUR_PrePass', common);
		}

		for (let i = 0; i < REBLUR_TEMPORAL_ACCUMULATION_PERMUTATION_NUM; i++) {
			const hasDisocclusionThresholdMix = ((i >> 2) & 1) !== 0, hasConfidenceInputs = ((i >> 1) & 1) !== 0, isAfterPrepass = (i & 1) !== 0;
			pass('Temporal accumulation');
			this.pushInput(TILES);
			this.pushInput(IN_NORMAL_ROUGHNESS);
			this.pushInput(IN_VIEWZ);
			this.pushInput(IN_MV);
			this.pushInput(PREV_VIEWZ);
			this.pushInput(PREV_NORMAL_ROUGHNESS);
			this.pushInput(PREV_INTERNAL_DATA);
			this.pushInput(hasDisocclusionThresholdMix ? IN_DISOCCLUSION_THRESHOLD_MIX : REBLUR_DUMMY);
			this.pushInput(hasConfidenceInputs ? IN_DIFF_CONFIDENCE : REBLUR_DUMMY);
			this.pushInput(isAfterPrepass ? DIFF_TEMP1 : IN_DIFF_SH0);
			this.pushInput(DIFF_HISTORY);
			this.pushInput(DIFF_FAST_HISTORY_P);
			this.pushInput(isAfterPrepass ? DIFF_SH_TEMP1 : IN_DIFF_SH1);
			this.pushInput(DIFF_SH_HISTORY);
			this.pushOutput(DATA1);
			this.pushOutput(DIFF_TEMP2);
			this.pushOutput(DIFF_FAST_HISTORY_T);
			this.pushOutput(DATA2);
			this.pushOutput(DIFF_SH_TEMP2);
			this.addDispatch('REBLUR_TemporalAccumulation', common);
		}

		pass('History fix');
		this.pushInput(TILES);
		this.pushInput(IN_NORMAL_ROUGHNESS);
		this.pushInput(DATA1);
		this.pushInput(IN_VIEWZ);
		this.pushInput(DIFF_TEMP2);
		this.pushInput(DIFF_FAST_HISTORY_T);
		this.pushInput(DIFF_SH_TEMP2);
		this.pushOutput(DIFF_TEMP1);
		this.pushOutput(DIFF_FAST_HISTORY_P);
		this.pushOutput(DIFF_SH_TEMP1);
		this.addDispatch('REBLUR_HistoryFix', common);

		pass('Blur');
		this.pushInput(TILES);
		this.pushInput(IN_NORMAL_ROUGHNESS);
		this.pushInput(IN_VIEWZ);
		this.pushInput(DATA1);
		this.pushInput(DIFF_TEMP1);
		this.pushInput(DIFF_SH_TEMP1);
		this.pushOutput(PREV_VIEWZ);
		this.pushOutput(DIFF_TEMP2);
		this.pushOutput(DIFF_SH_TEMP2);
		this.addDispatch('REBLUR_Blur', common);

		for (let i = 0; i < REBLUR_POST_BLUR_PERMUTATION_NUM; i++) {
			const isTemporalStabilization = (i & 1) !== 0;
			pass('Post-blur');
			this.pushInput(TILES);
			this.pushInput(IN_NORMAL_ROUGHNESS);
			this.pushInput(DATA1);
			this.pushInput(PREV_VIEWZ);
			this.pushInput(DIFF_TEMP2);
			this.pushInput(DIFF_SH_TEMP2);
			this.pushOutput(PREV_NORMAL_ROUGHNESS);
			this.pushOutput(DIFF_HISTORY);
			if (!isTemporalStabilization) {
				this.pushOutput(PREV_INTERNAL_DATA);
				this.pushOutput(OUT_DIFF_SH0);
				this.pushOutput(OUT_DIFF_SH1);
			}
			this.pushOutput(DIFF_SH_HISTORY);
			this.addDispatch('REBLUR_PostBlur', [common[0], common[1], ['TEMPORAL_STABILIZATION', isTemporalStabilization ? '1' : '0']]);
		}

		pass('Temporal stabilization');
		this.pushInput(TILES);
		this.pushInput(IN_NORMAL_ROUGHNESS);
		this.pushInput(PREV_VIEWZ);
		this.pushInput(DATA1);
		this.pushInput(DATA2);
		this.pushInput(DIFF_HISTORY);
		this.pushInput(DIFF_HISTORY_STABILIZED_PING, DIFF_HISTORY_STABILIZED_PONG);
		this.pushInput(DIFF_SH_HISTORY);
		this.pushOutput(IN_MV);
		this.pushOutput(PREV_INTERNAL_DATA);
		this.pushOutput(OUT_DIFF_SH0);
		this.pushOutput(DIFF_HISTORY_STABILIZED_PONG, DIFF_HISTORY_STABILIZED_PING);
		this.pushOutput(OUT_DIFF_SH1);
		this.addDispatch('REBLUR_TemporalStabilization', common);

		pass('Split screen');
		this.pushInput(IN_VIEWZ);
		this.pushInput(IN_DIFF_SH0);
		this.pushInput(IN_DIFF_SH1);
		this.pushOutput(OUT_DIFF_SH0);
		this.pushOutput(OUT_DIFF_SH1);
		this.addDispatch('REBLUR_SplitScreen', common);

		this.addValidation(NAME, DATA2, IN_DIFF_SH0, IN_DIFF_SH0, DATA1);
	}

	private addReblurSpecularSh(): void {
		const NAME = 'REBLUR_SpecularSh';
		const pass = (n: string) => this.pushPass(`${NAME} - ${n}`);
		const P = PERMANENT_POOL_START, PREV_VIEWZ = P, PREV_NORMAL_ROUGHNESS = P + 1, PREV_INTERNAL_DATA = P + 2, SPEC_HISTORY = P + 3,
			SPEC_FAST_HISTORY_P = P + 4, SPEC_HISTORY_STABILIZED_PING = P + 5, SPEC_HISTORY_STABILIZED_PONG = P + 6, SPEC_SH_HISTORY = P + 7,
			SPEC_HITDIST_FOR_TRACKING_PING = P + 8, SPEC_HITDIST_FOR_TRACKING_PONG = P + 9;
		this.addPermanent(REBLUR_FORMAT_PREV_VIEWZ, 1);
		this.addPermanent(REBLUR_FORMAT_PREV_NORMAL_ROUGHNESS, 1);
		this.addPermanent(REBLUR_FORMAT_PREV_INTERNAL_DATA, 1);
		this.addPermanent(REBLUR_FORMAT, 1);
		this.addPermanent(REBLUR_FORMAT_FAST_HISTORY, 1);
		this.addPermanent(R16_SFLOAT, 1);
		this.addPermanent(R16_SFLOAT, 1);
		this.addPermanent(REBLUR_FORMAT, 1);
		this.addPermanent(REBLUR_FORMAT_HITDIST_FOR_TRACKING, 1);
		this.addPermanent(REBLUR_FORMAT_HITDIST_FOR_TRACKING, 1);

		const T = TRANSIENT_POOL_START, DATA1 = T, DATA2 = T + 1, SPEC_HITDIST_FOR_TRACKING = T + 2, SPEC_TMP2 = T + 3,
			SPEC_FAST_HISTORY_T = T + 4, SPEC_SH_TMP2 = T + 5, TILES = T + 6;
		this.addTransient(R8_UNORM, 1);
		this.addTransient(R32_UINT, 1);
		this.addTransient(REBLUR_FORMAT_HITDIST_FOR_TRACKING, 1);
		this.addTransient(REBLUR_FORMAT, 1);
		this.addTransient(REBLUR_FORMAT_FAST_HISTORY, 1);
		this.addTransient(REBLUR_FORMAT, 1);
		this.addTransient(REBLUR_FORMAT_TILES, 16);

		const SPEC_TEMP1 = OUT_SPEC_SH0, SPEC_TEMP2 = SPEC_TMP2, SPEC_SH_TEMP1 = OUT_SPEC_SH1, SPEC_SH_TEMP2 = SPEC_SH_TMP2;
		const common: Define[] = [['NRD_SIGNAL', 'NRD_SIGNAL_SPEC'], ['NRD_MODE', 'NRD_MODE_SH']];

		pass('Classify tiles');
		this.pushInput(IN_VIEWZ);
		this.pushOutput(TILES);
		this.addDispatch('REBLUR_ClassifyTiles', []);

		for (let i = 0; i < REBLUR_HITDIST_RECONSTRUCTION_PERMUTATION_NUM; i++) {
			const is5x5 = ((i >> 1) & 1) !== 0, isPrepassEnabled = (i & 1) !== 0;
			pass('Hit distance reconstruction');
			this.pushInput(TILES);
			this.pushInput(IN_NORMAL_ROUGHNESS);
			this.pushInput(IN_VIEWZ);
			this.pushInput(IN_SPEC_SH0);
			this.pushOutput(isPrepassEnabled ? SPEC_TEMP2 : SPEC_TEMP1);
			this.addDispatch('REBLUR_HitDistReconstruction', [common[0], ['NRD_MODE', 'NRD_MODE_RADIANCE'], ['MODE_5X5', is5x5 ? '1' : '0']]);
		}

		for (let i = 0; i < REBLUR_PREPASS_PERMUTATION_NUM; i++) {
			const isAfterReconstruction = (i & 1) !== 0;
			pass('Pre-pass');
			this.pushInput(TILES);
			this.pushInput(IN_NORMAL_ROUGHNESS);
			this.pushInput(IN_VIEWZ);
			this.pushInput(isAfterReconstruction ? SPEC_TEMP2 : IN_SPEC_SH0);
			this.pushInput(IN_SPEC_SH1);
			this.pushOutput(SPEC_TEMP1);
			this.pushOutput(SPEC_HITDIST_FOR_TRACKING);
			this.pushOutput(SPEC_SH_TEMP1);
			this.addDispatch('REBLUR_PrePass', common);
		}

		for (let i = 0; i < REBLUR_TEMPORAL_ACCUMULATION_PERMUTATION_NUM; i++) {
			const hasDisocclusionThresholdMix = ((i >> 2) & 1) !== 0, hasConfidenceInputs = ((i >> 1) & 1) !== 0, isAfterPrepass = (i & 1) !== 0;
			pass('Temporal accumulation');
			this.pushInput(TILES);
			this.pushInput(IN_NORMAL_ROUGHNESS);
			this.pushInput(IN_VIEWZ);
			this.pushInput(IN_MV);
			this.pushInput(PREV_VIEWZ);
			this.pushInput(PREV_NORMAL_ROUGHNESS);
			this.pushInput(PREV_INTERNAL_DATA);
			this.pushInput(hasDisocclusionThresholdMix ? IN_DISOCCLUSION_THRESHOLD_MIX : REBLUR_DUMMY);
			this.pushInput(hasConfidenceInputs ? IN_SPEC_CONFIDENCE : REBLUR_DUMMY);
			this.pushInput(isAfterPrepass ? SPEC_TEMP1 : IN_SPEC_SH0);
			this.pushInput(SPEC_HISTORY);
			this.pushInput(SPEC_FAST_HISTORY_P);
			this.pushInput(SPEC_HITDIST_FOR_TRACKING_PING, SPEC_HITDIST_FOR_TRACKING_PONG);
			this.pushInput(SPEC_HITDIST_FOR_TRACKING);
			this.pushInput(isAfterPrepass ? SPEC_SH_TEMP1 : IN_SPEC_SH1);
			this.pushInput(SPEC_SH_HISTORY);
			this.pushOutput(DATA1);
			this.pushOutput(SPEC_TEMP2);
			this.pushOutput(SPEC_FAST_HISTORY_T);
			this.pushOutput(SPEC_HITDIST_FOR_TRACKING_PONG, SPEC_HITDIST_FOR_TRACKING_PING);
			this.pushOutput(DATA2);
			this.pushOutput(SPEC_SH_TEMP2);
			this.addDispatch('REBLUR_TemporalAccumulation', common);
		}

		pass('History fix');
		this.pushInput(TILES);
		this.pushInput(IN_NORMAL_ROUGHNESS);
		this.pushInput(DATA1);
		this.pushInput(IN_VIEWZ);
		this.pushInput(SPEC_TEMP2);
		this.pushInput(SPEC_FAST_HISTORY_T);
		this.pushInput(SPEC_HITDIST_FOR_TRACKING_PONG, SPEC_HITDIST_FOR_TRACKING_PING);
		this.pushInput(SPEC_SH_TEMP2);
		this.pushOutput(SPEC_TEMP1);
		this.pushOutput(SPEC_FAST_HISTORY_P);
		this.pushOutput(SPEC_SH_TEMP1);
		this.addDispatch('REBLUR_HistoryFix', common);

		pass('Blur');
		this.pushInput(TILES);
		this.pushInput(IN_NORMAL_ROUGHNESS);
		this.pushInput(IN_VIEWZ);
		this.pushInput(DATA1);
		this.pushInput(SPEC_TEMP1);
		this.pushInput(SPEC_SH_TEMP1);
		this.pushOutput(PREV_VIEWZ);
		this.pushOutput(SPEC_TEMP2);
		this.pushOutput(SPEC_SH_TEMP2);
		this.addDispatch('REBLUR_Blur', common);

		for (let i = 0; i < REBLUR_POST_BLUR_PERMUTATION_NUM; i++) {
			const isTemporalStabilization = (i & 1) !== 0;
			pass('Post-blur');
			this.pushInput(TILES);
			this.pushInput(IN_NORMAL_ROUGHNESS);
			this.pushInput(DATA1);
			this.pushInput(PREV_VIEWZ);
			this.pushInput(SPEC_TEMP2);
			this.pushInput(SPEC_SH_TEMP2);
			this.pushOutput(PREV_NORMAL_ROUGHNESS);
			this.pushOutput(SPEC_HISTORY);
			if (!isTemporalStabilization) {
				this.pushOutput(PREV_INTERNAL_DATA);
				this.pushOutput(OUT_SPEC_SH0);
				this.pushOutput(OUT_SPEC_SH1);
			}
			this.pushOutput(SPEC_SH_HISTORY);
			this.addDispatch('REBLUR_PostBlur', [common[0], common[1], ['TEMPORAL_STABILIZATION', isTemporalStabilization ? '1' : '0']]);
		}

		pass('Temporal stabilization');
		this.pushInput(TILES);
		this.pushInput(IN_NORMAL_ROUGHNESS);
		this.pushInput(PREV_VIEWZ);
		this.pushInput(DATA1);
		this.pushInput(DATA2);
		this.pushInput(SPEC_HITDIST_FOR_TRACKING_PONG, SPEC_HITDIST_FOR_TRACKING_PING);
		this.pushInput(SPEC_HISTORY);
		this.pushInput(SPEC_HISTORY_STABILIZED_PING, SPEC_HISTORY_STABILIZED_PONG);
		this.pushInput(SPEC_SH_HISTORY);
		this.pushOutput(IN_MV);
		this.pushOutput(PREV_INTERNAL_DATA);
		this.pushOutput(OUT_SPEC_SH0);
		this.pushOutput(SPEC_HISTORY_STABILIZED_PONG, SPEC_HISTORY_STABILIZED_PING);
		this.pushOutput(OUT_SPEC_SH1);
		this.addDispatch('REBLUR_TemporalStabilization', common);

		pass('Split screen');
		this.pushInput(IN_VIEWZ);
		this.pushInput(IN_SPEC_SH0);
		this.pushInput(IN_SPEC_SH1);
		this.pushOutput(OUT_SPEC_SH0);
		this.pushOutput(OUT_SPEC_SH1);
		this.addDispatch('REBLUR_SplitScreen', common);

		this.addValidation(NAME, DATA2, IN_SPEC_SH0, IN_SPEC_SH0, DATA1);
	}
}
