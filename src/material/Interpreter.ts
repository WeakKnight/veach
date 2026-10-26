// CPU interpreter of material bytecode: the reference for the Slang interpreter, and what the host
// uses to evaluate materials (emissive power estimates).
import { Geometry, NOISE_COLOR, NOISE_NORMALIZE, OPERAND_CONSTANT, OPERAND_NONE, OUTPUT_GROUPS, Op, instructionWords } from './Bytecode';
import type { CompiledMaterial } from './Compile';
import { applyNormalMap, defaultSurfaceValues, sampleTexture, tangentBitangent, transformVector, type ShadingContext, type SurfaceValues } from './Evaluate';
import { TYPE_SIZE } from './Graph';
import { OPEN_PBR_SURFACE } from './NodeDefs';
import { blenderChecker, blenderMagic, blenderNoise } from './Procedural';

type Float4 = [number, number, number, number];

const splat = (x: number): Float4 => [x, x, x, x];
const map = (a: Float4, f: (x: number) => number): Float4 => [f(a[0]), f(a[1]), f(a[2]), f(a[3])];
const map2 = (a: Float4, b: Float4, f: (x: number, y: number) => number): Float4 => [f(a[0], b[0]), f(a[1], b[1]), f(a[2], b[2]), f(a[3], b[3])];
const map3 = (a: Float4, b: Float4, c: Float4, f: (x: number, y: number, z: number) => number): Float4 => [
	f(a[0], b[0], c[0]),
	f(a[1], b[1], c[1]),
	f(a[2], b[2], c[2]),
	f(a[3], b[3], c[3]),
];

function geometry(ctx: ShadingContext, which: Geometry): Float4 {
	switch (which) {
		case Geometry.Texcoord0:
			return [ctx.uv0[0], ctx.uv0[1], 0, 0];
		case Geometry.Texcoord1:
			return [ctx.uv1[0], ctx.uv1[1], 0, 0];
		case Geometry.Position:
			return [...ctx.position, 0];
		case Geometry.Normal:
			return [...ctx.normal, 0];
		case Geometry.Tangent:
			return [...ctx.tangent];
		case Geometry.Bitangent:
			return [...tangentBitangent(ctx), 0];
		case Geometry.ObjectPosition:
			return [...(ctx.objectPosition ?? ctx.position), 0];
		default:
			throw new Error(`material interpreter: unknown geometry ${which}`);
	}
}

