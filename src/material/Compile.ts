// MaterialGraph -> bytecode (src/material/Bytecode.ts): lower, optimize, slice into the surface,
// opacity and emission programs, allocate stack slots by liveness, emit.
import { AlphaMode } from '../scene/Scene';
import { Geometry, MAX_STACK_SIZE, NOISE_COLOR, NOISE_NORMALIZE, OPERAND_CONSTANT, OPERAND_NONE, OUTPUT_GROUPS, Op, instructionWords } from './Bytecode';
import type { TextureSampling } from './Evaluate';
import { TYPE_SIZE, constantOf, isConnection, toArg, type GraphNode, type Input, type MaterialGraph } from './Graph';
import { lowerGraph } from './Lower';
import { optimizeGraph } from './Optimize';

export interface CompiledMaterial {
	name: string;
	alphaMode: AlphaMode;
	alphaCutoff: number;
	doubleSided: boolean;
	code: Uint32Array; // uint4 instructions of all three programs
	constants: Float32Array; // float4 per constant
	textures: TextureSampling[];
	// Program offsets into `code` in uint4 units; -1 when the program would write nothing.
	surface: number; // every BSDFInputs field but the opacity
	opacity: number; // geometry_opacity (alpha test, -1 for opaque materials)
	emission: number; // emission_luminance and emission_color (light sampling)
	stackSize: number; // float4 slots
	alphaTested: boolean;
	emissive: boolean;
	debugTexture: number; // texture table entry feeding base_color (debug view 9), -1 if none
}

const OPACITY_FIELDS = ['geometry_opacity'];
const EMISSION_FIELDS = ['emission_luminance', 'emission_color'];
const SURFACE_FIELDS = OUTPUT_GROUPS.flat().filter((f) => !OPACITY_FIELDS.includes(f));

const BINARY: Record<string, Op> = {
	add: Op.Add,
	subtract: Op.Sub,
	multiply: Op.Mul,
	divide: Op.Div,
	min: Op.Min,
	max: Op.Max,
	power: Op.Pow,
	modulo: Op.Modulo,
	veach_greater: Op.Greater,
	crossproduct: Op.Cross,
};
const UNARY: Record<string, Op> = { sqrt: Op.Sqrt, sin: Op.Sin, cos: Op.Cos, absval: Op.Abs, floor: Op.Floor, sign: Op.Sign, exp: Op.Exp, ln: Op.Log };
const GEOMETRY: Record<string, Geometry> = { position: Geometry.Position, normal: Geometry.Normal, tangent: Geometry.Tangent, bitangent: Geometry.Bitangent };

class ConstantPool {
	readonly lanes: number[] = [];
	private readonly keys = new Map<string, number>();

	add(value: readonly number[]): number {
		const v = value.length === 1 ? [value[0], value[0], value[0], value[0]] : [0, 1, 2, 3].map((i) => value[i] ?? 0);
		const key = v.map(String).join(',');
		let index = this.keys.get(key);
		if (index === undefined) {
			index = this.lanes.push(...v) / 4 - 1;
			this.keys.set(key, index);
		}
		return index;
	}
}

class TextureTable {
	readonly entries: TextureSampling[] = [];
	private readonly keys = new Map<string, number>();

	add(t: TextureSampling): number {
		const key = JSON.stringify(t);
		let index = this.keys.get(key);
		if (index === undefined) {
			index = this.entries.push(t) - 1;
			this.keys.set(key, index);
		}
		return index;
	}
}

class ProgramCompiler {
	readonly code: number[] = [];
	readonly constants = new ConstantPool();
	readonly textures = new TextureTable();
	readonly textureOfNode = new Map<number, number>();
	stackSize = 0;

	constructor(private readonly graph: MaterialGraph) {}

	private sizeOf(input: Input | undefined): number {
		if (input === undefined) {
			return 1;
		}
		if (isConnection(input)) {
			return TYPE_SIZE[this.graph.nodes[input.node].type];
		}
		return 'value' in input ? input.value.length : 1;
	}

	// A narrowing or splatting convert is free: the value is reused as is.
	private isAlias(node: GraphNode): boolean {
		if (node.category !== 'convert') {
			return false;
		}
		const size = this.sizeOf(node.inputs.in);
		return isConnection(node.inputs.in) && (size === 1 || size >= TYPE_SIZE[node.type]);
	}

	private constantInput(node: GraphNode, name: string, fallback: number): number {
		const input = node.inputs[name];
		const c = input ? constantOf(toArg(input)) : [fallback];
		if (!c) {
			throw new Error(`material compiler: ${node.category}.${name} must be a constant`);
		}
		return c[0];
	}

	private emit(op: Op, dst: number, imm: number, operands: number[]): void {
		if (dst > 0xff || imm > 0xffff) {
			throw new Error('material compiler: instruction field out of range');
		}
		const words = instructionWords(operands.length);
		const padded = [...operands, ...new Array(words * 4 - 1 - operands.length).fill(OPERAND_NONE)];
		this.code.push((op | (dst << 8) | (imm << 16)) >>> 0, ...padded);
	}

