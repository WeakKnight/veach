import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { parseGLTF } from '../src/loaders/GLTFLoader';
import { parseHDR } from '../src/loaders/HDRLoader';
import { buildEnvironmentCdf, floatToHalf } from '../src/render/Environment';
import { AlphaMode } from '../src/scene/Scene';

const samples = join(__dirname, '..', 'public', 'samples');
const sample = (name: string) => join(samples, name);
const read = (name: string) => {
	const b = readFileSync(sample(name));
	return b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength) as ArrayBuffer;
};
const hasSamples = existsSync(sample('DamagedHelmet.glb'));

function gltfJson(json: object, bin?: Uint8Array): ArrayBuffer {
	const buffers = bin ? [{ byteLength: bin.byteLength, uri: `data:application/octet-stream;base64,${Buffer.from(bin).toString('base64')}` }] : [];
	return new TextEncoder().encode(JSON.stringify({ asset: { version: '2.0' }, buffers, ...json })).buffer as ArrayBuffer;
}

describe('glTF loader', () => {
	it('parses a minimal embedded triangle with node transforms', async () => {
		const positions = new Float32Array([0, 0, 0, 1, 0, 0, 0, 1, 0]);
		const indices = new Uint16Array([0, 1, 2, 0]); // padded to 4-byte alignment
		const bin = new Uint8Array(positions.byteLength + indices.byteLength);
		bin.set(new Uint8Array(positions.buffer), 0);
		bin.set(new Uint8Array(indices.buffer), positions.byteLength);
		const scene = await parseGLTF(
			gltfJson(
				{
					bufferViews: [
						{ buffer: 0, byteOffset: 0, byteLength: 36 },
						{ buffer: 0, byteOffset: 36, byteLength: 6 },
					],
					accessors: [
						{ bufferView: 0, componentType: 5126, count: 3, type: 'VEC3', min: [0, 0, 0], max: [1, 1, 0] },
						{ bufferView: 1, componentType: 5123, count: 3, type: 'SCALAR' },
					],
					meshes: [{ primitives: [{ attributes: { POSITION: 0 }, indices: 1 }] }],
					nodes: [{ children: [1], translation: [10, 0, 0] }, { mesh: 0, scale: [2, 2, 2] }],
					scenes: [{ nodes: [0] }],
				},
				bin,
			),
			{ decodeImages: false },
		);
		expect(scene.meshes).toHaveLength(1);
		expect(Array.from(scene.meshes[0].indices)).toEqual([0, 1, 2]);
		expect(scene.meshes[0].normals).toBeNull();
		expect(scene.instances).toHaveLength(1);
		const m = scene.instances[0].transform;
		expect(m[0]).toBe(2);
		expect(m[12]).toBe(10);
	});

	it('rejects unsupported required extensions', async () => {
		await expect(parseGLTF(gltfJson({ extensionsRequired: ['KHR_draco_mesh_compression'] }), { decodeImages: false })).rejects.toThrow(/draco/);
	});

	it.runIf(hasSamples)('loads DamagedHelmet', async () => {
		const scene = await parseGLTF(read('DamagedHelmet.glb'), { decodeImages: false });
		expect(scene.meshes).toHaveLength(1);
		const mesh = scene.meshes[0];
		expect(mesh.indices.length / 3).toBe(15452);
		expect(mesh.normals).not.toBeNull();
		expect(mesh.uv0).not.toBeNull();
		expect(mesh.tangents).not.toBeNull(); // generated: the asset has a normal map but no TANGENT
		const mat = scene.materials[mesh.material];
		expect(mat.textures.baseColor).toBeDefined();
		expect(mat.textures.normal).toBeDefined();
		expect(mat.textures.emissive).toBeDefined();
		expect(mat.emission).toEqual([1, 1, 1]);
	});

	it.runIf(hasSamples)('loads extension test assets', async () => {
		const alpha = await parseGLTF(read('AlphaBlendModeTest.glb'), { decodeImages: false });
		expect(alpha.materials.some((m) => m.alphaMode === AlphaMode.Mask)).toBe(true);
		expect(alpha.materials.some((m) => m.alphaMode === AlphaMode.Blend)).toBe(true);

		const emissive = await parseGLTF(read('EmissiveStrengthTest.glb'), { decodeImages: false });
		expect(Math.max(...emissive.materials.map((m) => m.emission[0]))).toBeGreaterThan(1);

		const transmission = await parseGLTF(read('TransmissionTest.glb'), { decodeImages: false });
		expect(transmission.materials.some((m) => m.transmission > 0)).toBe(true);

		const clearcoat = await parseGLTF(read('ClearCoatTest.glb'), { decodeImages: false });
		expect(clearcoat.materials.some((m) => m.clearcoat > 0)).toBe(true);
	});
});

describe('HDR / environment', () => {
	it('converts floats to half', () => {
		expect(floatToHalf(0)).toBe(0);
		expect(floatToHalf(1)).toBe(0x3c00);
		expect(floatToHalf(-2)).toBe(0xc000);
		expect(floatToHalf(65504)).toBe(0x7bff);
		expect(floatToHalf(1e9)).toBe(0x7bff);
		expect(floatToHalf(0.5)).toBe(0x3800);
		expect(floatToHalf(6.0e-8)).toBe(1);
	});

	it('builds a normalized CDF', () => {
		const W = 8, H = 4;
		const data = new Float32Array(W * H * 4);
		data[(1 * W + 5) * 4] = 100; // one hot pixel
		const cdf = buildEnvironmentCdf({ width: W, height: H, data })!;
		expect(cdf.texWidth).toBe(W + 1);
		const at = (x: number, y: number) => cdf.data[y * cdf.texWidth + x];
		expect(at(H, H)).toBe(1);
		expect(at(1, H)).toBe(0);
		expect(at(2, H)).toBeCloseTo(1); // all marginal mass in row 1
		expect(at(5, 1)).toBe(0);
		expect(at(6, 1)).toBeCloseTo(1);
		expect(buildEnvironmentCdf({ width: W, height: H, data: new Float32Array(W * H * 4) })).toBeNull();
	});

	it.runIf(hasSamples)('parses an RLE .hdr', () => {
		const img = parseHDR(read('studio_small_09_1k.hdr'));
		expect(img.width).toBe(1024);
		expect(img.height).toBe(512);
		let max = 0;
		for (let i = 0; i < img.data.length; i += 4) max = Math.max(max, img.data[i]);
		expect(max).toBeGreaterThan(1);
		expect(img.data.every(Number.isFinite)).toBe(true);
	});
});
