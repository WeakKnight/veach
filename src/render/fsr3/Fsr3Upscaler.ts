// AMD FidelityFX FSR 3.1.4 upscaler on WebGPU (docs/Fsr3.md). A TypeScript port of the host dispatch logic of
// ThirdParty/FidelityFX/host/ffx_fsr3upscaler.cpp (fsr3upscalerCreate resources, fsr3upscalerDispatch ping-pong,
// clears and dispatch order) for Veach's context flags: HIGH_DYNAMIC_RANGE | DEPTH_INVERTED | DEPTH_INFINITE |
// AUTO_EXPOSURE, render-resolution motion vectors, no reactive or transparency-and-composition masks.
// Inputs and the output are textures, as in FidelityFX: color rgba16float, depth r32float (inverted infinite),
// motion rg32float (previous - current, render pixels), output rgba16float at the upscaled size.
import { fsr3Shaders } from '../../generated/fsr3/Fsr3Shaders';
import { FSR3_CONSTANTS_BYTES, FSR3_RCAS_CONSTANTS_BYTES, FSR3_SPD_CONSTANTS_BYTES, Fsr3ConstantState, fsr3RcasConstants, fsr3SpdSetup, type Fsr3Dispatch } from './Fsr3Config';

export interface Fsr3Inputs { color: GPUTexture; depth: GPUTexture; motion: GPUTexture; output: GPUTexture }

type Pass = 'PrepareInputs' | 'LumaPyramid' | 'LumaPyramidTail' | 'ShadingChangePyramid' | 'ShadingChange' | 'PrepareReactivity'
	| 'LumaInstability' | 'Accumulate' | 'AccumulateSharpen' | 'Rcas';
const PASSES: Pass[] = ['PrepareInputs', 'LumaPyramid', 'LumaPyramidTail', 'ShadingChangePyramid', 'ShadingChange', 'PrepareReactivity',
	'LumaInstability', 'Accumulate', 'AccumulateSharpen', 'Rcas'];

export interface Declaration { binding: number; kind: 'uniform' | 'read-only-storage' | 'storage' | 'texture' | 'storage-texture' | 'sampler'; sample: GPUTextureSampleType; format: GPUTextureFormat; access: GPUStorageTextureAccess }

/** Resource declarations (group 0) of the WGSL slangc emits. */
export function declarations(code: string): Declaration[] {
	return [...code.matchAll(/@binding\((\d+)\) @group\(0\) var(<[\w, ]+>)? \w+ : ([^;]+);/g)].map(([, binding, space, type]) => {
		const storage = type.match(/^texture_storage_2d<(\w+), (\w+)>/);
		const kind = space === '<uniform>' ? 'uniform' : space === '<storage, read>' ? 'read-only-storage' : space ? 'storage'
			: storage ? 'storage-texture' : type === 'sampler' ? 'sampler' : 'texture';
		return { binding: +binding, kind, sample: type.includes('<u32>') ? 'uint' : 'float', format: (storage?.[1] ?? 'rgba8unorm') as GPUTextureFormat,
			access: storage?.[2] === 'read_write' ? 'read-write' : 'write-only' };
	});
}

export interface Pipeline { pipeline: GPUComputePipeline; layout: GPUBindGroupLayout; declarations: Declaration[] }

export async function createPipeline(device: GPUDevice, label: string, code: string): Promise<Pipeline> {
	const decls = declarations(code);
	const layout = device.createBindGroupLayout({ label, entries: decls.map(d => ({
		binding: d.binding, visibility: GPUShaderStage.COMPUTE,
		...(d.kind === 'uniform' || d.kind === 'read-only-storage' || d.kind === 'storage' ? { buffer: { type: d.kind } }
			: d.kind === 'sampler' ? { sampler: { type: 'filtering' as const } }
				: d.kind === 'storage-texture' ? { storageTexture: { access: d.access, format: d.format } }
					: { texture: { sampleType: d.sample === 'uint' ? 'uint' as const : 'float' as const } }),
	})) });
	const pipeline = await device.createComputePipelineAsync({ label, layout: device.createPipelineLayout({ bindGroupLayouts: [layout] }),
		compute: { module: device.createShaderModule({ label, code }), entryPoint: 'main' } });
	return { pipeline, layout, declarations: decls };
}

