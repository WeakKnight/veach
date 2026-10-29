// Streaming virtual texturing with GPU feedback, after Unreal's SVT:
//   - one physical page cache (rgba8 atlas of 136^2 bordered pages) shared by every texture
//   - one r32uint page table; each entry names the finest resident page covering it
//   - the path tracer reservoir-samples one page request per pixel and writes it for one jittered
//     pixel per 4x4 tile into a feedback texture, which is read back asynchronously
//   - the host turns requests into page uploads (budgeted, prioritised), evicting LRU pages
// Texel data comes from CPU mip chains built at load time; tails are pinned so every lookup hits.
import { nextPowerOfTwo } from '../../math/Math';
import { WrapMode, type SceneDesc } from '../../scene/Scene';
import type { TextureUsage } from '../SceneMaterials';
import { PageTable, entryTile, VT_ENTRY_VALID } from './PageTable';
import { CpuTexture, buildMipChain, extractTile, type MipLevel } from './TileSource';
import { VTAddressSpace, VT_MAX_LOG2_SIZE, VT_PITCH, pageIndex, vtLevelCount, type VTTextureLayout } from './VirtualTextureLayout';

export interface VirtualTextureOptions {
	physicalTilesPerRow?: number; // physical cache = tilesPerRow^2 pages; default sized to the scene
	maxUploadsPerFrame?: number; // default 1024
	uploadBudgetMs?: number; // CPU time per frame for tile uploads, default 8
	prefetchFraction?: number; // fraction of the cache filled with coarse mips at load, default 0.25
	speculativeFill?: boolean; // spend leftover upload budget on unrequested pages (free tiles only), default true
	maxTextureSize?: number; // virtual size cap per dimension (power of two)
}

export interface VirtualTextureUpdate {
	mapped: number;
	feedbackFrames: number; // completed readbacks consumed by this update
	pendingFeedback: boolean; // readbacks still in flight; an idle CPU frame is not settled feedback
	// Fraction of this round's feedback samples that requested the newly mapped pages (~ screen share).
	coverage: number;
}

export interface VirtualTextureDescriptor {
	pageTableOffset: number;
	log2W: number;
	log2H: number;
	levels: number;
}

export interface VirtualTextureStats {
	textures: number;
	physicalPages: number;
	residentPages: number;
	pendingRequests: number;
	uploadsLastFrame: number;
	totalUploads: number;
	evictions: number;
}

interface VTTexture {
	layout: VTTextureLayout;
	chain: MipLevel[];
	wrapS: WrapMode;
	wrapT: WrapMode;
	srgb: boolean;
}

interface StagingBuffer {
	buffer: GPUBuffer;
	state: 'idle' | 'recorded' | 'mapping';
	width: number;
	height: number;
	bytesPerRow: number;
}

// Pixel offsets inside a 4x4 feedback tile, visited in a stratified order.
const FEEDBACK_JITTER = [0, 10, 2, 8, 5, 15, 7, 13, 1, 11, 3, 9, 4, 14, 6, 12];
export const VT_FEEDBACK_PERIOD = FEEDBACK_JITTER.length;
export const VT_FEEDBACK_SHIFT = 2;

