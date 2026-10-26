// CPU evaluation of lowered material graphs at a surface point. Mirrors the shader:
// Materials/Textures.slang (SampleTexture) and Materials/MaterialSample.slang (ApplyNormalMap).
import type { Vec3 } from '../math/Math';
import { WrapMode } from '../scene/Scene';
import { isConnection, type ColorSpace, type MaterialGraph } from './Graph';
import { lowerGraph } from './Lower';
import { OPEN_PBR_SURFACE } from './NodeDefs';
import { evalMath, isMathCategory } from './Ops';
import { optimizeGraph } from './Optimize';

export interface ShadingContext {
	uv0: [number, number];
	uv1: [number, number];
	position: Vec3; // world space
	objectPosition?: Vec3; // defaults to position
	objectToWorld?: readonly number[]; // 3x4 row-major, for directions; identity if absent
	worldToObject?: readonly number[];
	normal: Vec3; // interpolated world normal, not flipped
	tangent: [number, number, number, number]; // world xyz, w = handedness (0 = no tangent)
	// Raw texel of a texture source (as stored, before colorspace decoding) at wrapped uvs.
	sample(source: number, uv: [number, number]): number[];
}

// OpenPBR inputs by name; booleans are 0 / 1.
export type SurfaceValues = Record<string, number[]>;

export interface TextureSampling {
	source: number;
	colorspace: ColorSpace;
	uvindex: number;
	offset: readonly number[];
	scale: readonly number[];
	rotation: number; // radians
	wrapS: WrapMode;
	wrapT: WrapMode;
}

export function srgbToLinear(c: number): number {
	return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function wrapCoord(x: number, mode: WrapMode): number {
	if (mode === WrapMode.Clamp) {
		return Math.min(Math.max(x, 0), 1);
	}
	if (mode === WrapMode.Mirror) {
		const t = x - 2 * Math.floor(x * 0.5);
		return t > 1 ? 2 - t : t;
	}
	return x - Math.floor(x);
}

// KHR_texture_transform (T * R * S), wrapping and colorspace decoding.
export function sampleTexture(ctx: ShadingContext, t: TextureSampling): number[] {
	const uv = t.uvindex === 1 ? ctx.uv1 : ctx.uv0;
	const sx = t.scale[0] * uv[0];
	const sy = t.scale[1] * uv[1];
	const c = Math.cos(t.rotation);
	const s = Math.sin(t.rotation);
	const u = wrapCoord(c * sx + s * sy + t.offset[0], t.wrapS);
	const v = wrapCoord(-s * sx + c * sy + t.offset[1], t.wrapT);
	const texel = ctx.sample(t.source, [u, v]);
	const out = [texel[0] ?? 0, texel[1] ?? 0, texel[2] ?? 0, texel[3] ?? 1];
	if (t.colorspace === 'srgb_texture') {
		for (let i = 0; i < 3; i++) {
			out[i] = srgbToLinear(out[i]);
		}
	}
	return out;
}

const dot = (a: readonly number[], b: readonly number[]) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a: readonly number[], b: readonly number[]): Vec3 => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const normalize = (a: readonly number[]): Vec3 => {
	const l = Math.hypot(a[0], a[1], a[2]);
	return [a[0] / l, a[1] / l, a[2] / l];
};

// Tangent orthogonalized against n and the bitangent, or null without a usable tangent.
function tangentFrame(tangent: readonly number[], n: readonly number[]): { t: Vec3; b: Vec3 } | null {
	if (tangent[3] === 0 || dot(tangent, tangent) === 0) {
		return null;
	}
	const d = dot(tangent, n);
	const t = normalize([tangent[0] - n[0] * d, tangent[1] - n[1] * d, tangent[2] - n[2] * d]);
	const c = cross(n, t);
	return { t, b: [c[0] * tangent[3], c[1] * tangent[3], c[2] * tangent[3]] };
}

export function applyNormalMap(tangent: readonly number[], n: Vec3, texel: readonly number[], scale: number): Vec3 {
	const frame = tangentFrame(tangent, n);
	if (!frame) {
		return n;
	}
	const x = (texel[0] * 2 - 1) * scale;
	const y = (texel[1] * 2 - 1) * scale;
	const z = texel[2] <= 0 ? Math.sqrt(Math.min(Math.max(1 - x * x - y * y, 0), 1)) : Math.abs(texel[2] * 2 - 1);
	if (x === 0 && y === 0 && z === 0) {
		return n;
	}
	const l = normalize([x, y, z]);
	return normalize([0, 1, 2].map((i) => frame.t[i] * l[0] + frame.b[i] * l[1] + n[i] * l[2]));
}

