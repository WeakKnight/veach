// Byte layouts of the structs in shaders/Scene/SceneTypes.slang. Keep both files in sync.
import type { CompiledMaterial } from '../material/Compile';
import type { TextureSampling } from '../material/Evaluate';
import type { Mat4, Vec3 } from '../math/Math';
import type { LightDesc } from '../scene/Scene';
import { materialShadeCapacities, materialStackCapacity, materialLightCapacity } from './MaterialCapacity';

export const INSTANCE_BYTES = 128;
export const VERTEX_BYTES = 64;
export const TEXTURE_REF_BYTES = 32;
export const MATERIAL_HEADER_WORDS = 2; // uint4
export const LIGHT_BYTES = 128;
export const FRAME_UNIFORM_BYTES = 224;
export const ACCUM_BYTES_PER_PIXEL = 48; // radiance, albedo, normal (float4 each)

export const INSTANCE_FLAG_ALPHA_TESTED = 1;
export const INSTANCE_FLAG_EMISSIVE = 2;

export const LIGHT_ANALYTIC = 0x80000000;
export const LIGHT_HIDDEN_FROM_CAMERA = 0x100;
export const LIGHT_ELLIPSE = 0x200;
export const LIGHT_NO_SHADOW = 0x400;
export const LIGHT_TYPE_POINT = 0;
export const LIGHT_TYPE_SPOT = 1;
export const LIGHT_TYPE_AREA = 2;

// One analytic light in the EmissiveTriangle slot layout (see SceneTypes.slang).
export function packAnalyticLight(f32: Float32Array, u32: Uint32Array, at: number, l: LightDesc, pdf: number, cdf: number): void {
	const norm = (v: Vec3) => Math.hypot(...v);
	const type = l.type === 'area' ? LIGHT_TYPE_AREA : l.type === 'spot' ? LIGHT_TYPE_SPOT : LIGHT_TYPE_POINT;
	let size = l.radius;
	let scale: number;
	if (l.type === 'area') {
		size = norm(l.sizeU) * norm(l.sizeV) * (l.ellipse ? Math.PI / 4 : 1);
		scale = size > 0 ? 1 / (Math.PI * size) : 0;
	} else {
		scale = l.radius > 0 ? 1 / (4 * Math.PI * Math.PI * l.radius * l.radius) : 1 / (4 * Math.PI);
	}
	const dirLength = norm(l.direction) || 1;
	const cosHalf = Math.cos(l.spotAngle / 2);
	f32.set([...l.position, size], at);
	f32.set([l.power[0] * scale, l.power[1] * scale, l.power[2] * scale, pdf], at + 4);
	f32.set([l.direction[0] / dirLength, l.direction[1] / dirLength, l.direction[2] / dirLength, cdf], at + 8);
	f32.set([...l.sizeU, 0], at + 12);
	u32[at + 15] = (LIGHT_ANALYTIC | (l.visibleToCamera ? 0 : LIGHT_HIDDEN_FROM_CAMERA) | (l.ellipse ? LIGHT_ELLIPSE : 0) | (l.castShadow ? 0 : LIGHT_NO_SHADOW) | type) >>> 0;
	f32.set([...l.sizeV, cosHalf], at + 16);
	f32.set([l.spotBlend > 0 ? 1 / ((1 - cosHalf) * l.spotBlend) : 0, 0, 0, 0], at + 20);
}

export const TEXTURE_FLAG_VALID = 1;
export const TEXTURE_FLAG_SRGB = 2;
export const TEXTURE_FLAG_TEXCOORD1 = 4;

export const MATERIAL_FLAG_DOUBLE_SIDED = 1;
export const PROGRAM_NONE = 0xffffffff;

export const FRAME_FLAG_ENVIRONMENT = 1;
export const FRAME_FLAG_SUN = 2;
export const FRAME_FLAG_ENV_IMPORTANCE = 4;
export const FRAME_FLAG_ENV_VISIBLE = 8;

export enum DebugMode {
	None = 0,
	Albedo = 1,
	ShadingNormal = 2,
	GeometryNormal = 3,
	UV = 4,
	Instance = 5,
	Material = 6,
	Traversal = 7,
	Emission = 8,
	VirtualTexture = 9,
}

export enum Tonemapper {
	None = 0,
	ACESFilmic = 1, // Narkowicz's ACES 1.x fit
	ACES2 = 2, // ACES 2.0 SDR 100 nit Rec.709 output transform, baked into a 3D LUT
}

export interface TextureSlot {
	pageTableOffset: number;
	log2W: number;
	log2H: number;
	levels: number;
}

