// GPU host of the fused fine-residual Fusion local exposure (shaders/Passes/LocalExposure.slang),
// scheduled like the LocalExposure project's FineResidualToneMapper: quarter-resolution
// initialize, downsample to a small tail, one-workgroup tail reduction / reconstruction, coarse
// to fine reconstruction with levels 2 -> 0 fused. Present.slang applies the result.
import localExposureWgsl from '../generated/shaders/LocalExposure.wgsl?raw';
import { FORWARD_LUT_SIZE, INVERSE_LUT_SIZE, type ZCurve } from './LocalExposureCurve';
import type { PipelineCompiler } from './PipelineCompiler';

export const LOCAL_EXPOSURE_PARAMS_BYTES = 48;
// Unreal's r.LocalExposure.ExposureFusion.NumLevels default.
const MAX_LEVELS = 16;
const FINE_LEVELS = 3; // rgba16float pyramid mips; coarser mips are rgba32float

export interface LocalExposureFrame {
	enabled: boolean;
	visualize: boolean;
	luminanceWeights: [number, number, number];
	luminanceMin: number;
}

interface Dispatch {
	entryPoint: string; // pipeline looked up when encoding (resize runs before the pipelines compile)
	bindGroup: GPUBindGroup;
	workgroups: [number, number];
}

export function fusionLevelCount(width: number, height: number, maxLevels = MAX_LEVELS): number {
	return Math.min(maxLevels, Math.floor(Math.log2(Math.max(1, Math.min(width, height)))) + 1);
}

export class LocalExposure {
	readonly paramsBuffer: GPUBuffer;
	readonly forwardLut: GPUTexture;
	readonly reducedLut: GPUTexture;
	readonly inverseLut: GPUTexture;
	private readonly params = new ArrayBuffer(LOCAL_EXPOSURE_PARAMS_BYTES);
	private readonly levelBuffers: { normal: GPUBuffer; coarsest: GPUBuffer };
	private readonly dummyResult: GPUTexture;
	private readonly layouts: Record<string, GPUBindGroupLayout> = {};
	private readonly pipelines: Record<string, GPUComputePipeline> = {};
	readonly compiled: Promise<void>; // the pipelines have compiled
	private textures: GPUTexture[] = [];
	private pyramidMip0: GPUTextureView | null = null;
	private residual: GPUTextureView | null = null;
	private dispatches: Dispatch[] = [];
	private curve: ZCurve | null = null;

