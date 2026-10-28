import { GraphBuilder, type Arg, type ColorSpace, type MaterialGraph } from './Graph';
import { AlphaMode, WrapMode } from '../scene/Scene';
import type { PbrMaterial, ResourceTextureBinding } from '../scene/RenderScene';

export type HostTextureResolver = (binding: ResourceTextureBinding) => { source: number; colorSpace: ColorSpace };

/** PBR parameters are translated to the same graph/compiler used by imported materials. */
export function hostMaterialGraph(desc: PbrMaterial, resolve: HostTextureResolver): MaterialGraph {
	const b = new GraphBuilder();
	const wrap = (value: ResourceTextureBinding['wrapU']) => value === 'clamp' ? WrapMode.Clamp : value === 'mirror' ? WrapMode.Mirror : WrapMode.Repeat;
	const image = (binding: ResourceTextureBinding): Arg => {
		const texture = resolve(binding);
		return b.node('gltf_image', 'color4', {
			file: { source: texture.source, colorspace: texture.colorSpace }, factor: [1, 1, 1, 1],
			uvindex: binding.texCoord ?? 0, offset: binding.offset ?? [0, 0], scale: binding.scale ?? [1, 1],
			rotate: (binding.rotation ?? 0) * 180 / Math.PI, uaddressmode: wrap(binding.wrapU), vaddressmode: wrap(binding.wrapV),
		});
	};
	const scalar = (binding: ResourceTextureBinding | undefined, value: number, channel: number): Arg =>
		binding ? b.mul(value, b.extract(image(binding), binding.channel ?? channel)) : value;
	const baseTexel = desc.baseColorMap ? image(desc.baseColorMap) : null;
	const base: Arg = baseTexel ? b.mul(desc.baseColor ?? [1, 1, 1], b.convert(baseTexel, 'color3')) : desc.baseColor ?? [1, 1, 1];
	let alpha: Arg = desc.opacity ?? 1;
	if (baseTexel) alpha = b.mul(alpha, b.extract(baseTexel, 3));
	if (desc.opacityMap) alpha = b.mul(alpha, b.extract(image(desc.opacityMap), desc.opacityMap.channel ?? 3));
	let normal: Arg | undefined;
	if (desc.normalMap) {
		const texel = b.convert(image(desc.normalMap), 'vector3');
		const scale = desc.normalScale ?? [1, 1];
		const scaled = b.add(b.mul(b.sub(texel, [0.5, 0.5, 0.5]), [scale[0], scale[1], 1]), [0.5, 0.5, 0.5]);
		normal = b.node('normalmap', 'vector3', { in: scaled, scale: 1 });
	}
	const emission: Arg = desc.emissionMap ? b.mul(desc.emission ?? [0, 0, 0], b.convert(image(desc.emissionMap), 'color3')) : desc.emission ?? [0, 0, 0];
	const surface = desc.unlit ? b.node('open_pbr_surface', 'surfaceshader', {
		base_color: [0, 0, 0], specular_weight: 0, emission_luminance: 1, emission_color: base,
		geometry_opacity: alpha, geometry_thin_walled: true,
	}) : b.node('gltf_pbr', 'surfaceshader', {
		base_color: base, metallic: scalar(desc.metallicMap, desc.metallic ?? 0, 2),
		roughness: scalar(desc.roughnessMap, desc.roughness ?? 0.5, 1), alpha, normal,
		emissive: emission, emissive_strength: 1, ior: desc.ior ?? 1.5, transmission: desc.transmission ?? 0,
	});
	return { name: desc.name ?? '', nodes: b.nodes, surface: surface.node,
		alphaMode: desc.alphaMode === 'mask' ? AlphaMode.Mask : AlphaMode.Opaque,
		alphaCutoff: desc.alphaCutoff ?? 0.5, doubleSided: desc.doubleSided ?? false };
}
