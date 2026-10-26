// Blender shader node trees -> MaterialGraph (open_pbr_surface). Covers the nodes the Cycles
// principled_bsdf render tests use, with the versioning of pre-4.0 Principled sockets; unsupported
// nodes fall back to their socket defaults and are reported.
import type { Vec3 } from '../../math/Math';
import { GraphBuilder, isConnection, type Arg, type MaterialGraph, type ValueType } from '../../material/Graph';
import { OPEN_PBR_SURFACE } from '../../material/NodeDefs';
import { AlphaMode } from '../../scene/Scene';
import type { BStruct } from './BlendFile';

const SOCK_FLOAT = 0;
const SOCK_VECTOR = 1;
const SOCK_RGBA = 2;
const SOCK_SHADER = 3;
const SOCK_BOOLEAN = 4;
const SOCK_INT = 6;
const NODE_MUTED = 1 << 9;
const NODE_DO_OUTPUT = 1 << 6;
const NODE_LINK_MUTED = 1 << 4;
const SHD_OUTPUT_EEVEE = 1;

const LUMINANCE: Vec3 = [0.2126, 0.7152, 0.0722];

// Mesh texture space in object space: Generated = ((p - location) / size) * 0.5 + 0.5.
export interface TexSpace {
	location: Vec3;
	size: Vec3;
}

interface Socket {
	s: BStruct;
	node: Node;
	identifier: string;
	type: number;
	link: Socket | null; // the output feeding an input
}

interface Node {
	s: BStruct;
	idname: string;
	name: string;
	inputs: Socket[];
	outputs: Socket[];
}

type Want = 'float' | 'vector3' | 'color3';

// Bump evaluation shifts the shading point by a world-space offset.
interface Ctx {
	offset: Arg | null;
	key: string;
}

// open_pbr_surface inputs; emission is premultiplied into emission_color (luminance 1) so closures mix linearly.
type Surface = Record<string, Arg | undefined>;
interface Closure {
	surface: Surface;
	transparent?: boolean; // Transparent BSDF: only geometry_opacity, every other input comes from what it is mixed with
}

const NO_OFFSET: Ctx = { offset: null, key: '' };

function socketType(type: number): ValueType {
	return type === SOCK_VECTOR ? 'vector3' : type === SOCK_RGBA ? 'color3' : 'float';
}

const VALUE_STRUCTS: Record<number, string> = {
	[SOCK_FLOAT]: 'bNodeSocketValueFloat',
	[SOCK_VECTOR]: 'bNodeSocketValueVector',
	[SOCK_RGBA]: 'bNodeSocketValueRGBA',
	[SOCK_BOOLEAN]: 'bNodeSocketValueBoolean',
	[SOCK_INT]: 'bNodeSocketValueInt',
};

// The default value of a socket, typed by its socket type (older files store it untyped).
function socketValue(s: BStruct): number[] | null {
	const type = s.num('type');
	const struct = VALUE_STRUCTS[type];
	if (!struct || !s.file.sdna.byName.has(struct)) {
		return null;
	}
	const v = s.get('default_value', struct);
	if (!v) {
		return null;
	}
	if (type === SOCK_VECTOR || type === SOCK_RGBA) {
		return v.nums('value').slice(0, 3);
	}
	return [v.num('value')];
}

function storageOf(node: Node, type: string): BStruct | null {
	return node.s.file.sdna.byName.has(type) ? node.s.get('storage', type) : null;
}

function readTree(tree: BStruct): Node[] {
	const nodes: Node[] = [];
	const sockets = new Map<number, Socket>();
	for (const n of tree.list('nodes', 'bNode')) {
		const node: Node = { s: n, idname: n.str('idname'), name: n.str('name'), inputs: [], outputs: [] };
		for (const [list, out] of [['inputs', node.inputs], ['outputs', node.outputs]] as const) {
			for (const s of n.list(list, 'bNodeSocket')) {
				const socket: Socket = { s, node, identifier: s.str('identifier') || s.str('name'), type: s.num('type'), link: null };
				out.push(socket);
				sockets.set(s.offset, socket);
			}
		}
		nodes.push(node);
	}
	for (const l of tree.list('links', 'bNodeLink')) {
		if (l.num('flag') & NODE_LINK_MUTED) {
			continue;
		}
		const from = sockets.get(l.resolve('fromsock')?.offset ?? -1);
		const to = sockets.get(l.resolve('tosock')?.offset ?? -1);
		if (from && to) {
			to.link = from;
		}
	}
	return nodes;
}

// Fresnel reflectance of a conductor with complex IOR n + ik.
function conductorFresnel(n: number, k: number, cosTheta: number): number {
	const c2 = cosTheta * cosTheta;
	const s2 = 1 - c2;
	const n2 = n * n;
	const k2 = k * k;
	const t0 = n2 - k2 - s2;
	const a2b2 = Math.sqrt(t0 * t0 + 4 * n2 * k2);
	const a = Math.sqrt(Math.max(0.5 * (a2b2 + t0), 0));
	const t1 = a2b2 + c2;
	const t2 = 2 * a * cosTheta;
	const rs = (t1 - t2) / (t1 + t2);
	const t3 = c2 * a2b2 + s2 * s2;
	const t4 = t2 * s2;
	const rp = (rs * (t3 - t4)) / (t3 + t4);
	return 0.5 * (rs + rp);
}

// Cycles' anisotropy (alpha_x = r^2 / aspect, alpha_y = r^2 * aspect, aspect = sqrt(1 - 0.9 a)) as
// OpenPBR's (alpha_t = r'^2 sqrt(2 / (1 + (1 - a')^2)), alpha_b = (1 - a') alpha_t): a' = 0.9 a, and r'
// such that both axes match.
function anisotropicRoughness(b: GraphBuilder, roughness: Arg, anisotropy: Arg): { roughness: Arg; anisotropy: Arg } {
	const a = b.mul(b.saturate(anisotropy), 0.9);
	const q = b.sub(1, a); // aspect^2
	const aspect = b.unary('sqrt', q);
	const k = b.unary('sqrt', b.div(b.unary('sqrt', b.mul(b.add(1, b.mul(q, q)), 0.5)), aspect));
	return { roughness: b.mul(roughness, k), anisotropy: a };
}

class Translator {
	readonly b = new GraphBuilder();
	readonly warnings = new Set<string>();
	usesGenerated = false;
	private readonly memo = new Map<string, Arg>();

