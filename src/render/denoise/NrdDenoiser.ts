// NVIDIA NRD REBLUR on WebGPU (docs/Nrd.md). The NRD runtime (WASM) plans dispatches; this class owns
// textures, pipelines and bind groups. Loaded lazily: the generated shaders and runtime are only
// fetched when NRD is enabled. Two modes: 'radiance' (REBLUR_DIFFUSE_SPECULAR) and 'sh'
// (REBLUR_DIFFUSE_SH + REBLUR_SPECULAR_SH, SG resolve and re-jittering in Composite).
import createNRDModule, { type NRDModule } from '../../generated/nrd/nrd.mjs';
import { nrdShaders } from '../../generated/nrd/NrdShaders';
import { nrdPasses } from '../../generated/nrd/NrdPasses';
import { vec3, type Vec3 } from '../../math/Math';

export interface NrdCamera { position: Vec3; right: Vec3; up: Vec3; forward: Vec3 }
export type NrdMode = 'radiance' | 'sh';
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

// Matches the CONFIG and register shifts in scripts/build-nrd.mjs.
const SHIFT = { sampler: 0, constant: 2, storage: 3, texture: 20 };
// nrd::Denoiser values; identifiers are indices (scripts/build-nrd.mjs DENOISERS).
const DENOISERS: Record<NrdMode, number[]> = { radiance: [6], sh: [2, 5] };
const DESCRIPTOR_TEXTURE = 0;
const IN_MV = 0, IN_NORMAL_ROUGHNESS = 1, IN_VIEWZ = 2, IN_DIFF = 6, IN_SPEC = 7, IN_DIFF_SH0 = 11, IN_DIFF_SH1 = 12, IN_SPEC_SH0 = 13, IN_SPEC_SH1 = 14;
const OUT_DIFF = 18, OUT_SPEC = 19, OUT_DIFF_SH0 = 20, OUT_DIFF_SH1 = 21, OUT_SPEC_SH0 = 22, OUT_SPEC_SH1 = 23, OUT_VALIDATION = 29, TRANSIENT_POOL = 30, PERMANENT_POOL = 31;
// Prepare storage bindings and Composite texture bindings per mode (NrdPasses.slang).
const PREPARE: Record<NrdMode, [number, number][]> = {
	radiance: [[4, IN_MV], [5, IN_NORMAL_ROUGHNESS], [6, IN_VIEWZ], [7, IN_DIFF], [8, IN_SPEC]],
	sh: [[4, IN_MV], [5, IN_NORMAL_ROUGHNESS], [6, IN_VIEWZ], [7, IN_DIFF_SH0], [8, IN_SPEC_SH0], [12, IN_DIFF_SH1], [13, IN_SPEC_SH1]],
};
const COMPOSITE: Record<NrdMode, [number, number][]> = {
	radiance: [[9, OUT_DIFF], [10, OUT_SPEC]],
	sh: [[9, OUT_DIFF_SH0], [10, OUT_SPEC_SH0], [14, OUT_DIFF_SH1], [15, OUT_SPEC_SH1]],
};
const ACCUMULATION_CONTINUE = 0, ACCUMULATION_CLEAR_AND_RESTART = 2;
const CONSTANT_STRIDE = 1024;
// Sky and other surfaceless pixels are written beyond the denoising range (NrdPasses.slang).
const DENOISING_RANGE = 1e6;
const HIT_DISTANCE = [3, 0.1, 20] as const; // REBLUR defaults (A, B, C), shared with Prepare

