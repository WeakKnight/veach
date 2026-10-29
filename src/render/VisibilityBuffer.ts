import cullCode from '../generated/shaders/VisibilityCull.wgsl?raw';
import rasterCode from '../generated/shaders/VisibilityRaster.wgsl?raw';
import type { GpuScene } from './GpuScene';

/** One geometry draw per sample; all persistent geometry stays in existing scene buffers. */
export class VisibilityBuffer {
	readonly compiled: Promise<void>;
	private readonly sceneLayout: GPUBindGroupLayout;
	private readonly cullLayout: GPUBindGroupLayout;
	private readonly drawLayout: GPUBindGroupLayout;
	private cull!: GPUComputePipeline;
	private args!: GPUComputePipeline;
	private near!: GPUComputePipeline;
	private raster!: GPURenderPipeline;
	texture: GPUTexture | null = null;
	private depth: GPUTexture | null = null;
	private sceneGroup: GPUBindGroup | null = null;
	private cullGroup: GPUBindGroup | null = null;
	private drawGroup: GPUBindGroup | null = null;
	private accumulation: GPUBuffer | null = null;
	private scene: GpuScene | null = null;
	scratchOffset = 0;
	private dimensions = '';
	private destroyed = false;

	static scratchBytes(clusters: number): number { return 64 + Math.ceil(clusters * 2 / 4) * 16; }

