import { describe, expect, it } from 'vitest';
import { compileMaterial } from '../src/material/Compile';
import { defaultMaterialGraph } from '../src/material/GLTFMaterial';
import { GraphBuilder, type MaterialGraph } from '../src/material/Graph';
import { evaluateCompiled, programOps } from '../src/material/Interpreter';
import type { ShadingContext } from '../src/material/Evaluate';
import { stressMaterial } from '../scripts/wavefront-material-stress';
import { AlphaMode } from '../src/scene/Scene';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseGLTF } from '../src/loaders/GLTFLoader';

function compare(graph: MaterialGraph) {
	const a = compileMaterial(graph, { schedule: false }), b = compileMaterial(graph, { schedule: true });
	expect(b.stackSize).toBeLessThanOrEqual(a.stackSize);
	expect(b.textures).toEqual(a.textures);
	expect(b.debugTexture).toBe(a.debugTexture);
	expect([b.alphaTested, b.emissive, b.alphaMode, b.alphaCutoff, b.doubleSided])
		.toEqual([a.alphaTested, a.emissive, a.alphaMode, a.alphaCutoff, a.doubleSided]);
	for (const field of ['surface', 'opacity', 'emission'] as const) {
		if (a[field] < 0) { expect(b[field]).toBe(-1); continue; }
		expect(programOps(b, b[field]).sort()).toEqual(programOps(a, a[field]).sort());
	}
	for (let i = 0; i < 8; i++) {
		const sequence: number[] = [];
		const ctx: ShadingContext = { uv0: [i * 0.13, 0.7], uv1: [0.3, 0.4], position: [i * 0.2, -0.3, 0.4],
			objectPosition: [i * 0.2, -0.3, 0.4], normal: [0, 1, 0], tangent: [1, 0, 0, 1],
			sample: source => { sequence.push(source); return [0.1 * sequence.length, 0.2, 0.3, 0.7]; } };
		const x = evaluateCompiled(a, ctx), originalSequence = [...sequence]; sequence.length = 0;
		expect(evaluateCompiled(b, ctx)).toEqual(x);
		expect(sequence).toEqual(originalSequence);
	}
	return [a, b];
}

describe('material instruction scheduling', () => {
	it.skipIf(!existsSync(join(__dirname, '../public/samples/DamagedHelmet.glb')))('preserves existing glTF material evaluations and texture call order', async () => {
		for (const name of ['DamagedHelmet', 'AlphaBlendModeTest', 'TransmissionTest', 'ClearCoatTest', 'EmissiveStrengthTest',
			'SpecGlossVsMetalRough', 'AnisotropyBarnLamp', 'SheenChair', 'IridescentDishWithOlives']) {
			const path = join(__dirname, `../public/samples/${name}.glb`);
			if (!existsSync(path)) continue;
			const bytes = readFileSync(path);
			const scene = await parseGLTF(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer);
			for (const material of scene.materials) compare(material.graph);
		}
	});
	it('reduces reusable procedural live ranges without removing or reassociating operations', () => {
		for (const layers of [4, 8, 12]) {
			const graph = stressMaterial(defaultMaterialGraph(), layers);
			const [a, b] = compare(graph);
			expect(compileMaterial(graph).code).toEqual(a.code);
			expect(a.stackSize).toBe(layers + 1);
			expect(b.stackSize).toBe(4);
		}
	});
	it('preserves texture sequence and sliced opacity/emission programs', () => {
		const b = new GraphBuilder();
		const textures = [0, 1, 2].map(source => b.node('veach_texture', 'color4', { file: { source, colorspace: 'lin_rec709' } }));
		const surface = b.node('open_pbr_surface', 'surfaceshader', {
			base_color: b.mul(b.convert(textures[0], 'color3'), b.convert(textures[1], 'color3')),
			specular_roughness: b.extract(textures[0], 0), geometry_opacity: b.extract(textures[2], 3),
			emission_luminance: b.extract(textures[1], 1), emission_color: b.convert(textures[2], 'color3'),
		});
		compare(stressMaterial({ name: 'ordered samples', nodes: b.nodes, surface: surface.node,
			alphaMode: AlphaMode.Blend, alphaCutoff: 0.5, doubleSided: true }, 4));
	});
	it('preserves deterministic DAGs with shared branches, aliases and multiple outputs', () => {
		let seed = 12345;
		const random = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 0x100000000; };
		for (let trial = 0; trial < 80; trial++) {
			const b = new GraphBuilder(), uv = b.node('texcoord', 'vector2', { index: 0 });
			const values = [b.extract(uv, 0), b.extract(uv, 1)];
			for (let n = 0; n < 25; n++) {
				const a = values[Math.floor(random() * values.length)], c = values[Math.floor(random() * values.length)];
				values.push(b.math(n % 2 ? 'sin' : 'cos', 'float', { in: b.add(a, b.mul(c, 0.3)) }));
			}
			const surface = b.node('open_pbr_surface', 'surfaceshader', {
				base_color: b.convert(b.saturate(values[26]), 'color3'), specular_roughness: b.saturate(values[25]),
				coat_weight: b.saturate(values[24]), coat_roughness: b.saturate(values[23]),
			});
			compare({ name: 'shared DAG', nodes: b.nodes, surface: surface.node, alphaMode: AlphaMode.Opaque, alphaCutoff: 0.5, doubleSided: false });
		}
	});
});