// nrd::Format -> [exact format, core WebGPU storage fallback]. Fallbacks only widen precision; normalized
// formats without a WebGPU storage equivalent are stored as floats (NRD writes values in range).
const FORMATS: Record<number, [GPUTextureFormat, GPUTextureFormat]> = {
	0: ['r8unorm', 'rgba8unorm'], 1: ['r8snorm', 'r32float'], 2: ['r8uint', 'r32uint'], 3: ['r8sint', 'r32sint'],
	4: ['rg8unorm', 'rgba8unorm'], 5: ['rg8snorm', 'rg32float'], 6: ['rg8uint', 'rg32uint'], 7: ['rg8sint', 'rg32sint'],
	8: ['rgba8unorm', 'rgba8unorm'], 9: ['rgba8snorm', 'rgba8snorm'], 10: ['rgba8uint', 'rgba8uint'], 11: ['rgba8sint', 'rgba8sint'], 12: ['rgba8unorm', 'rgba8unorm'],
	13: ['r16float', 'r32float'], 14: ['r16float', 'r32float'], 15: ['r16uint', 'r32uint'], 16: ['r16sint', 'r32sint'], 17: ['r16float', 'r32float'],
	18: ['rg16float', 'rg32float'], 19: ['rg16float', 'rg32float'], 20: ['rg16uint', 'rg32uint'], 21: ['rg16sint', 'rg32sint'], 22: ['rg16float', 'rgba16float'],
	23: ['rgba32float', 'rgba32float'], 24: ['rgba32float', 'rgba32float'], 25: ['rgba16uint', 'rgba16uint'], 26: ['rgba16sint', 'rgba16sint'], 27: ['rgba16float', 'rgba16float'],
	28: ['r32uint', 'r32uint'], 29: ['r32sint', 'r32sint'], 30: ['r32float', 'r32float'],
	31: ['rg32uint', 'rg32uint'], 32: ['rg32sint', 'rg32sint'], 33: ['rg32float', 'rg32float'],
	37: ['rgba32uint', 'rgba32uint'], 38: ['rgba32sint', 'rgba32sint'], 39: ['rgba32float', 'rgba32float'],
	40: ['rgb10a2unorm', 'rgba16float'], 41: ['rgb10a2uint', 'rgba32uint'], 42: ['rg11b10ufloat', 'rgba16float'], 43: ['rgba16float', 'rgba16float'],
};
const USER_FORMAT: Record<number, GPUTextureFormat> = { [IN_VIEWZ]: 'r32float', [OUT_VALIDATION]: 'rgba8unorm' };
const userFormat = (type: number): GPUTextureFormat => USER_FORMAT[type] ?? 'rgba16float';
const BYTES: Partial<Record<GPUTextureFormat, number>> = { r8unorm: 1, r8snorm: 1, r8uint: 1, r8sint: 1, rg8unorm: 2, rg8snorm: 2, rg8uint: 2, rg8sint: 2,
	rgba8unorm: 4, rgba8snorm: 4, rgba8uint: 4, rgba8sint: 4, r16uint: 2, r16sint: 2, r16float: 2, rg16uint: 4, rg16sint: 4, rg16float: 4,
	rgba16uint: 8, rgba16sint: 8, rgba16float: 8, r32uint: 4, r32sint: 4, r32float: 4, rg32uint: 8, rg32sint: 8, rg32float: 8,
	rgba32uint: 16, rgba32sint: 16, rgba32float: 16, rgb10a2unorm: 4, rgb10a2uint: 4, rg11b10ufloat: 4 };

interface InstanceDesc {
	constantBufferMaxDataSize: number;
	samplers: number[];
	permanentPool: [number, number][];
	transientPool: [number, number][];
	pipelines: { shader: string; hasConstantData: boolean; ranges: [number, number][] }[];
}
interface Resource { descriptor: number; type: number; index: number }
interface Dispatch { pipeline: number; width: number; height: number; constants: Uint8Array; resources: Resource[]; name: string }
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

export class NrdDenoiser {
	stats: NrdStats;
	private readonly context: number;
	private readonly desc: InstanceDesc;
	private readonly samplers: GPUSampler[];
	private readonly params: GPUBuffer;
	private constants: GPUBuffer | null = null;
	private readonly scratch: number;
	private readonly pipelines = new Map<string, { pipeline: GPUComputePipeline; layouts: GPUBindGroupLayout[]; declarations: Declaration[] } | 'pending' | 'failed'>();
	private readonly passes: Record<'Prepare' | 'Composite', { pipeline: GPUComputePipeline; layout: GPUBindGroupLayout }>;
	private permanent: GPUTexture[] = [];
	private transient: GPUTexture[] = [];
	private user = new Map<number, GPUTexture>();
	private composite: GPUBuffer | null = null;
	private width = 0;
	private height = 0;
	private previous: { camera: NrdCamera; jitter: [number, number]; width: number; height: number } | null = null;
	private frameIndex = 0;
	private needsReset = true;
	private readonly exact: boolean;

