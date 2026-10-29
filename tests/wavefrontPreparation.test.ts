import { afterEach, describe, expect, it, vi } from 'vitest';
import { Wavefront } from '../src/render/Wavefront';

function fixture() {
	vi.stubGlobal('GPUBufferUsage', { INDIRECT: 1, COPY_DST: 2, UNIFORM: 4 });
	vi.stubGlobal('GPUTextureUsage', { TEXTURE_BINDING: 4 });
	vi.stubGlobal('GPUShaderStage', { COMPUTE: 1 });
	const device = {
		limits: { minUniformBufferOffsetAlignment: 256 }, features: new Set(),
		createTexture: vi.fn(() => ({ createView: () => ({}), destroy() {} })),
		createBuffer: vi.fn(() => ({ getMappedRange: () => new ArrayBuffer(48), unmap() {}, destroy() {} })),
		createBindGroupLayout: vi.fn(() => ({})), createPipelineLayout: vi.fn(() => ({})),
		createShaderModule: vi.fn(() => ({})),
		createComputePipelineAsync: vi.fn(async (descriptor: GPUComputePipelineDescriptor) => ({ label: descriptor.label })),
	};
	const wavefront = new Wavefront(device as unknown as GPUDevice, {} as GPUBindGroupLayout, 1);
	return { device, wavefront };
}
const experimental = (label = '') => /^wavefront\.(?:Shade(?:Primary|Secondary|Late|Bucket|Surface|Light)|(?:ShadowClassify|ShadowAlpha|CompactShadowAlpha)|(?:Count|Prefix|Scatter)(?:Buckets|Materials))/.test(label);

