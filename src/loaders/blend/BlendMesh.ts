// Blender meshes: polygon data from the three storage schemes (2.7x-3.x MVert/MEdge/MPoly/MLoop
// layers, 4.0 generic attributes in CustomData, 5.x AttributeStorage), Catmull-Clark subdivision
// with creases (the Subdivision Surface modifier, approximated), normals and triangulation.
import { generateTangents } from '../Tangents';
import { type BStruct, readFloats, readInts } from './BlendFile';

export interface PolyMesh {
	positions: Float32Array; // xyz per vertex
	faceOffsets: Int32Array; // faces + 1 corner offsets
	cornerVerts: Int32Array;
	uv: Float32Array | null; // per corner
	edgeKeys: Map<number, number>; // edgeKey(a, b) -> edge index
	edgeCrease: Float32Array | null; // 0..1 per edge
	edgeSharp: Uint8Array | null; // sharp_edge: splits normals
	faceSmooth: Uint8Array; // 1 = smooth shading
	faceMaterial: Int32Array | null;
}

export function edgeKey(a: number, b: number, vertexCount: number): number {
	return a < b ? a * vertexCount + b : b * vertexCount + a;
}

// CustomData / AttributeStorage domains.
const enum Domain {
	Point = 0,
	Edge = 1,
	Face = 2,
	Corner = 3,
}

const CD_MVERT = 0;
const CD_MEDGE = 3;
const CD_CREASE = 30;
const CD_MPOLY = 25;
const CD_MLOOP = 26;
const CD_MLOOPUV = 16;
const CD_PROP_FLOAT2 = 49;
const ME_SMOOTH = 1;
const ME_SHARP = 1 << 9;

interface Layer {
	name: string;
	type: number; // CustomData type, or -1 for AttributeStorage
	bytes: Uint8Array;
	layer: BStruct | null;
}

function customDataLayers(me: BStruct, names: string[]): Layer[] {
	const name = names.find((n) => me.has(n));
	if (!name) {
		return [];
	}
	const cd = me.sub(name);
	const out: Layer[] = [];
	for (const l of cd.array('layers', cd.num('totlayer'), 'CustomDataLayer')) {
		const bytes = l.data('data');
		if (bytes) {
			out.push({ name: l.str('name'), type: l.num('type'), bytes, layer: l });
		}
	}
	return out;
}

function storageAttributes(me: BStruct): Map<string, { domain: number; type: number; bytes: Uint8Array }> {
	const out = new Map<string, { domain: number; type: number; bytes: Uint8Array }>();
	if (!me.has('attribute_storage')) {
		return out;
	}
	const st = me.sub('attribute_storage');
	const f = me.file;
	for (const a of st.array('dna_attributes', st.num('dna_attributes_num'), 'Attribute')) {
		const nameRef = a.resolve('name');
		if (!nameRef || a.num('storage_type') !== 0) {
			continue; // storage 1 is a single value (selection etc.)
		}
		const name = new TextDecoder().decode(f.bytes.subarray(nameRef.offset, f.bytes.indexOf(0, nameRef.offset)));
		const bytes = a.get('data', 'AttributeArray')?.data('data');
		if (bytes) {
			out.set(name, { domain: a.num('domain'), type: a.num('data_type'), bytes });
		}
	}
	return out;
}

