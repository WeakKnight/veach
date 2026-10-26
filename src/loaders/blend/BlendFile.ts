// Reader for Blender .blend files (2.5x .. 5.x): file header, zstd, block headers, and the SDNA
// the file embeds, so struct members are read by name whatever the version wrote them.
// Reference: source/blender/blenloader (readfile.cc, BLO_core_bhead.hh) and
// source/blender/makesdna/intern/dna_genfile.cc. Only little-endian files are supported.
import { decompress } from 'fzstd';

export interface SdnaMember {
	name: string; // without pointer / array decoration
	type: string;
	offset: number;
	size: number;
	elementSize: number;
	pointer: boolean;
	dims: number[]; // array dimensions, [] for scalars
}

export interface SdnaStruct {
	index: number;
	name: string;
	size: number;
	members: Map<string, SdnaMember>;
}

export class Sdna {
	readonly types: string[] = [];
	readonly typeSizes: number[] = [];
	readonly structs: SdnaStruct[] = [];
	readonly byName = new Map<string, SdnaStruct>();

	constructor(bytes: Uint8Array, pointerSize: number) {
		const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
		const decoder = new TextDecoder('latin1');
		let p = 0;
		const tag = (expected: string) => {
			const got = decoder.decode(bytes.subarray(p, p + 4));
			if (got !== expected) {
				throw new Error(`blend: SDNA expected ${expected}, got ${got}`);
			}
			p += 4;
		};
		const align = () => {
			p = (p + 3) & ~3;
		};
		const strings = (count: number) => {
			const out: string[] = [];
			for (let i = 0; i < count; i++) {
				const end = bytes.indexOf(0, p);
				out.push(decoder.decode(bytes.subarray(p, end)));
				p = end + 1;
			}
			return out;
		};
		tag('SDNA');
		tag('NAME');
		const nameCount = view.getInt32(p, true);
		p += 4;
		const names = strings(nameCount);
		align();
		tag('TYPE');
		const typeCount = view.getInt32(p, true);
		p += 4;
		this.types = strings(typeCount);
		align();
		tag('TLEN');
		for (let i = 0; i < typeCount; i++) {
			this.typeSizes.push(view.getInt16(p, true));
			p += 2;
		}
		align();
		tag('STRC');
		const structCount = view.getInt32(p, true);
		p += 4;
		for (let s = 0; s < structCount; s++) {
			const type = view.getInt16(p, true);
			const memberCount = view.getInt16(p + 2, true);
			p += 4;
			const struct: SdnaStruct = { index: s, name: this.types[type], size: this.typeSizes[type], members: new Map() };
			let offset = 0;
			for (let m = 0; m < memberCount; m++) {
				const typeIndex = view.getInt16(p, true);
				const decorated = names[view.getInt16(p + 2, true)];
				p += 4;
				const pointer = decorated.startsWith('*') || decorated.startsWith('(*');
				const dims = [...decorated.matchAll(/\[(\d+)\]/g)].map((d) => Number(d[1]));
				const name = decorated.replace(/^\(?\*+/, '').replace(/\)\(.*$/, '').replace(/\[.*$/, '');
				const elementSize = pointer ? pointerSize : this.typeSizes[typeIndex];
				const size = elementSize * dims.reduce((a, b) => a * b, 1);
				struct.members.set(name, { name, type: this.types[typeIndex], offset, size, elementSize, pointer, dims });
				offset += size;
			}
			this.structs.push(struct);
			this.byName.set(struct.name, struct);
		}
	}
}

export interface Block {
	code: string;
	sdna: number;
	address: bigint;
	offset: number; // of the data in BlendFile.bytes
	length: number;
	count: number;
	scope: number; // index of the block starting the ID (or other non-DATA block) this block belongs to
}

// Address lookup over a set of blocks: exact block starts, then pointers into a block.
class AddressIndex {
	private readonly starts = new Map<bigint, Block>();
	private readonly sorted: Block[];

	constructor(blocks: Block[]) {
		this.sorted = blocks.filter((b) => b.address !== 0n).sort((a, b) => (a.address < b.address ? -1 : a.address > b.address ? 1 : 0));
		for (const b of this.sorted) {
			if (!this.starts.has(b.address)) {
				this.starts.set(b.address, b);
			}
		}
	}

	exact(address: bigint): Block | undefined {
		return this.starts.get(address);
	}

	containing(address: bigint): { block: Block; offset: number } | null {
		let lo = 0;
		let hi = this.sorted.length - 1;
		while (lo <= hi) {
			const mid = (lo + hi) >> 1;
			if (this.sorted[mid].address <= address) {
				lo = mid + 1;
			} else {
				hi = mid - 1;
			}
		}
		const block = this.sorted[hi];
		if (!block) {
			return null;
		}
		const delta = Number(address - block.address);
		return delta < Math.max(block.length, 1) ? { block, offset: block.offset + delta } : null;
	}
}

const ZSTD_MAGIC = [0x28, 0xb5, 0x2f, 0xfd];

export class BlendFile {
	readonly bytes: Uint8Array;
	readonly view: DataView;
	readonly version: number; // e.g. 278, 403, 503
	readonly pointerSize: number;
	readonly blocks: Block[] = [];
	readonly sdna: Sdna;
	private readonly global: AddressIndex;
	private readonly idBlocks: AddressIndex;
	private readonly scopes = new Map<number, AddressIndex>();

	constructor(input: Uint8Array) {
		const bytes = ZSTD_MAGIC.every((b, i) => input[i] === b) ? decompress(input) : input;
		this.bytes = bytes;
		this.view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
		const header = new TextDecoder('latin1').decode(bytes.subarray(0, 17));
		if (!header.startsWith('BLENDER')) {
			throw new Error('blend: not a .blend file');
		}
		let p: number;
		let large: boolean;
		const modern = /^BLENDER(\d\d)-(\d\d)v(\d{4})/.exec(header);
		if (modern) {
			// BLENDER17-01v0500: header size, file format version 1 (LargeBHead8), Blender version
			if (modern[2] !== '01') {
				throw new Error(`blend: unsupported file format version ${modern[2]}`);
			}
			p = Number(modern[1]);
			large = true;
			this.pointerSize = 8;
			this.version = Number(modern[3]);
		} else {
			// BLENDER-v403: pointer size ('-' 8, '_' 4), endianness ('v' little), version
			if (header[8] !== 'v') {
				throw new Error('blend: big-endian files are not supported');
			}
			p = 12;
			large = false;
			this.pointerSize = header[7] === '-' ? 8 : 4;
			this.version = Number(header.slice(9, 12));
		}

		const v = this.view;
		const code = (at: number) => String.fromCharCode(...bytes.subarray(at, at + 4)).replace(/\0+$/, '');
		let dna: Block | null = null;
		let scope = -1;
		while (p < bytes.length) {
			let block: Block;
			if (large) {
				block = { code: code(p), sdna: v.getInt32(p + 4, true), address: v.getBigUint64(p + 8, true), length: Number(v.getBigInt64(p + 16, true)), count: Number(v.getBigInt64(p + 24, true)), offset: p + 32, scope };
			} else if (this.pointerSize === 8) {
				block = { code: code(p), length: v.getInt32(p + 4, true), address: v.getBigUint64(p + 8, true), sdna: v.getInt32(p + 16, true), count: v.getInt32(p + 20, true), offset: p + 24, scope };
			} else {
				block = { code: code(p), length: v.getInt32(p + 4, true), address: BigInt(v.getUint32(p + 8, true)), sdna: v.getInt32(p + 12, true), count: v.getInt32(p + 16, true), offset: p + 20, scope };
			}
			if (block.code === 'ENDB') {
				break;
			}
			if (block.code !== 'DATA') {
				scope = block.scope = this.blocks.length;
			}
			this.blocks.push(block);
			if (block.code === 'DNA1') {
				dna = block;
			}
			p = block.offset + block.length;
		}
		if (!dna) {
			throw new Error('blend: no DNA1 block');
		}
		this.sdna = new Sdna(bytes.subarray(dna.offset, dna.offset + dna.length), this.pointerSize);
		this.global = new AddressIndex(this.blocks);
		this.idBlocks = new AddressIndex(this.blocks.filter((b) => b.code !== 'DATA'));
		const byScope = new Map<number, Block[]>();
		for (const b of this.blocks) {
			let list = byScope.get(b.scope);
			if (!list) {
				byScope.set(b.scope, (list = []));
			}
			list.push(b);
		}
		for (const [s, list] of byScope) {
			this.scopes.set(s, new AddressIndex(list));
		}
	}

	// The block owning a file offset.
	blockAt(offset: number): Block | undefined {
		let lo = 0;
		let hi = this.blocks.length - 1;
		while (lo <= hi) {
			const mid = (lo + hi) >> 1;
			if (this.blocks[mid].offset <= offset) {
				lo = mid + 1;
			} else {
				hi = mid - 1;
			}
		}
		return this.blocks[hi];
	}

	// The block an address points into, and the byte offset. As in readfile.cc, data addresses are
	// only unique within one ID (the ID block and the DATA blocks following it; 5.x writes stable
	// ids that repeat across IDs), so the scope of the struct holding the pointer (`from`, a file
	// offset) is searched first, then ID blocks, then everything (older files point into arrays).
	resolve(address: bigint, from?: number): { block: Block; offset: number } | null {
		if (address === 0n) {
			return null;
		}
		const scope = from !== undefined ? this.scopes.get(this.blockAt(from)?.scope ?? -2) : undefined;
		const exact = scope?.exact(address) ?? this.idBlocks.exact(address) ?? this.global.exact(address);
		if (exact) {
			return { block: exact, offset: exact.offset };
		}
		return scope?.containing(address) ?? this.global.containing(address);
	}

	structOf(block: Block): SdnaStruct | undefined {
		return this.sdna.structs[block.sdna];
	}

	struct(type: string | SdnaStruct, offset: number): BStruct {
		const def = typeof type === 'string' ? this.sdna.byName.get(type) : type;
		if (!def) {
			throw new Error(`blend: no struct ${type}`);
		}
		return new BStruct(this, def, offset);
	}

	// Every ID data-block of a type ('OB', 'ME', 'MA', ...), in file order.
	ids(code: string): BStruct[] {
		return this.blocks.filter((b) => b.code === code).map((b) => new BStruct(this, this.structOf(b)!, b.offset));
	}

	// The struct at an address, typed by its block (or by `type` when given).
	at(address: bigint, type?: string, from?: number): BStruct | null {
		const r = this.resolve(address, from);
		if (!r) {
			return null;
		}
		const def = type ? this.sdna.byName.get(type) : this.structOf(r.block);
		return def ? new BStruct(this, def, r.offset) : null;
	}
}

const textDecoder = new TextDecoder('utf-8');

// A struct instance in the file, accessed by member name.
export class BStruct {
	constructor(
		readonly file: BlendFile,
		readonly def: SdnaStruct,
		readonly offset: number,
	) {}

	get type(): string {
		return this.def.name;
	}

	has(name: string): boolean {
		return this.def.members.has(name);
	}

	member(name: string): SdnaMember {
		const m = this.def.members.get(name);
		if (!m) {
			throw new Error(`blend: ${this.def.name} has no member ${name}`);
		}
		return m;
	}

	private scalar(type: string, at: number): number {
		const v = this.file.view;
		switch (type) {
			case 'char':
			case 'uchar':
			case 'uint8_t':
			case 'bool':
				return v.getUint8(at);
			case 'int8_t':
				return v.getInt8(at);
			case 'short':
			case 'int16_t':
				return v.getInt16(at, true);
			case 'ushort':
			case 'uint16_t':
				return v.getUint16(at, true);
			case 'int':
			case 'int32_t':
				return v.getInt32(at, true);
			case 'uint32_t':
				return v.getUint32(at, true);
			case 'float':
				return v.getFloat32(at, true);
			case 'double':
				return v.getFloat64(at, true);
			case 'long':
			case 'int64_t':
				return Number(this.file.pointerSize === 4 && type === 'long' ? v.getInt32(at, true) : v.getBigInt64(at, true));
			case 'ulong':
			case 'uint64_t':
				return Number(this.file.pointerSize === 4 && type === 'ulong' ? v.getUint32(at, true) : v.getBigUint64(at, true));
			default:
				throw new Error(`blend: ${type} is not a number`);
		}
	}

	// A numeric member, or element `index` of a numeric array member. Missing members give `fallback`.
	num(name: string, index = 0, fallback?: number): number {
		const m = this.def.members.get(name);
		if (!m) {
			if (fallback !== undefined) {
				return fallback;
			}
			throw new Error(`blend: ${this.def.name} has no member ${name}`);
		}
		return this.scalar(m.type, this.offset + m.offset + index * m.elementSize);
	}

	nums(name: string): number[] {
		const m = this.member(name);
		const count = m.dims.reduce((a, b) => a * b, 1);
		return Array.from({ length: count }, (_, i) => this.num(name, i));
	}

	str(name: string): string {
		const m = this.def.members.get(name);
		if (!m) {
			return '';
		}
		const bytes = this.file.bytes.subarray(this.offset + m.offset, this.offset + m.offset + m.size);
		const end = bytes.indexOf(0);
		return textDecoder.decode(end >= 0 ? bytes.subarray(0, end) : bytes);
	}

	ptr(name: string, index = 0): bigint {
		const m = this.def.members.get(name);
		if (!m || !m.pointer) {
			return 0n;
		}
		const at = this.offset + m.offset + index * this.file.pointerSize;
		return this.file.pointerSize === 8 ? this.file.view.getBigUint64(at, true) : BigInt(this.file.view.getUint32(at, true));
	}

	// The block and file offset a pointer member points to, looked up in this struct's ID scope.
	resolve(name: string): { block: Block; offset: number } | null {
		return this.file.resolve(this.ptr(name), this.offset);
	}

	// The `count` pointers of a pointer-to-pointer-array member (e.g. material slots `**mat`).
	ptrs(name: string, count: number): bigint[] {
		const r = this.resolve(name);
		if (!r) {
			return new Array<bigint>(count).fill(0n);
		}
		const size = this.file.pointerSize;
		return Array.from({ length: count }, (_, i) => {
			const at = r.offset + i * size;
			if (at + size > r.block.offset + r.block.length) {
				return 0n;
			}
			return size === 8 ? this.file.view.getBigUint64(at, true) : BigInt(this.file.view.getUint32(at, true));
		});
	}

	// The struct a pointer member points to, typed by the member when it names a struct.
	get(name: string, type?: string): BStruct | null {
		const m = this.def.members.get(name);
		if (!m) {
			return null;
		}
		const address = this.ptr(name);
		if (!type) {
			// A pointer to the start of a block takes the block's type (e.g. `ID *data` is a Camera).
			// SDNA index 0 (Link) marks untyped data (writedata) in older files.
			const r = this.file.resolve(address, this.offset);
			const blockType = r && r.offset === r.block.offset && r.block.sdna !== 0 ? this.file.structOf(r.block) : undefined;
			if (blockType && blockType.size <= r!.block.length) {
				return new BStruct(this.file, blockType, r!.offset);
			}
		}
		const declared = this.file.sdna.byName.has(m.type) ? m.type : undefined;
		return this.file.at(address, type ?? declared, this.offset);
	}

	// An embedded struct member (or element `index` of an array of structs).
	sub(name: string, index = 0): BStruct {
		const m = this.member(name);
		const def = this.file.sdna.byName.get(m.type);
		if (!def) {
			throw new Error(`blend: ${this.def.name}.${name} is not a struct`);
		}
		return new BStruct(this.file, def, this.offset + m.offset + index * def.size);
	}

	// Items of a ListBase member, linked through their first member (`next`).
	list(name: string, type?: string): BStruct[] {
		if (!this.has(name)) {
			return [];
		}
		const out: BStruct[] = [];
		let item = this.sub(name).get('first', type);
		const seen = new Set<number>();
		while (item && !seen.has(item.offset)) {
			seen.add(item.offset);
			out.push(item);
			const r = this.file.resolve(item.ptr('next'), item.offset);
			if (!r) {
				break;
			}
			const def = type ? this.file.sdna.byName.get(type)! : (this.file.structOf(r.block) ?? item.def);
			item = new BStruct(this.file, def, r.offset);
		}
		return out;
	}

	// `count` consecutive structs a pointer member points to (default: as many as its block holds).
	array(name: string, count?: number, type?: string): BStruct[] {
		const first = this.get(name, type);
		if (!first) {
			return [];
		}
		const r = this.resolve(name)!;
		const available = Math.floor((r.block.offset + r.block.length - r.offset) / first.def.size);
		const n = Math.min(count ?? available, available);
		return Array.from({ length: n }, (_, i) => new BStruct(this.file, first.def, first.offset + i * first.def.size));
	}

	// Raw bytes a pointer member points to, to the end of their block.
	data(name: string): Uint8Array | null {
		const r = this.resolve(name);
		return r ? this.file.bytes.subarray(r.offset, r.block.offset + r.block.length) : null;
	}

	// The ID name without its two-letter code ('OBCube' -> 'Cube'), for structs starting with an ID.
	get idName(): string {
		const id = this.has('id') ? this.sub('id') : this;
		return id.str('name').slice(2);
	}
}

// Copies `count` little-endian float32s starting at `bytes` (which need not be 4-byte aligned).
export function readFloats(bytes: Uint8Array, count: number): Float32Array {
	const out = new Float32Array(count);
	new Uint8Array(out.buffer).set(bytes.subarray(0, count * 4));
	return out;
}

export function readInts(bytes: Uint8Array, count: number): Int32Array {
	const out = new Int32Array(count);
	new Uint8Array(out.buffer).set(bytes.subarray(0, count * 4));
	return out;
}
