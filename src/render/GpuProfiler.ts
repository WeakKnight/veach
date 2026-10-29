export interface GpuProfileNode { name: string; ms: number; count: number; children: GpuProfileNode[] }
export interface GpuProfilePass { path: string[]; ms: number }
export interface GpuProfileMetadata { width: number; height: number; samples: 0 | 1; integrator: string }
export interface GpuProfileReport extends GpuProfileMetadata {
	id: number; totalMs: number; spanMs: number; passes: GpuProfilePass[]; roots: GpuProfileNode[];
	hotspots: { name: string; ms: number; count: number }[]; dropped: number; invalid: number;
}
export type GpuProfileStatus = 'unsupported' | 'idle' | 'waiting' | 'recording' | 'reading' | 'ready' | 'error';

/** Inclusive totals sum measured passes, never parent + child timings. */
export function aggregateGpuPasses(passes: readonly GpuProfilePass[]): Pick<GpuProfileReport, 'totalMs' | 'roots' | 'hotspots'> {
	const roots: GpuProfileNode[] = [], hotspots = new Map<string, { name: string; ms: number; count: number }>();
	let totalMs = 0;
	for (const pass of passes) {
		totalMs += pass.ms;
		let children = roots;
		for (const name of pass.path) {
			let node = children.find(n => n.name === name);
			if (!node) { node = { name, ms: 0, count: 0, children: [] }; children.push(node); }
			node.ms += pass.ms; node.count++; children = node.children;
		}
		const name = pass.path.filter(part => !/^Bounce \d+$/.test(part)).slice(-2).join('.') || 'Unnamed';
		const hot = hotspots.get(name) ?? { name, ms: 0, count: 0 };
		hot.ms += pass.ms; hot.count++; hotspots.set(name, hot);
	}
	return { totalMs, roots, hotspots: [...hotspots.values()].sort((a, b) => b.ms - a.ms) };
}

function passPath(label: string): string[] {
	const wavefront = /^wavefront\.(.+)\.b(\d+)$/.exec(label);
	if (wavefront) return ['Wavefront', `Bounce ${wavefront[2]}`, wavefront[1]];
	const dot = label.indexOf('.');
	return dot < 0 ? [label] : [label.slice(0, dot), label.slice(dot + 1)];
}

/** On-demand pass timestamps. No global GPU prototype patching, blocking waits or idle queries. */
export class GpuProfiler {
	readonly supported: boolean;
	status: GpuProfileStatus;
	error: string | null = null;
	report: GpuProfileReport | null = null;
	private queries: GPUQuerySet | null = null;
	private resolve: GPUBuffer | null = null;
	private readback: GPUBuffer | null = null;
	private readonly listeners = new Set<() => void>();
	private scopes: string[] = [];
	private paths: string[][] = [];
	private dropped = 0;
	private metadata: GpuProfileMetadata = { width: 0, height: 0, samples: 0, integrator: '' };
	private serial = 0;
	private destroyed = false;
	// Bounded memory and query count; excess passes are explicitly reported as incomplete.
	private static readonly maxPasses = 1024;

