// NVIDIA NRD REBLUR on WebGPU (docs/Nrd.md). The TypeScript port of NRD's runtime (nrd/Planner.ts) plans
// dispatches; this class owns textures, pipelines and bind groups. Loaded lazily: the generated shaders and runtime are only
// fetched when NRD is enabled. Two modes: 'radiance' (REBLUR_DIFFUSE_SPECULAR) and 'sh'
// (REBLUR_DIFFUSE_SH + REBLUR_SPECULAR_SH, SG resolve and re-jittering in Composite).
import { nrdShaders } from '../../generated/nrd/NrdShaders';
import { nrdPasses } from '../../generated/nrd/NrdPasses';
import { vec3, type Vec3 } from '../../math/Math';
import {
	ACCUMULATION_CLEAR_AND_RESTART, ACCUMULATION_CONTINUE, DENOISING_RANGE, DESCRIPTOR_TEXTURE, HIT_DISTANCE, PERMANENT_POOL, SHIFT, TRANSIENT_POOL,
	IN_DIFF, IN_DIFF_SH0, IN_DIFF_SH1, IN_MV, IN_NORMAL_ROUGHNESS, IN_SPEC, IN_SPEC_SH0, IN_SPEC_SH1, IN_VIEWZ, OUT_DIFF, OUT_DIFF_SH0, OUT_DIFF_SH1, OUT_SPEC, OUT_SPEC_SH0, OUT_SPEC_SH1,
	DENOISERS, REBLUR_FLOATS, REBLUR_INTS, nrdVariantKey, poolFormat, userFormat, type Dispatch, type InstanceDesc, type NrdMode, type Resource,
} from './NrdConfig.mjs';
import { NrdPlanner } from './nrd/Planner';

export type { NrdMode };
export interface NrdCamera { position: Vec3; right: Vec3; up: Vec3; forward: Vec3 }
export interface NrdStats { active: boolean; reason: string | null; mode: NrdMode; dispatches: number; frames: number; bytes: number }
export interface NrdFrame {
	frame: GPUBuffer; // FrameUniforms of this frame (jitter in temporal.xy, pre-exposure)
	accumulation: GPUBuffer; // image prefix plus the NRD split region at region (float4 offset)
	region: number;
	motion: GPUBuffer; // TAA motion: two float4 per pixel
	width: number;
	height: number;
	camera: NrdCamera;
	jitter: [number, number]; // film jitter in [0, 1]
	reset: boolean;
	debug: number; // 0 denoised, 1 noisy split, 2 diffuse, 3 specular, 4 guides, 5 re-jitter scale (SH)
	reJitter: boolean; // SH mode only
}

// Prepare storage bindings and Composite texture bindings per mode (NrdPasses.slang).
const PREPARE: Record<NrdMode, [number, number][]> = {
	radiance: [[4, IN_MV], [5, IN_NORMAL_ROUGHNESS], [6, IN_VIEWZ], [7, IN_DIFF], [8, IN_SPEC]],
	sh: [[4, IN_MV], [5, IN_NORMAL_ROUGHNESS], [6, IN_VIEWZ], [7, IN_DIFF_SH0], [8, IN_SPEC_SH0], [12, IN_DIFF_SH1], [13, IN_SPEC_SH1]],
};
const COMPOSITE: Record<NrdMode, [number, number][]> = {
	radiance: [[9, OUT_DIFF], [10, OUT_SPEC]],
	sh: [[9, OUT_DIFF_SH0], [10, OUT_SPEC_SH0], [14, OUT_DIFF_SH1], [15, OUT_SPEC_SH1]],
};
const CONSTANT_STRIDE = 1024;
const BYTES: Partial<Record<GPUTextureFormat, number>> = { r8unorm: 1, r8snorm: 1, r8uint: 1, r8sint: 1, rg8unorm: 2, rg8snorm: 2, rg8uint: 2, rg8sint: 2,
	rgba8unorm: 4, rgba8snorm: 4, rgba8uint: 4, rgba8sint: 4, r16uint: 2, r16sint: 2, r16float: 2, rg16uint: 4, rg16sint: 4, rg16float: 4,
	rgba16uint: 8, rgba16sint: 8, rgba16float: 8, r32uint: 4, r32sint: 4, r32float: 4, rg32uint: 8, rg32sint: 8, rg32float: 8,
	rgba32uint: 16, rgba32sint: 16, rgba32float: 16, rgb10a2unorm: 4, rgb10a2uint: 4, rg11b10ufloat: 4 };

