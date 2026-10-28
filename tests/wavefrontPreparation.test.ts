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
const experimental = (label = '') => /^wavefront\.(?:Shade(?:Primary|Secondary|Late|Bucket)|CountBuckets|PrefixBuckets|ScatterBuckets)/.test(label);

describe('wavefront shading preparation', () => {
	afterEach(() => vi.unstubAllGlobals());

	it('prepares compact shading and partition stages lazily without scan pipelines', async () => {
		const { device, wavefront } = fixture();
		await wavefront.compiled;
		const count = device.createComputePipelineAsync.mock.calls.length;
		await wavefront.prepareBuckets([0, 4], 16, [0xffffffff, 0xffffffff], 0, 'compact');
		await wavefront.prepareBuckets([0, 4], 16, [0xffffffff, 0xffffffff], 0, 'compact');
		expect(device.createComputePipelineAsync.mock.calls.slice(count).map(([d]) => d.label).sort()).toEqual([
			'wavefront.CountBuckets.stack16', 'wavefront.PrefixBuckets.stack16', 'wavefront.ScatterBuckets.stack16',
			'wavefront.ShadeBucketCompact.stack0', 'wavefront.ShadeBucketCompact.stack4',
		]);
		expect(wavefront.shadeBucketMode).toBe('scan');
		wavefront.destroy();
		await expect(wavefront.prepareBuckets([1], 1, [0, 0])).rejects.toThrow('destroyed');
	});

	it('prepares only bucket shading kernels at smaller capacities and reuses a single global bucket', async () => {
		const { device, wavefront } = fixture();
		await wavefront.compiled;
		const count = device.createComputePipelineAsync.mock.calls.length;
		await wavefront.prepareBuckets([1], 1, [0xffffffff, 0xffffffff]);
		expect(device.createComputePipelineAsync).toHaveBeenCalledTimes(count);
		await wavefront.prepareBuckets([0, 4], 16, [0xffffffff, 0xffffffff]);
		await wavefront.prepareBuckets([0, 4], 16, [0xffffffff, 0xffffffff]);
		expect(device.createComputePipelineAsync.mock.calls.slice(count).map(([d]) => d.label).sort()).toEqual([
			'wavefront.ShadeBucket.stack0', 'wavefront.ShadeBucket.stack4',
			'wavefront.ShadeBucketDirect.stack0', 'wavefront.ShadeBucketDirect.stack4',
		]);
		await expect(wavefront.prepareBuckets([8], 4, [0, 0])).rejects.toThrow('Invalid shading bucket');
		wavefront.destroy();
	});

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
