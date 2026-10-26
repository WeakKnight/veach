// .blend scenes -> SceneDesc: objects of the active scene (collections, visibility, parenting,
// transforms), meshes with their modifiers (Subdivision Surface, Smooth by Angle), the camera and
// render settings, materials (BlendNodes). Blender is Z-up; instances convert to Veach's Y-up, while
// meshes stay in Blender object space.
import { luminance, mat4, type Mat4, type Vec3 } from '../../math/Math';
import { defaultMaterial, type CameraDesc, type LightDesc, type MaterialDesc, type SceneDesc } from '../../scene/Scene';
import { BlendFile, type BStruct } from './BlendFile';
import { readMesh, smoothByAngle, subdivide, triangulate, type PolyMesh } from './BlendMesh';
import { translateMaterial, type TexSpace } from './BlendNodes';

// A Blender sun lamp: Veach's sun (one, the brightest) or nothing.
export interface BlendSun {
	direction: Vec3; // toward the sun, Y-up
	irradiance: Vec3; // color * strength, W/m^2
	angle: number; // angular diameter, radians
}

export interface BlendRenderSettings {
	width: number;
	height: number;
	viewTransform: string; // 'Standard', 'Filmic', 'AgX', ...
	look: string;
	exposure: number;
	gamma: number;
}

export interface BlendScene {
	file: BlendFile;
	scene: SceneDesc;
	sun: BlendSun | null;
	world: BStruct | null;
	materials: (BStruct | null)[]; // Blender material per SceneDesc material
	render: BlendRenderSettings;
	warnings: string[];
}

const OB_MESH = 1;
const OB_LAMP = 10;
const OB_CAMERA = 11;
const OB_HIDE_RENDER = 1 << 2;
const COLLECTION_HIDE_RENDER = 1 << 3;
const eModifierMode_Render = 1 << 1;
const eSubsurfModifierFlag_UseCrease = 1 << 4;
const eSubsurfModifierFlag_UseRecursiveSubdivision = 1 << 6;
const eSubsurfModifierFlag_SubsurfUv = 1 << 3; // before 2.80

// (x, y, z) Z-up -> (x, z, -y) Y-up.
const Z_UP_TO_Y_UP = new Float32Array([1, 0, 0, 0, 0, 0, -1, 0, 0, 1, 0, 0, 0, 0, 0, 1]);

function rotationAxis(axis: number, angle: number): number[] {
	const c = Math.cos(angle);
	const s = Math.sin(angle);
	// Row-major 3x3.
	if (axis === 0) return [1, 0, 0, 0, c, -s, 0, s, c];
	if (axis === 1) return [c, 0, s, 0, 1, 0, -s, 0, c];
	return [c, -s, 0, s, c, 0, 0, 0, 1];
}

function multiply3(a: number[], b: number[]): number[] {
	const out = new Array<number>(9).fill(0);
	for (let r = 0; r < 3; r++) {
		for (let c = 0; c < 3; c++) {
			for (let k = 0; k < 3; k++) {
				out[r * 3 + c] += a[r * 3 + k] * b[k * 3 + c];
			}
		}
	}
	return out;
}

function quaternion3(w: number, x: number, y: number, z: number): number[] {
	const l = Math.hypot(w, x, y, z) || 1;
	[w, x, y, z] = [w / l, x / l, y / l, z / l];
	return [
		1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y),
		2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x),
		2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y),
	];
}

// Euler orders by rotmode (1..6): axes in application order, as in BLI eulO_to_mat3.
const EULER_ORDERS = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]];