interface Declaration { binding: number; group: number; kind: 'texture' | 'storage' | 'sampler' | 'uniform'; sample: GPUTextureSampleType; format: string; access: GPUStorageTextureAccess }

/** Parses the WGSL resource declarations emitted by slangc. */
function declarations(code: string): Declaration[] {
	return [...code.matchAll(/@binding\((\d+)\) @group\((\d+)\) var(<\w+>)? \w+ : ([^;]+);/g)].map(([, binding, group, space, type]) => {
		const storage = type.match(/^texture_storage_2d<(\w+), (\w+)>/);
		const access: GPUStorageTextureAccess = storage?.[2] === 'read_write' ? 'read-write' : storage?.[2] === 'read' ? 'read-only' : 'write-only';
		const kind = space === '<uniform>' ? 'uniform' : storage ? 'storage' : type === 'sampler' ? 'sampler' : 'texture';
		const sample: GPUTextureSampleType = type.includes('<u32>') ? 'uint' : type.includes('<i32>') ? 'sint' : 'float';
		return { binding: +binding, group: +group, kind, sample, format: storage?.[1] ?? '', access };
	});
}

/** Column-major matrices. View space is left-handed (X right, Y up, Z forward), as viewZ in Prepare. */
export function nrdMatrices(camera: NrdCamera): { worldToView: Float32Array; viewToClip: Float32Array } {
	const x = vec3.normalize(camera.right), y = vec3.normalize(camera.up), z = vec3.normalize(vec3.cross(camera.up, camera.right));
	const worldToView = new Float32Array(16);
	[x, y, z].forEach((axis, row) => {
		for (let c = 0; c < 3; c++) worldToView[c * 4 + row] = axis[c];
		worldToView[12 + row] = -vec3.dot(axis, camera.position);
	});
	worldToView[15] = 1;
	// A pixel ray is forward + ndc.x * right + ndc.y * up (off-axis host projections included).
	const f = [vec3.dot(camera.forward, x), vec3.dot(camera.forward, y), vec3.dot(camera.forward, z)];
	const sx = vec3.length(camera.right), sy = vec3.length(camera.up), near = 0.01;
	const viewToClip = new Float32Array(16);
	viewToClip[0] = f[2] / sx; viewToClip[8] = -f[0] / sx;
	viewToClip[5] = f[2] / sy; viewToClip[9] = -f[1] / sy;
	viewToClip[10] = 1; viewToClip[14] = -near;
	viewToClip[11] = 1;
	return { worldToView, viewToClip };
}

export interface NrdFrameState { camera: NrdCamera; jitter: [number, number]; width: number; height: number }

/**
 * NRD common settings for one frame, as NrdPlanner.plan takes them. `previous` is the last
 * denoised frame; it is ignored for matrices and jitter on a history reset. `timeDelta` 0 lets NRD measure
 * the time between frames itself (production); tests pass a fixed value for deterministic constants.
 */
export function nrdCommonInputs(current: NrdFrameState, previous: NrdFrameState | null, frameIndex: number, reset: boolean, timeDelta = 0) {
	const now = nrdMatrices(current.camera), prev = previous && !reset ? nrdMatrices(previous.camera) : now;
	const jitter = current.jitter.map(v => v - 0.5), previousJitter = previous && !reset ? previous.jitter.map(v => v - 0.5) : jitter;
	return {
		matrices: [...now.viewToClip, ...prev.viewToClip, ...now.worldToView, ...prev.worldToView],
		params: [1 / current.width, 1 / current.height, 0, ...jitter, ...previousJitter, DENOISING_RANGE, 0.01, 1, timeDelta],
		ints: [current.width, current.height, previous?.width ?? current.width, previous?.height ?? current.height,
			frameIndex, reset ? ACCUMULATION_CLEAR_AND_RESTART : ACCUMULATION_CONTINUE, 0],
	};
}

export class NrdDenoiser {
	stats: NrdStats;
	private readonly desc: InstanceDesc;
	private readonly samplers: GPUSampler[];
	private readonly params: GPUBuffer;
	private constants: GPUBuffer | null = null;
	private readonly pipelines = new Map<string, { pipeline: GPUComputePipeline; layouts: GPUBindGroupLayout[]; declarations: Declaration[] } | 'pending' | 'failed'>();
	private readonly passes: Record<'Prepare' | 'Composite', { pipeline: GPUComputePipeline; layout: GPUBindGroupLayout }>;
	private permanent: GPUTexture[] = [];
	private transient: GPUTexture[] = [];
	private user = new Map<number, GPUTexture>();
	private composite: GPUBuffer | null = null;
	private width = 0;
	private height = 0;
	private previous: NrdFrameState | null = null;
	private frameIndex = 0;
	private needsReset = true;
	private readonly exact: boolean;

