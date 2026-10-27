// Bounded tile work storage shares accumulation binding 0. Only a dynamic uniform is added.
import wavefrontWgsl from '../generated/shaders/Wavefront.wgsl?raw';
import compactWgsl from '../generated/shaders/WavefrontCompact.wgsl?raw';

const RECORD_BYTES = 21 * 16; // WAVEFRONT_STRIDE in Wavefront.slang
const TILE_CAPACITY = 262144;
const WORKGROUP_SIZE = 64;
const ENTRIES = ['Initialize', 'Intersect', 'IntersectOpaque', 'Shade', 'Shadow', 'ShadowOpaque', 'Tail', 'TailOpaque', 'Finalize', 'Compact'] as const;
type Entry = typeof ENTRIES[number];

export class Wavefront {
	// Experimental tuning knob for the benchmark; keep the fully staged default until measured.
	tailStart = Number.POSITIVE_INFINITY;
	tailThreshold = 0;
	readonly layout: GPUBindGroupLayout;
	readonly compiled: Promise<void>;
	private readonly pipelines = new Map<Entry, GPUComputePipeline>();
	private parameters: GPUBuffer | null = null;
	private group: GPUBindGroup | null = null;
	private parameterKey = '';
	private accumulation: GPUBuffer | null = null;
	private feedback: GPUTexture | null = null;
	private readonly alignment: number;
	private readonly indirect: GPUBuffer;

	constructor(private readonly device: GPUDevice, sceneLayout: GPUBindGroupLayout) {
		this.alignment = device.limits.minUniformBufferOffsetAlignment;
		this.indirect = device.createBuffer({ label: 'wavefrontDispatch', size: 32, usage: GPUBufferUsage.INDIRECT | GPUBufferUsage.COPY_DST });
		this.layout = device.createBindGroupLayout({ label: 'wavefront', entries: [
			{ binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'storage' } },
			{ binding: 1, visibility: GPUShaderStage.COMPUTE, storageTexture: { access: 'write-only', format: 'r32uint' } },
			{ binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'uniform', hasDynamicOffset: true, minBindingSize: 32 } },
		] });
		const module = device.createShaderModule({ label: 'Wavefront', code: wavefrontWgsl });
		const compactModule = device.createShaderModule({ label: 'WavefrontCompact', code: compactWgsl });
		const layout = device.createPipelineLayout({ bindGroupLayouts: [sceneLayout, this.layout] });
		this.compiled = Promise.all(ENTRIES.map(async entryPoint => {
			const pipeline = await device.createComputePipelineAsync({ label: `wavefront.${entryPoint}`, layout, compute: { module: entryPoint === 'Compact' ? compactModule : module, entryPoint } });
			this.pipelines.set(entryPoint, pipeline);
		})).then(() => {});
	}

	capacity(pixels: number): number {
		const available = Math.min(this.device.limits.maxStorageBufferBindingSize, this.device.limits.maxBufferSize) - pixels * 48 - 80;
		const capacity = Math.min(TILE_CAPACITY, pixels, Math.floor(available / (RECORD_BYTES + 8)));
		if (capacity < 1) throw new Error('Image dimensions leave no room for wavefront work storage');
		return capacity;
	}

	storageBytes(pixels: number): number {
		const capacity = this.capacity(pixels);
		return 48 + capacity * RECORD_BYTES + Math.ceil(capacity / 4) * 32;
	}

	bind(accumulation: GPUBuffer, feedback: GPUTexture): void {
		this.accumulation = accumulation;
		this.feedback = feedback;
		this.parameterKey = '';
		this.group = null;
	}

	encode(encoder: GPUCommandEncoder, scene: GPUBindGroup, width: number, height: number, maxBounces: number, hasAlphaTested: boolean): void {
		if (!this.accumulation || !this.feedback) return;
		const pixels = width * height, capacity = this.capacity(pixels);
		const workItems = Math.ceil(width / 8) * Math.ceil(height / 8) * 64;
		const tiles = Math.ceil(workItems / capacity), bounces = Math.max(0, Math.floor(maxBounces));
		const key = `${width}/${height}/${bounces}/${capacity}/${this.tailThreshold}`;
		if (key !== this.parameterKey) {
			this.parameters?.destroy();
			const data = new Uint32Array(tiles * (bounces + 1) * this.alignment / 4);
			for (let tile = 0; tile < tiles; tile++) {
				for (let bounce = 0; bounce <= bounces; bounce++) {
					data.set([tile * capacity, Math.min(capacity, workItems - tile * capacity), bounce, capacity, this.tailThreshold],
						(tile * (bounces + 1) + bounce) * this.alignment / 4);
				}
			}
			this.parameters = this.device.createBuffer({ label: 'wavefrontParameters', size: data.byteLength, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
			this.device.queue.writeBuffer(this.parameters, 0, data);
			this.group = this.device.createBindGroup({ label: 'wavefront', layout: this.layout, entries: [
				{ binding: 0, resource: { buffer: this.accumulation } },
				{ binding: 1, resource: this.feedback.createView() },
				{ binding: 2, resource: { buffer: this.parameters, size: 32 } },
			] });
			this.parameterKey = key;
		}
		for (let tile = 0; tile < tiles; tile++) {
			const count = Math.min(capacity, workItems - tile * capacity);
			const dispatch = (entry: Entry, bounce: number) => {
				const pass = encoder.beginComputePass({ label: `wavefront.${entry}.b${bounce}` });
				const pipeline = !hasAlphaTested && (entry === 'Intersect' || entry === 'Shadow' || entry === 'Tail') ? `${entry}Opaque` as Entry : entry;
				pass.setPipeline(this.pipelines.get(pipeline)!);
				pass.setBindGroup(0, scene);
				pass.setBindGroup(1, this.group!, [(tile * (bounces + 1) + bounce) * this.alignment]);
				if (entry === 'Intersect' || entry === 'Shade' || entry === 'Shadow' || entry === 'Tail') {
					pass.dispatchWorkgroupsIndirect(this.indirect, entry === 'Shadow' ? 16 : 0);
				} else {
					pass.dispatchWorkgroups(Math.ceil(count / WORKGROUP_SIZE));
				}
				pass.end();
			};
			const copyArguments = () => encoder.copyBufferToBuffer(this.accumulation!, pixels * 48 + 16, this.indirect, 0, 32);
			const compact = (bounce: number) => {
				encoder.clearBuffer(this.accumulation!, pixels * 48, 16);
				encoder.clearBuffer(this.accumulation!, pixels * 48 + 16, 4);
				encoder.clearBuffer(this.accumulation!, pixels * 48 + 32, 4);
				dispatch('Compact', bounce);
				copyArguments();
			};
			dispatch('Initialize', 0);
			copyArguments();
			for (let bounce = 0; bounce <= bounces; bounce++) {
				if (bounce >= this.tailStart) {
					dispatch('Tail', bounce);
					if (this.tailThreshold === 0) break;
					// Adaptive tails either return immediately or terminate all queued paths.
					// Following stages observe liveness; compaction drives their indirect counts to zero.
				}
				dispatch('Intersect', bounce);
				compact(bounce);
				dispatch('Shade', bounce);
				if (bounce < bounces) {
					compact(bounce);
					dispatch('Shadow', bounce);
				}
			}
			dispatch('Finalize', bounces);
		}
	}

	destroy(): void {
		this.indirect.destroy();
		this.parameters?.destroy();
		this.group = null;
		this.accumulation = null;
		this.feedback = null;
	}
}
