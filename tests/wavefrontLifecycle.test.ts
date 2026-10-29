import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PathTracer } from '../src/render/PathTracer';
import type { GpuScene } from '../src/render/GpuScene';

const compilation = vi.hoisted(() => ({ pending: Promise.resolve(), instances: [] as { destroy: ReturnType<typeof vi.fn> }[] }));
vi.mock('../src/render/Wavefront', () => ({
	Wavefront: class {
		compiled = compilation.pending;
		prepareStack = async () => {};
		prepareLightStages = () => compilation.pending;
		prepareShadowBatches = () => compilation.pending;
		destroy = vi.fn();
		constructor() { compilation.instances.push(this); }
	},
}));

function pending() {
	let resolve!: () => void;
	let reject!: (error: Error) => void;
	const promise = new Promise<void>((yes, no) => { resolve = yes; reject = no; });
	return { promise, resolve, reject };
}

function tracer(): PathTracer {
	// Only exercise asynchronous ownership; GPU allocation/rendering are covered by the browser tests.
	return Object.assign(Object.create(PathTracer.prototype), {
		integrator: 'megakernel' as const, width: 8, height: 8, hasGeometry: true,
		materialPipelines: new Map(), materialPipelineLoading: new Map(), materialCapacity: 16,
		materialOperandMode: 0, boundMaterialOperandMode: 0,
		materialOpcodes: [0xffffffff, 0xffffffff],
		opaqueMegakernel: false, boundOpaqueMegakernel: false,
		resize: vi.fn(),
		uniformBuffer: { destroy: vi.fn() }, toneLUT: { destroy: vi.fn() },
		displayTransform: { destroy: vi.fn() }, bsdfTables: { destroy: vi.fn() },
		autoExposure: { destroy: vi.fn() }, localExposure: { destroy: vi.fn() },
	});
}

describe('wavefront compilation ownership', () => {
	beforeEach(() => { compilation.instances.length = 0; compilation.pending = Promise.resolve(); });

	it.each(['setSeparateLight', 'setBatchedShadows'] as const)('%s publishes only after successful compilation and rejects disposal races', async method => {
		const pathTracer = tracer();
		await pathTracer.setIntegrator('wavefront');
		const field = method === 'setSeparateLight' ? 'separateLight' : 'batchedShadows';
		const failed = pending(); compilation.pending = failed.promise;
		const first = pathTracer[method](true);
		const rejected = expect(first).rejects.toThrow('compile failed');
		expect(pathTracer[field]).not.toBe(true);
		failed.reject(new Error('compile failed')); await rejected;
		expect(pathTracer[field]).not.toBe(true);
		const delayed = pending(); compilation.pending = delayed.promise;
		const second = pathTracer[method](true);
		const disposed = expect(second).rejects.toThrow(/destroyed/i);
		pathTracer.destroy(); delayed.resolve(); await disposed;
		expect(pathTracer[field]).not.toBe(true);
	});

	it('defers material kernels for empty scenes but prepares them when geometry arrives', async () => {
		const pathTracer = tracer();
		const device = { createShaderModule: vi.fn(() => ({})), createComputePipelineAsync: vi.fn().mockResolvedValue({}) };
		Object.assign(pathTracer, { hasGeometry: false, materialStackOverride: null, compiled: Promise.resolve(), emptyPipeline: {}, device });
		const emptyScene = { instanceCount: 0, materialStackSize: 0 } as GpuScene;
		await pathTracer.setIntegrator('wavefront');
		await pathTracer.prepareScene(emptyScene);
		expect(pathTracer.integrator).toBe('wavefront');
		expect(device.createComputePipelineAsync).not.toHaveBeenCalled();
		expect(compilation.instances).toHaveLength(0);
		// Forced capacity keeps a full reference path available for empty-scene GPU comparisons.
		pathTracer.materialStackOverride = 16;
		await pathTracer.prepareScene(emptyScene);
		expect(device.createComputePipelineAsync).toHaveBeenCalledTimes(1);
		expect(compilation.instances).toHaveLength(0);
		pathTracer.materialStackOverride = null;
		await pathTracer.prepareScene({ instanceCount: 1, materialStackSize: 3 } as GpuScene);
		expect(device.createComputePipelineAsync).toHaveBeenCalledTimes(1); // Geometry needs wavefront only.
		expect(compilation.instances).toHaveLength(1);
		expect(Reflect.get(pathTracer, 'hasGeometry')).toBe(false);
	});

	it('disposes a stage compiler that completes after the tracer is destroyed', async () => {
		const compile = pending();
		compilation.pending = compile.promise;
		const pathTracer = tracer();
		const switching = pathTracer.setIntegrator('wavefront');
		const rejected = expect(switching).rejects.toThrow(/destroyed/i);
		await vi.waitFor(() => expect(compilation.instances).toHaveLength(1));
		pathTracer.destroy();
		compile.resolve();
		await rejected;
		expect(compilation.instances[0].destroy).toHaveBeenCalledTimes(1);
		expect(pathTracer.resize).not.toHaveBeenCalled();
	});

	it('releases failed compilation resources and allows a later retry', async () => {
		const compile = pending();
		compilation.pending = compile.promise;
		const pathTracer = tracer();
		const switching = pathTracer.setIntegrator('wavefront');
		const rejected = expect(switching).rejects.toThrow('compilation failed');
		await vi.waitFor(() => expect(compilation.instances).toHaveLength(1));
		compile.reject(new Error('compilation failed'));
		await rejected;
		expect(compilation.instances[0].destroy).toHaveBeenCalledTimes(1);
		expect(pathTracer.integrator).toBe('megakernel');
		compilation.pending = Promise.resolve();
		await pathTracer.setIntegrator('wavefront');
		expect(compilation.instances).toHaveLength(2);
		expect(pathTracer.integrator).toBe('wavefront');
		pathTracer.destroy();
		expect(compilation.instances[1].destroy).toHaveBeenCalledTimes(1);
	});

	it('releases a ready compiler when disposal races promise delivery', async () => {
		const compile = pending();
		compilation.pending = compile.promise;
		const pathTracer = tracer();
		const switching = pathTracer.setIntegrator('wavefront');
		const rejected = expect(switching).rejects.toThrow(/destroyed/i);
		await vi.waitFor(() => expect(compilation.instances).toHaveLength(1));
		compile.resolve();
		// The compiler's await resumes first; the outer import/catch chain has not delivered it yet.
		await Promise.resolve();
		pathTracer.destroy();
		await rejected;
		expect(compilation.instances[0].destroy).toHaveBeenCalledTimes(1);
		expect(pathTracer.resize).not.toHaveBeenCalled();
	});
});

