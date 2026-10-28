// Bounded tile work storage shares accumulation binding 0. Only a dynamic uniform is added.
import wavefrontWgsl from '../generated/shaders/Wavefront.wgsl?raw';
import compactWgsl from '../generated/shaders/WavefrontCompact.wgsl?raw';
import bucketsWgsl from '../generated/shaders/WavefrontBuckets.wgsl?raw';
import compactSubgroupWgsl from '../generated/shaders/WavefrontCompactSubgroup.wgsl?raw';
import compactDenseWgsl from '../generated/shaders/WavefrontCompactDense.wgsl?raw';
import compactPacketWgsl from '../generated/shaders/WavefrontCompactPacket.wgsl?raw';
import compactAdaptiveWgsl from '../generated/shaders/WavefrontCompactAdaptive.wgsl?raw';
import compactSpatialWgsl from '../generated/shaders/WavefrontCompactSpatial.wgsl?raw';
import sort64Wgsl from '../generated/shaders/WavefrontSort64.wgsl?raw';
import sort256Wgsl from '../generated/shaders/WavefrontSort256.wgsl?raw';
import shadowWgsl from '../generated/shaders/WavefrontShadow.wgsl?raw';
import { specializeMaterialShader, type MaterialStackCapacity } from './MaterialShaderVariants';
import { ALL_MATERIAL_OPCODES, materialPipelineKey, materialPipelineConstants, type MaterialOpcodeMask } from './MaterialProgramFeatures';

const RECORD_BYTES = 21 * 16; // WAVEFRONT_STRIDE in Wavefront.slang
const TILE_CAPACITY = 262144;
const WORKGROUP_SIZE = 64;
const ENTRIES = ['Initialize', 'Intersect', 'IntersectOpaque', 'Shade', 'Shadow', 'ShadowOpaque', 'Tail', 'TailOpaque', 'Finalize',
	'IntersectDirect', 'IntersectOpaqueDirect', 'ShadeDirect', 'ShadeBucket', 'ShadeBucketDirect', 'ShadeBucketCompact', 'ShadowDirect', 'ShadowOpaqueDirect',
	'CountBuckets', 'PrefixBuckets', 'ScatterBuckets',
	'CompactIntersect', 'CompactShade', 'CompactIntersectDense', 'CompactShadeDense', 'CompactIntersectSubgroup', 'CompactShadeSubgroup',
	'CompactIntersectAdaptive', 'CompactShadeAdaptive', 'CompactShadeSpatial', 'CompactIntersectPacket', 'CompactShadePacket',
	'SortMaterial64', 'SortProgram64', 'SortMaterial256', 'SortProgram256',
	'SortDirection64', 'SortDirection256',
	'ShadePrimary', 'ShadeSecondary', 'ShadeLate', 'ShadePrimaryLate', 'ShadeSecondaryLate',
	'ShadePrimaryDirect', 'ShadeSecondaryDirect', 'ShadeLateDirect', 'ShadePrimaryLateDirect', 'ShadeSecondaryLateDirect',
	'ShadowOpaqueParallel', 'ShadowOpaqueParallelDirect', 'ShadowOpaqueParallelSky', 'ShadowOpaqueParallelSkyDirect'] as const;
type Entry = typeof ENTRIES[number];
type ShadeMode = 'unified' | 'split' | 'late' | 'split-late';
type BucketMode = 'scan' | 'compact';
const PARTITION_ENTRIES: readonly Entry[] = ['CountBuckets', 'PrefixBuckets', 'ScatterBuckets'];
const BUCKET_CAPACITIES = [0, 1, 2, 4, 8, 16] as const;

