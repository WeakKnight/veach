import * as THREE from 'three';
import type { HostView, Renderer } from '../render/Renderer';
import { RenderScene, type GeometryHandle, type GeometryResource, type InstanceHandle, type MaterialHandle, type PbrMaterial, type ResourceTextureBinding, type SceneUpdate, type TextureHandle, type TextureResource } from '../scene/RenderScene';

type Stamp = readonly unknown[];
type Entry<H> = { handle: H; stamp: Stamp };
type GeometryEntry = Entry<GeometryHandle> & { topology: Stamp; attributes: Map<string, Stamp> };
type InstanceEntry = Entry<InstanceHandle> & { geometry: GeometryHandle; materials: MaterialHandle[]; enabled: boolean };
const same = (a: Stamp | undefined, b: Stamp) => !!a && a.length === b.length && a.every((v, i) => v === b[i]);
const attributeNames = ['position', 'normal', 'tangent', 'uv', 'uv1'] as const;
const maps = ['map', 'metalnessMap', 'roughnessMap', 'normalMap', 'emissiveMap', 'alphaMap'] as const;
type SupportedMaterial = THREE.MeshStandardMaterial | THREE.MeshBasicMaterial;
const fail = (message: string): never => { throw new Error(`Veach ThreeAdapter: ${message}`); };

function attributeStamp(a: THREE.BufferAttribute | THREE.InterleavedBufferAttribute | undefined): Stamp {
	if (!a) return [];
	if (a instanceof THREE.InterleavedBufferAttribute) return [a, a.data, a.data.array, a.data.version, a.count, a.itemSize, a.normalized, a.data.stride, a.offset];
	return [a, a.array, a.version, a.count, a.itemSize, a.normalized];
}

function floats(g: THREE.BufferGeometry, name: string, size: number): Float32Array | undefined {
	const a = g.getAttribute(name);
	if (!a) return undefined;
	if (!(a instanceof THREE.BufferAttribute || a instanceof THREE.InterleavedBufferAttribute) || a.itemSize !== size) fail(`Unsupported ${name} attribute`);
	const out = new Float32Array(a.count * size);
	for (let i = 0; i < a.count; i++) for (let c = 0; c < size; c++) out[i * size + c] = a.getComponent(i, c);
	return out;
}

function range(g: THREE.BufferGeometry): { start: number; end: number } {
	const count = g.index?.count ?? g.getAttribute('position')?.count ?? 0;
	const start = Math.max(0, g.drawRange.start), end = Math.min(count, start + g.drawRange.count);
	if (!Number.isInteger(start) || start % 3 || end % 3) fail('drawRange must contain whole triangles');
	return { start, end };
}

function geometryResource(g: THREE.BufferGeometry, grouped: boolean): GeometryResource {
	const positions = floats(g, 'position', 3) ?? fail('Geometry needs positions');
	const { start, end } = range(g);
	const indices = new Uint32Array(end - start);
	for (let i = start; i < end; i++) indices[i - start] = g.index ? g.index.getX(i) : i;
	const groups = g.groups.map(p => ({ firstIndex: Math.max(start, p.start) - start,
		indexCount: Math.min(end, p.start + p.count) - Math.max(start, p.start), materialSlot: p.materialIndex ?? 0 })).filter(p => p.indexCount > 0);
	return { positions, indices, normals: floats(g, 'normal', 3), tangents: floats(g, 'tangent', 4),
		uv0: floats(g, 'uv', 2), uv1: floats(g, 'uv1', 2), groups: grouped ? groups : undefined };
}

function materialStamp(m: SupportedMaterial): Stamp {
	const p = m as THREE.MeshPhysicalMaterial;
	const out: unknown[] = [m.version, m.name, m.color.r, m.color.g, m.color.b, p.metalness, p.roughness,
		p.emissive?.r, p.emissive?.g, p.emissive?.b, p.emissiveIntensity, p.ior, p.transmission,
		m.opacity, m.alphaTest, m.side, m.transparent, m.visible, p.normalScale?.x, p.normalScale?.y,
		m.vertexColors, p.flatShading, p.clearcoat, p.sheen, p.iridescence, p.anisotropy, p.dispersion,
		p.bumpMap, p.displacementMap, p.aoMap, p.lightMap, p.transmissionMap, p.normalMapType,
		m.onBeforeCompile];
	for (const key of maps) {
		const t = p[key]; out.push(t);
		if (t) { if (t.matrixAutoUpdate) t.updateMatrix(); out.push(t.channel, t.wrapS, t.wrapT, ...t.matrix.elements); }
	}
	return out;
}

