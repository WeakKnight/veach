import { afterEach, expect, it, vi } from 'vitest';
import { aggregateGpuPasses, GpuProfiler } from '../src/render/GpuProfiler';

afterEach(() => vi.unstubAllGlobals());

function fixture(supported = true) {
	vi.stubGlobal('GPUBufferUsage', { QUERY_RESOLVE: 1, COPY_SRC: 2, COPY_DST: 4, MAP_READ: 8 });
	vi.stubGlobal('GPUMapMode', { READ: 1 });
	const timestamps = new BigUint64Array(2048); timestamps.set([1_000_000n, 3_000_000n, 4_000_000n, 5_000_000n]);
	const compute = vi.fn(() => ({})), render = vi.fn(() => ({}));
	const encoder = { beginComputePass: compute, beginRenderPass: render, resolveQuerySet: vi.fn(), copyBufferToBuffer: vi.fn(), finish: vi.fn(() => ({})) };
	const device = {
		features: new Set(supported ? ['timestamp-query'] : []), lost: new Promise(() => {}),
		createQuerySet: vi.fn(() => ({ destroy: vi.fn() })),
		createBuffer: vi.fn(() => ({ mapAsync: vi.fn(async () => {}), getMappedRange: () => timestamps.buffer, unmap: vi.fn(), destroy: vi.fn() })),
		createCommandEncoder: vi.fn(() => encoder), queue: { submit: vi.fn() },
	};
	return { profiler: new GpuProfiler(device as unknown as GPUDevice), device, encoder, compute, render };
}

it('aggregates nested scopes and repeated passes without double-counting', () => {
	const result = aggregateGpuPasses([{ path: ['Sample 1', 'Bounce 0', 'Shade'], ms: 2 }, { path: ['Sample 1', 'Bounce 0', 'Shade'], ms: 3 }, { path: ['Sample 2', 'Bounce 1', 'Shade'], ms: 1 }]);
	expect(result.totalMs).toBe(6);
	expect(result.roots[0].ms).toBe(5);
	expect(result.roots[0].children[0].children[0].count).toBe(2);
	expect(result.hotspots).toEqual([{ name: 'Shade', ms: 6, count: 3 }]);
});

it('does not allocate or substitute CPU timing on unsupported devices', () => {
	const { profiler, device, encoder } = fixture(false);
	profiler.capture(); profiler.beginFrame({ width: 1, height: 1, samples: 0, integrator: 'wavefront' });
	expect(profiler.status).toBe('unsupported'); expect(device.createQuerySet).not.toHaveBeenCalled();
	expect(profiler.createCommandEncoder({})).toBe(encoder);
	profiler.destroy();
});

it('captures pass boundaries asynchronously and stops querying after one frame', async () => {
	const { profiler, device, encoder, compute, render } = fixture();
	expect(profiler.createCommandEncoder({})).toBe(encoder); expect(device.createBuffer).not.toHaveBeenCalled();
	profiler.capture(); profiler.beginFrame({ width: 128, height: 96, samples: 0, integrator: 'wavefront' });
	const wrapped = profiler.createCommandEncoder({ label: 'test' });
	expect(() => profiler.scope('Unwound', () => { throw new Error('scope'); })).toThrow('scope');
	profiler.scope('Sample 1', () => wrapped.beginComputePass({ label: 'wavefront.Shade.b0' }));
	profiler.scope('Presentation', () => wrapped.beginRenderPass({ label: 'present', colorAttachments: [] }));
	expect(compute.mock.calls[0]).toEqual([expect.objectContaining({ timestampWrites: expect.objectContaining({ beginningOfPassWriteIndex: 0, endOfPassWriteIndex: 1 }) })]);
	expect(render.mock.calls[0]).toEqual([expect.objectContaining({ timestampWrites: expect.objectContaining({ beginningOfPassWriteIndex: 2, endOfPassWriteIndex: 3 }) })]);
	profiler.endFrame(1); expect(profiler.status).toBe('reading');
	await vi.waitFor(() => expect(profiler.status).toBe('ready'));
	expect(profiler.report).toMatchObject({ totalMs: 3, spanMs: 4, samples: 1, dropped: 0, invalid: 0 });
	expect(profiler.report!.passes[0].path).toEqual(['Sample 1', 'Wavefront', 'Bounce 0', 'Shade']);
	expect(profiler.createCommandEncoder({})).toBe(encoder);
	profiler.capture(); profiler.cancelPending(); expect(profiler.status).toBe('ready');
	profiler.destroy();
});

it('reports overflow instead of reusing timestamp slots', async () => {
	const { profiler, compute } = fixture();
	profiler.capture(); profiler.beginFrame({ width: 1, height: 1, samples: 0, integrator: 'wavefront' });
	const encoder = profiler.createCommandEncoder({});
	for (let i = 0; i < 1025; i++) encoder.beginComputePass({ label: 'work' });
	expect(compute.mock.calls[1024]).toEqual([{ label: 'work' }]);
	profiler.endFrame(1); await vi.waitFor(() => expect(profiler.report?.dropped).toBe(1));
	profiler.destroy();
});
