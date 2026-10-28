import { afterEach, describe, expect, it, vi } from 'vitest';
import { Wavefront } from '../src/render/Wavefront';

function fixture() {
	vi.stubGlobal('GPUBufferUsage', { INDIRECT: 1, COPY_DST: 2, UNIFORM: 4 });
	vi.stubGlobal('GPUShaderStage', { COMPUTE: 1 });
	const device = {
		limits: { minUniformBufferOffsetAlignment: 256 }, features: new Set(),
		createBuffer: vi.fn(() => ({ getMappedRange: () => new ArrayBuffer(48), unmap() {}, destroy() {} })),
		createBindGroupLayout: vi.fn(() => ({})), createPipelineLayout: vi.fn(() => ({})),
		createShaderModule: vi.fn(() => ({})),
		createComputePipelineAsync: vi.fn(async (descriptor: GPUComputePipelineDescriptor) => ({ label: descriptor.label })),
	};
	const wavefront = new Wavefront(device as unknown as GPUDevice, {} as GPUBindGroupLayout, 1);
	return { device, wavefront };
}
const experimental = (label = '') => /^wavefront\.Shade(?:Primary|Secondary|Late)/.test(label);

describe('wavefront shading preparation', () => {
	afterEach(() => vi.unstubAllGlobals());

	it('keeps experimental entries out of default preparation and caches only requested phases', async () => {
		const { device, wavefront } = fixture();
		await wavefront.compiled;
		expect(device.createComputePipelineAsync.mock.calls.some(([d]) => experimental(d.label))).toBe(false);
		const count = device.createComputePipelineAsync.mock.calls.length;
		await wavefront.prepareShadeMode('split-late', 1);
		expect(wavefront.shadeMode).toBe('unified');
		expect(device.createComputePipelineAsync.mock.calls.slice(count).map(([d]) => d.label)).toEqual([
			'wavefront.ShadePrimaryLate.stack1', 'wavefront.ShadeSecondaryLate.stack1',
			'wavefront.ShadePrimaryLateDirect.stack1', 'wavefront.ShadeSecondaryLateDirect.stack1',
		]);
		await wavefront.prepareShadeMode('split-late', 1);
		expect(device.createComputePipelineAsync).toHaveBeenCalledTimes(count + 4);
		wavefront.shadeMode = 'split-late';
		await wavefront.prepareStack(2);
		expect(device.createComputePipelineAsync.mock.calls.filter(([d]) => experimental(d.label) && d.label?.endsWith('stack2'))).toHaveLength(4);
		wavefront.destroy();
	});

	it('shares concurrent compilation and does not publish entries after destruction', async () => {
		const { device, wavefront } = fixture();
		await wavefront.compiled;
		let release!: () => void;
		const gate = new Promise<void>(resolve => { release = resolve; });
		device.createComputePipelineAsync.mockImplementation(async descriptor => { await gate; return { label: descriptor.label }; });
		const a = wavefront.prepareShadeMode('late', 1), b = wavefront.prepareShadeMode('late', 1);
		const rejected = Promise.all([expect(a).rejects.toThrow(/destroyed/i), expect(b).rejects.toThrow(/destroyed/i)]);
		await vi.waitFor(() => expect(device.createComputePipelineAsync.mock.calls.filter(([d]) => experimental(d.label))).toHaveLength(2));
		wavefront.destroy(); release();
		await rejected;
	});

	it('retries a failed experimental group without rebuilding the base kernels', async () => {
		const { device, wavefront } = fixture();
		await wavefront.compiled;
		const count = device.createComputePipelineAsync.mock.calls.length;
		device.createComputePipelineAsync.mockRejectedValueOnce(new Error('compile failed'));
		await expect(wavefront.prepareShadeMode('late', 1)).rejects.toThrow('compile failed');
		await wavefront.prepareShadeMode('late', 1);
		expect(device.createComputePipelineAsync).toHaveBeenCalledTimes(count + 4);
		wavefront.destroy();
	});
});