	constructor(
		private readonly label: string,
		private readonly texspace: TexSpace,
	) {}

	warn(message: string): void {
		this.warnings.add(`${this.label}: ${message}`);
	}

	// ---- values ----

	private convert(arg: Arg, from: ValueType, want: Want): Arg {
		const b = this.b;
		const size = b.sizeOf(arg);
		if (want === 'float') {
			if (size === 1) {
				return arg;
			}
			if (from === 'color3') {
				return b.math('dotproduct', 'float', { in1: arg, in2: LUMINANCE });
			}
			return b.mul(b.math('dotproduct', 'float', { in1: arg, in2: [1, 1, 1] }), 1 / 3);
		}
		return size === 1 ? b.convert(arg, want) : arg;
	}

	input(node: Node, id: string, want: Want, ctx: Ctx, fallback?: number[]): Arg {
		const socket = node.inputs.find((s) => s.identifier === id);
		if (!socket) {
			return fallback ?? (want === 'float' ? [0] : [0, 0, 0]);
		}
		return this.socket(socket, want, ctx);
	}

	has(node: Node, id: string): boolean {
		return node.inputs.some((s) => s.identifier === id);
	}

	linked(node: Node, id: string): boolean {
		return !!node.inputs.find((s) => s.identifier === id)?.link;
	}

	socket(socket: Socket, want: Want, ctx: Ctx): Arg {
		if (socket.link) {
			const from = socket.link;
			const value = this.output(from.node, from.identifier, ctx);
			if (value) {
				return this.convert(value.arg, value.type, want);
			}
		}
		const v = socketValue(socket.s) ?? [0];
		return this.convert(v.length === 1 ? v[0] : v, socketType(socket.type), want);
	}

	// Vector inputs of textures default to Generated coordinates, like Cycles' LINK_TEXTURE_GENERATED.
	textureVector(node: Node, ctx: Ctx): Arg {
		return this.linked(node, 'Vector') ? this.input(node, 'Vector', 'vector3', ctx) : this.generated(ctx);
	}

	private output(node: Node, id: string, ctx: Ctx): { arg: Arg; type: ValueType } | null {
		const key = `${node.s.offset}.${id}${ctx.key}`;
		const socket = node.outputs.find((s) => s.identifier === id);
		const type = socketType(socket?.type ?? SOCK_FLOAT);
		let arg = this.memo.get(key);
		if (arg === undefined) {
			const value = this.evalOutput(node, id, ctx);
			if (value === null) {
				return null;
			}
			arg = value;
			this.memo.set(key, arg);
		}
		return { arg, type };
	}

	// ---- geometry ----

	worldPosition(ctx: Ctx): Arg {
		const p = this.b.node('position', 'vector3', {});
		return ctx.offset ? this.b.add(p, ctx.offset) : p;
	}

	objectPosition(ctx: Ctx): Arg {
		const p = this.b.node('position', 'vector3', { space: 1 });
		return ctx.offset ? this.b.add(p, this.b.node('veach_world_to_object', 'vector3', { in: ctx.offset })) : p;
	}

	generated(ctx: Ctx): Arg {
		this.usesGenerated = true;
		const b = this.b;
		const { location, size } = this.texspace;
		return b.add(b.mul(b.div(b.sub(this.objectPosition(ctx), location), size), 0.5), 0.5);
	}

	uv(): Arg {
		const b = this.b;
		const uv = b.node('texcoord', 'vector2', { index: 0 });
		return b.math('combine3', 'vector3', { in1: b.extract(uv, 0), in2: b.sub(1, b.extract(uv, 1)), in3: 0 });
	}

	normal(): Arg {
		return this.b.node('normal', 'vector3', {});
	}

	// Veach's world is Y-up; Blender's is Z-up.
	toBlenderWorld(v: Arg): Arg {
		const b = this.b;
		return b.math('combine3', 'vector3', { in1: b.extract(v, 0), in2: b.sub(0, b.extract(v, 2)), in3: b.extract(v, 1) });
	}

	// ---- nodes ----