export class Wavefront {
	// Experimental tuning knob for the benchmark; keep the fully staged default until measured.
	tailStart = Number.POSITIVE_INFINITY;
	tailThreshold = 0;
	compaction: 'dense' | 'queued' | 'subgroup' | 'adaptive' | 'packet' | 'none' = 'dense';
	// Internal experiment: bits 1/2/4 select direct intersection/shading/shadow dispatch.
	directStages = 0;
	// Bits select packet retention in the queues consumed by intersection/shading/shadow.
	packetStages = 7;
	// Chunk sorting experiments preserve path/RNG storage and change only shading order.
	sort: 'none' | 'material' | 'program' = 'none';
	sortSize: 64 | 256 = 64;
	// Sort continuation rays by octant, leaving camera rays in their spatial order.
	raySortSize: 0 | 64 | 256 = 0;
	// Generate exact 256-slot sort bounds in the existing work header.
	sortIndirect = false;
	// Separate primary AOV writes and/or defer unrelated state loads until after SVM.
	shadeMode: ShadeMode = 'unified';
	// Specialize shading by SVM capacity, using scans or compact ranges (experimental).
	shadeBuckets = false;
	shadeBucketMode: BucketMode = 'scan';
	// Restore physical 8x8 path neighborhoods after shading; adaptive compaction only.
	spatialQueues = false;
	// Alpha traversal retains serial feedback/RNG ordering; only opaque scenes opt in.
	shadowMode: 'serial' | 'parallel' | 'parallel-auto' = 'serial';
	readonly layout: GPUBindGroupLayout;
	readonly compiled: Promise<void>;
	private readonly pipelines = new Map<string, Map<Entry, GPUComputePipeline>>();
	private readonly compiling = new Map<string, Promise<void>>();
	private readonly pipelineLayout: GPUPipelineLayout;
	private readonly compactModule: GPUShaderModule;
	private readonly compactDenseModule: GPUShaderModule;
	private readonly compactPacketModule: GPUShaderModule;
	private readonly compactAdaptiveModule: GPUShaderModule;
	private readonly compactSpatialModule: GPUShaderModule;
	private readonly compactSubgroupModule: GPUShaderModule | null;
	private readonly sort64Module: GPUShaderModule;
	private readonly sort256Module: GPUShaderModule;
	private readonly shadowModule: GPUShaderModule;
	private destroyed = false;
	private parameters: GPUBuffer | null = null;
	private group: GPUBindGroup | null = null;
	private parameterKey = '';
	private accumulation: GPUBuffer | null = null;
	private feedback: GPUTexture | null = null;
	private readonly alignment: number;
	private readonly indirect: GPUBuffer;