// Bindings of shaders/Fsr3/Fsr3Callbacks.hlsli.
const B = {
	constants: 0, cb2: 1, pointSampler: 2, linearSampler: 3, frameInfo: 4, reconstructedDepth: 5,
	spdMips: 10, inputDepth: 11, reactiveMask: 12, tcMask: 13, inputColor: 14, inputMotion: 15, internalUpscaled: 16, lumaHistory: 17,
	rcasInput: 18, accumulation: 19, shadingChange: 20, farthestDepth: 21, farthestDepthMip1: 22, currentLuma: 23, lumaInstability: 24,
	previousLuma: 25, newLocksSrv: 26, dilatedMotion: 27, dilatedDepth: 28, lanczosLut: 29, dilatedReactiveMasks: 30, spdMip5Srv: 31,
	rwLumaHistory: 40, rwInternalUpscaled: 41, rwOutput: 42, rwAccumulation: 43, rwShadingChange: 44, rwFarthestDepth: 45,
	rwFarthestDepthMip1: 46, rwCurrentLuma: 47, rwLumaInstability: 48, rwNewLocks: 49, rwDilatedDepth: 50, rwDilatedMotion: 51,
	rwDilatedReactiveMasks: 52, rwSpdMip0: 53,
} as const;

interface Resources {
	accumulation: [GPUTexture, GPUTexture]; luma: [GPUTexture, GPUTexture]; intermediate: GPUTexture; shadingChange: GPUTexture;
	newLocks: GPUTexture; internalUpscaled: [GPUTexture, GPUTexture]; spdMips: GPUTexture; farthestDepthMip1: GPUTexture;
	lumaHistory: [GPUTexture, GPUTexture]; dilatedReactiveMasks: GPUTexture; dilatedDepth: GPUTexture; dilatedMotion: GPUTexture;
	defaultReactivity: GPUTexture; frameInfo: GPUBuffer; reconstructedDepth: GPUBuffer;
}

/** One FfxFsr3UpscalerContext: maxRenderSize and maxUpscaleSize are fixed; create a new context to resize. */
export class Fsr3Upscaler {
	private readonly state: Fsr3ConstantState;
	private readonly constants: GPUBuffer;
	private readonly spdConstants: GPUBuffer;
	private readonly rcasConstants: GPUBuffer;
	private readonly point: GPUSampler;
	private readonly linear: GPUSampler;
	private readonly r: Resources;
	private resourceFrameIndex = 0;
	private firstExecution = true;

