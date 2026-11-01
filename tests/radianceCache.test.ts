// Radiance cache scheduling (docs/RadianceCache.md): toroidal slots, scroll invalidation and the per-frame budget.
import { describe, expect, it } from 'vitest';
import { RadianceCacheScheduler, radianceCacheCellSize, radianceCacheProbeWords } from '../src/render/RadianceCache';

describe('radiance cache scheduler', () => {
	it('centers each window on the camera with doubling cell sizes', () => {
		const s = new RadianceCacheScheduler(3, 8, 0.5);
		expect(s.windowOrigin(0, [0.1, 0.1, 0.1])).toEqual([-4, -4, -4]);
		expect(s.windowOrigin(1, [3.2, -0.1, 0])).toEqual([-1, -5, -4]);
		expect(s.clipmapCellSize(2)).toBe(2);
	});

	it('addresses world cells toroidally, so a scroll keeps every other slot', () => {
		const s = new RadianceCacheScheduler(1, 4, 1);
		expect(s.slot(0, [0, 0, 0])).toBe(s.slot(0, [4, -4, 8]));
		expect(s.slot(0, [-1, 0, 0])).toBe(3);
		expect(new Set(Array.from({ length: 64 }, (_, i) => s.slot(0, [i % 4 + 10, (i >> 2) % 4 - 7, (i >> 4) + 3]))).size).toBe(64);
	});

	it('traces every slot once first, center out, interleaving clipmaps', () => {
		const s = new RadianceCacheScheduler(2, 4, 1);
		s.follow([0, 0, 0]);
		expect(s.pendingCount).toBe(128);
		const first = s.next(4);
		expect(first.map(slot => slot >= 64)).toEqual([false, true, false, true]);
		// The first slots of a clipmap are its 8 center cells: world -1 and 0 of the window [-2, 2), slots 3 and 0.
		const cells = [first[0], first[2]].map(slot => [slot % 4, (slot >> 2) % 4, slot >> 4]);
		for (const cell of cells) for (const v of cell) expect([0, 3]).toContain(v);
		const all = new Set(first);
		while (s.pendingCount) for (const slot of s.next(Math.min(10, s.pendingCount))) { expect(all.has(slot)).toBe(false); all.add(slot); }
		expect(all.size).toBe(128);
	});

	it('invalidates only the slab a scroll uncovers', () => {
		const s = new RadianceCacheScheduler(1, 4, 1);
		s.follow([0, 0, 0]);
		s.next(64);
		s.follow([1.5, 0, 0]); // one cell in +x
		expect(s.pendingCount).toBe(16);
		const slab = s.next(16);
		// The new cells x = 2 (window [-1, 3)) live where x = -2 was: slot x = posmod(2, 4) = 2.
		expect(new Set(slab.map(slot => slot % 4))).toEqual(new Set([2]));
	});

	it('spends the rest of the budget on a per-clipmap round robin without duplicates', () => {
		const s = new RadianceCacheScheduler(2, 4, 1);
		s.follow([0, 0, 0]);
		while (s.pendingCount) s.next(1000);
		const frame = s.next(10);
		expect(new Set(frame).size).toBe(frame.length);
		expect(frame.length).toBe(10);
		expect(frame.filter(slot => slot < 64).length).toBe(Math.floor(10 * 0.4 / 0.7));
	});

	it('sizes clipmap 0 from the scene and probes from the octahedral resolution', () => {
		expect(radianceCacheCellSize([0, 0, 0], [96, 0, 0])).toBe(1);
		expect(radianceCacheCellSize([0, 0, 0], [0, 0, 0])).toBe(0.25);
		expect(radianceCacheProbeWords()).toBe(4 + 128);
	});
});
