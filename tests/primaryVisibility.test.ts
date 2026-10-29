import { describe, expect, it, vi } from 'vitest';
import { PathTracer } from '../src/render/PathTracer';
import { Wavefront } from '../src/render/Wavefront';

describe('primary visibility ownership and memory', () => {
	it('reports a GPU near-plane fallback as actual ray tracing after explicit readback', async () => {
		const tracer: PathTracer = Object.assign(Object.create(PathTracer.prototype), {
			rasterActive: true, primaryVisibilityStats: { requested: 'rasterized', actual: 'rasterized', reason: null, drawCalls: 1 },
			visibility: { readCounters: async () => ({ nearClipFallback: true, fallbackPixels: 100 }) },
		});
		expect(await tracer.readPrimaryVisibilityStats()).toMatchObject({ actual: 'ray-traced', reason: 'near-clip', drawCalls: 1 });
		expect(tracer.primaryVisibilityStats.actual).toBe('rasterized');
	});
	it('reserves raster scratch without exceeding the existing storage binding limit', () => {
		const limit = 128 * 1024 * 1024, pixels = 1920 * 1080;
		const wf: Wavefront = Object.assign(Object.create(Wavefront.prototype), {
			device: { limits: { maxStorageBufferBindingSize: limit, maxBufferSize: limit } }, visibilityScratchBytes: 0, separateLight: false,
		});
		const baseline = wf.capacity(pixels);
		wf.visibilityScratchBytes = 8 * 1024 * 1024;
		expect(wf.capacity(pixels)).toBeLessThan(baseline);
		expect(pixels * 48 + wf.storageBytes(pixels)).toBeLessThanOrEqual(limit);
		wf.visibilityScratchBytes = limit;
		expect(() => wf.capacity(pixels)).toThrow('no room');
	});

	it('uses sparse slot bounds and disables shared raster jitter for depth of field', () => {
		const tracer: PathTracer = Object.assign(Object.create(PathTracer.prototype), {
			integrator: 'wavefront', hasGeometry: true, primaryVisibility: 'rasterized', rasterAllocated: true,
			gpuScene: { visibilityCount: 2, visibilityOffset: 37, instanceSlots: 11 }, visibility: { scratchOffset: 1024 },
			wavefront: { tailStart: Infinity, visibilityScratchBytes: 80 }, width: 129, height: 97, sharedPrimaryJitter: false,
		});
		expect(tracer.primaryVisibilityFrame(0, 0)).toEqual({ sharedJitter: true, data: [256, 37, 2, 11] });
		expect(tracer.primaryVisibilityFrame(0.1, 0)).toEqual({ sharedJitter: false, data: [0, 0, 0, 0] });
		expect(tracer.primaryVisibilityStats.reason).toBe('depth-of-field');
	});

	it('keeps the active mode and frees failed pipelines before a retry', async () => {
		const destroy = vi.fn(), resize = vi.fn();
		const tracer: PathTracer = Object.assign(Object.create(PathTracer.prototype), {
			primaryVisibility: 'ray-traced', destroyed: false, visibility: { compiled: Promise.reject(new Error('compile failed')), destroy }, resize,
		});
		await expect(tracer.setPrimaryVisibility('rasterized')).rejects.toThrow('compile failed');
		expect(tracer.primaryVisibility).toBe('ray-traced'); expect(destroy).toHaveBeenCalledOnce(); expect(resize).not.toHaveBeenCalled();
		expect(Reflect.get(tracer, 'visibility')).toBeNull();
	});
});
