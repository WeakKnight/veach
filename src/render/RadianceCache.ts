// Radiance cache host (docs/RadianceCache.md): dense, toroidally addressed probe clipmaps around the camera, the
// fallback of screen-space reflections. RadianceCacheScheduler (pure, tested) decides which probe slots to trace each
// frame; RadianceCache owns the GPU buffers and the probe trace pipeline (Passes/RadianceCache.slang).
import code from '../generated/shaders/RadianceCache.wgsl?raw';
import type { Vec3 } from '../math/Math';
import { materialPipelineConstants, type MaterialOpcodeMask } from './MaterialProgramFeatures';
import { specializeMaterialShader, type MaterialStackCapacity } from './MaterialShaderVariants';
import type { PipelineCompiler } from './PipelineCompiler';

export const RADIANCE_CACHE_PROBE_RESOLUTION = 8;
export const RADIANCE_CACHE_MAX_CLIPMAPS = 4;
export const RADIANCE_CACHE_MAX_UPDATES = 1024;
export const RADIANCE_CACHE_CONSTANTS_BYTES = 176;
const HEADER_WORDS = 4;
export const radianceCacheProbeWords = (probeResolution = RADIANCE_CACHE_PROBE_RESOLUTION) => HEADER_WORDS + 2 * probeResolution * probeResolution;

export interface RadianceCacheOptions {
	clipmaps: number; // 1..4
	resolution: number; // probes per clipmap axis (even)
	cellSize: number; // clipmap 0 cell size, world units; clipmap c has cellSize * 2^c
	probesPerFrame: number; // trace budget, <= RADIANCE_CACHE_MAX_UPDATES
	maxBounces: number;
}

// Share of the refresh budget (after newly covered probes) per clipmap: finer clipmaps change faster on screen.
const REFRESH_SHARE = [0.4, 0.3, 0.2, 0.1];
// A probe's first traces are one path per texel each: it is traced again on the next frames until it has this many,
// before the round robin, so probes that just scrolled in are not noisy (black blocks in moving reflections).
export const RADIANCE_CACHE_YOUNG_TRACES = 4;

const posMod = (a: number, b: number) => ((a % b) + b) % b;

/**
 * Which slots to trace: slots whose world cell is new (first frame, clipmap scroll, reset) first, interleaved over
 * clipmaps from the window center outward, then young slots (fewer than RADIANCE_CACHE_YOUNG_TRACES traces since their
 * cell became new), then a per-clipmap round robin over every slot. A slot appears at most once per frame.
 */
export class RadianceCacheScheduler {
	readonly origins: ([number, number, number] | null)[];
	private readonly pending: number[][]; // per clipmap, slots whose world cell is new, nearest first
	private readonly queued: Set<number>[];
	private readonly cursors: number[];
	private readonly young: number[] = []; // slots traced fewer than RADIANCE_CACHE_YOUNG_TRACES times, oldest first
	private readonly traces: Uint8Array; // traces since the slot's cell became new, saturating

	constructor(readonly clipmaps: number, readonly resolution: number, readonly cellSize: number) {
		if (clipmaps < 1 || clipmaps > RADIANCE_CACHE_MAX_CLIPMAPS) throw new Error(`Radiance cache clipmaps must be 1..${RADIANCE_CACHE_MAX_CLIPMAPS}`);
		if (resolution < 2 || resolution % 2 !== 0 || resolution > 64) throw new Error('Radiance cache resolution must be even, 2..64');
		this.origins = Array.from({ length: clipmaps }, () => null);
		this.pending = Array.from({ length: clipmaps }, () => []);
		this.queued = Array.from({ length: clipmaps }, () => new Set());
		this.cursors = Array.from({ length: clipmaps }, () => 0);
		this.traces = new Uint8Array(clipmaps * resolution ** 3);
	}

	get probesPerClipmap(): number { return this.resolution ** 3; }
	clipmapCellSize(clipmap: number): number { return this.cellSize * 2 ** clipmap; }

	/** World cell of the window's minimum corner for a camera position: the camera sits at the window center. */
	windowOrigin(clipmap: number, camera: Vec3): [number, number, number] {
		const size = this.clipmapCellSize(clipmap), half = this.resolution / 2;
		return [0, 1, 2].map(i => Math.floor(camera[i] / size) - half) as [number, number, number];
	}

