import { beforeAll, describe, expect, it, vi } from 'vitest';
import { TinyBVH } from '../src/accel/TinyBVH';
import { mat4 } from '../src/math/Math';
import { RenderScene, type GeometryResource } from '../src/scene/RenderScene';
import { HostGpuScene, type PreparedHostScene } from '../src/render/HostGpuScene';

let bvh: TinyBVH;
beforeAll(async () => {
	vi.stubGlobal('GPUBufferUsage', { STORAGE: 128, COPY_DST: 8, COPY_SRC: 4 });
	bvh = await TinyBVH.create();
});

function fixture() {
	const writes: string[] = [];
	const device = {
		limits: { maxBufferSize: 1 << 24, maxStorageBufferBindingSize: 1 << 24 },
		createBuffer: ({ size, label }: GPUBufferDescriptor) => ({ size, label, memory: new Uint8Array(size), destroy: vi.fn() }),
		queue: { writeBuffer: (buffer: GPUBuffer & { memory: Uint8Array }, offset: number, bytes: Uint8Array) => {
			writes.push(buffer.label); buffer.memory.set(bytes, offset);
		} },
	} as unknown as GPUDevice;
	const gpu = new HostGpuScene(device, bvh);
	let last!: PreparedHostScene;
	const scene = new RenderScene(async (snapshot, changes) => {
		last = gpu.prepare(snapshot, changes, () => { throw new Error('Unexpected texture'); }, { descriptorOf: () => null, cpuTexture: () => null });
		last.publish();
	}, () => gpu.destroy());
	const triangle = (): GeometryResource => ({ positions: new Float32Array([0, 0, 0, 1, 0, 0, 0, 1, 0]), indices: new Uint32Array([0, 1, 2]) });
	const u = scene.beginUpdate(); const geometry = u.createGeometry(triangle()); const material = u.createMaterial({ baseColor: [1, 0, 0] });
	const first = u.addInstance({ geometry, materials: [material], worldMatrix: mat4.identity() });
	const second = u.addInstance({ geometry, materials: [material], worldMatrix: mat4.identity() });
	return { scene, gpu, u, geometry, material, first, second, writes, triangle, last: () => last };
}

function memory(buffer: GPUBuffer): Uint8Array { return (buffer as GPUBuffer & { memory: Uint8Array }).memory; }

