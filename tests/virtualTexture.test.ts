import { describe, expect, it, vi } from 'vitest';
import { WrapMode } from '../src/scene/Scene';
import { PageTable, VT_ENTRY_VALID, entryLevel, entryTile } from '../src/render/vt/PageTable';
import { buildMipChain, extractTile } from '../src/render/vt/TileSource';
import { VTAddressSpace, VT_BORDER, VT_PITCH, layoutTexture, pageIndex } from '../src/render/vt/VirtualTextureLayout';
import { VT_FEEDBACK_PERIOD, VirtualTextureSystem } from '../src/render/vt/VirtualTextureSystem';

describe('virtual texture feedback residency', () => {
	function cache(lastUsed = 2) {
		const space = new VTAddressSpace();
		const layout = space.add(8, 8); // four fine pages and a pinned tail
		const table = new PageTable(space.entryCount);
		table.map(layout, 1, 0, 0, 0);
		table.map(layout, 0, 0, 0, 1);
		const feedbackQueue: Uint32Array[] = [];
		const vt = Object.assign(Object.create(VirtualTextureSystem.prototype), {
			space, table, feedbackQueue, frame: 2, staging: [],
			device: { queue: { writeTexture: vi.fn() } }, physical: {}, pageTable: {},
			pageTableWidth: space.entryCount, tilesPerRow: 2, tileCount: 2,
			tileOwner: new Int32Array([4, 0]), tileLastUsed: new Uint32Array([2, lastUsed]),
			tilePinned: new Uint8Array([1, 0]), freeTiles: [], resident: new Map([[4, 0], [0, 1]]),
			textures: [{ layout, chain: buildMipChain({ width: 256, height: 256, data: new Uint8Array(256 * 256 * 4) }, 2, false), wrapS: WrapMode.Repeat, wrapT: WrapMode.Repeat }],
			tileScratch: new Uint8Array(VT_PITCH * VT_PITCH * 4),
			maxUploadsPerFrame: 1, uploadBudgetMs: Infinity, speculativeFill: false,
			stats: { pendingRequests: 0, totalUploads: 0, evictions: 0 },
		}) as VirtualTextureSystem;
		const request = () => {
			feedbackQueue.push(new Uint32Array([2])); // fine page 1, currently missing
			return vt.update();
		};
		return { vt, request };
	}

	it('protects requested pages through a feedback jitter cycle, even across long readback gaps', () => {
		const { vt, request } = cache();
		for (let i = 0; i < 64; i++) expect(vt.update().feedbackFrames).toBe(0);
		for (let i = 0; i < VT_FEEDBACK_PERIOD; i++) expect(request().mapped).toBe(0);
		expect(vt.stats.evictions).toBe(0);
		expect(vt.stats.pendingRequests).toBe(1);
		expect(request().mapped).toBe(1);
		expect(vt.stats.evictions).toBe(1);
		expect(vt.stats.pendingRequests).toBe(0);
	});

	it('can immediately replace speculative pages that feedback never requested', () => {
		const { vt, request } = cache(0);
		expect(request().mapped).toBe(1);
		expect(vt.stats.evictions).toBe(1);
		expect(vt.stats.residentPages).toBe(2);
	});
});

describe('virtual texture layout', () => {
	it('lays out mips down to the single-page tail', () => {
		const l = layoutTexture(0, 10, 9, 0); // 1024 x 512
		expect(l.levels).toBe(4);
		expect(l.pagesX).toEqual([8, 4, 2, 1]);
		expect(l.pagesY).toEqual([4, 2, 1, 1]);
		expect(l.entryCount).toBe(32 + 8 + 2 + 1);
		expect(layoutTexture(0, 6, 3, 0).levels).toBe(1); // 64 x 8: tail only
		expect(layoutTexture(0, 12, 5, 0).pagesY).toEqual([1, 1, 1, 1, 1, 1]);
	});

	it('decodes every page index back to its address', () => {
		const space = new VTAddressSpace();
		const a = space.add(9, 9);
		const b = space.add(11, 8);
		const c = space.add(5, 5);
		for (const layout of [a, b, c]) {
			for (let level = 0; level < layout.levels; level++) {
				for (let py = 0; py < layout.pagesY[level]; py++) {
					for (let px = 0; px < layout.pagesX[level]; px++) {
						const d = space.decode(pageIndex(layout, level, px, py))!;
						expect([d.layout.id, d.level, d.px, d.py]).toEqual([layout.id, level, px, py]);
					}
				}
			}
		}
		expect(space.decode(space.entryCount)).toBeNull();
		expect(space.decode(0xffffffff)).toBeNull();
	});
});

