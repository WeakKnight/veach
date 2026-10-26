// Lowering: every surface becomes an open_pbr_surface fed by primitive nodes only (math, geometry,
// veach_texture, normalmap). The gltf_pbr mapping is the one Materials/MaterialSample.slang applies.
import { AlphaMode } from '../scene/Scene';
import {
	GraphBuilder,
	constantOf,
	isConnection,
	isConstant,
	toArg,
	type Arg,
	type Connection,
	type Input,
	type MaterialGraph,
} from './Graph';
import { GLTF_PBR, GLTF_SPECULAR_GLOSSINESS, type InputDef } from './NodeDefs';

const RADIANS = Math.PI / 180;

type Args = Record<string, Arg | undefined>;

function withDefaults(inputs: Args, defs: Record<string, InputDef>): Args {
	const out: Args = { ...inputs };
	for (const [name, def] of Object.entries(defs)) {
		if (out[name] === undefined && def.default) {
			out[name] = def.default;
		}
	}
	return out;
}

// gltf_*image texture inputs -> one veach_texture sample (rgba, colorspace decoded).
function texture(b: GraphBuilder, i: Args): Arg {
	return b.node('veach_texture', 'color4', {
		file: i.file,
		uvindex: i.uvindex ?? 0,
		offset: i.offset ?? [0, 0],
		scale: i.scale ?? [1, 1],
		rotation: b.mul(i.rotate ?? 0, RADIANS),
		uaddressmode: i.uaddressmode ?? 0,
		vaddressmode: i.vaddressmode ?? 0,
	});
}

function emission(b: GraphBuilder, i: Args): Args {
	return { emission_luminance: 1, emission_color: b.mul(i.emissive!, i.emissive_strength!) };
}

function lowerGltfPbr(b: GraphBuilder, i: Args, alphaMode: AlphaMode): Arg {
	const thickness = constantOf(i.thickness);
	const thinWalled = thickness !== null && !(thickness[0] > 0);
	const attenuationDistance = constantOf(i.attenuation_distance)?.[0] ?? Infinity;
	const out: Args = {
		base_color: i.base_color,
		base_metalness: b.saturate(i.metallic!),
		specular_roughness: b.saturate(i.roughness!),
		specular_ior: i.ior,
		specular_weight: i.specular,
		specular_color: i.specular_color,
		transmission_weight: b.saturate(i.transmission!),
		geometry_thin_walled: thinWalled,
		coat_weight: b.saturate(i.clearcoat!),
		coat_roughness: b.saturate(i.clearcoat_roughness!),
		coat_ior: 1.5,
		thin_film_weight: b.saturate(i.iridescence!),
		thin_film_thickness: b.mul(i.iridescence_thickness!, 1e-3),
		thin_film_ior: i.iridescence_ior,
		geometry_normal: i.normal,
		geometry_coat_normal: i.clearcoat_normal ?? i.normal,
		geometry_opacity: alphaMode === AlphaMode.Opaque ? undefined : i.alpha,
		...emission(b, i),
	};

	if (!thinWalled && Number.isFinite(attenuationDistance) && attenuationDistance > 0) {
		out.transmission_color = i.attenuation_color;
		out.transmission_depth = attenuationDistance;
	} else {
		// glTF tints transmission by the base color (at the surface when there is no attenuation)
		out.transmission_color = i.base_color;
	}
	if (!isConstant(i.dispersion, 0)) {
		out.transmission_dispersion_scale = 1;
		out.transmission_dispersion_abbe_number = b.div(20, i.dispersion!);
	}
	if (!isConstant(i.sheen_color, 0)) {
		out.fuzz_weight = 1;
		out.fuzz_color = i.sheen_color;
		out.fuzz_roughness = b.saturate(i.sheen_roughness!);
	}
	if (!isConstant(i.anisotropy_strength, 0)) {
		out.specular_roughness_anisotropy = b.saturate(i.anisotropy_strength!);
		const rotation = i.anisotropy_rotation!;
		if (!isConstant(rotation, 0)) {
			const t = b.node('tangent', 'vector3', {});
			const bt = b.node('bitangent', 'vector3', {});
			out.geometry_tangent = b.add(b.mul(t, b.unary('cos', rotation)), b.mul(bt, b.unary('sin', rotation)));
		}
	}
	return b.node('open_pbr_surface', 'surfaceshader', out);
}

