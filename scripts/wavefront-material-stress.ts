// Optional benchmark-only workload. Never modifies source assets or production materials.
import { compileMaterial } from '../src/material/Compile';
import { GraphBuilder, toArg, type MaterialGraph } from '../src/material/Graph';
import { lowerGraph } from '../src/material/Lower';
import { OPEN_PBR_SURFACE } from '../src/material/NodeDefs';
import type { SceneDesc } from '../src/scene/Scene';

export function stressMaterial(graph: MaterialGraph, layers: number): MaterialGraph {
	if (!Number.isInteger(layers) || layers < 1 || layers > 12) throw new Error('Material stress layers must be 1..12');
	const lowered = lowerGraph(graph), b = new GraphBuilder();
	b.nodes.push(...lowered.nodes);
	const inputs = Object.fromEntries(Object.entries(lowered.nodes[lowered.surface].inputs).map(([name, input]) => [name, toArg(input)]));
	const p = b.node('position', 'vector3', { space: 1 });
	const bands = Array.from({ length: layers }, (_, i) => b.math('veach_blender_noise', 'color3', {
		in: b.mul(p, 1 + i * 0.37), params: [3, 0.625, 2.25, 0.375], normalize: 1,
	}));
	// Reuse each band for color and roughness so the compiler must retain live values.
	const color = bands.reduce((sum, band) => b.add(sum, band));
	const roughness = bands.map(band => b.extract(band, 0)).reduce((sum, band) => b.add(sum, band));
	const base = inputs.base_color ?? OPEN_PBR_SURFACE.base_color.default!;
	const rough = inputs.specular_roughness ?? OPEN_PBR_SURFACE.specular_roughness.default!;
	const surface = b.node('open_pbr_surface', 'surfaceshader', { ...inputs,
		base_color: b.mul(base, b.add(0.5, b.mul(color, 0.5 / layers))),
		specular_roughness: b.mul(rough, b.add(0.5, b.mul(roughness, 0.5 / layers))),
	});
	return { ...lowered, name: `${graph.name} [noise ${layers}]`, nodes: b.nodes, surface: surface.node };
}

export function applyMaterialStress(scene: SceneDesc, layers: number, mixed = false) {
	if (layers === 0) return null;
	if (!Number.isInteger(layers) || layers < 1 || layers > 12) throw new Error('Material stress layers must be 0..12');
	const materials = scene.materials.map((material, index) => {
		const count = mixed ? 1 + index % layers : layers;
		const graph = stressMaterial(material.graph, count);
		// Do not let the renderer's friendly fallback hide a failed stress workload.
		const compiled = compileMaterial(graph);
		material.graph = graph;
		return { name: graph.name, layers: count, stack: compiled.stackSize };
	});
	return { layers, mixed, materials };
}
