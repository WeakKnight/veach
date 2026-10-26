// CPU mirror of the GPU page table. Like Unreal's page table updates, every entry always points
// at the finest resident page covering it (the tail is pinned), so the shader needs one lookup.
import { pageIndex, type VTTextureLayout } from './VirtualTextureLayout';

export const VT_ENTRY_VALID = 0x80000000;

export function packEntry(level: number, tile: number): number {
	return (VT_ENTRY_VALID | (level << 16) | tile) >>> 0;
}

export function entryLevel(entry: number): number {
	return (entry >>> 16) & 0xf;
}

export function entryTile(entry: number): number {
	return entry & 0xffff;
}

export class PageTable {
	readonly entries: Uint32Array<ArrayBuffer>;
	dirtyMin = Infinity;
	dirtyMax = -1;

	constructor(entryCount: number) {
		this.entries = new Uint32Array(Math.max(entryCount, 1));
	}

	private set(index: number, value: number): void {
		if (this.entries[index] !== value) {
			this.entries[index] = value;
			this.dirtyMin = Math.min(this.dirtyMin, index);
			this.dirtyMax = Math.max(this.dirtyMax, index);
		}
	}

	clearDirty(): void {
		this.dirtyMin = Infinity;
		this.dirtyMax = -1;
	}

	// Visits the page and every finer page it covers.
	private forEachCovered(layout: VTTextureLayout, level: number, px: number, py: number, fn: (index: number) => void): void {
		for (let l = level; l >= 0; l--) {
			const k = level - l;
			const x0 = px << k, y0 = py << k;
			const x1 = Math.min((px + 1) << k, layout.pagesX[l]);
			const y1 = Math.min((py + 1) << k, layout.pagesY[l]);
			for (let y = y0; y < y1; y++) {
				const row = pageIndex(layout, l, 0, y);
				for (let x = x0; x < x1; x++) {
					fn(row + x);
				}
			}
		}
	}

	map(layout: VTTextureLayout, level: number, px: number, py: number, tile: number): void {
		const value = packEntry(level, tile);
		this.forEachCovered(layout, level, px, py, (i) => {
			const e = this.entries[i];
			if (!(e & VT_ENTRY_VALID) || entryLevel(e) >= level) {
				this.set(i, value);
			}
		});
	}

	// Entries that referenced this page fall back to the parent's (coarser) mapping.
	unmap(layout: VTTextureLayout, level: number, px: number, py: number): void {
		const fallback = level + 1 < layout.levels ? this.entries[pageIndex(layout, level + 1, px >> 1, py >> 1)] : 0;
		this.forEachCovered(layout, level, px, py, (i) => {
			if (entryLevel(this.entries[i]) === level && this.entries[i] & VT_ENTRY_VALID) {
				this.set(i, fallback);
			}
		});
	}

	lookup(layout: VTTextureLayout, level: number, px: number, py: number): number {
		return this.entries[pageIndex(layout, level, px, py)];
	}
}
