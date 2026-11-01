// AMD FidelityFX SSSR 1.5 + reflection denoiser 1.3 on WebGPU (docs/Sssr.md). A TypeScript port of the host
// dispatch logic of ThirdParty/FidelityFX/host/ffx_sssr.cpp and ffx_denoiser.cpp (resources, ping-pong,
// indirect dispatches, history copies), with Veach's input preparation, depth hierarchy (instead of SPD,
// whose single-pass global atomics WebGPU cannot synchronize) and apply pass. Loaded lazily.
import { sssrShaders } from '../../generated/sssr/SssrShaders';
import type { ScreenCacheHistory } from '../ScreenCache';
import { SSSR_CONSTANTS_BYTES, SSSR_NEAR_PLANE, brdfLut, packSssrConstants, sssrDepthMips, sssrMatrices, type SssrCamera, type SssrMatrices, type SssrParameters } from './SssrConfig';

export interface SssrStats { active: boolean; reason: string | null; frames: number; bytes: number }
export interface SssrFrame {
	frame: GPUBuffer; // FrameUniforms of this frame (jitter in temporal.xy)
	accumulation: GPUBuffer; // image prefix (albedo/distance and normal guides) plus the NRD split region
	region: number;
	motion: GPUBuffer; // TAA motion: two float4 per pixel
	color: GPUBuffer; // NRD composite (three float4 per pixel): bypass + denoised diffuse
	width: number;
	height: number;
	camera: SssrCamera;
	jitter: [number, number]; // film jitter in [0, 1]
	environment: GPUTexture;
	environmentKey: string; // changes when the environment's contents change
	iblFactor: number;
	envRotation: number;
	preExposure: number;
	// Radiance cache for misses and rough surfaces (docs/RadianceCache.md); null falls back to the environment.
	radianceCache: { constants: GPUBuffer; probes: GPUBuffer } | null;
	parameters: SssrParameters;
	debug: number;
}

type Pass = 'Prepare' | 'Downsample' | 'ClassifyTiles' | 'PrepareBlueNoise' | 'PrepareIndirectArgs' | 'Intersect'
	| 'Reproject' | 'Prefilter' | 'ResolveTemporal' | 'Apply' | 'EnvironmentDownsample';
const PASSES: Pass[] = ['Prepare', 'Downsample', 'ClassifyTiles', 'PrepareBlueNoise', 'PrepareIndirectArgs', 'Intersect',
	'Reproject', 'Prefilter', 'ResolveTemporal', 'Apply', 'EnvironmentDownsample'];

interface Declaration { binding: number; kind: 'uniform' | 'read-only-storage' | 'storage' | 'texture' | 'storage-texture' | 'sampler'; sample: GPUTextureSampleType; format: GPUTextureFormat }

/** Resource declarations (group 0) of the WGSL slangc emits for SssrPasses.slang. */
function declarations(code: string): Declaration[] {
	return [...code.matchAll(/@binding\((\d+)\) @group\(0\) var(<[\w, ]+>)? \w+ : ([^;]+);/g)].map(([, binding, space, type]) => {
		const storage = type.match(/^texture_storage_2d<(\w+), \w+>/);
		const kind = space === '<uniform>' ? 'uniform' : space === '<storage, read>' ? 'read-only-storage' : space ? 'storage'
			: storage ? 'storage-texture' : type === 'sampler' ? 'sampler' : 'texture';
		return { binding: +binding, kind, sample: type.includes('<u32>') ? 'uint' : 'float', format: (storage?.[1] ?? 'rgba8unorm') as GPUTextureFormat };
	});
}

interface Pipeline { pipeline: GPUComputePipeline; layout: GPUBindGroupLayout; declarations: Declaration[] }
interface Textures {
	depth: GPUTexture; depthHistory: GPUTexture; normal: GPUTexture; normalHistory: GPUTexture;
	radiance: [GPUTexture, GPUTexture]; variance: [GPUTexture, GPUTexture]; sampleCount: [GPUTexture, GPUTexture]; averageRadiance: [GPUTexture, GPUTexture];
	extractedRoughness: GPUTexture; roughnessHistory: GPUTexture; reprojectedRadiance: GPUTexture;
}