	constructor(
		private readonly device: GPUDevice,
		compiler: PipelineCompiler,
	) {
		this.paramsBuffer = device.createBuffer({ label: 'localExposureParams', size: LOCAL_EXPOSURE_PARAMS_BYTES, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
		const table = (label: string, width: number, format: GPUTextureFormat) =>
			device.createTexture({ label, size: [width, 1], format, usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST });
		this.forwardLut = table('localExposureForwardLut', FORWARD_LUT_SIZE, 'rgba32float');
		this.reducedLut = table('localExposureReducedLut', FORWARD_LUT_SIZE, 'rgba32float');
		this.inverseLut = table('localExposureInverseLut', INVERSE_LUT_SIZE, 'r32float');
		this.dummyResult = device.createTexture({ label: 'localExposureDummy', size: [1, 1], format: 'r32float', usage: GPUTextureUsage.TEXTURE_BINDING });
		const level = (label: string, coarsest: number) => {
			const buffer = device.createBuffer({ label, size: 16, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
			device.queue.writeBuffer(buffer, 0, new Uint32Array([coarsest, 0, 0, 0]));
			return buffer;
		};
		this.levelBuffers = { normal: level('localExposureLevel', 0), coarsest: level('localExposureCoarsest', 1) };

		const module = device.createShaderModule({ label: 'LocalExposure', code: localExposureWgsl });
		void module.getCompilationInfo().then((info) => {
			for (const m of info.messages) {
				if (m.type === 'error') console.error(`LocalExposure.wgsl:${m.lineNum}:${m.linePos} ${m.message}`);
			}
		});
		// bindings as declared in LocalExposure.slang
		const C = GPUShaderStage.COMPUTE;
		const uniform = (binding: number): GPUBindGroupLayoutEntry => ({ binding, visibility: C, buffer: { type: 'uniform' } });
		const storage = (binding: number): GPUBindGroupLayoutEntry => ({ binding, visibility: C, buffer: { type: 'read-only-storage' } });
		const texture = (binding: number): GPUBindGroupLayoutEntry => ({ binding, visibility: C, texture: { sampleType: 'unfilterable-float' } });
		const output = (binding: number, format: GPUTextureFormat): GPUBindGroupLayoutEntry => ({ binding, visibility: C, storageTexture: { access: 'write-only', format } });
		const entries: Record<string, GPUBindGroupLayoutEntry[]> = {
			Initialize: [uniform(0), storage(1), storage(2), uniform(3), texture(4), texture(5), output(11, 'rgba16float')],
			DownsampleHalf: [texture(6), output(11, 'rgba16float')],
			DownsampleFloat: [texture(6), output(12, 'rgba32float')],
			Tail: [texture(6), output(13, 'r32float'), uniform(14)],
			Reconstruct: [texture(6), texture(7), texture(8), output(13, 'r32float'), uniform(14)],
			ReconstructFused: [texture(6), texture(7), texture(8), texture(9), texture(10), output(13, 'r32float')],
		};
		const compiled: Promise<void>[] = [];
		for (const [entryPoint, layoutEntries] of Object.entries(entries)) {
			const layout = device.createBindGroupLayout({ label: entryPoint, entries: layoutEntries });
			this.layouts[entryPoint] = layout;
			const pipeline = compiler.compute({
				label: `localExposure${entryPoint}`,
				layout: device.createPipelineLayout({ bindGroupLayouts: [layout] }),
				compute: { module, entryPoint },
			});
			compiled.push(pipeline.then((p) => void (this.pipelines[entryPoint] = p)));
		}
		this.compiled = Promise.all(compiled).then(() => {});
	}

	get calibrated(): boolean {
		return this.curve !== null;
	}

	setCurve(curve: ZCurve): void {
		this.curve = curve;
		this.device.queue.writeTexture({ texture: this.inverseLut }, curve.inverse, {}, [INVERSE_LUT_SIZE, 1]);
	}

	setTables(forward: Float32Array<ArrayBuffer>, reduced: Float32Array<ArrayBuffer>): void {
		this.device.queue.writeTexture({ texture: this.forwardLut }, forward, {}, [FORWARD_LUT_SIZE, 1]);
		this.device.queue.writeTexture({ texture: this.reducedLut }, reduced, {}, [FORWARD_LUT_SIZE, 1]);
	}

	// Views Present.slang samples (the quarter-resolution residual and pyramid mip 0).
	get presentViews(): { residual: GPUTextureView; pyramid: GPUTextureView } {
		return { residual: this.residual!, pyramid: this.pyramidMip0! };
	}

	// Reallocates the quarter-resolution pyramid for a new accumulation size and records the
	// dispatch schedule; call before rebuilding the present bind group.
	resize(frameUniforms: GPUBuffer, accumulation: GPUBuffer, exposure: GPUBuffer, width: number, height: number): void {
		for (const t of this.textures) t.destroy();
		const device = this.device;
		const w = Math.ceil(width / 4);
		const h = Math.ceil(height / 4);
		const levels = fusionLevelCount(w, h);
		const usage = GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.STORAGE_BINDING;
		const fine = device.createTexture({ label: 'localExposurePyramid', size: [w, h], format: 'rgba16float', mipLevelCount: Math.min(FINE_LEVELS, levels), usage });
		const coarse =
			levels > FINE_LEVELS
				? device.createTexture({ label: 'localExposureCoarsePyramid', size: [Math.max(1, w >> FINE_LEVELS), Math.max(1, h >> FINE_LEVELS)], format: 'rgba32float', mipLevelCount: levels - FINE_LEVELS, usage })
				: null;
		const reconstruction = device.createTexture({ label: 'localExposureReconstruction', size: [w, h], format: 'r32float', mipLevelCount: levels, usage });
		this.textures = coarse ? [fine, coarse, reconstruction] : [fine, reconstruction];
		const pyramid = (mip: number) => (mip < FINE_LEVELS ? fine.createView({ baseMipLevel: mip, mipLevelCount: 1 }) : coarse!.createView({ baseMipLevel: mip - FINE_LEVELS, mipLevelCount: 1 }));
		const result = (mip: number) => reconstruction.createView({ baseMipLevel: mip, mipLevelCount: 1 });
		const size = (mip: number): [number, number] => [Math.max(1, w >> mip), Math.max(1, h >> mip)];
		const groups = (mip: number, x: number, y: number): [number, number] => [Math.ceil(size(mip)[0] / x), Math.ceil(size(mip)[1] / y)];
		this.pyramidMip0 = pyramid(0);
		this.residual = result(0);

		const dispatch = (entryPoint: string, resources: Record<number, GPUBindingResource>, workgroups: [number, number]): Dispatch => ({
			entryPoint,
			bindGroup: device.createBindGroup({
				label: `localExposure${entryPoint}`,
				layout: this.layouts[entryPoint],
				entries: Object.entries(resources).map(([binding, resource]) => ({ binding: Number(binding), resource })),
			}),
			workgroups,
		});
		const list: Dispatch[] = [];
		list.push(
			dispatch(
				'Initialize',
				{ 0: { buffer: frameUniforms }, 1: { buffer: accumulation }, 2: { buffer: exposure }, 3: { buffer: this.paramsBuffer }, 4: this.forwardLut.createView(), 5: this.reducedLut.createView(), 11: pyramid(0) },
				groups(0, 4, 8),
			),
		);
		// the tail takes over once a level fits one 16x8 workgroup
		let tailMip = 1;
		while (tailMip < levels - 1 && (size(tailMip)[0] > 16 || size(tailMip)[1] > 8)) tailMip++;
		const useTail = tailMip < levels - 1;
		for (let mip = 1; mip < (useTail ? tailMip + 1 : levels); mip++) {
			list.push(dispatch(mip < FINE_LEVELS ? 'DownsampleHalf' : 'DownsampleFloat', { 6: pyramid(mip - 1), [mip < FINE_LEVELS ? 11 : 12]: pyramid(mip) }, groups(mip, 4, 16)));
		}
		const tailLevels = levels - tailMip;
		this.device.queue.writeBuffer(this.levelBuffers.normal, 0, new Uint32Array([0, tailLevels, 0, 0]));
		this.device.queue.writeBuffer(this.levelBuffers.coarsest, 0, new Uint32Array([1, tailLevels, 0, 0]));
		if (useTail) {
			list.push(dispatch('Tail', { 6: pyramid(tailMip), 13: result(tailMip), 14: { buffer: this.levelBuffers.normal } }, [1, 1]));
		}
		const fuseFine = levels > FINE_LEVELS && (!useTail || tailMip >= FINE_LEVELS);
		for (let mip = (useTail ? tailMip : levels) - 1; mip >= 0; mip--) {
			if (fuseFine && (mip === 1 || mip === 2)) continue;
			if (fuseFine && mip === 0) {
				list.push(dispatch('ReconstructFused', { 6: pyramid(0), 7: pyramid(1), 8: result(3), 9: pyramid(2), 10: pyramid(3), 13: result(0) }, groups(0, 16, 16)));
				continue;
			}
			const coarsest = mip === levels - 1;
			list.push(
				dispatch(
					'Reconstruct',
					{
						6: pyramid(mip),
						7: pyramid(Math.min(mip + 1, levels - 1)),
						8: coarsest ? this.dummyResult.createView() : result(mip + 1),
						13: result(mip),
						14: { buffer: coarsest ? this.levelBuffers.coarsest : this.levelBuffers.normal },
					},
					groups(mip, 8, 8),
				),
			);
		}
		this.dispatches = list;
	}

	// Writes the per-frame parameters (also read by Present) and records the graph when enabled.
	encode(encoder: GPUCommandEncoder, frame: LocalExposureFrame): void {
		const curve = this.curve;
		const enabled = frame.enabled && curve !== null;
		const f32 = new Float32Array(this.params);
		const u32 = new Uint32Array(this.params);
		f32.set([curve?.maxInput ?? 1, curve?.maxLightness ?? 1, curve?.warpEpsilon ?? 0, curve?.warpSpan ?? 1], 0);
		f32.set([...frame.luminanceWeights, frame.luminanceMin], 4);
		u32.set([enabled ? 1 : 0, frame.visualize ? 1 : 0, 0, 0], 8);
		this.device.queue.writeBuffer(this.paramsBuffer, 0, this.params);
		if (!enabled) return;
		const pass = encoder.beginComputePass({ label: 'localExposure' });
		for (const d of this.dispatches) {
			pass.setPipeline(this.pipelines[d.entryPoint]);
			pass.setBindGroup(0, d.bindGroup);
			pass.dispatchWorkgroups(d.workgroups[0], d.workgroups[1]);
		}
		pass.end();
	}

	destroy(): void {
		for (const t of this.textures) t.destroy();
		this.forwardLut.destroy();
		this.reducedLut.destroy();
		this.inverseLut.destroy();
		this.dummyResult.destroy();
		this.paramsBuffer.destroy();
		this.levelBuffers.normal.destroy();
		this.levelBuffers.coarsest.destroy();
	}
}
