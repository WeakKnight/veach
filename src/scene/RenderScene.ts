import { mat4 } from '../math/Math';
import type { LightDesc } from './Scene';

declare const handleKind: unique symbol;
export type GeometryHandle = number & { readonly [handleKind]: 'geometry' };
export type TextureHandle = number & { readonly [handleKind]: 'texture' };
export type MaterialHandle = number & { readonly [handleKind]: 'material' };
export type InstanceHandle = number & { readonly [handleKind]: 'instance' };
export type LightHandle = number & { readonly [handleKind]: 'light' };

export interface GeometryResource {
	positions: Float32Array;
	indices: Uint32Array;
	normals?: Float32Array;
	tangents?: Float32Array;
	uv0?: Float32Array;
	uv1?: Float32Array;
	groups?: readonly { firstIndex: number; indexCount: number; materialSlot: number }[];
}

export interface TextureResource {
	source: ImageBitmap | { width: number; height: number; data: Uint8Array | Uint8ClampedArray };
	colorSpace: 'srgb' | 'linear';
}

export interface ResourceTextureBinding {
	texture: TextureHandle;
	texCoord?: 0 | 1;
	wrapU?: 'repeat' | 'clamp' | 'mirror';
	wrapV?: 'repeat' | 'clamp' | 'mirror';
	offset?: readonly [number, number];
	scale?: readonly [number, number];
	rotation?: number;
	/** Select a scalar channel. Defaults: roughness G, metallic B, opacity A. */
	channel?: 0 | 1 | 2 | 3;
}

export interface PbrMaterial {
	name?: string;
	baseColor?: readonly [number, number, number];
	metallic?: number;
	roughness?: number;
	emission?: readonly [number, number, number];
	ior?: number;
	transmission?: number;
	opacity?: number;
	alphaMode?: 'opaque' | 'mask';
	alphaCutoff?: number;
	doubleSided?: boolean;
	unlit?: boolean;
	normalScale?: readonly [number, number];
	baseColorMap?: ResourceTextureBinding;
	metallicMap?: ResourceTextureBinding;
	roughnessMap?: ResourceTextureBinding;
	normalMap?: ResourceTextureBinding;
	emissionMap?: ResourceTextureBinding;
	opacityMap?: ResourceTextureBinding;
}

export interface RenderInstance {
	geometry: GeometryHandle;
	materials: readonly MaterialHandle[];
	worldMatrix: Float32Array;
	enabled?: boolean;
}

/** Internal immutable-by-convention snapshots; only supplied to the renderer's commit sink. */
export interface SceneSnapshot {
	geometries: ReadonlyMap<GeometryHandle, GeometryResource>;
	textures: ReadonlyMap<TextureHandle, TextureResource>;
	materials: ReadonlyMap<MaterialHandle, PbrMaterial>;
	instances: ReadonlyMap<InstanceHandle, RenderInstance>;
	lights: ReadonlyMap<LightHandle, LightDesc>;
	revision: number;
}

export interface SceneChanges {
	geometries: Set<GeometryHandle>;
	textures: Set<TextureHandle>;
	materials: Set<MaterialHandle>;
	instances: Set<InstanceHandle>;
	lights: Set<LightHandle>;
	/** Position/topology changes, distinct from shading-only vertex changes. */
	geometryBounds: Set<GeometryHandle>;
}

export type SceneCommitSink = (next: SceneSnapshot, changes: SceneChanges) => Promise<void>;
const textureKeys = ['baseColorMap', 'metallicMap', 'roughnessMap', 'normalMap', 'emissionMap', 'opacityMap'] as const;
let nextHandle = 1;

function requireValue<K, V>(map: ReadonlyMap<K, V>, key: K, kind: string): V {
	const value = map.get(key);
	if (!value) throw new Error(`Unknown or released ${kind} handle: ${String(key)}`);
	return value;
}

function finite(values: ArrayLike<number>, label: string): void {
	for (let i = 0; i < values.length; i++) if (!Number.isFinite(values[i])) throw new Error(`${label} must be finite`);
}

function matrix(value: Float32Array): Float32Array {
	if (value.length !== 16) throw new Error('worldMatrix must have 16 elements');
	finite(value, 'worldMatrix');
	if (value[3] !== 0 || value[7] !== 0 || value[11] !== 0 || value[15] !== 1 || !mat4.invert(value)) {
		throw new Error('worldMatrix must be an invertible affine matrix');
	}
	return value.slice();
}

