import code from '../generated/shaders/SharcMaintenance.wgsl?raw';

export interface SharcSettings {
	/** Zero derives the finest voxel size from the scene bounds. */
	voxelSize: number;
	capacity: number;
	roughnessThreshold: number;
	minSamples: number;
	historyFrames: number;
	maxAge: number;
}
export const defaultSharcSettings: Readonly<SharcSettings> = Object.freeze({ voxelSize: 0, capacity: 65536, roughnessThreshold: 0.5, minSamples: 4, historyFrames: 16, maxAge: 64 });
export interface SharcStats {
	enabled: boolean;
	active: boolean;
	reason: string | null;
	bytes: number;
	voxelSize: number;
	epoch: number;
	paths?: number;
	tracedSegments?: number;
	averageSegments?: number;
	cacheHits?: number;
	queries?: number;
	updatePaths?: number;
	updateRecords?: number;
	acceptedUpdates?: number;
	occupiedCells?: number;
	collisions?: number;
}

export function sharcSettings(options: Partial<SharcSettings>, previous: Readonly<SharcSettings> = defaultSharcSettings): SharcSettings {
	const value = { ...previous, ...options };
	if (!Number.isFinite(value.voxelSize) || value.voxelSize < 0) throw new Error('SHARC voxelSize must be finite and nonnegative');
	if (!Number.isInteger(value.capacity) || value.capacity < 4096 || value.capacity > 262144 || (value.capacity & (value.capacity - 1))) throw new Error('SHARC capacity must be a power of two from 4096 to 262144');
	if (!Number.isFinite(value.roughnessThreshold) || value.roughnessThreshold < 0.3 || value.roughnessThreshold > 1) throw new Error('SHARC roughnessThreshold must be in [0.3, 1]');
	for (const [key, max] of [['minSamples', 512], ['historyFrames', 64], ['maxAge', 1024]] as const)
		if (!Number.isInteger(value[key]) || value[key] < 1 || value[key] > max) throw new Error(`Invalid SHARC ${key}`);
	return value;
}

/** Cache cells and sparse path records share the existing accumulation buffer. */
export class SharcCache {
	readonly compiled: Promise<void>;
	private readonly sceneLayout: GPUBindGroupLayout;
	private readonly workLayout: GPUBindGroupLayout;
	private readonly pipelines = new Map<string, GPUComputePipeline>();
	private frameGroup: GPUBindGroup | null = null;
	private workGroup: GPUBindGroup | null = null;
	private buffer: GPUBuffer | null = null;
	private parameters: GPUBuffer | null = null;
	private dirty = true;
	epoch = 0;
	cacheOffset = 0;
	recordOffset = 0;
	recordCount = 0;
	static cacheBytes(capacity: number): number { return 64 + capacity * 64; }
	static recordBytes(paths: number): number { return Math.ceil(paths / 16) * 4 * 64; }

	constructor(private readonly device: GPUDevice, compiler?: import('./PipelineCompiler').PipelineCompiler) {
		this.sceneLayout = device.createBindGroupLayout({ entries: [{ binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'uniform' } }] });
		this.workLayout = device.createBindGroupLayout({ entries: [
			{ binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'storage' } },
			{ binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'uniform', hasDynamicOffset: true, minBindingSize: 32 } },
		] });
		const layout = device.createPipelineLayout({ bindGroupLayouts: [this.sceneLayout, this.workLayout] });
		const module = device.createShaderModule({ label: 'SharcMaintenance', code });
		this.compiled = Promise.all(['Accumulate', 'Publish', 'Resolve', 'Statistics'].map(async entryPoint => {
			const descriptor: GPUComputePipelineDescriptor = { label: `sharc.${entryPoint}`, layout, compute: { module, entryPoint } };
			this.pipelines.set(entryPoint, await (compiler ? compiler.compute(descriptor) : device.createComputePipelineAsync(descriptor)));
		})).then(() => {});
	}

	invalidate(): void { this.dirty = true; this.epoch = 0; }
	bind(buffer: GPUBuffer, frame: GPUBuffer, cacheOffset: number, cells: number, paths: number): void {
		if (this.buffer !== buffer || this.cacheOffset !== cacheOffset || this.recordOffset !== cacheOffset + SharcCache.cacheBytes(cells)) this.invalidate();
		this.buffer = buffer; this.cacheOffset = cacheOffset;
		this.recordOffset = cacheOffset + SharcCache.cacheBytes(cells); this.recordCount = Math.ceil(paths / 16) * 4;
		this.frameGroup = this.device.createBindGroup({ layout: this.sceneLayout, entries: [{ binding: 0, resource: { buffer: frame } }] });
		this.parameters = null; this.workGroup = null;
	}
	frame(): number { if (this.epoch === 0xffffffff) this.invalidate(); return ++this.epoch; }
	beginSample(encoder: GPUCommandEncoder): void {
		encoder.clearBuffer(this.buffer!, this.cacheOffset, this.dirty ? this.recordOffset - this.cacheOffset : 64);
		this.dirty = false;
	}
	beginTile(encoder: GPUCommandEncoder): void { encoder.clearBuffer(this.buffer!, this.recordOffset, this.recordCount * 64); }
	private dispatch(encoder: GPUCommandEncoder, entry: string, groups: number, offset: number): void {
		const pass = encoder.beginComputePass({ label: `sharc.${entry}` });
		pass.setPipeline(this.pipelines.get(entry)!); pass.setBindGroup(0, this.frameGroup!); pass.setBindGroup(1, this.workGroup!, [offset]);
		pass.dispatchWorkgroups(groups); pass.end();
	}
	finishTile(encoder: GPUCommandEncoder, parameters: GPUBuffer, offset: number, paths: number): void {
		if (parameters !== this.parameters) {
			this.parameters = parameters;
			this.workGroup = this.device.createBindGroup({ layout: this.workLayout, entries: [
				{ binding: 0, resource: { buffer: this.buffer! } }, { binding: 2, resource: { buffer: parameters, size: 32 } },
			] });
		}
		this.dispatch(encoder, 'Statistics', Math.ceil(paths / 64), offset);
		this.dispatch(encoder, 'Accumulate', Math.ceil(this.recordCount / 64), offset);
		this.dispatch(encoder, 'Publish', Math.ceil(this.recordCount / 64), offset);
	}
	resolve(encoder: GPUCommandEncoder, cells: number): void { this.dispatch(encoder, 'Resolve', Math.ceil(cells / 64), 0); }
	async readStats(): Promise<Partial<SharcStats>> {
		if (!this.buffer) return {};
		const readback = this.device.createBuffer({ size: 64, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST });
		try {
			const encoder = this.device.createCommandEncoder(); encoder.copyBufferToBuffer(this.buffer, this.cacheOffset, readback, 0, 64);
			this.device.queue.submit([encoder.finish()]); await readback.mapAsync(GPUMapMode.READ);
			const s = new Uint32Array(readback.getMappedRange());
			return { paths: s[0], tracedSegments: s[1], averageSegments: s[0] ? s[1] / s[0] : 0, cacheHits: s[2], updatePaths: s[3], updateRecords: s[4], occupiedCells: s[5], collisions: s[6], queries: s[8], acceptedUpdates: s[9] };
		} finally { readback.destroy(); }
	}
	release(): void { this.buffer = null; this.parameters = null; this.frameGroup = null; this.workGroup = null; this.invalidate(); }
}
