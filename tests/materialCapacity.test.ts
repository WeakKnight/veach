import { describe, expect, it } from 'vitest';
import { compileMaterial } from '../src/material/Compile';
import { defaultMaterialGraph } from '../src/material/GLTFMaterial';
import { GraphBuilder, type MaterialGraph } from '../src/material/Graph';
import { AlphaMode, type SceneDesc } from '../src/scene/Scene';
import { materialShadeCapacities, materialStackCapacity, materialLightCapacity } from '../src/render/MaterialCapacity';
import { packMaterialData } from '../src/render/GpuLayout';
import { sceneShadeCapacities } from '../src/render/SceneMaterials';
import { stressMaterial } from '../scripts/wavefront-material-stress';

function textured(field: string): MaterialGraph {
	const b = new GraphBuilder();
	const x = b.node('veach_texture', 'color4', { file: { source: 0, colorspace: 'lin_rec709' } });
	const y = b.node('veach_texture', 'color4', { file: { source: 1, colorspace: 'lin_rec709' } });
	const surface = b.node('open_pbr_surface', 'surfaceshader', { base_color: [0.3, 0.4, 0.5], emission_luminance: 2,
		[field]: b.mul(b.extract(x, 0), b.extract(y, 1)) });
	return { name: field, nodes: b.nodes, surface: surface.node, alphaMode: AlphaMode.Mask, alphaCutoff: 0.4, doubleSided: true };
}

describe('material shading capacity', () => {
	it('reports independent program maxima, including absent programs after a larger one', () => {
		const opacity = compileMaterial(textured('geometry_opacity'));
		expect(opacity.programStackSizes.surface).toBe(0);
		expect(opacity.programStackSizes.opacity).toBeGreaterThan(0);
		expect(opacity.programStackSizes.emission).toBe(0);
		const heavy = compileMaterial(stressMaterial(defaultMaterialGraph(), 8));
		expect(heavy.programStackSizes.surface).toBe(9);
		expect(heavy.programStackSizes.opacity).toBe(0);
		expect(heavy.programStackSizes.emission).toBe(0);
		for (const m of [opacity, heavy]) expect(m.stackSize).toBe(Math.max(...Object.values(m.programStackSizes)));
	});

	it('reserves other materials emission stacks while preserving packed alpha flags', () => {
		const cheap = compileMaterial(textured('geometry_opacity'));
		const light = compileMaterial(textured('emission_luminance'));
		const heavy = compileMaterial(stressMaterial(defaultMaterialGraph(), 8));
		const materials = [cheap, light, heavy];
		const capacities = materialShadeCapacities(materials);
		expect(capacities[0]).toBe(materialStackCapacity(light.programStackSizes.emission));
		expect(capacities[0]).toBeGreaterThan(0);
		expect(capacities[2]).toBe(16);
		const data = packMaterialData(materials, () => null);
		for (let i = 0; i < materials.length; i++) {
			expect((data[i * 8 + 3] >>> 16) & 31).toBe(capacities[i]);
			expect((data[i * 8 + 3] >>> 8) & 3).toBe(materials[i].alphaMode);
			expect((data[i * 8 + 3] >>> 21) & 31).toBe(materialStackCapacity(materials[i].programStackSizes.surface));
			expect((data[i * 8 + 3] >>> 26) & 31).toBe(materialLightCapacity(materials[i]));
			expect(data[i * 8 + 3] & 1).toBe(Number(materials[i].doubleSided));
		}
	});

	it('separates masked-emitter opacity from surface capacity and ignores blend opacity for NEE', () => {
		const masked = compileMaterial(textured('geometry_opacity'));
		const capacity = materialStackCapacity(masked.programStackSizes.opacity);
		expect(materialLightCapacity(masked)).toBe(capacity);
		expect(materialShadeCapacities([masked])).toEqual([capacity]);
		expect(materialShadeCapacities([masked], true)).toEqual([0]);
		expect(materialLightCapacity({ ...masked, alphaMode: AlphaMode.Blend })).toBe(0);
		expect(materialShadeCapacities([{ ...masked, emissive: false }])).toEqual([0]);
	});

	it('prepares only referenced surfaces but keeps a conservative emission floor', () => {
		const materials = [compileMaterial(defaultMaterialGraph()), compileMaterial(textured('emission_luminance')),
			compileMaterial(stressMaterial(defaultMaterialGraph(), 8)), compileMaterial(defaultMaterialGraph())];
		const scene = { meshes: [{ material: 0 }, { material: -1 }], instances: [{ mesh: 0 }, { mesh: 1 }] } as SceneDesc;
		const capacity = materialStackCapacity(materials[1].programStackSizes.emission);
		expect(sceneShadeCapacities(scene, materials)).toEqual([capacity]);
		expect(sceneShadeCapacities({ ...scene, instances: [] }, materials)).toEqual([]);
	});
});
