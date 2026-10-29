import { describe, expect, it } from 'vitest';
import * as THREE from 'three';
import { ThreeAdapter } from '../src/three/ThreeAdapter';
import { RenderScene, type SceneChanges, type SceneSnapshot } from '../src/scene/RenderScene';

function fixture() {
	const commits: { scene: SceneSnapshot; changes: SceneChanges }[] = [];
	let reject = false;
	const adapter = new ThreeAdapter({ createScene: () => new RenderScene(async (scene, changes) => {
		if (reject) throw new Error('prepare failed'); commits.push({ scene, changes });
	}) });
	const root = new THREE.Scene(), geometry = new THREE.BoxGeometry(), material = new THREE.MeshStandardMaterial();
	const a: THREE.Mesh = new THREE.Mesh(geometry, material), b: THREE.Mesh = new THREE.Mesh(geometry, material); root.add(a, b);
	return { adapter, root, geometry, material, a, b, commits, last: () => commits.at(-1)!, reject: (v: boolean) => { reject = v; } };
}

describe('Three.js adapter synchronization', () => {
	it('shares resources, snapshots small properties and releases only last references', async () => {
		const f = fixture(); await f.adapter.sync(f.root);
		expect(f.adapter.scene.stats).toMatchObject({ geometries: 1, materials: 1, instances: 2 });
		expect([...f.last().scene.geometries.values()][0].groups).toBeUndefined();
		await f.adapter.sync(f.root); expect(f.commits).toHaveLength(1);
		f.a.position.x = 2; await f.adapter.sync(f.root);
		expect(f.last().changes.instances.size).toBe(1); expect(f.last().changes.geometries.size).toBe(0);
		f.material.roughness = 0.1; await f.adapter.sync(f.root);
		expect(f.last().changes.materials.size).toBe(1); expect(f.last().changes.geometryBounds.size).toBe(0);
		f.root.remove(f.a); await f.adapter.sync(f.root); expect(f.adapter.scene.stats.geometries).toBe(1);
		f.root.remove(f.b); await f.adapter.sync(f.root); expect(f.adapter.scene.stats).toMatchObject({ geometries: 0, materials: 0, textures: 0, instances: 0 });
	});

	it('uses attribute versions; UV changes never dirty bounds; position replacements do', async () => {
		const f = fixture(); await f.adapter.sync(f.root);
		const uv = f.geometry.getAttribute('uv'); uv.setX(0, 0.7);
		await f.adapter.sync(f.root); expect(f.commits).toHaveLength(1);
		uv.needsUpdate = true; await f.adapter.sync(f.root);
		expect(f.last().changes.geometries.size).toBe(1); expect(f.last().changes.geometryBounds.size).toBe(0);
		f.geometry.setAttribute('position', f.geometry.getAttribute('position').clone()); await f.adapter.sync(f.root);
		expect(f.last().changes.geometryBounds.size).toBe(1);
		f.geometry.setDrawRange(0, 3); await f.adapter.sync(f.root);
		expect([...f.last().scene.geometries.values()][0].indices).toHaveLength(3);
	});

	it('tracks interleaved buffer versions without mutating the host', async () => {
		const f = fixture();
		const data = new THREE.InterleavedBuffer(new Float32Array([0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]), 5);
		const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.InterleavedBufferAttribute(data, 3, 0)); g.setAttribute('uv', new THREE.InterleavedBufferAttribute(data, 2, 3));
		f.a.geometry = g; f.root.remove(f.b); await f.adapter.sync(f.root);
		data.array[0] = 2; data.needsUpdate = true; await f.adapter.sync(f.root);
		expect([...f.last().scene.geometries.values()][0].positions[0]).toBe(2);
		expect(g.index).toBeNull();
	});

	it('updates texture bytes only on version, detects transforms, preserves scalar channels', async () => {
		const f = fixture(), texture = new THREE.DataTexture(new Uint8Array([255, 0, 0, 255, 0, 255, 0, 255]), 1, 2);
		texture.flipY = true; f.material.map = texture; f.material.alphaMap = texture; await f.adapter.sync(f.root);
		const source = [...f.last().scene.textures.values()][0].source;
		expect('data' in source && [...source.data.slice(0, 4)]).toEqual([0, 255, 0, 255]);
		texture.offset.x = 0.25; await f.adapter.sync(f.root);
		expect(f.last().changes.textures.size).toBe(0); expect(f.last().changes.materials.size).toBe(1);
		const m = [...f.last().scene.materials.values()][0]; expect(m.baseColorMap?.offset?.[0]).toBe(0.25); expect(m.opacityMap?.channel).toBe(1);
		texture.image.data![0] = 42; texture.needsUpdate = true; await f.adapter.sync(f.root);
		expect(f.last().changes.textures.size).toBe(1);
		f.material.map = null; f.material.alphaMap = null; await f.adapter.sync(f.root); expect(f.adapter.scene.stats.textures).toBe(0);
	});

	it('commits snapshots only on success, rejects overlapping sync and retries failed preparation', async () => {
		const f = fixture(); await f.adapter.sync(f.root); f.material.color.setHex(0xff0000); f.reject(true);
		await expect(f.adapter.sync(f.root)).rejects.toThrow('prepare failed'); expect(f.adapter.scene.revision).toBe(1);
		f.reject(false); const pending = f.adapter.sync(f.root);
		await expect(f.adapter.sync(f.root)).rejects.toThrow('previous sync'); await pending;
		expect(f.last().changes.materials.size).toBe(1); expect([...f.last().scene.materials.values()][0].baseColor).toEqual([1, 0, 0]);
	});

	it('synchronizes parent visibility, camera layers, instanced transforms and count', async () => {
		const f = fixture(), group = new THREE.Group(); f.root.clear(); f.root.add(group);
		const mesh = new THREE.InstancedMesh(f.geometry, f.material, 3); group.add(mesh);
		mesh.setMatrixAt(1, new THREE.Matrix4().makeTranslation(3, 0, 0)); const camera = new THREE.PerspectiveCamera();
		await f.adapter.sync(f.root, camera); expect(f.adapter.scene.stats.instances).toBe(3);
		group.visible = false; await f.adapter.sync(f.root, camera); expect([...f.last().scene.instances.values()].every(i => i.enabled === false)).toBe(true);
		group.visible = true; mesh.count = 1; mesh.layers.set(1); await f.adapter.sync(f.root, camera);
		expect(f.adapter.scene.stats.instances).toBe(1); expect([...f.last().scene.instances.values()][0].enabled).toBe(false);
		camera.layers.enable(1); await f.adapter.sync(f.root, camera); expect([...f.last().scene.instances.values()][0].enabled).toBe(true);
	});

	it('handles material arrays separately from single material geometry semantics', async () => {
		const f = fixture(); f.b.material = Array.from({ length: 6 }, () => f.material);
		await f.adapter.sync(f.root); expect(f.adapter.scene.stats.geometries).toBe(2);
		const grouped = [...f.last().scene.geometries.values()].find(g => g.groups); expect(grouped?.groups).toHaveLength(6);
		f.b.material = f.material; await f.adapter.sync(f.root); expect(f.adapter.scene.stats.geometries).toBe(1);
	});

	it('reports unsupported features and can sync again after a validation error', async () => {
		const f = fixture(); f.material.vertexColors = true;
		await expect(f.adapter.sync(f.root)).rejects.toThrow('Unsupported material feature');
		f.material.vertexColors = false; await f.adapter.sync(f.root);
		f.root.add(new THREE.PointLight()); await expect(f.adapter.sync(f.root)).rejects.toThrow('light conversion');
		f.adapter.dispose(); await expect(f.adapter.sync(f.root)).rejects.toThrow('disposed');
	});
});