	private evalOutput(node: Node, id: string, ctx: Ctx): Arg | null {
		const b = this.b;
		if (node.s.num('flag') & NODE_MUTED) {
			const pass = node.inputs.find((s) => s.type !== SOCK_SHADER && s.link);
			return pass ? this.socket(pass, 'color3', ctx) : null;
		}
		const f = (name: string, fallback?: number) => this.input(node, name, 'float', ctx, fallback !== undefined ? [fallback] : undefined);
		const v = (name: string) => this.input(node, name, 'vector3', ctx);
		const c = (name: string) => this.input(node, name, 'color3', ctx);
		switch (node.idname) {
			case 'NodeReroute':
				return node.inputs[0] ? this.socket(node.inputs[0], socketType(node.inputs[0].type) as Want, ctx) : null;
			case 'ShaderNodeValue':
			case 'ShaderNodeRGB': {
				const value = socketValue(node.outputs[0].s) ?? [0];
				return value.length === 1 ? value[0] : value;
			}
			case 'ShaderNodeTexCoord':
			case 'ShaderNodeUVMap':
				switch (id) {
					case 'UV':
						return this.uv();
					case 'Generated':
						return this.generated(ctx);
					case 'Object':
						return this.objectPosition(ctx);
					case 'Normal':
						return b.unary('normalize', b.node('veach_world_to_object', 'vector3', { in: this.normal() }));
					default:
						this.warn(`Texture Coordinate ${id} is not supported (using Generated)`);
						return this.generated(ctx);
				}
			case 'ShaderNodeNewGeometry':
				switch (id) {
					case 'Position':
						return this.toBlenderWorld(this.worldPosition(ctx));
					case 'Normal':
					case 'True Normal':
						return this.toBlenderWorld(this.normal());
					default:
						this.warn(`Geometry ${id} is not supported`);
						return [0, 0, 0];
				}
			case 'ShaderNodeSeparateXYZ':
			case 'ShaderNodeSeparateRGB':
			case 'ShaderNodeSeparateColor': {
				const index = ['X', 'R', 'Red'].includes(id) ? 0 : ['Y', 'G', 'Green'].includes(id) ? 1 : 2;
				const input = node.idname === 'ShaderNodeSeparateXYZ' ? v('Vector') : c(node.idname === 'ShaderNodeSeparateRGB' ? 'Image' : 'Color');
				if (node.idname === 'ShaderNodeSeparateColor' && node.s.get('storage')?.num('mode', 0, 0)) {
					this.warn('Separate Color HSV / HSL is not supported (using RGB)');
				}
				return b.extract(input, index);
			}
			case 'ShaderNodeCombineXYZ':
				return b.math('combine3', 'vector3', { in1: f('X'), in2: f('Y'), in3: f('Z') });
			case 'ShaderNodeCombineRGB':
				return b.math('combine3', 'color3', { in1: f('R'), in2: f('G'), in3: f('B') });
			case 'ShaderNodeCombineColor':
				return b.math('combine3', 'color3', { in1: f('Red'), in2: f('Green'), in3: f('Blue') });
			case 'ShaderNodeMath':
				return this.math(node, ctx);
			case 'ShaderNodeVectorMath':
				return this.vectorMath(node, id, ctx);
			case 'ShaderNodeMix':
				return this.mix(node, ctx);
			case 'ShaderNodeMixRGB': {
				const out = this.blend(node.s.num('custom1'), f('Fac'), c('Color1'), c('Color2'));
				return node.s.num('custom2') & 2 ? b.saturate(out) : out;
			}
			case 'ShaderNodeInvert': {
				const color = c('Color');
				return b.mix(color, b.sub(1, color), b.saturate(f('Fac')));
			}
			case 'ShaderNodeGamma':
				return b.math('power', 'color3', { in1: b.max(c('Color'), 0), in2: f('Gamma') });
			case 'ShaderNodeMapRange':
				return this.mapRange(node, ctx);
			case 'ShaderNodeClamp': {
				const min = f('Min');
				const max = f('Max');
				return b.math('clamp', 'float', { in: f('Value'), low: min, high: max });
			}
			case 'ShaderNodeValToRGB':
				return this.colorRamp(node, id, ctx);
			case 'ShaderNodeTexChecker': {
				const fac = b.math('veach_blender_checker', 'float', { in: b.mul(this.textureVector(node, ctx), f('Scale')) });
				return id === 'Fac' ? fac : b.mix(c('Color2'), c('Color1'), fac);
			}
			case 'ShaderNodeTexNoise':
				return this.noise(node, id, ctx);
			case 'ShaderNodeTexMagic': {
				const storage = storageOf(node, 'NodeTexMagic');
				const rgbf = b.math('veach_blender_magic', 'color4', {
					in: b.mul(this.textureVector(node, ctx), f('Scale')),
					distortion: f('Distortion'),
					depth: storage?.num('depth') ?? 2,
				});
				return id === 'Fac' ? b.extract(rgbf, 3) : b.convert(rgbf, 'color3');
			}
			case 'ShaderNodeBump':
				return this.bump(node, ctx);
			case 'ShaderNodeNormal':
				return this.normal();
			default:
				this.warn(`${node.idname} (${node.name}) is not supported`);
				return null;
		}
	}

	private math(node: Node, ctx: Ctx): Arg {
		const b = this.b;
		const op = node.s.num('custom1');
		const a = this.input(node, 'Value', 'float', ctx);
		const x = this.input(node, 'Value_001', 'float', ctx);
		const y = this.input(node, 'Value_002', 'float', ctx);
		const fl = (v: Arg) => b.math('floor', 'float', { in: v });
		const un = (category: string, v: Arg) => b.math(category, 'float', { in: v });
		let r: Arg;
		switch (op) {
			case 0: r = b.add(a, x); break;
			case 1: r = b.sub(a, x); break;
			case 2: r = b.mul(a, x); break;
			case 3: r = b.div(a, x); break;
			case 4: r = b.unary('sin', a); break;
			case 5: r = b.unary('cos', a); break;
			case 6: r = b.div(b.unary('sin', a), b.unary('cos', a)); break;
			case 9: r = b.atan2(a, 1); break;
			case 10: r = b.math('power', 'float', { in1: a, in2: x }); break;
			case 11: r = b.div(un('ln', a), un('ln', x)); break;
			case 12: r = b.math('min', 'float', { in1: a, in2: x }); break;
			case 13: r = b.max(a, x); break;
			case 14: r = fl(b.add(a, 0.5)); break;
			case 15: r = b.math('veach_greater', 'float', { in1: x, in2: a }); break;
			case 16: r = b.math('veach_greater', 'float', { in1: a, in2: x }); break;
			case 17: { // fmod
				const q = b.div(a, x);
				r = b.sub(a, b.mul(x, b.mul(un('sign', q), fl(un('absval', q)))));
				break;
			}
			case 18: r = un('absval', a); break;
			case 19: r = b.atan2(a, x); break;
			case 20: r = fl(a); break;
			case 21: r = b.sub(0, fl(b.sub(0, a))); break;
			case 22: r = b.sub(a, fl(a)); break;
			case 23: r = b.unary('sqrt', b.max(a, 0)); break;
			case 24: r = b.div(1, b.unary('sqrt', b.max(a, 0))); break;
			case 25: r = un('sign', a); break;
			case 26: r = un('exp', a); break;
			case 27: r = b.mul(a, Math.PI / 180); break;
			case 28: r = b.mul(a, 180 / Math.PI); break;
			case 32: r = b.mul(un('sign', a), fl(un('absval', a))); break;
			case 33: r = b.mul(fl(b.div(a, x)), x); break;
			case 34: { // wrap(a, max, min)
				const range = b.sub(x, y);
				r = b.sub(a, b.mul(range, fl(b.div(b.sub(a, y), range))));
				break;
			}
			case 35: // compare
				r = b.sub(1, b.math('veach_greater', 'float', { in1: un('absval', b.sub(a, x)), in2: b.max(y, 1e-5) }));
				break;
			case 36: r = b.add(b.mul(a, x), y); break;
			case 37: { // ping-pong
				const t = b.div(b.sub(a, x), b.mul(x, 2));
				r = un('absval', b.sub(b.mul(b.sub(t, fl(t)), b.mul(x, 2)), x));
				break;
			}
			case 38: r = b.math('min', 'float', { in1: a, in2: x }); this.warn('Smooth Min is approximated by Min'); break;
			case 39: r = b.max(a, x); this.warn('Smooth Max is approximated by Max'); break;
			case 40: r = b.math('modulo', 'float', { in1: a, in2: x }); break;
			default:
				this.warn(`Math operation ${op} is not supported`);
				r = a;
		}
		return node.s.num('custom2') & 1 ? b.saturate(r) : r;
	}

