// glTF 2.0 loader (.gltf / .glb) producing a SceneDesc.
import { gltfMaterialGraph } from '../material/GLTFMaterial';
import { mat4, type Mat4, type Vec3 } from '../math/Math';
import {
	AlphaMode,
	WrapMode,
	defaultMaterial,
	type CameraDesc,
	type InstanceDesc,
	type MaterialDesc,
	type MeshDesc,
	type SceneDesc,
	type TextureBinding,
	type TextureSource,
} from '../scene/Scene';
import { generateTangents } from './Tangents';

/* eslint-disable @typescript-eslint/no-explicit-any */
type Json = any;

export interface GLTFLoadOptions {
	// Resolves external buffer / image URIs (relative to the .gltf file).
	resolveUri?: (uri: string) => Promise<ArrayBuffer>;
	// Decode images into ImageBitmaps (requires createImageBitmap). Default: true when available.
	decodeImages?: boolean;
}

const SUPPORTED_EXTENSIONS = new Set([
	'KHR_materials_emissive_strength',
	'KHR_materials_ior',
	'KHR_materials_transmission',
	'KHR_materials_clearcoat',
	'KHR_materials_specular',
	'KHR_materials_sheen',
	'KHR_materials_anisotropy',
	'KHR_materials_unlit',
	'KHR_materials_volume',
	'KHR_materials_dispersion',
	'KHR_materials_iridescence',
	'KHR_materials_pbrSpecularGlossiness',
	'KHR_texture_transform',
	'KHR_mesh_quantization',
	'KHR_lights_punctual',
]);

const GLB_MAGIC = 0x46546c67;
const CHUNK_JSON = 0x4e4f534a;
const CHUNK_BIN = 0x004e4942;

const COMPONENT_INFO: Record<number, { bytes: number; read: (v: DataView, o: number) => number; normalize: number }> = {
	5120: { bytes: 1, read: (v, o) => v.getInt8(o), normalize: 127 },
	5121: { bytes: 1, read: (v, o) => v.getUint8(o), normalize: 255 },
	5122: { bytes: 2, read: (v, o) => v.getInt16(o, true), normalize: 32767 },
	5123: { bytes: 2, read: (v, o) => v.getUint16(o, true), normalize: 65535 },
	5125: { bytes: 4, read: (v, o) => v.getUint32(o, true), normalize: 4294967295 },
	5126: { bytes: 4, read: (v, o) => v.getFloat32(o, true), normalize: 0 },
};

const TYPE_COMPONENTS: Record<string, number> = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT2: 4, MAT3: 9, MAT4: 16 };

function decodeDataUri(uri: string): ArrayBuffer {
	const comma = uri.indexOf(',');
	const header = uri.slice(0, comma);
	const payload = uri.slice(comma + 1);
	if (header.endsWith(';base64')) {
		const binary = atob(payload);
		const bytes = new Uint8Array(binary.length);
		for (let i = 0; i < binary.length; i++) {
			bytes[i] = binary.charCodeAt(i);
		}
		return bytes.buffer;
	}
	return new TextEncoder().encode(decodeURIComponent(payload)).buffer as ArrayBuffer;
}

function parseContainer(data: ArrayBuffer): { json: Json; bin: ArrayBuffer | null } {
	const view = new DataView(data);
	if (data.byteLength >= 12 && view.getUint32(0, true) === GLB_MAGIC) {
		const length = view.getUint32(8, true);
		let json: Json = null;
		let bin: ArrayBuffer | null = null;
		let offset = 12;
		while (offset + 8 <= length) {
			const chunkLength = view.getUint32(offset, true);
			const chunkType = view.getUint32(offset + 4, true);
			const start = offset + 8;
			if (chunkType === CHUNK_JSON) {
				json = JSON.parse(new TextDecoder().decode(new Uint8Array(data, start, chunkLength)));
			} else if (chunkType === CHUNK_BIN && !bin) {
				bin = data.slice(start, start + chunkLength);
			}
			offset = start + ((chunkLength + 3) & ~3);
		}
		if (!json) {
			throw new Error('glb: missing JSON chunk');
		}
		return { json, bin };
	}
	return { json: JSON.parse(new TextDecoder().decode(data)), bin: null };
}

