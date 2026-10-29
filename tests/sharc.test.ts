import { expect, it } from 'vitest';
import { Wavefront } from '../src/render/Wavefront';
import { SharcCache } from '../src/render/SharcCache';

it('fits cache, sparse records and visibility scratch inside the shared storage limit', () => {
	for (const limit of [128, 512].map(mb => mb * 1024 * 1024)) for (const pixels of [640 * 360, 1920 * 1080]) {
		const wf: Wavefront = Object.assign(Object.create(Wavefront.prototype), {
			device: { limits: { maxStorageBufferBindingSize: limit, maxBufferSize: limit } },
			visibilityScratchBytes: 1024 * 1024, sharcCacheBytes: SharcCache.cacheBytes(65536), separateLight: true,
		});
		expect(wf.capacity(pixels)).toBeGreaterThan(0);
		expect(pixels * 48 + wf.storageBytes(pixels)).toBeLessThanOrEqual(limit);
	}
});