function rotation3(ob: BStruct, delta: boolean): number[] {
	const mode = ob.num('rotmode', 0, 1);
	const d = delta ? 'd' : '';
	if (mode === 0) {
		const q = ob.nums(delta ? 'dquat' : 'quat');
		return quaternion3(q[0], q[1], q[2], q[3]);
	}
	if (mode === -1) {
		const axis = ob.nums(delta ? 'drotAxis' : 'rotAxis');
		const angle = ob.num(delta ? 'drotAngle' : 'rotAngle');
		const l = Math.hypot(...axis);
		if (l === 0) {
			return [1, 0, 0, 0, 1, 0, 0, 0, 1];
		}
		const s = Math.sin(angle / 2);
		return quaternion3(Math.cos(angle / 2), (axis[0] / l) * s, (axis[1] / l) * s, (axis[2] / l) * s);
	}
	const e = ob.nums(`${d}rot`);
	let m = [1, 0, 0, 0, 1, 0, 0, 0, 1];
	for (const axis of EULER_ORDERS[Math.min(Math.max(mode, 1), 6) - 1]) {
		m = multiply3(rotationAxis(axis, e[axis]), m);
	}
	return m;
}

// BKE_object_to_mat4: translation (loc + dloc) * (drot * rot) * (size * dscale).
function localMatrix(ob: BStruct): Mat4 {
	const r = multiply3(ob.has('drot') ? rotation3(ob, true) : [1, 0, 0, 0, 1, 0, 0, 0, 1], rotation3(ob, false));
	const loc = ob.nums('loc');
	const dloc = ob.has('dloc') ? ob.nums('dloc') : [0, 0, 0];
	const size = ob.has('scale') ? ob.nums('scale') : ob.nums('size');
	const dscale = ob.has('dscale') ? ob.nums('dscale') : ob.has('dsize') ? ob.nums('dsize').map((x) => x + 1) : [1, 1, 1];
	const m = new Float32Array(16);
	for (let c = 0; c < 3; c++) {
		const s = size[c] * dscale[c];
		for (let row = 0; row < 3; row++) {
			m[c * 4 + row] = r[row * 3 + c] * s;
		}
		m[12 + c] = loc[c] + dloc[c];
	}
	m[15] = 1;
	return m;
}

// Object to world in Blender's Z-up space (what obmat / object_to_world stores).
export function worldMatrix(ob: BStruct, cache = new Map<number, Mat4>()): Mat4 {
	const cached = cache.get(ob.offset);
	if (cached) {
		return cached;
	}
	let m = localMatrix(ob);
	const parent = ob.get('parent', 'Object');
	if (parent) {
		const parentinv = Float32Array.from(ob.nums('parentinv'));
		m = mat4.multiply(worldMatrix(parent, cache), mat4.multiply(parentinv, m));
	}
	cache.set(ob.offset, m);
	return m;
}

function sceneObjects(scene: BStruct): BStruct[] {
	const out = new Map<number, BStruct>();
	if (scene.has('master_collection')) {
		const visit = (collection: BStruct | null, seen: Set<number>) => {
			if (!collection || seen.has(collection.offset) || collection.num('flag', 0, 0) & COLLECTION_HIDE_RENDER) {
				return;
			}
			seen.add(collection.offset);
			for (const co of collection.list('gobject', 'CollectionObject')) {
				const ob = co.get('ob', 'Object');
				if (ob) {
					out.set(ob.offset, ob);
				}
			}
			for (const child of collection.list('children', 'CollectionChild')) {
				visit(child.get('collection', 'Collection'), seen);
			}
		};
		visit(scene.get('master_collection', 'Collection'), new Set());
	} else {
		for (const base of scene.list('base', 'Base')) {
			const ob = base.get('object', 'Object');
			if (ob) {
				out.set(ob.offset, ob);
			}
		}
	}
	return [...out.values()].filter((ob) => !((ob.num('visibility_flag', 0, 0) | ob.num('restrictflag', 0, 0)) & OB_HIDE_RENDER));
}

const LA_LOCAL = 0;
const LA_SUN = 1;
const LA_SPOT = 2;
const LA_AREA = 4;
const LA_SHADOW = 1 << 0;
const LA_AREA_SQUARE = 0;
const LA_AREA_DISK = 4;
const LA_AREA_ELLIPSE = 5;
const OB_HIDE_CAMERA = 1 << 3;
const LA_SHAD_RAY = 1 << 13; // before 2.80
const IDP_INT = 1;
const IDP_GROUP = 6;
const IDP_BOOLEAN = 8;

