import { BuildQuality, BVH_NODE_BYTES, BVH_TRI_FLOATS, type BLASData, type TinyBVH } from '../accel/TinyBVH';
import { compileMaterial, type CompiledMaterial } from '../material/Compile';
import { hostMaterialGraph, type HostTextureResolver } from '../material/HostMaterial';
import { luminance, mat4, vec3, type Vec3 } from '../math/Math';
import type { GeometryHandle, GeometryResource, MaterialHandle, SceneChanges, SceneSnapshot } from '../scene/RenderScene';
import { GpuScene } from './GpuScene';
import { INSTANCE_BYTES, VERTEX_BYTES, LIGHT_BYTES, INSTANCE_FLAG_ALPHA_TESTED, INSTANCE_FLAG_EMISSIVE,
	packVertices, packInstance, packMaterialData, packAnalyticLight } from './GpuLayout';
import { materialLightCapacity, materialShadeCapacities, materialStackCapacity } from './MaterialCapacity';
import { materialOpcodeMask } from './MaterialProgramFeatures';
import { emissionLuminance } from './SceneMaterials';
import { StorageArena, type PreparedStorage } from './StorageArena';
import type { CpuTexture } from './vt/TileSource';
import type { VirtualTextureDescriptor } from './vt/VirtualTextureSystem';

interface GeometryPart { key: string; materialSlot: number; firstIndex: number; indices: Uint32Array; blas: BLASData }
interface GeometryState { desc: GeometryResource; parts: GeometryPart[] }
interface Draw {
	key: string; geometry: GeometryResource; part: GeometryPart; world: Float32Array;
	material: CompiledMaterial; materialIndex: number; slot: number;
}
export interface HostTextureAccess {
	descriptorOf(source: number): VirtualTextureDescriptor | null;
	cpuTexture(source: number): CpuTexture | null;
}
export interface HostGpuUpdateStats {
	blasBuilds: number;
	tlasBuilds: number;
	materialCompiles: number;
	uploadedBytes: Record<string, number>;
	bufferGrowths: number;
}
export interface PreparedHostScene {
	scene: GpuScene;
	stats: HostGpuUpdateStats;
	publish(): void;
	discard(): void;
}

const names = ['nodes', 'tris', 'instances', 'vertices', 'indices', 'materials', 'lights'] as const;
type ArenaName = typeof names[number];
function equal(a: ArrayLike<number>, b: ArrayLike<number>): boolean {
	if (a.length !== b.length) return false;
	for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
	return true;
}
const sameDrawBounds = (a: Draw, b: Draw) => a.slot === b.slot && a.part.blas === b.part.blas && equal(a.world, b.world);
const sameEmitter = (a: Draw, b: Draw) => sameDrawBounds(a, b) && a.geometry === b.geometry && a.material === b.material && a.materialIndex === b.materialIndex;

/** Incremental GPU publication. A geometry group is one BLAS, shared by every instance using it. */
export class HostGpuScene {
	private readonly arenas: Record<ArenaName, StorageArena>;
	private geometries = new Map<GeometryHandle, GeometryState>();
	private materials = new Map<MaterialHandle, CompiledMaterial>();
	private draws: Draw[] = [];
	private emitters: Draw[] = [];
	private lightOffsets = new Map<string, number>();
	private lightCount = 0;
	private analyticCount = 0;
	private emissiveCount = 0;
	private tlasNodes = 0;
	private previous: SceneSnapshot | null = null;
	private destroyed = false;

	constructor(device: GPUDevice, private readonly bvh: TinyBVH, private readonly quality = BuildQuality.Fast) {
		this.arenas = Object.fromEntries(names.map(name => [name, new StorageArena(device, `host:${name}`,
			name === 'nodes' ? BVH_NODE_BYTES : name === 'instances' ? INSTANCE_BYTES : name === 'vertices' ? VERTEX_BYTES : name === 'materials' ? 32 : name === 'tris' ? BVH_TRI_FLOATS * 4 : 16)])) as Record<ArenaName, StorageArena>;
	}

