// Input definitions of the surface nodes. Names and defaults follow the MaterialX nodedefs
// (ND_open_pbr_surface_surfaceshader, ND_gltf_pbr_surfaceshader); inputs without a default take
// a geometric property of the hit (normal, tangent).
import type { ValueType } from './Graph';

export interface InputDef {
	type: ValueType;
	default?: number[];
}

export const OPEN_PBR_SURFACE: Record<string, InputDef> = {
	base_weight: { type: 'float', default: [1] },
	base_color: { type: 'color3', default: [0.8, 0.8, 0.8] },
	base_diffuse_roughness: { type: 'float', default: [0] },
	base_metalness: { type: 'float', default: [0] },
	specular_weight: { type: 'float', default: [1] },
	specular_color: { type: 'color3', default: [1, 1, 1] },
	specular_roughness: { type: 'float', default: [0.3] },
	specular_roughness_anisotropy: { type: 'float', default: [0] },
	specular_ior: { type: 'float', default: [1.5] },
	transmission_weight: { type: 'float', default: [0] },
	transmission_color: { type: 'color3', default: [1, 1, 1] },
	transmission_depth: { type: 'float', default: [0] },
	transmission_scatter: { type: 'color3', default: [0, 0, 0] },
	transmission_scatter_anisotropy: { type: 'float', default: [0] },
	transmission_dispersion_scale: { type: 'float', default: [0] },
	transmission_dispersion_abbe_number: { type: 'float', default: [20] },
	subsurface_weight: { type: 'float', default: [0] },
	subsurface_color: { type: 'color3', default: [0.8, 0.8, 0.8] },
	subsurface_radius: { type: 'float', default: [1] },
	subsurface_radius_scale: { type: 'color3', default: [1, 0.5, 0.25] },
	subsurface_scatter_anisotropy: { type: 'float', default: [0] },
	fuzz_weight: { type: 'float', default: [0] },
	fuzz_color: { type: 'color3', default: [1, 1, 1] },
	fuzz_roughness: { type: 'float', default: [0.5] },
	coat_weight: { type: 'float', default: [0] },
	coat_color: { type: 'color3', default: [1, 1, 1] },
	coat_roughness: { type: 'float', default: [0] },
	coat_roughness_anisotropy: { type: 'float', default: [0] },
	coat_ior: { type: 'float', default: [1.6] },
	coat_darkening: { type: 'float', default: [1] },
	thin_film_weight: { type: 'float', default: [0] },
	thin_film_thickness: { type: 'float', default: [0.5] }, // micrometers
	thin_film_ior: { type: 'float', default: [1.4] },
	emission_luminance: { type: 'float', default: [0] },
	emission_color: { type: 'color3', default: [1, 1, 1] },
	geometry_opacity: { type: 'float', default: [1] },
	geometry_thin_walled: { type: 'boolean', default: [0] },
	geometry_normal: { type: 'vector3' },
	geometry_coat_normal: { type: 'vector3' },
	geometry_tangent: { type: 'vector3' },
	geometry_coat_tangent: { type: 'vector3' },
};

// glTF metallic-roughness and the KHR_materials_* extensions. Alpha mode, cutoff and double-sidedness
// live on the MaterialGraph instead.
export const GLTF_PBR: Record<string, InputDef> = {
	base_color: { type: 'color3', default: [1, 1, 1] },
	metallic: { type: 'float', default: [1] },
	roughness: { type: 'float', default: [1] },
	normal: { type: 'vector3' },
	alpha: { type: 'float', default: [1] },
	ior: { type: 'float', default: [1.5] },
	transmission: { type: 'float', default: [0] },
	specular: { type: 'float', default: [1] },
	specular_color: { type: 'color3', default: [1, 1, 1] },
	clearcoat: { type: 'float', default: [0] },
	clearcoat_roughness: { type: 'float', default: [0] },
	clearcoat_normal: { type: 'vector3' },
	sheen_color: { type: 'color3', default: [0, 0, 0] },
	sheen_roughness: { type: 'float', default: [0] },
	iridescence: { type: 'float', default: [0] },
	iridescence_ior: { type: 'float', default: [1.3] },
	iridescence_thickness: { type: 'float', default: [100] }, // nanometers
	anisotropy_strength: { type: 'float', default: [0] },
	anisotropy_rotation: { type: 'float', default: [0] }, // radians, from the tangent toward the bitangent
	emissive: { type: 'color3', default: [0, 0, 0] },
	emissive_strength: { type: 'float', default: [1] },
	thickness: { type: 'float', default: [0] },
	attenuation_distance: { type: 'float', default: [Infinity] },
	attenuation_color: { type: 'color3', default: [1, 1, 1] },
	dispersion: { type: 'float', default: [0] },
};

// KHR_materials_pbrSpecularGlossiness. Not a MaterialX nodedef: Veach's own.
export const GLTF_SPECULAR_GLOSSINESS: Record<string, InputDef> = {
	diffuse: { type: 'color3', default: [1, 1, 1] },
	alpha: { type: 'float', default: [1] },
	specular: { type: 'color3', default: [1, 1, 1] },
	glossiness: { type: 'float', default: [1] },
	normal: { type: 'vector3' },
	emissive: { type: 'color3', default: [0, 0, 0] },
	emissive_strength: { type: 'float', default: [1] },
};

export const SURFACE_DEFS: Record<string, Record<string, InputDef>> = {
	open_pbr_surface: OPEN_PBR_SURFACE,
	gltf_pbr: GLTF_PBR,
	veach_gltf_specular_glossiness: GLTF_SPECULAR_GLOSSINESS,
};

// Outputs other than 'out'.
export const MULTI_OUTPUT_TYPES: Record<string, Record<string, ValueType>> = {
	gltf_colorimage: { outcolor: 'color3', outa: 'float' },
};
