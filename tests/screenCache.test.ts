import { describe, expect, it } from 'vitest';
import { SCREEN_CACHE_CONSTANTS_BYTES, SCREEN_CACHE_DEFAULTS, SCREEN_CACHE_HITS, SCREEN_CACHE_TRACE, packScreenCacheConstants } from '../src/render/ScreenCache';
import { sssrMatrices } from '../src/render/sssr/SssrConfig';

const texture = (width: number, height: number, mipLevelCount: number) => ({ width, height, mipLevelCount }) as GPUTexture;

describe('screen cache constants', () => {
	it('is all zero (mode 0) without a frame', () => {
		const data = new Uint32Array(packScreenCacheConstants(null));
		expect(data.byteLength).toBe(SCREEN_CACHE_CONSTANTS_BYTES);
		expect(data.every(v => v === 0)).toBe(true);
	});

	it('packs matrices as rows that project like the column-major source', () => {
		const camera = { position: [1, 2, 3] as [number, number, number], right: [1.2, 0, 0] as [number, number, number], up: [0, 0.8, 0] as [number, number, number], forward: [0, 0, -1] as [number, number, number] };
		const previous = sssrMatrices(camera, [0.25, 0.75], 640, 400).viewProjection;
		const current = sssrMatrices({ ...camera, position: [1.5, 2, 3] }, [0.5, 0.5], 640, 400).viewProjection;
		const depth = texture(640, 400, 7);
		const data = packScreenCacheConstants({ depth, normal: texture(640, 400, 1), color: texture(640, 400, 1), previous, current, near: 0.01,
			mode: SCREEN_CACHE_TRACE | SCREEN_CACHE_HITS, settings: { ...SCREEN_CACHE_DEFAULTS, iterations: 33.6 } });
		const f = new Float32Array(data), u = new Uint32Array(data);
		const p = [0.3, 1.7, -4];
		for (const [offset, m] of [[0, previous], [16, current]] as const) {
			for (let r = 0; r < 4; r++) {
				const row = f[offset + r * 4] * p[0] + f[offset + r * 4 + 1] * p[1] + f[offset + r * 4 + 2] * p[2] + f[offset + r * 4 + 3];
				const column = m[r] * p[0] + m[4 + r] * p[1] + m[8 + r] * p[2] + m[12 + r];
				expect(row).toBeCloseTo(column, 5);
			}
		}
		// w is the view depth along the camera's forward axis; the jittered pixel center maps to the traced ray.
		const clip = [0, 1, 2, 3].map(r => f[r * 4] * p[0] + f[r * 4 + 1] * p[1] + f[r * 4 + 2] * p[2] + f[r * 4 + 3]);
		expect(clip[3]).toBeCloseTo(7, 5);
		expect(clip[2] / clip[3]).toBeCloseTo(0.01 / 7, 7);
		expect([...u.slice(32, 36)]).toEqual([3, 640, 400, 7]);
		expect(f[36]).toBeCloseTo(0.01);
		expect(f[37]).toBeCloseTo(SCREEN_CACHE_DEFAULTS.thickness);
		expect(f[38]).toBe(34);
		expect(f[39]).toBeCloseTo(SCREEN_CACHE_DEFAULTS.confidence);
	});
});
