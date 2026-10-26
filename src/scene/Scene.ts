// Backend-independent scene description produced by the loaders and consumed by the GPU scene builder.
import { defaultMaterialGraph } from '../material/GLTFMaterial';
import type { MaterialGraph } from '../material/Graph';
import type { Mat4, Vec3 } from '../math/Math';

export enum WrapMode {
	Repeat = 0,
	Clamp = 1,
	Mirror = 2,
}

export enum AlphaMode {
	Opaque = 0,
	Mask = 1,
	Blend = 2,
}

export interface TextureSource {
	name: string;
	image: ImageBitmap | null; // null when images are not decoded (e.g. in Node tests)
}

export interface TextureBinding {
	source: number; // index into SceneDesc.textures
	texCoord: 0 | 1;
	wrapS: WrapMode;
	wrapT: WrapMode;
	offset: [number, number];
	scale: [number, number];
	rotation: number;
}

export interface MaterialTextures {
	baseColor?: TextureBinding;
	metallicRoughness?: TextureBinding; // G = roughness, B = metallic
	normal?: TextureBinding;
	emissive?: TextureBinding;
	transmission?: TextureBinding; // R
	clearcoat?: TextureBinding; // R
	clearcoatRoughness?: TextureBinding; // G
}

// glTF metallic-roughness and KHR_materials_* parameters (factors; textures in `textures`).
// `graph` is the same material as a node graph (docs/MaterialSystem.md); the renderer does not
// read it yet.
export interface MaterialDesc {
	name: string;
	graph: MaterialGraph;
	baseColor: [number, number, number, number];
	emission: Vec3; // already multiplied by the emissive strength
	metallic: number;
	roughness: number;
	ior: number;
	specularWeight: number; // KHR_materials_specular specularFactor
	specularColor: Vec3; // KHR_materials_specular specularColorFactor
	transmission: number;
	thinWalled: boolean; // no KHR_materials_volume thickness: an infinitely thin surface
	attenuationColor: Vec3; // KHR_materials_volume
	attenuationDistance: number; // Infinity = no absorption
	dispersion: number; // KHR_materials_dispersion: 20 / Abbe number
	clearcoat: number;
	clearcoatRoughness: number;
	sheenColor: Vec3;
	sheenRoughness: number;
	anisotropy: number; // KHR_materials_anisotropy strength
	anisotropyRotation: number; // radians, from the tangent toward the bitangent
	iridescence: number;
	iridescenceIor: number;
	iridescenceThickness: number; // nanometers (thicknessMaximum)
	normalScale: number;
	alphaCutoff: number;
	alphaMode: AlphaMode;
	doubleSided: boolean;
	textures: MaterialTextures;
}

// One triangle list with a single material (a glTF mesh primitive).
export interface MeshDesc {
	name: string;
	positions: Float32Array; // xyz
	normals: Float32Array | null; // xyz; null = flat shading
	tangents: Float32Array | null; // xyzw
	uv0: Float32Array | null;
	uv1: Float32Array | null;
	indices: Uint32Array;
	material: number; // -1 = default material
}

export interface InstanceDesc {
	mesh: number;
	transform: Mat4;
}

export interface CameraDesc {
	name: string;
	transform: Mat4; // camera looks down -Z, +Y up
	yfov: number;
	aspectRatio?: number;
}

// Analytic light with Cycles conventions: `power` is the radiant flux in watts per channel (color
// times strength); points and spots are spheres (radius 0 = delta light), area lights emit from
// their front side along `direction`.
export interface LightDesc {
	type: 'point' | 'spot' | 'area';
	position: Vec3;
	direction: Vec3; // spot axis / area light normal
	power: Vec3;
	radius: number;
	spotAngle: number; // full cone angle, radians
	spotBlend: number; // 0..1
	sizeU: Vec3; // area light extents (full size)
	sizeV: Vec3;
	ellipse: boolean;
	visibleToCamera: boolean;
	castShadow: boolean;
}

export interface SceneDesc {
	meshes: MeshDesc[];
	materials: MaterialDesc[];
	textures: TextureSource[];
	instances: InstanceDesc[];
	cameras: CameraDesc[];
	lights?: LightDesc[];
}

export function defaultMaterial(): MaterialDesc {
	return {
		name: 'default',
		graph: defaultMaterialGraph(),
		baseColor: [0.8, 0.8, 0.8, 1],
		emission: [0, 0, 0],
		metallic: 0,
		roughness: 0.5,
		ior: 1.5,
		specularWeight: 1,
		specularColor: [1, 1, 1],
		transmission: 0,
		thinWalled: true,
		attenuationColor: [1, 1, 1],
		attenuationDistance: Infinity,
		dispersion: 0,
		clearcoat: 0,
		clearcoatRoughness: 0,
		sheenColor: [0, 0, 0],
		sheenRoughness: 0,
		anisotropy: 0,
		anisotropyRotation: 0,
		iridescence: 0,
		iridescenceIor: 1.3,
		iridescenceThickness: 400,
		normalScale: 1,
		alphaCutoff: 0.5,
		alphaMode: AlphaMode.Opaque,
		doubleSided: false,
		textures: {},
	};
}

export function sceneBounds(scene: SceneDesc): { min: Vec3; max: Vec3 } | null {
	const min: Vec3 = [Infinity, Infinity, Infinity];
	const max: Vec3 = [-Infinity, -Infinity, -Infinity];
	for (const inst of scene.instances) {
		const p = scene.meshes[inst.mesh].positions;
		const m = inst.transform;
		for (let i = 0; i < p.length; i += 3) {
			for (let r = 0; r < 3; r++) {
				const v = m[r] * p[i] + m[4 + r] * p[i + 1] + m[8 + r] * p[i + 2] + m[12 + r];
				min[r] = Math.min(min[r], v);
				max[r] = Math.max(max[r], v);
			}
		}
	}
	return min[0] <= max[0] ? { min, max } : null;
}
