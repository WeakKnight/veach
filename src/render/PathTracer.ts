// WebGPU pipelines for the megakernel path tracer (PathTracing.wgsl) and the present pass.
import pathTracingWgsl from '../generated/shaders/PathTracing.wgsl?raw';
import pathTracingEmptyWgsl from '../generated/shaders/PathTracingEmpty.wgsl?raw';
import presentWgsl from '../generated/shaders/Present.wgsl?raw';
import { createToneLUTTexture } from './aces/ToneLUT';
import { createDisplayTransformGPU, type DisplayTransformGPU } from './color/DisplayTransformGPU';
import { createBSDFTablesTexture } from './BSDFTables';
import { AutoExposure } from './AutoExposure';
import { LocalExposure } from './LocalExposure';
import type { PipelineCompiler } from './PipelineCompiler';
import { OIDNGuides } from './denoise/OIDNGuides';
import type { Environment } from './Environment';
import { ACCUM_BYTES_PER_PIXEL, FRAME_UNIFORM_BYTES } from './GpuLayout';
import type { GpuScene } from './GpuScene';
import { VT_FEEDBACK_SHIFT, type VirtualTextureSystem } from './vt/VirtualTextureSystem';
import type { Wavefront } from './Wavefront';
import { materialStackCapacity, specializeMaterialShader, type MaterialStackCapacity } from './MaterialShaderVariants';
import { ALL_MATERIAL_OPCODES, materialPipelineKey, materialPipelineConstants, type MaterialOpcodeMask } from './MaterialProgramFeatures';

const WORKGROUP_SIZE = 8;

export class PathTracer {
	readonly uniformBuffer: GPUBuffer;
	readonly autoExposure: AutoExposure;
	readonly localExposure: LocalExposure;
	readonly oidnGuides: OIDNGuides;
	private presentationBuffer: GPUBuffer | null = null;
	private readonly sceneLayout: GPUBindGroupLayout;
	private readonly accumLayout: GPUBindGroupLayout;
	private readonly presentLayout: GPUBindGroupLayout;
	private computePipeline!: GPUComputePipeline;
	private emptyPipeline!: GPUComputePipeline;
	private readonly materialPipelines = new Map<string, GPUComputePipeline>();
	private readonly materialPipelineLoading = new Map<string, Promise<GPUComputePipeline>>();
	private readonly computeLayout: GPUPipelineLayout;
	materialCapacity: MaterialStackCapacity = 1;
	// Internal experiment control; null selects the compiler-derived scene bound.
	materialStackOverride: MaterialStackCapacity | null = null;
	materialOpcodeSpecialization = false;
	materialOperandMode = 0;
	boundMaterialOperandMode = 0;
	// Internal traversal experiment; alpha-tested scenes always retain the general kernel.
	opaqueMegakernel = false;
	boundOpaqueMegakernel = false;
	materialOpcodes: MaterialOpcodeMask = ALL_MATERIAL_OPCODES;
	materialShadeCapacities: readonly MaterialStackCapacity[] = [];
	materialCount = 0;
	private presentPipeline!: GPURenderPipeline;
	readonly compiled: Promise<void>; // all pipelines (including exposure) have compiled
	private readonly sampler: GPUSampler;
	private readonly toneLUT: GPUTexture;
	private readonly toneLUTSampler: GPUSampler;
	private displayTransform: DisplayTransformGPU;
	private readonly bsdfTables: GPUTexture;

	private sceneBindGroup: GPUBindGroup | null = null;
	private hasAlphaTested = false;
	private lightCount = 0;
	private hasGeometry = false;
	private accumBindGroup: GPUBindGroup | null = null;
	private presentBindGroup: GPUBindGroup | null = null;
	private accumBuffer: GPUBuffer | null = null;
	private feedbackTexture: GPUTexture | null = null;
	private wavefront: Wavefront | null = null;
	private wavefrontLoading: Promise<Wavefront> | null = null;
	private destroyed = false;
	integrator: 'megakernel' | 'wavefront' = 'megakernel';
	width = 0;
	height = 0;