function wrapMode(gl: number | undefined): WrapMode {
	switch (gl) {
		case 33071:
			return WrapMode.Clamp;
		case 33648:
			return WrapMode.Mirror;
		default:
			return WrapMode.Repeat;
	}
}

class GLTFParser {
	private buffers: ArrayBuffer[] = [];

	constructor(
		private readonly json: Json,
		private readonly bin: ArrayBuffer | null,
		private readonly options: GLTFLoadOptions,
	) {}

	async parse(): Promise<SceneDesc> {
		const json = this.json;
		const version = String(json.asset?.version ?? '2.0');
		if (!version.startsWith('2')) {
			throw new Error(`glTF: unsupported version ${version}`);
		}
		for (const ext of json.extensionsRequired ?? []) {
			if (!SUPPORTED_EXTENSIONS.has(ext)) {
				throw new Error(`glTF: required extension ${ext} is not supported`);
			}
		}

		this.buffers = await Promise.all((json.buffers ?? []).map((b: Json, i: number) => this.loadBuffer(b, i)));

		const textures = await this.loadTextures();
		const materials = (json.materials ?? []).map((m: Json) => this.parseMaterial(m));
		const { meshes, meshPrimitives } = this.parseMeshes();
		const instances: InstanceDesc[] = [];
		const cameras: CameraDesc[] = [];

		const visit = (nodeIndex: number, parent: Mat4, depth: number) => {
			if (depth > 256) {
				throw new Error('glTF: node hierarchy too deep (cycle?)');
			}
			const node = json.nodes[nodeIndex];
			const local = node.matrix
				? new Float32Array(node.matrix)
				: mat4.fromTRS(node.translation ?? [0, 0, 0], node.rotation ?? [0, 0, 0, 1], node.scale ?? [1, 1, 1]);
			const world = mat4.multiply(parent, local);
			if (node.mesh !== undefined) {
				for (const mesh of meshPrimitives[node.mesh]) {
					instances.push({ mesh, transform: world });
				}
			}
			if (node.camera !== undefined) {
				const cam = json.cameras?.[node.camera];
				if (cam?.type === 'perspective' && cam.perspective) {
					cameras.push({
						name: cam.name ?? node.name ?? `camera${cameras.length}`,
						transform: world,
						yfov: cam.perspective.yfov,
						aspectRatio: cam.perspective.aspectRatio,
					});
				}
			}
			for (const child of node.children ?? []) {
				visit(child, world, depth + 1);
			}
		};

		const sceneIndex = json.scene ?? 0;
		let roots: number[] | undefined = json.scenes?.[sceneIndex]?.nodes;
		if (!roots) {
			const isChild = new Set<number>();
			(json.nodes ?? []).forEach((n: Json) => (n.children ?? []).forEach((c: number) => isChild.add(c)));
			roots = (json.nodes ?? []).map((_: Json, i: number) => i).filter((i: number) => !isChild.has(i));
		}
		for (const root of roots!) {
			visit(root, mat4.identity(), 0);
		}

		return { meshes, materials, textures, instances, cameras };
	}

	private async loadBuffer(buffer: Json, index: number): Promise<ArrayBuffer> {
		if (buffer.uri === undefined) {
			if (index === 0 && this.bin) {
				return this.bin;
			}
			throw new Error(`glTF: buffer ${index} has no data`);
		}
		if (buffer.uri.startsWith('data:')) {
			return decodeDataUri(buffer.uri);
		}
		if (!this.options.resolveUri) {
			throw new Error(`glTF: external buffer "${buffer.uri}" but no resolver`);
		}
		return this.options.resolveUri(decodeURIComponent(buffer.uri));
	}