describe('material pipeline preparation', () => {
	const scene = { instanceCount: 1, materialStackSize: 3 } as GpuScene;
	it('defers the debug reference kernel, preserves the active frame, and reuses it for megakernel switching', async () => {
		const pathTracer = tracer(), gate = pending(), active = {}, reference = {};
		const device = { createShaderModule: vi.fn(() => ({})), createComputePipelineAsync: vi.fn(() => gate.promise.then(() => reference)) };
		Object.assign(pathTracer, { integrator: 'wavefront', device, computePipeline: active });
		expect(pathTracer.framePipelinesReady(7)).toBe(false);
		expect(pathTracer.framePipelinesReady(7)).toBe(false);
		expect(device.createComputePipelineAsync).toHaveBeenCalledTimes(1);
		expect(Reflect.get(pathTracer, 'computePipeline')).toBe(active);
		gate.resolve();
		await vi.waitFor(() => expect(pathTracer.framePipelinesReady(7)).toBe(true));
		expect(Reflect.get(pathTracer, 'computePipeline')).toBe(reference);
		await pathTracer.setIntegrator('megakernel');
		expect(device.createComputePipelineAsync).toHaveBeenCalledTimes(1);
		expect(pathTracer.integrator).toBe('megakernel');
	});
	it('specializes opaque traversal independently, falls back for alpha, and reuses cached pipelines', async () => {
		const device = { createShaderModule: vi.fn(() => ({})), createComputePipelineAsync: vi.fn().mockResolvedValue({}) };
		const pathTracer = tracer();
		Object.assign(pathTracer, { device, opaqueMegakernel: true });
		const opaqueScene = { ...scene, hasAlphaTested: false } as GpuScene;
		const alphaScene = { ...scene, hasAlphaTested: true } as GpuScene;
		await Promise.all([pathTracer.prepareScene(opaqueScene), pathTracer.prepareScene(opaqueScene)]);
		await pathTracer.prepareScene(alphaScene);
		pathTracer.opaqueMegakernel = false;
		await pathTracer.prepareScene(opaqueScene);
		pathTracer.opaqueMegakernel = true;
		await pathTracer.prepareScene(opaqueScene);
		expect(device.createComputePipelineAsync.mock.calls.map(([d]) => d.label)).toEqual(['pathTracing.opaque.stack4', 'pathTracing.stack4']);
		expect(pathTracer.boundOpaqueMegakernel).toBe(false);
	});
	it('does not reuse a pipeline compiled for another scene opcode set', async () => {
		const device = { createShaderModule: vi.fn(() => ({})), createComputePipelineAsync: vi.fn().mockResolvedValue({}) };
		const pathTracer = tracer();
		Object.assign(pathTracer, { device, materialOpcodeSpecialization: true });
		const a = { ...scene, materialOpcodes: [0xa00001, 0] as const } as GpuScene;
		const b = { ...scene, materialOpcodes: [0xa00009, 7] as const } as GpuScene;
		await pathTracer.prepareScene(a);
		await pathTracer.prepareScene(b);
		await pathTracer.prepareScene(a);
		expect(device.createComputePipelineAsync).toHaveBeenCalledTimes(2);
		expect(device.createComputePipelineAsync.mock.calls.map(([d]) => d.compute.constants)).toEqual([
			{ '0': 0xa00001, '1': 0, '2': 0 }, { '0': 0xa00009, '1': 7, '2': 0 },
		]);
	});

	it('compiles each operand mode independently and reuses a previous mode', async () => {
		const device = { createShaderModule: vi.fn(() => ({})), createComputePipelineAsync: vi.fn().mockResolvedValue({}) };
		const pathTracer = tracer();
		Object.assign(pathTracer, { device });
		for (const mode of [0, 1, 2, 3, 4, 7, 1, 0]) {
			pathTracer.materialOperandMode = mode;
			await pathTracer.prepareScene(scene);
		}
		expect(device.createComputePipelineAsync.mock.calls.map(([d]) => d.compute.constants['2'])).toEqual([0, 1, 2, 3, 4, 7]);
		expect(pathTracer.boundMaterialOperandMode).toBe(0);
	});

	it('shares concurrent compilation, caches success, and leaves the active pipeline alone', async () => {
		const compile = pending();
		const pipeline = {} as GPUComputePipeline;
		const active = {};
		const device = { createShaderModule: vi.fn(() => ({})), createComputePipelineAsync: vi.fn(() => compile.promise.then(() => pipeline)) };
		const pathTracer = tracer();
		Object.assign(pathTracer, { device, computePipeline: active });
		const first = pathTracer.prepareScene(scene), second = pathTracer.prepareScene(scene);
		expect(device.createComputePipelineAsync).toHaveBeenCalledTimes(1);
		expect(pathTracer.materialCapacity).toBe(16);
		compile.resolve();
		await Promise.all([first, second]);
		await pathTracer.prepareScene(scene);
		expect(device.createComputePipelineAsync).toHaveBeenCalledTimes(1);
		expect(Reflect.get(pathTracer, 'computePipeline')).toBe(active);
	});

	it('allows retry after a failed material compilation', async () => {
		const device = { createShaderModule: vi.fn(() => ({})), createComputePipelineAsync: vi.fn()
			.mockRejectedValueOnce(new Error('material compile failed')).mockResolvedValue({}) };
		const pathTracer = tracer();
		Object.assign(pathTracer, { device });
		await expect(pathTracer.prepareScene(scene)).rejects.toThrow('material compile failed');
		await pathTracer.prepareScene(scene);
		expect(device.createComputePipelineAsync).toHaveBeenCalledTimes(2);
	});

	it('rejects completed compilation after disposal and rejects undersized overrides', async () => {
		const compile = pending();
		const device = { createShaderModule: vi.fn(() => ({})), createComputePipelineAsync: vi.fn(() => compile.promise.then(() => ({}))) };
		const pathTracer = tracer();
		Object.assign(pathTracer, { device });
		pathTracer.materialStackOverride = 2;
		await expect(pathTracer.prepareScene(scene)).rejects.toThrow('Scene needs 3');
		expect(device.createComputePipelineAsync).not.toHaveBeenCalled();
		pathTracer.materialStackOverride = null;
		const preparation = pathTracer.prepareScene(scene);
		const rejected = expect(preparation).rejects.toThrow(/destroyed/i);
		pathTracer.destroy();
		compile.resolve();
		await rejected;
	});
});