// A child of an ID's (system) property group, e.g. idProperty(light, 'cycles', 'cast_shadow').
function idProperty(owner: BStruct, ...path: string[]): BStruct | null {
	const id = owner.sub('id');
	let prop = (id.has('system_properties') ? id.get('system_properties', 'IDProperty') : null) ?? id.get('properties', 'IDProperty');
	for (const name of path) {
		if (!prop || prop.num('type') !== IDP_GROUP) {
			return null;
		}
		prop = prop.sub('data').list('group', 'IDProperty').find((p) => p.str('name') === name) ?? null;
	}
	return prop;
}

function idBoolean(prop: BStruct | null, fallback: boolean): boolean {
	const type = prop?.num('type');
	return prop && (type === IDP_INT || type === IDP_BOOLEAN) ? prop.sub('data').num('val') !== 0 : fallback;
}

// LA_SHADOW after versioning_280 (ray shadows) and versioning_402 (Cycles' cast_shadow property).
function castsShadow(light: BStruct, version: number, engine: string): boolean {
	let shadow = (light.num('mode') & (LA_SHADOW | (version < 280 ? LA_SHAD_RAY : 0))) !== 0;
	if (version < 402 && !engine.startsWith('BLENDER_EEVEE')) {
		const cycles = idProperty(light, 'cycles');
		if (cycles) {
			shadow = idBoolean(idProperty(light, 'cycles', 'cast_shadow'), true);
		}
	}
	return shadow;
}

// OB_HIDE_CAMERA after versioning_300 (Cycles' cycles_visibility property).
function visibleToCamera(ob: BStruct, version: number): boolean {
	if (version < 300) {
		return idBoolean(idProperty(ob, 'cycles_visibility', 'camera'), true);
	}
	return !(ob.num('visibility_flag', 0, 0) & OB_HIDE_CAMERA);
}

// Constant Color * Strength of the Emission node feeding the light output (1 when absent or linked).
function lightNodeEmission(light: BStruct): { color: Vec3; strength: number } | null {
	const tree = light.get('nodetree', 'bNodeTree');
	if (!tree) {
		return null;
	}
	const emission = tree.list('nodes', 'bNode').find((n) => n.str('idname') === 'ShaderNodeEmission');
	if (!emission) {
		return null;
	}
	let color: Vec3 = [1, 1, 1];
	let strength = 1;
	for (const s of emission.list('inputs', 'bNodeSocket')) {
		const value = s.ptr('link') === 0n ? s.get('default_value') : null;
		if (!value) {
			continue;
		}
		if (s.str('identifier') === 'Color') {
			const v = value.nums('value');
			color = [v[0], v[1], v[2]];
		} else if (s.str('identifier') === 'Strength') {
			strength = value.num('value');
		}
	}
	return { color, strength };
}

// Color times watts (point / spot / area) or irradiance (sun), with the 2.80 light versioning
// (versioning_280.cc light_emission_unify) for older files.
function lightStrength(light: BStruct, version: number, engine: string): Vec3 {
	const type = light.num('type');
	let color: Vec3 = [light.num('r'), light.num('g'), light.num('b')];
	let energy: number;
	const nodes = light.num('use_nodes', 0, 0) ? lightNodeEmission(light) : null;
	if (version < 280) {
		energy = light.num('energy') * (type === LA_SUN ? 1 : 100);
		if (engine === 'CYCLES') {
			if (nodes) {
				energy = nodes.strength;
				color = nodes.color;
			} else {
				energy = type === LA_SUN ? 1 : 100;
			}
		}
	} else {
		energy = light.has('energy_new') ? light.num('energy_new') : light.num('energy');
		if (nodes) {
			energy *= nodes.strength;
			color = [color[0] * nodes.color[0], color[1] * nodes.color[1], color[2] * nodes.color[2]];
		}
	}
	energy *= 2 ** light.num('exposure', 0, 0);
	return [color[0] * energy, color[1] * energy, color[2] * energy];
}