	// scalar: the program runs where only texture coordinates are known (BVH traversal, light
	// sampling), so it may not read other geometry or apply normal maps.
	compile(fields: readonly string[], scalar = false): number {
		const graph = this.graph;
		const surface = graph.nodes[graph.surface];
		const present = fields.filter((f) => surface.inputs[f] !== undefined);
		if (present.length === 0) {
			return -1;
		}

		const live = new Set<number>();
		const visit = (input: Input) => {
			if (isConnection(input) && !live.has(input.node)) {
				live.add(input.node);
				Object.values(graph.nodes[input.node].inputs).forEach(visit);
			}
		};
		present.forEach((f) => visit(surface.inputs[f]));

		const alias = new Map<number, number>();
		const root = (n: number) => alias.get(n) ?? n;
		const instructions: number[] = [];
		for (const n of [...live].sort((a, b) => a - b)) {
			const node = graph.nodes[n];
			if (this.isAlias(node)) {
				alias.set(n, root((node.inputs.in as { node: number }).node));
			} else {
				instructions.push(n);
			}
		}

		const operandsOf = (inputs: Iterable<Input | undefined>) => [...inputs].filter((i): i is Input => !!i && isConnection(i)).map((i) => root((i as { node: number }).node));
		const lastUse = new Map<number, number>();
		instructions.forEach((n, i) => operandsOf(Object.values(graph.nodes[n].inputs)).forEach((r) => lastUse.set(r, i)));
		operandsOf(present.map((f) => surface.inputs[f])).forEach((r) => lastUse.set(r, instructions.length));

		const slot = new Map<number, number>();
		const free: number[] = [];
		let size = 0;
		const offset = this.code.length / 4;
		const operand = (input: Input | undefined, fallback: readonly number[]): number => {
			if (input === undefined) {
				return (OPERAND_CONSTANT | this.constants.add(fallback)) >>> 0;
			}
			if (isConnection(input)) {
				return slot.get(root(input.node))!;
			}
			if ('file' in input) {
				throw new Error('material compiler: unexpected file input');
			}
			return (OPERAND_CONSTANT | this.constants.add(input.value)) >>> 0;
		};

		instructions.forEach((n, i) => {
			const node = graph.nodes[n];
			const inputs = node.inputs;
			const operands = (spec: [string, readonly number[]][]) => spec.map(([name, fallback]) => operand(inputs[name], fallback));
			let op: Op;
			let imm = 0;
			let args: number[] = [];
			if (node.category in BINARY) {
				op = BINARY[node.category];
				const unit = op === Op.Mul || op === Op.Div || op === Op.Pow ? [1] : [0];
				args = operands([['in1', [0]], ['in2', unit]]);
			} else if (node.category in UNARY) {
				op = UNARY[node.category];
				args = operands([['in', [0]]]);
			} else if (node.category === 'position' && this.constantInput(node, 'space', 0) === 1) {
				op = Op.Geometry;
				imm = Geometry.ObjectPosition;
			} else if (node.category in GEOMETRY) {
				if (scalar) {
					throw new Error(`material compiler: ${graph.name}: opacity and emission may not use ${node.category}`);
				}
				op = Op.Geometry;
				imm = GEOMETRY[node.category];
			} else {
				switch (node.category) {
					case 'atan2':
						op = Op.Atan2;
						args = operands([['iny', [0]], ['inx', [1]]]);
						break;
					case 'clamp':
						op = Op.Clamp;
						args = operands([['in', [0]], ['low', [0]], ['high', [1]]]);
						break;
					case 'mix':
						op = Op.Mix;
						args = operands([['bg', [0]], ['fg', [0]], ['mix', [0]]]);
						break;
					case 'extract':
						op = Op.Extract;
						imm = this.constantInput(node, 'index', 0);
						args = operands([['in', [0]]]);
						break;
					case 'convert':
						op = Op.Widen;
						imm = this.sizeOf(inputs.in) | ((node.type === 'color4' ? 1 : 0) << 8);
						args = operands([['in', [0]]]);
						break;
					case 'combine2':
					case 'combine3':
					case 'combine4':
						op = Op.Combine;
						imm = TYPE_SIZE[node.type];
						args = operands(['in1', 'in2', 'in3', 'in4'].slice(0, imm).map((name) => [name, [0]] as [string, number[]]));
						break;
					case 'dotproduct':
						op = Op.Dot;
						imm = Math.max(this.sizeOf(inputs.in1), this.sizeOf(inputs.in2));
						args = operands([['in1', [0]], ['in2', [0]]]);
						break;
					case 'normalize':
						op = Op.Normalize;
						imm = this.sizeOf(inputs.in);
						args = operands([['in', [0]]]);
						break;
					case 'texcoord':
						op = Op.Geometry;
						imm = this.constantInput(node, 'index', 0) === 1 ? Geometry.Texcoord1 : Geometry.Texcoord0;
						break;
					case 'veach_texture': {
						const file = inputs.file;
						if (!file || !('file' in file)) {
							throw new Error('material compiler: veach_texture without a file');
						}
						const vector = (name: string, fallback: number[]) => {
							const c = inputs[name] ? constantOf(toArg(inputs[name])) : fallback;
							if (!c) {
								throw new Error(`material compiler: veach_texture.${name} must be a constant (procedural uvs are not supported yet)`);
							}
							return c;
						};
						op = Op.Texture;
						imm = this.textures.add({
							...file.file,
							uvindex: this.constantInput(node, 'uvindex', 0),
							offset: vector('offset', [0, 0]),
							scale: vector('scale', [1, 1]),
							rotation: this.constantInput(node, 'rotation', 0),
							wrapS: this.constantInput(node, 'uaddressmode', 0),
							wrapT: this.constantInput(node, 'vaddressmode', 0),
						});
						this.textureOfNode.set(n, imm);
						break;
					}
					case 'normalmap':
						if (scalar) {
							throw new Error(`material compiler: ${graph.name}: opacity and emission may not use normalmap`);
						}
						op = Op.NormalMap;
						args = operands([['in', [0.5, 0.5, 1]], ['scale', [1]]]);
						break;
					case 'veach_world_to_object':
					case 'veach_object_to_world':
						if (scalar) {
							throw new Error(`material compiler: ${graph.name}: opacity and emission may not use ${node.category}`);
						}
						op = Op.Transform;
						imm = node.category === 'veach_object_to_world' ? 1 : 0;
						args = operands([['in', [0]]]);
						break;
					case 'veach_blender_noise':
						op = Op.Noise;
						imm = (this.constantInput(node, 'normalize', 1) !== 0 ? NOISE_NORMALIZE : 0) | (node.type !== 'float' ? NOISE_COLOR : 0);
						args = operands([['in', [0]], ['params', [2, 0.5, 2, 0]]]);
						break;
					case 'veach_blender_magic':
						op = Op.Magic;
						imm = this.constantInput(node, 'depth', 2);
						args = operands([['in', [0]], ['distortion', [1]]]);
						break;
					case 'veach_blender_checker':
						op = Op.Checker;
						args = operands([['in', [0]]]);
						break;
					default:
						throw new Error(`material compiler: unsupported node ${node.category}`);
				}
			}

			// operands are read before the result is written, so a dying operand's slot is reusable
			for (const r of new Set(operandsOf(Object.values(inputs)))) {
				if (lastUse.get(r) === i) {
					free.push(slot.get(r)!);
				}
			}
			free.sort((a, b) => b - a);
			const dst = free.length > 0 ? free.pop()! : size++;
			slot.set(n, dst);
			this.emit(op, dst, imm, args);
		});

		OUTPUT_GROUPS.forEach((group, g) => {
			const args = group.map((f) => (present.includes(f) ? operand(surface.inputs[f], []) : OPERAND_NONE));
			if (args.some((a) => a !== OPERAND_NONE)) {
				this.emit(Op.Output, 0, g, args);
			}
		});
		this.emit(Op.End, 0, 0, []);

		if (size > MAX_STACK_SIZE) {
			throw new Error(`material compiler: ${graph.name} needs ${size} stack slots (max ${MAX_STACK_SIZE})`);
		}
		this.stackSize = Math.max(this.stackSize, size);
		return offset;
	}
}

