// glTF material -> MaterialGraph: a gltf_pbr (or veach_gltf_specular_glossiness) surface fed by
// gltf_image / gltf_colorimage / gltf_normalmap nodes, the way MaterialX represents glTF.
import { AlphaMode, type TextureBinding } from '../scene/Scene';
import { GraphBuilder, outputType, type Arg, type ColorSpace, type MaterialGraph, type ValueType } from './Graph';

/* eslint-disable @typescript-eslint/no-explicit-any */
type Json = any;

export type TextureResolver = (info: Json | undefined) => TextureBinding | undefined;

const DEGREES = 180 / Math.PI;

// Texture inputs shared by the gltf_*image nodes. glTF uv conventions (origin top-left) are kept;
// `rotate` is in degrees as in MaterialX.
function imageInputs(t: TextureBinding, colorspace: ColorSpace): Record<string, Arg> {
	return {
		file: { source: t.source, colorspace },
		uvindex: t.texCoord,
		offset: t.offset,
		scale: t.scale,
		rotate: t.rotation * DEGREES,
		uaddressmode: t.wrapS,
		vaddressmode: t.wrapT,
	};
}

class GLTFGraphBuilder extends GraphBuilder {
	constructor(private readonly resolve: TextureResolver) {
		super();
	}

	// factor × texture, or just the factor without a texture (or with a zero factor).
	image(info: Json | undefined, type: ValueType, factor: readonly number[], colorspace: ColorSpace = 'lin_rec709'): Arg {
		const t = this.resolve(info);
		if (!t || factor.every((f) => f === 0)) {
			return factor;
		}
		return this.node('gltf_image', type, { ...imageInputs(t, colorspace), factor });
	}

	// factor × one channel of a texture.
	channel(info: Json | undefined, channel: number, factor: number): Arg {
		const t = this.resolve(info);
		if (!t || factor === 0) {
			return factor;
		}
		const texel = this.node('gltf_image', 'color4', { ...imageInputs(t, 'lin_rec709'), factor: [1, 1, 1, 1] });
		return this.mul(this.extract(texel, channel), factor);
	}

	// color3 and alpha of factor × texture.
	colorImage(info: Json | undefined, factor: readonly number[]): { color: Arg; alpha: Arg } {
		const t = this.resolve(info);
		if (!t) {
			return { color: factor.slice(0, 3), alpha: factor[3] };
		}
		const c = this.node('gltf_colorimage', 'color3', { ...imageInputs(t, 'srgb_texture'), color: factor });
		return { color: { node: c.node, output: 'outcolor' }, alpha: { node: c.node, output: 'outa' } };
	}

	normalMap(info: Json | undefined): Arg | undefined {
		const t = this.resolve(info);
		if (!t) {
			return undefined;
		}
		return this.node('gltf_normalmap', 'vector3', { ...imageInputs(t, 'lin_rec709'), normal_scale: info.scale ?? 1 });
	}
}

function finish(b: GraphBuilder, m: Json, surface: Arg): MaterialGraph {
	if (typeof surface !== 'object' || !('node' in surface) || outputType(b.nodes, surface) !== 'surfaceshader') {
		throw new Error('material graph: surface is not a surfaceshader');
	}
	return {
		name: m.name ?? '',
		nodes: b.nodes,
		surface: surface.node,
		alphaMode: m.alphaMode === 'MASK' ? AlphaMode.Mask : m.alphaMode === 'BLEND' ? AlphaMode.Blend : AlphaMode.Opaque,
		alphaCutoff: m.alphaCutoff ?? 0.5,
		doubleSided: !!m.doubleSided,
	};
}