	private constructor(private readonly device: GPUDevice, private readonly module: NRDModule, passes: NrdDenoiser['passes'], readonly mode: NrdMode) {
		this.passes = passes;
		this.stats = { active: false, reason: 'not-rendered', mode, dispatches: 0, frames: 0, bytes: 0 };
		this.exact = device.features.has('texture-formats-tier1' as GPUFeatureName);
		const list = module._nrd_malloc(DENOISERS[mode].length * 4);
		module.HEAPU32.set(DENOISERS[mode], list >> 2);
		this.context = module._nrd_create(list, DENOISERS[mode].length);
		module._nrd_free(list);
		if (!this.context) throw new Error('NRD instance creation failed');
		this.desc = JSON.parse(module.UTF8ToString(module._nrd_instance_desc(this.context))) as InstanceDesc;
		this.samplers = this.desc.samplers.map(kind => device.createSampler({ label: `nrd.sampler${kind}`, magFilter: kind ? 'linear' : 'nearest', minFilter: kind ? 'linear' : 'nearest' }));
		this.params = device.createBuffer({ label: 'nrd.params', size: 32, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
		this.scratch = module._nrd_malloc(4 * (64 + 11 + 7));
		const reblur = module._nrd_malloc(4 * 18);
		module.HEAPF32.set([...HIT_DISTANCE, 2, 30, 50, 1, 30, 0.15, 0.15, 0.02], reblur >> 2);
		module.HEAPU32.set([30, 6, 63, 3, 0, 0, 1], (reblur >> 2) + 11);
		if (module._nrd_set_reblur(this.context, reblur, reblur + 44) !== 0) throw new Error('NRD REBLUR settings rejected');
		module._nrd_free(reblur);
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
		const module = await createNRDModule();
		const C = GPUShaderStage.COMPUTE;
		const buffer = (binding: number, type: GPUBufferBindingType): GPUBindGroupLayoutEntry => ({ binding, visibility: C, buffer: { type } });
		const prepare = device.createBindGroupLayout({ label: 'nrd.prepare', entries: [buffer(0, 'uniform'), buffer(1, 'uniform'), buffer(2, 'read-only-storage'), buffer(3, 'read-only-storage'),
			...PREPARE[mode].map(([binding, type]) => ({ binding, visibility: C, storageTexture: { access: 'write-only' as const, format: userFormat(type) } }))] });
		const composite = device.createBindGroupLayout({ label: 'nrd.composite', entries: [buffer(0, 'uniform'), buffer(1, 'uniform'), buffer(2, 'read-only-storage'),
			...COMPOSITE[mode].map(([binding]) => ({ binding, visibility: C, texture: { sampleType: 'float' as const } })), buffer(11, 'storage')] });
		const formats = new Map<number, string>(PREPARE[mode].map(([binding, type]) => [binding, userFormat(type)]));
		const suffix = mode === 'sh' ? 'Sh' : '';
		const compile = async (entry: 'Prepare' | 'Composite', layout: GPUBindGroupLayout) => ({ layout, pipeline: await device.createComputePipelineAsync({ label: `nrd.${entry}${suffix}`,
			layout: device.createPipelineLayout({ bindGroupLayouts: [layout] }),
			compute: { module: device.createShaderModule({ label: `nrd.${entry}${suffix}`, code: NrdDenoiser.specialize(nrdPasses[`${entry}${suffix}`], 0, formats) }), entryPoint: 'main' } }) });
		const [Prepare, Composite] = await Promise.all([compile('Prepare', prepare), compile('Composite', composite)]);
		return new NrdDenoiser(device, module, { Prepare, Composite }, mode);
	}

	/** Substitutes storage texture formats (by binding in the group) and renames the entry point to main. */
	private static specialize(code: string, group: number, formats: Map<number, string>): string {
		return code.replace(/@binding\((\d+)\) @group\((\d+)\) var (\w+) : texture_storage_2d<(\w+), (\w+)>/g, (match, binding, g, name, _format, access) =>
			+g === group && formats.has(+binding) ? `@binding(${binding}) @group(${g}) var ${name} : texture_storage_2d<${formats.get(+binding)}, ${access}>` : match)
			.replace(/fn (Prepare|Composite)\(/, 'fn main(');
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
		const m = this.module, base = this.scratch >> 2;
		const current = nrdMatrices(input.camera), previous = this.previous && !reset ? nrdMatrices(this.previous.camera) : current;
		m.HEAPF32.set(current.viewToClip, base); m.HEAPF32.set(previous.viewToClip, base + 16);
		m.HEAPF32.set(current.worldToView, base + 32); m.HEAPF32.set(previous.worldToView, base + 48);
		const jitter = input.jitter.map(v => v - 0.5), previousJitter = this.previous && !reset ? this.previous.jitter.map(v => v - 0.5) : jitter;
		m.HEAPF32.set([1 / input.width, 1 / input.height, 0, ...jitter, ...previousJitter, DENOISING_RANGE, 0.01, 1, 0], base + 64);
		m.HEAPU32.set([input.width, input.height, this.previous?.width ?? input.width, this.previous?.height ?? input.height,
			this.frameIndex, reset ? ACCUMULATION_CLEAR_AND_RESTART : ACCUMULATION_CONTINUE, 0], base + 75);
		if (m._nrd_set_common(this.context, this.scratch, this.scratch + 256, this.scratch + 300) !== 0) throw new Error('NRD common settings rejected');
		const pointer = m._nrd_dispatches(this.context);
		if (!pointer) throw new Error('NRD GetComputeDispatches failed');
		const words = m.HEAPU32, bytes = m.HEAPU8;
		let at = pointer >> 2;
		const count = words[at++];
		const dispatches: Dispatch[] = [];
		for (let i = 0; i < count; i++) {
			const [pipeline, width, height, resourceCount, constantBytes, name] = words.subarray(at, at + 6);
			at += 6;
			const constants = bytes.slice(at * 4, at * 4 + constantBytes);
			at += Math.ceil(constantBytes / 4);
			const resources: Resource[] = [];
			for (let r = 0; r < resourceCount; r++, at += 3) resources.push({ descriptor: words[at], type: words[at + 1], index: words[at + 2] });
			dispatches.push({ pipeline, width, height, constants, resources, name: name ? m.UTF8ToString(name) : `nrd${pipeline}` });
		}
		return dispatches;
	}

	private texture(resource: Resource): GPUTexture {
		const texture = resource.type === PERMANENT_POOL ? this.permanent[resource.index] : resource.type === TRANSIENT_POOL ? this.transient[resource.index] : this.user.get(resource.type);
		if (!texture) throw new Error(`NRD resource ${resource.type}/${resource.index} is not provided`);
		return texture;
	}

	// Storage formats are baked into WGSL; resolve them from the textures the dispatch binds.
	private pipelineFor(dispatch: Dispatch): { pipeline: GPUComputePipeline; layouts: GPUBindGroupLayout[]; declarations: Declaration[] } | null {
		const desc = this.desc.pipelines[dispatch.pipeline];
		const formats = new Map<number, string>();
		let storage = 0;
		for (const resource of dispatch.resources) if (resource.descriptor !== DESCRIPTOR_TEXTURE) formats.set(SHIFT.storage + storage++, this.texture(resource).format);
		const key = `${dispatch.pipeline}:${[...formats.values()].join(',')}`;
		const entry = this.pipelines.get(key);
		if (entry === 'failed') throw new Error(`NRD pipeline ${desc.shader} failed to compile`);
		if (entry && entry !== 'pending') return entry;
		if (!entry) {
			this.pipelines.set(key, 'pending');
			const code = NrdDenoiser.specialize(nrdShaders[desc.shader], 0, formats);
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
		const format = (nrd: number) => {
			const pair = FORMATS[nrd];
			if (!pair) throw new Error(`NRD texture format ${nrd} has no WebGPU mapping`);
			return pair[this.exact ? 0 : 1];
		};
		this.permanent = this.desc.permanentPool.map(([f, d], i) => create(`nrd.permanent${i}`, format(f), d));
		this.transient = this.desc.transientPool.map(([f, d], i) => create(`nrd.transient${i}`, format(f), d));
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
		this.module._nrd_free(this.scratch);
		this.module._nrd_destroy(this.context);
	}
}
