// Bounded tile work storage shares accumulation binding 0. Only a dynamic uniform is added.
import wavefrontWgsl from '../generated/shaders/Wavefront.wgsl?raw';
import compactWgsl from '../generated/shaders/WavefrontCompact.wgsl?raw';
import compactSubgroupWgsl from '../generated/shaders/WavefrontCompactSubgroup.wgsl?raw';
import compactDenseWgsl from '../generated/shaders/WavefrontCompactDense.wgsl?raw';
import compactPacketWgsl from '../generated/shaders/WavefrontCompactPacket.wgsl?raw';
import compactAdaptiveWgsl from '../generated/shaders/WavefrontCompactAdaptive.wgsl?raw';
import { specializeMaterialShader, type MaterialStackCapacity } from './MaterialShaderVariants';

const RECORD_BYTES = 21 * 16; // WAVEFRONT_STRIDE in Wavefront.slang
const TILE_CAPACITY = 262144;
const WORKGROUP_SIZE = 64;
const ENTRIES = ['Initialize', 'Intersect', 'IntersectOpaque', 'Shade', 'Shadow', 'ShadowOpaque', 'Tail', 'TailOpaque', 'Finalize',
	'IntersectDirect', 'IntersectOpaqueDirect', 'ShadeDirect', 'ShadowDirect', 'ShadowOpaqueDirect',
	'CompactIntersect', 'CompactShade', 'CompactIntersectDense', 'CompactShadeDense', 'CompactIntersectSubgroup', 'CompactShadeSubgroup',
	'CompactIntersectAdaptive', 'CompactShadeAdaptive', 'CompactIntersectPacket', 'CompactShadePacket'] as const;
type Entry = typeof ENTRIES[number];

export class Wavefront {
	// Experimental tuning knob for the benchmark; keep the fully staged default until measured.
	tailStart = Number.POSITIVE_INFINITY;
	tailThreshold = 0;
	compaction: 'dense' | 'queued' | 'subgroup' | 'adaptive' | 'packet' | 'none' = 'dense';
	// Internal experiment: bits 1/2/4 select direct intersection/shading/shadow dispatch.
	directStages = 0;
	// Bits select packet retention in the queues consumed by intersection/shading/shadow.
	packetStages = 7;
	readonly layout: GPUBindGroupLayout;
	readonly compiled: Promise<void>;
	private readonly pipelines = new Map<MaterialStackCapacity, Map<Entry, GPUComputePipeline>>();
	private readonly compiling = new Map<MaterialStackCapacity, Promise<void>>();
	private readonly pipelineLayout: GPUPipelineLayout;
	private readonly compactModule: GPUShaderModule;
	private readonly compactDenseModule: GPUShaderModule;
	private readonly compactPacketModule: GPUShaderModule;
	private readonly compactAdaptiveModule: GPUShaderModule;
	private readonly compactSubgroupModule: GPUShaderModule | null;
	private destroyed = false;
	private parameters: GPUBuffer | null = null;
	private group: GPUBindGroup | null = null;
	private parameterKey = '';
	private accumulation: GPUBuffer | null = null;
	private feedback: GPUTexture | null = null;
	private readonly alignment: number;
	private readonly indirect: GPUBuffer;