function geometry(desc: GeometryResource): GeometryResource {
	const count = desc.positions.length / 3;
	if (!Number.isInteger(count) || count === 0 || desc.indices.length === 0 || desc.indices.length % 3) {
		throw new Error('Geometry requires xyz vertices and complete indexed triangles');
	}
	finite(desc.positions, 'positions');
	for (const i of desc.indices) if (i >= count) throw new Error('Geometry index is outside the vertex array');
	for (const [key, size] of [['normals', 3], ['tangents', 4], ['uv0', 2], ['uv1', 2]] as const) {
		const value = desc[key];
		if (value) {
			if (value.length !== count * size) throw new Error(`Invalid ${key} length`);
			finite(value, key);
		}
	}
	let previousEnd = 0;
	for (const g of desc.groups ?? []) {
		if (![g.firstIndex, g.indexCount, g.materialSlot].every(Number.isSafeInteger) || g.firstIndex < previousEnd
			|| g.indexCount <= 0 || g.firstIndex % 3 || g.indexCount % 3 || g.materialSlot < 0
			|| g.firstIndex + g.indexCount > desc.indices.length) throw new Error('Invalid or overlapping geometry groups');
		previousEnd = g.firstIndex + g.indexCount;
	}
	return {
		positions: desc.positions.slice(), indices: desc.indices.slice(), normals: desc.normals?.slice(),
		tangents: desc.tangents?.slice(), uv0: desc.uv0?.slice(), uv1: desc.uv1?.slice(),
		groups: desc.groups?.map(g => ({ ...g })),
	};
}

function texture(desc: TextureResource): TextureResource {
	const source = desc.source;
	if (!Number.isSafeInteger(source.width) || !Number.isSafeInteger(source.height) || source.width <= 0 || source.height <= 0) {
		throw new Error('Texture requires positive integer dimensions');
	}
	if (desc.colorSpace !== 'srgb' && desc.colorSpace !== 'linear') throw new Error('Invalid texture color space');
	if ('data' in source) {
		if (!(source.data instanceof Uint8Array || source.data instanceof Uint8ClampedArray) || source.data.length !== source.width * source.height * 4) throw new Error('Texture requires RGBA8 pixels');
		return { ...desc, source: { ...source, data: source.data.slice() } };
	}
	return { ...desc }; // Borrow the bitmap; its lifetime stays with the application.
}

function material(desc: PbrMaterial): PbrMaterial {
	const out: PbrMaterial = { ...desc };
	for (const key of ['baseColor', 'emission', 'normalScale'] as const) {
		const value = desc[key];
		if (value) {
			finite(value, key);
			if (value.length !== (key === 'normalScale' ? 2 : 3)) throw new Error(`Invalid ${key}`);
			if (key !== 'normalScale' && value.some(v => v < 0)) throw new Error(`${key} must be nonnegative`);
			Object.assign(out, { [key]: [...value] });
		}
	}
	for (const key of ['metallic', 'roughness', 'opacity', 'transmission', 'alphaCutoff'] as const) {
		const value = desc[key];
		if (value !== undefined && (!Number.isFinite(value) || value < 0 || value > 1)) throw new Error(`${key} must be in [0, 1]`);
	}
	if (desc.ior !== undefined && (!Number.isFinite(desc.ior) || desc.ior < 1)) throw new Error('ior must be at least 1');
	if (desc.alphaMode !== undefined && !['opaque', 'mask'].includes(desc.alphaMode)) throw new Error('Invalid alphaMode');
	for (const key of textureKeys) {
		const binding = desc[key];
		if (!binding) continue;
		finite([...(binding.offset ?? [0, 0]), ...(binding.scale ?? [1, 1]), binding.rotation ?? 0], key);
		if ((binding.offset && binding.offset.length !== 2) || (binding.scale && binding.scale.length !== 2)) throw new Error('Texture offset and scale require two elements');
		if (binding.texCoord !== undefined && binding.texCoord !== 0 && binding.texCoord !== 1) throw new Error('Unsupported UV channel');
		for (const wrap of [binding.wrapU, binding.wrapV]) if (wrap && !['repeat', 'clamp', 'mirror'].includes(wrap)) throw new Error('Invalid wrap mode');
		if (binding.channel !== undefined && ![0, 1, 2, 3].includes(binding.channel)) throw new Error('Invalid texture channel');
		out[key] = { ...binding, offset: binding.offset && [...binding.offset], scale: binding.scale && [...binding.scale] };
	}
	return out;
}

