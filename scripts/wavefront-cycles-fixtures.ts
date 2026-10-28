import { AlphaMode, defaultMaterial, type SceneDesc, type MeshDesc } from '../src/scene/Scene';
import { GraphBuilder } from '../src/material/Graph';
import { mat4 } from '../src/math/Math';

// Deterministic stress cases for independent light and opacity programs.
export function cyclesFixture(kind: 'deep-alpha' | 'masked-emitter'): SceneDesc {
	const receiver = defaultMaterial();
	const alpha = defaultMaterial(), b = new GraphBuilder();
	const uv = b.node('texcoord', 'vector2', { index: 0 });
	const opacity = b.add(0.1, b.mul(b.extract(uv, 0), kind === 'deep-alpha' ? 0.1 : 0.8));
	const surface = b.node('open_pbr_surface', 'surfaceshader', {
		base_color: [0.6, 0.4, 0.2], specular_roughness: 0.5, geometry_opacity: opacity,
		emission_luminance: kind === 'masked-emitter' ? 20 : 0, emission_color: [1, 0.6, 0.2],
	});
	alpha.graph = { name: kind, nodes: b.nodes, surface: surface.node, alphaMode: AlphaMode.Mask, alphaCutoff: 0.5, doubleSided: true };
	const meshes: MeshDesc[] = [];
	function plane(z: number, material: number, size: number, x = 0) {
		meshes.push({ name: `plane-${meshes.length}`, material,
			positions: new Float32Array([x-size,-size,z, x+size,-size,z, x+size,size,z, x-size,size,z]),
			normals: null, tangents: null, uv0: new Float32Array([0,0,1,0,1,1,0,1]), uv1: null,
			indices: new Uint32Array([0,1,2,0,2,3]) });
	}
	plane(0, 0, 5);
	if (kind === 'deep-alpha') for (let i = 0; i < 24; i++) plane(0.15 + i * 0.06, 1, 4);
	else plane(2, 1, 0.8, 2);
	const camera = mat4.identity(); camera[14] = 5;
	return { materials: [receiver, alpha], textures: [], meshes,
		instances: meshes.map((_, mesh) => ({ mesh, transform: mat4.identity() })),
		cameras: [{ name: kind, transform: camera, yfov: 0.7 }],
		lights: kind === 'deep-alpha' ? [{ type: 'point', position: [0, 0, 3], direction: [0, 0, -1], power: [100, 100, 100],
			radius: 0, spotAngle: 1, spotBlend: 0, sizeU: [0,0,0], sizeV: [0,0,0], ellipse: false, visibleToCamera: false, castShadow: true }] : [],
	};
}