describe('wavefront shading preparation', () => {
	afterEach(() => vi.unstubAllGlobals());

	it('compiles active dispatch choices and lazily adds tail/direct/sort variants once', async () => {
		const { device, wavefront } = fixture();
		await wavefront.compiled;
		const labels = () => device.createComputePipelineAsync.mock.calls.map(([d]) => d.label!);
		expect(labels().some(label => /Tail|Direct|Sort|Dense|Packet|Spatial/.test(label))).toBe(false);
		expect(labels()).toContain('wavefront.CompactIntersectAdaptive.stack1');
		wavefront.tailStart = 2; wavefront.directStages = 4; wavefront.sort = 'material';
		await wavefront.prepareStack(1);
		expect(labels()).toEqual(expect.arrayContaining(['wavefront.Tail.stack1', 'wavefront.ShadowDirect.stack1', 'wavefront.SortMaterial64.stack1']));
		expect(labels().filter(label => label === 'wavefront.Shade.stack1')).toHaveLength(1);
		const count = labels().length;
		wavefront.tailStart = Infinity; wavefront.directStages = 0; wavefront.sort = 'none';
		await wavefront.prepareStack(1);
		expect(labels()).toHaveLength(count);
		wavefront.destroy();
	});

	it('prepares light and alpha work at independent capacities without traversal SVM', async () => {
		const { device, wavefront } = fixture();
		await wavefront.compiled;
		const count = device.createComputePipelineAsync.mock.calls.length;
		await wavefront.prepareLightStages(4, 2, [0xffffffff, 0xffffffff], 0, [0, 4]);
		await wavefront.prepareShadowBatches(1, [0xffffffff, 0xffffffff]);
		const added = device.createComputePipelineAsync.mock.calls.slice(count).map(([d]) => d);
		expect(added.filter(d => d.label?.includes('ShadeLight')).every(d => d.label?.endsWith('stack2'))).toBe(true);
		expect(added.filter(d => /\.ShadowAlpha\./.test(d.label!)).map(d => d.label)).toHaveLength(1);
		expect(added.filter(d => /\.ShadowAlpha\./.test(d.label!)).every(d => d.label?.endsWith('stack1') && d.compute.constants)).toBe(true);
		expect(added.filter(d => /(?:ShadowClassify|CompactShadowAlpha)/.test(d.label!)).every(d => d.label?.endsWith('stack0') && !d.compute.constants)).toBe(true);
		const n = device.createComputePipelineAsync.mock.calls.length;
		await wavefront.prepareShadowBatches(1, [0xffffffff, 0xffffffff]);
		expect(device.createComputePipelineAsync).toHaveBeenCalledTimes(n);
		Object.assign(device.limits, { maxStorageBufferBindingSize: 128 * 1024 * 1024, maxBufferSize: 128 * 1024 * 1024 });
		const size = wavefront.storageBytes(1000), capacity = wavefront.capacity(1024 * 1024);
		wavefront.batchedShadows = true;
		expect(wavefront.storageBytes(1000) - size).toBe(0);
		expect(wavefront.capacity(1024 * 1024)).toBe(capacity);
		wavefront.separateLight = true;
		expect(wavefront.storageBytes(1000) - size).toBe(1000 * 32);
		expect(wavefront.storageBytes(1024 * 1024) + 1024 * 1024 * 48).toBeLessThanOrEqual(128 * 1024 * 1024);
		wavefront.destroy();
	});

	it('keeps opaque dispatch unchanged and dispatches alpha only through the compact queue', async () => {
		const { device, wavefront } = fixture();
		Object.assign(device.limits, { maxStorageBufferBindingSize: 128 * 1024 * 1024, maxBufferSize: 128 * 1024 * 1024 });
		Object.assign(device, { queue: { writeBuffer() {} }, createBindGroup: () => ({}) });
		await wavefront.compiled;
		await wavefront.prepareShadowBatches(1, [0xffffffff, 0xffffffff]);
		wavefront.bind({} as GPUBuffer, { createView: () => ({}) } as GPUTexture);
		const passes: { label: string; indirect?: number; direct?: boolean }[] = [];
		const encoder = {
			beginComputePass: ({ label }: { label: string }) => {
				const pass = { label }; passes.push(pass);
				return { setPipeline() {}, setBindGroup() {}, end() {},
					dispatchWorkgroups: () => Object.assign(pass, { direct: true }),
					dispatchWorkgroupsIndirect: (_buffer: GPUBuffer, offset: number) => Object.assign(pass, { indirect: offset }) };
			},
			clearBuffer() {}, copyBufferToBuffer() {},
		} as unknown as GPUCommandEncoder;
		const encode = async (alpha: boolean) => {
			wavefront.hasAlphaTested = alpha;
			await wavefront.prepareStack(1);
			passes.length = 0;
			wavefront.encode(encoder, {} as GPUBindGroup, 129, 97, 3, alpha, 1, 0, [0xffffffff, 0xffffffff]);
			return passes.map(p => ({ ...p }));
		};
		const opaque = await encode(false);
		wavefront.batchedShadows = true;
		expect(await encode(false)).toEqual(opaque);
		for (const directStages of [0, 4, 7]) {
			wavefront.directStages = directStages;
			const alpha = await encode(true);
			for (const name of ['ShadowClassify', 'CompactShadowAlpha', 'ShadowAlpha'])
				expect(alpha.filter(p => p.label.startsWith(`wavefront.${name}.`))).toHaveLength(6); // Two padded tiles, three bounces.
			expect(alpha.filter(p => p.label.startsWith('wavefront.ShadowAlpha.')).every(p => p.indirect === 16 && !p.direct)).toBe(true);
			expect(alpha.some(p => p.label.includes('ShadowBatch') || p.label.startsWith('wavefront.Shadow.'))).toBe(false);
		}
		wavefront.destroy();
	});

	it('groups materials with one global-capacity shading pipeline, including a single capacity', async () => {
		const { device, wavefront } = fixture();
		await wavefront.compiled;
		const count = device.createComputePipelineAsync.mock.calls.length;
		await wavefront.prepareBuckets([0, 4], 16, [0xffffffff, 0xffffffff], 0, 'material');
		await wavefront.prepareBuckets([0, 4], 16, [0xffffffff, 0xffffffff], 0, 'material');
		await wavefront.prepareBuckets([0], 0, [0xffffffff, 0xffffffff], 0, 'material');
		expect(device.createComputePipelineAsync.mock.calls.slice(count).map(([d]) => d.label).sort()).toEqual([
			'wavefront.CountMaterials.stack0', 'wavefront.CountMaterials.stack16',
			'wavefront.PrefixMaterials.stack0', 'wavefront.PrefixMaterials.stack16',
			'wavefront.ScatterMaterials.stack0', 'wavefront.ScatterMaterials.stack16',
			'wavefront.ShadeBucketCompact.stack0', 'wavefront.ShadeBucketCompact.stack16',
		]);
		wavefront.bind({} as GPUBuffer, {} as GPUTexture);
		wavefront.shadeBuckets = true; wavefront.shadeBucketMode = 'material';
		for (const materials of [0, 257, NaN]) expect(() => wavefront.encode({} as GPUCommandEncoder, {} as GPUBindGroup,
			1, 1, 1, false, 1, 0, [0, 0], 0, [1], materials)).toThrow('1..256 materials');
		wavefront.destroy();
	});

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
		expect(device.createComputePipelineAsync).toHaveBeenCalledTimes(count + 3); // Only the failed entry retries.
		wavefront.destroy();
	});
});