// Runs one program, writing the fields it outputs into `out`.
export function runProgram(m: CompiledMaterial, offset: number, ctx: ShadingContext, out: SurfaceValues): void {
	const code = m.code;
	const stack: Float4[] = Array.from({ length: m.stackSize }, () => splat(0));
	const load = (operand: number): Float4 => {
		if (operand >= OPERAND_CONSTANT) {
			const i = (operand - OPERAND_CONSTANT) * 4;
			return [m.constants[i], m.constants[i + 1], m.constants[i + 2], m.constants[i + 3]];
		}
		return [...stack[operand]];
	};
	let pc = offset * 4;
	for (;;) {
		const header = code[pc];
		const op = header & 0xff;
		const dst = (header >>> 8) & 0xff;
		const imm = header >>> 16;
		const operand = (i: number) => code[pc + 1 + i];
		const count = op === Op.Output ? OUTPUT_GROUPS[imm].length : op === Op.Combine ? imm : 3;
		const next = pc + instructionWords(count) * 4;
		const a = () => load(operand(0));
		const b = () => load(operand(1));
		const c = () => load(operand(2));
		let result: Float4 | null = null;
		switch (op as Op) {
			case Op.End:
				return;
			case Op.Add:
				result = map2(a(), b(), (x, y) => x + y);
				break;
			case Op.Sub:
				result = map2(a(), b(), (x, y) => x - y);
				break;
			case Op.Mul:
				result = map2(a(), b(), (x, y) => x * y);
				break;
			case Op.Div:
				result = map2(a(), b(), (x, y) => x / y);
				break;
			case Op.Min:
				result = map2(a(), b(), Math.min);
				break;
			case Op.Max:
				result = map2(a(), b(), Math.max);
				break;
			case Op.Pow:
				result = map2(a(), b(), Math.pow);
				break;
			case Op.Atan2:
				result = map2(a(), b(), Math.atan2);
				break;
			case Op.Sqrt:
				result = map(a(), Math.sqrt);
				break;
			case Op.Sin:
				result = map(a(), Math.sin);
				break;
			case Op.Cos:
				result = map(a(), Math.cos);
				break;
			case Op.Abs:
				result = map(a(), Math.abs);
				break;
			case Op.Clamp:
				result = map3(a(), b(), c(), (x, lo, hi) => Math.min(Math.max(x, lo), hi));
				break;
			case Op.Mix:
				result = map3(a(), b(), c(), (bg, fg, t) => bg + (fg - bg) * t);
				break;
			case Op.Extract:
				result = splat(a()[imm]);
				break;
			case Op.Widen: {
				const size = imm & 0xff;
				const pad = imm >>> 8;
				result = a().map((x, i) => (i < size ? x : pad)) as Float4;
				break;
			}
			case Op.Combine:
				result = splat(0);
				for (let i = 0; i < imm; i++) {
					result[i] = load(operand(i))[0];
				}
				break;
			case Op.Dot: {
				const x = a();
				const y = b();
				let s = 0;
				for (let i = 0; i < imm; i++) {
					s += x[i] * y[i];
				}
				result = splat(s);
				break;
			}
			case Op.Normalize: {
				const x = a();
				const len = Math.hypot(...x.slice(0, imm));
				result = len > 0 ? map(x, (v) => v / len) : splat(0);
				break;
			}
			case Op.Geometry:
				result = geometry(ctx, imm);
				break;
			case Op.Texture:
				result = sampleTexture(ctx, m.textures[imm]) as Float4;
				break;
			case Op.NormalMap: {
				const n = applyNormalMap(ctx.tangent, ctx.normal, a(), b()[0]);
				result = [...n, 0];
				break;
			}
			case Op.Floor:
				result = map(a(), Math.floor);
				break;
			case Op.Sign:
				result = map(a(), Math.sign);
				break;
			case Op.Exp:
				result = map(a(), Math.exp);
				break;
			case Op.Log:
				result = map(a(), Math.log);
				break;
			case Op.Modulo:
				result = map2(a(), b(), (x, y) => x - y * Math.floor(x / y));
				break;
			case Op.Greater:
				result = map2(a(), b(), (x, y) => (x > y ? 1 : 0));
				break;
			case Op.Cross: {
				const x = a();
				const y = b();
				result = [x[1] * y[2] - x[2] * y[1], x[2] * y[0] - x[0] * y[2], x[0] * y[1] - x[1] * y[0], 0];
				break;
			}
			case Op.Transform:
				result = [...transformVector(ctx, a(), imm === 1), 0];
				break;
			case Op.Noise: {
				const v = blenderNoise(a(), b(), (imm & NOISE_NORMALIZE) !== 0, (imm & NOISE_COLOR) !== 0);
				result = (imm & NOISE_COLOR) !== 0 ? [...v, 0] : splat(v[0]);
				break;
			}
			case Op.Magic: {
				const c = blenderMagic(a(), imm, b()[0]);
				result = [...c, (c[0] + c[1] + c[2]) / 3];
				break;
			}
			case Op.Checker:
				result = splat(blenderChecker(a()));
				break;
			case Op.Output:
				OUTPUT_GROUPS[imm].forEach((field, i) => {
					const o = operand(i);
					if (o !== OPERAND_NONE) {
						out[field] = load(o).slice(0, TYPE_SIZE[OPEN_PBR_SURFACE[field].type]);
					}
				});
				break;
			default:
				throw new Error(`material interpreter: unknown opcode ${op}`);
		}
		if (result) {
			stack[dst] = result;
		}
		pc = next;
	}
}

// The opcodes of a program, in order.
export function programOps(m: CompiledMaterial, offset: number): Op[] {
	const ops: Op[] = [];
	for (let pc = offset * 4; ; ) {
		const op = (m.code[pc] & 0xff) as Op;
		ops.push(op);
		if (op === Op.End) {
			return ops;
		}
		const imm = m.code[pc] >>> 16;
		pc += instructionWords(op === Op.Output ? OUTPUT_GROUPS[imm].length : op === Op.Combine ? imm : 3) * 4;
	}
}

// True when a program reads neither textures nor the hit, i.e. its outputs are constant.
export function isConstantProgram(m: CompiledMaterial, offset: number): boolean {
	return programOps(m, offset).every((op) => op !== Op.Texture && op !== Op.Geometry && op !== Op.NormalMap && op !== Op.Transform);
}

// Every OpenPBR input, as evaluateSurface returns them: all three programs over the defaults.
export function evaluateCompiled(m: CompiledMaterial, ctx: ShadingContext): SurfaceValues {
	const out = defaultSurfaceValues(ctx);
	for (const offset of [m.surface, m.opacity, m.emission]) {
		if (offset >= 0) {
			runProgram(m, offset, ctx, out);
		}
	}
	return out;
}