	constructor(private readonly device: GPUDevice) {
		const CV = GPUShaderStage.COMPUTE | GPUShaderStage.VERTEX;
		this.sceneLayout = device.createBindGroupLayout({ label: 'visibilityScene', entries: [
			{ binding: 0, visibility: CV, buffer: { type: 'uniform' } },
			...[3, 4, 5].map(binding => ({ binding, visibility: CV, buffer: { type: 'read-only-storage' as const } })),
		] });
		this.cullLayout = device.createBindGroupLayout({ entries: [{ binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'storage' } }] });
		this.drawLayout = device.createBindGroupLayout({ entries: [{ binding: 0, visibility: GPUShaderStage.VERTEX, buffer: { type: 'read-only-storage' } }] });
		const computeLayout = device.createPipelineLayout({ bindGroupLayouts: [this.sceneLayout, this.cullLayout] });
		const module = device.createShaderModule({ label: 'VisibilityCull', code: cullCode });
		const drawModule = device.createShaderModule({ label: 'VisibilityRaster', code: rasterCode });
		this.compiled = Promise.all([
			device.createComputePipelineAsync({ label: 'visibility.cull', layout: computeLayout, compute: { module, entryPoint: 'Cull' } }),
			device.createComputePipelineAsync({ label: 'visibility.arguments', layout: computeLayout, compute: { module, entryPoint: 'DrawArguments' } }),
			device.createComputePipelineAsync({ label: 'visibility.near', layout: computeLayout, compute: { module, entryPoint: 'CheckNear' } }),
			device.createRenderPipelineAsync({ label: 'visibility.raster', layout: device.createPipelineLayout({ bindGroupLayouts: [this.sceneLayout, this.drawLayout] }),
				vertex: { module: drawModule, entryPoint: 'vsMain' }, fragment: { module: drawModule, entryPoint: 'fsMain', targets: [{ format: 'rg32uint' }] },
				primitive: { topology: 'triangle-list', cullMode: 'none' }, depthStencil: { format: 'depth32float', depthWriteEnabled: true, depthCompare: 'greater' } }),
		]).then(([cull, args, near, raster]) => { this.cull = cull; this.args = args; this.near = near; this.raster = raster; });
	}

	bind(scene: GpuScene, frame: GPUBuffer, accumulation: GPUBuffer, width: number, height: number, scratchOffset: number): void {
		if (this.destroyed) throw new Error('Visibility buffer has been destroyed');
		this.scene = scene; this.accumulation = accumulation; this.scratchOffset = scratchOffset;
		const dimensions = `${width}/${height}`;
		if (dimensions !== this.dimensions) {
			this.texture?.destroy(); this.depth?.destroy();
			this.texture = this.device.createTexture({ label: 'primaryVisibility', size: [width, height], format: 'rg32uint', usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_SRC });
			this.depth = this.device.createTexture({ label: 'primaryDepth', size: [width, height], format: 'depth32float', usage: GPUTextureUsage.RENDER_ATTACHMENT });
			this.dimensions = dimensions;
		}
		this.sceneGroup = this.device.createBindGroup({ layout: this.sceneLayout, entries: [
			{ binding: 0, resource: { buffer: frame } }, { binding: 3, resource: { buffer: scene.instances } },
			{ binding: 4, resource: { buffer: scene.vertices } }, { binding: 5, resource: { buffer: scene.indices } },
		] });
		this.cullGroup = this.device.createBindGroup({ layout: this.cullLayout, entries: [{ binding: 0, resource: { buffer: accumulation } }] });
		this.drawGroup = this.device.createBindGroup({ layout: this.drawLayout, entries: [{ binding: 0, resource: { buffer: accumulation } }] });
	}

	encode(encoder: GPUCommandEncoder, indirect: GPUBuffer): void {
		if (!this.scene || !this.accumulation) throw new Error('Visibility buffer is unbound');
		encoder.clearBuffer(this.accumulation, this.scratchOffset, 64);
		for (const [label, pipeline, groups] of [['cull', this.cull, Math.ceil(this.scene.visibilityCount / 64)], ['arguments', this.args, 1]] as const) {
			const pass = encoder.beginComputePass({ label: `visibility.${label}` });
			pass.setPipeline(pipeline); pass.setBindGroup(0, this.sceneGroup!); pass.setBindGroup(1, this.cullGroup!);
			pass.dispatchWorkgroups(Math.min(groups, 65535), Math.ceil(groups / 65535)); pass.end();
		}
		encoder.copyBufferToBuffer(this.accumulation, this.scratchOffset + 16, indirect, 144, 16);
		encoder.copyBufferToBuffer(this.accumulation, this.scratchOffset + 48, indirect, 160, 16);
		const nearPass = encoder.beginComputePass({ label: 'visibility.near' });
		nearPass.setPipeline(this.near); nearPass.setBindGroup(0, this.sceneGroup!); nearPass.setBindGroup(1, this.cullGroup!);
		nearPass.dispatchWorkgroupsIndirect(indirect, 160); nearPass.end();
		const pass = encoder.beginRenderPass({ label: 'visibility.raster', colorAttachments: [
			{ view: this.texture!.createView(), loadOp: 'clear', storeOp: 'store', clearValue: [0xffffffff, 0xffffffff, 0, 0] },
		], depthStencilAttachment: { view: this.depth!.createView(), depthLoadOp: 'clear', depthStoreOp: 'discard', depthClearValue: 0 } });
		pass.setPipeline(this.raster); pass.setBindGroup(0, this.sceneGroup!); pass.setBindGroup(1, this.drawGroup!);
		pass.drawIndirect(indirect, 144); pass.end();
	}

	/** Explicit diagnostic readback; normal rendering never waits for counters. */
	async readCounters(): Promise<{ visibleClusters: number; vertexSlots: number; usefulVertexSlots: number; paddingVertexSlots: number; numericalFallbackPixels: number; sparseFallbackPixels: number; fallbackPixels: number; alphaFallbackPixels: number; nearClipFallback: boolean }> {
		if (!this.accumulation || this.destroyed) throw new Error('Visibility buffer is unbound');
		const counts = this.scene!.visibilityTriangleCounts, bytes = VisibilityBuffer.scratchBytes(counts.length);
		const readback = this.device.createBuffer({ size: bytes, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
		try {
			const encoder = this.device.createCommandEncoder(); encoder.copyBufferToBuffer(this.accumulation, this.scratchOffset, readback, 0, bytes);
			this.device.queue.submit([encoder.finish()]); await readback.mapAsync(GPUMapMode.READ);
			const words = new Uint32Array(readback.getMappedRange());
			let triangles = 0;
			for (let i = 0; i < words[0]; i++) triangles += counts[words[16 + i]];
			return { sparseFallbackPixels: words[3], usefulVertexSlots: triangles * 3, paddingVertexSlots: words[0] * 192 - triangles * 3, numericalFallbackPixels: words[1] ? 0 : words[8] - words[9], visibleClusters: words[0], vertexSlots: words[0] * 192, nearClipFallback: words[1] !== 0, fallbackPixels: words[8], alphaFallbackPixels: words[9] };
		} finally { readback.destroy(); }
	}

	release(): void {
		this.dimensions = ''; this.texture?.destroy(); this.depth?.destroy();
		this.texture = null; this.depth = null; this.accumulation = null; this.scene = null;
		this.sceneGroup = null; this.cullGroup = null; this.drawGroup = null;
	}

	destroy(): void { this.release(); this.destroyed = true; }
}
