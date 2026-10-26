// Material node graphs: a subset of the MaterialX standard library, with MaterialX node and input
// names. Every material ends in one surfaceshader node; see docs/MaterialSystem.md.
import type { AlphaMode } from '../scene/Scene';
import { MULTI_OUTPUT_TYPES } from './NodeDefs';
import { evalMath, isMathCategory } from './Ops';

export type ValueType = 'float' | 'integer' | 'boolean' | 'vector2' | 'vector3' | 'vector4' | 'color3' | 'color4' | 'surfaceshader';

export const TYPE_SIZE: Record<ValueType, number> = {
	float: 1,
	integer: 1,
	boolean: 1,
	vector2: 2,
	vector3: 3,
	vector4: 4,
	color3: 3,
	color4: 4,
	surfaceshader: 0,
};

export type ColorSpace = 'srgb_texture' | 'lin_rec709';

// A texture of SceneDesc.textures. The colorspace only affects rgb; alpha is always linear.
export interface TextureFile {
	source: number;
	colorspace: ColorSpace;
}

export interface Connection {
	node: number;
	output: string;
}

export type Input = { value: number[] } | { file: TextureFile } | Connection;

export interface GraphNode {
	category: string;
	type: ValueType; // type of the 'out' output
	inputs: Record<string, Input>;
}

export interface MaterialGraph {
	name: string;
	nodes: GraphNode[]; // topologically ordered: connections only reference earlier nodes
	surface: number; // index of the surfaceshader node
	// Not shading inputs in MaterialX, but needed by traversal (alpha test) and the instance setup.
	alphaMode: AlphaMode;
	alphaCutoff: number;
	doubleSided: boolean;
}

// What builder methods accept for an input; numbers and arrays are values.
export type Arg = number | boolean | readonly number[] | Connection | TextureFile;

export function isConnection(input: Input | Arg): input is Connection {
	return typeof input === 'object' && 'node' in input;
}

export function isTextureFile(input: Input | Arg): input is TextureFile {
	return typeof input === 'object' && 'source' in input;
}

export function toInput(arg: Arg): Input {
	if (typeof arg === 'number') {
		return { value: [arg] };
	}
	if (typeof arg === 'boolean') {
		return { value: [arg ? 1 : 0] };
	}
	if (isConnection(arg)) {
		return { node: arg.node, output: arg.output };
	}
	if (isTextureFile(arg)) {
		return { file: { ...arg } };
	}
	return { value: [...(arg as readonly number[])] };
}

// The inverse of toInput.
export function toArg(input: Input): Arg {
	if ('value' in input) {
		return input.value;
	}
	if ('file' in input) {
		return input.file;
	}
	return { node: input.node, output: input.output };
}

export function outputType(nodes: readonly GraphNode[], c: Connection): ValueType {
	const node = nodes[c.node];
	if (c.output === 'out') {
		return node.type;
	}
	const type = MULTI_OUTPUT_TYPES[node.category]?.[c.output];
	if (!type) {
		throw new Error(`material graph: ${node.category} has no output ${c.output}`);
	}
	return type;
}

// The constant value of an argument, or null when it is connected.
export function constantOf(arg: Arg | undefined): number[] | null {
	if (arg === undefined || isConnection(arg) || isTextureFile(arg)) {
		return null;
	}
	return typeof arg === 'number' ? [arg] : typeof arg === 'boolean' ? [arg ? 1 : 0] : [...arg];
}

export function isConstant(arg: Arg | undefined, value: number): boolean {
	const c = constantOf(arg);
	return c !== null && c.every((x) => x === value);
}

const SIZE_TYPE: ValueType[] = ['float', 'float', 'vector2', 'color3', 'color4'];

function inputKey(input: Input): string {
	if ('value' in input) {
		return input.value.map(String).join(',');
	}
	if ('file' in input) {
		return `file:${input.file.source}:${input.file.colorspace}`;
	}
	return `#${input.node}.${input.output}`;
}

function nodeKey(node: GraphNode): string {
	const inputs = Object.keys(node.inputs)
		.sort()
		.map((name) => `${name}=${inputKey(node.inputs[name])}`);
	return `${node.category}:${node.type}(${inputs.join(';')})`;
}

// Appends nodes; identical nodes are merged (every node is a pure function of its inputs), and
// the math helpers fold constants and drop identities as they build.
export class GraphBuilder {
	readonly nodes: GraphNode[] = [];
	private readonly keys = new Map<string, number>();

	node(category: string, type: ValueType, inputs: Record<string, Arg | undefined>): Connection {
		const node: GraphNode = { category, type, inputs: {} };
		for (const [name, arg] of Object.entries(inputs)) {
			if (arg !== undefined) {
				node.inputs[name] = toInput(arg);
			}
		}
		const key = nodeKey(node);
		let index = this.keys.get(key);
		if (index === undefined) {
			index = this.nodes.push(node) - 1;
			this.keys.set(key, index);
		}
		return { node: index, output: 'out' };
	}