function textureResource(t: THREE.Texture): TextureResource {
	if (t.isRenderTargetTexture || t instanceof THREE.CompressedTexture || t instanceof THREE.CubeTexture || t instanceof THREE.VideoTexture) fail('GPU, compressed, cube and video textures require a custom bridge');
	if (t.mapping !== THREE.UVMapping) fail('Only UV-mapped textures are supported');
	if (t.type !== THREE.UnsignedByteType || t.format !== THREE.RGBAFormat || t.premultiplyAlpha) fail('Textures must be unpremultiplied RGBA8');
	if (!(new Set<string>([THREE.NoColorSpace, THREE.SRGBColorSpace, THREE.LinearSRGBColorSpace])).has(t.colorSpace)) fail('Unsupported texture color space');
	const image = t.image as { width: number; height: number; naturalWidth?: number; naturalHeight?: number; data?: Uint8Array | Uint8ClampedArray };
	if (!image) fail('Texture image is not loaded; await loading before sync');
	let data: Uint8Array | Uint8ClampedArray;
	let width: number, height: number;
	if (image.data) {
		if (!(image.data instanceof Uint8Array || image.data instanceof Uint8ClampedArray)) fail('DataTexture requires RGBA8 pixels');
		({ width, height } = image); data = image.data;
	} else {
		width = image.naturalWidth || image.width; height = image.naturalHeight || image.height;
		if (!width || !height) fail('Texture image is not loaded');
		const canvas = new OffscreenCanvas(width, height), ctx = canvas.getContext('2d')!;
		ctx.drawImage(image as CanvasImageSource, 0, 0); data = ctx.getImageData(0, 0, width, height).data;
	}
	if (t.flipY) {
		const flipped = new Uint8Array(data.length), stride = width * 4;
		for (let y = 0; y < height; y++) flipped.set(data.subarray(y * stride, (y + 1) * stride), (height - 1 - y) * stride);
		data = flipped;
	}
	return { source: { width, height, data }, colorSpace: t.colorSpace === THREE.SRGBColorSpace ? 'srgb' : 'linear' };
}

/** Owns a Veach scene; does not dispose or mutate host geometries, materials or textures.
 * Call sync after simulation, await it, then renderFrame. Large array edits require needsUpdate.
 * A failed sync preserves the last committed scene and all detection snapshots. */
export class ThreeAdapter {
	readonly scene: RenderScene;
	private geometries = new Map<string, GeometryEntry>();
	private textures = new Map<THREE.Texture, Entry<TextureHandle>>();
	private materials = new Map<THREE.Material, Entry<MaterialHandle>>();
	private instances = new Map<string, InstanceEntry>();
	private syncing = false;
	private disposed = false;

	constructor(renderer: Pick<Renderer, 'createScene'>) { this.scene = renderer.createScene(); }

	view(camera: THREE.PerspectiveCamera): HostView {
		if (!(camera instanceof THREE.PerspectiveCamera)) fail('Only PerspectiveCamera is supported');
		camera.updateWorldMatrix(true, false);
		return { worldFromCamera: new Float32Array(camera.matrixWorld.elements), clipFromView: new Float32Array(camera.projectionMatrix.elements) };
	}