	private vectorMath(node: Node, id: string, ctx: Ctx): Arg {
		const b = this.b;
		const op = node.s.num('custom1');
		const a = this.input(node, 'Vector', 'vector3', ctx);
		const x = this.input(node, 'Vector_001', 'vector3', ctx);
		const y = this.input(node, 'Vector_002', 'vector3', ctx);
		const dot = (p: Arg, q: Arg) => b.math('dotproduct', 'float', { in1: p, in2: q });
		const un = (category: string, v: Arg) => b.math(category, 'vector3', { in: v });
		let vector: Arg = [0, 0, 0];
		let value: Arg = 0;
		switch (op) {
			case 0: vector = b.add(a, x); break;
			case 1: vector = b.sub(a, x); break;
			case 2: vector = b.mul(a, x); break;
			case 3: vector = b.div(a, x); break;
			case 4: vector = b.math('crossproduct', 'vector3', { in1: a, in2: x }); break;
			case 5: vector = b.mul(x, b.div(dot(a, x), dot(x, x))); break;
			case 6: { const n = b.unary('normalize', x); vector = b.sub(a, b.mul(n, b.mul(dot(a, n), 2))); break; }
			case 7: value = dot(a, x); break;
			case 8: value = b.unary('sqrt', dot(b.sub(a, x), b.sub(a, x))); break;
			case 9: value = b.unary('sqrt', dot(a, a)); break;
			case 10: vector = b.mul(a, this.input(node, 'Scale', 'float', ctx)); break;
			case 11: vector = b.unary('normalize', a); break;
			case 13: vector = un('floor', a); break;
			case 16: vector = b.sub(a, un('floor', a)); break;
			case 17: vector = un('absval', a); break;
			case 18: vector = b.math('min', 'vector3', { in1: a, in2: x }); break;
			case 19: vector = b.max(a, x); break;
			case 21: vector = b.unary('sin', a); break;
			case 22: vector = b.unary('cos', a); break;
			case 26: vector = b.add(b.mul(a, x), y); break;
			default:
				this.warn(`Vector Math operation ${op} is not supported`);
				vector = a;
		}
		return id === 'Value' ? value : vector;
	}

	// Blender's ramp_blend for the color blend modes.
	private blend(type: number, fac: Arg, a: Arg, c: Arg): Arg {
		const b = this.b;
		const t = b.saturate(fac);
		switch (type) {
			case 0: return b.mix(a, c, t);
			case 1: return b.add(a, b.mul(c, t));
			case 2: return b.mix(a, b.mul(a, c), t);
			case 3: return b.sub(a, b.mul(c, t));
			case 4: return b.sub(1, b.mul(b.add(b.sub(1, t), b.mul(t, b.sub(1, c))), b.sub(1, a)));
			case 5: return b.mix(a, b.div(a, c), t);
			case 6: return b.mix(a, b.math('absval', 'color3', { in: b.sub(a, c) }), t);
			case 7: return b.mix(a, b.math('min', 'color3', { in1: a, in2: c }), t);
			case 8: return b.mix(a, b.max(a, c), t);
			default:
				this.warn(`Mix blend mode ${type} is approximated by Mix`);
				return b.mix(a, c, t);
		}
	}

	private mix(node: Node, ctx: Ctx): Arg {
		const b = this.b;
		const storage = storageOf(node, 'NodeShaderMix');
		const dataType = storage?.num('data_type') ?? SOCK_FLOAT;
		const clampFactor = storage?.num('clamp_factor', 0, 1) ?? 1;
		const suffix = dataType === SOCK_RGBA ? 'Color' : dataType === SOCK_VECTOR ? 'Vector' : 'Float';
		const want: Want = dataType === SOCK_RGBA ? 'color3' : dataType === SOCK_VECTOR ? 'vector3' : 'float';
		const nonUniform = dataType === SOCK_VECTOR && storage?.num('factor_mode', 0, 0) === 1;
		let fac = nonUniform ? this.input(node, 'Factor_Vector', 'vector3', ctx) : this.input(node, 'Factor_Float', 'float', ctx);
		if (clampFactor) {
			fac = b.saturate(fac);
		}
		const a = this.input(node, `A_${suffix}`, want, ctx);
		const c = this.input(node, `B_${suffix}`, want, ctx);
		if (dataType !== SOCK_RGBA) {
			return b.mix(a, c, fac);
		}
		const out = this.blend(storage?.num('blend_type') ?? 0, fac, a, c);
		return storage?.num('clamp_result') ? b.saturate(out) : out;
	}

	private mapRange(node: Node, ctx: Ctx): Arg {
		const b = this.b;
		const f = (name: string) => this.input(node, name, 'float', ctx);
		const storage = storageOf(node, 'NodeMapRange');
		const interpolation = storage?.num('interpolation_type') ?? node.s.num('custom2');
		const fromMin = f('From Min');
		const fromMax = f('From Max');
		const toMin = f('To Min');
		const toMax = f('To Max');
		let t = b.div(b.sub(f('Value'), fromMin), b.sub(fromMax, fromMin));
		if (interpolation === 1) {
			const steps = f('Steps');
			t = b.div(b.math('floor', 'float', { in: b.mul(t, b.add(steps, 1)) }), steps);
		} else if (interpolation === 2 || interpolation === 3) {
			t = b.saturate(t);
			t = interpolation === 2 ? b.mul(b.mul(t, t), b.sub(3, b.mul(t, 2))) : b.mul(b.mul(b.mul(t, t), t), b.add(b.mul(t, b.sub(b.mul(t, 6), 15)), 10));
		}
		const out = b.add(toMin, b.mul(t, b.sub(toMax, toMin)));
		const clamp = storage?.num('clamp') ?? node.s.num('custom1');
		if (clamp && interpolation !== 2 && interpolation !== 3) {
			return b.math('clamp', 'float', { in: out, low: b.math('min', 'float', { in1: toMin, in2: toMax }), high: b.max(toMin, toMax) });
		}
		return out;
	}