function light(desc: LightDesc): LightDesc {
	if (!['point', 'spot', 'area'].includes(desc.type)) throw new Error('Unsupported light type');
	for (const key of ['position', 'direction', 'power', 'sizeU', 'sizeV'] as const) {
		if (desc[key].length !== 3) throw new Error(`Invalid light ${key}`);
		finite(desc[key], key);
	}
	finite([desc.radius, desc.spotAngle, desc.spotBlend], 'light');
	if (desc.power.some(v => v < 0) || desc.radius < 0 || desc.spotAngle < 0 || desc.spotAngle > Math.PI * 2 || desc.spotBlend < 0 || desc.spotBlend > 1) throw new Error('Invalid light power, radius or spot parameters');
	if (desc.type !== 'point' && Math.hypot(...desc.direction) === 0) throw new Error('Light direction must be nonzero');
	if (desc.type === 'spot' && desc.spotAngle === 0) throw new Error('Spot angle must be positive');
	if (desc.type === 'area' && (Math.hypot(...desc.sizeU) === 0 || Math.hypot(...desc.sizeV) === 0)) throw new Error('Area light extents must be nonzero');
	return { ...desc, position: [...desc.position], direction: [...desc.direction], power: [...desc.power], sizeU: [...desc.sizeU], sizeV: [...desc.sizeV] };
}

/** Persistent, engine-independent render state. Create through Renderer.createScene for GPU use. */
export class RenderScene {
	private snapshot: SceneSnapshot = {
		geometries: new Map(), textures: new Map(), materials: new Map(), instances: new Map(), lights: new Map(), revision: 0,
	};
	private active = false;
	private disposed = false;

	constructor(private readonly apply: SceneCommitSink = async () => {}, private readonly onDispose: () => void = () => {}) {}

	get revision(): number { return this.snapshot.revision; }
	get isDisposed(): boolean { return this.disposed; }
	get stats(): { geometries: number; textures: number; materials: number; instances: number; lights: number } {
		const s = this.snapshot;
		return { geometries: s.geometries.size, textures: s.textures.size, materials: s.materials.size, instances: s.instances.size, lights: s.lights.size };
	}

	beginUpdate(): SceneUpdate {
		if (this.disposed) throw new Error('Scene is disposed');
		if (this.active) throw new Error('A scene update is already active');
		this.active = true;
		return new SceneUpdate(this.snapshot, async (next, changes) => {
			if (this.disposed) throw new Error('Scene is disposed');
			await this.apply(next, changes);
			if (this.disposed) throw new Error('Scene was disposed during commit');
			this.snapshot = next;
		}, () => { this.active = false; });
	}

	dispose(): void {
		if (this.disposed) return;
		this.disposed = true;
		this.snapshot = { geometries: new Map(), textures: new Map(), materials: new Map(), instances: new Map(), lights: new Map(), revision: this.revision };
		this.onDispose();
	}
}

export class SceneUpdate {
	private readonly geometries: Map<GeometryHandle, GeometryResource>;
	private readonly textures: Map<TextureHandle, TextureResource>;
	private readonly materials: Map<MaterialHandle, PbrMaterial>;
	private readonly instances: Map<InstanceHandle, RenderInstance>;
	private readonly lights: Map<LightHandle, LightDesc>;
	private closed = false;
	private readonly changes: SceneChanges = { geometries: new Set(), textures: new Set(), materials: new Set(), instances: new Set(), lights: new Set(), geometryBounds: new Set() };

	constructor(private readonly previous: SceneSnapshot, private readonly apply: SceneCommitSink, private readonly finish: () => void) {
		this.geometries = new Map(previous.geometries);
		this.textures = new Map(previous.textures);
		this.materials = new Map(previous.materials);
		this.instances = new Map(previous.instances);
		this.lights = new Map(previous.lights);
	}

	private check(): void { if (this.closed) throw new Error('Scene update is closed'); }
	private id<H extends number>(): H { this.check(); return nextHandle++ as H; }