	async sync(root: THREE.Object3D, camera?: THREE.PerspectiveCamera): Promise<void> {
		if (this.disposed) fail('Adapter is disposed');
		if (this.syncing) fail('Await the previous sync before calling sync again');
		this.syncing = true;
		let update: SceneUpdate | undefined;
		let committing = false;
		try {
			root.updateWorldMatrix(true, true);
			const geometries = new Map<string, GeometryEntry>(), textures = new Map<THREE.Texture, Entry<TextureHandle>>();
			const materials = new Map<THREE.Material, Entry<MaterialHandle>>(), instances = new Map<string, InstanceEntry>();
			const meshes: { mesh: THREE.Mesh; enabled: boolean }[] = [];
			const walk = (obj: THREE.Object3D, visible: boolean) => {
				visible &&= obj.visible;
				if (obj instanceof THREE.Scene && obj.overrideMaterial) fail('Scene overrideMaterial requires an explicit material bridge');
				if (obj instanceof THREE.Light) fail('Use Veach lights/environment; automatic Three.js light conversion is not supported yet');
				if (obj instanceof THREE.Line || obj instanceof THREE.Points || obj instanceof THREE.Sprite || obj instanceof THREE.LOD) fail(`Unsupported object ${obj.type}`);
				if (obj instanceof THREE.Mesh) {
					if (obj instanceof THREE.SkinnedMesh || obj instanceof THREE.BatchedMesh || Object.keys(obj.geometry.morphAttributes).length || (obj instanceof THREE.InstancedMesh && obj.instanceColor)) fail('Skinning, batching, morph targets and instance colors need an explicit geometry/material bridge');
					const r = range(obj.geometry);
					if (r.end > r.start && (!Array.isArray(obj.material) || obj.geometry.groups.some((g: { start: number; count: number }) => g.start < r.end && g.start + g.count > r.start))) meshes.push({ mesh: obj, enabled: visible && (!camera || obj.layers.test(camera.layers)) });
				}
				for (const child of obj.children) walk(child, visible);
			};
			walk(root, true);
			update = this.scene.beginUpdate();
			const u = update;
			for (const { mesh } of meshes) {
				for (const m of Array.isArray(mesh.material) ? mesh.material : [mesh.material]) {
					if (!(m instanceof THREE.MeshStandardMaterial || m instanceof THREE.MeshBasicMaterial)) fail(`Unsupported material ${m.type}`);
					for (const key of maps) {
						const t = (m as THREE.MeshStandardMaterial)[key];
						if (!t || textures.has(t)) continue;
						const stamp = [t.version, t.source, t.source.version, t.image, t.colorSpace, t.flipY, t.format, t.type, t.premultiplyAlpha, t.mapping];
						const old = this.textures.get(t);
						let handle = old?.handle;
						if (!same(old?.stamp, stamp)) { const desc = textureResource(t); if (handle) u.setTexture(handle, desc); else handle = u.createTexture(desc); }
						textures.set(t, { handle: handle!, stamp });
					}
				}
			}
			const binding = (t: THREE.Texture | null | undefined, channel?: 0 | 1 | 2 | 3): ResourceTextureBinding | undefined => {
				if (!t) return undefined;
				if (t.channel !== 0 && t.channel !== 1) fail('Only uv and uv1 are supported');
				if (t.matrixAutoUpdate) t.updateMatrix();
				const e = t.matrix.elements, sx = Math.hypot(e[0], e[1]);
				const rotation = sx ? Math.atan2(e[1], e[0]) : 0, c = Math.cos(rotation), s = Math.sin(rotation);
				const sy = -s * e[3] + c * e[4];
				if (Math.abs(c * e[3] + s * e[4]) > 1e-6 || e[2] !== 0 || e[5] !== 0 || e[8] !== 1) fail('UV shear is unsupported; use uniform repeat when rotating textures');
				const wrap = (v: THREE.Wrapping) => v === THREE.ClampToEdgeWrapping ? 'clamp' : v === THREE.MirroredRepeatWrapping ? 'mirror' : 'repeat';
				return { texture: textures.get(t)!.handle, texCoord: t.channel as 0 | 1, wrapU: wrap(t.wrapS), wrapV: wrap(t.wrapT), offset: [e[6], e[7]], scale: [sx, sy], rotation, channel };
			};
			for (const { mesh, enabled } of meshes) {
				const g = mesh.geometry, grouped = Array.isArray(mesh.material), geometryKey = `${g.uuid}/${grouped}`;
				if (!geometries.has(geometryKey)) {
					const old = this.geometries.get(geometryKey), attributes = new Map(attributeNames.map(name => [name, attributeStamp(g.getAttribute(name))]));
					const topology = [g, ...attributeStamp(g.index ?? undefined), g.getAttribute('position')?.count, g.drawRange.start, g.drawRange.count, ...(grouped ? g.groups.flatMap(p => [p.start, p.count, p.materialIndex]) : [])];
					let handle = old?.handle;
					if (!old || !same(old.topology, topology)) { const desc = geometryResource(g, grouped); if (handle) u.setGeometry(handle, desc); else handle = u.createGeometry(desc); }
					else {
						const changes: Partial<GeometryResource> = {};
						for (const [name, target, size] of [['position', 'positions', 3], ['normal', 'normals', 3], ['tangent', 'tangents', 4], ['uv', 'uv0', 2], ['uv1', 'uv1', 2]] as const) {
							if (!same(old.attributes.get(name), attributes.get(name)!)) changes[target] = floats(g, name, size);
						}
						if (Object.keys(changes).length) u.updateGeometryAttributes(handle!, changes);
					}
					geometries.set(geometryKey, { handle: handle!, stamp: [], topology, attributes });
				}
				const hostMaterials = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
				for (const m of hostMaterials) {
					if (materials.has(m)) continue;
					const p = m as THREE.MeshPhysicalMaterial;
					if (p.wireframe || m.alphaHash || m.clippingPlanes?.length || p.envMap || p.thickness || p.thicknessMap
						|| (p.attenuationDistance !== undefined && p.attenuationDistance !== Infinity)
						|| (p.specularIntensity !== undefined && p.specularIntensity !== 1)
						|| (p.specularColor && !p.specularColor.equals(new THREE.Color(1, 1, 1))) || p.specularIntensityMap || p.specularColorMap) fail(`Unsupported material feature on "${m.name || m.type}"`);
					if (m.vertexColors || p.flatShading || p.clearcoat || p.sheen || p.iridescence || p.anisotropy || p.dispersion || p.bumpMap || p.displacementMap || p.aoMap || p.lightMap || p.transmissionMap || m.onBeforeCompile !== THREE.Material.prototype.onBeforeCompile) fail(`Unsupported material feature on "${m.name || m.type}"`);
					if (m.side === THREE.BackSide || (m.transparent && m.alphaTest === 0 && !p.transmission) || (p.normalMap && p.normalMapType !== THREE.TangentSpaceNormalMap)) fail('BackSide, blended opacity and object-space normal maps are unsupported');
					const stamp = materialStamp(m as SupportedMaterial), old = this.materials.get(m);
					let handle = old?.handle;
					if (!same(old?.stamp, stamp)) {
						const desc: PbrMaterial = { name: m.name, baseColor: [p.color.r, p.color.g, p.color.b], metallic: p.metalness ?? 0, roughness: p.roughness ?? 1,
							emission: p.emissive && [p.emissive.r * p.emissiveIntensity, p.emissive.g * p.emissiveIntensity, p.emissive.b * p.emissiveIntensity], ior: p.ior, transmission: p.transmission,
							opacity: p.opacity, alphaMode: p.alphaTest > 0 ? 'mask' : 'opaque', alphaCutoff: p.alphaTest, doubleSided: p.side === THREE.DoubleSide,
							unlit: m instanceof THREE.MeshBasicMaterial, normalScale: p.normalScale?.toArray(),
							baseColorMap: binding(p.map), metallicMap: binding(p.metalnessMap, 2), roughnessMap: binding(p.roughnessMap, 1),
							normalMap: binding(p.normalMap), emissionMap: binding(p.emissiveMap), opacityMap: binding(p.alphaMap, 1) };
						if (handle) u.setMaterial(handle, desc); else handle = u.createMaterial(desc);
					}
					materials.set(m, { handle: handle!, stamp });
				}
				const materialIds = hostMaterials.map(m => materials.get(m)!.handle), geometryId = geometries.get(geometryKey)!.handle;
				const count = mesh instanceof THREE.InstancedMesh ? mesh.count : 1;
				if (hostMaterials.some(m => !m.visible) && !hostMaterials.every(m => !m.visible)) fail('Mixed material visibility needs separate meshes');
				for (let i = 0; i < count; i++) {
					const world = mesh.matrixWorld.clone();
					if (mesh instanceof THREE.InstancedMesh) { const local = new THREE.Matrix4(); mesh.getMatrixAt(i, local); world.multiply(local); }
					const matrix = new Float32Array(world.elements), key = `${mesh.uuid}/${i}`, old = this.instances.get(key);
					const active = enabled && hostMaterials.some(m => m.visible);
					let handle = old?.handle;
					if (!old) handle = u.addInstance({ geometry: geometryId, materials: materialIds, worldMatrix: matrix, enabled: active });
					else {
						if (!same(old.stamp, [...matrix])) u.setInstanceTransform(handle!, matrix);
						if (old.geometry !== geometryId) u.setInstanceGeometry(handle!, geometryId);
						if (!same(old.materials, materialIds)) u.setInstanceMaterials(handle!, materialIds);
						if (old.enabled !== active) u.setInstanceEnabled(handle!, active);
					}
					instances.set(key, { handle: handle!, stamp: [...matrix], geometry: geometryId, materials: materialIds, enabled: active });
				}
			}
			for (const [key, old] of this.instances) if (!instances.has(key)) u.removeInstance(old.handle);
			for (const [key, old] of this.materials) if (!materials.has(key)) u.releaseMaterial(old.handle);
			for (const [key, old] of this.geometries) if (!geometries.has(key)) u.releaseGeometry(old.handle);
			for (const [key, old] of this.textures) if (!textures.has(key)) u.releaseTexture(old.handle);
			committing = true; await u.commit();
			this.geometries = geometries; this.materials = materials; this.textures = textures; this.instances = instances;
		} catch (error) { if (update && !committing) update.cancel(); throw error; }
		finally { this.syncing = false; }
	}

	dispose(): void {
		this.disposed = true; this.scene.dispose();
		this.geometries.clear(); this.materials.clear(); this.textures.clear(); this.instances.clear();
	}
}
