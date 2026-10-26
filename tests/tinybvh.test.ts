// Validates the tinybvh WASM output against brute force, using a TypeScript mirror of the
// Slang traversal in shaders/RayTracing/Traversal.slang.
import { beforeAll, describe, expect, it } from 'vitest';
import { BuildQuality, TinyBVH, type BLASData } from '../src/accel/TinyBVH';
import { mat4, type Mat4, type Vec3 } from '../src/math/Math';

const LEAF_BIT = 0x80000000;
const FAR = 1e30;

function rng(seed: number) {
	return () => {
		seed = (seed * 1664525 + 1013904223) >>> 0;
		return seed / 4294967296;
	};
}

function randomMesh(random: () => number, triCount: number) {
	const positions = new Float32Array(triCount * 9);
	const indices = new Uint32Array(triCount * 3);
	for (let t = 0; t < triCount; t++) {
		const c = [random() * 10 - 5, random() * 10 - 5, random() * 10 - 5];
		for (let v = 0; v < 3; v++) {
			for (let k = 0; k < 3; k++) {
				positions[t * 9 + v * 3 + k] = c[k] + (random() - 0.5) * 1.5;
			}
			indices[t * 3 + v] = t * 3 + v;
		}
	}
	return { positions, indices };
}

function intersectTri(o: Vec3, d: Vec3, v0: Vec3, e1: Vec3, e2: Vec3, tMax: number): number {
	const h: Vec3 = [d[1] * e2[2] - d[2] * e2[1], d[2] * e2[0] - d[0] * e2[2], d[0] * e2[1] - d[1] * e2[0]];
	const a = e1[0] * h[0] + e1[1] * h[1] + e1[2] * h[2];
	if (a === 0) return FAR;
	const f = 1 / a;
	const s: Vec3 = [o[0] - v0[0], o[1] - v0[1], o[2] - v0[2]];
	const u = f * (s[0] * h[0] + s[1] * h[1] + s[2] * h[2]);
	if (u < 0 || u > 1) return FAR;
	const q: Vec3 = [s[1] * e1[2] - s[2] * e1[1], s[2] * e1[0] - s[0] * e1[2], s[0] * e1[1] - s[1] * e1[0]];
	const v = f * (d[0] * q[0] + d[1] * q[1] + d[2] * q[2]);
	if (v < 0 || u + v > 1) return FAR;
	const t = f * (e2[0] * q[0] + e2[1] * q[1] + e2[2] * q[2]);
	return t > 0 && t < tMax ? t : FAR;
}

function intersectBox(f: Float32Array, at: number, o: Vec3, rd: Vec3, tMax: number): number {
	let tn = 0;
	let tf = tMax;
	for (let k = 0; k < 3; k++) {
		const t1 = (f[at + k] - o[k]) * rd[k];
		const t2 = (f[at + 4 + k] - o[k]) * rd[k];
		tn = Math.max(tn, Math.min(t1, t2));
		tf = Math.min(tf, Math.max(t1, t2));
	}
	return tn <= tf ? tn : FAR;
}

interface Hit {
	t: number;
	prim: number;
	instance: number;
}

// Mirrors TraverseBLAS / TraceScene.
function traverse(nodes: ArrayBuffer, nodeOffset: number, o: Vec3, d: Vec3, hit: Hit, leaf: (first: number, count: number) => void) {
	const f = new Float32Array(nodes);
	const u = new Uint32Array(nodes);
	const rd: Vec3 = [1 / d[0], 1 / d[1], 1 / d[2]];
	const stack: number[] = [];
	let ref = 0;
	for (;;) {
		if (ref & LEAF_BIT) {
			leaf(ref & 0xffffff, (ref >>> 24) & 127);
			if (!stack.length) break;
			ref = stack.pop()!;
			continue;
		}
		const at = (nodeOffset + ref) * 16;
		let d1 = intersectBox(f, at, o, rd, hit.t);
		let d2 = intersectBox(f, at + 8, o, rd, hit.t);
		let near = u[at + 3] >>> 0;
		let far = u[at + 7] >>> 0;
		if (d1 > d2) {
			[d1, d2] = [d2, d1];
			[near, far] = [far, near];
		}
		if (d1 === FAR) {
			if (!stack.length) break;
			ref = stack.pop()!;
		} else {
			ref = near;
			if (d2 !== FAR) stack.push(far);
		}
	}
}

function traceBLAS(blas: BLASData, o: Vec3, d: Vec3, hit: Hit, instance: number) {
	const tris = blas.tris;
	const triU32 = new Uint32Array(tris.buffer, tris.byteOffset, tris.length);
	traverse(blas.nodes, 0, o, d, hit, (first, count) => {
		for (let i = 0; i < count; i++) {
			const b = (first + i) * 12;
			const t = intersectTri(o, d, [tris[b], tris[b + 1], tris[b + 2]], [tris[b + 4], tris[b + 5], tris[b + 6]], [tris[b + 8], tris[b + 9], tris[b + 10]], hit.t);
			if (t < hit.t) {
				hit.t = t;
				hit.prim = triU32[b + 3];
				hit.instance = instance;
			}
		}
	});
}