export function readMesh(me: BStruct): PolyMesh {
	const vertCount = me.num('totvert', 0, 0) || me.num('verts_num', 0, 0);
	const edgeCount = me.num('totedge', 0, 0) || me.num('edges_num', 0, 0);
	const faceCount = me.num('totpoly', 0, 0) || me.num('faces_num', 0, 0);
	const cornerCount = me.num('totloop', 0, 0) || me.num('corners_num', 0, 0);
	const storage = storageAttributes(me);
	const layers = {
		[Domain.Point]: customDataLayers(me, ['vert_data', 'vdata']),
		[Domain.Edge]: customDataLayers(me, ['edge_data', 'edata']),
		[Domain.Face]: customDataLayers(me, ['face_data', 'pdata']),
		[Domain.Corner]: customDataLayers(me, ['corner_data', 'ldata']),
	};
	const named = (domain: Domain, name: string): Uint8Array | null => {
		const s = storage.get(name);
		if (s && s.domain === domain) {
			return s.bytes;
		}
		return layers[domain].find((l) => l.name === name)?.bytes ?? null;
	};
	const legacy = (domain: Domain, type: number) => layers[domain].find((l) => l.type === type) ?? null;
	const structs = (layer: Layer, type: string, count: number) => {
		const def = me.file.sdna.byName.get(type)!;
		const base = layer.bytes.byteOffset - me.file.bytes.byteOffset;
		return Array.from({ length: count }, (_, i) => me.file.struct(def, base + i * def.size));
	};

	let positions: Float32Array;
	let edgeVerts: Int32Array;
	let faceOffsets: Int32Array;
	let cornerVerts: Int32Array;
	let faceSmooth = new Uint8Array(faceCount).fill(1);
	let edgeSharp: Uint8Array | null = null;
	let edgeCrease: Float32Array | null = null;
	let faceMaterial: Int32Array | null = null;
	let uv: Float32Array | null = null;

	const position = named(Domain.Point, 'position');
	if (position) {
		positions = readFloats(position, vertCount * 3);
		edgeVerts = readInts(named(Domain.Edge, '.edge_verts')!, edgeCount * 2);
		cornerVerts = readInts(named(Domain.Corner, '.corner_vert')!, cornerCount);
		const offsets = me.data('face_offset_indices') ?? me.data('poly_offset_indices');
		faceOffsets = offsets ? readInts(offsets, faceCount + 1) : Int32Array.from({ length: faceCount + 1 }, (_, i) => i * 3);
		const sharpFace = named(Domain.Face, 'sharp_face');
		if (sharpFace) {
			faceSmooth = faceSmooth.map((_, i) => (sharpFace[i] ? 0 : 1));
		}
		const sharpEdge = named(Domain.Edge, 'sharp_edge');
		edgeSharp = sharpEdge ? sharpEdge.slice(0, edgeCount) : null;
		const crease = named(Domain.Edge, 'crease_edge') ?? legacy(Domain.Edge, CD_CREASE)?.bytes;
		edgeCrease = crease ? readFloats(crease, edgeCount) : null;
		const material = named(Domain.Face, 'material_index');
		faceMaterial = material ? readInts(material, faceCount) : null;
		const uvBytes =
			[...storage.entries()].find(([n, a]) => a.domain === Domain.Corner && a.type === 6 && !n.startsWith('.'))?.[1].bytes ??
			layers[Domain.Corner].find((l) => l.type === CD_PROP_FLOAT2 && !l.name.startsWith('.'))?.bytes;
		uv = uvBytes ? readFloats(uvBytes, cornerCount * 2) : null;
	} else {
		const verts = structs(legacy(Domain.Point, CD_MVERT)!, 'MVert', vertCount);
		positions = new Float32Array(vertCount * 3);
		verts.forEach((v, i) => positions.set(v.nums('co'), i * 3));
		const edges = structs(legacy(Domain.Edge, CD_MEDGE)!, 'MEdge', edgeCount);
		edgeVerts = new Int32Array(edgeCount * 2);
		edgeSharp = new Uint8Array(edgeCount);
		edgeCrease = new Float32Array(edgeCount);
		edges.forEach((e, i) => {
			edgeVerts[2 * i] = e.num('v1');
			edgeVerts[2 * i + 1] = e.num('v2');
			edgeSharp![i] = e.num('flag') & ME_SHARP ? 1 : 0;
			edgeCrease![i] = e.num('crease', 0, 0) / 255;
		});
		const polys = structs(legacy(Domain.Face, CD_MPOLY)!, 'MPoly', faceCount);
		faceOffsets = new Int32Array(faceCount + 1);
		faceMaterial = new Int32Array(faceCount);
		polys.forEach((p, i) => {
			faceOffsets[i] = p.num('loopstart');
			faceSmooth[i] = p.num('flag') & ME_SMOOTH ? 1 : 0;
			faceMaterial![i] = p.num('mat_nr');
		});
		faceOffsets[faceCount] = cornerCount;
		cornerVerts = Int32Array.from(structs(legacy(Domain.Corner, CD_MLOOP)!, 'MLoop', cornerCount), (l) => l.num('v'));
		const uvLayer = legacy(Domain.Corner, CD_MLOOPUV);
		if (uvLayer) {
			uv = new Float32Array(cornerCount * 2);
			structs(uvLayer, 'MLoopUV', cornerCount).forEach((l, i) => uv!.set(l.nums('uv'), i * 2));
		}
	}

	const edgeKeys = new Map<number, number>();
	for (let e = 0; e < edgeCount; e++) {
		edgeKeys.set(edgeKey(edgeVerts[2 * e], edgeVerts[2 * e + 1], vertCount), e);
	}
	return { positions, faceOffsets, cornerVerts, uv, edgeKeys, edgeCrease, edgeSharp, faceSmooth, faceMaterial };
}

