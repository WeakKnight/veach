import { nextPowerOfTwo } from '../../math/Math';
import type { ColorSpace } from '../../material/Graph';
import type { ResourceTextureBinding, SceneSnapshot, TextureHandle, TextureResource } from '../../scene/RenderScene';
import { WrapMode } from '../../scene/Scene';
import type { HostTextureAccess } from '../HostGpuScene';
import { PageTable, entryTile, VT_ENTRY_VALID } from './PageTable';
import { buildMipChain, CpuTexture, extractTile, type MipLevel } from './TileSource';
import { layoutTexture, pageIndex, VT_PITCH, type VTTextureLayout } from './VirtualTextureLayout';
import { decodeImages, type VirtualTextureOptions, type VirtualTextureStats, type VirtualTextureUpdate } from './VirtualTextureSystem';
import type { SceneTextures } from './SceneTextures';

interface Variant { id: number; key: string; resource: TextureResource; layout: VTTextureLayout; chain: MipLevel[]; wrapS: WrapMode; wrapT: WrapMode }
interface Address { variant: Variant; level: number; px: number; py: number }
interface Readback { buffer: GPUBuffer; state: 'idle' | 'recorded' | 'mapping'; width: number; height: number; stride: number; epoch: number }
const keys = ['baseColorMap', 'metallicMap', 'roughnessMap', 'normalMap', 'emissionMap', 'opacityMap'] as const;
const wrap = (v: ResourceTextureBinding['wrapU']) => v === 'clamp' ? WrapMode.Clamp : v === 'mirror' ? WrapMode.Mirror : WrapMode.Repeat;
const variantKey = (b: ResourceTextureBinding) => `${b.texture}/${wrap(b.wrapU)}/${wrap(b.wrapV)}`;

export interface PreparedHostTextures extends HostTextureAccess {
	resolve(binding: ResourceTextureBinding): { source: number; colorSpace: ColorSpace };
	publish(): void;
	discard(): void;
}

/** Persistent virtual textures: independent sources/wrap variants, pinned mip tails and LRU
 * streaming. Publication epochs discard stale feedback when virtual addresses are recycled. */
export class HostTextureSystem implements SceneTextures {
	readonly physical: GPUTexture;
	pageTable: GPUTexture;
	readonly pageTableWidth = 1024;
	readonly tilesPerRow: number;
	readonly stats: VirtualTextureStats;
	private table = new PageTable(1024);
	private variants = new Map<string, Variant>();
	private decoded = new Map<TextureHandle, { resource: TextureResource; base: MipLevel }>();
	private addresses = new Map<number, Address>();
	private readonly resident = new Map<number, number>();
	private readonly owners: Int32Array;
	private readonly ages: Float64Array;
	private readonly pinned: Uint8Array;
	private readonly free: number[] = [];
	private readonly readbacks: Readback[] = [];
	private readonly feedback: Uint32Array[] = [];
	private fillOrder: number[] = [];
	private fillCursor = 0;
	private epoch = 0;
	private frame = 0;
	private nextId = 0;
	private destroyed = false;
	private readonly scratch = new Uint8Array(VT_PITCH * VT_PITCH * 4);

	constructor(private readonly device: GPUDevice, private readonly options: VirtualTextureOptions = {}) {
		this.tilesPerRow = Math.min(options.physicalTilesPerRow ?? 16, Math.floor(device.limits.maxTextureDimension2D / VT_PITCH));
		if (this.tilesPerRow < 2) throw new Error('Virtual texture cache requires at least four tiles');
		const count = this.tilesPerRow ** 2;
		this.physical = device.createTexture({ label: 'host:vtPhysical', size: [this.tilesPerRow * VT_PITCH, this.tilesPerRow * VT_PITCH],
			format: 'rgba8unorm', usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST });
		this.pageTable = this.createPageTable(1);
		this.owners = new Int32Array(count).fill(-1); this.ages = new Float64Array(count); this.pinned = new Uint8Array(count);
		for (let i = count - 1; i >= 0; i--) this.free.push(i);
		this.stats = { textures: 0, physicalPages: count, residentPages: 0, pendingRequests: 0, uploadsLastFrame: 0, totalUploads: 0, evictions: 0 };
	}