	private bufferViewBytes(index: number): Uint8Array {
		const bv = this.json.bufferViews[index];
		if (bv.extensions?.EXT_meshopt_compression) {
			throw new Error('glTF: EXT_meshopt_compression is not supported');
		}
		return new Uint8Array(this.buffers[bv.buffer], bv.byteOffset ?? 0, bv.byteLength);
	}

	// Reads an accessor into a tightly packed Float32Array (normalized integers are mapped to [0,1]/[-1,1]).
	readAccessor(index: number): { data: Float32Array; components: number; count: number } {
		const acc = this.json.accessors[index];
		const components = TYPE_COMPONENTS[acc.type];
		const info = COMPONENT_INFO[acc.componentType];
		if (!components || !info) {
			throw new Error(`glTF: unsupported accessor type ${acc.type}/${acc.componentType}`);
		}
		const count: number = acc.count;
		const out = new Float32Array(count * components);
		const scale = acc.normalized && info.normalize ? 1 / info.normalize : 1;
		const signed = acc.componentType === 5120 || acc.componentType === 5122;

		const readInto = (bufferView: number, byteOffset: number, n: number, write: (i: number, c: number, v: number) => void) => {
			const bv = this.json.bufferViews[bufferView];
			const bytes = this.bufferViewBytes(bufferView);
			const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
			const elementBytes = info.bytes * components;
			const stride = bv.byteStride ?? elementBytes;
			for (let i = 0; i < n; i++) {
				const base = byteOffset + i * stride;
				for (let c = 0; c < components; c++) {
					let v = info.read(view, base + c * info.bytes) * scale;
					if (acc.normalized && signed) {
						v = Math.max(v, -1);
					}
					write(i, c, v);
				}
			}
		};

		if (acc.bufferView !== undefined) {
			readInto(acc.bufferView, acc.byteOffset ?? 0, count, (i, c, v) => (out[i * components + c] = v));
		}
		if (acc.sparse) {
			const s = acc.sparse;
			const idxInfo = COMPONENT_INFO[s.indices.componentType];
			const idxBytes = this.bufferViewBytes(s.indices.bufferView);
			const idxView = new DataView(idxBytes.buffer, idxBytes.byteOffset, idxBytes.byteLength);
			const targets: number[] = [];
			for (let i = 0; i < s.count; i++) {
				targets.push(idxInfo.read(idxView, (s.indices.byteOffset ?? 0) + i * idxInfo.bytes));
			}
			readInto(s.values.bufferView, s.values.byteOffset ?? 0, s.count, (i, c, v) => (out[targets[i] * components + c] = v));
		}
		return { data: out, components, count };
	}

	private readIndices(index: number): Uint32Array {
		const acc = this.json.accessors[index];
		if (acc.bufferView === undefined || acc.sparse || acc.componentType === 5126) {
			return Uint32Array.from(this.readAccessor(index).data);
		}
		const bytes = this.bufferViewBytes(acc.bufferView);
		const offset = bytes.byteOffset + (acc.byteOffset ?? 0);
		const count: number = acc.count;
		switch (acc.componentType) {
			case 5121:
				return Uint32Array.from(new Uint8Array(bytes.buffer, offset, count));
			case 5123:
				return offset % 2 === 0
					? Uint32Array.from(new Uint16Array(bytes.buffer, offset, count))
					: Uint32Array.from(this.readAccessor(index).data);
			default:
				return offset % 4 === 0
					? new Uint32Array(bytes.buffer.slice(offset, offset + count * 4))
					: Uint32Array.from(this.readAccessor(index).data);
		}
	}