	constructor(private readonly device: GPUDevice) {
		this.supported = device.features.has('timestamp-query');
		this.status = this.supported ? 'idle' : 'unsupported';
		void device.lost.then(info => { if (!this.destroyed) this.abort(`GPU device lost: ${info.message}`); });
	}
	subscribe(listener: () => void): () => void { this.listeners.add(listener); return () => { this.listeners.delete(listener); }; }
	private notify(): void { for (const listener of this.listeners) listener(); }
	capture(): void {
		if (this.destroyed || !this.supported || ['waiting', 'recording', 'reading'].includes(this.status)) return;
		this.error = null; this.status = 'waiting'; this.notify();
	}
	cancelPending(): void { if (this.status === 'waiting') { this.status = this.report ? 'ready' : 'idle'; this.notify(); } }
	beginFrame(metadata: GpuProfileMetadata): void {
		if (this.status !== 'waiting' || this.destroyed) return;
		if (!this.queries) {
			const size = GpuProfiler.maxPasses * 16;
			this.queries = this.device.createQuerySet({ label: 'gpuProfile.timestamps', type: 'timestamp', count: GpuProfiler.maxPasses * 2 });
			this.resolve = this.device.createBuffer({ label: 'gpuProfile.resolve', size, usage: GPUBufferUsage.QUERY_RESOLVE | GPUBufferUsage.COPY_SRC });
			this.readback = this.device.createBuffer({ label: 'gpuProfile.readback', size, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
		}
		this.paths = []; this.scopes = []; this.dropped = 0; this.metadata = { ...metadata };
		this.status = 'recording'; this.notify();
	}
	/** Synchronous lexical scope; descendants inherit its label and contribute their pass time. */
	scope<T>(name: string, encode: () => T): T {
		if (this.status !== 'recording') return encode();
		this.scopes.push(name);
		try { return encode(); } finally { this.scopes.pop(); }
	}
	createCommandEncoder(descriptor: GPUCommandEncoderDescriptor): GPUCommandEncoder {
		const encoder = this.device.createCommandEncoder(descriptor);
		if (this.status !== 'recording') return encoder;
		return new Proxy(encoder, { get: (target, key) => {
			if (key === 'beginComputePass') return (d: GPUComputePassDescriptor = {}) => target.beginComputePass(this.withTimestamps(d));
			if (key === 'beginRenderPass') return (d: GPURenderPassDescriptor) => target.beginRenderPass(this.withTimestamps(d));
			const value = Reflect.get(target, key, target);
			return typeof value === 'function' ? value.bind(target) : value;
		} });
	}
	private withTimestamps<T extends GPUComputePassDescriptor | GPURenderPassDescriptor>(descriptor: T): T {
		if (this.status !== 'recording') return descriptor;
		if (descriptor.timestampWrites || this.paths.length >= GpuProfiler.maxPasses) { this.dropped++; return descriptor; }
		const index = this.paths.length * 2;
		this.paths.push([...this.scopes, ...passPath(descriptor.label ?? 'Unnamed pass')]);
		return { ...descriptor, timestampWrites: { querySet: this.queries!, beginningOfPassWriteIndex: index, endOfPassWriteIndex: index + 1 } };
	}
	/** Call after all captured command buffers have been submitted to the same queue. */
	endFrame(samples: 0 | 1): void {
		if (this.status !== 'recording') return;
		if (!this.paths.length) { this.abort('No GPU passes were submitted'); return; }
		this.metadata.samples = samples;
		const encoder = this.device.createCommandEncoder({ label: 'gpuProfile.readback' });
		const count = this.paths.length * 2;
		encoder.resolveQuerySet(this.queries!, 0, count, this.resolve!, 0);
		encoder.copyBufferToBuffer(this.resolve!, 0, this.readback!, 0, count * 8);
		this.device.queue.submit([encoder.finish()]);
		this.status = 'reading'; this.notify();
		void this.collect(count);
	}
	private async collect(count: number): Promise<void> {
		const buffer = this.readback!;
		try {
			await buffer.mapAsync(GPUMapMode.READ, 0, count * 8);
			if (this.destroyed || this.status !== 'reading') { buffer.unmap(); return; }
			const timestamps = new BigUint64Array(buffer.getMappedRange(0, count * 8));
			const passes: GpuProfilePass[] = [];
			let invalid = 0, first: bigint | null = null, last = 0n;
			for (let i = 0; i < this.paths.length; i++) {
				const begin = timestamps[i * 2], end = timestamps[i * 2 + 1];
				if (end < begin || end === 0n || (first !== null && begin < last)) { invalid++; continue; }
				first ??= begin; last = end;
				passes.push({ path: this.paths[i], ms: Number(end - begin) / 1e6 });
			}
			buffer.unmap();
			this.report = { ...this.metadata, ...aggregateGpuPasses(passes), id: ++this.serial, passes,
				spanMs: first === null ? 0 : Number(last - first) / 1e6, dropped: this.dropped, invalid };
			this.status = 'ready'; this.notify();
		} catch (error) { if (!this.destroyed) this.abort(error); }
	}
	abort(error: unknown): void {
		this.error = String(error); this.status = 'error'; this.scopes = []; this.notify();
	}
	destroy(): void {
		this.destroyed = true; this.listeners.clear(); this.queries?.destroy(); this.resolve?.destroy(); this.readback?.destroy();
	}
}