// Every OpenPBR input of a lowered graph; unset inputs take their defaults or the hit's geometry.
export function evaluateSurface(graph: MaterialGraph, ctx: ShadingContext): SurfaceValues {
	const values: number[][] = [];
	const surfaceNode = graph.nodes[graph.surface];
	if (surfaceNode?.category !== 'open_pbr_surface') {
		throw new Error('material graph: evaluate expects a lowered graph');
	}
	graph.nodes.forEach((node, index) => {
		if (index === graph.surface || node.type === 'surfaceshader') {
			values.push([]);
			return;
		}
		const i: Record<string, number[]> = {};
		let file: { source: number; colorspace: ColorSpace } | undefined;
		for (const [name, input] of Object.entries(node.inputs)) {
			if ('file' in input) {
				file = input.file;
			} else {
				i[name] = isConnection(input) ? values[input.node] : input.value;
			}
		}
		if (isMathCategory(node.category)) {
			values.push(evalMath(node.category, node.type, i));
			return;
		}
		switch (node.category) {
			case 'texcoord':
				values.push((i.index?.[0] ?? 0) === 1 ? [...ctx.uv1] : [...ctx.uv0]);
				break;
			case 'position':
				values.push((i.space?.[0] ?? 0) === 1 ? [...(ctx.objectPosition ?? ctx.position)] : [...ctx.position]);
				break;
			case 'veach_world_to_object':
			case 'veach_object_to_world':
				values.push(transformVector(ctx, i.in ?? [0, 0, 0], node.category === 'veach_object_to_world'));
				break;
			case 'normal':
				values.push([...ctx.normal]);
				break;
			case 'tangent':
				values.push(ctx.tangent.slice(0, 3));
				break;
			case 'bitangent':
				values.push(tangentBitangent(ctx));
				break;
			case 'veach_texture':
				if (!file) {
					throw new Error('material graph: veach_texture without a file');
				}
				values.push(
					sampleTexture(ctx, {
						...file,
						uvindex: i.uvindex?.[0] ?? 0,
						offset: i.offset ?? [0, 0],
						scale: i.scale ?? [1, 1],
						rotation: i.rotation?.[0] ?? 0,
						wrapS: (i.uaddressmode?.[0] ?? 0) as WrapMode,
						wrapT: (i.vaddressmode?.[0] ?? 0) as WrapMode,
					}),
				);
				break;
			case 'normalmap':
				values.push(applyNormalMap(ctx.tangent, ctx.normal, i.in ?? [0.5, 0.5, 1], i.scale?.[0] ?? 1));
				break;
			default:
				throw new Error(`material graph: cannot evaluate ${node.category}`);
		}
	});

	const out = defaultSurfaceValues(ctx);
	for (const [name, input] of Object.entries(surfaceNode.inputs)) {
		if ('file' in input) {
			throw new Error(`material graph: open_pbr_surface.${name} is a file`);
		}
		out[name] = [...(isConnection(input) ? values[input.node] : input.value)];
	}
	return out;
}

// open_pbr_surface defaults, with the geometric inputs taken from the hit.
export function defaultSurfaceValues(ctx: ShadingContext): SurfaceValues {
	const out: SurfaceValues = {};
	for (const [name, def] of Object.entries(OPEN_PBR_SURFACE)) {
		if (def.default) {
			out[name] = [...def.default];
		}
	}
	out.geometry_normal = [...ctx.normal];
	out.geometry_coat_normal = [...ctx.normal];
	out.geometry_tangent = ctx.tangent.slice(0, 3);
	out.geometry_coat_tangent = ctx.tangent.slice(0, 3);
	return out;
}

// A direction between world and object space.
export function transformVector(ctx: ShadingContext, v: readonly number[], toWorld: boolean): Vec3 {
	const m = toWorld ? ctx.objectToWorld : ctx.worldToObject;
	if (!m) {
		return [v[0], v[1], v[2]];
	}
	return [0, 1, 2].map((r) => m[r * 4] * v[0] + m[r * 4 + 1] * v[1] + m[r * 4 + 2] * v[2]) as Vec3;
}

export function tangentBitangent(ctx: ShadingContext): Vec3 {
	return tangentFrame(ctx.tangent, ctx.normal)?.b ?? [0, 0, 0];
}

// Lowers, optimizes and evaluates any material graph.
export function evaluateMaterial(graph: MaterialGraph, ctx: ShadingContext): SurfaceValues {
	return evaluateSurface(optimizeGraph(lowerGraph(graph)), ctx);
}