	private parseMeshes(): { meshes: MeshDesc[]; meshPrimitives: number[][] } {
		const meshes: MeshDesc[] = [];
		const meshPrimitives: number[][] = [];
		for (const [meshIndex, mesh] of (this.json.meshes ?? []).entries()) {
			const ids: number[] = [];
			for (const [primIndex, prim] of mesh.primitives.entries()) {
				if (prim.extensions?.KHR_draco_mesh_compression) {
					throw new Error('glTF: KHR_draco_mesh_compression is not supported');
				}
				const mode = prim.mode ?? 4;
				if (mode < 4 || prim.attributes.POSITION === undefined) {
					continue; // points / lines
				}
				const attr = prim.attributes;
				const positions = this.readAccessor(attr.POSITION).data;
				const vertexCount = positions.length / 3;
				let indices = prim.indices !== undefined ? this.readIndices(prim.indices) : Uint32Array.from({ length: vertexCount }, (_, i) => i);
				if (mode === 5) {
					indices = stripToList(indices);
				} else if (mode === 6) {
					indices = fanToList(indices);
				}
				indices = removeDegenerate(indices, vertexCount);
				if (indices.length === 0) {
					continue;
				}

				const normals = attr.NORMAL !== undefined ? this.readAccessor(attr.NORMAL).data : null;
				const uv0 = attr.TEXCOORD_0 !== undefined ? this.readAccessor(attr.TEXCOORD_0).data : null;
				const uv1 = attr.TEXCOORD_1 !== undefined ? this.readAccessor(attr.TEXCOORD_1).data : null;
				let tangents = attr.TANGENT !== undefined ? this.readAccessor(attr.TANGENT).data : null;

				const material = prim.material ?? -1;
				const normalTex = material >= 0 ? this.json.materials?.[material]?.normalTexture : undefined;
				if (!tangents && normals && normalTex) {
					const texCoord = normalTex.extensions?.KHR_texture_transform?.texCoord ?? normalTex.texCoord ?? 0;
					const uv = texCoord === 1 ? uv1 : uv0;
					if (uv) {
						tangents = generateTangents(positions, normals, uv, indices);
					}
				}

				ids.push(meshes.length);
				meshes.push({
					name: `${mesh.name ?? `mesh${meshIndex}`}/${primIndex}`,
					positions,
					normals,
					tangents,
					uv0,
					uv1,
					indices,
					material,
				});
			}
			meshPrimitives.push(ids);
		}
		return { meshes, meshPrimitives };
	}

	private async loadTextures(): Promise<TextureSource[]> {
		const json = this.json;
		const decode = this.options.decodeImages ?? typeof createImageBitmap === 'function';
		const images: Promise<ImageBitmap | null>[] = (json.images ?? []).map(async (img: Json) => {
			if (!decode) {
				return null;
			}
			try {
				let bytes: ArrayBuffer | Uint8Array;
				if (img.bufferView !== undefined) {
					bytes = this.bufferViewBytes(img.bufferView);
				} else if (img.uri?.startsWith('data:')) {
					bytes = decodeDataUri(img.uri);
				} else if (img.uri && this.options.resolveUri) {
					bytes = await this.options.resolveUri(decodeURIComponent(img.uri));
				} else {
					return null;
				}
				const blob = new Blob([bytes as BlobPart], { type: img.mimeType ?? '' });
				return await createImageBitmap(blob, { colorSpaceConversion: 'none', premultiplyAlpha: 'none' });
			} catch (e) {
				console.warn(`glTF: failed to decode image ${img.name ?? img.uri ?? ''}`, e);
				return null;
			}
		});
		const decoded = await Promise.all(images);
		// One TextureSource per glTF texture: the sampler lives in the TextureBinding.
		return (json.textures ?? []).map((tex: Json, i: number) => {
			const source = tex.source ?? tex.extensions?.EXT_texture_webp?.source ?? tex.extensions?.KHR_texture_basisu?.source;
			return { name: tex.name ?? `texture${i}`, image: source !== undefined ? decoded[source] ?? null : null };
		});
	}