	prepare(snapshot: SceneSnapshot, changes: SceneChanges, resolveTexture: HostTextureResolver, textures: HostTextureAccess): PreparedHostScene {
		if (this.destroyed) throw new Error('GPU scene is destroyed');
		const start = performance.now();
		const plans = Object.fromEntries(names.map(name => [name, this.arenas[name].plan()])) as Record<ArenaName, ReturnType<StorageArena['plan']>>;
		const geometries = new Map(this.geometries), materials = new Map(this.materials);
		const stats: HostGpuUpdateStats = { blasBuilds: 0, tlasBuilds: 0, materialCompiles: 0, uploadedBytes: {}, bufferGrowths: 0 };

		for (const id of changes.geometries) {
			const old = geometries.get(id), desc = snapshot.geometries.get(id), key = String(id);
			if (!desc) {
				plans.vertices.delete(key); plans.indices.delete(key);
				for (const part of old?.parts ?? []) { plans.nodes.delete(part.key); plans.tris.delete(part.key); }
				geometries.delete(id); continue;
			}
			const vertices = new Float32Array(desc.positions.length / 3 * VERTEX_BYTES / 4);
			packVertices(vertices, 0, desc.positions, desc.normals ?? null, desc.tangents ?? null, desc.uv0 ?? null, desc.uv1 ?? null);
			plans.vertices.set(key, vertices);
			if (!old || changes.geometryBounds.has(id)) {
				plans.indices.set(key, desc.indices);
				const groups = desc.groups?.length ? desc.groups : [{ firstIndex: 0, indexCount: desc.indices.length, materialSlot: 0 }];
				const parts = groups.map((g, i) => {
					const partKey = `geometry:${id}:${i}`;
					const indices = desc.indices.subarray(g.firstIndex, g.firstIndex + g.indexCount);
					const blas = this.bvh.buildBLAS(desc.positions, indices, this.quality); stats.blasBuilds++;
					plans.nodes.set(partKey, blas.nodes); plans.tris.set(partKey, blas.tris);
					return { key: partKey, materialSlot: g.materialSlot, firstIndex: g.firstIndex, indices, blas };
				});
				for (const part of old?.parts ?? []) if (!parts.some(p => p.key === part.key)) { plans.nodes.delete(part.key); plans.tris.delete(part.key); }
				geometries.set(id, { desc, parts });
			} else geometries.set(id, { desc, parts: old.parts });
		}

		for (const id of changes.materials) if (!snapshot.materials.has(id)) { materials.delete(id); plans.materials.delete(String(id)); }
		for (const [id, desc] of snapshot.materials) {
			// Texture color interpretation can change without changing the material descriptor.
			const textureChanged = (['baseColorMap', 'metallicMap', 'roughnessMap', 'normalMap', 'emissionMap', 'opacityMap'] as const)
				.some(key => desc[key] && changes.textures.has(desc[key].texture));
			if (!materials.has(id) || changes.materials.has(id) || textureChanged) {
				materials.set(id, compileMaterial(hostMaterialGraph(desc, resolveTexture))); stats.materialCompiles++;
			}
		}
		const compiled = [...materials.values()];
		const capacities = materialShadeCapacities(compiled);
		const oldLightFloor = Math.max(0, ...[...this.materials.values()].filter(m => m.emissive).map(materialLightCapacity));
		const lightFloor = Math.max(0, ...compiled.filter(m => m.emissive).map(materialLightCapacity));
		let materialOrdinal = 0;
		for (const [id, material] of materials) {
			const capacity = capacities[materialOrdinal++];
			if (this.materials.get(id) === material && oldLightFloor === lightFloor) continue;
			const data = packMaterialData([material], textures.descriptorOf.bind(textures));
			const block = plans.materials.set(String(id), data), base = block.offset / 16;
			for (let i = 0; i < 3; i++) if (data[i] !== 0xffffffff) data[i] += base;
			data[4] += base; data[5] += base;
			data[3] = (data[3] & ~(31 << 16)) | (capacity << 16);
			plans.materials.set(String(id), data);
		}

		const draws: Draw[] = [];
		for (const [id, instance] of snapshot.instances) {
			if (instance.enabled === false) continue;
			const g = geometries.get(instance.geometry)!;
			for (const part of g.parts) {
				const key = `${id}:${part.key}`;
				const block = plans.instances.get(key) ?? plans.instances.set(key, new Uint8Array(INSTANCE_BYTES));
				const materialId = instance.materials[part.materialSlot];
				draws.push({ key, geometry: g.desc, part, world: instance.worldMatrix,
					material: materials.get(materialId)!, materialIndex: plans.materials.get(String(materialId))!.offset / 32,
					slot: block.offset / INSTANCE_BYTES });
			}
		}
		const active = new Set(draws.map(d => d.key));
		for (const old of this.draws) if (!active.has(old.key)) plans.instances.delete(old.key);
		const accelerationChanged = draws.length !== this.draws.length || draws.some((d, i) => !sameDrawBounds(d, this.draws[i]));
		let boundsMin: Vec3 = [Infinity, Infinity, Infinity], boundsMax: Vec3 = [-Infinity, -Infinity, -Infinity];
		const aabbs = accelerationChanged ? new Float32Array(draws.length * 8) : null;
		for (let i = 0; i < draws.length; i++) {
			const d = draws[i], box = mat4.transformAABB(d.world, d.part.blas.boundsMin, d.part.blas.boundsMax);
			boundsMin = vec3.min(boundsMin, box.min); boundsMax = vec3.max(boundsMax, box.max);
			aabbs?.set([...box.min, 0, ...box.max, 0], i * 8);
		}
		let tlasNodes = this.tlasNodes;
		if (accelerationChanged) {
			if (draws.length) {
				const tlas = this.bvh.buildTLAS(aabbs!); stats.tlasBuilds++; tlasNodes = tlas.nodeCount;
				plans.nodes.set('tlas', tlas.nodes);
				plans.indices.set('tlas', Uint32Array.from(tlas.primIndices, i => draws[i].slot));
			} else { plans.nodes.delete('tlas'); plans.indices.delete('tlas'); tlasNodes = 0; }
		}

		const emitters = draws.filter(d => d.material.emissive);
		const lightsChanged = !this.previous || changes.lights.size > 0
			|| emitters.length !== this.emitters.length || emitters.some((d, i) => !sameEmitter(d, this.emitters[i]));
		let lightOffsets = this.lightOffsets, lightCount = this.lightCount, analyticCount = this.analyticCount, emissiveCount = this.emissiveCount;
		if (lightsChanged) {
			const result = packHostLights(snapshot, emitters, textures);
			lightOffsets = result.offsets; lightCount = result.count; analyticCount = result.analytic; emissiveCount = result.emissive;
			plans.lights.set('lights', result.data);
		}

		for (const d of draws) {
			const geometryId = Number(d.part.key.split(':')[1]);
			const data = new ArrayBuffer(INSTANCE_BYTES);
			const offset = lightOffsets.get(d.key);
			packInstance(data, 0, {
				objectToWorld: d.world, worldToObject: mat4.invert(d.world)!,
				blasNodeOffset: plans.nodes.get(d.part.key)!.offset / BVH_NODE_BYTES,
				blasTriOffset: plans.tris.get(d.part.key)!.offset / (BVH_TRI_FLOATS * 4),
				vertexOffset: plans.vertices.get(String(geometryId))!.offset / VERTEX_BYTES,
				indexOffset: plans.indices.get(String(geometryId))!.offset / 4 + d.part.firstIndex,
				materialIndex: d.materialIndex,
				flags: (d.material.alphaTested ? INSTANCE_FLAG_ALPHA_TESTED : 0) | (offset === undefined ? 0 : INSTANCE_FLAG_EMISSIVE),
				lightOffset: offset ?? 0, triCount: d.part.indices.length / 3,
			});
			const previous = plans.instances.get(d.key)!;
			if (!equal(previous.bytes, new Uint8Array(data))) plans.instances.set(d.key, data);
		}

		const scene = new GpuScene();
		scene.instanceCount = draws.length;
		scene.lightCount = lightCount; scene.analyticLightCount = analyticCount;
		scene.tlasPrimOffset = (plans.indices.get('tlas')?.offset ?? 0) / 4;
		scene.tlasNodeOffset = (plans.nodes.get('tlas')?.offset ?? 0) / BVH_NODE_BYTES;
		scene.boundsMin = draws.length ? boundsMin : [0, 0, 0]; scene.boundsMax = draws.length ? boundsMax : [0, 0, 0];
		scene.hasAlphaTested = draws.some(d => d.material.alphaTested);
		scene.materialStackSize = Math.max(0, ...compiled.map(m => m.stackSize));
		scene.materialSurfaceCapacity = materialStackCapacity(Math.max(0, ...compiled.map(m => m.programStackSizes.surface)));
		scene.materialOpacityCapacity = materialStackCapacity(Math.max(0, ...compiled.map(m => m.programStackSizes.opacity)));
		scene.materialLightCapacity = materialStackCapacity(lightFloor);
		scene.materialShadeCapacities = [...new Set(draws.map(d => materialStackCapacity(Math.max(d.material.programStackSizes.surface, lightFloor))))].sort((a, b) => a - b);
		scene.materialSurfaceCapacities = [...new Set(draws.map(d => materialStackCapacity(d.material.programStackSizes.surface)))].sort((a, b) => a - b);
		scene.materialOpcodes = materialOpcodeMask(compiled);
		scene.materialCount = Math.max(0, ...[...materials.keys()].map(id => plans.materials.get(String(id))!.offset / 32 + 1));
		scene.stats = { meshes: geometries.size, instances: draws.length, triangles: draws.reduce((n, d) => n + d.part.indices.length / 3, 0),
			emissiveTriangles: emissiveCount, analyticLights: analyticCount,
			bvhNodes: tlasNodes + [...geometries.values()].reduce((n, g) => n + g.parts.reduce((s, p) => s + p.blas.nodeCount, 0), 0), buildMs: performance.now() - start };
		const prepared: PreparedStorage[] = [];
		try {
			for (const name of names) {
				const p = plans[name].prepare(); prepared.push(p); scene[name] = p.buffer;
				stats.uploadedBytes[name] = p.uploadedBytes; if (p.grew) stats.bufferGrowths++;
			}
		} catch (error) { for (const p of prepared) p.discard(); throw error; }
		let done = false;
		return {
			scene, stats,
			publish: () => {
				if (done || this.destroyed) throw new Error('GPU scene publication is no longer valid');
				for (const p of prepared) p.publish();
				this.geometries = geometries; this.materials = materials; this.draws = draws; this.emitters = emitters;
				this.lightOffsets = lightOffsets; this.lightCount = lightCount; this.analyticCount = analyticCount; this.emissiveCount = emissiveCount;
				this.tlasNodes = tlasNodes; this.previous = snapshot; done = true;
			},
			discard: () => { if (!done) { for (const p of prepared) p.discard(); done = true; } },
		};
	}