	private colorRamp(node: Node, id: string, ctx: Ctx): Arg {
		const b = this.b;
		const band = storageOf(node, 'ColorBand');
		const fac = this.input(node, 'Fac', 'float', ctx);
		if (!band) {
			return id === 'Alpha' ? 1 : fac;
		}
		const ipo = band.num('ipotype');
		if (ipo === 2 || ipo === 3) {
			this.warn('Color Ramp B-Spline / Cardinal is approximated by Linear');
		}
		const stops = Array.from({ length: Math.max(band.num('tot'), 1) }, (_, i) => band.sub('data', i))
			.map((d) => ({ pos: d.num('pos'), color: [d.num('r'), d.num('g'), d.num('b')], alpha: d.num('a') }))
			.sort((p, q) => p.pos - q.pos);
		const pick = (s: (typeof stops)[number]) => (id === 'Alpha' ? s.alpha : s.color);
		let out: Arg = pick(stops[0]);
		for (let i = 0; i + 1 < stops.length; i++) {
			const p0 = stops[i].pos;
			const p1 = stops[i + 1].pos;
			let t: Arg;
			if (ipo === 4 || p1 <= p0) {
				t = b.math('veach_greater', 'float', { in1: fac, in2: p1 - 1e-6 });
			} else {
				t = b.saturate(b.div(b.sub(fac, p0), p1 - p0));
				if (ipo === 1) {
					t = b.mul(b.mul(t, t), b.sub(3, b.mul(t, 2)));
				}
			}
			out = b.mix(out, pick(stops[i + 1]), t);
		}
		return out;
	}

	private noise(node: Node, id: string, ctx: Ctx): Arg {
		const b = this.b;
		const storage = storageOf(node, 'NodeTexNoise');
		const dimensions = storage?.num('dimensions', 0, 3) ?? 3;
		if (dimensions !== 3) {
			this.warn(`Noise Texture ${dimensions}D is evaluated in 3D`);
		}
		if ((storage?.num('type', 0, 1) ?? 1) !== 1) {
			this.warn('Noise Texture types other than fBM are evaluated as fBM');
		}
		const f = (name: string, fallback: number) => (this.has(node, name) ? this.input(node, name, 'float', ctx) : fallback);
		const params = b.math('combine4', 'vector4', { in1: f('Detail', 2), in2: f('Roughness', 0.5), in3: f('Lacunarity', 2), in4: f('Distortion', 0) });
		const color = id === 'Color';
		return b.math('veach_blender_noise', color ? 'color3' : 'float', {
			in: b.mul(this.textureVector(node, ctx), f('Scale', 5)),
			params,
			normalize: storage?.num('normalize', 0, 1) ?? 1,
		});
	}

	// Cycles' svm_node_set_bump with the height evaluated at two offset points along an
	// orthonormal frame around the normal: N' = normalize(N - distance * surface gradient).
	private bump(node: Node, ctx: Ctx): Arg {
		const b = this.b;
		const n = this.linked(node, 'Normal') ? b.unary('normalize', this.input(node, 'Normal', 'vector3', ctx)) : this.normal();
		const height = node.inputs.find((s) => s.identifier === 'Height');
		if (!height?.link) {
			return n;
		}
		const EPS = 1e-3;
		const ny = b.math('absval', 'float', { in: b.extract(n, 1) });
		const axis = b.mix([1, 0, 0], [0, 1, 0], b.math('veach_greater', 'float', { in1: 0.9, in2: ny }));
		const t = b.unary('normalize', b.math('crossproduct', 'vector3', { in1: axis, in2: n }));
		const bt = b.math('crossproduct', 'vector3', { in1: n, in2: t });
		const at = (offset: Arg | null, key: string): Arg => {
			const base = ctx.offset;
			const shifted: Ctx = offset === null ? ctx : { offset: base ? b.add(base, offset) : offset, key: `${ctx.key}|${key}${node.s.offset}` };
			return this.socket(height, 'float', shifted);
		};
		const hc = at(null, '');
		const hx = at(b.mul(t, EPS), 'x');
		const hy = at(b.mul(bt, EPS), 'y');
		let distance = this.input(node, 'Distance', 'float', ctx);
		if (node.s.num('custom1')) {
			distance = b.sub(0, distance);
		}
		const gradient = b.add(b.mul(t, b.div(b.sub(hx, hc), EPS)), b.mul(bt, b.div(b.sub(hy, hc), EPS)));
		const bumped = b.unary('normalize', b.sub(n, b.mul(gradient, distance)));
		const strength = b.max(this.input(node, 'Strength', 'float', ctx), 0);
		return b.unary('normalize', b.mix(n, bumped, b.math('min', 'float', { in1: strength, in2: 1 })));
	}

	// ---- closures ----

	closure(socket: Socket | undefined, ctx: Ctx): Closure | null {
		const from = socket?.link;
		if (!from) {
			return null;
		}
		const node = from.node;
		const b = this.b;
		const f = (name: string, fallback?: number) => this.input(node, name, 'float', ctx, fallback !== undefined ? [fallback] : undefined);
		const c = (name: string) => this.input(node, name, 'color3', ctx);
		const normal = (name: string): Arg | undefined => (this.linked(node, name) ? b.unary('normalize', this.input(node, name, 'vector3', ctx)) : undefined);
		switch (node.idname) {
			case 'NodeReroute':
				return this.closure(node.inputs[0], ctx);
			case 'ShaderNodeBsdfPrincipled':
				return { surface: this.principled(node, ctx) };
			case 'ShaderNodeBsdfDiffuse':
				return { surface: { base_color: c('Color'), base_diffuse_roughness: f('Roughness'), specular_weight: 0, geometry_normal: normal('Normal') } };
			case 'ShaderNodeEmission':
				return { surface: { base_weight: 0, specular_weight: 0, emission_luminance: 1, emission_color: b.mul(c('Color'), f('Strength')) } };
			case 'ShaderNodeBackground':
				return { surface: { base_weight: 0, specular_weight: 0, emission_luminance: 1, emission_color: b.mul(c('Color'), f('Strength')) } };
			case 'ShaderNodeBsdfTranslucent':
				return {
					surface: { base_weight: 0, specular_weight: 0, subsurface_weight: 1, subsurface_color: c('Color'), geometry_thin_walled: true, geometry_normal: normal('Normal') },
				};
			case 'ShaderNodeBsdfMetallic':
				return { surface: this.metallic(node, ctx) };
			case 'ShaderNodeBsdfGlossy':
			case 'ShaderNodeBsdfAnisotropic': {
				const r = anisotropicRoughness(b, f('Roughness'), this.has(node, 'Anisotropy') ? f('Anisotropy') : 0);
				const surface: Surface = { base_metalness: 1, base_color: c('Color'), specular_roughness: r.roughness, specular_roughness_anisotropy: r.anisotropy, geometry_normal: normal('Normal') };
				this.anisotropy(node, ctx, surface, 'Rotation');
				return { surface };
			}
			case 'ShaderNodeBsdfGlass':
			case 'ShaderNodeBsdfRefraction':
				return {
					surface: {
						base_weight: 0,
						transmission_weight: 1,
						transmission_color: c('Color'),
						specular_roughness: f('Roughness'),
						specular_ior: f('IOR', 1.5),
						geometry_normal: normal('Normal'),
					},
				};
			case 'ShaderNodeBsdfTransparent':
				return { surface: { geometry_opacity: b.sub(1, b.extract(c('Color'), 1)) }, transparent: true };
			case 'ShaderNodeMixShader': {
				const shaders = node.inputs.filter((s) => s.type === SOCK_SHADER);
				const fac = b.saturate(f('Fac'));
				return this.mixClosures(this.closure(shaders[0], ctx), this.closure(shaders[1], ctx), fac);
			}
			case 'ShaderNodeAddShader': {
				const shaders = node.inputs.filter((s) => s.type === SOCK_SHADER);
				return this.addClosures(this.closure(shaders[0], ctx), this.closure(shaders[1], ctx));
			}
			default:
				this.warn(`${node.idname} (${node.name}) is not supported (using the default surface)`);
				return { surface: {} };
		}
	}