	private constructor(private readonly device: GPUDevice, private readonly pipelines: Record<Pass, Pipeline>,
		readonly maxRenderSize: [number, number], readonly maxUpscaleSize: [number, number]) {
		this.state = new Fsr3ConstantState(maxRenderSize, maxUpscaleSize);
		const uniform = (label: string, size: number) => device.createBuffer({ label, size, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
		this.constants = uniform('fsr3.constants', FSR3_CONSTANTS_BYTES);
		this.spdConstants = uniform('fsr3.spdConstants', FSR3_SPD_CONSTANTS_BYTES);
		this.rcasConstants = uniform('fsr3.rcasConstants', FSR3_RCAS_CONSTANTS_BYTES);
		this.point = device.createSampler({ label: 'fsr3.pointClamp' });
		this.linear = device.createSampler({ label: 'fsr3.linearClamp', magFilter: 'linear', minFilter: 'linear', mipmapFilter: 'linear' });
		const [rw, rh] = maxRenderSize, [uw, uh] = maxUpscaleSize, T = GPUTextureUsage;
		const work = T.TEXTURE_BINDING | T.STORAGE_BINDING | T.RENDER_ATTACHMENT;
		const texture = (label: string, format: GPUTextureFormat, w: number, h: number, mipLevelCount = 1) =>
			device.createTexture({ label: `fsr3.${label}`, size: [Math.max(1, w), Math.max(1, h)], format, usage: work, mipLevelCount });
		const pair = (label: string, format: GPUTextureFormat, w: number, h: number) => [texture(`${label}1`, format, w, h), texture(`${label}2`, format, w, h)] as [GPUTexture, GPUTexture];
		const halfW = Math.floor(rw / 2), halfH = Math.floor(rh / 2);
		this.r = {
			accumulation: pair('accumulation', 'r32float', rw, rh),
			luma: pair('luma', 'r32float', rw, rh),
			intermediate: texture('intermediateFp16x1', 'r32float', rw, rh),
			shadingChange: texture('shadingChange', 'r32float', halfW, halfH),
			newLocks: texture('newLocks', 'r32float', uw, uh),
			internalUpscaled: pair('internalUpscaled', 'rgba16float', uw, uh),
			spdMips: texture('spdMips', 'rg32float', halfW, halfH, Math.floor(Math.log2(Math.max(1, halfW, halfH))) + 1),
			farthestDepthMip1: texture('farthestDepthMip1', 'r32float', halfW, halfH),
			lumaHistory: pair('lumaHistory', 'rgba16float', rw, rh),
			dilatedReactiveMasks: texture('dilatedReactiveMasks', 'rgba8unorm', rw, rh),
			dilatedDepth: texture('dilatedDepth', 'r32float', rw, rh),
			dilatedMotion: texture('dilatedMotionVectors', 'rg32float', rw, rh),
			// FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_DEFAULT_REACTIVITY (0), for the reactive and T&C masks
			defaultReactivity: device.createTexture({ label: 'fsr3.defaultReactivity', size: [1, 1], format: 'r8unorm', usage: T.TEXTURE_BINDING }),
			frameInfo: device.createBuffer({ label: 'fsr3.frameInfo', size: 16, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST }),
			reconstructedDepth: device.createBuffer({ label: 'fsr3.reconstructedPrevNearestDepth', size: rw * rh * 4, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST }),
		};
	}

	/** Requires float32-filterable: r32float / rg32float intermediates are sampled with linear filtering. */
	static unsupportedReason(device: GPUDevice): string | null {
		return device.features.has('float32-filterable') ? null : 'float32-filterable';
	}

	static async create(device: GPUDevice, maxRenderSize: [number, number], maxUpscaleSize: [number, number], pipelines?: Record<Pass, Pipeline>): Promise<Fsr3Upscaler> {
		const reason = Fsr3Upscaler.unsupportedReason(device);
		if (reason) throw new Error(`FSR3 is unsupported on this device: ${reason}`);
		pipelines ??= await Fsr3Upscaler.compile(device);
		return new Fsr3Upscaler(device, pipelines, maxRenderSize, maxUpscaleSize);
	}

	/** A context for compiled pipelines (compile()); contexts of any size share them. */
	static withPipelines(device: GPUDevice, pipelines: Record<Pass, Pipeline>, maxRenderSize: [number, number], maxUpscaleSize: [number, number]): Fsr3Upscaler {
		return new Fsr3Upscaler(device, pipelines, maxRenderSize, maxUpscaleSize);
	}

	/** The pipelines are independent of the sizes: compile once, share between contexts. */
	static async compile(device: GPUDevice): Promise<Record<Pass, Pipeline>> {
		const entries = await Promise.all(PASSES.map(async pass => [pass, await createPipeline(device, `fsr3.${pass}`, fsr3Shaders[pass])] as const));
		return Object.fromEntries(entries) as Record<Pass, Pipeline>;
	}

	get bytes(): number {
		let total = this.r.frameInfo.size + this.r.reconstructedDepth.size;
		const bpp: Partial<Record<GPUTextureFormat, number>> = { r32float: 4, rg32float: 8, rgba16float: 8, rgba8unorm: 4, r8unorm: 1 };
		const r = this.r;
		for (const t of [...r.accumulation, ...r.luma, r.intermediate, r.shadingChange, r.newLocks, ...r.internalUpscaled, r.spdMips, r.farthestDepthMip1,
			...r.lumaHistory, r.dilatedReactiveMasks, r.dilatedDepth, r.dilatedMotion]) {
			let texels = 0;
			for (let mip = 0; mip < t.mipLevelCount; mip++) texels += Math.max(1, t.width >> mip) * Math.max(1, t.height >> mip);
			total += texels * (bpp[t.format] ?? 16);
		}
		return total;
	}

	/** fsr3upscalerDispatch. */
	dispatch(encoder: GPUCommandEncoder, input: Fsr3Inputs, d: Fsr3Dispatch): void {
		const r = this.r;
		const clear = (texture: GPUTexture, value: GPUColor = [0, 0, 0, 0]) => {
			for (let mip = 0; mip < texture.mipLevelCount; mip++) {
				encoder.beginRenderPass({ label: `fsr3.clear.${texture.label}`, colorAttachments: [{ view: texture.createView({ baseMipLevel: mip, mipLevelCount: 1 }), loadOp: 'clear', storeOp: 'store', clearValue: value }] }).end();
			}
		};
		if (this.firstExecution) {
			clear(r.accumulation[0]); clear(r.accumulation[1]); clear(r.luma[0]); clear(r.luma[1]);
		}
		// Prepare per frame descriptor tables
		const odd = (this.resourceFrameIndex & 1) !== 0;
		const accumulationSrv = odd ? r.accumulation[1] : r.accumulation[0], accumulationUav = odd ? r.accumulation[0] : r.accumulation[1];
		const upscaledSrv = odd ? r.internalUpscaled[1] : r.internalUpscaled[0], upscaledUav = odd ? r.internalUpscaled[0] : r.internalUpscaled[1];
		const lumaHistorySrv = odd ? r.lumaHistory[1] : r.lumaHistory[0], lumaHistoryUav = odd ? r.lumaHistory[0] : r.lumaHistory[1];
		const currentLuma = odd ? r.luma[1] : r.luma[0], previousLuma = odd ? r.luma[0] : r.luma[1];
		this.firstExecution = false;
		const reset = this.state.update(d);
		this.device.queue.writeBuffer(this.constants, 0, this.state.words);
		const [w, h] = d.renderSize, [uw, uh] = d.upscaleSize[0] || d.upscaleSize[1] ? d.upscaleSize : this.maxUpscaleSize;
		const groups = (x: number, y: number, dim = 8): [number, number] => [Math.ceil(x / dim), Math.ceil(y / dim)];
		const src = groups(w, h), dst = groups(uw, uh), shadingChange = groups(Math.trunc(w * 0.5), Math.trunc(h * 0.5));
		// Clear reconstructed depth for max depth store.
		if (reset) {
			clear(accumulationSrv);
			clear(r.spdMips);
			// Auto exposure always used to track luma changes in locking logic
			this.device.queue.writeBuffer(r.frameInfo, 0, new Float32Array([-1, 1, 0, 0]));
		}
		// Inverted depth clears to 0 (InterlockedMax).
		encoder.clearBuffer(r.reconstructedDepth);
		// FidelityFX clears SPD_MIPS every frame ("SPD counter needs to be cleared").
		clear(r.spdMips);
		const spd = fsr3SpdSetup(w, h);
		this.device.queue.writeBuffer(this.spdConstants, 0, new Uint32Array([spd.mips, spd.numWorkGroups, 0, 0, w, h, 0, 0]));
		this.device.queue.writeBuffer(this.rcasConstants, 0, fsr3RcasConstants(d.sharpness));

		const view = (t: GPUTexture, mip?: number) => mip === undefined ? t.createView() : t.createView({ baseMipLevel: mip, mipLevelCount: 1 });
		const spdMip = (mip: number) => view(r.spdMips, Math.min(mip, r.spdMips.mipLevelCount - 1));
		const common: Record<number, GPUBindingResource> = {
			[B.constants]: { buffer: this.constants }, [B.pointSampler]: this.point, [B.linearSampler]: this.linear,
			[B.frameInfo]: { buffer: r.frameInfo }, [B.reconstructedDepth]: { buffer: r.reconstructedDepth },
			[B.spdMips]: view(r.spdMips), [B.inputDepth]: view(input.depth), [B.reactiveMask]: view(r.defaultReactivity), [B.tcMask]: view(r.defaultReactivity),
			[B.inputColor]: view(input.color), [B.inputMotion]: view(input.motion), [B.internalUpscaled]: view(upscaledSrv),
			[B.lumaHistory]: view(lumaHistorySrv), [B.rcasInput]: view(upscaledUav), [B.accumulation]: view(accumulationSrv),
			[B.shadingChange]: view(r.shadingChange), [B.farthestDepth]: view(r.intermediate), [B.farthestDepthMip1]: view(r.farthestDepthMip1),
			[B.currentLuma]: view(currentLuma), [B.lumaInstability]: view(r.intermediate), [B.previousLuma]: view(previousLuma),
			[B.dilatedMotion]: view(r.dilatedMotion), [B.dilatedDepth]: view(r.dilatedDepth), [B.dilatedReactiveMasks]: view(r.dilatedReactiveMasks),
			[B.spdMip5Srv]: spdMip(5),
			[B.rwLumaHistory]: view(lumaHistoryUav), [B.rwInternalUpscaled]: view(upscaledUav), [B.rwOutput]: view(input.output),
			[B.rwAccumulation]: view(accumulationUav), [B.rwShadingChange]: view(r.shadingChange), [B.rwFarthestDepth]: view(r.intermediate),
			[B.rwFarthestDepthMip1]: view(r.farthestDepthMip1), [B.rwCurrentLuma]: view(currentLuma), [B.rwLumaInstability]: view(r.intermediate),
			[B.rwNewLocks]: view(r.newLocks), [B.rwDilatedDepth]: view(r.dilatedDepth), [B.rwDilatedMotion]: view(r.dilatedMotion),
			[B.rwDilatedReactiveMasks]: view(r.dilatedReactiveMasks),
		};
		for (let mip = 0; mip < 6; mip++) common[B.rwSpdMip0 + mip] = spdMip(mip);
		const run = (pass: GPUComputePassEncoder, name: Pass, dispatch: [number, number], cb2?: GPUBuffer) => {
			const p = this.pipelines[name];
			pass.setPipeline(p.pipeline);
			pass.setBindGroup(0, this.device.createBindGroup({ label: `fsr3.${name}`, layout: p.layout, entries: p.declarations.map(decl => {
				const resource = decl.binding === B.cb2 ? (cb2 ? { buffer: cb2 } : undefined) : common[decl.binding];
				if (!resource) throw new Error(`FSR3 ${name}: nothing bound at ${decl.binding}`);
				return { binding: decl.binding, resource };
			}) }));
			pass.dispatchWorkgroups(...dispatch);
		};
		// One compute pass per FidelityFX job, as the DX12 backend records them.
		const dispatch = (name: Pass, size: [number, number], cb2?: GPUBuffer) => {
			const pass = encoder.beginComputePass({ label: `fsr3.${name}` });
			run(pass, name, size, cb2);
			pass.end();
		};
		dispatch('PrepareInputs', src);
		dispatch('LumaPyramid', spd.dispatch, this.spdConstants);
		dispatch('LumaPyramidTail', [1, 1], this.spdConstants);
		dispatch('ShadingChangePyramid', spd.dispatch, this.spdConstants);
		dispatch('ShadingChange', shadingChange);
		dispatch('PrepareReactivity', src);
		dispatch('LumaInstability', src);
		const sharpen = d.sharpness > 0;
		dispatch(sharpen ? 'AccumulateSharpen' : 'Accumulate', dst);
		if (sharpen) dispatch('Rcas', groups(uw, uh, 16), this.rcasConstants);
		this.resourceFrameIndex = (this.resourceFrameIndex + 1) % 16;
	}

	destroy(): void {
		const r = this.r;
		for (const t of [...r.accumulation, ...r.luma, r.intermediate, r.shadingChange, r.newLocks, ...r.internalUpscaled, r.spdMips, r.farthestDepthMip1,
			...r.lumaHistory, r.dilatedReactiveMasks, r.dilatedDepth, r.dilatedMotion, r.defaultReactivity]) t.destroy();
		for (const b of [r.frameInfo, r.reconstructedDepth, this.constants, this.spdConstants, this.rcasConstants]) b.destroy();
	}
}