function convertLight(ob: BStruct, light: BStruct, transform: Mat4, version: number, engine: string): LightDesc | BlendSun | null {
	const type = light.num('type');
	const strength = lightStrength(light, version, engine);
	const column = (c: number): Vec3 => [transform[c * 4], transform[c * 4 + 1], transform[c * 4 + 2]];
	const back = column(2);
	const direction: Vec3 = [-back[0], -back[1], -back[2]];
	if (type === LA_SUN) {
		const angle = light.has('sun_angle') ? light.num('sun_angle') : 2 * Math.atan(light.num('area_size'));
		const l = Math.hypot(...back) || 1;
		return { direction: [back[0] / l, back[1] / l, back[2] / l], irradiance: strength, angle };
	}
	// versioning_300.cc: before 3.5 the point / spot radius was area_size.
	const radius = version >= 306 && light.has('radius') ? light.num('radius') : light.num('area_size', 0, 0);
	const desc: LightDesc = {
		type: type === LA_SPOT ? 'spot' : type === LA_AREA ? 'area' : 'point',
		position: column(3),
		direction,
		power: strength,
		radius,
		spotAngle: light.num('spotsize', 0, Math.PI / 4),
		spotBlend: light.num('spotblend', 0, 0),
		sizeU: [0, 0, 0],
		sizeV: [0, 0, 0],
		ellipse: false,
		visibleToCamera: visibleToCamera(ob, version),
		castShadow: castsShadow(light, version, engine),
	};
	if (type === LA_AREA) {
		const shape = light.num('area_shape', 0, LA_AREA_SQUARE);
		const sizeU = light.num('area_size');
		const sizeV = shape === LA_AREA_SQUARE || shape === LA_AREA_DISK ? sizeU : light.num('area_sizey');
		const u = column(0);
		const v = column(1);
		desc.sizeU = [u[0] * sizeU, u[1] * sizeU, u[2] * sizeU];
		desc.sizeV = [v[0] * sizeV, v[1] * sizeV, v[2] * sizeV];
		desc.ellipse = shape === LA_AREA_DISK || shape === LA_AREA_ELLIPSE;
	} else if (type !== LA_LOCAL && type !== LA_SPOT) {
		return null; // hemi (removed in 2.80)
	}
	return desc;
}

// The mesh's texture space (BKE_mesh_texspace_calc for automatic ones, from the unmodified mesh).
function meshTexSpace(me: BStruct, mesh: PolyMesh): TexSpace {
	const auto = me.has('texspace_flag') ? me.num('texspace_flag') & 1 : me.num('texflag', 0, 1) & 1;
	if (!auto) {
		const location = me.has('texspace_location') ? me.nums('texspace_location') : me.nums('loc');
		const size = me.has('texspace_size') ? me.nums('texspace_size') : me.nums('size');
		return { location: [location[0], location[1], location[2]], size: [size[0] || 1, size[1] || 1, size[2] || 1] };
	}
	const min = [Infinity, Infinity, Infinity];
	const max = [-Infinity, -Infinity, -Infinity];
	const p = mesh.positions;
	for (let i = 0; i < p.length; i += 3) {
		for (let c = 0; c < 3; c++) {
			min[c] = Math.min(min[c], p[i + c]);
			max[c] = Math.max(max[c], p[i + c]);
		}
	}
	if (p.length === 0) {
		return { location: [0, 0, 0], size: [1, 1, 1] };
	}
	const location: Vec3 = [0, 1, 2].map((c) => (min[c] + max[c]) / 2) as Vec3;
	const size: Vec3 = [0, 1, 2].map((c) => {
		const s = (max[c] - min[c]) / 2;
		return s === 0 ? 1 : s < 0.00001 ? 0.00001 : s;
	}) as Vec3;
	return { location, size };
}

