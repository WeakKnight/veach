// Bounded tile work storage shares accumulation binding 0. Only a dynamic uniform is added.
import wavefrontWgsl from '../generated/shaders/Wavefront.wgsl?raw';

const RECORD_BYTES = 21 * 16; // WAVEFRONT_STRIDE in Wavefront.slang
const TILE_CAPACITY = 65536;
const WORKGROUP_SIZE = 64;
const ENTRIES = ['Initialize', 'Intersect', 'Shade', 'Shadow', 'Finalize'] as const;
type Entry = typeof ENTRIES[number];

export class Wavefront {
	readonly layout: GPUBindGroupLayout;
	readonly compiled: Promise<void>;
	private readonly pipelines = new Map<Entry, GPUComputePipeline>();
	private parameters: GPUBuffer | null = null;
	private group: GPUBindGroup | null = null;
	private parameterKey = '';
	private accumulation: GPUBuffer | null = null;
	private feedback: GPUTexture | null = null;
	private readonly alignment: number;

	constructor(private readonly device: GPUDevice, sceneLayout: GPUBindGroupLayout) {
		this.alignment = device.limits.minUniformBufferOffsetAlignment;
		this.layout = device.createBindGroupLayout({ label: 'wavefront', entries: [
			{ binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'storage' } },
			{ binding: 1, visibility: GPUShaderStage.COMPUTE, storageTexture: { access: 'write-only', format: 'r32uint' } },
			{ binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'uniform', hasDynamicOffset: true, minBindingSize: 16 } },
		] });
		const module = device.createShaderModule({ label: 'Wavefront', code: wavefrontWgsl });
		const layout = device.createPipelineLayout({ bindGroupLayouts: [sceneLayout, this.layout] });
		this.compiled = Promise.all(ENTRIES.map(async entryPoint => {
			const pipeline = await device.createComputePipelineAsync({ label: `wavefront.${entryPoint}`, layout, compute: { module, entryPoint } });
			this.pipelines.set(entryPoint, pipeline);
		})).then(() => {});
	}

	capacity(pixels: number): number {
		const available = Math.min(this.device.limits.maxStorageBufferBindingSize, this.device.limits.maxBufferSize) - pixels * 48;
		const capacity = Math.min(TILE_CAPACITY, pixels, Math.floor(available / RECORD_BYTES));
		if (capacity < 1) throw new Error('Image dimensions leave no room for wavefront work storage');
		return capacity;
	}

	storageBytes(pixels: number): number { return this.capacity(pixels) * RECORD_BYTES; }

	bind(accumulation: GPUBuffer, feedback: GPUTexture): void {
		this.accumulation = accumulation;
		this.feedback = feedback;
		this.parameterKey = '';
		this.group = null;
	}

	encode(encoder: GPUCommandEncoder, scene: GPUBindGroup, width: number, height: number, maxBounces: number): void {
		if (!this.accumulation || !this.feedback) return;
		const pixels = width * height, capacity = this.capacity(pixels);
		const tiles = Math.ceil(pixels / capacity), bounces = Math.max(0, Math.floor(maxBounces));
		const key = `${pixels}/${bounces}/${capacity}`;
		if (key !== this.parameterKey) {
			this.parameters?.destroy();
			const data = new Uint32Array(tiles * (bounces + 1) * this.alignment / 4);
			for (let tile = 0; tile < tiles; tile++) {
				for (let bounce = 0; bounce <= bounces; bounce++) {
					data.set([tile * capacity, Math.min(capacity, pixels - tile * capacity), bounce, capacity],
						(tile * (bounces + 1) + bounce) * this.alignment / 4);
				}
			}
			this.parameters = this.device.createBuffer({ label: 'wavefrontParameters', size: data.byteLength, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
			this.device.queue.writeBuffer(this.parameters, 0, data);
			this.group = this.device.createBindGroup({ label: 'wavefront', layout: this.layout, entries: [
				{ binding: 0, resource: { buffer: this.accumulation } },
				{ binding: 1, resource: this.feedback.createView() },
				{ binding: 2, resource: { buffer: this.parameters, size: 16 } },
			] });
			this.parameterKey = key;
		}
		for (let tile = 0; tile < tiles; tile++) {
			const count = Math.min(capacity, pixels - tile * capacity);
			const dispatch = (entry: Entry, bounce: number) => {
				const pass = encoder.beginComputePass({ label: `wavefront.${entry}` });
				pass.setPipeline(this.pipelines.get(entry)!);
				pass.setBindGroup(0, scene);
				pass.setBindGroup(1, this.group!, [(tile * (bounces + 1) + bounce) * this.alignment]);
				pass.dispatchWorkgroups(Math.ceil(count / WORKGROUP_SIZE));
				pass.end();
			};
			dispatch('Initialize', 0);
			for (let bounce = 0; bounce <= bounces; bounce++) {
				dispatch('Intersect', bounce);
				dispatch('Shade', bounce);
				if (bounce < bounces) dispatch('Shadow', bounce);
			}
			dispatch('Finalize', bounces);
		}
	}

	destroy(): void {
		this.parameters?.destroy();
		this.group = null;
		this.accumulation = null;
		this.feedback = null;
	}
}