// Marks edges whose faces meet at more than `angle` as sharp (the "Smooth by Angle" modifier).
export function smoothByAngle(mesh: PolyMesh, angle: number): void {
	const vertexCount = mesh.positions.length / 3;
	const normals = faceNormals(mesh);
	const firstFace = new Map<number, number>();
	const sharp = mesh.edgeSharp ?? new Uint8Array(mesh.edgeKeys.size);
	const cos = Math.cos(angle);
	forEachFaceEdge(mesh, (f, a, b) => {
		const key = edgeKey(a, b, vertexCount);
		const g = firstFace.get(key);
		if (g === undefined) {
			firstFace.set(key, f);
			return;
		}
		const d = normals[3 * f] * normals[3 * g] + normals[3 * f + 1] * normals[3 * g + 1] + normals[3 * f + 2] * normals[3 * g + 2];
		const e = mesh.edgeKeys.get(key);
		if (e !== undefined && d < cos) {
			sharp[e] = 1;
		}
	});
	mesh.edgeSharp = sharp;
	mesh.faceSmooth.fill(1);
}

function forEachFaceEdge(mesh: PolyMesh, fn: (face: number, a: number, b: number, corner: number, next: number) => void): void {
	const { faceOffsets, cornerVerts } = mesh;
	for (let f = 0; f + 1 < faceOffsets.length; f++) {
		const start = faceOffsets[f];
		const end = faceOffsets[f + 1];
		for (let c = start; c < end; c++) {
			const n = c + 1 < end ? c + 1 : start;
			fn(f, cornerVerts[c], cornerVerts[n], c, n);
		}
	}
}

function faceNormals(mesh: PolyMesh): Float32Array {
	const { positions: p, faceOffsets, cornerVerts } = mesh;
	const faces = faceOffsets.length - 1;
	const out = new Float32Array(faces * 3);
	for (let f = 0; f < faces; f++) {
		let x = 0;
		let y = 0;
		let z = 0;
		for (let c = faceOffsets[f]; c < faceOffsets[f + 1]; c++) {
			const a = cornerVerts[c] * 3;
			const b = cornerVerts[c + 1 < faceOffsets[f + 1] ? c + 1 : faceOffsets[f]] * 3;
			x += (p[a + 1] - p[b + 1]) * (p[a + 2] + p[b + 2]);
			y += (p[a + 2] - p[b + 2]) * (p[a] + p[b]);
			z += (p[a] - p[b]) * (p[a + 1] + p[b + 1]);
		}
		const l = Math.hypot(x, y, z) || 1;
		out[3 * f] = x / l;
		out[3 * f + 1] = y / l;
		out[3 * f + 2] = z / l;
	}
	return out;
}

