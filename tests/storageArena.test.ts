import { beforeEach, describe, expect, it, vi } from 'vitest';
import { StorageArena } from '../src/render/StorageArena';

function device() {
	const writes: { buffer: GPUBuffer; offset: number; bytes: Uint8Array }[] = [];
	const buffers: GPUBuffer[] = [];
	const gpu = {
		limits: { maxBufferSize: 4096, maxStorageBufferBindingSize: 4096 },
		createBuffer: ({ size }: GPUBufferDescriptor) => { const b = { size, destroy: vi.fn() } as unknown as GPUBuffer; buffers.push(b); return b; },
		queue: { writeBuffer: (buffer: GPUBuffer, offset: number, bytes: Uint8Array) => writes.push({ buffer, offset, bytes: bytes.slice() }) },
	} as unknown as GPUDevice;
	return { gpu, writes, buffers };
}

beforeEach(() => vi.stubGlobal('GPUBufferUsage', { STORAGE: 128, COPY_DST: 8, COPY_SRC: 4 }));

describe('persistent storage regions', () => {
	it('uploads only changed blocks and keeps offsets and GPU buffers stable', () => {
		const d = device(), arena = new StorageArena(d.gpu, 'vertices', 16);
		const first = arena.plan();
		const a = first.set('a', new Float32Array([1, 2, 3, 4]));
		first.set('b', new Float32Array([5, 6, 7, 8]));
		const upload = first.prepare(); expect(d.writes).toHaveLength(0); upload.publish();
		expect(d.writes).toHaveLength(1); // adjacent records coalesced
		const second = arena.plan();
		expect(second.set('a', new Float32Array([9, 2, 3, 4])).offset).toBe(a.offset);
		const patch = second.prepare(); expect(patch.buffer).toBe(upload.buffer); expect(patch.uploadedBytes).toBe(16); patch.publish();
		expect(d.buffers).toHaveLength(1);
		expect(d.writes[1].offset).toBe(0);
		expect(new Float32Array(d.writes[1].bytes.buffer)[0]).toBe(9);
		const noop = arena.plan().prepare(); expect(noop.uploadedBytes).toBe(0); noop.publish();
	});

	it('reuses released regions without relocating unrelated resources', () => {
		const d = device(), arena = new StorageArena(d.gpu, 'nodes', 64);
		const first = arena.plan(); first.set('a', new Uint32Array(16)); first.set('b', new Uint32Array(16)); first.prepare().publish();
		const second = arena.plan(); second.delete('a');
		expect(second.set('c', new Uint32Array(16)).offset).toBe(0);
		expect(second.get('b')!.offset).toBe(64); second.prepare().publish();
	});

	it('grows without losing payloads and can discard preparation', () => {
		const d = device(), arena = new StorageArena(d.gpu, 'indices');
		const first = arena.plan(); first.set('a', new Uint32Array([42])); const old = first.prepare(); old.publish();
		const discarded = arena.plan(); discarded.set('b', new Uint32Array(100)); const candidate = discarded.prepare();
		candidate.discard(); expect(candidate.buffer.destroy).toHaveBeenCalledOnce();
		expect(old.buffer.destroy).not.toHaveBeenCalled(); expect(arena.plan().get('b')).toBeUndefined();
		const next = arena.plan(); next.set('b', new Uint32Array(100)); const grown = next.prepare(); grown.publish();
		expect(grown.grew).toBe(true); expect(old.buffer.destroy).toHaveBeenCalledOnce();
		expect(d.writes.some(w => w.buffer === grown.buffer && new Uint32Array(w.bytes.buffer)[0] === 42)).toBe(true);
	});

	it('rejects stale plans and oversized buffers before upload', () => {
		const d = device(), arena = new StorageArena(d.gpu, 'storage');
		const old = arena.plan(), next = arena.plan(); next.set('a', new Uint32Array(4)); next.prepare().publish();
		expect(() => old.prepare()).toThrow('Stale');
		const huge = arena.plan(); huge.set('huge', new Uint32Array(2048));
		expect(() => huge.prepare()).toThrow('limit'); expect(d.writes).toHaveLength(1);
	});
});