	constructor(private readonly device: GPUDevice, sceneLayout: GPUBindGroupLayout, capacity: MaterialStackCapacity = 16, opcodes: MaterialOpcodeMask = ALL_MATERIAL_OPCODES, operandMode = 0) {
		this.alignment = device.limits.minUniformBufferOffsetAlignment;
		this.indirect = device.createBuffer({ label: 'wavefrontDispatch', size: 144, usage: GPUBufferUsage.INDIRECT | GPUBufferUsage.COPY_DST, mappedAtCreation: true });
		new Uint32Array(this.indirect.getMappedRange()).set([0, 1, 1, 0], 8);
		this.indirect.unmap();
		this.layout = device.createBindGroupLayout({ label: 'wavefront', entries: [
			{ binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'storage' } },
			{ binding: 1, visibility: GPUShaderStage.COMPUTE, storageTexture: { access: 'write-only', format: 'r32uint' } },
			{ binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: 'uniform', hasDynamicOffset: true, minBindingSize: 32 } },
		] });
		this.compactModule = device.createShaderModule({ label: 'WavefrontCompact', code: compactWgsl });
		this.compactDenseModule = device.createShaderModule({ label: 'WavefrontCompactDense', code: compactDenseWgsl });
		this.compactPacketModule = device.createShaderModule({ label: 'WavefrontCompactPacket', code: compactPacketWgsl });
		this.compactAdaptiveModule = device.createShaderModule({ label: 'WavefrontCompactAdaptive', code: compactAdaptiveWgsl });
		this.compactSpatialModule = device.createShaderModule({ label: 'WavefrontCompactSpatial', code: compactSpatialWgsl });
		this.sort64Module = device.createShaderModule({ label: 'WavefrontSort64', code: sort64Wgsl });
		this.sort256Module = device.createShaderModule({ label: 'WavefrontSort256', code: sort256Wgsl });
		this.shadowModule = device.createShaderModule({ label: 'WavefrontShadow', code: shadowWgsl });
		this.compactSubgroupModule = device.features.has('subgroups')
			? device.createShaderModule({ label: 'WavefrontCompactSubgroup', code: compactSubgroupWgsl }) : null;
		this.pipelineLayout = device.createPipelineLayout({ bindGroupLayouts: [sceneLayout, this.layout] });
		this.compiled = this.prepareStack(capacity, opcodes, operandMode);
	}

	async prepareStack(capacity: MaterialStackCapacity, opcodes: MaterialOpcodeMask = ALL_MATERIAL_OPCODES, operandMode = 0): Promise<void> {
		await this.prepareShadeMode(this.shadeMode, capacity, opcodes, operandMode);
	}

	// Prepare before publishing a new mode, so a renderer can keep drawing during compilation.
	async prepareShadeMode(mode: ShadeMode, capacity: MaterialStackCapacity, opcodes: MaterialOpcodeMask = ALL_MATERIAL_OPCODES, operandMode = 0): Promise<void> {
		if (!['unified', 'split', 'late', 'split-late'].includes(mode)) throw new Error('Invalid shade mode');
		await this.prepareStageGroup('unified', capacity, opcodes, operandMode);
		if (mode !== 'unified') await this.prepareStageGroup(mode, capacity, opcodes, operandMode);
	}

	async prepareBuckets(capacities: readonly MaterialStackCapacity[], globalCapacity: MaterialStackCapacity, opcodes: MaterialOpcodeMask, operandMode = 0, mode: BucketMode = this.shadeBucketMode): Promise<void> {
		if (this.destroyed) throw new Error('Wavefront has been destroyed');
		if (!['scan', 'compact'].includes(mode)) throw new Error('Invalid shading bucket mode');
		if (capacities.some(capacity => ![0, 1, 2, 4, 8, 16].includes(capacity) || capacity > globalCapacity) || new Set(capacities).size !== capacities.length)
			throw new Error('Invalid shading bucket capacities');
		if (capacities.length === 1 && capacities[0] === globalCapacity) return;
		await Promise.all([
			...capacities.map(capacity => this.prepareStageGroup(mode === 'compact' ? 'bucket-compact' : 'bucket', capacity, opcodes, operandMode)),
			...(mode === 'compact' ? [this.prepareStageGroup('partition', globalCapacity, opcodes, operandMode)] : []),
		]);
	}

	private async prepareStageGroup(mode: ShadeMode | 'bucket' | 'bucket-compact' | 'partition', capacity: MaterialStackCapacity, opcodes: MaterialOpcodeMask, operandMode: number): Promise<void> {
		if (this.destroyed) throw new Error('Wavefront has been destroyed');
		const key = materialPipelineKey(capacity, opcodes, operandMode);
		const compilationKey = `${key}/${mode}`;
		let pending = this.compiling.get(compilationKey);
		if (!pending) {
			const module = this.device.createShaderModule({ label: mode === 'partition' ? 'WavefrontBuckets' : 'Wavefront',
				code: mode === 'partition' ? bucketsWgsl : specializeMaterialShader(wavefrontWgsl, 'Wavefront', capacity) });
			const selected = ENTRIES.filter(entry => {
				if (mode === 'partition') return PARTITION_ENTRIES.includes(entry);
				if (PARTITION_ENTRIES.includes(entry)) return false;
				const phase = entry.replace(/Direct$/, '');
				const experimental = phase.startsWith('Shade') && phase !== 'Shade';
				if (mode === 'unified') return !experimental && (!entry.endsWith('Subgroup') || this.compactSubgroupModule);
				if (mode === 'bucket') return phase === 'ShadeBucket';
				if (mode === 'bucket-compact') return phase === 'ShadeBucketCompact';
				if (mode === 'late') return phase === 'ShadeLate';
				const suffix = mode === 'split-late' ? 'Late' : '';
				return phase === `ShadePrimary${suffix}` || phase === `ShadeSecondary${suffix}`;
			});
			pending = Promise.all(selected.map(async entryPoint => {
				const compact = entryPoint.startsWith('Compact');
				const sort = entryPoint.startsWith('Sort');
				const shader = entryPoint.startsWith('ShadowOpaqueParallel') ? this.shadowModule
					: sort ? (entryPoint.endsWith('64') ? this.sort64Module : this.sort256Module)
					: entryPoint.endsWith('Dense') ? this.compactDenseModule
					: entryPoint.endsWith('Packet') ? this.compactPacketModule
					: entryPoint.endsWith('Adaptive') ? this.compactAdaptiveModule
					: entryPoint.endsWith('Spatial') ? this.compactSpatialModule
					: entryPoint.endsWith('Subgroup') ? this.compactSubgroupModule! : compact ? this.compactModule : module;
				const usesMaterial = entryPoint.startsWith('Shade') || ['Tail', 'TailOpaque', 'Intersect', 'IntersectDirect', 'Shadow', 'ShadowDirect'].includes(entryPoint);
				const pipeline = await this.device.createComputePipelineAsync({ label: `wavefront.${entryPoint}.stack${capacity}`, layout: this.pipelineLayout,
					compute: { module: shader, entryPoint: sort ? entryPoint.replace(/64|256/g, '') : compact ? entryPoint.replace(/Dense|Subgroup|Adaptive|Packet|Spatial/g, '') : entryPoint,
						constants: usesMaterial ? materialPipelineConstants(capacity, opcodes, operandMode) : undefined } });
				return [entryPoint, pipeline] as const;
			})).then(entries => {
				if (this.destroyed) throw new Error('Wavefront has been destroyed');
				const pipelines = this.pipelines.get(key) ?? new Map<Entry, GPUComputePipeline>();
				for (const [entry, pipeline] of entries) pipelines.set(entry, pipeline);
				this.pipelines.set(key, pipelines);
			}).catch(error => {
				this.compiling.delete(compilationKey);
				throw error;
			});
			this.compiling.set(compilationKey, pending);
		}
		await pending;
	}

	capacity(pixels: number): number {
		const available = Math.min(this.device.limits.maxStorageBufferBindingSize, this.device.limits.maxBufferSize) - pixels * 48 - 288;
		const capacity = Math.min(TILE_CAPACITY, pixels, Math.floor(available / (RECORD_BYTES + 12)));
		if (capacity < 1) throw new Error('Image dimensions leave no room for wavefront work storage');
		return capacity;
	}

	storageBytes(pixels: number): number {
		const capacity = this.capacity(pixels);
		return 48 + capacity * RECORD_BYTES + Math.ceil(capacity / 4) * 48 + 192;
	}

	bind(accumulation: GPUBuffer, feedback: GPUTexture): void {
		this.accumulation = accumulation;
		this.feedback = feedback;
		this.parameterKey = '';
		this.group = null;
	}

	encode(encoder: GPUCommandEncoder, scene: GPUBindGroup, width: number, height: number, maxBounces: number, hasAlphaTested: boolean, materialCapacity: MaterialStackCapacity, lightCount: number, opcodes: MaterialOpcodeMask, operandMode = 0, shadeCapacities: readonly MaterialStackCapacity[] = []): void {
		if (!this.accumulation || !this.feedback) return;
		const directStages = this.compaction === 'none' ? 7 : this.directStages;
		if (!Number.isInteger(directStages) || directStages < 0 || directStages > 7) throw new Error('Invalid direct stage mask');
		const direct = directStages === 7;
		if (this.spatialQueues && (this.compaction !== 'adaptive' || direct)) throw new Error('Spatial queues require adaptive compaction');
		if (!['serial', 'parallel', 'parallel-auto'].includes(this.shadowMode)) throw new Error('Invalid shadow mode');
		if (!['unified', 'split', 'late', 'split-late'].includes(this.shadeMode)) throw new Error('Invalid shade mode');
		if (this.shadeBuckets && (this.shadeMode !== 'unified' || shadeCapacities.length === 0)) throw new Error('Shading buckets require unified mode and scene capacities');
		const useBuckets = this.shadeBuckets && !(shadeCapacities.length === 1 && shadeCapacities[0] === materialCapacity);
		if (!['scan', 'compact'].includes(this.shadeBucketMode)) throw new Error('Invalid shading bucket mode');
		if (this.shadeBuckets && this.shadeBucketMode === 'compact' && (directStages & 2) !== 0) throw new Error('Compact buckets require queued shading');
		const compactBuckets = useBuckets && this.shadeBucketMode === 'compact';
		if (!['none', 'material', 'program'].includes(this.sort) || ![64, 256].includes(this.sortSize)) throw new Error('Invalid shading sort');
		if (this.sort !== 'none' && (directStages & 2) !== 0) throw new Error('Shading sort requires queued shading');
		if (![0, 64, 256].includes(this.raySortSize)) throw new Error('Invalid ray sort size');
		if (this.raySortSize !== 0 && (directStages & 1) !== 0) throw new Error('Ray sorting requires queued intersection');
		const sortGroupSize = this.sortIndirect && ((this.sort !== 'none' && this.sortSize === 256) || this.raySortSize === 256) ? 256 : 0;
		if (this.sortIndirect && sortGroupSize === 0) throw new Error('Indirect sorting requires a 256-slot sort');
		if (!Number.isInteger(this.packetStages) || this.packetStages < 0 || this.packetStages > 7) throw new Error('Invalid packet stage mask');
		if (this.compaction === 'packet' && this.tailThreshold !== 0) throw new Error('Packet counts include inactive slots; use fixed tails');
		if (direct && this.tailThreshold !== 0) throw new Error('Direct dispatch supports fixed tails only; adaptive tails require queue counts');
		if (this.compaction === 'subgroup' && !this.compactSubgroupModule) throw new Error('Subgroup compaction requires the subgroups device feature');
		const pipelines = this.pipelines.get(materialPipelineKey(materialCapacity, opcodes, operandMode));
		if (!pipelines) throw new Error('Wavefront material pipelines have not been prepared');
		const compactSuffix = { dense: 'Dense', queued: '', subgroup: 'Subgroup', adaptive: 'Adaptive', packet: 'Packet', none: '' }[this.compaction];
		const pixels = width * height, capacity = this.capacity(pixels);
		const workItems = Math.ceil(width / 8) * Math.ceil(height / 8) * 64;
		const tiles = Math.ceil(workItems / capacity), bounces = Math.max(0, Math.floor(maxBounces));
		const key = `${width}/${height}/${bounces}/${capacity}/${this.tailThreshold}/${this.packetStages}/${sortGroupSize}`;
		if (key !== this.parameterKey) {
			this.parameters?.destroy();
			const data = new Uint32Array(tiles * (bounces + 1) * this.alignment / 4);
			for (let tile = 0; tile < tiles; tile++) {
				for (let bounce = 0; bounce <= bounces; bounce++) {
					data.set([tile * capacity, Math.min(capacity, workItems - tile * capacity), bounce, capacity, this.tailThreshold, this.packetStages, sortGroupSize],
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
			const dispatch = (entry: Entry, bounce: number, bucketCapacity?: MaterialStackCapacity) => {
				const pass = encoder.beginComputePass({ label: `wavefront.${entry}${bucketCapacity === undefined ? '' : `Bucket${compactBuckets ? 'Compact' : ''}${bucketCapacity}`}.b${bounce}` });
				const compact = entry === 'CompactIntersect' || entry === 'CompactShade';
				const spatial = entry === 'CompactShade' && this.spatialQueues;
				const directStage = (directStages & (entry === 'Intersect' ? 1 : entry === 'Shade' ? 2 : entry === 'Shadow' ? 4 : 0)) !== 0;
				let pipeline = spatial ? 'CompactShadeSpatial' as Entry : compact ? `${entry}${compactSuffix}` as Entry
					: !hasAlphaTested && (entry === 'Intersect' || entry === 'Shadow' || entry === 'Tail') ? `${entry}Opaque` as Entry : entry;
				if (pipeline === 'ShadowOpaque' && this.shadowMode !== 'serial')
					pipeline = this.shadowMode === 'parallel-auto' && lightCount === 0 ? 'ShadowOpaqueParallelSky' : 'ShadowOpaqueParallel';
				if (entry === 'Shade' && this.shadeMode !== 'unified')
					pipeline = `Shade${this.shadeMode.startsWith('split') ? (bounce === 0 ? 'Primary' : 'Secondary') : ''}${this.shadeMode.endsWith('late') ? 'Late' : ''}` as Entry;
				if (bucketCapacity !== undefined) pipeline = compactBuckets ? 'ShadeBucketCompact' : 'ShadeBucket';
				if (directStage) pipeline = `${pipeline}Direct` as Entry;
				const selected = bucketCapacity === undefined ? pipelines : this.pipelines.get(materialPipelineKey(bucketCapacity, opcodes, operandMode));
				if (!selected?.has(pipeline)) throw new Error('Shading pipelines must be prepared before encoding');
				pass.setPipeline(selected.get(pipeline)!);
				pass.setBindGroup(0, scene);
				pass.setBindGroup(1, this.group!, [(tile * (bounces + 1) + bounce) * this.alignment]);
				if (entry === 'PrefixBuckets') pass.dispatchWorkgroups(1);
				else if (bucketCapacity !== undefined && compactBuckets) {
					pass.dispatchWorkgroupsIndirect(this.indirect, 48 + BUCKET_CAPACITIES.indexOf(bucketCapacity) * 16);
				} else if (!direct && !directStage && !spatial && entry !== 'Initialize' && entry !== 'Finalize' && !(compact && (this.compaction === 'dense' || this.compaction === 'packet'))) {
					pass.dispatchWorkgroupsIndirect(this.indirect, entry === 'Shadow' ? 16 : 0);
				} else {
					pass.dispatchWorkgroups(Math.ceil(count / WORKGROUP_SIZE));
				}
				pass.end();
			};
			const copyArguments = () => {
				encoder.copyBufferToBuffer(this.accumulation!, pixels * 48 + 16, this.indirect, 0, 32);
				if (sortGroupSize !== 0) encoder.copyBufferToBuffer(this.accumulation!, pixels * 48 + 12, this.indirect, 32, 4);
			};
			const compact = (bounce: number, afterShade: boolean) => {
				// Keep the input queue count while clearing the other queue's output count.
				encoder.clearBuffer(this.accumulation!, pixels * 48 + (afterShade ? 0 : 4), 8);
				encoder.clearBuffer(this.accumulation!, pixels * 48 + 16, 4);
				encoder.clearBuffer(this.accumulation!, pixels * 48 + 32, 4);
				if (sortGroupSize !== 0) encoder.clearBuffer(this.accumulation!, pixels * 48 + 12, 4);
				dispatch(afterShade ? 'CompactShade' : 'CompactIntersect', bounce);
				copyArguments();
			};
			const sortQueue = (entry: Entry, size: 64 | 256, bounce: number) => {
				const pass = encoder.beginComputePass({ label: `wavefront.${entry}.b${bounce}` });
				pass.setPipeline(pipelines.get(entry)!);
				pass.setBindGroup(0, scene);
				pass.setBindGroup(1, this.group!, [(tile * (bounces + 1) + bounce) * this.alignment]);
				if (size === 64) pass.dispatchWorkgroupsIndirect(this.indirect, 0);
				else if (sortGroupSize !== 0) pass.dispatchWorkgroupsIndirect(this.indirect, 32);
				else pass.dispatchWorkgroups(Math.ceil(count / size));
				pass.end();
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
				if (bounce > 0 && this.raySortSize !== 0) sortQueue(`SortDirection${this.raySortSize}`, this.raySortSize, bounce);
				dispatch('Intersect', bounce);
				if (!direct) compact(bounce, false);
				if (this.sort !== 'none') {
					const entry = `Sort${this.sort === 'material' ? 'Material' : 'Program'}${this.sortSize}` as Entry;
					sortQueue(entry, this.sortSize, bounce);
				}
				if (compactBuckets) {
					// Queue C is free until CompactShade builds shadows. Preserve B for that pass.
					const metadata = pixels * 48 + 48 + capacity * RECORD_BYTES + Math.ceil(capacity / 4) * 48;
					encoder.clearBuffer(this.accumulation!, metadata, 96);
					dispatch('CountBuckets', bounce);
					dispatch('PrefixBuckets', bounce);
					dispatch('ScatterBuckets', bounce);
					encoder.copyBufferToBuffer(this.accumulation!, metadata + 96, this.indirect, 48, 96);
				}
				if (useBuckets) for (const capacity of shadeCapacities) dispatch('Shade', bounce, capacity);
				else dispatch('Shade', bounce);
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
