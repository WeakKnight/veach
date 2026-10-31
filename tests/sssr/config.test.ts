// FidelityFX SSSR host math (docs/Sssr.md): projection conventions, constant layout and the BRDF LUT.
import { describe, expect, it } from 'vitest';
import { mat4, vec3, type Vec3 } from '../../src/math/Math';
import { SSSR_CONSTANTS_BYTES, SSSR_DEFAULTS, SSSR_NEAR_PLANE, brdfLut, packSssrConstants, sssrDepthMips, sssrMatrices } from '../../src/render/sssr/SssrConfig';
import { lookAt } from '../nrd/scenarios';

const W = 64, H = 40;

describe('SSSR matrices', () => {
	const camera = lookAt([1, 1.5, 4], [0, 1, 0], W, H);
	const jitter: [number, number] = [0.2, 0.85];
	const m = sssrMatrices(camera, jitter, W, H);
	// The path tracer's jittered ray through pixel p (Wavefront / PrimaryViewZ in SssrPasses.slang).
	const ray = (px: number, py: number): Vec3 => {
		const nx = ((px + jitter[0]) / W) * 2 - 1, ny = 1 - ((py + jitter[1]) / H) * 2;
		return vec3.add(vec3.add(camera.forward, vec3.scale(camera.right, nx)), vec3.scale(camera.up, ny));
	};
	const project = (p: Vec3) => {
		const c = [0, 1, 2, 3].map(r => m.viewProjection[r] * p[0] + m.viewProjection[4 + r] * p[1] + m.viewProjection[8 + r] * p[2] + m.viewProjection[12 + r]);
		return { uv: [c[0] / c[3] * 0.5 + 0.5, 0.5 - c[1] / c[3] * 0.5], depth: c[2] / c[3] };
	};

	it('maps the traced ray of each pixel to its FidelityFX pixel-center UV, with depth near / viewZ', () => {
		const axis = vec3.normalize(vec3.cross(camera.up, camera.right));
		for (const [px, py, t] of [[0, 0, 0.5], [31, 17, 3], [63, 39, 40]]) {
			const d = vec3.normalize(ray(px, py));
			const p = vec3.add(camera.position, vec3.scale(d, t));
			const { uv, depth } = project(p);
			expect(uv[0]).toBeCloseTo((px + 0.5) / W, 5);
			expect(uv[1]).toBeCloseTo((py + 0.5) / H, 5);
			expect(depth).toBeCloseTo(SSSR_NEAR_PLANE / (t * vec3.dot(d, axis)), 6);
		}
	});

	it('inverts the projection and view', () => {
		const ivp = mat4.invert(m.viewProjection)!, product = mat4.multiply(ivp, m.viewProjection);
		for (let i = 0; i < 16; i++) expect(product[i]).toBeCloseTo(i % 5 === 0 ? 1 : 0, 4);
	});
});

describe('SSSR constants', () => {
	it('packs the SssrConstants fields at their WGSL offsets', () => {
		const current = sssrMatrices(lookAt([0, 1, 4], [0, 1, 0], W, H), [0.5, 0.5], W, H);
		const data = packSssrConstants({ current, previous: current, width: W, height: H, frameIndex: 2 ** 32 + 5, parameters: SSSR_DEFAULTS,
			iblFactor: 2, envRotation: 0.5, region: 1234, debug: 1, preExposure: 3, sceneColorHistory: true, jitterDelta: [0.25, -0.5] });
		expect(data.byteLength).toBe(SSSR_CONSTANTS_BYTES);
		const f = new Float32Array(data), u = new Uint32Array(data);
		expect(f.subarray(16, 32)).toEqual(current.projection);
		expect(f.subarray(80, 96)).toEqual(current.viewProjection);
		expect([u[96], u[97]]).toEqual([W, H]);
		expect([u[104], u[105]]).toEqual([0, 1]); // roughness channel, perceptual roughness
		expect(f[106]).toBe(2);
		expect(u[111]).toBe(5);
		expect([u[112], u[113], u[115], u[116], u[117]]).toEqual([128, 4, 1, 1, 1234]);
		expect([f[118], u[119]]).toEqual([0.5, 1]);
		expect(f[120]).toBeCloseTo(SSSR_NEAR_PLANE, 7);
		expect([f[121], u[122], f[124], f[125]]).toEqual([3, 1, 0.25, -0.5]);
	});

	it('limits the depth hierarchy to FidelityFX mip counts', () => {
		expect(sssrDepthMips(1920, 1080)).toBe(7);
		expect(sssrDepthMips(16, 9)).toBe(4);
		expect(sssrDepthMips(1, 1)).toBe(1);
	});
});

describe('SSSR BRDF LUT', () => {
	const size = 16, lut = brdfLut(size, 256);
	it('stays within [0, 1] and integrates to one for a smooth surface seen head-on', () => {
		for (const v of lut) expect(v).toBeGreaterThanOrEqual(0);
		for (let i = 0; i < size * size; i++) expect(lut[i * 2] + lut[i * 2 + 1]).toBeLessThanOrEqual(1.001);
		const headOn = (size - 1) * 2; // roughness row 0, largest N.V
		expect(lut[headOn] + lut[headOn + 1]).toBeGreaterThan(0.98);
		expect(lut[headOn + 1]).toBeLessThan(0.01); // little Fresnel at normal incidence
	});
	it('loses energy with roughness at grazing angles', () => {
		const grazing = (row: number) => lut[row * size * 2] + lut[row * size * 2 + 1];
		expect(grazing(size - 1)).toBeLessThan(grazing(0));
	});
});