	slot(clipmap: number, cell: readonly number[]): number {
		const R = this.resolution;
		return clipmap * R ** 3 + (posMod(cell[2], R) * R + posMod(cell[1], R)) * R + posMod(cell[0], R);
	}

	/** Moves the windows with the camera; slots whose world cell changed become pending. */
	follow(camera: Vec3): void {
		const R = this.resolution;
		for (let c = 0; c < this.clipmaps; c++) {
			const origin = this.windowOrigin(c, camera), old = this.origins[c];
			if (old && origin.every((v, i) => v === old[i])) continue;
			const fresh: { slot: number; distance: number }[] = [];
			for (let z = 0; z < R; z++) for (let y = 0; y < R; y++) for (let x = 0; x < R; x++) {
				const cell = [origin[0] + x, origin[1] + y, origin[2] + z];
				if (old && cell.every((v, i) => v >= old[i] && v < old[i] + R)) continue;
				fresh.push({ slot: this.slot(c, cell), distance: Math.max(Math.abs(x + 0.5 - R / 2), Math.abs(y + 0.5 - R / 2), Math.abs(z + 0.5 - R / 2)) });
			}
			fresh.sort((a, b) => a.distance - b.distance);
			// Newly covered cells go before older pending ones, which may be off screen by now.
			const queue = fresh.map(f => f.slot).filter(slot => !this.queued[c].has(slot));
			for (const slot of queue) this.queued[c].add(slot);
			for (const f of fresh) this.traces[f.slot] = 0;
			this.pending[c] = [...queue, ...this.pending[c]];
			this.origins[c] = origin;
		}
	}

	/** Every slot's history is gone (new scene, cleared storage): all slots pending again. */
	invalidate(): void {
		for (let c = 0; c < this.clipmaps; c++) { this.origins[c] = null; this.pending[c] = []; this.queued[c].clear(); }
		this.young.length = 0;
		this.traces.fill(0);
	}

	/** Number of slots still waiting for their first trace. */
	get pendingCount(): number { return this.pending.reduce((sum, p) => sum + p.length, 0); }

	/** Number of slots that have been traced but not yet RADIANCE_CACHE_YOUNG_TRACES times. */
	get youngCount(): number { return this.young.length; }

	/** Slots to trace this frame, at most `budget`. */
	next(budget: number): number[] {
		const out: number[] = [], taken = new Set<number>();
		const traced = (slot: number) => {
			out.push(slot); taken.add(slot);
			const count = this.traces[slot] = Math.min(255, this.traces[slot] + 1);
			if (count < RADIANCE_CACHE_YOUNG_TRACES) this.young.push(slot);
		};
		// Pending slots, interleaved over clipmaps so coarse clipmaps cover the camera early.
		for (let progress = true; out.length < budget && progress;) {
			progress = false;
			for (let c = 0; c < this.clipmaps && out.length < budget; c++) {
				const slot = this.pending[c].shift();
				if (slot === undefined) continue;
				this.queued[c].delete(slot);
				traced(slot); progress = true;
			}
		}
		// Young slots, oldest first; one that scrolled out and back in since is pending again and skipped here.
		for (let n = this.young.length; n > 0 && out.length < budget; n--) {
			const slot = this.young.shift()!;
			const c = Math.floor(slot / this.probesPerClipmap);
			if (taken.has(slot) || this.queued[c].has(slot) || this.traces[slot] >= RADIANCE_CACHE_YOUNG_TRACES || this.traces[slot] === 0) continue;
			traced(slot);
		}
		// Round robin refresh with the rest.
		const rest = budget - out.length, perClipmap = this.probesPerClipmap;
		if (rest > 0) {
			const shares = REFRESH_SHARE.slice(0, this.clipmaps), total = shares.reduce((a, b) => a + b, 0);
			let remaining = rest;
			for (let c = 0; c < this.clipmaps; c++) {
				const count = c === this.clipmaps - 1 ? remaining : Math.min(remaining, Math.floor(rest * shares[c] / total));
				remaining -= count;
				for (let i = 0; i < count && i < perClipmap; i++) {
					const slot = c * perClipmap + this.cursors[c];
					this.cursors[c] = (this.cursors[c] + 1) % perClipmap;
					if (!taken.has(slot) && !this.queued[c].has(slot)) traced(slot);
				}
			}
		}
		return out;
	}
}