// One Catmull-Clark step. Creases follow OpenSubdiv: sharpness = 10 crease^2, edges with
// sharpness >= 1 (and boundaries) use the sharp rules, fractional sharpness blends, children
// get sharpness - 1. UVs are interpolated linearly, or smoothed (smoothFaceVarying).
function subdivideOnce(mesh: PolyMesh, sharpness: Float32Array, smoothUV: boolean): { mesh: PolyMesh; sharpness: Float32Array } {
	const { positions: p, faceOffsets, cornerVerts, uv } = mesh;
	const V = p.length / 3;
	const F = faceOffsets.length - 1;

	// Edges from the face loops (indexing by our own order; the input edge map gives the attributes).
	const edgeIndex = new Map<number, number>();
	const edgeA: number[] = [];
	const edgeB: number[] = [];
	const edgeFaces: number[][] = [];
	const cornerEdge = new Int32Array(cornerVerts.length);
	forEachFaceEdge(mesh, (f, a, b, c) => {
		const key = edgeKey(a, b, V);
		let e = edgeIndex.get(key);
		if (e === undefined) {
			e = edgeA.length;
			edgeIndex.set(key, e);
			edgeA.push(a);
			edgeB.push(b);
			edgeFaces.push([]);
		}
		edgeFaces[e].push(f);
		cornerEdge[c] = e;
	});
	const E = edgeA.length;
	const sourceEdge = (e: number) => mesh.edgeKeys.get(edgeKey(edgeA[e], edgeB[e], V));
	const edgeSharpness = new Float32Array(E);
	const edgeSplit = new Uint8Array(E);
	for (let e = 0; e < E; e++) {
		const s = sourceEdge(e);
		edgeSharpness[e] = edgeFaces[e].length !== 2 ? Infinity : s !== undefined ? sharpness[s] : 0;
		edgeSplit[e] = s !== undefined && mesh.edgeSharp ? mesh.edgeSharp[s] : 0;
	}

	const out = new Float32Array((V + E + F) * 3);
	const facePoint = (f: number) => (V + E + f) * 3;
	const edgePoint = (e: number) => (V + e) * 3;
	for (let f = 0; f < F; f++) {
		const n = faceOffsets[f + 1] - faceOffsets[f];
		for (let c = faceOffsets[f]; c < faceOffsets[f + 1]; c++) {
			for (let k = 0; k < 3; k++) {
				out[facePoint(f) + k] += p[cornerVerts[c] * 3 + k] / n;
			}
		}
	}
	for (let e = 0; e < E; e++) {
		const s = Math.min(edgeSharpness[e], 1);
		const faces = edgeFaces[e];
		for (let k = 0; k < 3; k++) {
			const mid = (p[edgeA[e] * 3 + k] + p[edgeB[e] * 3 + k]) / 2;
			const smooth = faces.length === 2 ? (mid * 2 + out[facePoint(faces[0]) + k] + out[facePoint(faces[1]) + k]) / 4 : mid;
			out[edgePoint(e) + k] = smooth + (mid - smooth) * s;
		}
	}

	// Vertex points.
	const vertEdges: number[][] = Array.from({ length: V }, () => []);
	for (let e = 0; e < E; e++) {
		vertEdges[edgeA[e]].push(e);
		vertEdges[edgeB[e]].push(e);
	}
	const vertFaces: number[][] = Array.from({ length: V }, () => []);
	for (let f = 0; f < F; f++) {
		for (let c = faceOffsets[f]; c < faceOffsets[f + 1]; c++) {
			vertFaces[cornerVerts[c]].push(f);
		}
	}
	for (let v = 0; v < V; v++) {
		const edges = vertEdges[v];
		const faces = vertFaces[v];
		const n = edges.length;
		const sharp = edges.filter((e) => edgeSharpness[e] > 0);
		const smooth = [0, 0, 0];
		if (n > 0 && faces.length > 0) {
			for (let k = 0; k < 3; k++) {
				let F = 0;
				for (const f of faces) {
					F += out[facePoint(f) + k];
				}
				let R = 0;
				for (const e of edges) {
					R += (p[edgeA[e] * 3 + k] + p[edgeB[e] * 3 + k]) / 2;
				}
				smooth[k] = (F / faces.length + 2 * (R / n) + (n - 3) * p[v * 3 + k]) / n;
			}
		}
		let target = smooth;
		let weight = 0;
		if (sharp.length >= 2) {
			weight = Math.min(sharp.reduce((sum, e) => sum + Math.min(edgeSharpness[e], 1), 0) / sharp.length, 1);
			if (sharp.length === 2) {
				const other = sharp.map((e) => (edgeA[e] === v ? edgeB[e] : edgeA[e]));
				target = [0, 1, 2].map((k) => (p[other[0] * 3 + k] + p[other[1] * 3 + k] + 6 * p[v * 3 + k]) / 8);
			} else {
				target = [p[v * 3], p[v * 3 + 1], p[v * 3 + 2]];
			}
		}
		for (let k = 0; k < 3; k++) {
			out[v * 3 + k] = n === 0 ? p[v * 3 + k] : smooth[k] + (target[k] - smooth[k]) * (target === smooth ? 0 : weight);
		}
	}

	// Child quads: corner, next edge point, face point, previous edge point.
	const corners = cornerVerts.length;
	const childVerts = new Int32Array(corners * 4);
	const childUV = uv ? new Float32Array(corners * 8) : null;
	const childSmooth = new Uint8Array(corners);
	const childMaterial = mesh.faceMaterial ? new Int32Array(corners) : null;
	const childEdgeKeys = new Map<number, number>();
	const childSharpness: number[] = [];
	const childSplit: number[] = [];
	const smooth = uv && smoothUV ? smoothFaceVarying(mesh, uv) : null;
	const NV = V + E + F;
	const addEdge = (a: number, b: number, s: number, split: number) => {
		const key = edgeKey(a, b, NV);
		if (!childEdgeKeys.has(key)) {
			childEdgeKeys.set(key, childSharpness.length);
			childSharpness.push(s);
			childSplit.push(split);
		}
	};
	for (let f = 0; f < F; f++) {
		const start = faceOffsets[f];
		const end = faceOffsets[f + 1];
		const n = end - start;
		const center = [0, 0];
		if (uv) {
			for (let c = start; c < end; c++) {
				center[0] += uv[2 * c] / n;
				center[1] += uv[2 * c + 1] / n;
			}
		}
		for (let c = start; c < end; c++) {
			const prev = c > start ? c - 1 : end - 1;
			const next = c + 1 < end ? c + 1 : start;
			const q = c * 4;
			const eNext = cornerEdge[c];
			const ePrev = cornerEdge[prev];
			childVerts[q] = cornerVerts[c];
			childVerts[q + 1] = V + eNext;
			childVerts[q + 2] = V + E + f;
			childVerts[q + 3] = V + ePrev;
			childSmooth[c] = mesh.faceSmooth[f];
			if (childMaterial) {
				childMaterial[c] = mesh.faceMaterial![f];
			}
			const child = (s: number) => (s === Infinity ? Infinity : Math.max(s - 1, 0));
			addEdge(childVerts[q], childVerts[q + 1], child(edgeSharpness[eNext]), edgeSplit[eNext]);
			addEdge(childVerts[q + 3], childVerts[q], child(edgeSharpness[ePrev]), edgeSplit[ePrev]);
			addEdge(childVerts[q + 1], childVerts[q + 2], 0, 0);
			addEdge(childVerts[q + 2], childVerts[q + 3], 0, 0);
			if (uv && childUV) {
				const u = (i: number, k: number) => uv[2 * i + k];
				for (let k = 0; k < 2; k++) {
					childUV[8 * c + k] = smooth ? smooth.vertex[2 * smooth.id[c] + k] : u(c, k);
					childUV[8 * c + 2 + k] = smooth ? smooth.edge(c, next, k) : (u(c, k) + u(next, k)) / 2;
					childUV[8 * c + 4 + k] = center[k];
					childUV[8 * c + 6 + k] = smooth ? smooth.edge(prev, c, k) : (u(c, k) + u(prev, k)) / 2;
				}
			}
		}
	}
	const childSharpnessArray = Float32Array.from(childSharpness);
	return {
		mesh: {
			positions: out,
			faceOffsets: Int32Array.from({ length: corners + 1 }, (_, i) => i * 4),
			cornerVerts: childVerts,
			uv: childUV,
			edgeKeys: childEdgeKeys,
			edgeCrease: null,
			edgeSharp: Uint8Array.from(childSplit),
			faceSmooth: childSmooth,
			faceMaterial: childMaterial,
		},
		sharpness: childSharpnessArray,
	};
}

