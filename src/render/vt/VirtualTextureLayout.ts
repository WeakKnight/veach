// Virtual texture address space, modelled on Unreal's streaming virtual textures: every texture
// is a power-of-two virtual image split into 128x128 pages per mip level, down to the "tail"
// level that fits in a single page. All page table entries of all textures live in one linear
// page table; a page's global entry index doubles as its feedback request id.

export const VT_PAGE_SIZE = 128;
export const VT_PAGE_SIZE_LOG2 = 7;
export const VT_BORDER = 4; // texels of neighbour data around each page (bilinear + headroom)
export const VT_PITCH = VT_PAGE_SIZE + 2 * VT_BORDER; // physical page size in texels
export const VT_MAX_LOG2_SIZE = 15;

export interface VTTextureLayout {
	id: number; // index into the system's texture list
	log2W: number;
	log2H: number;
	levels: number; // level levels-1 is the single-page tail
	pageTableOffset: number;
	levelOffsets: number[]; // per level, relative to pageTableOffset
	pagesX: number[];
	pagesY: number[];
	entryCount: number;
}

export function vtLevelCount(log2W: number, log2H: number): number {
	return Math.max(Math.max(log2W, log2H) - VT_PAGE_SIZE_LOG2, 0) + 1;
}

export function layoutTexture(id: number, log2W: number, log2H: number, pageTableOffset: number): VTTextureLayout {
	const levels = vtLevelCount(log2W, log2H);
	const levelOffsets: number[] = [];
	const pagesX: number[] = [];
	const pagesY: number[] = [];
	let count = 0;
	for (let l = 0; l < levels; l++) {
		levelOffsets.push(count);
		pagesX.push(1 << Math.max(log2W - l - VT_PAGE_SIZE_LOG2, 0));
		pagesY.push(1 << Math.max(log2H - l - VT_PAGE_SIZE_LOG2, 0));
		count += pagesX[l] * pagesY[l];
	}
	return { id, log2W, log2H, levels, pageTableOffset, levelOffsets, pagesX, pagesY, entryCount: count };
}

export function pageIndex(layout: VTTextureLayout, level: number, px: number, py: number): number {
	return layout.pageTableOffset + layout.levelOffsets[level] + py * layout.pagesX[level] + px;
}

export interface VTPageAddress {
	layout: VTTextureLayout;
	level: number;
	px: number;
	py: number;
}

// Maps a global page table index (= feedback request) back to its page.
export class VTAddressSpace {
	readonly layouts: VTTextureLayout[] = [];
	entryCount = 0;

	add(log2W: number, log2H: number): VTTextureLayout {
		const layout = layoutTexture(this.layouts.length, log2W, log2H, this.entryCount);
		this.layouts.push(layout);
		this.entryCount += layout.entryCount;
		return layout;
	}

	decode(index: number): VTPageAddress | null {
		if (!(index >= 0 && index < this.entryCount)) {
			return null;
		}
		let lo = 0;
		let hi = this.layouts.length - 1;
		while (lo < hi) {
			const mid = (lo + hi + 1) >> 1;
			if (this.layouts[mid].pageTableOffset <= index) lo = mid;
			else hi = mid - 1;
		}
		const layout = this.layouts[lo];
		let local = index - layout.pageTableOffset;
		for (let level = 0; level < layout.levels; level++) {
			const n = layout.pagesX[level] * layout.pagesY[level];
			if (local < n) {
				return { layout, level, px: local % layout.pagesX[level], py: Math.floor(local / layout.pagesX[level]) };
			}
			local -= n;
		}
		return null;
	}
}