// Bindings of shaders/Sssr/SssrCallbacks.hlsli and SssrPasses.slang.
const B = {
	constants: 0, frame: 1, accum: 2, motion: 3, color: 4, rayList: 5, tileList: 6, rayCounter: 7, indirectArgs: 8, output: 9,
	linearSampler: 10, environmentSampler: 11, depthHierarchy: 12, normal: 13, radiance: 14, radianceHistory: 15, variance: 16,
	extractedRoughness: 17, sobol: 18, scrambling: 19, blueNoise: 20, sampleCount: 21, averageRadiance: 22, reprojectedRadiance: 23,
	depthHistory: 24, normalHistory: 25, roughnessHistory: 26, environment: 27, brdfLut: 28, source: 29,
	rwRadiance: 30, rwVariance: 31, rwExtractedRoughness: 32, rwBlueNoise: 33, rwSampleCount: 34, rwAverageRadiance: 35,
	rwReprojectedRadiance: 36, outDepth: 37, outNormal: 38, sourceColor: 39, outColor: 40, sceneColorHistory: 41, sceneColorOut: 42, radianceCacheConstants: 43, radianceCacheProbes: 44,
} as const;
const BYTES: Partial<Record<GPUTextureFormat, number>> = { r32float: 4, rgba16float: 8, rgba8unorm: 4, r32uint: 4, rg32float: 8 };
const BRDF_LUT_SIZE = 32;

export class SssrReflections {
	stats: SssrStats = { active: false, reason: 'not-rendered', frames: 0, bytes: 0 };
	private readonly constants: GPUBuffer;
	private readonly linear: GPUSampler;
	private readonly environmentSampler: GPUSampler;
	private readonly brdf: GPUTexture;
	private readonly sobol: GPUTexture;
	private readonly scrambling: GPUTexture;
	private readonly blueNoise: GPUTexture;
	private readonly rayCounter: GPUBuffer;
	private readonly indirectArgs: GPUBuffer;
	// Bound when there is no radiance cache (gSssr.radianceCache = 0 never reads them).
	private readonly noRadianceCache: { constants: GPUBuffer; probes: GPUBuffer };
	private textures: Textures | null = null;
	private rayList: GPUBuffer | null = null;
	private tileList: GPUBuffer | null = null;
	private output: GPUBuffer | null = null;
	// Linear scene color (Apply output / pre-exposure), ping-pong by frame: the previous frame's is the ray-march input.
	private sceneColor: [GPUTexture, GPUTexture] | null = null;
	private previousJitter: [number, number] | null = null;
	private environment: { texture: GPUTexture; source: GPUTexture; key: string } | null = null;
	private width = 0;
	private height = 0;
	private frameIndex = 0; // FidelityFX constants.frameIndex: 0 after (re)creating the history
	private previous: SssrMatrices | null = null;