	private mixClosures(a: Closure | null, c: Closure | null, fac: Arg): Closure {
		const b = this.b;
		const black: Closure = { surface: { base_weight: 0, specular_weight: 0 } };
		const p = a ?? black;
		const q = c ?? black;
		const defaults = (s: Surface, other: Surface, transparent: boolean): Surface => (transparent ? { ...other, geometry_opacity: s.geometry_opacity ?? 1 } : s);
		const sp = defaults(p.surface, q.surface, !!p.transparent);
		const sq = defaults(q.surface, p.surface, !!q.transparent);
		const out: Surface = {};
		for (const name of new Set([...Object.keys(sp), ...Object.keys(sq)])) {
			const x = sp[name] ?? surfaceDefault(this, name);
			const y = sq[name] ?? surfaceDefault(this, name);
			if (name === 'geometry_thin_walled') {
				out[name] = b.max(x, y);
			} else if (name.startsWith('geometry_') && name !== 'geometry_opacity') {
				out[name] = isConnection(x) || isConnection(y) ? b.unary('normalize', b.mix(x, y, fac)) : x;
			} else {
				out[name] = b.mix(x, y, fac);
			}
		}
		return { surface: out, transparent: !!p.transparent && !!q.transparent };
	}

	private addClosures(a: Closure | null, c: Closure | null): Closure {
		if (!a || !c) {
			return a ?? c ?? { surface: {} };
		}
		const b = this.b;
		const emitter = (s: Surface) => isZeroArg(s.base_weight) && isZeroArg(s.specular_weight) && s.emission_color !== undefined && s.transmission_weight === undefined;
		const [main, extra] = emitter(a.surface) ? [c, a] : [a, c];
		const out: Surface = { ...main.surface };
		if (extra.surface.emission_color !== undefined) {
			out.emission_luminance = 1;
			out.emission_color = main.surface.emission_color !== undefined ? b.add(main.surface.emission_color, extra.surface.emission_color) : extra.surface.emission_color;
		}
		if (!emitter(extra.surface)) {
			this.warn('Add Shader of two BSDFs keeps only the first');
		}
		return { surface: out };
	}

	private metallic(node: Node, ctx: Ctx): Surface {
		const b = this.b;
		const f = (name: string, fallback?: number) => this.input(node, name, 'float', ctx, fallback !== undefined ? [fallback] : undefined);
		const c = (name: string) => this.input(node, name, 'color3', ctx);
		const r = anisotropicRoughness(b, f('Roughness', 0.5), f('Anisotropy', 0));
		const surface: Surface = { base_metalness: 1, specular_roughness: r.roughness, specular_roughness_anisotropy: r.anisotropy };
		if (node.s.num('custom2') === 0) {
			// Physical conductor: F0 and the F82 tint from the complex IOR.
			const n = this.input(node, 'IOR', 'vector3', ctx);
			const k = this.input(node, 'Extinction', 'vector3', ctx);
			if (isConnection(n) || isConnection(k)) {
				this.warn('Metallic BSDF with linked IOR / Extinction uses a fixed color');
				surface.base_color = [0.9, 0.9, 0.9];
			} else {
				const nv = n as number[];
				const kv = k as number[];
				const cos82 = Math.cos((82 * Math.PI) / 180);
				const f0 = [0, 1, 2].map((i) => conductorFresnel(nv[i], kv[i], 1));
				const f82 = [0, 1, 2].map((i) => conductorFresnel(nv[i], kv[i], cos82));
				const schlick82 = (x: number) => x + (1 - x) * Math.pow(1 - cos82, 5);
				surface.base_color = f0;
				surface.specular_color = f0.map((x, i) => Math.min(f82[i] / Math.max(schlick82(x), 1e-6), 1));
			}
		} else {
			surface.base_color = c('Base Color');
			surface.specular_color = c('Edge Tint');
		}
		this.thinFilm(node, ctx, surface);
		this.anisotropy(node, ctx, surface, 'Rotation');
		if (this.linked(node, 'Normal')) {
			surface.geometry_normal = b.unary('normalize', this.input(node, 'Normal', 'vector3', ctx));
		}
		return surface;
	}

	private thinFilm(node: Node, ctx: Ctx, surface: Surface): void {
		if (!this.has(node, 'Thin Film Thickness')) {
			return;
		}
		const b = this.b;
		const thickness = this.input(node, 'Thin Film Thickness', 'float', ctx);
		surface.thin_film_weight = b.math('veach_greater', 'float', { in1: thickness, in2: 0 });
		surface.thin_film_thickness = b.mul(thickness, 1e-3);
		surface.thin_film_ior = this.input(node, 'Thin Film IOR', 'float', ctx);
	}