function bruteForce(positions: Float32Array, indices: Uint32Array, o: Vec3, d: Vec3, hit: Hit, instance: number) {
	for (let t = 0; t < indices.length / 3; t++) {
		const p = (k: number): Vec3 => [positions[indices[t * 3 + k] * 3], positions[indices[t * 3 + k] * 3 + 1], positions[indices[t * 3 + k] * 3 + 2]];
		const v0 = p(0);
		const v1 = p(1);
		const v2 = p(2);
		const th = intersectTri(o, d, v0, [v1[0] - v0[0], v1[1] - v0[1], v1[2] - v0[2]], [v2[0] - v0[0], v2[1] - v0[1], v2[2] - v0[2]], hit.t);
		if (th < hit.t) {
			hit.t = th;
			hit.prim = t;
			hit.instance = instance;
		}
	}
}

function randomRay(random: () => number): { o: Vec3; d: Vec3 } {
	const o: Vec3 = [random() * 20 - 10, random() * 20 - 10, random() * 20 - 10];
	const target: Vec3 = [random() * 6 - 3, random() * 6 - 3, random() * 6 - 3];
	return { o, d: [target[0] - o[0], target[1] - o[1], target[2] - o[2]] };
}

let tinybvh: TinyBVH;
beforeAll(async () => {
	tinybvh = await TinyBVH.create();
});

describe('tinybvh BLAS', () => {
	for (const quality of [BuildQuality.Fast, BuildQuality.High]) {
		it(`matches brute force (${BuildQuality[quality]})`, () => {
			const random = rng(1234 + quality);
			const mesh = randomMesh(random, 2000);
			const blas = tinybvh.buildBLAS(mesh.positions, mesh.indices, quality);
			expect(blas.nodeCount).toBeGreaterThan(1);
			expect(blas.primRefCount).toBeGreaterThanOrEqual(2000);

			let hits = 0;
			for (let i = 0; i < 2000; i++) {
				const { o, d } = randomRay(random);
				const a: Hit = { t: FAR, prim: -1, instance: -1 };
				const b: Hit = { t: FAR, prim: -1, instance: -1 };
				traceBLAS(blas, o, d, a, 0);
				bruteForce(mesh.positions, mesh.indices, o, d, b, 0);
				expect(a.prim).toBe(b.prim);
				if (b.prim >= 0) {
					hits++;
					expect(a.t).toBeCloseTo(b.t, 4);
				}
			}
			expect(hits).toBeGreaterThan(500);
		});
	}

	it('handles a single triangle', () => {
		const blas = tinybvh.buildBLAS(new Float32Array([0, 0, 0, 1, 0, 0, 0, 1, 0]), new Uint32Array([0, 1, 2]));
		const hit: Hit = { t: FAR, prim: -1, instance: -1 };
		traceBLAS(blas, [0.2, 0.2, 1], [0, 0, -1], hit, 0);
		expect(hit.prim).toBe(0);
		expect(hit.t).toBeCloseTo(1, 6);
	});
});

describe('tinybvh TLAS', () => {
	it('two-level traversal matches brute force', () => {
		const random = rng(99);
		const meshes = [randomMesh(random, 300), randomMesh(random, 500)];
		const blases = meshes.map((m) => tinybvh.buildBLAS(m.positions, m.indices));

		const instances: { mesh: number; m: Mat4; inv: Mat4 }[] = [];
		for (let i = 0; i < 24; i++) {
			const angle = random() * Math.PI * 2;
			const q = [0, Math.sin(angle / 2), 0, Math.cos(angle / 2)];
			const s = 0.3 + random() * 0.5;
			const m = mat4.fromTRS([random() * 40 - 20, random() * 40 - 20, random() * 40 - 20], q, [s, s * 1.5, s]);
			instances.push({ mesh: i % 2, m, inv: mat4.invert(m)! });
		}

		const aabbs = new Float32Array(instances.length * 8);
		instances.forEach((inst, i) => {
			const b = mat4.transformAABB(inst.m, blases[inst.mesh].boundsMin, blases[inst.mesh].boundsMax);
			aabbs.set([...b.min, 0, ...b.max, 0], i * 8);
		});
		const tlas = tinybvh.buildTLAS(aabbs);

		let hits = 0;
		for (let r = 0; r < 1500; r++) {
			const o: Vec3 = [random() * 60 - 30, random() * 60 - 30, random() * 60 - 30];
			const target = mat4.transformPoint(instances[r % instances.length].m, [0, 0, 0]);
			const d: Vec3 = [target[0] - o[0], target[1] - o[1], target[2] - o[2]];

			const a: Hit = { t: FAR, prim: -1, instance: -1 };
			traverse(tlas.nodes, 0, o, d, a, (first, count) => {
				for (let i = 0; i < count; i++) {
					const idx = tlas.primIndices[first + i];
					const inst = instances[idx];
					traceBLAS(blases[inst.mesh], mat4.transformPoint(inst.inv, o), mat4.transformVector(inst.inv, d), a, idx);
				}
			});

			const b: Hit = { t: FAR, prim: -1, instance: -1 };
			instances.forEach((inst, idx) => {
				bruteForce(meshes[inst.mesh].positions, meshes[inst.mesh].indices, mat4.transformPoint(inst.inv, o), mat4.transformVector(inst.inv, d), b, idx);
			});

			expect(a.instance).toBe(b.instance);
			expect(a.prim).toBe(b.prim);
			if (b.prim >= 0) {
				hits++;
				expect(a.t).toBeCloseTo(b.t, 3);
			}
		}
		expect(hits).toBeGreaterThan(300);
	});
});
