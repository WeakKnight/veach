import code from '../generated/shaders/TemporalAA.wgsl?raw';
import { vec3, type Vec3 } from '../math/Math';
import type { GpuScene } from './GpuScene';
import type { PipelineCompiler } from './PipelineCompiler';

export interface TemporalCamera { position: Vec3; right: Vec3; up: Vec3; forward: Vec3 }
export interface TaaStats { active: boolean; reason: string | null; historyFrames: number; resetReason: string; bytes: number }
export function temporalJitter(frame: number): [number, number] {
	const radical = (n: number, base: number) => { let value = 0, scale = 1; while (n > 0) { scale /= base; value += (n % base) * scale; n = Math.floor(n / base); } return value; };
	return [radical(frame % 32 + 1, 2), radical(frame % 32 + 1, 3)];
}
export function temporalInverse(camera: TemporalCamera): [Vec3, Vec3, Vec3] {
	const a = vec3.cross(camera.up, camera.forward), b = vec3.cross(camera.forward, camera.right), c = vec3.cross(camera.right, camera.up);
	const det = vec3.dot(camera.right, a);
	if (!Number.isFinite(det) || Math.abs(det) < 1e-12) throw new Error('TAA requires an invertible camera basis');
	return [vec3.scale(a, 1 / det), vec3.scale(b, 1 / det), vec3.scale(c, 1 / det)];
}

export class TemporalAA {
	readonly compiled: Promise<void>;
	private pipeline!: GPUComputePipeline;
	private motionPipeline!: GPUComputePipeline;
	private readonly layout: GPUBindGroupLayout;
	private readonly uniform: GPUBuffer;
	private history: GPUBuffer[] = [];
	private output: GPUBuffer | null = null;
	private motion: GPUBuffer | null = null;
	private instances: GPUBuffer | null = null;
	private retiredInstances: GPUBuffer[] = [];
	private previousCamera: TemporalCamera | null = null;
	private currentCamera: TemporalCamera | null = null;
	private previousJitter: [number, number] = [0.5, 0.5];
	jitter: [number, number] = [0.5, 0.5];
	private width = 0;
	private height = 0;
	private previousSlots = 0;
	private ping = 0;
	private sequence = 0;
	private identity: object | null = null;
	private maximumRadiance = 0;
	stats: TaaStats = { active: false, reason: 'not-rendered', historyFrames: 0, resetReason: 'initial', bytes: 0 };