	private createPageTable(height: number): GPUTexture {
		return this.device.createTexture({ label: 'host:vtPageTable', size: [this.pageTableWidth, height], format: 'r32uint',
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST });
	}

	async prepare(snapshot: SceneSnapshot): Promise<PreparedHostTextures> {
		if (this.destroyed) throw new Error('Texture system is destroyed');
		const expectedEpoch = this.epoch;
		const requested = new Map<string, ResourceTextureBinding>();
		for (const m of snapshot.materials.values()) for (const key of keys) { const b = m[key]; if (b) requested.set(variantKey(b), b); }
		if (requested.size >= this.owners.length) throw new Error('Too many texture mip tails for the physical cache; increase physicalTilesPerRow');
		const variants = new Map<string, Variant>(), decoded = new Map(this.decoded);
		for (const id of decoded.keys()) if (!snapshot.textures.has(id)) decoded.delete(id);
		const maxSize = 2 ** Math.floor(Math.log2(Math.min(this.options.maxTextureSize ?? 4096, this.device.limits.maxTextureDimension2D)));
		const used = new Set([...requested.values()].map(b => b.texture));
		for (const id of used) {
			const resource = snapshot.textures.get(id)!;
			if (decoded.get(id)?.resource === resource) continue;
			let base: MipLevel;
			if ('data' in resource.source) {
				const source = resource.source;
				const width = Math.min(nextPowerOfTwo(source.width), maxSize), height = Math.min(nextPowerOfTwo(source.height), maxSize);
				const data = new Uint8Array(width * height * 4);
				for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
					const at = (Math.floor(y * source.height / height) * source.width + Math.floor(x * source.width / width)) * 4;
					data.set(source.data.subarray(at, at + 4), (y * width + x) * 4);
				}
				base = { width, height, data };
			} else [base] = await decodeImages(this.device, [resource.source], maxSize);
			decoded.set(id, { resource, base });
		}
		if (this.destroyed || this.epoch !== expectedEpoch) throw new Error('Texture preparation is obsolete');
		// First keep matching layouts. New layouts occupy the first available address gap.
		const occupied: { offset: number; end: number }[] = [];
		for (const [key, binding] of requested) {
			const old = this.variants.get(key), source = decoded.get(binding.texture)!;
			if (old && old.layout.log2W === Math.log2(source.base.width) && old.layout.log2H === Math.log2(source.base.height)) {
				const variant = old.resource === source.resource ? old : { ...old, resource: source.resource,
					chain: buildMipChain(source.base, old.layout.levels, source.resource.colorSpace === 'srgb') };
				variants.set(key, variant); occupied.push({ offset: old.layout.pageTableOffset, end: old.layout.pageTableOffset + old.layout.entryCount });
			}
		}
		occupied.sort((a, b) => a.offset - b.offset);
		for (const [key, binding] of requested) {
			if (variants.has(key)) continue;
			const source = decoded.get(binding.texture)!;
			const layout = layoutTexture(this.nextId++, Math.log2(source.base.width), Math.log2(source.base.height), 0);
			let offset = 0;
			for (const range of occupied) { if (offset + layout.entryCount <= range.offset) break; offset = range.end; }
			layout.pageTableOffset = offset;
			occupied.push({ offset, end: offset + layout.entryCount }); occupied.sort((a, b) => a.offset - b.offset);
			variants.set(key, { id: layout.id, key, resource: source.resource, layout,
				chain: buildMipChain(source.base, layout.levels, source.resource.colorSpace === 'srgb'), wrapS: wrap(binding.wrapU), wrapT: wrap(binding.wrapV) });
		}
		const required = Math.max(1, ...occupied.map(r => r.end));
		const height = nextPowerOfTwo(Math.ceil(required / this.pageTableWidth));
		if (height > this.device.limits.maxTextureDimension2D) throw new Error('Virtual texture address space exceeds the device limit');
		const replacement = height > this.pageTable.height ? this.createPageTable(height) : null;
		const changed = [...this.variants].some(([key, v]) => variants.get(key) !== v) || [...variants].some(([key, v]) => this.variants.get(key) !== v);
		const byId = new Map([...variants.values()].map(v => [v.id, v]));
		let done = false;
		return {
			resolve: binding => {
				const v = variants.get(variantKey(binding));
				if (!v) throw new Error('Texture binding was not prepared');
				return { source: v.id, colorSpace: v.resource.colorSpace === 'srgb' ? 'srgb_texture' : 'lin_rec709' };
			},
			descriptorOf: source => { const v = byId.get(source); return v ? v.layout : null; },
			cpuTexture: source => { const v = byId.get(source); return v ? new CpuTexture(v.chain[v.chain.length - 1]) : null; },
			publish: () => {
				if (done || this.destroyed || this.epoch !== expectedEpoch) throw new Error('Texture publication is obsolete');
				if (changed) {
					this.epoch++; this.feedback.length = 0;
					const table = new PageTable(replacement ? this.pageTableWidth * height : this.table.entries.length);
					table.entries.set(this.table.entries);
					for (const [key, old] of this.variants) if (variants.get(key) !== old) {
						const start = old.layout.pageTableOffset, end = start + old.layout.entryCount;
						table.entries.fill(0, start, end);
						for (const [page, tile] of this.resident) if (page >= start && page < end) {
							this.resident.delete(page); this.owners[tile] = -1; this.pinned[tile] = 0; this.free.push(tile);
						}
					}
					this.table = table;
					this.addresses.clear();
					for (const v of variants.values()) for (let l = 0; l < v.layout.levels; l++) {
						for (let y = 0; y < v.layout.pagesY[l]; y++) for (let x = 0; x < v.layout.pagesX[l]; x++) {
							this.addresses.set(pageIndex(v.layout, l, x, y), { variant: v, level: l, px: x, py: y });
						}
					}
					for (const [key, v] of variants) if (this.variants.get(key) !== v) {
						const level = v.layout.levels - 1, tile = this.acquire();
						if (tile < 0) throw new Error('No virtual texture tail slot');
						this.pinned[tile] = 1; this.map({ variant: v, level, px: 0, py: 0 }, tile);
					}
					this.variants = variants;
					this.fillOrder = [...this.addresses.keys()].sort((a, b) => this.addresses.get(b)!.level - this.addresses.get(a)!.level);
					this.fillCursor = 0;
					if (replacement) { const old = this.pageTable; this.pageTable = replacement; old.destroy(); }
					this.table.dirtyMin = 0; this.table.dirtyMax = this.table.entries.length - 1;
					this.flush();
				}
				this.decoded = decoded; this.stats.textures = variants.size; this.stats.residentPages = this.resident.size;
				done = true;
			},
			discard: () => { if (!done) { replacement?.destroy(); done = true; } },
		};
	}

	get invPhysicalSize(): number { return 1 / (this.tilesPerRow * VT_PITCH); }
	nextFeedbackJitter(): number { const j = this.frame++ % 16; return (j & 3) | ((j >> 2) << 16); }

	private acquire(): number {
		const free = this.free.pop(); if (free !== undefined) return free;
		let victim = -1;
		for (let i = 0; i < this.owners.length; i++) if (!this.pinned[i] && (victim < 0 || this.ages[i] < this.ages[victim])) victim = i;
		if (victim >= 0) {
			const page = this.owners[victim], address = this.addresses.get(page);
			if (address) this.table.unmap(address.variant.layout, address.level, address.px, address.py);
			this.resident.delete(page); this.owners[victim] = -1; this.stats.evictions++;
		}
		return victim;
	}

	private map(address: Address, tile: number): void {
		const { variant: v, level, px, py } = address;
		extractTile(v.chain[level], px, py, v.wrapS, v.wrapT, this.scratch);
		this.device.queue.writeTexture({ texture: this.physical, origin: [(tile % this.tilesPerRow) * VT_PITCH, Math.floor(tile / this.tilesPerRow) * VT_PITCH] },
			this.scratch, { bytesPerRow: VT_PITCH * 4 }, [VT_PITCH, VT_PITCH]);
		const index = pageIndex(v.layout, level, px, py);
		this.table.map(v.layout, level, px, py, tile); this.resident.set(index, tile); this.owners[tile] = index; this.ages[tile] = this.frame;
		this.stats.totalUploads++;
	}

	private flush(): void {
		if (this.table.dirtyMax < 0) return;
		const first = Math.floor(this.table.dirtyMin / this.pageTableWidth), last = Math.floor(this.table.dirtyMax / this.pageTableWidth);
		this.device.queue.writeTexture({ texture: this.pageTable, origin: [0, first] },
			this.table.entries.subarray(first * this.pageTableWidth, (last + 1) * this.pageTableWidth), { bytesPerRow: this.pageTableWidth * 4 }, [this.pageTableWidth, last - first + 1]);
		this.table.clearDirty();
	}

	update(): VirtualTextureUpdate {
		const feedback = this.feedback.splice(0), requests = new Map<number, number>();
		let total = 0, served = 0, uploaded = 0;
		for (const pixels of feedback) for (const value of pixels) {
			total++; const page = value - 1; if (!this.addresses.has(page)) continue;
			const tile = this.resident.get(page);
			if (tile !== undefined) this.ages[tile] = this.frame;
			else { const entry = this.table.entries[page]; if (entry & VT_ENTRY_VALID) this.ages[entryTile(entry)] = this.frame; requests.set(page, (requests.get(page) ?? 0) + 1); }
		}
		const limit = this.options.maxUploadsPerFrame ?? 64, deadline = performance.now() + (this.options.uploadBudgetMs ?? 4);
		for (const [page, count] of [...requests].sort((a, b) => b[1] - a[1])) {
			if (uploaded >= limit || (uploaded > 0 && performance.now() > deadline)) break;
			const tile = this.acquire(); if (tile < 0) break;
			this.map(this.addresses.get(page)!, tile); uploaded++; served += count;
		}
		if (this.options.speculativeFill !== false) while (this.fillCursor < this.fillOrder.length && this.free.length && uploaded < limit && performance.now() < deadline) {
			const page = this.fillOrder[this.fillCursor++]; if (this.resident.has(page)) continue;
			this.map(this.addresses.get(page)!, this.free.pop()!); uploaded++;
		}
		this.flush(); this.stats.residentPages = this.resident.size; this.stats.uploadsLastFrame = uploaded;
		this.stats.pendingRequests = [...requests.keys()].filter(p => !this.resident.has(p)).length;
		return { mapped: uploaded, coverage: served / Math.max(total, 1), feedbackFrames: feedback.length, pendingFeedback: this.readbacks.some(r => r.state !== 'idle') };
	}

	recordFeedbackReadback(encoder: GPUCommandEncoder, texture: GPUTexture): void {
		const stride = Math.ceil(texture.width * 4 / 256) * 256, size = stride * texture.height;
		let r = this.readbacks.find(r => r.state === 'idle' && r.buffer.size >= size);
		if (!r) {
			if (this.readbacks.length >= 3) {
				const index = this.readbacks.findIndex(r => r.state === 'idle'); if (index < 0) return;
				this.readbacks[index].buffer.destroy(); this.readbacks.splice(index, 1);
			}
			r = { buffer: this.device.createBuffer({ label: 'host:vtFeedback', size, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ }),
				state: 'idle', width: 0, height: 0, stride: 0, epoch: 0 }; this.readbacks.push(r);
		}
		r.width = texture.width; r.height = texture.height; r.stride = stride; r.epoch = this.epoch; r.state = 'recorded';
		encoder.copyTextureToBuffer({ texture }, { buffer: r.buffer, bytesPerRow: stride }, [r.width, r.height]);
	}

	afterSubmit(): void {
		for (const r of this.readbacks) if (r.state === 'recorded') {
			r.state = 'mapping';
			void r.buffer.mapAsync(GPUMapMode.READ).then(() => {
				if (this.destroyed) return;
				if (r.epoch === this.epoch) {
					const input = new Uint32Array(r.buffer.getMappedRange()), output = new Uint32Array(r.width * r.height);
					for (let y = 0; y < r.height; y++) output.set(input.subarray(y * r.stride / 4, y * r.stride / 4 + r.width), y * r.width);
					this.feedback.push(output);
				}
				r.buffer.unmap(); r.state = 'idle';
			}).catch(() => { r.state = 'idle'; });
		}
	}

	destroy(): void {
		if (this.destroyed) return;
		this.destroyed = true; this.physical.destroy(); this.pageTable.destroy();
		for (const r of this.readbacks) r.buffer.destroy();
		this.decoded.clear(); this.variants.clear(); this.addresses.clear(); this.resident.clear(); this.feedback.length = 0;
	}
}
