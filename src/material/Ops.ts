// Pure math nodes, shared by constant folding and the CPU evaluator.
import { TYPE_SIZE, type ValueType } from './Graph';
import { blenderChecker, blenderMagic, blenderNoise } from './Procedural';

const MATH_CATEGORIES = new Set([
	'add',
	'subtract',
	'multiply',
	'divide',
	'min',
	'max',
	'power',
	'atan2',
	'sqrt',
	'sin',
	'cos',
	'absval',
	'clamp',
	'mix',
	'extract',
	'convert',
	'combine2',
	'combine3',
	'combine4',
	'dotproduct',
	'normalize',
	'floor',
	'sign',
	'exp',
	'ln',
	'modulo',
	'crossproduct',
	'veach_greater', // in1 > in2 ? 1 : 0
	// Blender procedural textures (src/material/Procedural.ts) at scaled coordinates `in`.
	'veach_blender_noise', // params = (detail, roughness, lacunarity, distortion), normalize; color3 = (fac, g, b)
	'veach_blender_magic', // distortion, depth; color4 = (rgb, fac)
	'veach_blender_checker', // float
]);

export function isMathCategory(category: string): boolean {
	return MATH_CATEGORIES.has(category);
}

// Component-wise with a float operand broadcast, like MaterialX's FA node variants.
function zip(a: number[], b: number[], f: (x: number, y: number) => number): number[] {
	const n = Math.max(a.length, b.length);
	const out = new Array<number>(n);
	for (let i = 0; i < n; i++) {
		out[i] = f(a.length === 1 ? a[0] : a[i], b.length === 1 ? b[0] : b[i]);
	}
	return out;
}

function zip3(a: number[], b: number[], c: number[], f: (x: number, y: number, z: number) => number): number[] {
	const n = Math.max(a.length, b.length, c.length);
	const at = (v: number[], i: number) => (v.length === 1 ? v[0] : v[i]);
	const out = new Array<number>(n);
	for (let i = 0; i < n; i++) {
		out[i] = f(at(a, i), at(b, i), at(c, i));
	}
	return out;
}

export function convertValue(v: number[], type: ValueType): number[] {
	const n = TYPE_SIZE[type];
	if (v.length === n) {
		return v;
	}
	if (v.length === 1) {
		return new Array(n).fill(v[0]);
	}
	if (v.length > n) {
		return v.slice(0, n);
	}
	// widening: color alpha is opaque, vectors pad with 0
	const pad = type === 'color4' ? 1 : 0;
	return [...v, ...new Array(n - v.length).fill(pad)];
}

export function evalMath(category: string, type: ValueType, inputs: Record<string, number[]>): number[] {
	const in1 = inputs.in1 ?? [0];
	const in2 = inputs.in2 ?? [category === 'multiply' || category === 'divide' || category === 'power' ? 1 : 0];
	const x = inputs.in ?? [0];
	switch (category) {
		case 'add':
			return zip(in1, in2, (a, b) => a + b);
		case 'subtract':
			return zip(in1, in2, (a, b) => a - b);
		case 'multiply':
			return zip(in1, in2, (a, b) => a * b);
		case 'divide':
			return zip(in1, in2, (a, b) => a / b);
		case 'min':
			return zip(in1, in2, Math.min);
		case 'max':
			return zip(in1, in2, Math.max);
		case 'power':
			return zip(in1, in2, Math.pow);
		case 'atan2':
			return zip(inputs.iny ?? [0], inputs.inx ?? [1], Math.atan2);
		case 'sqrt':
			return x.map(Math.sqrt);
		case 'sin':
			return x.map(Math.sin);
		case 'cos':
			return x.map(Math.cos);
		case 'absval':
			return x.map(Math.abs);
		case 'clamp':
			return zip3(x, inputs.low ?? [0], inputs.high ?? [1], (v, lo, hi) => Math.min(Math.max(v, lo), hi));
		case 'mix':
			return zip3(inputs.bg ?? [0], inputs.fg ?? [0], inputs.mix ?? [0], (bg, fg, t) => bg + (fg - bg) * t);
		case 'extract':
			return [x[(inputs.index ?? [0])[0]] ?? 0];
		case 'convert':
			return convertValue(x, type);
		case 'combine2':
		case 'combine3':
		case 'combine4':
			return ['in1', 'in2', 'in3', 'in4'].slice(0, TYPE_SIZE[type]).map((name) => (inputs[name] ?? [0])[0]);
		case 'dotproduct':
			return [zip(in1, in2, (a, b) => a * b).reduce((s, v) => s + v, 0)];
		case 'normalize': {
			const len = Math.hypot(...x);
			return len > 0 ? x.map((v) => v / len) : x.map(() => 0);
		}
		case 'floor':
			return x.map(Math.floor);
		case 'sign':
			return x.map(Math.sign);
		case 'exp':
			return x.map(Math.exp);
		case 'ln':
			return x.map(Math.log);
		case 'modulo':
			return zip(in1, in2, (a, b) => a - b * Math.floor(a / b));
		case 'veach_greater':
			return zip(in1, in2, (a, b) => (a > b ? 1 : 0));
		case 'crossproduct': {
			const a = convertValue(in1, 'vector3');
			const b = convertValue(in2, 'vector3');
			return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
		}
		case 'veach_blender_noise': {
			const color = type !== 'float';
			const v = blenderNoise(convertValue(x, 'vector3'), inputs.params ?? [2, 0.5, 2, 0], (inputs.normalize ?? [1])[0] !== 0, color);
			return color ? v : [v[0]];
		}
		case 'veach_blender_magic': {
			const c = blenderMagic(convertValue(x, 'vector3'), (inputs.depth ?? [2])[0], (inputs.distortion ?? [1])[0]);
			return [...c, (c[0] + c[1] + c[2]) / 3];
		}
		case 'veach_blender_checker':
			return [blenderChecker(convertValue(x, 'vector3'))];
		default:
			throw new Error(`material graph: ${category} is not a math node`);
	}
}
