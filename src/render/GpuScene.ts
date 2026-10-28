// Flattens a SceneDesc into the storage buffers bound by shaders/Scene/SceneBindings.slang:
//   gNodes     [TLAS nodes][BLAS 0 nodes][BLAS 1 nodes]...
//   gTris      per-BLAS reordered triangles (3 float4 each)
//   gIndices   [mesh indices...][TLAS prim indices]
//   gVertices, gInstances, gLights
//   gMaterialData  material headers, texture tables, constants, bytecode (GpuLayout.packMaterialData)
import { BVH_NODE_BYTES, BVH_TRI_FLOATS, BuildQuality, type BLASData, type TinyBVH } from '../accel/TinyBVH';
import type { CompiledMaterial } from '../material/Compile';
import { luminance, mat4, vec3, type Mat4, type Vec3 } from '../math/Math';
import type { SceneDesc } from '../scene/Scene';
import { INSTANCE_BYTES, INSTANCE_FLAG_ALPHA_TESTED, INSTANCE_FLAG_EMISSIVE, LIGHT_BYTES, VERTEX_BYTES, packAnalyticLight, packInstance, packMaterialData, packVertices } from './GpuLayout';
import { emissionLuminance, sceneShadeCapacities } from './SceneMaterials';
import { materialStackCapacity, materialLightCapacity, type MaterialStackCapacity } from './MaterialCapacity';
import { materialOpcodeMask, type MaterialOpcodeMask } from './MaterialProgramFeatures';
import type { CpuTexture } from './vt/TileSource';
import type { VirtualTextureSystem } from './vt/VirtualTextureSystem';

export interface SceneStats {
	meshes: number;
	instances: number;
	triangles: number;
	emissiveTriangles: number;
	analyticLights: number;
	bvhNodes: number;
	buildMs: number;
}

export interface GpuSceneOptions {
	quality?: BuildQuality;
}

function createBuffer(device: GPUDevice, label: string, data: ArrayBufferView | ArrayBuffer, minBytes = 16): GPUBuffer {
	const bytes = data instanceof ArrayBuffer ? new Uint8Array(data) : new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
	const size = Math.max(minBytes, Math.ceil(bytes.byteLength / 16) * 16);
	const buffer = device.createBuffer({ label, size, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST, mappedAtCreation: true });
	new Uint8Array(buffer.getMappedRange()).set(bytes);
	buffer.unmap();
	return buffer;
}

export class GpuScene {
	nodes!: GPUBuffer;
	tris!: GPUBuffer;
	instances!: GPUBuffer;
	vertices!: GPUBuffer;
	indices!: GPUBuffer;
	materials!: GPUBuffer;
	lights!: GPUBuffer;

	instanceCount = 0;
	hasAlphaTested = false;
	materialStackSize = 0;
	materialCount = 0;
	materialShadeCapacities: MaterialStackCapacity[] = [];
	materialSurfaceCapacities: MaterialStackCapacity[] = [];
	materialSurfaceCapacity: MaterialStackCapacity = 0;
	materialLightCapacity: MaterialStackCapacity = 0;
	materialOpacityCapacity: MaterialStackCapacity = 0;
	materialOpcodes: MaterialOpcodeMask = [0, 0];
	lightCount = 0;
	analyticLightCount = 0;
	tlasPrimOffset = 0;
	boundsMin: Vec3 = [0, 0, 0];
	boundsMax: Vec3 = [0, 0, 0];
	stats!: SceneStats;

	private constructor() {}