// Writes rows 0..2 of a column-major affine matrix as three float4.
export function writeAffineRows(f32: Float32Array, at: number, m: Mat4): void {
	for (let r = 0; r < 3; r++) {
		f32[at + r * 4 + 0] = m[r];
		f32[at + r * 4 + 1] = m[4 + r];
		f32[at + r * 4 + 2] = m[8 + r];
		f32[at + r * 4 + 3] = m[12 + r];
	}
}

export interface InstanceRecord {
	objectToWorld: Mat4;
	worldToObject: Mat4;
	blasNodeOffset: number;
	blasTriOffset: number;
	indexOffset: number;
	vertexOffset: number;
	materialIndex: number;
	flags: number;
	lightOffset: number;
	triCount: number;
}

export function packInstance(buffer: ArrayBuffer, index: number, r: InstanceRecord): void {
	const f32 = new Float32Array(buffer, index * INSTANCE_BYTES, INSTANCE_BYTES / 4);
	const u32 = new Uint32Array(buffer, index * INSTANCE_BYTES, INSTANCE_BYTES / 4);
	writeAffineRows(f32, 0, r.objectToWorld);
	writeAffineRows(f32, 12, r.worldToObject);
	u32[24] = r.blasNodeOffset;
	u32[25] = r.blasTriOffset;
	u32[26] = r.indexOffset;
	u32[27] = r.vertexOffset;
	u32[28] = r.materialIndex;
	u32[29] = r.flags;
	u32[30] = r.lightOffset;
	u32[31] = r.triCount;
}

// Writes vertexCount vertices starting at vertex `first`.
export function packVertices(
	f32: Float32Array,
	first: number,
	positions: Float32Array,
	normals: Float32Array | null,
	tangents: Float32Array | null,
	uv0: Float32Array | null,
	uv1: Float32Array | null,
): void {
	const count = positions.length / 3;
	for (let i = 0; i < count; i++) {
		const o = (first + i) * (VERTEX_BYTES / 4);
		f32[o + 0] = positions[i * 3];
		f32[o + 1] = positions[i * 3 + 1];
		f32[o + 2] = positions[i * 3 + 2];
		f32[o + 3] = uv0 ? uv0[i * 2] : 0;
		f32[o + 4] = normals ? normals[i * 3] : 0;
		f32[o + 5] = normals ? normals[i * 3 + 1] : 0;
		f32[o + 6] = normals ? normals[i * 3 + 2] : 0;
		f32[o + 7] = uv0 ? uv0[i * 2 + 1] : 0;
		if (tangents) {
			f32[o + 8] = tangents[i * 4];
			f32[o + 9] = tangents[i * 4 + 1];
			f32[o + 10] = tangents[i * 4 + 2];
			f32[o + 11] = tangents[i * 4 + 3];
		}
		f32[o + 12] = uv1 ? uv1[i * 2] : 0;
		f32[o + 13] = uv1 ? uv1[i * 2 + 1] : 0;
	}
}

// A TextureRef; all zero (not valid) when the texture has no virtual texture.
function packTextureRef(f32: Float32Array, u32: Uint32Array, at: number, t: TextureSampling, slot: TextureSlot | null): void {
	if (!slot) {
		u32.fill(0, at, at + 8);
		return;
	}
	let flags = TEXTURE_FLAG_VALID;
	if (t.colorspace === 'srgb_texture') flags |= TEXTURE_FLAG_SRGB;
	if (t.uvindex === 1) flags |= TEXTURE_FLAG_TEXCOORD1;
	flags |= (t.wrapS & 3) << 8;
	flags |= (t.wrapT & 3) << 10;
	flags |= (slot.levels & 15) << 12;
	flags |= (slot.log2W & 15) << 16;
	flags |= (slot.log2H & 15) << 20;
	u32[at + 0] = flags;
	u32[at + 1] = slot.pageTableOffset;
	u32[at + 2] = 0;
	f32[at + 3] = t.rotation;
	f32[at + 4] = t.scale[0];
	f32[at + 5] = t.scale[1];
	f32[at + 6] = t.offset[0];
	f32[at + 7] = t.offset[1];
}