describe('host GPU publication with real tinybvh', () => {
	it('shares raster clusters and follows sparse instance slots through updates and removal', async () => {
		const f = fixture(); await f.u.commit();
		const pairs = () => {
			const s = f.last().scene, words = new Uint32Array(memory(s.indices).buffer);
			return words.slice(s.visibilityOffset, s.visibilityOffset + s.visibilityCount * 2);
		};
		const before = pairs(); expect(before.length).toBe(4); expect(before[1]).toBe(before[3]);
		const moved = f.scene.beginUpdate(), matrix = mat4.identity(); matrix[12] = 2;
		moved.setInstanceTransform(f.first, matrix); await moved.commit();
		expect(pairs()).toEqual(before); expect(f.last().stats.blasBuilds).toBe(0);
		const remove = f.scene.beginUpdate(); remove.removeInstance(f.first); await remove.commit();
		expect(Array.from(pairs())).toEqual(Array.from(before.slice(2))); expect(f.last().scene.instanceSlots).toBeGreaterThan(before[2]);
		const replace = f.scene.beginUpdate(), geometry = f.triangle(); geometry.positions[0] = -3;
		replace.setGeometry(f.geometry, geometry); await replace.commit();
		const words = pairs(), floats = new Float32Array(memory(f.last().scene.indices).buffer);
		expect(floats[words[1]]).toBe(-3);
		const material = f.scene.beginUpdate(); material.setMaterial(f.material, { opacity: 0.5, alphaMode: 'mask' }); await material.commit();
		expect(f.last().scene.hasAlphaTested).toBe(true); expect(pairs()).toEqual(words);
		f.scene.dispose();
	});

	it('does not recompile or upload unrelated materials when an unused texture changes', async () => {
		const f = fixture(); await f.u.commit();
		const update = f.scene.beginUpdate();
		const texture = update.createTexture({ source: { width: 1, height: 1, data: new Uint8Array([1, 2, 3, 255]) }, colorSpace: 'linear' });
		await update.commit();
		expect(f.last().stats.materialCompiles).toBe(0);
		expect(Object.values(f.last().stats.uploadedBytes).every(bytes => bytes === 0)).toBe(true);
		const release = f.scene.beginUpdate(); release.releaseTexture(texture); await release.commit();
		expect(f.last().stats.materialCompiles).toBe(0);
		expect(f.last().stats.tlasBuilds).toBe(0);
		f.scene.dispose();
	});

	it('builds one shared BLAS, then only updates TLAS and one record when moving an instance', async () => {
		const f = fixture(); await f.u.commit();
		expect(f.last().stats.blasBuilds).toBe(1); expect(f.last().stats.tlasBuilds).toBe(1);
		const geometryBuffer = f.last().scene.vertices, blasBuffer = f.last().scene.tris;
		const u = f.scene.beginUpdate(), m = mat4.identity(); m[12] = 10; u.setInstanceTransform(f.second, m); await u.commit();
		const { stats, scene } = f.last();
		expect(stats.blasBuilds).toBe(0); expect(stats.tlasBuilds).toBe(1); expect(stats.materialCompiles).toBe(0);
		expect(stats.uploadedBytes.vertices).toBe(0); expect(stats.uploadedBytes.tris).toBe(0); expect(stats.uploadedBytes.materials).toBe(0);
		expect(stats.uploadedBytes.instances).toBe(128); expect(stats.uploadedBytes.lights).toBe(0);
		expect(scene.vertices).toBe(geometryBuffer); expect(scene.tris).toBe(blasBuffer);
		expect(scene.boundsMax[0]).toBe(11);
		expect(new Float32Array(memory(scene.instances).buffer)[32 + 3]).toBe(10);
		f.scene.dispose();
	});

	it('does not rebuild acceleration for a material edit or shading-only attributes', async () => {
		const f = fixture(); await f.u.commit();
		const u = f.scene.beginUpdate(); u.setMaterial(f.material, { metallic: 1, roughness: 0.25 }); await u.commit();
		expect(f.last().stats.blasBuilds).toBe(0); expect(f.last().stats.tlasBuilds).toBe(0);
		expect(f.last().stats.uploadedBytes.nodes).toBe(0); expect(f.last().stats.uploadedBytes.vertices).toBe(0);
		expect(f.last().stats.uploadedBytes.materials).toBeGreaterThan(0);
		const attrs = f.scene.beginUpdate(); attrs.updateGeometryAttributes(f.geometry, { uv0: new Float32Array([0, 0, 1, 0, 0, 1]) }); await attrs.commit();
		expect(f.last().stats.blasBuilds).toBe(0); expect(f.last().stats.tlasBuilds).toBe(0);
		expect(f.last().stats.uploadedBytes.vertices).toBe(3 * 64); expect(f.last().stats.uploadedBytes.tris).toBe(0);
		f.scene.dispose();
	});

	it('rebuilds only the changed BLAS and updates every shared instance bound', async () => {
		const f = fixture(); const other = f.u.createGeometry(f.triangle());
		f.u.addInstance({ geometry: other, materials: [f.material], worldMatrix: mat4.identity() }); await f.u.commit();
		const u = f.scene.beginUpdate(); const positions = f.triangle().positions; positions[3] = 5;
		u.updateGeometryAttributes(f.geometry, { positions }); await u.commit();
		expect(f.last().stats.blasBuilds).toBe(1); expect(f.last().stats.tlasBuilds).toBe(1);
		expect(f.last().scene.boundsMax[0]).toBe(5);
		expect(f.last().stats.uploadedBytes.vertices).toBe(192);
		f.scene.dispose();
	});

	it('supports holes in instance slots and independent TLAS storage', async () => {
		const f = fixture(); await f.u.commit();
		const firstScene = f.last().scene;
		expect(firstScene.tlasNodeOffset).toBeGreaterThan(0);
		const u = f.scene.beginUpdate(); u.removeInstance(f.first); await u.commit();
		const s = f.last().scene;
		expect(s.instanceCount).toBe(1); expect(f.last().stats.blasBuilds).toBe(0);
		const indices = new Uint32Array(memory(s.indices).buffer);
		expect(indices[s.tlasPrimOffset]).toBe(1); // active input zero maps to stable GPU slot one
		f.scene.dispose();
	});

	it('updates emissive geometry and distribution in the same commit', async () => {
		const f = fixture(); f.u.setMaterial(f.material, { emission: [2, 2, 2] }); await f.u.commit();
		expect(f.last().scene.lightCount).toBe(2);
		const u = f.scene.beginUpdate(), m = mat4.identity(); m[0] = 2; m[5] = 2; m[12] = 3;
		u.setInstanceTransform(f.first, m); await u.commit();
		const lights = new Float32Array(memory(f.last().scene.lights).buffer);
		expect(lights[0]).toBe(3); expect(lights[3]).toBe(2);
		expect(lights[7]).toBeCloseTo(0.8); expect(lights[32 + 7]).toBeCloseTo(0.2);
		expect(f.last().stats.blasBuilds).toBe(0);
		f.scene.dispose();
	});

	it('shares each geometry group across instances with different material bindings', async () => {
		const f = fixture();
		const g = f.triangle(); g.indices = new Uint32Array([0, 1, 2, 2, 1, 0]);
		g.groups = [{ firstIndex: 0, indexCount: 3, materialSlot: 0 }, { firstIndex: 3, indexCount: 3, materialSlot: 1 }];
		f.u.setGeometry(f.geometry, g);
		const blue = f.u.createMaterial({ baseColor: [0, 0, 1] });
		f.u.setInstanceMaterials(f.first, [f.material, blue]); f.u.setInstanceMaterials(f.second, [blue, f.material]);
		await f.u.commit();
		expect(f.last().stats.blasBuilds).toBe(2); expect(f.last().scene.instanceCount).toBe(4);
		const instances = new Uint32Array(memory(f.last().scene.instances).buffer);
		expect(instances[24]).toBe(instances[64 + 24]); // same group BLAS
		expect(instances[28]).not.toBe(instances[64 + 28]); // distinct material
		f.scene.dispose();
	});
});