	// Anisotropy tangent: the Tangent input or Cycles' default radial tangent around the object Z axis,
	// rotated by `rotation` turns around the normal.
	private anisotropy(node: Node, ctx: Ctx, surface: Surface, rotationName: string): void {
		const b = this.b;
		const anisotropy = surface.specular_roughness_anisotropy;
		if (anisotropy === undefined || (!isConnection(anisotropy) && (anisotropy as number[])[0] === 0)) {
			return;
		}
		const n = this.normal();
		let t: Arg;
		if (this.linked(node, 'Tangent')) {
			t = this.input(node, 'Tangent', 'vector3', ctx);
		} else {
			const g = this.generated(ctx);
			const radial = b.math('combine3', 'vector3', { in1: b.sub(0.5, b.extract(g, 1)), in2: b.sub(b.extract(g, 0), 0.5), in3: 0 });
			t = b.node('veach_object_to_world', 'vector3', { in: radial });
		}
		t = b.unary('normalize', b.math('crossproduct', 'vector3', { in1: n, in2: b.math('crossproduct', 'vector3', { in1: t, in2: n }) }));
		const rotation = this.input(node, rotationName, 'float', ctx);
		const angle = b.mul(rotation, 2 * Math.PI);
		const bt = b.math('crossproduct', 'vector3', { in1: n, in2: t });
		surface.geometry_tangent = b.add(b.mul(t, b.unary('cos', angle)), b.mul(bt, b.unary('sin', angle)));
	}

	private principled(node: Node, ctx: Ctx): Surface {
		const b = this.b;
		const f = (name: string, fallback: number) => (this.has(node, name) ? this.input(node, name, 'float', ctx) : fallback);
		const c = (name: string, fallback: number[]) => (this.has(node, name) ? this.input(node, name, 'color3', ctx) : fallback);
		const legacy = !this.has(node, 'Specular IOR Level');
		let baseColor = c('Base Color', [0.8, 0.8, 0.8]);
		const r = anisotropicRoughness(b, f('Roughness', 0.5), f(this.has(node, 'Anisotropic') ? 'Anisotropic' : 'Anisotropy', 0));
		// Cycles attenuates the base by the coat tint and albedo only, without OpenPBR's darkening.
		const s: Surface = {
			base_metalness: f('Metallic', 0),
			base_diffuse_roughness: f('Diffuse Roughness', 0),
			specular_roughness: r.roughness,
			specular_ior: f('IOR', 1.5),
			specular_roughness_anisotropy: r.anisotropy,
			geometry_opacity: f('Alpha', 1),
			coat_darkening: 0,
		};
		if (legacy) {
			// What versioning_400.cc turns the pre-4.0 sockets into (the references are rendered that way).
			const subsurface = f('Subsurface', 0);
			if (this.linked(node, 'Subsurface') || !isZeroArg(subsurface)) {
				baseColor = b.mix(baseColor, c('Subsurface Color', [0.8, 0.8, 0.8]), subsurface);
				s.subsurface_weight = 1;
				s.subsurface_radius = subsurface;
			}
			s.subsurface_radius_scale = c('Subsurface Radius', [1, 0.2, 0.1]);
			s.specular_weight = b.mul(f('Specular', 0.5), 2);
			const metallicMix = b.mix(baseColor, [1, 1, 1], s.base_metalness!);
			s.specular_color = b.mix([1, 1, 1], metallicMix, f('Specular Tint', 0));
			s.transmission_weight = f(this.has(node, 'Transmission') ? 'Transmission' : 'Transparency', 0);
			const coatLinked = this.linked(node, 'Clearcoat');
			s.coat_weight = coatLinked ? f('Clearcoat', 0) : b.mul(f('Clearcoat', 0), 0.25);
			s.coat_ior = coatLinked ? 1.2 : 1.5;
			s.coat_roughness = this.has(node, 'Clearcoat Roughness') ? f('Clearcoat Roughness', 0.03) : b.sub(1, f('Clearcoat Gloss', 1));
			if (this.linked(node, 'Clearcoat Normal')) {
				s.geometry_coat_normal = b.unary('normalize', this.input(node, 'Clearcoat Normal', 'vector3', ctx));
			}
			const sheenLinked = this.linked(node, 'Sheen');
			s.fuzz_weight = sheenLinked ? f('Sheen', 0) : b.mul(f('Sheen', 0), 0.2);
			s.fuzz_color = sheenLinked ? [0.2, 0.2, 0.2] : [1, 1, 1];
			if (this.has(node, 'Emission')) {
				s.emission_luminance = 1;
				s.emission_color = b.mul(c('Emission', [0, 0, 0]), f('Emission Strength', 1));
			}
		} else {
			s.specular_weight = b.mul(f('Specular IOR Level', 0.5), 2);
			s.specular_color = c('Specular Tint', [1, 1, 1]);
			s.subsurface_weight = f('Subsurface Weight', 0);
			s.subsurface_radius = f('Subsurface Scale', 0.05);
			s.subsurface_radius_scale = c('Subsurface Radius', [1, 0.2, 0.1]);
			s.subsurface_scatter_anisotropy = f('Subsurface Anisotropy', 0);
			s.transmission_weight = f('Transmission Weight', 0);
			s.coat_weight = f('Coat Weight', 0);
			s.coat_roughness = f('Coat Roughness', 0.03);
			s.coat_ior = f('Coat IOR', 1.5);
			s.coat_color = c('Coat Tint', [1, 1, 1]);
			if (this.linked(node, 'Coat Normal')) {
				s.geometry_coat_normal = b.unary('normalize', this.input(node, 'Coat Normal', 'vector3', ctx));
			}
			s.fuzz_weight = f('Sheen Weight', 0);
			s.fuzz_color = c('Sheen Tint', [1, 1, 1]);
			s.fuzz_roughness = f('Sheen Roughness', 0.5);
			s.emission_luminance = 1;
			s.emission_color = b.mul(c('Emission Color', [1, 1, 1]), f('Emission Strength', 0));
			this.thinFilm(node, ctx, s);
			if (this.has(node, 'Thin Wall')) {
				s.geometry_thin_walled = b.math('veach_greater', 'float', { in1: f('Thin Wall', 0), in2: 0.5 });
			}
		}
		s.base_color = baseColor;
		s.subsurface_color = baseColor;
		// Cycles tints solid transmission by sqrt(base) per interface, so passing in and out gives the
		// base color; OpenPBR's zero-depth tint applies transmission_color per interface. Thin walls
		// (bsdf_thin_glass_setup) take the base color as is.
		const solidTint = b.unary('sqrt', b.saturate(baseColor));
		s.transmission_color = s.geometry_thin_walled === undefined ? solidTint : b.mix(solidTint, baseColor, s.geometry_thin_walled);
		// Veach's media only absorb, so a solid subsurface would render as tinted glass; at the radii
		// these scenes use, Cycles' random walk is much closer to the diffuse base. Thin walls keep it
		// (the BSDF turns it into diffuse reflection and transmission).
		if (s.geometry_thin_walled === undefined && s.subsurface_weight !== undefined && !isZeroArg(s.subsurface_weight)) {
			this.warn('Subsurface scattering is approximated by the diffuse base');
			s.subsurface_weight = 0;
		}
		this.anisotropy(node, ctx, s, 'Anisotropic Rotation');
		if (this.linked(node, 'Normal')) {
			s.geometry_normal = b.unary('normalize', this.input(node, 'Normal', 'vector3', ctx));
		}
		return s;
	}
}