export function compileMaterial(graph: MaterialGraph): CompiledMaterial {
	const g = optimizeGraph(lowerGraph(graph));
	const surfaceInputs = g.nodes[g.surface].inputs;
	const c = new ProgramCompiler(g);
	const surface = c.compile(SURFACE_FIELDS);
	const opacity = c.compile(OPACITY_FIELDS, true);
	const emission = c.compile(EMISSION_FIELDS, true);

	let debugTexture = -1;
	const findTexture = (input: Input | undefined) => {
		if (debugTexture < 0 && input && isConnection(input)) {
			debugTexture = c.textureOfNode.get(input.node) ?? -1;
			Object.values(g.nodes[input.node].inputs).forEach(findTexture);
		}
	};
	findTexture(surfaceInputs.base_color);
	return {
		name: g.name,
		alphaMode: g.alphaMode,
		alphaCutoff: g.alphaCutoff,
		doubleSided: g.doubleSided,
		code: Uint32Array.from(c.code),
		constants: Float32Array.from(c.constants.lanes),
		textures: c.textures.entries,
		surface,
		opacity,
		emission,
		stackSize: c.stackSize,
		alphaTested: g.alphaMode !== AlphaMode.Opaque && surfaceInputs.geometry_opacity !== undefined,
		emissive: surfaceInputs.emission_luminance !== undefined,
		debugTexture,
	};
}