	constructor(
		private readonly device: GPUDevice,
		readonly presentFormat: GPUTextureFormat,
		bsdfTables: ArrayBuffer,
		compiler: PipelineCompiler,
	) {
		this.bsdfTables = createBSDFTablesTexture(device, bsdfTables);
		this.uniformBuffer = device.createBuffer({
			label: 'frameUniforms',
			size: FRAME_UNIFORM_BYTES,
			usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
		});
		this.sampler = device.createSampler({
			label: 'linearEnvironment',
			magFilter: 'linear',
			minFilter: 'linear',
			addressModeU: 'repeat',
			// Equirectangular poles must not blend with the opposite pole. VT samples stay
			// inside bordered physical tiles, so they do not depend on this address mode.
			addressModeV: 'clamp-to-edge',
		});
		this.autoExposure = new AutoExposure(device, compiler);
		this.localExposure = new LocalExposure(device, compiler);
		this.oidnGuides = new OIDNGuides(device, compiler);
		this.toneLUT = createToneLUTTexture(device);
		this.displayTransform = createDisplayTransformGPU(device, null);
		this.toneLUTSampler = device.createSampler({ label: 'toneLUT', magFilter: 'linear', minFilter: 'linear' });

		const C = GPUShaderStage.COMPUTE;
		const storage = (binding: number): GPUBindGroupLayoutEntry => ({ binding, visibility: C, buffer: { type: 'read-only-storage' } });
		this.sceneLayout = device.createBindGroupLayout({
			label: 'scene',
			entries: [
				{ binding: 0, visibility: C, buffer: { type: 'uniform' } },
				storage(1),
				storage(2),
				storage(3),
				storage(4),
				storage(5),
				storage(6),
				storage(7),
				{ binding: 8, visibility: C, sampler: { type: 'filtering' } },
				{ binding: 9, visibility: C, texture: { sampleType: 'float' } },
				{ binding: 10, visibility: C, texture: { sampleType: 'unfilterable-float' } },
				{ binding: 11, visibility: C, texture: { sampleType: 'float' } },
				{ binding: 12, visibility: C, texture: { sampleType: 'uint' } },
				{ binding: 13, visibility: C, texture: { sampleType: 'unfilterable-float', viewDimension: '3d' } },
			],
		});
		this.accumLayout = device.createBindGroupLayout({
			label: 'accum',
			entries: [
				{ binding: 0, visibility: C, buffer: { type: 'storage' } },
				{ binding: 1, visibility: C, storageTexture: { access: 'write-only', format: 'r32uint' } },
			],
		});
		this.presentLayout = device.createBindGroupLayout({
			label: 'present',
			entries: [
				{ binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: 'uniform' } },
				{ binding: 1, visibility: GPUShaderStage.FRAGMENT, buffer: { type: 'read-only-storage' } },
				{ binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: 'float', viewDimension: '3d' } },
				{ binding: 3, visibility: GPUShaderStage.FRAGMENT, sampler: { type: 'filtering' } },
				{ binding: 4, visibility: GPUShaderStage.FRAGMENT, buffer: { type: 'read-only-storage' } },
				{ binding: 5, visibility: GPUShaderStage.FRAGMENT, buffer: { type: 'uniform' } },
				{ binding: 6, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: 'unfilterable-float' } },
				{ binding: 7, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: 'unfilterable-float' } },
				{ binding: 8, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: 'unfilterable-float' } },
				{ binding: 9, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: 'unfilterable-float' } },
				{ binding: 10, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: 'unfilterable-float', viewDimension: '3d' } },
				{ binding: 11, visibility: GPUShaderStage.FRAGMENT, buffer: { type: 'uniform' } },
			],
		});

		// Empty scenes only need camera, environment and visible analytic lights. Compile
		// material/traversal pipelines after the incoming scene establishes its stack bound.
		const ptModule = device.createShaderModule({ label: 'PathTracingEmpty', code: pathTracingEmptyWgsl });
		this.computeLayout = device.createPipelineLayout({ bindGroupLayouts: [this.sceneLayout, this.accumLayout] });
		const computePipeline = compiler.compute(
			{
				label: 'pathTracing.empty',
				layout: this.computeLayout,
				compute: { module: ptModule, entryPoint: 'main' },
			},
			1,
		);
		const presentModule = device.createShaderModule({ label: 'Present', code: presentWgsl });
		const presentPipeline = compiler.render({
			label: 'present',
			layout: device.createPipelineLayout({ bindGroupLayouts: [this.presentLayout] }),
			vertex: { module: presentModule, entryPoint: 'vsMain' },
			fragment: { module: presentModule, entryPoint: 'fsMain', targets: [{ format: presentFormat }] },
			primitive: { topology: 'triangle-list' },
		});
		this.compiled = Promise.all([computePipeline, presentPipeline, this.autoExposure.compiled, this.localExposure.compiled, this.oidnGuides.compiled]).then(([compute, present]) => {
			this.computePipeline = compute;
			this.emptyPipeline = compute;
			this.presentPipeline = present;
		});
		void this.reportShaderErrors(ptModule, 'PathTracingEmpty');
		void this.reportShaderErrors(presentModule, 'Present');
	}

	private async reportShaderErrors(module: GPUShaderModule, name: string): Promise<void> {
		const info = await module.getCompilationInfo();
		for (const m of info.messages) {
			if (m.type === 'error') {
				console.error(`${name}.wgsl:${m.lineNum}:${m.linePos} ${m.message}`);
			}
		}
	}

	private sceneCapacity(scene: GpuScene): MaterialStackCapacity {
		const capacity = this.materialStackOverride ?? materialStackCapacity(scene.materialStackSize);
		if (capacity < scene.materialStackSize) throw new Error(`Scene needs ${scene.materialStackSize} material stack slots; selected capacity is ${capacity}`);
		return capacity;
	}

	private sceneOpcodes(scene: GpuScene): MaterialOpcodeMask {
		return this.materialOpcodeSpecialization ? scene.materialOpcodes : ALL_MATERIAL_OPCODES;
	}

	private sceneOpaque(scene: GpuScene): boolean {
		return this.opaqueMegakernel && scene.instanceCount > 0 && !scene.hasAlphaTested;
	}

	private async prepareMaterialPipeline(capacity: MaterialStackCapacity, opcodes: MaterialOpcodeMask, operandMode: number, opaque = false): Promise<GPUComputePipeline> {
		if (this.destroyed) throw new Error('Path tracer has been destroyed');
		const key = `${materialPipelineKey(capacity, opcodes, operandMode)}/${Number(opaque)}`;
		const existing = this.materialPipelines.get(key);
		if (existing) return existing;
		let pending = this.materialPipelineLoading.get(key);
		if (!pending) {
			pending = (async () => {
				const code = opaque ? (await import('./OpaqueMaterialShader')).opaqueMaterialShader(capacity)
					: specializeMaterialShader(pathTracingWgsl, 'PathTracing', capacity);
				if (this.destroyed) throw new Error('Path tracer has been destroyed');
				const module = this.device.createShaderModule({ label: opaque ? 'PathTracingOpaque' : 'PathTracing', code });
				return this.device.createComputePipelineAsync({ label: `pathTracing.${opaque ? 'opaque.' : ''}stack${capacity}`, layout: this.computeLayout, compute: { module, entryPoint: 'main', constants: materialPipelineConstants(capacity, opcodes, operandMode) } });
			})().then(pipeline => {
				if (this.destroyed) throw new Error('Path tracer has been destroyed');
				this.materialPipelines.set(key, pipeline);
				return pipeline;
			}).catch(error => {
				this.materialPipelineLoading.delete(key);
				throw error;
			});
			this.materialPipelineLoading.set(key, pending);
		}
		return pending;
	}

	// Prepare without changing the currently bound scene/pipeline while compilation is pending.
	async prepareScene(scene: GpuScene): Promise<void> {
		if (this.destroyed) throw new Error('Path tracer has been destroyed');
		const capacity = this.sceneCapacity(scene);
		const opcodes = this.sceneOpcodes(scene);
		const operandMode = this.materialOperandMode;
		const opaque = this.sceneOpaque(scene);
		await Promise.all([this.useEmptyPipeline(scene) ? this.compiled : this.prepareMaterialPipeline(capacity, opcodes, operandMode, opaque),
			this.integrator === 'wavefront' && scene.instanceCount > 0 ? this.prepareWavefront(capacity, opcodes, operandMode, scene.materialShadeCapacities) : Promise.resolve()]);
		if (this.destroyed) throw new Error('Path tracer has been destroyed');
	}

	private useEmptyPipeline(scene: GpuScene): boolean {
		return scene.instanceCount === 0 && this.materialStackOverride === null;
	}

	setScene(scene: GpuScene, environment: Environment, vt: VirtualTextureSystem): void {
		this.materialCapacity = this.sceneCapacity(scene);
		this.materialOpcodes = this.sceneOpcodes(scene);
		this.materialShadeCapacities = scene.materialShadeCapacities;
		this.materialCount = scene.materialCount;
		this.boundMaterialOperandMode = this.materialOperandMode;
		this.boundOpaqueMegakernel = this.sceneOpaque(scene);
		const pipeline = this.useEmptyPipeline(scene) ? this.emptyPipeline : this.materialPipelines.get(`${materialPipelineKey(this.materialCapacity, this.materialOpcodes, this.boundMaterialOperandMode)}/${Number(this.boundOpaqueMegakernel)}`);
		if (!pipeline) throw new Error('Material pipeline must be prepared before binding a scene');
		this.computePipeline = pipeline;
		this.hasAlphaTested = scene.hasAlphaTested;
		this.lightCount = scene.lightCount;
		this.hasGeometry = scene.instanceCount > 0;
		this.sceneBindGroup = this.device.createBindGroup({
			label: 'scene',
			layout: this.sceneLayout,
			entries: [
				{ binding: 0, resource: { buffer: this.uniformBuffer } },
				{ binding: 1, resource: { buffer: scene.nodes } },
				{ binding: 2, resource: { buffer: scene.tris } },
				{ binding: 3, resource: { buffer: scene.instances } },
				{ binding: 4, resource: { buffer: scene.vertices } },
				{ binding: 5, resource: { buffer: scene.indices } },
				{ binding: 6, resource: { buffer: scene.materials } },
				{ binding: 7, resource: { buffer: scene.lights } },
				{ binding: 8, resource: this.sampler },
				{ binding: 9, resource: environment.view() },
				{ binding: 10, resource: environment.cdfView() },
				{ binding: 11, resource: vt.physical.createView() },
				{ binding: 12, resource: vt.pageTable.createView() },
				{ binding: 13, resource: this.bsdfTables.createView() },
			],
		});
		// Geometry changes can add/remove wavefront scratch even at the same resolution.
		if (this.accumBuffer) this.resize(this.width, this.height);
	}

	resize(width: number, height: number): void {
		width = Math.max(1, Math.floor(width));
		height = Math.max(1, Math.floor(height));
		const size = width * height * ACCUM_BYTES_PER_PIXEL + (this.integrator === 'wavefront' && this.hasGeometry ? this.wavefront!.storageBytes(width * height) : 0);
		if (width === this.width && height === this.height && this.accumBuffer?.size === size) {
			return;
		}
		this.width = width;
		this.height = height;
		this.presentationBuffer = null;
		this.accumBuffer?.destroy();
		this.accumBuffer = this.device.createBuffer({
			label: 'accumulation',
			size,
			usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST,
		});
		this.feedbackTexture?.destroy();
		this.feedbackTexture = this.device.createTexture({
			label: 'vtFeedback',
			size: [Math.ceil(width / (1 << VT_FEEDBACK_SHIFT)), Math.ceil(height / (1 << VT_FEEDBACK_SHIFT))],
			format: 'r32uint',
			usage: GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.COPY_SRC,
		});
		this.accumBindGroup = this.device.createBindGroup({
			label: 'accum',
			layout: this.accumLayout,
			entries: [
				{ binding: 0, resource: { buffer: this.accumBuffer } },
				{ binding: 1, resource: this.feedbackTexture.createView() },
			],
		});
		this.wavefront?.bind(this.accumBuffer, this.feedbackTexture);
		this.localExposure.resize(this.uniformBuffer, this.accumBuffer, this.autoExposure.exposureBuffer, width, height);
		this.rebuildPresentBindGroup();
		this.autoExposure.bind(this.uniformBuffer, this.accumBuffer);
	}

	setDisplayTransform(resources: DisplayTransformGPU): void {
		const previous = this.displayTransform;
		this.displayTransform = resources;
		this.rebuildPresentBindGroup();
		previous.destroy();
	}

	/** Switch every presentation pass together; the progressive accumulation remains untouched. */
	setPresentationBuffer(buffer: GPUBuffer | null): void {
		if (this.presentationBuffer === buffer) return;
		this.presentationBuffer = buffer;
		const source = buffer ?? this.accumBuffer;
		if (!source) return;
		this.localExposure.resize(this.uniformBuffer, source, this.autoExposure.exposureBuffer, this.width, this.height);
		this.autoExposure.bind(this.uniformBuffer, source);
		this.rebuildPresentBindGroup();
	}

	get presentation(): GPUBuffer | null { return this.presentationBuffer ?? this.accumBuffer; }

	private rebuildPresentBindGroup(): void {
		if (!this.accumBuffer) return;
		const localExposure = this.localExposure.presentViews;
		this.presentBindGroup = this.device.createBindGroup({
			label: 'present',
			layout: this.presentLayout,
			entries: [
				{ binding: 0, resource: { buffer: this.uniformBuffer } },
				{ binding: 1, resource: { buffer: this.presentation! } },
				{ binding: 2, resource: this.toneLUT.createView() },
				{ binding: 3, resource: this.toneLUTSampler },
				{ binding: 4, resource: { buffer: this.autoExposure.exposureBuffer } },
				{ binding: 5, resource: { buffer: this.localExposure.paramsBuffer } },
				{ binding: 6, resource: localExposure.residual },
				{ binding: 7, resource: localExposure.pyramid },
				{ binding: 8, resource: this.localExposure.forwardLut.createView() },
				{ binding: 9, resource: this.localExposure.inverseLut.createView() },
				{ binding: 10, resource: this.displayTransform.texture.createView() },
				{ binding: 11, resource: { buffer: this.displayTransform.uniforms } },
			],
		});
	}

	get ready(): boolean {
		return !!this.sceneBindGroup && !!this.accumBindGroup;
	}

	get accumulation(): GPUBuffer | null {
		return this.accumBuffer;
	}

	get feedback(): GPUTexture | null {
		return this.feedbackTexture;
	}

	private async prepareWavefront(capacity: MaterialStackCapacity, opcodes: MaterialOpcodeMask, operandMode: number, shadeCapacities: readonly MaterialStackCapacity[] = []): Promise<void> {
		if (this.destroyed) throw new Error('Path tracer has been destroyed');
		this.wavefrontLoading ??= import('./Wavefront').then(async ({ Wavefront }) => {
			if (this.destroyed) throw new Error('Path tracer has been destroyed');
			const wavefront = new Wavefront(this.device, this.sceneLayout, capacity, opcodes, operandMode);
			try {
				await wavefront.compiled;
				if (this.destroyed) throw new Error('Path tracer has been destroyed');
				return wavefront;
			} catch (error) {
				wavefront.destroy();
				throw error;
			}
		}).catch(error => {
			this.wavefrontLoading = null;
			throw error;
		});
		const wavefront = await this.wavefrontLoading;
		if (this.destroyed) {
			// Compilation can finish before destroy(), yet reach this await afterward.
			// Cached instances are already owned/disposed by this tracer; new ones are not.
			if (wavefront !== this.wavefront) wavefront.destroy();
			throw new Error('Path tracer has been destroyed');
		}
		this.wavefront = wavefront;
		await wavefront.prepareStack(capacity, opcodes, operandMode);
		if (wavefront.shadeBuckets) await wavefront.prepareBuckets(shadeCapacities, capacity, opcodes, operandMode);
		if (this.destroyed) throw new Error('Path tracer has been destroyed');
	}

	async setIntegrator(mode: 'megakernel' | 'wavefront'): Promise<void> {
		if (this.destroyed) throw new Error('Path tracer has been destroyed');
		if (mode === this.integrator) return;
		if (mode === 'wavefront' && this.hasGeometry) await this.prepareWavefront(this.materialCapacity, this.materialOpcodes, this.boundMaterialOperandMode, this.materialShadeCapacities);
		if (this.destroyed) throw new Error('Path tracer has been destroyed');
		this.integrator = mode;
		const width = this.width, height = this.height;
		this.width = 0;
		this.resize(width, height);
	}

	encodeTrace(encoder: GPUCommandEncoder, maxBounces = 8, debugMode = 0): void {
		if (!this.sceneBindGroup || !this.accumBindGroup) {
			return;
		}
		if (this.integrator === 'wavefront' && this.hasGeometry && debugMode === 0) {
			this.wavefront!.encode(encoder, this.sceneBindGroup, this.width, this.height, maxBounces, this.hasAlphaTested, this.materialCapacity, this.lightCount, this.materialOpcodes, this.boundMaterialOperandMode, this.materialShadeCapacities, this.materialCount);
			return;
		}
		const pass = encoder.beginComputePass({ label: 'pathTracing' });
		pass.setPipeline(this.computePipeline);
		pass.setBindGroup(0, this.sceneBindGroup);
		pass.setBindGroup(1, this.accumBindGroup);
		pass.dispatchWorkgroups(Math.ceil(this.width / WORKGROUP_SIZE), Math.ceil(this.height / WORKGROUP_SIZE));
		pass.end();
	}

	encodePresent(encoder: GPUCommandEncoder, target: GPUTextureView): void {
		if (!this.presentBindGroup) {
			return;
		}
		const pass = encoder.beginRenderPass({
			label: 'present',
			colorAttachments: [{ view: target, loadOp: 'clear', storeOp: 'store', clearValue: [0, 0, 0, 1] }],
		});
		pass.setPipeline(this.presentPipeline);
		pass.setBindGroup(0, this.presentBindGroup);
		pass.draw(3);
		pass.end();
	}

	destroy(): void {
		if (this.destroyed) return;
		this.destroyed = true;
		this.materialPipelines.clear();
		this.materialPipelineLoading.clear();
		this.wavefront?.destroy();
		this.uniformBuffer.destroy();
		this.accumBuffer?.destroy();
		this.feedbackTexture?.destroy();
		this.toneLUT.destroy();
		this.displayTransform.destroy();
		this.bsdfTables.destroy();
		this.autoExposure.destroy();
		this.localExposure.destroy();
	}
}
