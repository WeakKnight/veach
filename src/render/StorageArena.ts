// Persistent storage-buffer regions. Plans copy metadata, never unchanged payloads. No GPU
// writes happen before publish(), so failed asynchronous scene preparation can discard a plan.
export interface StorageBlock {
	readonly offset: number;
	readonly capacity: number;
	readonly bytes: Uint8Array<ArrayBuffer>;
}

interface FreeRange { offset: number; size: number }
const aligned = (n: number, alignment: number) => Math.ceil(n / alignment) * alignment;

export class StoragePlan {
	readonly blocks: Map<string, StorageBlock>;
	readonly dirty = new Set<string>();
	private readonly free: FreeRange[];
	private end: number;
	private closed = false;

	constructor(
		private readonly owner: StorageArena,
		readonly revision: number,
		blocks: ReadonlyMap<string, StorageBlock>,
		free: readonly FreeRange[],
		end: number,
	) {
		this.blocks = new Map(blocks); this.free = free.map(r => ({ ...r })); this.end = end;
	}

	get byteLength(): number { return Math.max(this.end, this.owner.alignment); }
	get(key: string): StorageBlock | undefined { return this.blocks.get(key); }

	set(key: string, data: ArrayBuffer | ArrayBufferView): StorageBlock {
		if (this.closed) throw new Error('Storage plan is closed');
		const input = data instanceof ArrayBuffer ? new Uint8Array(data) : new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
		if (input.byteLength % 4) throw new Error('Storage payload must be a multiple of four bytes');
		const capacity = aligned(Math.max(input.byteLength, 4), this.owner.alignment);
		const previous = this.blocks.get(key);
		let offset: number;
		if (previous && previous.capacity >= capacity) {
			offset = previous.offset;
		} else {
			if (previous) this.delete(key);
			const index = this.free.findIndex(r => r.size >= capacity);
			if (index >= 0) {
				const range = this.free[index]; offset = range.offset;
				range.offset += capacity; range.size -= capacity;
				if (range.size === 0) this.free.splice(index, 1);
			} else { offset = this.end; this.end += capacity; }
		}
		const block = { offset, capacity: previous && previous.capacity >= capacity ? previous.capacity : capacity, bytes: input.slice() };
		this.blocks.set(key, block); this.dirty.add(key); return block;
	}

	delete(key: string): void {
		if (this.closed) throw new Error('Storage plan is closed');
		const block = this.blocks.get(key);
		if (!block) return;
		this.blocks.delete(key); this.dirty.delete(key);
		this.free.push({ offset: block.offset, size: block.capacity });
		this.free.sort((a, b) => a.offset - b.offset);
		for (let i = 0; i + 1 < this.free.length;) {
			const a = this.free[i], b = this.free[i + 1];
			if (a.offset + a.size === b.offset) { a.size += b.size; this.free.splice(i + 1, 1); } else i++;
		}
		while (this.free.length && this.free[this.free.length - 1].offset + this.free[this.free.length - 1].size === this.end) {
			this.end = this.free.pop()!.offset;
		}
	}

	/** Allocate a replacement if capacity is insufficient; existing GPU data is still untouched. */
	prepare(): PreparedStorage {
		if (this.closed) throw new Error('Storage plan is closed');
		this.closed = true;
		return this.owner.prepare(this, this.free, this.end);
	}
}

export interface PreparedStorage {
	readonly buffer: GPUBuffer;
	readonly uploadedBytes: number;
	readonly grew: boolean;
	publish(): void;
	discard(): void;
}

export class StorageArena {
	private blocks = new Map<string, StorageBlock>();
	private free: FreeRange[] = [];
	private end = 0;
	private revision = 0;
	private buffer: GPUBuffer | null = null;
	private destroyed = false;

	constructor(private readonly device: GPUDevice, readonly label: string, readonly alignment = 16) {
		if (!Number.isSafeInteger(alignment) || alignment < 4 || alignment % 4) throw new Error('Invalid storage alignment');
	}

	plan(): StoragePlan {
		if (this.destroyed) throw new Error('Storage arena is destroyed');
		return new StoragePlan(this, this.revision, this.blocks, this.free, this.end);
	}

	prepare(plan: StoragePlan, free: FreeRange[], end: number): PreparedStorage {
		if (this.destroyed || plan.revision !== this.revision) throw new Error('Stale storage plan');
		const limit = Math.min(this.device.limits.maxBufferSize, this.device.limits.maxStorageBufferBindingSize);
		if (plan.byteLength > limit) throw new Error(`${this.label} exceeds the storage buffer limit`);
		const grew = !this.buffer || plan.byteLength > this.buffer.size;
		const buffer = grew ? this.device.createBuffer({
			label: this.label, size: Math.min(limit, Math.max(256, 2 ** Math.ceil(Math.log2(plan.byteLength)))),
			usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC,
		}) : this.buffer!;
		const writes = [...plan.blocks.entries()].filter(([key]) => grew || plan.dirty.has(key)).map(([, b]) => b).sort((a, b) => a.offset - b.offset);
		// Coalesce adjacent records; never read or compare the unchanged geometry payloads.
		const spans: { offset: number; bytes: Uint8Array<ArrayBuffer> }[] = [];
		for (let i = 0; i < writes.length;) {
			const start = i++, offset = writes[start].offset;
			let stop = offset + writes[start].bytes.byteLength;
			while (i < writes.length && writes[i].offset === stop) { stop += writes[i].bytes.byteLength; i++; }
			if (i === start + 1) spans.push({ offset, bytes: writes[start].bytes });
			else {
				const bytes = new Uint8Array(stop - offset);
				for (let j = start; j < i; j++) bytes.set(writes[j].bytes, writes[j].offset - offset);
				spans.push({ offset, bytes });
			}
		}
		let done = false;
		return {
			buffer, grew, uploadedBytes: spans.reduce((n, s) => n + s.bytes.byteLength, 0),
			publish: () => {
				if (done || this.destroyed || plan.revision !== this.revision) throw new Error('Stale storage publication');
				for (const s of spans) this.device.queue.writeBuffer(buffer, s.offset, s.bytes);
				const old = this.buffer;
				this.buffer = buffer; this.blocks = plan.blocks; this.free = free; this.end = end; this.revision++; done = true;
				// All commands using the old buffer have been submitted before the commit. WebGPU
				// keeps already-submitted uses alive; callers must not submit old bind groups later.
				if (grew && old) old.destroy();
			},
			discard: () => { if (!done) { if (grew) buffer.destroy(); done = true; } },
		};
	}

	destroy(): void {
		this.destroyed = true; this.buffer?.destroy(); this.buffer = null;
		this.blocks.clear(); this.free = []; this.end = 0;
	}
}