	constructor(private readonly device: GPUDevice, sceneLayout: GPUBindGroupLayout, capacity: MaterialStackCapacity = 16) {
		this.alignment = device.limits.minUniformBufferOffsetAlignment;
		this.indirect = device.createBuffer({ label: 'wavefrontDispatch', size: 32, usage: GPUBufferUsage.INDIRECT | GPUBufferUsage.COPY_DST });
		this.layout = device.createBindGroupLayout({ label: 'wavefront', entries: [
			{ binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'storage' } },
			{ binding: 1, visibility: GPUShaderStage.COMPUTE, storageTexture: { access: 'write-only', format: 'r32uint' } },
			{ binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'uniform', hasDynamicOffset: true, minBindingSize: 32 } },
		] });
		this.compactModule = device.createShaderModule({ label: 'WavefrontCompact', code: compactWgsl });
		this.compactDenseModule = device.createShaderModule({ label: 'WavefrontCompactDense', code: compactDenseWgsl });
		this.compactPacketModule = device.createShaderModule({ label: 'WavefrontCompactPacket', code: compactPacketWgsl });
		this.compactAdaptiveModule = device.createShaderModule({ label: 'WavefrontCompactAdaptive', code: compactAdaptiveWgsl });
		this.compactSubgroupModule = device.features.has('subgroups')
			? device.createShaderModule({ label: 'WavefrontCompactSubgroup', code: compactSubgroupWgsl }) : null;
		this.pipelineLayout = device.createPipelineLayout({ bindGroupLayouts: [sceneLayout, this.layout] });
		this.compiled = this.prepareStack(capacity);
	}

	async prepareStack(capacity: MaterialStackCapacity): Promise<void> {
		if (this.destroyed) throw new Error('Wavefront has been destroyed');
		if (this.pipelines.has(capacity)) return;
		let pending = this.compiling.get(capacity);
		if (!pending) {
			const module = this.device.createShaderModule({ label: 'Wavefront', code: specializeMaterialShader(wavefrontWgsl, 'Wavefront', capacity) });
			pending = Promise.all(ENTRIES.filter(entry => !entry.endsWith('Subgroup') || this.compactSubgroupModule).map(async entryPoint => {
				const compact = entryPoint.startsWith('Compact');
				const shader = entryPoint.endsWith('Dense') ? this.compactDenseModule
					: entryPoint.endsWith('Packet') ? this.compactPacketModule
					: entryPoint.endsWith('Adaptive') ? this.compactAdaptiveModule
					: entryPoint.endsWith('Subgroup') ? this.compactSubgroupModule! : compact ? this.compactModule : module;
				const pipeline = await this.device.createComputePipelineAsync({ label: `wavefront.${entryPoint}.stack${capacity}`, layout: this.pipelineLayout,
					compute: { module: shader, entryPoint: compact ? entryPoint.replace(/Dense|Subgroup|Adaptive|Packet/g, '') : entryPoint } });
				return [entryPoint, pipeline] as const;
			})).then(entries => {
				if (this.destroyed) throw new Error('Wavefront has been destroyed');
				this.pipelines.set(capacity, new Map(entries));
			}).catch(error => {
				this.compiling.delete(capacity);
				throw error;
			});
			this.compiling.set(capacity, pending);
		}
		await pending;
	}

	capacity(pixels: number): number {
		const available = Math.min(this.device.limits.maxStorageBufferBindingSize, this.device.limits.maxBufferSize) - pixels * 48 - 96;
		const capacity = Math.min(TILE_CAPACITY, pixels, Math.floor(available / (RECORD_BYTES + 12)));
		if (capacity < 1) throw new Error('Image dimensions leave no room for wavefront work storage');
		return capacity;
	}

	storageBytes(pixels: number): number {
		const capacity = this.capacity(pixels);
		return 48 + capacity * RECORD_BYTES + Math.ceil(capacity / 4) * 48;
	}

	bind(accumulation: GPUBuffer, feedback: GPUTexture): void {
		this.accumulation = accumulation;
		this.feedback = feedback;
		this.parameterKey = '';
		this.group = null;
	}

	encode(encoder: GPUCommandEncoder, scene: GPUBindGroup, width: number, height: number, maxBounces: number, hasAlphaTested: boolean, materialCapacity: MaterialStackCapacity): void {
		if (!this.accumulation || !this.feedback) return;
		const directStages = this.compaction === 'none' ? 7 : this.directStages;
		if (!Number.isInteger(directStages) || directStages < 0 || directStages > 7) throw new Error('Invalid direct stage mask');
		const direct = directStages === 7;
		if (!Number.isInteger(this.packetStages) || this.packetStages < 0 || this.packetStages > 7) throw new Error('Invalid packet stage mask');
		if (this.compaction === 'packet' && this.tailThreshold !== 0) throw new Error('Packet counts include inactive slots; use fixed tails');
		if (direct && this.tailThreshold !== 0) throw new Error('Direct dispatch supports fixed tails only; adaptive tails require queue counts');
		if (this.compaction === 'subgroup' && !this.compactSubgroupModule) throw new Error('Subgroup compaction requires the subgroups device feature');
		const pipelines = this.pipelines.get(materialCapacity);
		if (!pipelines) throw new Error('Wavefront material pipelines have not been prepared');
		const compactSuffix = { dense: 'Dense', queued: '', subgroup: 'Subgroup', adaptive: 'Adaptive', packet: 'Packet', none: '' }[this.compaction];
		const pixels = width * height, capacity = this.capacity(pixels);
		const workItems = Math.ceil(width / 8) * Math.ceil(height / 8) * 64;
		const tiles = Math.ceil(workItems / capacity), bounces = Math.max(0, Math.floor(maxBounces));
		const key = `${width}/${height}/${bounces}/${capacity}/${this.tailThreshold}/${this.packetStages}`;
		if (key !== this.parameterKey) {
			this.parameters?.destroy();
			const data = new Uint32Array(tiles * (bounces + 1) * this.alignment / 4);
			for (let tile = 0; tile < tiles; tile++) {
				for (let bounce = 0; bounce <= bounces; bounce++) {
					data.set([tile * capacity, Math.min(capacity, workItems - tile * capacity), bounce, capacity, this.tailThreshold, this.packetStages],
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
				const compact = entry === 'CompactIntersect' || entry === 'CompactShade';
				const directStage = (directStages & (entry === 'Intersect' ? 1 : entry === 'Shade' ? 2 : entry === 'Shadow' ? 4 : 0)) !== 0;
				let pipeline = compact ? `${entry}${compactSuffix}` as Entry
					: !hasAlphaTested && (entry === 'Intersect' || entry === 'Shadow' || entry === 'Tail') ? `${entry}Opaque` as Entry : entry;
				if (directStage) pipeline = `${pipeline}Direct` as Entry;
				pass.setPipeline(pipelines.get(pipeline)!);
				pass.setBindGroup(0, scene);
				pass.setBindGroup(1, this.group!, [(tile * (bounces + 1) + bounce) * this.alignment]);
				if (!direct && !directStage && entry !== 'Initialize' && entry !== 'Finalize' && !(compact && (this.compaction === 'dense' || this.compaction === 'packet'))) {
					pass.dispatchWorkgroupsIndirect(this.indirect, entry === 'Shadow' ? 16 : 0);
				} else {
					pass.dispatchWorkgroups(Math.ceil(count / WORKGROUP_SIZE));
				}
				pass.end();
			};
			const copyArguments = () => encoder.copyBufferToBuffer(this.accumulation!, pixels * 48 + 16, this.indirect, 0, 32);
			const compact = (bounce: number, afterShade: boolean) => {
				// Keep the input queue count while clearing the other queue's output count.
				encoder.clearBuffer(this.accumulation!, pixels * 48 + (afterShade ? 0 : 4), 8);
				encoder.clearBuffer(this.accumulation!, pixels * 48 + 16, 4);
				encoder.clearBuffer(this.accumulation!, pixels * 48 + 32, 4);
				dispatch(afterShade ? 'CompactShade' : 'CompactIntersect', bounce);
				copyArguments();
			};
			dispatch('Initialize', 0);
			if (!direct) copyArguments();
			for (let bounce = 0; bounce <= bounces; bounce++) {
				if (bounce >= this.tailStart) {
					dispatch('Tail', bounce);
					if (this.tailThreshold === 0) break;
					// Adaptive tails either return immediately or terminate all queued paths.
					// Following stages observe liveness; compaction drives their indirect counts to zero.
				}
				dispatch('Intersect', bounce);
				if (!direct) compact(bounce, false);
				dispatch('Shade', bounce);
				if (bounce < bounces) {
					if (!direct) compact(bounce, true);
					dispatch('Shadow', bounce);
				}
			}
			dispatch('Finalize', bounces);
		}
	}

	destroy(): void {
		if (this.destroyed) return;
		this.destroyed = true;
		this.pipelines.clear();
		this.compiling.clear();
		this.indirect.destroy();
		this.parameters?.destroy();
		this.group = null;
		this.accumulation = null;
		this.feedback = null;
	}
}