function isZeroArg(a: Arg | undefined): boolean {
	return a !== undefined && !isConnection(a) && (typeof a === 'number' ? a === 0 : Array.isArray(a) && a.every((x) => x === 0));
}

// Values a surface without the input behaves as (open_pbr_surface defaults, the hit's normal).
function surfaceDefault(t: Translator, name: string): Arg {
	switch (name) {
		case 'geometry_normal':
		case 'geometry_coat_normal':
			return t.normal();
		case 'geometry_tangent':
		case 'geometry_coat_tangent':
			return t.b.node('tangent', 'vector3', {});
		default:
			return OPEN_PBR_DEFAULTS[name] ?? 0;
	}
}

const OPEN_PBR_DEFAULTS: Record<string, number[]> = Object.fromEntries(Object.entries(OPEN_PBR_SURFACE).flatMap(([k, d]) => (d.default ? [[k, d.default]] : [])));

export interface BlendMaterial {
	graph: MaterialGraph;
	usesGenerated: boolean;
	warnings: string[];
}

function findOutput(nodes: Node[], idname: string): Node | undefined {
	const outputs = nodes.filter((n) => n.idname === idname && n.s.num('custom1') !== SHD_OUTPUT_EEVEE);
	return outputs.find((n) => n.s.num('flag') & NODE_DO_OUTPUT) ?? outputs[0];
}

function finishSurface(surface: Surface): Record<string, Arg> {
	const out: Record<string, Arg> = {};
	for (const [name, arg] of Object.entries(surface)) {
		if (arg !== undefined) {
			out[name] = arg;
		}
	}
	return out;
}

// A material's node tree (or its viewport color without nodes).
export function translateMaterial(ma: BStruct, texspace: TexSpace): BlendMaterial {
	const name = ma.idName;
	const t = new Translator(`material ${name}`, texspace);
	const b = t.b;
	let surface: Surface;
	const tree = ma.num('use_nodes', 0, 1) ? ma.get('nodetree', 'bNodeTree') : null;
	if (tree) {
		const nodes = readTree(tree);
		const output = findOutput(nodes, 'ShaderNodeOutputMaterial');
		const closure = output ? t.closure(output.inputs.find((s) => s.identifier === 'Surface'), NO_OFFSET) : null;
		surface = closure ? (closure.transparent ? { ...closure.surface, base_weight: 0, specular_weight: 0 } : closure.surface) : { base_weight: 0, specular_weight: 0 };
		if (output?.inputs.find((s) => s.identifier === 'Volume')?.link) {
			t.warn('volume shaders are not supported');
		}
		if (output?.inputs.find((s) => s.identifier === 'Displacement')?.link) {
			t.warn('displacement is not supported');
		}
	} else {
		surface = { base_color: [ma.num('r'), ma.num('g'), ma.num('b')], specular_roughness: ma.num('roughness', 0, 0.4), base_metalness: ma.num('metallic', 0, 0) };
	}
	const inputs = finishSurface(surface);
	const opacity = inputs.geometry_opacity;
	const translucent = opacity !== undefined && !(Array.isArray(opacity) && opacity.every((x) => x >= 1)) && opacity !== 1;
	if (!translucent) {
		delete inputs.geometry_opacity;
	}
	const node = b.node('open_pbr_surface', 'surfaceshader', inputs);
	return {
		graph: { name, nodes: b.nodes, surface: node.node, alphaMode: translucent ? AlphaMode.Blend : AlphaMode.Opaque, alphaCutoff: 0.5, doubleSided: true },
		usesGenerated: t.usesGenerated,
		warnings: [...t.warnings],
	};
}

export interface BlendWorld {
	color: Vec3; // constant background radiance
	sky: BStruct | null; // NodeTexSky feeding the background, if any
	strength: number;
	warnings: string[];
}

// The world background as a constant color (or a Sky Texture times strength).
export function translateWorld(world: BStruct): BlendWorld {
	const warnings: string[] = [];
	const horizon: Vec3 = [world.num('horr'), world.num('horg'), world.num('horb')];
	const tree = world.num('use_nodes', 0, 1) ? world.get('nodetree', 'bNodeTree') : null;
	if (!tree) {
		return { color: horizon, sky: null, strength: 1, warnings };
	}
	const nodes = readTree(tree);
	const output = findOutput(nodes, 'ShaderNodeOutputWorld');
	const from = output?.inputs.find((s) => s.identifier === 'Surface')?.link;
	if (!from || from.node.idname !== 'ShaderNodeBackground') {
		if (from) {
			warnings.push(`world: ${from.node.idname} is not supported`);
		}
		return { color: from ? horizon : [0, 0, 0], sky: null, strength: 1, warnings };
	}
	const bg = from.node;
	const t = new Translator('world', { location: [0, 0, 0], size: [1, 1, 1] });
	const strength = t.input(bg, 'Strength', 'float', NO_OFFSET);
	const colorSocket = bg.inputs.find((s) => s.identifier === 'Color');
	if (colorSocket?.link?.node.idname === 'ShaderNodeTexSky') {
		return { color: [1, 1, 1], sky: storageOf(colorSocket.link.node, 'NodeTexSky'), strength: constantNumber(strength, 1), warnings };
	}
	const color = colorSocket ? t.socket(colorSocket, 'color3', NO_OFFSET) : [0.05, 0.05, 0.05];
	if (isConnection(color) || isConnection(strength)) {
		warnings.push('world: only constant backgrounds are supported');
	}
	const s = constantNumber(strength, 1);
	const cv = isConnection(color) ? horizon : (color as number[]);
	warnings.push(...t.warnings);
	return { color: [cv[0] * s, cv[1] * s, cv[2] * s], sky: null, strength: 1, warnings };
}

function constantNumber(a: Arg, fallback: number): number {
	if (typeof a === 'number') {
		return a;
	}
	return Array.isArray(a) && a.length > 0 && !isConnection(a) ? (a as number[])[0] : fallback;
}