	// materials: compileSceneMaterials(scene).
	static build(device: GPUDevice, bvh: TinyBVH, scene: SceneDesc, vt: VirtualTextureSystem, materials: readonly CompiledMaterial[], options: GpuSceneOptions = {}): GpuScene {
		const start = performance.now();
		const out = new GpuScene();
		const quality = options.quality ?? BuildQuality.High;

		// ---- materials (the default material goes last) ----
		if (materials.length !== scene.materials.length + 1) {
			throw new Error('GpuScene: expected the compiled scene materials plus the default material');
		}
		const defaultMaterialIndex = materials.length - 1;
		out.materialCount = materials.length;
		out.materialStackSize = Math.max(0, ...materials.map(material => material.stackSize));
		out.materialShadeCapacities = sceneShadeCapacities(scene, materials);
		out.materialSurfaceCapacities = sceneShadeCapacities(scene, materials, true);
		out.materialSurfaceCapacity = materialStackCapacity(Math.max(0, ...materials.map(m => m.programStackSizes.surface)));
		out.materialOpacityCapacity = materialStackCapacity(Math.max(0, ...materials.map(m => m.programStackSizes.opacity)));
		out.materialLightCapacity = materialStackCapacity(Math.max(0, ...materials.filter(m => m.emissive).map(materialLightCapacity)));
		out.materialOpcodes = materialOpcodeMask(materials);
		const materialData = packMaterialData(materials, vt.descriptorOf);
		const materialOf = (mesh: number) => {
			const m = scene.meshes[mesh].material;
			return m >= 0 && m < scene.materials.length ? m : defaultMaterialIndex;
		};

		// ---- per-mesh geometry and BLAS, only for meshes that are instanced ----
		const used = new Set(scene.instances.map((i) => i.mesh));
		interface MeshGpu {
			blas: BLASData;
			nodeOffset: number; // local, before the TLAS shift
			triOffset: number;
			indexOffset: number;
			vertexOffset: number;
			triCount: number;
		}
		const meshGpu = new Map<number, MeshGpu>();
		let nodeTotal = 0, triRefTotal = 0, indexTotal = 0, vertexTotal = 0;
		for (const meshIndex of used) {
			const mesh = scene.meshes[meshIndex];
			const blas = bvh.buildBLAS(mesh.positions, mesh.indices, quality);
			meshGpu.set(meshIndex, {
				blas,
				nodeOffset: nodeTotal,
				triOffset: triRefTotal,
				indexOffset: indexTotal,
				vertexOffset: vertexTotal,
				triCount: mesh.indices.length / 3,
			});
			nodeTotal += blas.nodeCount;
			triRefTotal += blas.primRefCount;
			indexTotal += mesh.indices.length;
			vertexTotal += mesh.positions.length / 3;
		}

		// ---- instances + TLAS ----
		const instanceCount = scene.instances.length;
		const aabbs = new Float32Array(instanceCount * 8);
		const worldToObject: Mat4[] = [];
		let boundsMin: Vec3 = [Infinity, Infinity, Infinity];
		let boundsMax: Vec3 = [-Infinity, -Infinity, -Infinity];
		scene.instances.forEach((inst, i) => {
			const g = meshGpu.get(inst.mesh)!;
			const box = mat4.transformAABB(inst.transform, g.blas.boundsMin, g.blas.boundsMax);
			aabbs.set([...box.min, 0, ...box.max, 0], i * 8);
			boundsMin = vec3.min(boundsMin, box.min);
			boundsMax = vec3.max(boundsMax, box.max);
			worldToObject.push(mat4.invert(inst.transform) ?? mat4.identity());
		});
		const tlas = instanceCount > 0 ? bvh.buildTLAS(aabbs) : null;
		const tlasNodeCount = tlas?.nodeCount ?? 0;

		// ---- emissive triangles ----
		interface PendingLight {
			instance: number;
			p: [Vec3, Vec3, Vec3];
			n: Vec3;
			area: number;
			power: number;
			material: number;
			uv: number[]; // v0.uv0, v1.uv0, v2.uv0, v0.uv1, v1.uv1, v2.uv1 (12 floats)
		}
		const pending: PendingLight[] = [];
		const lightOffsets: (number | null)[] = new Array(instanceCount).fill(null);
		const cpuTextures = new Map<number, CpuTexture | null>();
		const textureOf = (source: number) => {
			if (!cpuTextures.has(source)) {
				cpuTextures.set(source, vt.cpuTexture(source));
			}
			return cpuTextures.get(source)!;
		};
		const emitters = materials.map((m) => emissionLuminance(m, textureOf));
		scene.instances.forEach((inst, i) => {
			const materialIndex = materialOf(inst.mesh);
			const emission = emitters[materialIndex];
			if (!emission) {
				return;
			}
			lightOffsets[i] = pending.length;
			const mesh = scene.meshes[inst.mesh];
			// Mean emitted luminance over a few points of the triangle. Underestimating is safe: BSDF
			// hits are MIS-weighted with the actual selection pdf.
			const weights = [[1, 0, 0], [0, 1, 0], [0, 0, 1], [0.5, 0.5, 0], [0, 0.5, 0.5], [0.5, 0, 0.5], [1 / 3, 1 / 3, 1 / 3]];
			const at = (set: Float32Array | null, v: number[], w: number[], c: number) => (set ? w[0] * set[v[0] * 2 + c] + w[1] * set[v[1] * 2 + c] + w[2] * set[v[2] * 2 + c] : 0);
			const meanLuminance = (v: number[]): number => {
				let sum = 0;
				for (const w of weights) {
					const p: Vec3 = [0, 1, 2].map((c) => w[0] * mesh.positions[v[0] * 3 + c] + w[1] * mesh.positions[v[1] * 3 + c] + w[2] * mesh.positions[v[2] * 3 + c]) as Vec3;
					sum += emission([at(mesh.uv0, v, w, 0), at(mesh.uv0, v, w, 1)], [at(mesh.uv1, v, w, 0), at(mesh.uv1, v, w, 1)], p);
				}
				return sum / weights.length;
			};
			const pos = mesh.positions;
			const idx = mesh.indices;
			for (let t = 0; t < idx.length; t += 3) {
				const v = [idx[t], idx[t + 1], idx[t + 2]];
				const p = v.map((k) => mat4.transformPoint(inst.transform, [pos[k * 3], pos[k * 3 + 1], pos[k * 3 + 2]])) as [Vec3, Vec3, Vec3];
				const cross = vec3.cross(vec3.sub(p[1], p[0]), vec3.sub(p[2], p[0]));
				const len = vec3.length(cross);
				const area = 0.5 * len;
				const uv: number[] = [];
				for (const set of [mesh.uv0, mesh.uv1]) {
					for (const k of v) {
						uv.push(set ? set[k * 2] : 0, set ? set[k * 2 + 1] : 0);
					}
				}
				pending.push({
					instance: i,
					p,
					n: len > 0 ? vec3.scale(cross, 1 / len) : [0, 1, 0],
					area,
					power: area * meanLuminance(v),
					material: materialIndex,
					uv,
				});
			}
		});
		// Analytic lights go first; their power is flux / pi to match the triangles' area * radiance.
		const analytic = (scene.lights ?? []).map((l) => ({ light: l, power: luminance(...l.power) / Math.PI })).filter((l) => l.power > 0);
		const analyticCount = analytic.length;
		const trianglePower = pending.reduce((s, l) => s + l.power, 0);
		const triangleCount = trianglePower > 0 ? pending.length : 0;
		const totalPower = trianglePower + analytic.reduce((s, l) => s + l.power, 0);
		const lightCount = analyticCount + triangleCount;
		const lightBuffer = new ArrayBuffer(Math.max(lightCount, 1) * LIGHT_BYTES);
		{
			const f32 = new Float32Array(lightBuffer);
			const u32 = new Uint32Array(lightBuffer);
			let cdf = 0;
			const advance = (i: number, power: number) => {
				const pdf = power / totalPower;
				cdf = i === lightCount - 1 ? 1 : Math.min(cdf + pdf, 1);
				return pdf;
			};
			analytic.forEach(({ light, power }, i) => {
				const pdf = advance(i, power);
				packAnalyticLight(f32, u32, i * (LIGHT_BYTES / 4), light, pdf, cdf);
			});
			for (let t = 0; t < triangleCount; t++) {
				const l = pending[t];
				const i = analyticCount + t;
				const pdf = advance(i, l.power);
				const o = i * (LIGHT_BYTES / 4);
				f32.set([...l.p[0], l.area, ...l.p[1], pdf, ...l.p[2], cdf, ...l.n], o);
				u32[o + 15] = l.material;
				f32.set(l.uv, o + 16);
				u32[o + 28] = l.instance;
			}
		}

		// ---- pack instances ----
		const instanceBuffer = new ArrayBuffer(Math.max(instanceCount, 1) * INSTANCE_BYTES);
		scene.instances.forEach((inst, i) => {
			const g = meshGpu.get(inst.mesh)!;
			const materialIndex = materialOf(inst.mesh);
			let flags = 0;
			if (materials[materialIndex].alphaTested) {
				flags |= INSTANCE_FLAG_ALPHA_TESTED;
				out.hasAlphaTested = true;
			}
			if (triangleCount > 0 && lightOffsets[i] !== null) flags |= INSTANCE_FLAG_EMISSIVE;
			packInstance(instanceBuffer, i, {
				objectToWorld: inst.transform,
				worldToObject: worldToObject[i],
				blasNodeOffset: tlasNodeCount + g.nodeOffset,
				blasTriOffset: g.triOffset,
				indexOffset: g.indexOffset,
				vertexOffset: g.vertexOffset,
				materialIndex,
				flags,
				lightOffset: analyticCount + (lightOffsets[i] ?? 0),
				triCount: g.triCount,
			});
		});

		// ---- nodes / tris / indices / vertices ----
		const nodes = new Uint8Array((tlasNodeCount + nodeTotal) * BVH_NODE_BYTES);
		if (tlas) nodes.set(new Uint8Array(tlas.nodes), 0);
		const tris = new Float32Array(triRefTotal * BVH_TRI_FLOATS);
		const tlasPrimOffset = indexTotal;
		const indices = new Uint32Array(indexTotal + (tlas?.primIndices.length ?? 0));
		const vertices = new Float32Array(vertexTotal * (VERTEX_BYTES / 4));
		for (const [meshIndex, g] of meshGpu) {
			const mesh = scene.meshes[meshIndex];
			nodes.set(new Uint8Array(g.blas.nodes), (tlasNodeCount + g.nodeOffset) * BVH_NODE_BYTES);
			tris.set(g.blas.tris, g.triOffset * BVH_TRI_FLOATS);
			indices.set(mesh.indices, g.indexOffset);
			packVertices(vertices, g.vertexOffset, mesh.positions, mesh.normals, mesh.tangents, mesh.uv0, mesh.uv1);
		}
		if (tlas) indices.set(tlas.primIndices, tlasPrimOffset);

		out.nodes = createBuffer(device, 'bvhNodes', nodes, BVH_NODE_BYTES);
		out.tris = createBuffer(device, 'bvhTris', tris);
		out.instances = createBuffer(device, 'instances', instanceBuffer, INSTANCE_BYTES);
		out.vertices = createBuffer(device, 'vertices', vertices, VERTEX_BYTES);
		out.indices = createBuffer(device, 'indices', indices);
		out.materials = createBuffer(device, 'materialData', materialData);
		out.lights = createBuffer(device, 'lights', lightBuffer, LIGHT_BYTES);
		out.instanceCount = instanceCount;
		out.lightCount = lightCount;
		out.analyticLightCount = analyticCount;
		out.tlasPrimOffset = tlasPrimOffset;
		if (instanceCount > 0) {
			out.boundsMin = boundsMin;
			out.boundsMax = boundsMax;
		}
		out.stats = {
			meshes: meshGpu.size,
			instances: instanceCount,
			triangles: scene.instances.reduce((s, i) => s + meshGpu.get(i.mesh)!.triCount, 0),
			emissiveTriangles: triangleCount > 0 ? pending.filter((l) => l.power > 0).length : 0,
			analyticLights: analyticCount,
			bvhNodes: tlasNodeCount + nodeTotal,
			buildMs: performance.now() - start,
		};
		return out;
	}

	destroy(): void {
		for (const b of [this.nodes, this.tris, this.instances, this.vertices, this.indices, this.materials, this.lights]) {
			b.destroy();
		}
	}
}