	destroy(): void { this.destroyed = true; for (const arena of Object.values(this.arenas)) arena.destroy(); this.geometries.clear(); this.materials.clear(); this.draws = []; this.emitters = []; this.previous = null; }
}

// Keep primitive order inside every emitting draw: MIS uses lightOffset + primitiveIndex.
function packHostLights(snapshot: SceneSnapshot, emitters: Draw[], textures: HostTextureAccess) {
	const triangles: { draw: Draw; p: Vec3[]; normal: Vec3; area: number; power: number; uv: number[] }[] = [];
	const offsets = new Map<string, number>();
	const analytic = [...snapshot.lights.values()].map(light => ({ light, power: luminance(...light.power) / Math.PI })).filter(l => l.power > 0);
	const weights = [[1, 0, 0], [0, 1, 0], [0, 0, 1], [0.5, 0.5, 0], [0, 0.5, 0.5], [0.5, 0, 0.5], [1 / 3, 1 / 3, 1 / 3]];
	for (const draw of emitters) {
		const { geometry: g, part } = draw;
		const emission = emissionLuminance(draw.material, s => textures.cpuTexture(s));
		if (!emission) continue;
		offsets.set(draw.key, analytic.length + triangles.length);
		for (let t = 0; t < part.indices.length; t += 3) {
			const v = [part.indices[t], part.indices[t + 1], part.indices[t + 2]];
			const local = v.map(i => [g.positions[i * 3], g.positions[i * 3 + 1], g.positions[i * 3 + 2]] as Vec3);
			const p = local.map(q => mat4.transformPoint(draw.world, q));
			const cross = vec3.cross(vec3.sub(p[1], p[0]), vec3.sub(p[2], p[0])), length = vec3.length(cross), area = length / 2;
			const uv = [g.uv0, g.uv1].flatMap(set => v.flatMap(i => [set?.[i * 2] ?? 0, set?.[i * 2 + 1] ?? 0]));
			const interp = (values: number[], weight: number[], stride: number, lane: number) => weight.reduce((s, w, i) => s + w * values[i * stride + lane], 0);
			const power = area * weights.reduce((sum, w) => sum + emission(
				[interp(uv, w, 2, 0), interp(uv, w, 2, 1)],
				[interp(uv.slice(6), w, 2, 0), interp(uv.slice(6), w, 2, 1)],
				[0, 1, 2].map(c => local.reduce((s, q, i) => s + q[c] * w[i], 0)) as Vec3), 0) / weights.length;
			triangles.push({ draw, p, normal: length > 0 ? vec3.scale(cross, 1 / length) : [0, 1, 0], area, power, uv });
		}
	}
	const trianglePower = triangles.reduce((s, t) => s + t.power, 0);
	if (!(trianglePower > 0)) { triangles.length = 0; offsets.clear(); }
	const total = analytic.reduce((s, a) => s + a.power, 0) + trianglePower, count = analytic.length + triangles.length;
	const data = new ArrayBuffer(Math.max(count, 1) * LIGHT_BYTES), f32 = new Float32Array(data), u32 = new Uint32Array(data);
	let cdf = 0;
	const advance = (i: number, power: number) => { const pdf = power / total; cdf = i === count - 1 ? 1 : Math.min(1, cdf + pdf); return pdf; };
	analytic.forEach((a, i) => { const pdf = advance(i, a.power); packAnalyticLight(f32, u32, i * LIGHT_BYTES / 4, a.light, pdf, cdf); });
	triangles.forEach((t, j) => {
		const i = analytic.length + j, o = i * LIGHT_BYTES / 4, pdf = advance(i, t.power);
		f32.set([...t.p[0], t.area, ...t.p[1], pdf, ...t.p[2], cdf, ...t.normal], o);
		u32[o + 15] = t.draw.materialIndex; f32.set(t.uv, o + 16); u32[o + 28] = t.draw.slot;
	});
	return { data, offsets, count, analytic: analytic.length, emissive: triangles.filter(t => t.power > 0).length };
}
