import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { parseGLTF } from '../src/loaders/GLTFLoader';
import { Op } from '../src/material/Bytecode';
import { compileMaterial, type CompiledMaterial } from '../src/material/Compile';
import { applyNormalMap, evaluateMaterial, evaluateSurface, sampleTexture, type ShadingContext, type SurfaceValues } from '../src/material/Evaluate';
import { defaultMaterialGraph } from '../src/material/GLTFMaterial';
import { GraphBuilder, type Arg, type MaterialGraph } from '../src/material/Graph';
import { evaluateCompiled, programOps } from '../src/material/Interpreter';
import { lowerGraph } from '../src/material/Lower';
import { optimizeGraph } from '../src/material/Optimize';
import type { Vec3 } from '../src/math/Math';
import { AlphaMode, type MaterialDesc, type TextureBinding } from '../src/scene/Scene';

const samples = join(__dirname, '..', 'public', 'samples');
const hasSamples = existsSync(join(samples, 'DamagedHelmet.glb'));
const SAMPLE_FILES = ['DamagedHelmet.glb', 'MetalRoughSpheres.glb', 'AlphaBlendModeTest.glb', 'EmissiveStrengthTest.glb', 'TransmissionTest.glb', 'ClearCoatTest.glb'];
// Materials the pre-graph mapping could not represent: compared against the graph evaluator only.
const GRAPH_ONLY_FILES = ['SpecGlossVsMetalRough.glb', 'AnisotropyBarnLamp.glb', 'SheenChair.glb', 'IridescentDishWithOlives.glb'].filter((f) => existsSync(join(samples, f)));
const read = (name: string) => {
	const b = readFileSync(join(samples, name));
	return b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength) as ArrayBuffer;
};

function gltfJson(json: object): ArrayBuffer {
	return new TextEncoder().encode(JSON.stringify({ asset: { version: '2.0' }, ...json })).buffer as ArrayBuffer;
}

