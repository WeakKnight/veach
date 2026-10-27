import { describe, expect, it } from 'vitest';
import { stressMaterial } from '../scripts/wavefront-material-stress';
import { compileMaterial } from '../src/material/Compile';
import { Op } from '../src/material/Bytecode';
import { GraphBuilder } from '../src/material/Graph';
import { evaluateCompiled, programOps } from '../src/material/Interpreter';
import type { ShadingContext } from '../src/material/Evaluate';
import { AlphaMode } from '../src/scene/Scene';
import type { Vec3 } from '../src/math/Math';

describe('optional wavefront material stress', () => {
	const b = new GraphBuilder();
	const graph = { name: 'preserve transport', nodes: b.nodes,
		surface: b.node('open_pbr_surface', 'surfaceshader', {
			base_color: [0.7, 0.4, 0.2], specular_roughness: 0.6, geometry_opacity: 0.4,
			transmission_weight: 0.7, coat_weight: 0.2, emission_luminance: 3, emission_color: [1, 0.2, 0.1],
		}).node, alphaMode: AlphaMode.Blend, alphaCutoff: 0.5, doubleSided: true };
	it('preserves transport fields and source graphs while adding real procedural work', () => {
		const before = JSON.stringify(graph), original = compileMaterial(graph);
		for (const layers of [1, 4, 8, 12]) {
			const result = stressMaterial(graph, layers), compiled = compileMaterial(result);
			expect(programOps(compiled, compiled.surface).filter(op => op === Op.Noise)).toHaveLength(layers);
			expect(compiled.stackSize).toBeGreaterThanOrEqual(layers);
			expect(compiled.alphaTested).toBe(true);
			expect(compiled.emissive).toBe(true);
			for (const objectPosition of [[0.31, 0.57, 0.91], [1.1, -2.3, 4.7]] as Vec3[]) {
				const ctx: ShadingContext = { objectPosition, position: objectPosition, normal: [0, 1, 0], tangent: [1, 0, 0, 1],
					uv0: [0.2, 0.4], uv1: [0.1, 0.3], sample: () => [1, 1, 1, 1] };
				const a = evaluateCompiled(original, ctx), c = evaluateCompiled(compiled, ctx);
				for (const name of Object.keys(a)) {
					if (name === 'base_color' || name === 'specular_roughness') expect(c[name]).not.toEqual(a[name]);
					else expect(c[name]).toEqual(a[name]);
				}
			}
		}
		expect(JSON.stringify(graph)).toBe(before);
	});
});