// gMaterialData, in uint4 units:
//   [0, 2 × materials)  MaterialHeader per material
//   then per material   texture table (TextureRef, 2 each), constant pool (float4 each)
//   then                code blocks, one per distinct bytecode (materials differing only in
//                       constants and textures share one)
export function packMaterialData(materials: readonly CompiledMaterial[], slotOf: (source: number) => TextureSlot | null): Uint32Array {
	const shadeCapacities = materialShadeCapacities(materials);
	let size = materials.length * MATERIAL_HEADER_WORDS;
	const dataBase = materials.map((m) => {
		const base = size;
		size += m.textures.length * 2 + m.constants.length / 4;
		return base;
	});
	const blocks = new Map<string, number>();
	const codeBase = materials.map((m) => {
		const key = m.code.join(',');
		let base = blocks.get(key);
		if (base === undefined) {
			base = size;
			blocks.set(key, base);
			size += m.code.length / 4;
		}
		return base;
	});

	const u32 = new Uint32Array(Math.max(size, 1) * 4);
	const f32 = new Float32Array(u32.buffer);
	materials.forEach((m, i) => {
		const program = (offset: number) => (offset < 0 ? PROGRAM_NONE : codeBase[i] + offset);
		const constantBase = dataBase[i] + m.textures.length * 2;
		const h = i * MATERIAL_HEADER_WORDS * 4;
		u32.set([program(m.surface), program(m.opacity), program(m.emission), (m.doubleSided ? MATERIAL_FLAG_DOUBLE_SIDED : 0) | ((m.alphaMode & 3) << 8) | (shadeCapacities[i] << 16)
			| (materialStackCapacity(m.programStackSizes.surface) << 21) | (materialLightCapacity(m) << 26)], h);
		u32.set([dataBase[i], constantBase, 0, m.debugTexture < 0 ? PROGRAM_NONE : m.debugTexture], h + 4);
		f32[h + 6] = m.alphaCutoff;
		m.textures.forEach((t, k) => packTextureRef(f32, u32, (dataBase[i] + k * 2) * 4, t, slotOf(t.source)));
		f32.set(m.constants, constantBase * 4);
		u32.set(m.code, codeBase[i] * 4);
	});
	return u32;
}

export interface FrameUniformData {
	cameraPosition: [number, number, number];
	lensRadius: number;
	cameraRight: [number, number, number];
	focusDistance: number;
	cameraUp: [number, number, number];
	cameraForward: [number, number, number];
	width: number;
	height: number;
	frameIndex: number;
	seed: number;
	maxBounces: number;
	debugMode: DebugMode;
	flags: number;
	tonemapper: Tonemapper;
	instanceCount: number;
	lightCount: number;
	tlasPrimOffset: number;
	analyticLightCount: number;
	envCdfWidth: number;
	envCdfHeight: number;
	sunDirection: [number, number, number];
	sunCosAngle: number;
	sunRadiance: [number, number, number];
	sunSolidAngle: number;
	envIntensity: number;
	envRotation: number;
	preExposure: number; // scale applied to radiance before accumulation
	fireflyClamp: number;
	background: [number, number, number];
	vtTilesPerRow: number;
	vtPageTableWidth: number;
	vtFeedbackJitter: number; // x | y << 16
	vtFeedbackShift: number;
	vtInvPhysicalSize: number;
	pixelSpreadAngle: number;
	vtMipBias: number;
}

export function packFrameUniforms(buffer: ArrayBuffer, d: FrameUniformData): void {
	const f32 = new Float32Array(buffer, 0, FRAME_UNIFORM_BYTES / 4);
	const u32 = new Uint32Array(buffer, 0, FRAME_UNIFORM_BYTES / 4);
	f32.set([...d.cameraPosition, d.lensRadius], 0);
	f32.set([...d.cameraRight, d.focusDistance], 4);
	f32.set([...d.cameraUp, 0], 8);
	f32.set([...d.cameraForward, 0], 12);
	u32.set([d.width, d.height, d.frameIndex, d.seed >>> 0], 16);
	u32.set([d.maxBounces, d.debugMode, d.flags, d.tonemapper], 20);
	u32.set([d.instanceCount, d.lightCount, d.tlasPrimOffset, d.analyticLightCount], 24);
	u32.set([d.envCdfWidth, d.envCdfHeight, 0, 0], 28);
	f32.set([...d.sunDirection, d.sunCosAngle], 32);
	f32.set([...d.sunRadiance, d.sunSolidAngle], 36);
	f32.set([d.envIntensity, d.envRotation, d.preExposure, d.fireflyClamp], 40);
	f32.set([...d.background, 0], 44);
	u32.set([d.vtTilesPerRow, d.vtPageTableWidth, d.vtFeedbackJitter, d.vtFeedbackShift], 48);
	f32.set([d.vtInvPhysicalSize, d.pixelSpreadAngle, d.vtMipBias, 0], 52);
}