	private constructor(private readonly device: GPUDevice, private readonly planner: NrdPlanner, passes: NrdDenoiser['passes'], readonly mode: NrdMode) {
		this.passes = passes;
		this.stats = { active: false, reason: 'not-rendered', mode, dispatches: 0, frames: 0, bytes: 0 };
		this.exact = device.features.has('texture-formats-tier1' as GPUFeatureName);
		this.desc = planner.desc;
		this.samplers = this.desc.samplers.map(kind => device.createSampler({ label: `nrd.sampler${kind}`, magFilter: kind ? 'linear' : 'nearest', minFilter: kind ? 'linear' : 'nearest' }));
		this.params = device.createBuffer({ label: 'nrd.params', size: 32, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
	}

	/** Requires float32-filterable (32-bit float pools are sampled with linear filtering) and 7 storage / 15 sampled textures. */
	static unsupportedReason(device: GPUDevice): string | null {
		if (!device.features.has('float32-filterable')) return 'float32-filterable';
		if (device.limits.maxStorageTexturesPerShaderStage < 7) return 'storage-texture-limit';
		if (device.limits.maxSampledTexturesPerShaderStage < 15) return 'sampled-texture-limit';
		return null;
	}

	static async create(device: GPUDevice, mode: NrdMode = 'radiance'): Promise<NrdDenoiser> {
		const reason = NrdDenoiser.unsupportedReason(device);
		if (reason) throw new Error(`NRD is unsupported on this device: ${reason}`);
		const planner = new NrdPlanner(DENOISERS[mode]);
		planner.setReblur(REBLUR_FLOATS, REBLUR_INTS);
		const C = GPUShaderStage.COMPUTE;
		const buffer = (binding: number, type: GPUBufferBindingType): GPUBindGroupLayoutEntry => ({ binding, visibility: C, buffer: { type } });
		const prepare = device.createBindGroupLayout({ label: 'nrd.prepare', entries: [buffer(0, 'uniform'), buffer(1, 'uniform'), buffer(2, 'read-only-storage'), buffer(3, 'read-only-storage'),
			...PREPARE[mode].map(([binding, type]) => ({ binding, visibility: C, storageTexture: { access: 'write-only' as const, format: userFormat(type) } }))] });
		const composite = device.createBindGroupLayout({ label: 'nrd.composite', entries: [buffer(0, 'uniform'), buffer(1, 'uniform'), buffer(2, 'read-only-storage'),
			...COMPOSITE[mode].map(([binding]) => ({ binding, visibility: C, texture: { sampleType: 'float' as const } })), buffer(11, 'storage')] });
		const suffix = mode === 'sh' ? 'Sh' : '';
		const compile = async (entry: 'Prepare' | 'Composite', layout: GPUBindGroupLayout) => ({ layout, pipeline: await device.createComputePipelineAsync({ label: `nrd.${entry}${suffix}`,
			layout: device.createPipelineLayout({ bindGroupLayouts: [layout] }),
			compute: { module: device.createShaderModule({ label: `nrd.${entry}${suffix}`, code: nrdPasses[`${entry}${suffix}`] }), entryPoint: entry } }) });
		const [Prepare, Composite] = await Promise.all([compile('Prepare', prepare), compile('Composite', composite)]);
		return new NrdDenoiser(device, planner, { Prepare, Composite }, mode);
	}

	/** Returns the resolve input for TAA (same three-float4 layout as the accumulation image), or null to bypass. */
	encode(encoder: GPUCommandEncoder, input: NrdFrame): GPUBuffer | null {
		this.resize(input.width, input.height);
		const reset = input.reset || this.needsReset || !this.previous || this.previous.width !== input.width || this.previous.height !== input.height;
		const dispatches = this.plan(input, reset);
		const ready = dispatches.every(d => this.pipelineFor(d) !== null);
		// Skipped NRD work leaves its internal history stale: restart on the next frame.
		this.needsReset = !ready;
		this.writeParams(input, ready);
		const prepare = this.device.createBindGroup({ layout: this.passes.Prepare.layout, entries: [
			{ binding: 0, resource: { buffer: input.frame } }, { binding: 1, resource: { buffer: this.params } },
			{ binding: 2, resource: { buffer: input.accumulation } }, { binding: 3, resource: { buffer: input.motion } },
			...PREPARE[this.mode].map(([binding, type]) => ({ binding, resource: this.user.get(type)!.createView() })),
		] });
		const groups = [Math.ceil(input.width / 8), Math.ceil(input.height / 8)] as const;
		let pass = encoder.beginComputePass({ label: 'nrd.prepare' });
		pass.setPipeline(this.passes.Prepare.pipeline); pass.setBindGroup(0, prepare); pass.dispatchWorkgroups(...groups); pass.end();
		if (ready && dispatches.length) this.encodeDispatches(encoder, dispatches);
		const composite = this.device.createBindGroup({ layout: this.passes.Composite.layout, entries: [
			{ binding: 0, resource: { buffer: input.frame } }, { binding: 1, resource: { buffer: this.params } }, { binding: 2, resource: { buffer: input.accumulation } },
			...COMPOSITE[this.mode].map(([binding, type]) => ({ binding, resource: this.user.get(type)!.createView() })),
			{ binding: 11, resource: { buffer: this.composite! } },
		] });
		pass = encoder.beginComputePass({ label: 'nrd.composite' });
		pass.setPipeline(this.passes.Composite.pipeline); pass.setBindGroup(0, composite); pass.dispatchWorkgroups(...groups); pass.end();
		this.previous = { camera: { position: [...input.camera.position], right: [...input.camera.right], up: [...input.camera.up], forward: [...input.camera.forward] },
			jitter: [...input.jitter], width: input.width, height: input.height };
		this.frameIndex++;
		this.stats = { active: true, reason: ready ? null : 'compiling', mode: this.mode, dispatches: ready ? dispatches.length : 0, frames: ready ? this.stats.frames + 1 : 0, bytes: this.bytes() };
		return this.composite;
	}

	suspend(reason: string): void {
		this.stats = { ...this.stats, active: false, reason, dispatches: 0, frames: 0 };
		this.needsReset = true;
	}

	private plan(input: NrdFrame, reset: boolean): Dispatch[] {
		const c = nrdCommonInputs(input, this.previous, this.frameIndex, reset);
		return this.planner.plan(c.matrices, c.params, c.ints);
	}

	private texture(resource: Resource): GPUTexture {
		const texture = resource.type === PERMANENT_POOL ? this.permanent[resource.index] : resource.type === TRANSIENT_POOL ? this.transient[resource.index] : this.user.get(resource.type);
		if (!texture) throw new Error(`NRD resource ${resource.type}/${resource.index} is not provided`);
		return texture;
	}

	// scripts/build-nrd.mjs generates one WGSL variant per combination of storage formats a dispatch binds.
	private pipelineFor(dispatch: Dispatch): { pipeline: GPUComputePipeline; layouts: GPUBindGroupLayout[]; declarations: Declaration[] } | null {
		const desc = this.desc.pipelines[dispatch.pipeline];
		const variant = nrdVariantKey(dispatch.resources.filter(r => r.descriptor !== DESCRIPTOR_TEXTURE).map(r => this.texture(r).format));
		const key = `${dispatch.pipeline}:${variant}`;
		const entry = this.pipelines.get(key);
		if (entry === 'failed') throw new Error(`NRD pipeline ${desc.shader} failed to compile`);
		if (entry && entry !== 'pending') return entry;
		if (!entry) {
			const code = nrdShaders[desc.shader]?.[variant];
			if (!code) {
				this.pipelines.set(key, 'failed');
				throw new Error(`NRD pipeline ${desc.shader} has no generated variant for storage formats ${variant}; run npm run build:nrd`);
			}
			this.pipelines.set(key, 'pending');
			const decls = declarations(code);
			const layouts = [0, 1].map(group => this.device.createBindGroupLayout({ label: `nrd.${dispatch.name}.${group}`, entries: decls.filter(d => d.group === group).map(d => ({
				binding: d.binding, visibility: GPUShaderStage.COMPUTE,
				...(d.kind === 'uniform' ? { buffer: { type: 'uniform' as const, hasDynamicOffset: true } }
					: d.kind === 'sampler' ? { sampler: { type: this.desc.samplers[d.binding - SHIFT.sampler] ? 'filtering' as const : 'non-filtering' as const } }
						: d.kind === 'storage' ? { storageTexture: { access: d.access, format: d.format as GPUTextureFormat } }
							: { texture: { sampleType: d.sample } }),
			})) }));
			this.device.createComputePipelineAsync({ label: `nrd.${dispatch.name}`, layout: this.device.createPipelineLayout({ bindGroupLayouts: layouts }),
				compute: { module: this.device.createShaderModule({ label: `nrd.${desc.shader}`, code }), entryPoint: 'main' } })
				.then(pipeline => this.pipelines.set(key, { pipeline, layouts, declarations: decls }), error => { console.error(`NRD pipeline ${desc.shader}:`, error); this.pipelines.set(key, 'failed'); });
		}
		return null;
	}

	private encodeDispatches(encoder: GPUCommandEncoder, dispatches: Dispatch[]): void {
		const bytes = dispatches.length * CONSTANT_STRIDE;
		if (!this.constants || this.constants.size < bytes) {
			this.constants?.destroy();
			this.constants = this.device.createBuffer({ label: 'nrd.constants', size: Math.max(bytes, 16 * CONSTANT_STRIDE), usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
		}
		const data = new Uint8Array(bytes);
		dispatches.forEach((d, i) => data.set(d.constants, i * CONSTANT_STRIDE));
		this.device.queue.writeBuffer(this.constants, 0, data);
		const pass = encoder.beginComputePass({ label: 'nrd.reblur' });
		dispatches.forEach((dispatch, i) => {
			const { pipeline, layouts, declarations: decls } = this.pipelineFor(dispatch)!;
			const ranges = this.desc.pipelines[dispatch.pipeline].ranges;
			const views = new Map<number, GPUTextureView>();
			let at = 0;
			for (const [descriptor, count] of ranges) {
				const base = descriptor === DESCRIPTOR_TEXTURE ? SHIFT.texture : SHIFT.storage;
				for (let r = 0; r < count; r++) views.set(base + r, this.texture(dispatch.resources[at++]).createView());
			}
			const group0 = this.device.createBindGroup({ layout: layouts[0], entries: decls.filter(d => d.group === 0).map(d => ({ binding: d.binding, resource: views.get(d.binding)! })) });
			const group1 = this.device.createBindGroup({ layout: layouts[1], entries: decls.filter(d => d.group === 1).map(d => ({ binding: d.binding,
				resource: d.kind === 'uniform' ? { buffer: this.constants!, size: CONSTANT_STRIDE } : this.samplers[d.binding - SHIFT.sampler] })) });
			pass.setPipeline(pipeline);
			pass.setBindGroup(0, group0);
			pass.setBindGroup(1, group1, decls.some(d => d.group === 1 && d.kind === 'uniform') ? [i * CONSTANT_STRIDE] : []);
			pass.dispatchWorkgroups(dispatch.width, dispatch.height);
		});
		pass.end();
	}

	private writeParams(input: NrdFrame, history: boolean): void {
		const data = new ArrayBuffer(32), f = new Float32Array(data), u = new Uint32Array(data);
		f.set([...HIT_DISTANCE, DENOISING_RANGE], 0);
		u.set([input.region, input.debug, Number(history), Number(input.reJitter)], 4);
		this.device.queue.writeBuffer(this.params, 0, data);
	}

	private resize(width: number, height: number): void {
		if (width === this.width && height === this.height) return;
		this.release();
		const usage = GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.STORAGE_BINDING;
		const create = (label: string, format: GPUTextureFormat, downsample = 1) => this.device.createTexture({ label, format, usage,
			size: [Math.max(1, Math.ceil(width / downsample)), Math.max(1, Math.ceil(height / downsample))] });
		this.permanent = this.desc.permanentPool.map(([f, d], i) => create(`nrd.permanent${i}`, poolFormat(f, this.exact), d));
		this.transient = this.desc.transientPool.map(([f, d], i) => create(`nrd.transient${i}`, poolFormat(f, this.exact), d));
		const types = new Set([...PREPARE[this.mode], ...COMPOSITE[this.mode]].map(([, type]) => type));
		this.user = new Map([...types].map(type => [type, create(`nrd.user${type}`, userFormat(type))]));
		this.composite = this.device.createBuffer({ label: 'nrd.composite', size: width * height * 48, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC });
		this.width = width; this.height = height;
		this.needsReset = true;
	}

	private bytes(): number {
		let total = this.composite?.size ?? 0;
		for (const t of [...this.permanent, ...this.transient, ...this.user.values()]) total += t.width * t.height * (BYTES[t.format] ?? 16);
		return total;
	}

	private release(): void {
		for (const t of [...this.permanent, ...this.transient, ...this.user.values()]) t.destroy();
		this.composite?.destroy();
		this.permanent = []; this.transient = []; this.user = new Map(); this.composite = null;
		this.width = 0; this.height = 0;
	}

	destroy(): void {
		this.release();
		this.constants?.destroy();
		this.params.destroy();
	}
}
