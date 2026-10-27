import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PathTracer } from '../src/render/PathTracer';

const compilation = vi.hoisted(() => ({ pending: Promise.resolve(), instances: [] as { destroy: ReturnType<typeof vi.fn> }[] }));
vi.mock('../src/render/Wavefront', () => ({
	Wavefront: class {
		compiled = compilation.pending;
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
		integrator: 'megakernel' as const, width: 8, height: 8,
		resize: vi.fn(),
		uniformBuffer: { destroy: vi.fn() }, toneLUT: { destroy: vi.fn() },
		displayTransform: { destroy: vi.fn() }, bsdfTables: { destroy: vi.fn() },
		autoExposure: { destroy: vi.fn() }, localExposure: { destroy: vi.fn() },
	});
}

describe('wavefront compilation ownership', () => {
	beforeEach(() => { compilation.instances.length = 0; compilation.pending = Promise.resolve(); });

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