	// Rebuilds a node through the simplifying helpers.
	replay(category: string, type: ValueType, inputs: Record<string, Arg | undefined>): Arg {
		const { in1, in2 } = inputs;
		const binary = in1 !== undefined && in2 !== undefined && Object.keys(inputs).length === 2;
		switch (category) {
			case 'multiply':
				return binary ? this.mul(in1, in2) : this.math(category, type, inputs);
			case 'add':
				return binary ? this.add(in1, in2) : this.math(category, type, inputs);
			case 'subtract':
				return binary ? this.sub(in1, in2) : this.math(category, type, inputs);
			case 'divide':
				return binary ? this.div(in1, in2) : this.math(category, type, inputs);
			case 'mix':
				return inputs.bg !== undefined && inputs.fg !== undefined && inputs.mix !== undefined ? this.mix(inputs.bg, inputs.fg, inputs.mix) : this.math(category, type, inputs);
			case 'extract':
			case 'convert':
				if (inputs.in !== undefined && this.sizeOf(inputs.in) === TYPE_SIZE[type]) {
					return inputs.in;
				}
				return this.math(category, type, inputs);
			default:
				return isMathCategory(category) ? this.math(category, type, inputs) : this.node(category, type, inputs);
		}
	}

	typeOf(arg: Arg): ValueType {
		if (isConnection(arg)) {
			return outputType(this.nodes, arg);
		}
		const c = constantOf(arg);
		if (!c || c.length > 4) {
			throw new Error('material graph: argument has no value type');
		}
		return SIZE_TYPE[c.length];
	}

	sizeOf(arg: Arg): number {
		return TYPE_SIZE[this.typeOf(arg)];
	}

	// A math node, folded when every input is constant.
	math(category: string, type: ValueType, inputs: Record<string, Arg | undefined>): Arg {
		const values: Record<string, number[]> = {};
		let constant = true;
		for (const [name, arg] of Object.entries(inputs)) {
			if (arg === undefined) {
				continue;
			}
			const c = constantOf(arg);
			if (!c) {
				constant = false;
				break;
			}
			values[name] = c;
		}
		if (constant && isMathCategory(category)) {
			return evalMath(category, type, values);
		}
		return this.node(category, type, inputs);
	}

	private binaryType(a: Arg, b: Arg): ValueType {
		return this.sizeOf(a) >= this.sizeOf(b) ? this.typeOf(a) : this.typeOf(b);
	}

	mul(a: Arg, b: Arg): Arg {
		const type = this.binaryType(a, b);
		if (isConstant(a, 0) || isConstant(b, 0)) {
			return new Array(TYPE_SIZE[type]).fill(0);
		}
		if (isConstant(b, 1) && this.sizeOf(a) === TYPE_SIZE[type]) {
			return a;
		}
		if (isConstant(a, 1) && this.sizeOf(b) === TYPE_SIZE[type]) {
			return b;
		}
		// (x * c1) * c2 = x * (c1 * c2)
		const c2 = constantOf(b) ?? constantOf(a);
		const product = constantOf(b) ? a : b;
		const inner = c2 && isConnection(product) && product.output === 'out' ? this.nodes[product.node] : null;
		if (inner?.category === 'multiply') {
			const { in1, in2 } = inner.inputs;
			const [x, c1] = in2 && 'value' in in2 ? [in1, in2.value] : in1 && 'value' in in1 ? [in2, in1.value] : [undefined, null];
			if (x && isConnection(x) && c1) {
				return this.mul(toArg(x), evalMath('multiply', type, { in1: c1, in2: c2! }));
			}
		}
		return this.math('multiply', type, { in1: a, in2: b });
	}

	add(a: Arg, b: Arg): Arg {
		const type = this.binaryType(a, b);
		if (isConstant(b, 0) && this.sizeOf(a) === TYPE_SIZE[type]) {
			return a;
		}
		if (isConstant(a, 0) && this.sizeOf(b) === TYPE_SIZE[type]) {
			return b;
		}
		return this.math('add', type, { in1: a, in2: b });
	}

	sub(a: Arg, b: Arg): Arg {
		const type = this.binaryType(a, b);
		if (isConstant(b, 0) && this.sizeOf(a) === TYPE_SIZE[type]) {
			return a;
		}
		return this.math('subtract', type, { in1: a, in2: b });
	}

	div(a: Arg, b: Arg): Arg {
		const type = this.binaryType(a, b);
		if (isConstant(b, 1) && this.sizeOf(a) === TYPE_SIZE[type]) {
			return a;
		}
		return this.math('divide', type, { in1: a, in2: b });
	}

	max(a: Arg, b: Arg): Arg {
		return this.math('max', this.binaryType(a, b), { in1: a, in2: b });
	}

	mix(bg: Arg, fg: Arg, t: Arg): Arg {
		if (isConstant(t, 0)) {
			return bg;
		}
		if (isConstant(t, 1)) {
			return fg;
		}
		return this.math('mix', this.binaryType(bg, fg), { bg, fg, mix: t });
	}

	saturate(a: Arg): Arg {
		return this.math('clamp', this.typeOf(a), { in: a, low: 0, high: 1 });
	}

	extract(a: Arg, index: number): Arg {
		if (this.sizeOf(a) === 1) {
			return a;
		}
		return this.math('extract', 'float', { in: a, index });
	}

	convert(a: Arg, type: ValueType): Arg {
		if (this.sizeOf(a) === TYPE_SIZE[type]) {
			return a;
		}
		return this.math('convert', type, { in: a });
	}

	unary(category: 'sin' | 'cos' | 'sqrt' | 'normalize', a: Arg): Arg {
		return this.math(category, this.typeOf(a), { in: a });
	}

	atan2(y: Arg, x: Arg): Arg {
		return this.math('atan2', 'float', { iny: y, inx: x });
	}
}