// F0 = specular exactly: specular_weight scales the F0 of IOR 1.5 (0.04), specular_color tints it.
function lowerSpecularGlossiness(b: GraphBuilder, i: Args, alphaMode: AlphaMode): Arg {
	const f0 = i.specular!;
	const maxF0 = b.max(b.max(b.extract(f0, 0), b.extract(f0, 1)), b.extract(f0, 2));
	return b.node('open_pbr_surface', 'surfaceshader', {
		base_color: i.diffuse,
		base_metalness: 0,
		specular_roughness: b.sub(1, b.saturate(i.glossiness!)),
		specular_ior: 1.5,
		specular_weight: b.div(maxF0, 0.04),
		specular_color: b.div(f0, b.max(maxF0, 1e-6)),
		geometry_normal: i.normal,
		geometry_coat_normal: i.normal,
		geometry_opacity: alphaMode === AlphaMode.Opaque ? undefined : i.alpha,
		...emission(b, i),
	});
}

export function lowerGraph(graph: MaterialGraph): MaterialGraph {
	const b = new GraphBuilder();
	const mapped = new Map<string, Arg>();
	const key = (c: Connection) => `${c.node}.${c.output}`;
	const resolve = (input: Input): Arg => {
		if (!isConnection(input)) {
			return toArg(input);
		}
		const arg = mapped.get(key(input));
		if (arg === undefined) {
			throw new Error(`material graph: ${graph.nodes[input.node]?.category ?? '?'} has no output ${input.output}`);
		}
		return arg;
	};

	graph.nodes.forEach((node, index) => {
		const i: Args = {};
		for (const [name, input] of Object.entries(node.inputs)) {
			i[name] = resolve(input);
		}
		const set = (output: string, arg: Arg) => mapped.set(key({ node: index, output }), arg);
		switch (node.category) {
			case 'gltf_image': {
				const texel = texture(b, i);
				const value = node.type === 'float' ? b.extract(texel, 0) : b.convert(texel, node.type);
				set('out', b.mul(value, i.factor ?? 1));
				break;
			}
			case 'gltf_colorimage': {
				const texel = texture(b, i);
				const color = i.color ?? [1, 1, 1, 1];
				set('outcolor', b.mul(b.convert(texel, 'color3'), b.convert(color, 'color3')));
				set('outa', b.mul(b.extract(texel, 3), b.extract(color, 3)));
				break;
			}
			case 'gltf_normalmap':
				set('out', b.node('normalmap', 'vector3', { in: b.convert(texture(b, i), 'vector3'), scale: i.normal_scale ?? 1 }));
				break;
			case 'gltf_pbr':
				set('out', lowerGltfPbr(b, withDefaults(i, GLTF_PBR), graph.alphaMode));
				break;
			case 'veach_gltf_specular_glossiness':
				set('out', lowerSpecularGlossiness(b, withDefaults(i, GLTF_SPECULAR_GLOSSINESS), graph.alphaMode));
				break;
			case 'open_pbr_surface':
				set('out', b.node('open_pbr_surface', 'surfaceshader', { ...i, geometry_opacity: graph.alphaMode === AlphaMode.Opaque ? undefined : i.geometry_opacity }));
				break;
			default:
				set('out', b.replay(node.category, node.type, i));
				break;
		}
	});

	const surface = mapped.get(key({ node: graph.surface, output: 'out' }));
	if (!surface || !isConnection(surface)) {
		throw new Error('material graph: no surface');
	}
	return { ...graph, nodes: b.nodes, surface: surface.node };
}