export interface RadianceCacheScene {
	layout: GPUBindGroupLayout; // PathTracer scene layout (group 0)
	bindGroup: GPUBindGroup;
	capacity: MaterialStackCapacity;
	opcodes: MaterialOpcodeMask;
	operandMode: number;
}
export interface RadianceCacheStats { active: boolean; reason: string | null; probes: number; pending: number; traced: number; bytes: number; cellSize: number }

/** GPU side: probe storage, constants and the trace pipeline. */
export class RadianceCache {
	stats: RadianceCacheStats = { active: false, reason: 'not-rendered', probes: 0, pending: 0, traced: 0, bytes: 0, cellSize: 0 };
	readonly constants: GPUBuffer;
	private readonly updates: GPUBuffer;
	private probes: GPUBuffer | null = null;
	private scheduler: RadianceCacheScheduler | null = null;
	private options: RadianceCacheOptions | null = null;
	private readonly layout: GPUBindGroupLayout;
	private readonly pipelines = new Map<string, GPUComputePipeline | 'pending' | 'failed'>();
	private frame = 0;

	constructor(private readonly device: GPUDevice, private readonly compiler: PipelineCompiler | null = null) {
		this.constants = device.createBuffer({ label: 'radianceCache.constants', size: RADIANCE_CACHE_CONSTANTS_BYTES, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
		this.updates = device.createBuffer({ label: 'radianceCache.updates', size: RADIANCE_CACHE_MAX_UPDATES * 4, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
		const C = GPUShaderStage.COMPUTE;
		this.layout = device.createBindGroupLayout({ label: 'radianceCache', entries: [
			{ binding: 2, visibility: C, buffer: { type: 'uniform' } }, { binding: 3, visibility: C, buffer: { type: 'storage' } }, { binding: 4, visibility: C, buffer: { type: 'uniform' } },
		] });
	}

	/** Probe storage for lookups (SSSR); null until configured. */
	get probeBuffer(): GPUBuffer | null { return this.probes; }

	/** (Re)creates storage when the layout changes; every probe starts invalid. */
	configure(options: RadianceCacheOptions): void {
		const o = this.options;
		if (o && o.clipmaps === options.clipmaps && o.resolution === options.resolution && o.cellSize === options.cellSize) { this.options = options; return; }
		this.probes?.destroy();
		this.scheduler = new RadianceCacheScheduler(options.clipmaps, options.resolution, options.cellSize);
		const words = options.clipmaps * options.resolution ** 3 * radianceCacheProbeWords();
		const bytes = words * 4;
		if (bytes > this.device.limits.maxStorageBufferBindingSize) throw new Error(`Radiance cache needs ${bytes} bytes; maxStorageBufferBindingSize is ${this.device.limits.maxStorageBufferBindingSize}`);
		this.probes = this.device.createBuffer({ label: 'radianceCache.probes', size: bytes, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST });
		this.options = options;
	}

	/** Discards every probe (new scene, new lighting setup): lookups fall back until probes are traced again. */
	invalidate(encoder?: GPUCommandEncoder): void {
		if (!this.probes || !this.scheduler) return;
		if (encoder) encoder.clearBuffer(this.probes); else {
			const e = this.device.createCommandEncoder({ label: 'radianceCache.invalidate' });
			e.clearBuffer(this.probes);
			this.device.queue.submit([e.finish()]);
		}
		this.scheduler.invalidate();
	}

	private pipeline(scene: RadianceCacheScene): GPUComputePipeline | null {
		const key = `${scene.capacity}/${scene.opcodes.join(',')}/${scene.operandMode}`;
		const entry = this.pipelines.get(key);
		if (entry === 'failed') throw new Error('Radiance cache pipeline failed to compile');
		if (entry && entry !== 'pending') return entry;
		if (!entry) {
			this.pipelines.set(key, 'pending');
			const module = this.device.createShaderModule({ label: 'RadianceCache', code: specializeMaterialShader(code, 'RadianceCache', scene.capacity) });
			const descriptor: GPUComputePipelineDescriptor = { label: `radianceCache.trace.stack${scene.capacity}`,
				layout: this.device.createPipelineLayout({ bindGroupLayouts: [scene.layout, this.layout] }),
				compute: { module, entryPoint: 'TraceProbes', constants: materialPipelineConstants(scene.capacity, scene.opcodes, scene.operandMode) } };
			(this.compiler ? this.compiler.compute(descriptor) : this.device.createComputePipelineAsync(descriptor))
				.then(pipeline => this.pipelines.set(key, pipeline), error => { console.error('Radiance cache pipeline:', error); this.pipelines.set(key, 'failed'); });
		}
		return null;
	}

	/** Follows the camera and traces this frame's probes. Returns false while the pipeline compiles. */
	encode(encoder: GPUCommandEncoder, scene: RadianceCacheScene, camera: Vec3, normalBias: number, maxRadiance: number): boolean {
		const options = this.options, scheduler = this.scheduler;
		if (!options || !scheduler || !this.probes) throw new Error('Radiance cache is not configured');
		const pipeline = this.pipeline(scene);
		scheduler.follow(camera);
		this.writeConstants(normalBias, maxRadiance, 0);
		if (!pipeline) { this.stats = { ...this.stats, active: false, reason: 'compiling' }; return false; }
		const slots = scheduler.next(Math.min(options.probesPerFrame, RADIANCE_CACHE_MAX_UPDATES));
		this.writeConstants(normalBias, maxRadiance, slots.length);
		if (slots.length) {
			this.device.queue.writeBuffer(this.updates, 0, Uint32Array.from(slots));
			const pass = encoder.beginComputePass({ label: 'radianceCache.trace' });
			pass.setPipeline(pipeline);
			pass.setBindGroup(0, scene.bindGroup);
			pass.setBindGroup(1, this.device.createBindGroup({ label: 'radianceCache', layout: this.layout, entries: [
				{ binding: 2, resource: { buffer: this.constants } }, { binding: 3, resource: { buffer: this.probes } }, { binding: 4, resource: { buffer: this.updates } },
			] }));
			pass.dispatchWorkgroups(slots.length);
			pass.end();
		}
		this.frame++;
		this.stats = { active: true, reason: null, probes: options.clipmaps * options.resolution ** 3, pending: scheduler.pendingCount, traced: slots.length,
			bytes: this.probes.size + RADIANCE_CACHE_CONSTANTS_BYTES + RADIANCE_CACHE_MAX_UPDATES * 4, cellSize: options.cellSize };
		return true;
	}

	suspend(reason: string): void { this.stats = { ...this.stats, active: false, reason, traced: 0 }; }

	private writeConstants(normalBias: number, maxRadiance: number, updates: number): void {
		const o = this.options!, s = this.scheduler!;
		const data = new ArrayBuffer(RADIANCE_CACHE_CONSTANTS_BYTES), f = new Float32Array(data), i = new Int32Array(data), u = new Uint32Array(data);
		for (let c = 0; c < o.clipmaps; c++) {
			const size = s.clipmapCellSize(c), origin = s.origins[c] ?? [0, 0, 0];
			f.set([origin[0] * size, origin[1] * size, origin[2] * size, size], c * 4);
			i.set(origin, 16 + c * 4);
		}
		u.set([o.resolution, RADIANCE_CACHE_PROBE_RESOLUTION, o.clipmaps, radianceCacheProbeWords()], 32);
		f.set([normalBias, maxRadiance, 0, 0], 36);
		u.set([this.frame, updates, o.maxBounces, 0], 40);
		this.device.queue.writeBuffer(this.constants, 0, data);
	}

	destroy(): void { this.probes?.destroy(); this.constants.destroy(); this.updates.destroy(); }
}

/** Clipmap 0 cell size for a scene: 1/96 of its bounding box diagonal (clipmap 3 then spans ~2 diagonals at R = 24). */
export function radianceCacheCellSize(boundsMin: Vec3, boundsMax: Vec3): number {
	const diagonal = Math.hypot(boundsMax[0] - boundsMin[0], boundsMax[1] - boundsMin[1], boundsMax[2] - boundsMin[2]);
	return Number.isFinite(diagonal) && diagonal > 0 ? Math.max(diagonal / 96, 1e-3) : 0.25;
}