	constructor(private readonly device: GPUDevice, compiler: PipelineCompiler) {
		this.uniform = device.createBuffer({ label: 'taa.params', size: 112, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
		this.layout = device.createBindGroupLayout({ entries: Array.from({ length: 9 }, (_, binding) => ({ binding, visibility: GPUShaderStage.COMPUTE,
			buffer: { type: (binding < 2 ? 'uniform' : binding < 6 ? 'read-only-storage' : 'storage') as GPUBufferBindingType } })) });
		const layout = device.createPipelineLayout({ bindGroupLayouts: [this.layout] });
		const module = device.createShaderModule({ label: 'TemporalAA', code });
		this.compiled = Promise.all([
			compiler.compute({ label: 'taa.motion', layout, compute: { module, entryPoint: 'GenerateMotion' } }),
			compiler.compute({ label: 'taa.resolve', layout, compute: { module, entryPoint: 'Resolve' } }),
		]).then(([motion, resolve]) => { this.motionPipeline = motion; this.pipeline = resolve; });
	}
	/** Borrowed buffer, two float4s/pixel: motion.xy (previous-current pixels), 0, valid; previous world.xyz, 0. */
	get motionVectorBuffer(): GPUBuffer | null { return this.stats.active ? this.motion : null; }
	reset(reason = 'explicit'): void { this.stats.historyFrames = 0; this.stats.resetReason = reason; }
	suspend(reason: string): void { this.reset(reason); this.stats.active = false; this.stats.reason = reason; }
	begin(camera: TemporalCamera, width: number, height: number, scene: GpuScene, identity: object, maximumRadiance: number, cut: boolean): boolean {
		// Previous frame commands have been submitted before the next begin().
		for (const buffer of this.retiredInstances) buffer.destroy();
		this.retiredInstances = [];
		const bytes = width * height * 48;
		if (bytes > Math.min(this.device.limits.maxBufferSize, this.device.limits.maxStorageBufferBindingSize)) { this.suspend('storage-budget'); return false; }
		if (width !== this.width || height !== this.height) {
			for (const buffer of [...this.history, this.output, this.motion]) buffer?.destroy();
			const create = (label: string) => this.device.createBuffer({ label, size: bytes, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST });
			this.history = [create('taa.history0'), create('taa.history1')]; this.output = create('taa.output');
			this.motion = this.device.createBuffer({ label: 'taa.motion', size: width * height * 32, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC });
			this.width = width; this.height = height; this.reset('resize');
		}
		this.instances ??= this.device.createBuffer({ label: 'taa.previousInstances', size: scene.instances.size, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST });
		if (this.identity !== identity) { this.reset('scene-switch'); this.identity = identity; }
		// This changes the encoding of stored PQ history, unlike ordinary rendering settings.
		if (this.maximumRadiance !== maximumRadiance) { this.reset('history-encoding'); this.maximumRadiance = maximumRadiance; }
		if (cut) this.reset('camera-cut');
		this.currentCamera = { position: [...camera.position], right: [...camera.right], up: [...camera.up], forward: [...camera.forward] };
		this.jitter = temporalJitter(this.sequence++);
		this.stats.active = true; this.stats.reason = null; this.stats.bytes = bytes * 3 + this.motion!.size + Math.max(this.instances.size, scene.instances.size) + 112;
		return true;
	}
	/** filter runs between motion generation and resolve (NRD) and may replace the resolve input, same layout. */
	encode(encoder: GPUCommandEncoder, frame: GPUBuffer, source: GPUBuffer, scene: GpuScene, weight: number, clamp: number, maximum: number,
		filter?: (encoder: GPUCommandEncoder, motion: GPUBuffer) => GPUBuffer): GPUBuffer {
		const old = this.previousCamera ?? this.currentCamera!, data = new ArrayBuffer(112), f = new Float32Array(data), u = new Uint32Array(data);
		f.set(old.position, 0);
		temporalInverse(old).forEach((row, i) => f.set(row, 4 + i * 4));
		f.set([...this.previousJitter, Math.max(vec3.length(old.right) * 2 / this.width, vec3.length(old.up) * 2 / this.height), 0], 16);
		f.set([Math.max(0.001, Math.min(1, weight)), Math.max(0.01, clamp), Math.max(1, maximum), Number(this.stats.historyFrames > 0)], 20);
		u.set([scene.instanceSlots, this.previousSlots, 0, 0], 24);
		this.device.queue.writeBuffer(this.uniform, 0, data);
		const createGroup = (input: GPUBuffer) => {
			const buffers = [frame, this.uniform, input, this.history[this.ping], scene.instances, this.instances!, this.history[this.ping ^ 1], this.output!, this.motion!];
			return this.device.createBindGroup({ layout: this.layout, entries: buffers.map((buffer, binding) => ({ binding, resource: { buffer } })) });
		};
		let group = createGroup(source);
		const motion = encoder.beginComputePass({ label: 'taa.motion' });
		motion.setPipeline(this.motionPipeline); motion.setBindGroup(0, group); motion.dispatchWorkgroups(Math.ceil(this.width / 8), Math.ceil(this.height / 8)); motion.end();
		const filtered = filter?.(encoder, this.motion!) ?? source;
		if (filtered !== source) group = createGroup(filtered);
		const pass = encoder.beginComputePass({ label: 'taa.resolve' });
		pass.setPipeline(this.pipeline); pass.setBindGroup(0, group); pass.dispatchWorkgroups(Math.ceil(this.width / 8), Math.ceil(this.height / 8)); pass.end();
		// Resolve reads the last rendered pose even when this frame grows the scene arena.
		// Only the next-frame snapshot needs the larger allocation; history remains intact.
		if (this.instances!.size < scene.instances.size) {
			this.retiredInstances.push(this.instances!);
			this.instances = this.device.createBuffer({ label: 'taa.previousInstances', size: scene.instances.size, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST });
		}
		encoder.copyBufferToBuffer(scene.instances, 0, this.instances!, 0, scene.instances.size);
		this.ping ^= 1; this.previousSlots = scene.instanceSlots; this.previousCamera = this.currentCamera; this.previousJitter = [...this.jitter];
		this.stats.historyFrames++;
		return this.output!;
	}
	destroy(): void { for (const buffer of [...this.history, ...this.retiredInstances, this.output, this.motion, this.instances, this.uniform]) buffer?.destroy(); }
}