// Moves the vertices of an all-quad mesh to the Catmull-Clark limit surface (Blender's
// "use limit surface"): interior (n^2 v + 4 sum(edge neighbors) + sum(diagonals)) / (n (n + 5)),
// crease / boundary (e1 + 4 v + e2) / 6, corners stay.
function projectToLimit(mesh: PolyMesh, sharpness: Float32Array): void {
	const { positions: p, cornerVerts } = mesh;
	const V = p.length / 3;
	const edgeSum = new Float64Array(V * 3);
	const diagSum = new Float64Array(V * 3);
	const valence = new Int32Array(V);
	const faces = new Int32Array(V);
	const sharpNeighbors: number[][] = Array.from({ length: V }, () => []);
	const edgeFaces = new Map<number, number>();
	forEachFaceEdge(mesh, (_f, a, b) => {
		const key = edgeKey(a, b, V);
		edgeFaces.set(key, (edgeFaces.get(key) ?? 0) + 1);
	});
	for (const [key, count] of edgeFaces) {
		const a = Math.floor(key / V);
		const b = key % V;
		valence[a]++;
		valence[b]++;
		for (let k = 0; k < 3; k++) {
			edgeSum[a * 3 + k] += p[b * 3 + k];
			edgeSum[b * 3 + k] += p[a * 3 + k];
		}
		const e = mesh.edgeKeys.get(key);
		if (count !== 2 || (e !== undefined && sharpness[e] > 0)) {
			sharpNeighbors[a].push(b);
			sharpNeighbors[b].push(a);
		}
	}
	for (let c = 0; c < cornerVerts.length; c += 4) {
		for (let i = 0; i < 4; i++) {
			const v = cornerVerts[c + i];
			const d = cornerVerts[c + ((i + 2) & 3)];
			faces[v]++;
			for (let k = 0; k < 3; k++) {
				diagSum[v * 3 + k] += p[d * 3 + k];
			}
		}
	}
	const out = new Float32Array(p);
	for (let v = 0; v < V; v++) {
		const s = sharpNeighbors[v];
		const n = valence[v];
		for (let k = 0; k < 3; k++) {
			if (s.length === 2) {
				out[v * 3 + k] = (p[s[0] * 3 + k] + 4 * p[v * 3 + k] + p[s[1] * 3 + k]) / 6;
			} else if (s.length < 2 && n > 0 && faces[v] === n) {
				out[v * 3 + k] = (n * n * p[v * 3 + k] + 4 * edgeSum[v * 3 + k] + diagSum[v * 3 + k]) / (n * (n + 5));
			}
		}
	}
	mesh.positions = out;
}