	private textureBinding(info: Json | undefined): TextureBinding | undefined {
		if (!info || info.index === undefined) {
			return undefined;
		}
		const tex = this.json.textures?.[info.index];
		if (!tex) {
			return undefined;
		}
		const sampler = tex.sampler !== undefined ? this.json.samplers?.[tex.sampler] : undefined;
		const transform = info.extensions?.KHR_texture_transform;
		return {
			source: info.index,
			texCoord: (transform?.texCoord ?? info.texCoord ?? 0) === 1 ? 1 : 0,
			wrapS: wrapMode(sampler?.wrapS),
			wrapT: wrapMode(sampler?.wrapT),
			offset: transform?.offset ?? [0, 0],
			scale: transform?.scale ?? [1, 1],
			rotation: transform?.rotation ?? 0,
		};
	}

	private parseMaterial(m: Json): MaterialDesc {
		const out = defaultMaterial();
		const pbr = m.pbrMetallicRoughness ?? {};
		const ext = m.extensions ?? {};
		out.name = m.name ?? '';
		out.graph = gltfMaterialGraph(m, (info) => this.textureBinding(info));
		out.baseColor = (pbr.baseColorFactor ?? [1, 1, 1, 1]) as [number, number, number, number];
		out.metallic = pbr.metallicFactor ?? 1;
		out.roughness = pbr.roughnessFactor ?? 1;
		out.textures.baseColor = this.textureBinding(pbr.baseColorTexture);
		out.textures.metallicRoughness = this.textureBinding(pbr.metallicRoughnessTexture);
		out.textures.normal = this.textureBinding(m.normalTexture);
		out.normalScale = m.normalTexture?.scale ?? 1;
		out.textures.emissive = this.textureBinding(m.emissiveTexture);
		const strength = ext.KHR_materials_emissive_strength?.emissiveStrength ?? 1;
		const emissive = (m.emissiveFactor ?? [0, 0, 0]) as Vec3;
		out.emission = [emissive[0] * strength, emissive[1] * strength, emissive[2] * strength];
		out.alphaMode = m.alphaMode === 'MASK' ? AlphaMode.Mask : m.alphaMode === 'BLEND' ? AlphaMode.Blend : AlphaMode.Opaque;
		out.alphaCutoff = m.alphaCutoff ?? 0.5;
		out.doubleSided = !!m.doubleSided;

		out.ior = ext.KHR_materials_ior?.ior ?? 1.5;
		if (ext.KHR_materials_transmission) {
			out.transmission = ext.KHR_materials_transmission.transmissionFactor ?? 0;
			out.textures.transmission = this.textureBinding(ext.KHR_materials_transmission.transmissionTexture);
		}
		if (ext.KHR_materials_clearcoat) {
			const cc = ext.KHR_materials_clearcoat;
			out.clearcoat = cc.clearcoatFactor ?? 0;
			out.clearcoatRoughness = cc.clearcoatRoughnessFactor ?? 0;
			out.textures.clearcoat = this.textureBinding(cc.clearcoatTexture);
			out.textures.clearcoatRoughness = this.textureBinding(cc.clearcoatRoughnessTexture);
		}
		if (ext.KHR_materials_specular) {
			out.specularWeight = ext.KHR_materials_specular.specularFactor ?? 1;
			out.specularColor = ext.KHR_materials_specular.specularColorFactor ?? [1, 1, 1];
		}
		if (ext.KHR_materials_volume) {
			const volume = ext.KHR_materials_volume;
			out.thinWalled = !((volume.thicknessFactor ?? 0) > 0);
			out.attenuationColor = volume.attenuationColor ?? [1, 1, 1];
			out.attenuationDistance = volume.attenuationDistance ?? Infinity;
		}
		out.dispersion = ext.KHR_materials_dispersion?.dispersion ?? 0;
		if (ext.KHR_materials_sheen) {
			out.sheenColor = ext.KHR_materials_sheen.sheenColorFactor ?? [0, 0, 0];
			out.sheenRoughness = ext.KHR_materials_sheen.sheenRoughnessFactor ?? 0;
		}
		if (ext.KHR_materials_anisotropy) {
			out.anisotropy = ext.KHR_materials_anisotropy.anisotropyStrength ?? 0;
			out.anisotropyRotation = ext.KHR_materials_anisotropy.anisotropyRotation ?? 0;
		}
		if (ext.KHR_materials_iridescence) {
			const iridescence = ext.KHR_materials_iridescence;
			out.iridescence = iridescence.iridescenceFactor ?? 0;
			out.iridescenceIor = iridescence.iridescenceIor ?? 1.3;
			out.iridescenceThickness = iridescence.iridescenceThicknessMaximum ?? 400;
		}
		if (ext.KHR_materials_unlit) {
			// Unlit surfaces emit their base color and reflect nothing.
			out.emission = [out.baseColor[0], out.baseColor[1], out.baseColor[2]];
			out.textures.emissive = out.textures.baseColor;
			out.baseColor = [0, 0, 0, out.baseColor[3]];
			out.metallic = 0;
			out.specularWeight = 0;
		}
		return out;
	}
}