export function gltfMaterialGraph(m: Json, resolve: TextureResolver): MaterialGraph {
	const b = new GLTFGraphBuilder(resolve);
	const ext = m.extensions ?? {};
	const emissive = b.image(m.emissiveTexture, 'color3', m.emissiveFactor ?? [0, 0, 0], 'srgb_texture');
	const emissiveStrength = ext.KHR_materials_emissive_strength?.emissiveStrength ?? 1;
	const normal = b.normalMap(m.normalTexture);

	const sg = ext.KHR_materials_pbrSpecularGlossiness;
	if (sg) {
		const diffuse = b.colorImage(sg.diffuseTexture, sg.diffuseFactor ?? [1, 1, 1, 1]);
		const specularFactor: number[] = sg.specularFactor ?? [1, 1, 1];
		const glossinessFactor: number = sg.glossinessFactor ?? 1;
		// rgb specular (sRGB) and alpha glossiness (linear) in one texture
		const texel = b.image(sg.specularGlossinessTexture, 'color4', [...specularFactor, glossinessFactor], 'srgb_texture');
		const surface = b.node('veach_gltf_specular_glossiness', 'surfaceshader', {
			diffuse: diffuse.color,
			alpha: diffuse.alpha,
			specular: b.convert(texel, 'color3'),
			glossiness: b.extract(texel, 3),
			normal,
			emissive,
			emissive_strength: emissiveStrength,
		});
		return finish(b, m, surface);
	}

	const pbr = m.pbrMetallicRoughness ?? {};
	const base = b.colorImage(pbr.baseColorTexture, pbr.baseColorFactor ?? [1, 1, 1, 1]);

	if (ext.KHR_materials_unlit) {
		// Unlit surfaces emit their base color and reflect nothing.
		const surface = b.node('open_pbr_surface', 'surfaceshader', {
			base_color: [0, 0, 0],
			specular_weight: 0,
			emission_luminance: 1,
			emission_color: base.color,
			geometry_opacity: base.alpha,
			geometry_thin_walled: true,
		});
		return finish(b, m, surface);
	}

	const metallicFactor: number = pbr.metallicFactor ?? 1;
	const roughnessFactor: number = pbr.roughnessFactor ?? 1;
	let metallic: Arg = metallicFactor;
	let roughness: Arg = roughnessFactor;
	if (resolve(pbr.metallicRoughnessTexture)) {
		const mr = b.image(pbr.metallicRoughnessTexture, 'vector3', [1, roughnessFactor, metallicFactor]);
		roughness = b.extract(mr, 1);
		metallic = b.extract(mr, 2);
	}

	const inputs: Record<string, Arg | undefined> = {
		base_color: base.color,
		alpha: base.alpha,
		metallic,
		roughness,
		normal,
		emissive,
		emissive_strength: emissiveStrength,
		ior: ext.KHR_materials_ior?.ior ?? 1.5,
	};

	const transmission = ext.KHR_materials_transmission;
	if (transmission) {
		inputs.transmission = b.image(transmission.transmissionTexture, 'float', [transmission.transmissionFactor ?? 0]);
	}
	const volume = ext.KHR_materials_volume;
	if (volume) {
		inputs.thickness = volume.thicknessFactor ?? 0;
		inputs.attenuation_distance = volume.attenuationDistance ?? Infinity;
		inputs.attenuation_color = volume.attenuationColor ?? [1, 1, 1];
	}
	if (ext.KHR_materials_dispersion) {
		inputs.dispersion = ext.KHR_materials_dispersion.dispersion ?? 0;
	}
	const clearcoat = ext.KHR_materials_clearcoat;
	if (clearcoat) {
		inputs.clearcoat = b.image(clearcoat.clearcoatTexture, 'float', [clearcoat.clearcoatFactor ?? 0]);
		inputs.clearcoat_roughness = b.channel(clearcoat.clearcoatRoughnessTexture, 1, clearcoat.clearcoatRoughnessFactor ?? 0);
		inputs.clearcoat_normal = b.normalMap(clearcoat.clearcoatNormalTexture);
	}
	const specular = ext.KHR_materials_specular;
	if (specular) {
		inputs.specular = b.channel(specular.specularTexture, 3, specular.specularFactor ?? 1);
		inputs.specular_color = b.image(specular.specularColorTexture, 'color3', specular.specularColorFactor ?? [1, 1, 1], 'srgb_texture');
	}
	const sheen = ext.KHR_materials_sheen;
	if (sheen) {
		inputs.sheen_color = b.image(sheen.sheenColorTexture, 'color3', sheen.sheenColorFactor ?? [0, 0, 0], 'srgb_texture');
		inputs.sheen_roughness = b.channel(sheen.sheenRoughnessTexture, 3, sheen.sheenRoughnessFactor ?? 0);
	}
	const anisotropy = ext.KHR_materials_anisotropy;
	if (anisotropy) {
		const strength: number = anisotropy.anisotropyStrength ?? 0;
		const rotation: number = anisotropy.anisotropyRotation ?? 0;
		inputs.anisotropy_strength = strength;
		inputs.anisotropy_rotation = rotation;
		if (resolve(anisotropy.anisotropyTexture) && strength !== 0) {
			// rg: direction in tangent space, encoded in [0, 1]; b: strength
			const texel = b.image(anisotropy.anisotropyTexture, 'vector3', [1, 1, 1]);
			const dx = b.sub(b.mul(b.extract(texel, 0), 2), 1);
			const dy = b.sub(b.mul(b.extract(texel, 1), 2), 1);
			inputs.anisotropy_strength = b.mul(b.extract(texel, 2), strength);
			inputs.anisotropy_rotation = b.add(b.atan2(dy, dx), rotation);
		}
	}
	const iridescence = ext.KHR_materials_iridescence;
	if (iridescence) {
		inputs.iridescence = b.image(iridescence.iridescenceTexture, 'float', [iridescence.iridescenceFactor ?? 0]);
		inputs.iridescence_ior = iridescence.iridescenceIor ?? 1.3;
		const max: number = iridescence.iridescenceThicknessMaximum ?? 400;
		inputs.iridescence_thickness = max;
		if (resolve(iridescence.iridescenceThicknessTexture)) {
			const min: number = iridescence.iridescenceThicknessMinimum ?? 100;
			inputs.iridescence_thickness = b.mix(min, max, b.channel(iridescence.iridescenceThicknessTexture, 1, 1));
		}
	}

	return finish(b, m, b.node('gltf_pbr', 'surfaceshader', inputs));
}

// SceneDesc's default material: glTF defaults with a grey dielectric.
export function defaultMaterialGraph(): MaterialGraph {
	const b = new GraphBuilder();
	const surface = b.node('gltf_pbr', 'surfaceshader', { base_color: [0.8, 0.8, 0.8], metallic: 0, roughness: 0.5 });
	return finish(b, { name: 'default' }, surface);
}