// Decodes an image to tightly packed RGBA8 at a power-of-two size, exactly (no premultiplication).
export async function decodeImages(device: GPUDevice, images: ImageBitmap[], maxSize: number): Promise<MipLevel[]> {
	const jobs = await Promise.all(
		images.map(async (image) => {
			const width = Math.min(nextPowerOfTwo(image.width), maxSize);
			const height = Math.min(nextPowerOfTwo(image.height), maxSize);
			const source =
				width === image.width && height === image.height
					? image
					: await createImageBitmap(image, { resizeWidth: width, resizeHeight: height, resizeQuality: 'high', premultiplyAlpha: 'none', colorSpaceConversion: 'none' });
			const texture = device.createTexture({
				size: [width, height],
				format: 'rgba8unorm',
				usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.COPY_SRC | GPUTextureUsage.RENDER_ATTACHMENT,
			});
			device.queue.copyExternalImageToTexture({ source }, { texture, premultipliedAlpha: false }, [width, height]);
			if (source !== image) source.close();
			const bytesPerRow = Math.ceil((width * 4) / 256) * 256;
			const buffer = device.createBuffer({ size: bytesPerRow * height, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
			const encoder = device.createCommandEncoder();
			encoder.copyTextureToBuffer({ texture }, { buffer, bytesPerRow }, [width, height]);
			device.queue.submit([encoder.finish()]);
			texture.destroy();
			return { width, height, bytesPerRow, buffer };
		}),
	);
	return Promise.all(
		jobs.map(async ({ width, height, bytesPerRow, buffer }) => {
			await buffer.mapAsync(GPUMapMode.READ);
			const src = new Uint8Array(buffer.getMappedRange());
			const data = new Uint8Array(width * height * 4);
			for (let y = 0; y < height; y++) {
				data.set(src.subarray(y * bytesPerRow, y * bytesPerRow + width * 4), y * width * 4);
			}
			buffer.unmap();
			buffer.destroy();
			return { width, height, data };
		}),
	);
}

export class VirtualTextureSystem {
	readonly physical: GPUTexture;
	readonly pageTable: GPUTexture;
	readonly pageTableWidth: number;
	readonly tilesPerRow: number;

	private readonly space = new VTAddressSpace();
	private readonly table: PageTable;
	private readonly textures: VTTexture[] = [];
	private readonly sourceToTexture: (number | null)[] = [];

	private readonly tileCount: number;
	private readonly tileOwner: Int32Array; // page index, -1 = free
	private readonly tileLastUsed: Uint32Array;
	private readonly tilePinned: Uint8Array;
	private readonly freeTiles: number[] = [];
	private readonly resident = new Map<number, number>(); // page index -> tile
	private readonly maxUploadsPerFrame: number;
	private readonly uploadBudgetMs: number;
	private readonly speculativeFill: boolean;
	private readonly fillOrder: Int32Array; // all non-tail pages, coarse to fine
	private fillCursor = 0;

	private readonly staging: StagingBuffer[] = [];
	private readonly feedbackQueue: Uint32Array[] = [];
	private readonly tileScratch = new Uint8Array(VT_PITCH * VT_PITCH * 4);
	private frame = 2;
	private jitterIndex = 0;
	private destroyed = false;
	readonly stats: VirtualTextureStats;

	private constructor(
		private readonly device: GPUDevice,
		textures: { base: MipLevel; wrapS: WrapMode; wrapT: WrapMode; srgb: boolean; source: number }[],
		sourceCount: number,
		options: VirtualTextureOptions,
	) {
		this.maxUploadsPerFrame = options.maxUploadsPerFrame ?? 1024;
		this.uploadBudgetMs = options.uploadBudgetMs ?? 8;
		for (let i = 0; i < sourceCount; i++) this.sourceToTexture.push(null);
		for (const t of textures) {
			const log2W = Math.log2(t.base.width);
			const log2H = Math.log2(t.base.height);
			const layout = this.space.add(log2W, log2H);
			this.sourceToTexture[t.source] = this.textures.length;
			this.textures.push({ layout, chain: buildMipChain(t.base, vtLevelCount(log2W, log2H), t.srgb), wrapS: t.wrapS, wrapT: t.wrapT, srgb: t.srgb });
		}

		// Default cache: room for every virtual page if possible (no streaming churn), capped at 40x40
		// pages (~118 MB); at least 16x16.
		const maxPerRow = Math.floor(device.limits.maxTextureDimension2D / VT_PITCH);
		const virtualPages = this.textures.reduce((n, t) => n + t.layout.entryCount, 0);
		const perRow = options.physicalTilesPerRow ?? Math.min(Math.max(Math.ceil(Math.sqrt(virtualPages)), 16), 40);
		this.tilesPerRow = Math.min(Math.max(perRow, Math.ceil(Math.sqrt(this.textures.length + 64))), maxPerRow);
		this.tileCount = this.tilesPerRow * this.tilesPerRow;
		if (this.tileCount <= this.textures.length) {
			throw new Error(`Virtual texture cache too small for ${this.textures.length} textures`);
		}
		this.physical = device.createTexture({
			label: 'vtPhysical',
			size: [this.tilesPerRow * VT_PITCH, this.tilesPerRow * VT_PITCH],
			format: 'rgba8unorm',
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
		});

		this.pageTableWidth = Math.min(4096, Math.max(this.space.entryCount, 1));
		const pageTableHeight = Math.ceil(Math.max(this.space.entryCount, 1) / this.pageTableWidth);
		this.table = new PageTable(this.pageTableWidth * pageTableHeight);
		this.pageTable = device.createTexture({
			label: 'vtPageTable',
			size: [this.pageTableWidth, pageTableHeight],
			format: 'r32uint',
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
		});

		this.tileOwner = new Int32Array(this.tileCount).fill(-1);
		this.tileLastUsed = new Uint32Array(this.tileCount);
		this.tilePinned = new Uint8Array(this.tileCount);
		for (let t = this.tileCount - 1; t >= 0; t--) this.freeTiles.push(t);

		this.stats = { textures: this.textures.length, physicalPages: this.tileCount, residentPages: 0, pendingRequests: 0, uploadsLastFrame: 0, totalUploads: 0, evictions: 0 };

		for (const tex of this.textures) {
			const tail = tex.layout.levels - 1;
			const tile = this.freeTiles.pop()!;
			this.tilePinned[tile] = 1;
			this.mapPage(tex, tail, 0, 0, tile);
		}
		this.fillOrder = this.buildFillOrder();
		this.speculativeFill = options.speculativeFill ?? true;
		this.fill(Math.floor(this.tileCount * (options.prefetchFraction ?? 0.25)), Infinity);
		this.stats.residentPages = this.resident.size;
		this.flushPageTable();
	}

	// usage: color space and wrap modes of every texture the materials sample (SceneMaterials.textureUsage).
	static async create(device: GPUDevice, scene: SceneDesc, usage: ReadonlyMap<number, TextureUsage>, options: VirtualTextureOptions = {}): Promise<VirtualTextureSystem> {
		const maxSize = Math.min(options.maxTextureSize ?? 4096, 1 << VT_MAX_LOG2_SIZE, device.limits.maxTextureDimension2D);
		const sources = scene.textures.map((t, i) => ({ image: t.image, source: i })).filter((t) => t.image && t.image.width > 0 && t.image.height > 0 && usage.has(t.source));
		const decoded = await decodeImages(device, sources.map((s) => s.image!), maxSize);
		const textures = sources.map((s, i) => ({ base: decoded[i], source: s.source, ...usage.get(s.source)! }));
		return new VirtualTextureSystem(device, textures, scene.textures.length, options);
	}

	descriptorOf = (source: number): VirtualTextureDescriptor | null => {
		const t = this.sourceToTexture[source];
		if (t === null || t === undefined) return null;
		const l = this.textures[t].layout;
		return { pageTableOffset: l.pageTableOffset, log2W: l.log2W, log2H: l.log2H, levels: l.levels };
	};

	// Tail mip on the CPU, for host-side estimates (emissive power).
	cpuTexture(source: number): CpuTexture | null {
		const t = this.sourceToTexture[source];
		if (t === null || t === undefined) return null;
		const chain = this.textures[t].chain;
		return new CpuTexture(chain[chain.length - 1]);
	}

	get invPhysicalSize(): number {
		return 1 / (this.tilesPerRow * VT_PITCH);
	}

	// Feedback pixel inside each 4x4 tile for the next dispatch, packed as x | y << 16.
	nextFeedbackJitter(): number {
		const j = FEEDBACK_JITTER[this.jitterIndex++ % FEEDBACK_JITTER.length];
		return (j & 3) | ((j >> 2) << 16);
	}

	private mapPage(tex: VTTexture, level: number, px: number, py: number, tile: number): void {
		extractTile(tex.chain[level], px, py, tex.wrapS, tex.wrapT, this.tileScratch);
		this.device.queue.writeTexture(
			{ texture: this.physical, origin: [(tile % this.tilesPerRow) * VT_PITCH, Math.floor(tile / this.tilesPerRow) * VT_PITCH] },
			this.tileScratch,
			{ bytesPerRow: VT_PITCH * 4 },
			[VT_PITCH, VT_PITCH],
		);
		const index = pageIndex(tex.layout, level, px, py);
		this.table.map(tex.layout, level, px, py, tile);
		this.resident.set(index, tile);
		this.tileOwner[tile] = index;
		this.tileLastUsed[tile] = this.frame;
		this.stats.totalUploads++;
	}

	private evict(tile: number): void {
		const owner = this.tileOwner[tile];
		const addr = this.space.decode(owner);
		if (addr) {
			this.table.unmap(addr.layout, addr.level, addr.px, addr.py);
		}
		this.resident.delete(owner);
		this.tileOwner[tile] = -1;
		this.stats.evictions++;
	}

	private flushPageTable(): void {
		const t = this.table;
		if (t.dirtyMax < 0) return;
		const w = this.pageTableWidth;
		const row0 = Math.floor(t.dirtyMin / w);
		const row1 = Math.floor(t.dirtyMax / w);
		this.device.queue.writeTexture(
			{ texture: this.pageTable, origin: [0, row0] },
			t.entries.subarray(row0 * w, (row1 + 1) * w),
			{ bytesPerRow: w * 4 },
			[w, row1 - row0 + 1],
		);
		t.clearDirty();
	}

	// Consumes completed feedback and streams pages within the per-frame upload budget.
	update(): VirtualTextureUpdate {
		const requests = new Map<number, number>();
		const feedbacks = this.feedbackQueue.splice(0);
		// Age residency by observed feedback, not CPU frames while readback is still in flight.
		this.frame += feedbacks.length;
		let feedbackTexels = 0;
		for (const feedback of feedbacks) {
			feedbackTexels += feedback.length;
			for (let i = 0; i < feedback.length; i++) {
				const v = feedback[i];
				if (v === 0) continue;
				const index = v - 1;
				if (index >= this.space.entryCount) continue;
				const tile = this.resident.get(index);
				if (tile !== undefined) {
					this.tileLastUsed[tile] = this.frame;
					continue;
				}
				const fallback = this.table.entries[index];
				if (fallback & VT_ENTRY_VALID) this.tileLastUsed[entryTile(fallback)] = this.frame;
				requests.set(index, (requests.get(index) ?? 0) + 1);
			}
		}

		// Most requested first; coarser levels break ties since they cover more texels.
		const ordered = [...requests.entries()]
			.map(([index, count]) => ({ index, count, addr: this.space.decode(index)! }))
			.sort((a, b) => b.count - a.count || b.addr.level - a.addr.level);

		let evictable: number[] | null = null;
		let mapped = 0;
		let mappedRequests = 0;
		const deadline = performance.now() + this.uploadBudgetMs;
		for (const req of ordered) {
			if (mapped >= this.maxUploadsPerFrame || (mapped > 0 && performance.now() > deadline)) break;
			let tile = this.freeTiles.pop();
			if (tile === undefined) {
				// A full jitter cycle is needed to revisit all 4x4 pixel offsets.
				evictable ??= Array.from({ length: this.tileCount }, (_, t) => t)
					.filter((t) => !this.tilePinned[t] && this.tileOwner[t] >= 0 && (this.tileLastUsed[t] === 0 || this.tileLastUsed[t] + VT_FEEDBACK_PERIOD < this.frame))
					.sort((a, b) => this.tileLastUsed[b] - this.tileLastUsed[a]);
				tile = evictable.pop();
				if (tile === undefined) break;
				this.evict(tile);
			}
			const tex = this.textures[req.addr.layout.id];
			this.mapPage(tex, req.addr.level, req.addr.px, req.addr.py, tile);
			mapped++;
			mappedRequests += req.count;
		}
		if (feedbacks.length > 0) this.stats.pendingRequests = requests.size - mapped;
		const filled = this.speculativeFill && this.stats.pendingRequests === 0 ? this.fill(this.maxUploadsPerFrame - mapped, deadline) : 0;
		this.flushPageTable();
		this.stats.residentPages = this.resident.size;
		this.stats.uploadsLastFrame = mapped + filled;
		return {
			mapped, coverage: mappedRequests / Math.max(feedbackTexels, 1),
			feedbackFrames: feedbacks.length,
			pendingFeedback: this.staging.some((s) => s.state !== 'idle'),
		};
	}

	// Speculatively maps pages nobody requested yet, coarsest mips first (interleaved across textures),
	// into free tiles only. Pages never seen by feedback (rare bounce hits) load without waiting for it.
	// Not pinned and never touched, so LRU evicts them first under pressure.
	private fill(maxPages: number, deadline: number): number {
		let mapped = 0;
		while (this.fillCursor < this.fillOrder.length && mapped < maxPages && this.freeTiles.length > 0) {
			if (mapped > 0 && performance.now() > deadline) break;
			const index = this.fillOrder[this.fillCursor++];
			if (this.resident.has(index)) continue;
			const addr = this.space.decode(index)!;
			this.mapPage(this.textures[addr.layout.id], addr.level, addr.px, addr.py, this.freeTiles.pop()!);
			this.tileLastUsed[this.resident.get(index)!] = 0;
			mapped++;
		}
		return mapped;
	}

	private buildFillOrder(): Int32Array {
		const order: number[] = [];
		const maxLevels = Math.max(0, ...this.textures.map((t) => t.layout.levels));
		for (let k = 1; k < maxLevels; k++) {
			for (const tex of this.textures) {
				const level = tex.layout.levels - 1 - k;
				if (level < 0) continue;
				const n = tex.layout.pagesX[level] * tex.layout.pagesY[level];
				const first = pageIndex(tex.layout, level, 0, 0);
				for (let i = 0; i < n; i++) order.push(first + i);
			}
		}
		return Int32Array.from(order);
	}

	// Records a copy of the feedback texture into a free staging buffer; call afterSubmit() next.
	recordFeedbackReadback(encoder: GPUCommandEncoder, feedback: GPUTexture): void {
		const width = feedback.width;
		const height = feedback.height;
		const bytesPerRow = Math.ceil((width * 4) / 256) * 256;
		let staging = this.staging.find((s) => s.state === 'idle' && s.buffer.size >= bytesPerRow * height);
		if (!staging) {
			if (this.staging.length >= 3) {
				const idle = this.staging.findIndex((s) => s.state === 'idle');
				if (idle < 0) return; // all in flight: skip this frame's feedback
				this.staging[idle].buffer.destroy();
				this.staging.splice(idle, 1);
			}
			staging = {
				buffer: this.device.createBuffer({ label: 'vtFeedbackStaging', size: bytesPerRow * height, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ }),
				state: 'idle',
				width,
				height,
				bytesPerRow,
			};
			this.staging.push(staging);
		}
		staging.width = width;
		staging.height = height;
		staging.bytesPerRow = bytesPerRow;
		encoder.copyTextureToBuffer({ texture: feedback }, { buffer: staging.buffer, bytesPerRow }, [width, height]);
		staging.state = 'recorded';
	}

	afterSubmit(): void {
		for (const s of this.staging) {
			if (s.state !== 'recorded') continue;
			s.state = 'mapping';
			s.buffer
				.mapAsync(GPUMapMode.READ)
				.then(() => {
					if (this.destroyed) return;
					const src = new Uint32Array(s.buffer.getMappedRange());
					const rowWords = s.bytesPerRow / 4;
					const out = new Uint32Array(s.width * s.height);
					for (let y = 0; y < s.height; y++) {
						out.set(src.subarray(y * rowWords, y * rowWords + s.width), y * s.width);
					}
					s.buffer.unmap();
					s.state = 'idle';
					this.feedbackQueue.push(out);
				})
				.catch(() => {
					s.state = 'idle';
				});
		}
	}

	destroy(): void {
		this.destroyed = true;
		this.physical.destroy();
		this.pageTable.destroy();
		for (const s of this.staging) s.buffer.destroy();
	}
}