function cameraDesc(ob: BStruct, camera: BStruct, world: Mat4, render: BlendRenderSettings): CameraDesc {
	const aspect = render.width / render.height;
	const lens = camera.num('lens');
	const sensorX = camera.num('sensor_x');
	const sensorY = camera.num('sensor_y', 0, 24);
	const fit = camera.num('sensor_fit', 0, 0); // 0 auto, 1 horizontal, 2 vertical
	let tanHalfY: number;
	if (fit === 2) {
		tanHalfY = sensorY / 2 / lens;
	} else if (fit === 1 || aspect >= 1) {
		tanHalfY = sensorX / 2 / lens / aspect;
	} else {
		tanHalfY = sensorX / 2 / lens;
	}
	const m = mat4.multiply(Z_UP_TO_Y_UP, world);
	for (let c = 0; c < 3; c++) {
		const l = Math.hypot(m[c * 4], m[c * 4 + 1], m[c * 4 + 2]) || 1;
		for (let r = 0; r < 3; r++) {
			m[c * 4 + r] /= l;
		}
	}
	return { name: ob.idName, transform: m, yfov: 2 * Math.atan(tanHalfY), aspectRatio: aspect };
}

export function loadBlend(input: Uint8Array): BlendScene {
	const file = new BlendFile(input);
	const warnings: string[] = [];
	const scene = file.ids('SC')[0];
	if (!scene) {
		throw new Error('blend: no scene');
	}
	const r = scene.sub('r');
	const percent = r.num('size') / 100;
	const view = scene.sub('view_settings');
	const render: BlendRenderSettings = {
		width: Math.max(1, Math.round(r.num('xsch') * percent)),
		height: Math.max(1, Math.round(r.num('ysch') * percent)),
		viewTransform: view.str('view_transform'),
		look: view.str('look'),
		exposure: view.num('exposure', 0, 0),
		gamma: view.num('gamma', 0, 1),
	};

	const desc: SceneDesc = { meshes: [], materials: [], textures: [], instances: [], cameras: [], lights: [] };
	let sun: BlendSun | null = null;
	const engine = r.str('engine');
	const materials: (BStruct | null)[] = [];
	const materialIndex = new Map<string, number>();
	const perMesh = new Set<number>(); // materials reading Generated coordinates: one copy per texture space
	const materialOf = (ma: BStruct | null, me: BStruct, texspace: () => TexSpace): number => {
		const key = ma ? (perMesh.has(ma.offset) ? `${ma.offset}:${me.offset}` : `${ma.offset}`) : 'default';
		let index = materialIndex.get(key);
		if (index === undefined) {
			const m: MaterialDesc = { ...defaultMaterial(), name: ma?.idName ?? 'default' };
			if (ma) {
				const translated = translateMaterial(ma, texspace());
				warnings.push(...translated.warnings);
				m.graph = translated.graph;
				if (translated.usesGenerated && !perMesh.has(ma.offset)) {
					perMesh.add(ma.offset);
					return materialOf(ma, me, texspace);
				}
			}
			index = desc.materials.length;
			materialIndex.set(key, index);
			desc.materials.push(m);
			materials.push(ma);
		}
		return index;
	};

	const matrices = new Map<number, Mat4>();
	const sceneCamera = scene.get('camera', 'Object');
	for (const ob of sceneObjects(scene)) {
		const type = ob.num('type');
		const world = worldMatrix(ob, matrices);
		if (type === OB_LAMP) {
			const light = ob.get('data');
			const converted = light ? convertLight(ob, light, mat4.multiply(Z_UP_TO_Y_UP, world), file.version, engine) : null;
			if (converted && 'irradiance' in converted) {
				if (sun) {
					warnings.push(`${ob.idName}: only one sun light is supported`);
				}
				if (!sun || luminance(...converted.irradiance) > luminance(...sun.irradiance)) {
					sun = converted;
				}
			} else if (converted) {
				desc.lights!.push(converted);
			}
			continue;
		}
		if (type === OB_CAMERA) {
			const camera = ob.get('data');
			if (camera) {
				const c = cameraDesc(ob, camera, world, render);
				if (sceneCamera && sceneCamera.offset === ob.offset) {
					desc.cameras.unshift(c);
				} else {
					desc.cameras.push(c);
				}
			}
			continue;
		}
		if (type !== OB_MESH) {
			continue;
		}
		const me = ob.get('data', 'Mesh');
		if (!me) {
			continue;
		}
		let mesh = readMesh(me);
		const original = mesh;
		let space: TexSpace | null = null;
		const texspace = () => (space ??= meshTexSpace(me, original));
		let firstSubsurf = true;
		for (const md of ob.list('modifiers')) {
			const base = md.sub('modifier');
			if (md.type === 'SubsurfModifierData') {
				// versioning_280: before 2.80 only the first Subdivision Surface uses creases
				const flags = md.num('flags');
				const useCrease = file.version < 280 ? firstSubsurf : (flags & eSubsurfModifierFlag_UseCrease) !== 0;
				firstSubsurf = false;
				if (!(base.num('mode') & eModifierMode_Render)) {
					continue;
				}
				if (!useCrease) {
					mesh.edgeCrease = null;
				}
				if (md.num('subdivType', 0, 0) === 1) {
					mesh.edgeCrease = new Float32Array(mesh.edgeKeys.size).fill(1);
				}
				// versioning_280: without uv_smooth, eSubsurfModifierFlag_SubsurfUv means Keep Corners
				const smoothUV = md.has('uv_smooth') ? md.num('uv_smooth') !== 0 : (flags & eSubsurfModifierFlag_SubsurfUv) !== 0;
				mesh = subdivide(mesh, md.num('renderLevels'), !(flags & eSubsurfModifierFlag_UseRecursiveSubdivision), smoothUV);
			} else if (!(base.num('mode') & eModifierMode_Render)) {
				continue;
			} else if (md.type === 'NodesModifierData' && /smooth by angle/i.test(md.get('node_group')?.idName ?? base.str('name'))) {
				smoothByAngle(mesh, (30 * Math.PI) / 180);
			} else if (md.type === 'BevelModifierData') {
				// No bevel geometry: the faces it separates shade flat, like the bevelled result away from the edges.
				smoothByAngle(mesh, md.num('bevel_angle', 0, Math.PI / 6));
				warnings.push(`${ob.idName}: Bevel is approximated by sharp edges`);
			} else {
				warnings.push(`${ob.idName}: ${md.type} (${base.str('name')}) is not supported`);
			}
		}

		const slots = Math.max(ob.num('totcol'), me.num('totcol'), 1);
		const obMats = ob.ptrs('mat', ob.num('totcol'));
		const meMats = me.ptrs('mat', me.num('totcol'));
		const matbits = ob.num('totcol') > 0 ? ob.resolve('matbits') : null;
		const slotMaterial = (slot: number) => {
			const fromObject = matbits && slot < ob.num('totcol') && file.bytes[matbits.offset + slot];
			const address = fromObject ? obMats[slot] : (meMats[slot] ?? 0n);
			return materialOf(file.at(address, 'Material'), me, texspace);
		};
		const transform = mat4.multiply(Z_UP_TO_Y_UP, world);
		for (const tri of triangulate(mesh, true)) {
			if (tri.indices.length === 0) {
				continue;
			}
			desc.instances.push({ mesh: desc.meshes.length, transform });
			desc.meshes.push({
				name: me.idName,
				positions: tri.positions,
				normals: tri.normals,
				tangents: tri.tangents,
				uv0: tri.uv,
				uv1: null,
				indices: tri.indices,
				material: slotMaterial(Math.min(Math.max(tri.material, 0), slots - 1)),
			});
		}
	}
	return { file, scene: desc, sun, world: scene.get('world', 'World'), materials, render, warnings: [...new Set(warnings)] };
}