describe('page table', () => {
	it('propagates the finest resident ancestor and falls back on unmap', () => {
		const l = layoutTexture(0, 9, 9, 0); // 512^2: levels 4x4, 2x2, 1x1
		const pt = new PageTable(l.entryCount);
		pt.map(l, 2, 0, 0, 7); // pinned tail
		for (let i = 0; i < l.entryCount; i++) {
			expect(entryTile(pt.entries[i])).toBe(7);
			expect(pt.entries[i] & VT_ENTRY_VALID).toBeTruthy();
		}

		pt.map(l, 1, 1, 0, 3);
		expect(entryLevel(pt.lookup(l, 0, 2, 1))).toBe(1);
		expect(entryTile(pt.lookup(l, 0, 3, 0))).toBe(3);
		expect(entryTile(pt.lookup(l, 0, 0, 0))).toBe(7);

		pt.map(l, 0, 2, 0, 9);
		expect(entryTile(pt.lookup(l, 0, 2, 0))).toBe(9);
		// mapping a coarser page must not overwrite finer residency
		pt.map(l, 1, 1, 0, 3);
		expect(entryTile(pt.lookup(l, 0, 2, 0))).toBe(9);

		pt.unmap(l, 1, 1, 0);
		expect(entryTile(pt.lookup(l, 1, 1, 0))).toBe(7);
		expect(entryTile(pt.lookup(l, 0, 3, 1))).toBe(7);
		expect(entryTile(pt.lookup(l, 0, 2, 0))).toBe(9); // finer page stays

		pt.unmap(l, 0, 2, 0);
		expect(entryTile(pt.lookup(l, 0, 2, 0))).toBe(7);
		expect(entryLevel(pt.lookup(l, 0, 2, 0))).toBe(2);
	});
});

describe('tile source', () => {
	const checker = (w: number, h: number) => {
		const data = new Uint8Array(w * h * 4);
		for (let y = 0; y < h; y++) {
			for (let x = 0; x < w; x++) {
				const i = (y * w + x) * 4;
				data.set([x & 255, y & 255, (x + y) & 1 ? 255 : 0, 255], i);
			}
		}
		return { width: w, height: h, data };
	};

	it('builds box-filtered mips', () => {
		const chain = buildMipChain(checker(256, 64), 2, false);
		expect(chain[1].width).toBe(128);
		expect(chain[1].height).toBe(32);
		const i = (5 * 128 + 7) * 4;
		expect(chain[1].data[i]).toBe(15); // avg(14, 15) rounded
		expect(chain[1].data[i + 2]).toBe(128); // half the checker texels are 255
	});

	it('extracts pages with wrapped borders', () => {
		const level = checker(256, 256);
		const tile = extractTile(level, 1, 0, WrapMode.Repeat, WrapMode.Clamp);
		const at = (x: number, y: number) => Array.from(tile.subarray((y * VT_PITCH + x) * 4, (y * VT_PITCH + x) * 4 + 2));
		expect(at(VT_BORDER, VT_BORDER)).toEqual([128, 0]); // page origin
		expect(at(VT_PITCH - 1, VT_BORDER)).toEqual([(128 + 128 + VT_BORDER - 1) & 255, 0]); // repeat in x
		expect(at(VT_BORDER, 0)).toEqual([128, 0]); // clamp in y
	});
});