function stripToList(strip: Uint32Array): Uint32Array {
	const out: number[] = [];
	for (let i = 0; i + 2 < strip.length; i++) {
		if (i & 1) {
			out.push(strip[i + 1], strip[i], strip[i + 2]);
		} else {
			out.push(strip[i], strip[i + 1], strip[i + 2]);
		}
	}
	return Uint32Array.from(out);
}

function fanToList(fan: Uint32Array): Uint32Array {
	const out: number[] = [];
	for (let i = 1; i + 1 < fan.length; i++) {
		out.push(fan[0], fan[i], fan[i + 1]);
	}
	return Uint32Array.from(out);
}

function removeDegenerate(indices: Uint32Array, vertexCount: number): Uint32Array {
	const triCount = Math.floor(indices.length / 3);
	let keep = 0;
	const out = new Uint32Array(triCount * 3);
	for (let t = 0; t < triCount; t++) {
		const a = indices[t * 3], b = indices[t * 3 + 1], c = indices[t * 3 + 2];
		if (a === b || b === c || a === c || a >= vertexCount || b >= vertexCount || c >= vertexCount) {
			continue;
		}
		out[keep++] = a;
		out[keep++] = b;
		out[keep++] = c;
	}
	return keep === out.length ? out : out.slice(0, keep);
}

export async function parseGLTF(data: ArrayBuffer, options: GLTFLoadOptions = {}): Promise<SceneDesc> {
	const { json, bin } = parseContainer(data);
	return new GLTFParser(json, bin, options).parse();
}

export async function loadGLTF(url: string, options: Omit<GLTFLoadOptions, 'resolveUri'> = {}): Promise<SceneDesc> {
	const fetchBuffer = async (u: string) => {
		const res = await fetch(u);
		if (!res.ok) {
			throw new Error(`Failed to fetch ${u}: ${res.status}`);
		}
		return res.arrayBuffer();
	};
	const base = new URL(url, globalThis.location?.href ?? 'file:///');
	return parseGLTF(await fetchBuffer(base.href), {
		...options,
		resolveUri: (uri) => fetchBuffer(new URL(uri, base).href),
	});
}

// Loads a .gltf/.glb from a set of dropped files; sibling files resolve external URIs.
export async function loadGLTFFromFiles(main: File, files: File[], options: Omit<GLTFLoadOptions, 'resolveUri'> = {}): Promise<SceneDesc> {
	const byName = new Map<string, File>();
	for (const f of files) {
		const path = (f as File & { webkitRelativePath?: string }).webkitRelativePath || f.name;
		byName.set(path.replace(/\\/g, '/'), f);
		byName.set(f.name, f);
	}
	return parseGLTF(await main.arrayBuffer(), {
		...options,
		resolveUri: async (uri) => {
			const name = uri.replace(/\\/g, '/').replace(/^\.\//, '');
			const file = byName.get(name) ?? byName.get(name.split('/').pop()!);
			if (!file) {
				throw new Error(`glTF: missing file "${uri}"`);
			}
			return file.arrayBuffer();
		},
	});
}