function rng(seed: number): () => number {
	let s = seed >>> 0;
	return () => {
		s = (s + 0x6d2b79f5) >>> 0;
		let t = s;
		t = Math.imul(t ^ (t >>> 15), t | 1);
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

const normalize = (v: number[]): Vec3 => {
	const l = Math.hypot(v[0], v[1], v[2]);
	return [v[0] / l, v[1] / l, v[2] / l];
};

function randomContext(random: () => number): ShadingContext {
	const n = normalize([random() - 0.5, random() - 0.5, random() - 0.5]);
	const a = normalize([random() - 0.5, random() - 0.5, random() - 0.5]);
	const d = a[0] * n[0] + a[1] * n[1] + a[2] * n[2];
	const t = normalize([a[0] - n[0] * d, a[1] - n[1] * d, a[2] - n[2] * d]);
	const fract = (x: number) => x - Math.floor(x);
	// object frame: a scaled rotation (rows t, b, n) and its inverse
	const b = [n[1] * t[2] - n[2] * t[1], n[2] * t[0] - n[0] * t[2], n[0] * t[1] - n[1] * t[0]];
	const s = 0.5 + random() * 2;
	const rows = [t, b, n];
	return {
		uv0: [random() * 5 - 2, random() * 5 - 2],
		uv1: [random() * 5 - 2, random() * 5 - 2],
		position: [random(), random(), random()],
		objectPosition: [random() * 4 - 2, random() * 4 - 2, random() * 4 - 2],
		objectToWorld: [0, 1, 2].flatMap((r) => [rows[0][r] * s, rows[1][r] * s, rows[2][r] * s, 0]),
		worldToObject: rows.flatMap((row) => [...row.map((v) => v / s), 0]),
		normal: n,
		tangent: [...t, random() < 0.5 ? -1 : 1],
		sample: (source, [u, v]) => [0, 1, 2, 3].map((c) => fract(Math.sin(source * 12.9898 + u * 78.233 + v * 37.719 + c * 4.581) * 43758.5453)),
	};
}

const saturate = (x: number) => Math.min(Math.max(x, 0), 1);

// TypeScript port of EvalMaterial / EvalOpacity in shaders/Materials (the mapping the GPU applies today).
function referenceInputs(m: MaterialDesc, ctx: ShadingContext): SurfaceValues {
	const tex = (b: TextureBinding | undefined, srgb: boolean) =>
		b
			? sampleTexture(ctx, { source: b.source, colorspace: srgb ? 'srgb_texture' : 'lin_rec709', uvindex: b.texCoord, offset: b.offset, scale: b.scale, rotation: b.rotation, wrapS: b.wrapS, wrapT: b.wrapT })
			: null;
	const t = m.textures;
	const out: SurfaceValues = {};
	const baseTex = tex(t.baseColor, true);
	const baseColor = [0, 1, 2].map((i) => m.baseColor[i] * (baseTex ? baseTex[i] : 1));
	out.base_color = baseColor;
	let metallic = m.metallic;
	let roughness = m.roughness;
	const mr = tex(t.metallicRoughness, false);
	if (mr) {
		roughness *= mr[1];
		metallic *= mr[2];
	}
	out.base_metalness = [saturate(metallic)];
	out.specular_roughness = [saturate(roughness)];
	out.specular_ior = [m.ior];
	out.specular_weight = [m.specularWeight];
	out.specular_color = [...m.specularColor];
	out.specular_roughness_anisotropy = [saturate(Math.abs(m.anisotropy))];

	let transmission = m.transmission;
	const tt = tex(t.transmission, false);
	if (tt) {
		transmission *= tt[0];
	}
	out.transmission_weight = [saturate(transmission)];
	out.geometry_thin_walled = [m.thinWalled ? 1 : 0];
	if (!m.thinWalled && Number.isFinite(m.attenuationDistance) && m.attenuationDistance > 0) {
		out.transmission_color = [...m.attenuationColor];
		out.transmission_depth = [m.attenuationDistance];
	} else {
		out.transmission_color = baseColor;
		out.transmission_depth = [0];
	}
	out.transmission_dispersion_scale = [m.dispersion > 0 ? 1 : 0];
	out.transmission_dispersion_abbe_number = [m.dispersion > 0 ? 20 / m.dispersion : 20];

	let clearcoat = m.clearcoat;
	let clearcoatRoughness = m.clearcoatRoughness;
	if (clearcoat > 0) {
		clearcoat *= tex(t.clearcoat, false)?.[0] ?? 1;
		clearcoatRoughness *= tex(t.clearcoatRoughness, false)?.[1] ?? 1;
	}
	out.coat_weight = [saturate(clearcoat)];
	out.coat_roughness = [saturate(clearcoatRoughness)];
	out.coat_ior = [1.5];

	const sheen = m.sheenColor.some((c) => c > 0);
	out.fuzz_weight = [sheen ? 1 : 0];
	out.fuzz_color = sheen ? [...m.sheenColor] : [1, 1, 1];
	out.fuzz_roughness = sheen ? [saturate(m.sheenRoughness)] : [0.5];

	out.thin_film_weight = [saturate(m.iridescence)];
	out.thin_film_thickness = [m.iridescenceThickness * 1e-3];
	out.thin_film_ior = [m.iridescenceIor];

	let emission = [...m.emission];
	const et = emission.some((c) => c > 0) ? tex(t.emissive, true) : null;
	if (et) {
		emission = emission.map((c, i) => c * et[i]);
	}
	out.emission_luminance = [1];
	out.emission_color = emission;

	out.geometry_opacity = [m.alphaMode === AlphaMode.Opaque ? 1 : m.baseColor[3] * (baseTex ? baseTex[3] : 1)];

	let n: Vec3 = [...ctx.normal];
	const nt = tex(t.normal, false);
	if (nt) {
		n = applyNormalMap(ctx.tangent, n, nt, m.normalScale);
	}
	out.geometry_normal = n;
	out.geometry_coat_normal = n;
	return out;
}

// Inputs that only matter when another one is non-zero.
const DEPENDS_ON: Record<string, string> = {
	specular_color: 'specular_weight',
	specular_roughness: 'specular_weight',
	specular_ior: 'specular_weight',
	transmission_color: 'transmission_weight',
	transmission_depth: 'transmission_weight',
	transmission_dispersion_scale: 'transmission_weight',
	transmission_dispersion_abbe_number: 'transmission_weight',
	coat_roughness: 'coat_weight',
	coat_ior: 'coat_weight',
	geometry_coat_normal: 'coat_weight',
	fuzz_color: 'fuzz_weight',
	fuzz_roughness: 'fuzz_weight',
	thin_film_thickness: 'thin_film_weight',
	thin_film_ior: 'thin_film_weight',
};

// Emitted radiance instead of its two factors (pruning resets an unused color to its default).
function withEmission(v: SurfaceValues): SurfaceValues {
	const { emission_luminance, emission_color, ...rest } = v;
	return { ...rest, emission: emission_color.map((c) => c * emission_luminance[0]) };
}

function expectMatchesReference(m: MaterialDesc, ctx: ShadingContext, skip: string[] = []): void {
	const expected = withEmission(referenceInputs(m, ctx));
	const actual = withEmission(evaluateMaterial(m.graph, ctx));
	const active = (name: string) => expected[name].some((v) => v !== 0);
	for (const [name, value] of Object.entries(expected)) {
		const gate = DEPENDS_ON[name];
		if (skip.includes(name) || (gate && !active(gate))) {
			continue;
		}
		expect(actual[name], `${m.name}.${name}`).toHaveLength(value.length);
		value.forEach((v, i) => expect(actual[name][i], `${m.name}.${name}[${i}]`).toBeCloseTo(v, 5));
	}
	if (m.anisotropy > 0) {
		// the old mapping rotates in the shading frame; the graph rotates the tangent
		const g = actual.geometry_tangent;
		const t = ctx.tangent;
		const n = actual.geometry_normal;
		const b = [n[1] * t[2] - n[2] * t[1], n[2] * t[0] - n[0] * t[2], n[0] * t[1] - n[1] * t[0]].map((c) => c * t[3]);
		const angle = Math.atan2(g[0] * b[0] + g[1] * b[1] + g[2] * b[2], g[0] * t[0] + g[1] * t[1] + g[2] * t[2]);
		expect(angle).toBeCloseTo(m.anisotropyRotation, 5);
	}
}

const texture = (index: number, extra: object = {}) => ({ index, ...extra });

const SYNTHETIC = {
	images: [0, 1, 2, 3, 4, 5].map((i) => ({ uri: `image${i}.png` })),
	samplers: [{ wrapS: 33071, wrapT: 33648 }, {}],
	textures: [0, 1, 2, 3, 4, 5].map((i) => ({ source: i, sampler: i % 2 })),
	materials: [
		{
			name: 'textured',
			pbrMetallicRoughness: {
				baseColorFactor: [0.9, 0.7, 0.5, 0.8],
				baseColorTexture: texture(0, { extensions: { KHR_texture_transform: { offset: [0.2, -0.1], scale: [2, 3], rotation: 0.4, texCoord: 1 } } }),
				metallicFactor: 0.6,
				roughnessFactor: 0.9,
				metallicRoughnessTexture: texture(1),
			},
			normalTexture: texture(2, { scale: 0.7 }),
			emissiveTexture: texture(3, { texCoord: 1 }),
			emissiveFactor: [1, 0.5, 0.25],
			alphaMode: 'MASK',
			alphaCutoff: 0.3,
			extensions: { KHR_materials_emissive_strength: { emissiveStrength: 3 } },
		},
		{
			name: 'volume',
			pbrMetallicRoughness: { baseColorFactor: [0.2, 0.9, 0.4, 1], metallicFactor: 0, roughnessFactor: 0.1 },
			extensions: {
				KHR_materials_transmission: { transmissionFactor: 0.9, transmissionTexture: texture(4) },
				KHR_materials_volume: { thicknessFactor: 1, attenuationDistance: 2, attenuationColor: [0.9, 0.5, 0.3] },
				KHR_materials_ior: { ior: 1.33 },
				KHR_materials_dispersion: { dispersion: 0.5 },
			},
		},
		{
			name: 'thin transmission',
			pbrMetallicRoughness: { baseColorTexture: texture(0), metallicFactor: 0 },
			extensions: { KHR_materials_transmission: { transmissionFactor: 1 } },
		},
		{
			name: 'coated',
			pbrMetallicRoughness: { baseColorFactor: [0.5, 0.1, 0.1, 1], metallicFactor: 0.2, roughnessFactor: 0.4 },
			extensions: {
				KHR_materials_clearcoat: { clearcoatFactor: 0.8, clearcoatTexture: texture(4), clearcoatRoughnessFactor: 0.3, clearcoatRoughnessTexture: texture(5) },
				KHR_materials_sheen: { sheenColorFactor: [0.5, 0.4, 0.3], sheenRoughnessFactor: 0.3 },
				KHR_materials_specular: { specularFactor: 0.6, specularColorFactor: [0.9, 0.5, 0.2] },
			},
		},
		{
			name: 'anisotropic',
			pbrMetallicRoughness: { metallicFactor: 1, roughnessFactor: 0.5 },
			extensions: {
				KHR_materials_anisotropy: { anisotropyStrength: 0.6, anisotropyRotation: 0.8 },
				KHR_materials_iridescence: { iridescenceFactor: 1, iridescenceIor: 1.8, iridescenceThicknessMaximum: 500 },
			},
		},
		{
			name: 'unlit',
			pbrMetallicRoughness: { baseColorFactor: [0.5, 0.6, 0.7, 0.5], baseColorTexture: texture(3) },
			alphaMode: 'BLEND',
			extensions: { KHR_materials_unlit: {} },
		},
		{ name: 'empty' },
	],
};

const SPECULAR_GLOSSINESS = {
	extensionsUsed: ['KHR_materials_pbrSpecularGlossiness'],
	images: [{ uri: 'a.png' }, { uri: 'b.png' }],
	textures: [{ source: 0 }, { source: 1 }],
	materials: [
		{
			name: 'sg',
			extensions: {
				KHR_materials_pbrSpecularGlossiness: {
					diffuseFactor: [0.8, 0.6, 0.4, 0.9],
					diffuseTexture: texture(0),
					specularFactor: [0.9, 0.6, 0.3],
					glossinessFactor: 0.8,
					specularGlossinessTexture: texture(1),
				},
			},
			alphaMode: 'BLEND',
		},
	],
};

describe('material graphs', () => {
	it('lowers glTF materials to the inputs MaterialSample produces', async () => {
		const scene = await parseGLTF(gltfJson(SYNTHETIC), { decodeImages: false });
		const random = rng(1);
		for (const m of scene.materials) {
			for (let i = 0; i < 64; i++) {
				expectMatchesReference(m, randomContext(random));
			}
		}
	});

	it('samples each texture once and folds untextured materials to constants', async () => {
		const scene = await parseGLTF(gltfJson(SYNTHETIC), { decodeImages: false });
		const optimized = (name: string) => optimizeGraph(lowerGraph(scene.materials.find((m) => m.name === name)!.graph));
		const textured = optimized('textured');
		expect(textured.nodes.filter((n) => n.category === 'veach_texture')).toHaveLength(4);
		const empty = optimized('empty');
		expect(empty.nodes).toHaveLength(1);
		expect(Object.keys(empty.nodes[0].inputs).sort()).toEqual(['base_color', 'base_metalness', 'geometry_thin_walled', 'specular_roughness']);
		const fallback = optimizeGraph(lowerGraph(defaultMaterialGraph()));
		expect(fallback.nodes).toHaveLength(1);
	});

	it('maps specular-glossiness so that F0 equals the specular color', async () => {
		const scene = await parseGLTF(gltfJson(SPECULAR_GLOSSINESS), { decodeImages: false });
		const graph = scene.materials[0].graph;
		const optimized = optimizeGraph(lowerGraph(graph));
		expect(optimized.nodes.filter((n) => n.category === 'veach_texture')).toHaveLength(2);
		const random = rng(2);
		for (let i = 0; i < 32; i++) {
			const ctx = randomContext(random);
			const v = evaluateSurface(optimized, ctx);
			const diffuse = sampleTexture(ctx, { source: 0, colorspace: 'srgb_texture', uvindex: 0, offset: [0, 0], scale: [1, 1], rotation: 0, wrapS: 0, wrapT: 0 });
			const sg = sampleTexture(ctx, { source: 1, colorspace: 'srgb_texture', uvindex: 0, offset: [0, 0], scale: [1, 1], rotation: 0, wrapS: 0, wrapT: 0 });
			[0.8, 0.6, 0.4].forEach((f, c) => expect(v.base_color[c]).toBeCloseTo(f * diffuse[c], 6));
			[0.9, 0.6, 0.3].forEach((f, c) => expect(v.specular_weight[0] * 0.04 * v.specular_color[c]).toBeCloseTo(f * sg[c], 6));
			expect(v.specular_ior[0]).toBe(1.5);
			expect(v.base_metalness[0]).toBe(0);
			expect(v.specular_roughness[0]).toBeCloseTo(1 - 0.8 * sg[3], 6);
			expect(v.geometry_opacity[0]).toBeCloseTo(0.9 * diffuse[3], 6);
		}
	});

	it.runIf(GRAPH_ONLY_FILES.includes('SpecGlossVsMetalRough.glb'))('loads the specular-glossiness sample', async () => {
		const json = JSON.parse(new TextDecoder().decode(new Uint8Array(read('SpecGlossVsMetalRough.glb'), 20, new DataView(read('SpecGlossVsMetalRough.glb')).getUint32(12, true))));
		const scene = await parseGLTF(read('SpecGlossVsMetalRough.glb'), { decodeImages: false });
		const specGloss = json.materials.filter((m: { extensions?: object }) => m.extensions && 'KHR_materials_pbrSpecularGlossiness' in m.extensions).length;
		expect(specGloss).toBeGreaterThan(0);
		const surfaces = scene.materials.map((m) => m.graph.nodes[m.graph.surface].category);
		expect(surfaces.filter((c) => c === 'veach_gltf_specular_glossiness')).toHaveLength(specGloss);
		for (const m of scene.materials) {
			const compiled = compileMaterial(m.graph);
			expect(compiled.surface).toBeGreaterThanOrEqual(0);
			if (m.graph.nodes[m.graph.surface].category === 'veach_gltf_specular_glossiness') {
				expect(compiled.textures.every((t) => t.colorspace === 'srgb_texture' || t.colorspace === 'lin_rec709')).toBe(true);
				expect(compiled.textures.some((t) => t.colorspace === 'srgb_texture')).toBe(true);
			}
		}
	});

	it.runIf(hasSamples)('matches MaterialSample on the sample assets', async () => {
		const random = rng(3);
		for (const file of SAMPLE_FILES) {
			const scene = await parseGLTF(read(file), { decodeImages: false });
			for (const m of scene.materials) {
				for (let i = 0; i < 8; i++) {
					// clearcoat normal textures are new with the graph
					expectMatchesReference(m, randomContext(random), ['geometry_coat_normal']);
				}
			}
		}
	});
});

function expectCompiledMatchesGraph(graph: MaterialGraph, compiled: CompiledMaterial, ctx: ShadingContext): void {
	const expected = evaluateMaterial(graph, ctx);
	const actual = evaluateCompiled(compiled, ctx);
	for (const [name, value] of Object.entries(expected)) {
		expect(actual[name], `${graph.name}.${name}`).toHaveLength(value.length);
		// constants are float32 in the bytecode
		value.forEach((v, i) => expect(actual[name][i], `${graph.name}.${name}[${i}]`).toBeCloseTo(v, Math.abs(v) > 10 ? 3 : 5));
	}
}

const instructions = programOps;

// Uses every opcode, on values that are not constant.
function coverageGraph(): MaterialGraph {
	const b = new GraphBuilder();
	const uv = b.node('texcoord', 'vector2', { index: 1 });
	const x = b.extract(uv, 0);
	const y = b.extract(uv, 1);
	const p = b.node('position', 'vector3', {});
	const t = b.node('tangent', 'vector3', {});
	const bt = b.node('bitangent', 'vector3', {});
	const n = b.node('normal', 'vector3', {});
	const texel = b.node('veach_texture', 'color4', {
		file: { source: 2, colorspace: 'srgb_texture' },
		uvindex: 1,
		offset: [0.1, 0.2],
		scale: [2, 0.5],
		rotation: 0.3,
		uaddressmode: 1,
		vaddressmode: 2,
	});
	const c3 = b.node('combine3', 'color3', { in1: x, in2: y, in3: b.math('absval', 'float', { in: b.unary('sin', x) }) });
	const four = b.node('combine4', 'vector4', { in1: x, in2: y, in3: b.extract(texel, 3), in4: b.unary('cos', y) });
	const direction = b.unary('normalize', b.add(p, b.mul(n, 0.5)));
	const angle: Arg = b.math('absval', 'float', { in: b.atan2(y, x) });
	return {
		name: 'coverage',
		nodes: b.nodes,
		surface: b.node('open_pbr_surface', 'surfaceshader', {
			base_color: b.saturate(b.mix(c3, b.convert(texel, 'color3'), b.unary('cos', y))),
			base_metalness: b.saturate(b.math('dotproduct', 'float', { in1: direction, in2: t })),
			specular_roughness: b.math('min', 'float', { in1: b.math('power', 'float', { in1: b.div(angle, Math.PI), in2: 2 }), in2: 1 }),
			specular_weight: b.unary('sqrt', b.math('dotproduct', 'float', { in1: four, in2: four })),
			coat_weight: b.saturate(b.math('dotproduct', 'float', { in1: bt, in2: direction })),
			coat_color: b.convert(b.convert(c3, 'color4'), 'color3'),
			thin_film_weight: 1,
			thin_film_thickness: b.extract(b.convert(c3, 'color4'), 3),
			emission_luminance: b.sub(b.max(x, y), b.extract(b.node('convert', 'vector3', { in: uv }), 2)),
			geometry_normal: b.node('normalmap', 'vector3', { in: b.convert(texel, 'vector3'), scale: b.saturate(x) }),
			geometry_opacity: b.saturate(y),
		}).node,
		alphaMode: AlphaMode.Blend,
		alphaCutoff: 0.5,
		doubleSided: false,
	};
}

// The Blender ops (procedural textures, object space).
function blenderCoverageGraph(): MaterialGraph {
	const b = new GraphBuilder();
	const uv = b.node('texcoord', 'vector2', { index: 0 });
	const x = b.extract(uv, 0);
	const y = b.extract(uv, 1);
	const p = b.node('position', 'vector3', {});
	const n = b.node('normal', 'vector3', {});
	const t = b.node('tangent', 'vector3', {});
	const object = b.node('position', 'vector3', { space: 1 });
	const params = b.node('combine4', 'vector4', { in1: b.add(1, b.math('absval', 'float', { in: x })), in2: b.saturate(y), in3: 2, in4: b.saturate(x) });
	const unary = (category: string, v: Arg) => b.math(category, 'float', { in: v });
	const steps = b.add(b.add(unary('floor', x), unary('sign', y)), b.add(unary('exp', b.saturate(x)), unary('ln', b.add(1, unary('absval', y)))));
	const wrapped = b.add(b.math('modulo', 'float', { in1: x, in2: 0.7 }), b.math('veach_greater', 'float', { in1: x, in2: y }));
	const objectNormal = b.node('veach_world_to_object', 'vector3', { in: n });
	const worldCross = b.node('veach_object_to_world', 'vector3', { in: b.math('crossproduct', 'vector3', { in1: objectNormal, in2: object }) });
	const magic = b.math('veach_blender_magic', 'color4', { in: object, distortion: x, depth: 3 });
	return {
		name: 'blender coverage',
		nodes: b.nodes,
		surface: b.node('open_pbr_surface', 'surfaceshader', {
			base_color: b.saturate(b.math('veach_blender_noise', 'color3', { in: object, params: [3, 0.625, 2.25, 0.375], normalize: 1 })),
			fuzz_weight: b.saturate(b.add(b.math('veach_blender_noise', 'float', { in: p, params, normalize: 0 }), 0.5)),
			fuzz_color: b.saturate(b.convert(magic, 'color3')),
			fuzz_roughness: b.saturate(b.add(b.mul(b.math('veach_blender_checker', 'float', { in: b.mul(object, 3) }), 0.5), b.extract(magic, 3))),
			base_diffuse_roughness: b.saturate(b.mul(b.add(steps, wrapped), 0.1)),
			specular_ior: b.add(1.5, b.mul(b.math('dotproduct', 'float', { in1: worldCross, in2: t }), 0.1)),
			geometry_opacity: b.saturate(b.math('veach_blender_checker', 'float', { in: object })),
		}).node,
		alphaMode: AlphaMode.Blend,
		alphaCutoff: 0.5,
		doubleSided: false,
	};
}

describe('material bytecode', () => {
	it('runs every opcode like the graph evaluator', () => {
		const graphs = [coverageGraph(), blenderCoverageGraph()];
		const compiled = graphs.map((g) => compileMaterial(g));
		const used = new Set(compiled.flatMap((c) => [c.surface, c.opacity, c.emission].flatMap((o) => instructions(c, o))));
		const all = Object.values(Op).filter((v): v is Op => typeof v === 'number');
		expect(all.filter((op) => !used.has(op)).map((op) => Op[op])).toEqual([]);
		const random = rng(4);
		for (let i = 0; i < 64; i++) {
			graphs.forEach((g, j) => expectCompiledMatchesGraph(g, compiled[j], randomContext(random)));
		}
	});

	it('runs glTF materials like the graph evaluator', async () => {
		const scenes = [await parseGLTF(gltfJson(SYNTHETIC), { decodeImages: false }), await parseGLTF(gltfJson(SPECULAR_GLOSSINESS), { decodeImages: false })];
		for (const file of [...(hasSamples ? SAMPLE_FILES : []), ...GRAPH_ONLY_FILES]) {
			scenes.push(await parseGLTF(read(file), { decodeImages: false }));
		}
		const random = rng(5);
		for (const m of scenes.flatMap((s) => s.materials)) {
			const compiled = compileMaterial(m.graph);
			for (let i = 0; i < 16; i++) {
				expectCompiledMatchesGraph(m.graph, compiled, randomContext(random));
			}
		}
	});

	it('slices programs and derives the instance flags', async () => {
		const scene = await parseGLTF(gltfJson(SYNTHETIC), { decodeImages: false });
		const compiled = (name: string) => compileMaterial(scene.materials.find((m) => m.name === name)!.graph);

		const textured = compiled('textured');
		expect(textured.alphaTested).toBe(true);
		expect(textured.emissive).toBe(true);
		expect(textured.textures).toHaveLength(4);
		expect(instructions(textured, textured.opacity)).toEqual([Op.Texture, Op.Extract, Op.Mul, Op.Output, Op.End]);
		expect(instructions(textured, textured.emission)).toEqual([Op.Texture, Op.Mul, Op.Output, Op.End]);
		expect(instructions(textured, textured.surface).length).toBeLessThanOrEqual(20);
		expect(textured.stackSize).toBeLessThanOrEqual(6);

		const empty = compiled('empty');
		expect(empty.alphaTested).toBe(false);
		expect(empty.emissive).toBe(false);
		expect(empty.opacity).toBe(-1);
		expect(empty.emission).toBe(-1);
		expect(instructions(empty, empty.surface)).toEqual([Op.Output, Op.Output, Op.Output, Op.End]);
		expect(empty.stackSize).toBe(0);
	});

	it('reuses stack slots of dead values', () => {
		const b = new GraphBuilder();
		const x = b.extract(b.node('texcoord', 'vector2', {}), 0);
		let v: Arg = x;
		for (let i = 0; i < 100; i++) {
			v = b.add(b.mul(v, x), i + 1);
		}
		const graph: MaterialGraph = { name: 'chain', nodes: b.nodes, surface: b.node('open_pbr_surface', 'surfaceshader', { base_metalness: v }).node, alphaMode: AlphaMode.Opaque, alphaCutoff: 0.5, doubleSided: false };
		const compiled = compileMaterial(graph);
		expect(compiled.stackSize).toBeLessThanOrEqual(3);
		expect(evaluateCompiled(compiled, randomContext(rng(6))).base_metalness[0]).toBeCloseTo(evaluateMaterial(graph, randomContext(rng(6))).base_metalness[0], 3);
	});
});