// Catmull-Clark on the UV mesh (corners welded where vertex and UV agree), Blender's "Keep Corners"
// UV smoothing: UV boundaries (seams, mesh borders) use the boundary rules, UV corners stay.
// Returns the vertex point per UV vertex and the edge point per corner pair.
function smoothFaceVarying(mesh: PolyMesh, uv: Float32Array): { id: Int32Array; vertex: Float32Array; edge: (a: number, b: number, k: number) => number } {
	const { faceOffsets, cornerVerts } = mesh;
	const F = faceOffsets.length - 1;
	const ids = new Map<string, number>();
	const id = new Int32Array(cornerVerts.length);
	const base: number[] = [];
	for (let c = 0; c < cornerVerts.length; c++) {
		const key = `${cornerVerts[c]}:${uv[2 * c]}:${uv[2 * c + 1]}`;
		let i = ids.get(key);
		if (i === undefined) {
			i = base.length / 2;
			ids.set(key, i);
			base.push(uv[2 * c], uv[2 * c + 1]);
		}
		id[c] = i;
	}
	const U = base.length / 2;
	const centers = new Float64Array(F * 2);
	const edgeFaces = new Map<number, number[]>();
	const vertFaces: number[][] = Array.from({ length: U }, () => []);
	const key = (a: number, b: number) => (a < b ? a * U + b : b * U + a);
	for (let f = 0; f < F; f++) {
		const start = faceOffsets[f];
		const end = faceOffsets[f + 1];
		for (let c = start; c < end; c++) {
			centers[2 * f] += uv[2 * c] / (end - start);
			centers[2 * f + 1] += uv[2 * c + 1] / (end - start);
			const next = c + 1 < end ? c + 1 : start;
			const k = key(id[c], id[next]);
			const faces = edgeFaces.get(k);
			if (faces) faces.push(f);
			else edgeFaces.set(k, [f]);
			vertFaces[id[c]].push(f);
		}
	}
	const vertEdges: number[][] = Array.from({ length: U }, () => []);
	for (const k of edgeFaces.keys()) {
		vertEdges[Math.floor(k / U)].push(k);
		vertEdges[k % U].push(k);
	}
	const vertex = new Float32Array(base);
	for (let v = 0; v < U; v++) {
		const edges = vertEdges[v];
		const faces = vertFaces[v];
		const other = (k: number) => (Math.floor(k / U) === v ? k % U : Math.floor(k / U));
		const boundary = edges.filter((k) => edgeFaces.get(k)!.length !== 2);
		for (let c = 0; c < 2; c++) {
			if (boundary.length === 0 && edges.length > 0) {
				const n = edges.length;
				const fAvg = faces.reduce((s, f) => s + centers[2 * f + c], 0) / faces.length;
				const rAvg = edges.reduce((s, k) => s + (base[2 * v + c] + base[2 * other(k) + c]) / 2, 0) / n;
				vertex[2 * v + c] = (fAvg + 2 * rAvg + (n - 3) * base[2 * v + c]) / n;
			} else if (boundary.length === 2 && faces.length > 1) {
				vertex[2 * v + c] = (base[2 * other(boundary[0]) + c] + 6 * base[2 * v + c] + base[2 * other(boundary[1]) + c]) / 8;
			}
		}
	}
	const edge = (a: number, b: number, c: number) => {
		const faces = edgeFaces.get(key(id[a], id[b]))!;
		const mid = (uv[2 * a + c] + uv[2 * b + c]) / 2;
		return faces.length === 2 ? (2 * mid + centers[2 * faces[0] + c] + centers[2 * faces[1] + c]) / 4 : mid;
	};
	return { id, vertex, edge };
}

