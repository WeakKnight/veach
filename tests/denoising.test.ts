import { describe, expect, it } from 'vitest';
import { validateDenoiserOptions } from '../src/render/denoise/OIDNDenoiser';

describe('OIDN configuration', () => {
	it('snapshots application-owned weights before asynchronous initialization', () => {
		const weights = new Uint8Array([1, 2, 3]).buffer;
		const config = validateDenoiserOptions({ type: 'oidn', weights });
		new Uint8Array(weights).fill(9);
		expect([...new Uint8Array(config.weights as ArrayBuffer)]).toEqual([1, 2, 3]);
		expect(config.maxTileSize).toBe(256);
	});
	it('rejects invalid data and unsupported tile settings before replacing an active denoiser', () => {
		for (const weights of ['', '  ', new ArrayBuffer(0)]) expect(() => validateDenoiserOptions({ type: 'oidn', weights })).toThrow();
		for (const maxTileSize of [0, 31, 33, 1024, NaN, Infinity]) expect(() => validateDenoiserOptions({ type: 'oidn', weights: '/model.tza', maxTileSize })).toThrow();
		expect(() => validateDenoiserOptions({ type: 'oidn', weights: '/model.tza', precision: 'int8' as never })).toThrow();
	});
});
