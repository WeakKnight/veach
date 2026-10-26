import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { describe, expect, it } from 'vitest';
import { loadBlend } from '../src/loaders/blend/BlendLoader';
import { translateWorld } from '../src/loaders/blend/BlendNodes';
import { compileMaterial } from '../src/material/Compile';

// Blender's tests/files/render/principled_bsdf, copied to public/samples/blender (gitignored).
const DIR = resolve(__dirname, '../public/samples/blender');
const files = existsSync(DIR) ? readdirSync(DIR).filter((f) => f.endsWith('.blend')) : [];

describe.skipIf(files.length === 0)('blend loader', () => {
	it.each(files)('loads %s', (file) => {
		const blend = loadBlend(new Uint8Array(readFileSync(join(DIR, file))));
		const { scene } = blend;
		expect(scene.cameras.length).toBeGreaterThan(0);
		expect(scene.instances.length).toBeGreaterThan(0);
		expect(blend.render.width).toBeGreaterThan(0);
		for (const instance of scene.instances) {
			const mesh = scene.meshes[instance.mesh];
			expect(mesh.indices.length % 3).toBe(0);
			expect(mesh.indices.every((i) => i < mesh.positions.length / 3)).toBe(true);
			expect(mesh.positions.every(Number.isFinite)).toBe(true);
		}
		for (const m of scene.materials) {
			const compiled = compileMaterial(m.graph);
			expect(compiled.stackSize, m.name).toBeLessThanOrEqual(16);
		}
		if (blend.world) {
			const world = translateWorld(blend.world);
			expect(world.color.every(Number.isFinite)).toBe(true);
		}
	});
});