export function subdivide(mesh: PolyMesh, levels: number, limit: boolean, smoothUV = false): PolyMesh {
	let sharpness: Float32Array = new Float32Array(mesh.edgeKeys.size);
	if (mesh.edgeCrease) {
		for (let e = 0; e < sharpness.length; e++) {
			sharpness[e] = 10 * mesh.edgeCrease[e] * mesh.edgeCrease[e];
		}
	}
	let current = mesh;
	for (let i = 0; i < levels; i++) {
		({ mesh: current, sharpness } = subdivideOnce(current, sharpness, smoothUV));
	}
	if (limit && levels > 0) {
		projectToLimit(current, sharpness);
	}
	return current;
}

export interface TriangleMesh {
	material: number; // slot index
	positions: Float32Array;
	normals: Float32Array;
	tangents: Float32Array | null;
	uv: Float32Array | null;
	indices: Uint32Array;
}

// Corner normals: corners of a vertex share a normal unless a sharp edge or a flat face separates
// them (angle-weighted face normals). Faces are fan-triangulated, one mesh per material slot.
export function triangulate(mesh: PolyMesh, withTangents: boolean): TriangleMesh[] {
	const { positions: p, faceOffsets, cornerVerts, uv } = mesh;
	const V = p.length / 3;
	const F = faceOffsets.length - 1;
	const fn = faceNormals(mesh);

	const parent = Int32Array.from({ length: cornerVerts.length }, (_, i) => i);
	const find = (i: number): number => {
		while (parent[i] !== i) {
			parent[i] = parent[parent[i]];
			i = parent[i];
		}
		return i;
	};
	const union = (a: number, b: number) => {
		parent[find(a)] = find(b);
	};
	// Half edges a -> b of smooth faces: corners at a and b on both sides of a smooth edge join.
	const halfEdges = new Map<number, [number, number, number]>(); // directed key -> face, corner a, corner b
	forEachFaceEdge(mesh, (f, a, b, c, n) => {
		if (mesh.faceSmooth[f]) {
			halfEdges.set(a * V + b, [f, c, n]);
		}
	});
	for (const [key, [, ca, cb]] of halfEdges) {
		const a = Math.floor(key / V);
		const b = key % V;
		const twin = halfEdges.get(b * V + a);
		if (!twin || a > b) {
			continue;
		}
		const e = mesh.edgeKeys.get(edgeKey(a, b, V));
		if (e !== undefined && mesh.edgeSharp?.[e]) {
			continue;
		}
		union(ca, twin[2]);
		union(cb, twin[1]);
	}

	const groupNormal = new Float32Array(cornerVerts.length * 3);
	for (let f = 0; f < F; f++) {
		const start = faceOffsets[f];
		const end = faceOffsets[f + 1];
		for (let c = start; c < end; c++) {
			const v = cornerVerts[c] * 3;
			const a = cornerVerts[c > start ? c - 1 : end - 1] * 3;
			const b = cornerVerts[c + 1 < end ? c + 1 : start] * 3;
			const e1 = [p[a] - p[v], p[a + 1] - p[v + 1], p[a + 2] - p[v + 2]];
			const e2 = [p[b] - p[v], p[b + 1] - p[v + 1], p[b + 2] - p[v + 2]];
			const d = (e1[0] * e2[0] + e1[1] * e2[1] + e1[2] * e2[2]) / (Math.hypot(...e1) * Math.hypot(...e2) || 1);
			const angle = Math.acos(Math.min(Math.max(d, -1), 1));
			const g = find(c) * 3;
			for (let k = 0; k < 3; k++) {
				groupNormal[g + k] += fn[3 * f + k] * angle;
			}
		}
	}

	const byMaterial = new Map<number, { positions: number[]; normals: number[]; uv: number[]; indices: number[]; keys: Map<string, number> }>();
	for (let f = 0; f < F; f++) {
		const material = mesh.faceMaterial ? mesh.faceMaterial[f] : 0;
		let out = byMaterial.get(material);
		if (!out) {
			out = { positions: [], normals: [], uv: [], indices: [], keys: new Map() };
			byMaterial.set(material, out);
		}
		const start = faceOffsets[f];
		const end = faceOffsets[f + 1];
		const vertexOf = (c: number) => {
			const g = find(c);
			const key = uv ? `${g}/${uv[2 * c]}/${uv[2 * c + 1]}` : `${g}`;
			let index = out.keys.get(key);
			if (index === undefined) {
				index = out.positions.length / 3;
				out.keys.set(key, index);
				const v = cornerVerts[c] * 3;
				out.positions.push(p[v], p[v + 1], p[v + 2]);
				const n = [groupNormal[g * 3], groupNormal[g * 3 + 1], groupNormal[g * 3 + 2]];
				const l = Math.hypot(...n) || 1;
				out.normals.push(n[0] / l, n[1] / l, n[2] / l);
				if (uv) {
					out.uv.push(uv[2 * c], 1 - uv[2 * c + 1]);
				}
			}
			return index;
		};
		const first = vertexOf(start);
		for (let c = start + 1; c + 1 < end; c++) {
			out.indices.push(first, vertexOf(c), vertexOf(c + 1));
		}
	}
	return [...byMaterial.entries()].map(([material, m]) => {
		const positions = Float32Array.from(m.positions);
		const normals = Float32Array.from(m.normals);
		const uvs = uv ? Float32Array.from(m.uv) : null;
		const indices = Uint32Array.from(m.indices);
		return { material, positions, normals, uv: uvs, indices, tangents: withTangents && uvs ? generateTangents(positions, normals, uvs, indices) : null };
	});
}