	createGeometry(desc: GeometryResource): GeometryHandle {
		const id = this.id<GeometryHandle>();
		this.geometries.set(id, geometry(desc)); this.changes.geometries.add(id); this.changes.geometryBounds.add(id); return id;
	}
	createTexture(desc: TextureResource): TextureHandle {
		const id = this.id<TextureHandle>();
		this.textures.set(id, texture(desc)); this.changes.textures.add(id); return id;
	}
	createMaterial(desc: PbrMaterial): MaterialHandle {
		const id = this.id<MaterialHandle>();
		this.materials.set(id, material(desc)); this.changes.materials.add(id); return id;
	}
	addInstance(desc: RenderInstance): InstanceHandle {
		const id = this.id<InstanceHandle>();
		this.instances.set(id, { ...desc, materials: [...desc.materials], worldMatrix: matrix(desc.worldMatrix) }); this.changes.instances.add(id); return id;
	}
	addLight(desc: LightDesc): LightHandle {
		const id = this.id<LightHandle>(); this.lights.set(id, light(desc)); this.changes.lights.add(id); return id;
	}
	setGeometry(id: GeometryHandle, desc: GeometryResource): void {
		this.check(); requireValue(this.geometries, id, 'geometry');
		this.geometries.set(id, geometry(desc)); this.changes.geometries.add(id); this.changes.geometryBounds.add(id);
	}
	updateGeometryAttributes(id: GeometryHandle, attributes: Partial<Pick<GeometryResource, 'positions' | 'normals' | 'tangents' | 'uv0' | 'uv1'>>): void {
		this.check(); const old = requireValue(this.geometries, id, 'geometry');
		if (attributes.positions && attributes.positions.length !== old.positions.length) throw new Error('Use setGeometry to change vertex count');
		this.geometries.set(id, geometry({ ...old, ...attributes })); this.changes.geometries.add(id);
		if (attributes.positions) this.changes.geometryBounds.add(id);
	}
	setTexture(id: TextureHandle, desc: TextureResource): void {
		this.check(); requireValue(this.textures, id, 'texture'); this.textures.set(id, texture(desc)); this.changes.textures.add(id);
	}
	setMaterial(id: MaterialHandle, desc: PbrMaterial): void {
		this.check(); requireValue(this.materials, id, 'material'); this.materials.set(id, material(desc)); this.changes.materials.add(id);
	}
	setInstanceTransform(id: InstanceHandle, worldMatrix: Float32Array): void {
		this.check(); const old = requireValue(this.instances, id, 'instance');
		this.instances.set(id, { ...old, worldMatrix: matrix(worldMatrix) }); this.changes.instances.add(id);
	}
	setInstanceMaterials(id: InstanceHandle, materials: readonly MaterialHandle[]): void {
		this.check(); const old = requireValue(this.instances, id, 'instance');
		this.instances.set(id, { ...old, materials: [...materials] }); this.changes.instances.add(id);
	}
	setInstanceGeometry(id: InstanceHandle, geometry: GeometryHandle): void {
		this.check(); const old = requireValue(this.instances, id, 'instance');
		this.instances.set(id, { ...old, geometry }); this.changes.instances.add(id);
	}
	setInstanceEnabled(id: InstanceHandle, enabled: boolean): void {
		this.check(); const old = requireValue(this.instances, id, 'instance');
		this.instances.set(id, { ...old, enabled }); this.changes.instances.add(id);
	}
	setLight(id: LightHandle, desc: LightDesc): void {
		this.check(); requireValue(this.lights, id, 'light'); this.lights.set(id, light(desc)); this.changes.lights.add(id);
	}
	removeInstance(id: InstanceHandle): void {
		this.check(); requireValue(this.instances, id, 'instance'); this.instances.delete(id); this.changes.instances.add(id);
	}
	removeLight(id: LightHandle): void {
		this.check(); requireValue(this.lights, id, 'light'); this.lights.delete(id); this.changes.lights.add(id);
	}
	releaseGeometry(id: GeometryHandle): void {
		this.check(); requireValue(this.geometries, id, 'geometry'); this.geometries.delete(id); this.changes.geometries.add(id); this.changes.geometryBounds.add(id);
	}
	releaseMaterial(id: MaterialHandle): void {
		this.check(); requireValue(this.materials, id, 'material'); this.materials.delete(id); this.changes.materials.add(id);
	}
	releaseTexture(id: TextureHandle): void {
		this.check(); requireValue(this.textures, id, 'texture'); this.textures.delete(id); this.changes.textures.add(id);
	}

	cancel(): void { this.check(); this.closed = true; this.finish(); }

	async commit(): Promise<void> {
		this.check(); this.closed = true;
		try {
			for (const desc of this.instances.values()) {
				const g = requireValue(this.geometries, desc.geometry, 'geometry');
				if (desc.materials.length === 0) throw new Error('Instance requires at least one material');
				for (const id of desc.materials) requireValue(this.materials, id, 'material');
				for (const group of g.groups ?? []) if (group.materialSlot >= desc.materials.length) throw new Error('Instance lacks a geometry material slot');
			}
			for (const desc of this.materials.values()) for (const key of textureKeys) {
				if (desc[key]) requireValue(this.textures, desc[key].texture, 'texture');
			}
			if (this.previous.revision === 0 || Object.values(this.changes).some(set => set.size > 0)) {
				await this.apply({ geometries: this.geometries, textures: this.textures, materials: this.materials, instances: this.instances, lights: this.lights, revision: this.previous.revision + 1 }, this.changes);
			}
		} finally { this.finish(); }
	}
}
