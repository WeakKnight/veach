import { describe, expect, it, vi } from 'vitest';
import { mat4 } from '../src/math/Math';
import { RenderScene, type GeometryResource, type SceneChanges, type SceneSnapshot } from '../src/scene/RenderScene';

function triangle(): GeometryResource {
	return { positions: new Float32Array([0, 0, 0, 1, 0, 0, 0, 1, 0]), indices: new Uint32Array([0, 1, 2]) };
}

function fixture() {
	let snapshot!: SceneSnapshot;
	let changes!: SceneChanges;
	const scene = new RenderScene(async (s, c) => { snapshot = s; changes = c; });
	const update = scene.beginUpdate();
	const geometry = update.createGeometry(triangle());
	const material = update.createMaterial({ roughness: 0.5 });
	const instance = update.addInstance({ geometry, materials: [material], worldMatrix: mat4.identity() });
	return { scene, update, geometry, material, instance, snapshot: () => snapshot, changes: () => changes };
}

describe('persistent render scene', () => {
	it('shares geometry and material; transforms do not dirty resources', async () => {
		const f = fixture();
		const second = f.update.addInstance({ geometry: f.geometry, materials: [f.material], worldMatrix: mat4.identity() });
		await f.update.commit();
		const firstGeometry = f.snapshot().geometries.get(f.geometry);
		const u = f.scene.beginUpdate();
		const transform = mat4.identity(); transform[12] = 10;
		u.setInstanceTransform(second, transform);
		await u.commit();
		expect(f.scene.stats).toEqual({ geometries: 1, textures: 0, materials: 1, instances: 2, lights: 0 });
		expect(f.snapshot().geometries.get(f.geometry)).toBe(firstGeometry);
		expect(f.changes().geometries.size).toBe(0);
		expect(f.changes().materials.size).toBe(0);
		expect([...f.changes().instances]).toEqual([second]);
		expect(f.snapshot().instances.get(second)?.worldMatrix[12]).toBe(10);
	});

	it('snapshots application arrays and small values without retaining mutable aliases', async () => {
		let snapshot!: SceneSnapshot;
		const scene = new RenderScene(async s => { snapshot = s; });
		const u = scene.beginUpdate();
		const source = triangle();
		const g = u.createGeometry(source);
		const pixels = new Uint8Array([255, 0, 0, 255]);
		const t = u.createTexture({ source: { width: 1, height: 1, data: pixels }, colorSpace: 'srgb' });
		const color: [number, number, number] = [1, 0, 0];
		const m = u.createMaterial({ baseColor: color, baseColorMap: { texture: t } });
		const transform = mat4.identity();
		const i = u.addInstance({ geometry: g, materials: [m], worldMatrix: transform });
		source.positions[0] = 99; pixels[0] = 0; color[0] = 0; transform[12] = 99;
		await u.commit();
		expect(snapshot.geometries.get(g)?.positions[0]).toBe(0);
		expect(snapshot.materials.get(m)?.baseColor?.[0]).toBe(1);
		expect(snapshot.instances.get(i)?.worldMatrix[12]).toBe(0);
		const texture = snapshot.textures.get(t)!.source;
		expect('data' in texture && texture.data[0]).toBe(255);
	});

	it('validates final references and preserves the last committed scene after rejection', async () => {
		const f = fixture(); await f.update.commit();
		const bad = f.scene.beginUpdate(); bad.releaseGeometry(f.geometry);
		await expect(bad.commit()).rejects.toThrow('geometry handle');
		expect(f.scene.revision).toBe(1);
		expect(f.scene.stats.geometries).toBe(1);
		const good = f.scene.beginUpdate();
		good.releaseGeometry(f.geometry); good.releaseMaterial(f.material); good.removeInstance(f.instance);
		await good.commit();
		expect(f.scene.stats.instances).toBe(0);
		expect(f.scene.stats.geometries).toBe(0);
	});

	it('does not release a resource used by another instance', async () => {
		const f = fixture();
		f.update.addInstance({ geometry: f.geometry, materials: [f.material], worldMatrix: mat4.identity() });
		await f.update.commit();
		const u = f.scene.beginUpdate(); u.removeInstance(f.instance); u.releaseMaterial(f.material);
		await expect(u.commit()).rejects.toThrow('material handle');
		expect(f.scene.stats.instances).toBe(2);
	});

	it('rejects cross-scene and released handles', async () => {
		const f = fixture(); await f.update.commit();
		const other = new RenderScene();
		const u = other.beginUpdate();
		u.addInstance({ geometry: f.geometry, materials: [f.material], worldMatrix: mat4.identity() });
		await expect(u.commit()).rejects.toThrow('geometry handle');
		const release = f.scene.beginUpdate(); release.removeInstance(f.instance); await release.commit();
		const next = f.scene.beginUpdate();
		expect(() => next.setInstanceEnabled(f.instance, true)).toThrow('instance handle'); next.cancel();
	});

	it('distinguishes shading attributes from position updates', async () => {
		const f = fixture(); await f.update.commit();
		const uv = f.scene.beginUpdate(); uv.updateGeometryAttributes(f.geometry, { uv0: new Float32Array(6) }); await uv.commit();
		expect(f.changes().geometries.has(f.geometry)).toBe(true);
		expect(f.changes().geometryBounds.size).toBe(0);
		const positions = f.scene.beginUpdate(); positions.updateGeometryAttributes(f.geometry, { positions: triangle().positions }); await positions.commit();
		expect(f.changes().geometryBounds.has(f.geometry)).toBe(true);
	});

	it('serializes commits and permits retry after backend preparation failure', async () => {
		let complete!: () => void;
		const apply = vi.fn(() => new Promise<void>(resolve => { complete = resolve; }));
		const scene = new RenderScene(apply);
		const u = scene.beginUpdate(); u.createMaterial({});
		const pending = u.commit();
		expect(() => scene.beginUpdate()).toThrow('already active');
		expect(() => u.createMaterial({})).toThrow('closed');
		expect(scene.revision).toBe(0);
		complete(); await pending;
		apply.mockRejectedValueOnce(new Error('pipeline failed'));
		const bad = scene.beginUpdate(); bad.createMaterial({});
		await expect(bad.commit()).rejects.toThrow('pipeline failed');
		expect(scene.stats.materials).toBe(1);
		scene.beginUpdate().cancel();
	});

	it('rejects invalid geometry, transforms and missing material slots', async () => {
		const scene = new RenderScene(); const u = scene.beginUpdate();
		expect(() => u.createGeometry({ ...triangle(), indices: new Uint32Array([0, 1, 9]) })).toThrow('outside');
		const g = u.createGeometry({ ...triangle(), groups: [{ firstIndex: 0, indexCount: 3, materialSlot: 1 }] });
		const m = u.createMaterial({});
		expect(() => u.addInstance({ geometry: g, materials: [m], worldMatrix: new Float32Array(16) })).toThrow('invertible');
		u.addInstance({ geometry: g, materials: [m], worldMatrix: mat4.identity() });
		await expect(u.commit()).rejects.toThrow('material slot');
	});

	it('empty commits are no-ops and disposal is idempotent', async () => {
		const apply = vi.fn(async () => {}), dispose = vi.fn();
		const scene = new RenderScene(apply, dispose);
		await scene.beginUpdate().commit();
		expect(apply).not.toHaveBeenCalled();
		expect(scene.revision).toBe(0);
		scene.dispose(); scene.dispose();
		expect(dispose).toHaveBeenCalledOnce();
		expect(() => scene.beginUpdate()).toThrow('disposed');
	});
});