	private constructor(private readonly device: GPUDevice, private readonly pipelines: Record<Pass, Pipeline>, noise: Uint8Array) {
		this.constants = device.createBuffer({ label: 'sssr.constants', size: SSSR_CONSTANTS_BYTES, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
		this.linear = device.createSampler({ label: 'sssr.linear', magFilter: 'linear', minFilter: 'linear' });
		this.environmentSampler = device.createSampler({ label: 'sssr.environment', magFilter: 'linear', minFilter: 'linear', mipmapFilter: 'linear', addressModeU: 'repeat' });
		const lut = brdfLut(BRDF_LUT_SIZE);
		this.brdf = device.createTexture({ label: 'sssr.brdfLut', size: [BRDF_LUT_SIZE, BRDF_LUT_SIZE], format: 'rg32float', usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST });
		device.queue.writeTexture({ texture: this.brdf }, lut, { bytesPerRow: BRDF_LUT_SIZE * 8 }, [BRDF_LUT_SIZE, BRDF_LUT_SIZE]);
		// FidelityFX uploads the 1 spp blue noise tables as R32_UINT textures: sobol 256x256, scrambling 512x256.
		const table = (label: string, width: number, height: number, offset: number) => {
			const texture = device.createTexture({ label, size: [width, height], format: 'r32uint', usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST });
			device.queue.writeTexture({ texture }, Uint32Array.from(noise.subarray(offset, offset + width * height)), { bytesPerRow: width * 4 }, [width, height]);
			return texture;
		};
		this.sobol = table('sssr.sobol', 256, 256, 0);
		this.scrambling = table('sssr.scramblingTile', 512, 256, 256 * 256);
		this.blueNoise = device.createTexture({ label: 'sssr.blueNoise', size: [128, 128], format: 'rgba8unorm', usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.STORAGE_BINDING });
		this.rayCounter = device.createBuffer({ label: 'sssr.rayCounter', size: 16, usage: GPUBufferUsage.STORAGE });
		this.indirectArgs = device.createBuffer({ label: 'sssr.indirectArgs', size: 24, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.INDIRECT });
		this.noRadianceCache = { constants: device.createBuffer({ label: 'sssr.noRadianceCache', size: 176, usage: GPUBufferUsage.UNIFORM }),
			probes: device.createBuffer({ label: 'sssr.noRadianceCacheProbes', size: 16, usage: GPUBufferUsage.STORAGE }) };
	}

	/** Requires subgroups (FidelityFX's wave intrinsics) and float32-filterable (r32float history is sampled linearly). */
	static unsupportedReason(device: GPUDevice): string | null {
		if (!device.features.has('subgroups' as GPUFeatureName)) return 'subgroups';
		if (!device.features.has('float32-filterable')) return 'float32-filterable';
		return null;
	}

	static async create(device: GPUDevice): Promise<SssrReflections> {
		const reason = SssrReflections.unsupportedReason(device);
		if (reason) throw new Error(`SSSR is unsupported on this device: ${reason}`);
		const response = await fetch(new URL('../../generated/sssr/SssrBlueNoise.bin', import.meta.url));
		if (!response.ok) throw new Error(`SSSR blue noise tables: HTTP ${response.status}`);
		const noise = new Uint8Array(await response.arrayBuffer());
		const entries = await Promise.all(PASSES.map(async pass => {
			const code = sssrShaders[pass];
			const decls = declarations(code);
			const layout = device.createBindGroupLayout({ label: `sssr.${pass}`, entries: decls.map(d => ({
				binding: d.binding, visibility: GPUShaderStage.COMPUTE,
				...(d.kind === 'uniform' || d.kind === 'read-only-storage' || d.kind === 'storage' ? { buffer: { type: d.kind } }
					: d.kind === 'sampler' ? { sampler: { type: 'filtering' as const } }
						: d.kind === 'storage-texture' ? { storageTexture: { access: 'write-only' as const, format: d.format } }
							: { texture: { sampleType: d.sample } }),
			})) });
			const pipeline = await device.createComputePipelineAsync({ label: `sssr.${pass}`, layout: device.createPipelineLayout({ bindGroupLayouts: [layout] }),
				compute: { module: device.createShaderModule({ label: `sssr.${pass}`, code }), entryPoint: 'main' } });
			return [pass, { pipeline, layout, declarations: decls }] as const;
		}));
		return new SssrReflections(device, Object.fromEntries(entries) as Record<Pass, Pipeline>, noise);
	}

	/** Returns the TAA input (the accumulation image layout): color plus denoised reflections. */
	encode(encoder: GPUCommandEncoder, input: SssrFrame): GPUBuffer {
		this.resize(input.width, input.height);
		this.updateEnvironment(encoder, input.environment, input.environmentKey);
		const t = this.textures!, env = this.environment!;
		const current = sssrMatrices(input.camera, input.jitter, input.width, input.height);
		this.device.queue.writeBuffer(this.constants, 0, packSssrConstants({
			current, previous: this.previous ?? current, width: input.width, height: input.height, frameIndex: this.frameIndex,
			// Debug 4 shows the raw intersection output: reflections only, without the denoiser passes.
			parameters: input.parameters, iblFactor: input.iblFactor, envRotation: input.envRotation, region: input.region, debug: input.debug === 4 ? 1 : input.debug,
			preExposure: input.preExposure, sceneColorHistory: this.frameIndex > 0, radianceCache: !!input.radianceCache,
			jitterDelta: this.previousJitter ? [input.jitter[0] - this.previousJitter[0], input.jitter[1] - this.previousJitter[1]] : [0, 0],
		}));
		const view = (texture: GPUTexture, mip?: number) => mip === undefined ? texture.createView() : texture.createView({ baseMipLevel: mip, mipLevelCount: 1 });
		const common: Record<number, GPUBindingResource> = {
			[B.constants]: { buffer: this.constants }, [B.frame]: { buffer: input.frame }, [B.accum]: { buffer: input.accumulation },
			[B.motion]: { buffer: input.motion }, [B.color]: { buffer: input.color }, [B.rayList]: { buffer: this.rayList! },
			[B.tileList]: { buffer: this.tileList! }, [B.rayCounter]: { buffer: this.rayCounter }, [B.indirectArgs]: { buffer: this.indirectArgs },
			[B.output]: { buffer: this.output! }, [B.sceneColorHistory]: view(this.sceneColor![(this.frameIndex + 1) & 1]),
			[B.sceneColorOut]: view(this.sceneColor![this.frameIndex & 1]),
			[B.radianceCacheConstants]: { buffer: (input.radianceCache ?? this.noRadianceCache).constants }, [B.radianceCacheProbes]: { buffer: (input.radianceCache ?? this.noRadianceCache).probes }, [B.linearSampler]: this.linear, [B.environmentSampler]: this.environmentSampler,
			[B.depthHierarchy]: view(t.depth), [B.normal]: view(t.normal), [B.extractedRoughness]: view(t.extractedRoughness),
			[B.sobol]: view(this.sobol), [B.scrambling]: view(this.scrambling), [B.blueNoise]: view(this.blueNoise),
			[B.reprojectedRadiance]: view(t.reprojectedRadiance), [B.depthHistory]: view(t.depthHistory), [B.normalHistory]: view(t.normalHistory),
			[B.roughnessHistory]: view(t.roughnessHistory), [B.environment]: view(env.texture), [B.brdfLut]: view(this.brdf),
			[B.rwExtractedRoughness]: view(t.extractedRoughness), [B.rwBlueNoise]: view(this.blueNoise), [B.rwReprojectedRadiance]: view(t.reprojectedRadiance),
		};
		const groups2d = [Math.ceil(input.width / 8), Math.ceil(input.height / 8)] as const;
		const pass = encoder.beginComputePass({ label: 'sssr' });
		const run = (name: Pass, resources: Record<number, GPUBindingResource>, dispatch: readonly [number, number] | number) => {
			const p = this.pipelines[name];
			const all = { ...common, ...resources };
			pass.setPipeline(p.pipeline);
			pass.setBindGroup(0, this.device.createBindGroup({ label: `sssr.${name}`, layout: p.layout, entries: p.declarations.map(d => {
				const resource = all[d.binding];
				if (!resource) throw new Error(`SSSR ${name}: nothing bound at ${d.binding}`);
				return { binding: d.binding, resource };
			}) }));
			if (typeof dispatch === 'number') pass.dispatchWorkgroupsIndirect(this.indirectArgs, dispatch);
			else pass.dispatchWorkgroups(...dispatch);
		};

		// Inputs: depth hierarchy mip 0 and normals, then the closest-depth mips.
		run('Prepare', { [B.outDepth]: view(t.depth, 0), [B.outNormal]: view(t.normal) }, groups2d);
		for (let mip = 1; mip < t.depth.mipLevelCount; mip++) {
			const w = Math.max(1, input.width >> mip), h = Math.max(1, input.height >> mip);
			run('Downsample', { [B.source]: view(t.depth, mip - 1), [B.outDepth]: view(t.depth, mip) }, [Math.ceil(w / 8), Math.ceil(h / 8)]);
		}

		// ffx_sssr.cpp sssrDispatch: ping-pong by frame parity.
		const odd = (this.frameIndex & 1) !== 0;
		const [radianceA, radianceB] = odd ? [t.radiance[0], t.radiance[1]] : [t.radiance[1], t.radiance[0]];
		const [varianceA, varianceB] = odd ? [t.variance[0], t.variance[1]] : [t.variance[1], t.variance[0]];
		run('ClassifyTiles', { [B.variance]: view(varianceB), [B.rwRadiance]: view(radianceA) }, groups2d);
		run('PrepareBlueNoise', {}, [128 / 8, 128 / 8]);
		run('PrepareIndirectArgs', {}, [1, 1]);
		run('Intersect', { [B.rwRadiance]: view(radianceA) }, 0);

		// ffx_denoiser.cpp denoiserDispatchReflections: radiance 0/1 = SSSR radiance A/B, variance 0/1 = A/B.
		const raw = input.debug === 4;
		const [sampleCountSrv, sampleCountUav] = odd ? [t.sampleCount[1], t.sampleCount[0]] : [t.sampleCount[0], t.sampleCount[1]];
		const [averageSrv, averageUav] = odd ? [t.averageRadiance[1], t.averageRadiance[0]] : [t.averageRadiance[0], t.averageRadiance[1]];
		if (!raw) run('Reproject', {
			[B.radiance]: view(radianceA), [B.radianceHistory]: view(radianceB), [B.variance]: view(varianceB), [B.sampleCount]: view(sampleCountSrv),
			[B.rwVariance]: view(varianceA), [B.rwSampleCount]: view(sampleCountUav), [B.rwAverageRadiance]: view(averageUav),
		}, 12);
		if (!raw) run('Prefilter', {
			[B.radiance]: view(radianceA), [B.variance]: view(varianceA), [B.averageRadiance]: view(averageSrv),
			[B.rwRadiance]: view(radianceB), [B.rwVariance]: view(varianceB),
		}, 12);
		if (!raw) run('ResolveTemporal', {
			[B.radiance]: view(radianceB), [B.radianceHistory]: view(radianceB), [B.variance]: view(varianceB), [B.sampleCount]: view(sampleCountSrv),
			[B.averageRadiance]: view(averageSrv), [B.rwRadiance]: view(radianceA), [B.rwVariance]: view(varianceA),
		}, 12);

		// The resolved reflections (radiance A) are FidelityFX's output; Apply composites them over the color.
		run('Apply', { [B.radiance]: view(radianceA) }, groups2d);
		pass.end();

		// History for the next frame's reprojection.
		const size = [input.width, input.height] as const;
		encoder.copyTextureToTexture({ texture: t.normal }, { texture: t.normalHistory }, size);
		encoder.copyTextureToTexture({ texture: t.extractedRoughness }, { texture: t.roughnessHistory }, size);
		encoder.copyTextureToTexture({ texture: t.depth, mipLevel: 0 }, { texture: t.depthHistory }, size);
		this.previous = current;
		this.previousJitter = [...input.jitter];
		this.frameIndex++;
		this.stats = { active: true, reason: null, frames: this.stats.frames + 1, bytes: this.bytes() };
		return this.output!;
	}

	/**
	 * The previous frame's depth hierarchy, normals and linear scene color for the screen cache (docs/ScreenCache.md),
	 * valid until this frame's encode; null without history or after a resize to `width` x `height`.
	 */
	history(width: number, height: number): ScreenCacheHistory | null {
		if (this.frameIndex === 0 || !this.textures || !this.sceneColor || !this.previous || width !== this.width || height !== this.height) return null;
		return { depth: this.textures.depth, normal: this.textures.normal, color: this.sceneColor[(this.frameIndex + 1) & 1],
			previous: this.previous.viewProjection, near: SSSR_NEAR_PLANE };
	}

	/** Keeps the resources; the next frame restarts the history. */
	suspend(reason: string): void {
		if (this.stats.active || this.stats.reason !== reason) this.stats = { ...this.stats, active: false, reason, frames: 0 };
		this.reset();
	}

	reset(): void {
		if (this.width) this.release();
	}

	private resize(width: number, height: number): void {
		if (width === this.width && height === this.height && this.textures) return;
		this.release();
		const device = this.device, T = GPUTextureUsage;
		const create = (label: string, format: GPUTextureFormat, usage: number, w = width, h = height, mipLevelCount = 1) =>
			device.createTexture({ label: `sssr.${label}`, size: [w, h], format, usage, mipLevelCount });
		const work = T.TEXTURE_BINDING | T.STORAGE_BINDING, source = work | T.COPY_SRC, history = T.TEXTURE_BINDING | T.COPY_DST;
		const pair = (label: string, format: GPUTextureFormat, w = width, h = height) =>
			[create(`${label}0`, format, work, w, h), create(`${label}1`, format, work, w, h)] as [GPUTexture, GPUTexture];
		this.textures = {
			depth: create('depthHierarchy', 'r32float', source, width, height, sssrDepthMips(width, height)),
			depthHistory: create('depthHistory', 'r32float', history),
			normal: create('normal', 'rgba16float', source), normalHistory: create('normalHistory', 'rgba16float', history),
			radiance: pair('radiance', 'rgba16float'), variance: pair('variance', 'r32float'), sampleCount: pair('sampleCount', 'r32float'),
			averageRadiance: pair('averageRadiance', 'rgba16float', Math.ceil(width / 8), Math.ceil(height / 8)),
			extractedRoughness: create('extractedRoughness', 'r32float', source), roughnessHistory: create('roughnessHistory', 'r32float', history),
			reprojectedRadiance: create('reprojectedRadiance', 'rgba16float', work),
		};
		const pixels = width * height;
		this.rayList = device.createBuffer({ label: 'sssr.rayList', size: pixels * 4, usage: GPUBufferUsage.STORAGE });
		this.tileList = device.createBuffer({ label: 'sssr.denoiserTileList', size: Math.max(4, Math.ceil(width / 8) * Math.ceil(height / 8) * 4), usage: GPUBufferUsage.STORAGE });
		this.output = device.createBuffer({ label: 'sssr.output', size: pixels * 48, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC });
		this.sceneColor = [create('sceneColor0', 'rgba16float', work), create('sceneColor1', 'rgba16float', work)];
		this.width = width; this.height = height;
		this.frameIndex = 0; this.previous = null; this.previousJitter = null;
	}

	// Equirect mip chain of the environment for FidelityFX's roughness-based fallback lookups.
	private updateEnvironment(encoder: GPUCommandEncoder, source: GPUTexture, key: string): void {
		if (this.environment?.source === source && this.environment.key === key) return;
		const mips = Math.floor(Math.log2(Math.max(source.width, source.height))) + 1;
		let texture = this.environment?.texture;
		if (!texture || texture.width !== source.width || texture.height !== source.height) {
			texture?.destroy();
			texture = this.device.createTexture({ label: 'sssr.environment', size: [source.width, source.height], format: 'rgba16float', mipLevelCount: mips,
				usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.STORAGE_BINDING });
		}
		const p = this.pipelines.EnvironmentDownsample;
		const pass = encoder.beginComputePass({ label: 'sssr.environment' });
		pass.setPipeline(p.pipeline);
		for (let mip = 0; mip < mips; mip++) {
			const from = mip === 0 ? source.createView() : texture.createView({ baseMipLevel: mip - 1, mipLevelCount: 1 });
			const to = texture.createView({ baseMipLevel: mip, mipLevelCount: 1 });
			pass.setBindGroup(0, this.device.createBindGroup({ layout: p.layout, entries: p.declarations.map(d => ({ binding: d.binding, resource: d.binding === B.sourceColor ? from : to })) }));
			pass.dispatchWorkgroups(Math.ceil(Math.max(1, source.width >> mip) / 8), Math.ceil(Math.max(1, source.height >> mip) / 8));
		}
		pass.end();
		this.environment = { texture, source, key };
	}

	private bytes(): number {
		const t = this.textures;
		if (!t) return 0;
		let total = (this.rayList?.size ?? 0) + (this.tileList?.size ?? 0) + (this.output?.size ?? 0) ;
		const textures = [t.depth, t.depthHistory, t.normal, t.normalHistory, ...t.radiance, ...t.variance, ...t.sampleCount, ...t.averageRadiance,
			t.extractedRoughness, t.roughnessHistory, t.reprojectedRadiance, ...(this.sceneColor ?? []), ...(this.environment ? [this.environment.texture] : [])];
		for (const texture of textures) {
			let texels = 0;
			for (let mip = 0; mip < texture.mipLevelCount; mip++) texels += Math.max(1, texture.width >> mip) * Math.max(1, texture.height >> mip);
			total += texels * (BYTES[texture.format] ?? 16);
		}
		return total;
	}

	private release(): void {
		const t = this.textures;
		if (t) for (const texture of [t.depth, t.depthHistory, t.normal, t.normalHistory, ...t.radiance, ...t.variance, ...t.sampleCount, ...t.averageRadiance,
			t.extractedRoughness, t.roughnessHistory, t.reprojectedRadiance]) texture.destroy();
		this.rayList?.destroy(); this.tileList?.destroy(); this.output?.destroy(); this.sceneColor?.forEach(t => t.destroy());
		this.textures = null; this.rayList = null; this.tileList = null; this.output = null; this.sceneColor = null;
		this.width = 0; this.height = 0;
	}

	destroy(): void {
		this.release();
		this.environment?.texture.destroy();
		this.environment = null;
		for (const resource of [this.constants, this.rayCounter, this.indirectArgs, this.noRadianceCache.constants, this.noRadianceCache.probes]) resource.destroy();
		for (const texture of [this.brdf, this.sobol, this.scrambling, this.blueNoise]) texture.destroy();
	}
}
