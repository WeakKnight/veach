// Histogram auto exposure (shaders/Passes/AutoExposure.slang): a
// 64-bucket log2 luminance histogram, a percentile-trimmed average and temporal adaptation into a
// GPU exposure buffer that the present pass applies directly. The buffer is also read back
// asynchronously; the renderer uses the last value as the pre-exposure of the next accumulation.
import autoExposureWgsl from '../generated/shaders/AutoExposure.wgsl?raw';
import type { PipelineCompiler } from './PipelineCompiler';

export const HISTOGRAM_SIZE = 64; // AutoExposure.slang
export const EYE_ADAPTATION_PARAMS_BYTES = 80;
const EXPOSURE_BYTES = 32; // float4 x 2
const MAX_READBACKS = 3;
// Transition distance in EV and reference frame time for matching the exponential slope.
const START_DISTANCE = 1.5;
const FRAME_TIME_EPS = 1 / 60;

// Luminance weighting options; local exposure meters with the same weights.
export enum LuminanceMethod {
	Uniform = 0,
	NTSC = 1,
	Rec709 = 2, // working color space
}

export function luminanceWeights(method: LuminanceMethod): [number, number, number] {
	if (method === LuminanceMethod.NTSC) return [0.3, 0.59, 0.11];
	if (method === LuminanceMethod.Rec709) return [0.2126, 0.7152, 0.0722];
	return [1 / 3, 1 / 3, 1 / 3];
}

// Exposure modes. Value 1 remains reserved; Basic metering is not implemented.
export enum AutoExposureMethod {
	Histogram = 0,
	Manual = 2,
}

// Eye adaptation inputs; EV100 values assume lens attenuation 0.78,
// where luminance max is 1 and EV100 = log2(luminance).
export interface EyeAdaptationInput {
	method: AutoExposureMethod;
	exposureCompensation: number; // EV: bias plus curve; Manual exposes by 2^compensation
	minBrightness: number; // EV100 of the white point (average luminance / 0.18)
	maxBrightness: number;
	histogramLogMin: number; // EV100
	histogramLogMax: number;
	lowPercent: number; // 1..99
	highPercent: number;
	speedUp: number; // f-stops per second
	speedDown: number;
	deltaTime: number; // seconds
	forceTarget: boolean; // jump to the target (scene changes)
	luminanceMethod: LuminanceMethod;
}

// Scales the exponential adaptation so its rate at the start
// distance matches the linear rate, making the switch between the two continuous.
export function exponentialAdaptationM(speed: number): number {
	const s = Math.max(speed, 1e-3);
	const startTime = START_DISTANCE / s;
	return FRAME_TIME_EPS / ((1 - Math.pow(2, -FRAME_TIME_EPS * s)) * startTime);
}

// Histogram lower bound, kept at least one stop below the upper bound; also the
// eye adaptation luminance floor (2^histogramLogMin).
export function histogramLogMin(p: Pick<EyeAdaptationInput, 'histogramLogMin' | 'histogramLogMax'>): number {
	return Math.min(p.histogramLogMin, p.histogramLogMax - 1);
}

// Packs EyeAdaptationParams for AutoExposure.slang.
export function packEyeAdaptationParams(out: Float32Array, p: EyeAdaptationInput): void {
	const logMin = histogramLogMin(p);
	const scale = 1 / (p.histogramLogMax - logMin);
	const manual = p.method === AutoExposureMethod.Manual;
	// white point luminance; histogram mode clamps the average luminance to it times middle grey, manual pins it to 1
	const minWhite = manual ? 1 : Math.pow(2, Math.min(p.minBrightness, p.maxBrightness));
	const maxWhite = manual ? 1 : Math.pow(2, p.maxBrightness);
	const high = Math.min(Math.max(p.highPercent, 1), 99) / 100;
	const low = Math.min(Math.min(Math.max(p.lowPercent, 1), 99) / 100, high);
	// Min Brightness = Max Brightness disables adaptation, like Manual
	const fixed = manual || p.minBrightness >= p.maxBrightness;
	out.set([scale, -logMin * scale, low, high], 0);
	out.set([minWhite * 0.18, maxWhite * 0.18, Math.pow(2, p.exposureCompensation), 0], 4);
	out.set([p.speedUp, p.speedDown, exponentialAdaptationM(p.speedUp), exponentialAdaptationM(p.speedDown)], 8);
	out.set([Math.max(p.deltaTime, 0), START_DISTANCE, fixed || p.forceTarget ? 1 : 0, 0], 12);
	out.set([...luminanceWeights(p.luminanceMethod), 0], 16);
}

export interface ExposureStats {
	exposure: number; // scale applied to scene-linear radiance
	targetExposure: number;
	averageLuminance: number;
}

interface Readback {
	buffer: GPUBuffer;
	state: 'idle' | 'recorded' | 'mapping';
}

export class AutoExposure {
	readonly exposureBuffer: GPUBuffer;
	private readonly paramsBuffer: GPUBuffer;
	private readonly histogramBuffer: GPUBuffer;
	private readonly layout: GPUBindGroupLayout;
	private histogramPipeline!: GPUComputePipeline;
	private adaptationPipeline!: GPUComputePipeline;
	readonly compiled: Promise<void>; // the pipelines have compiled
	private readonly params = new Float32Array(EYE_ADAPTATION_PARAMS_BYTES / 4);
	private readonly readbacks: Readback[] = [];
	private bindGroup: GPUBindGroup | null = null;
	private destroyed = false;
	// last exposure read back from the GPU (a few frames old)
	stats: ExposureStats = { exposure: 1, targetExposure: 1, averageLuminance: 0.18 };

	constructor(
		private readonly device: GPUDevice,
		compiler: PipelineCompiler,
	) {
		this.exposureBuffer = device.createBuffer({
			label: 'exposure',
			size: EXPOSURE_BYTES,
			usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST,
		});
		device.queue.writeBuffer(this.exposureBuffer, 0, new Float32Array([1, 1, 0.18, 1, 1, 0, 0, 0]));
		this.paramsBuffer = device.createBuffer({ label: 'eyeAdaptationParams', size: EYE_ADAPTATION_PARAMS_BYTES, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
		this.histogramBuffer = device.createBuffer({ label: 'exposureHistogram', size: HISTOGRAM_SIZE * 4, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST });

		// bindings as declared in AutoExposure.slang
		const C = GPUShaderStage.COMPUTE;
		this.layout = device.createBindGroupLayout({
			label: 'autoExposure',
			entries: [
				{ binding: 0, visibility: C, buffer: { type: 'uniform' } },
				{ binding: 1, visibility: C, buffer: { type: 'read-only-storage' } },
				{ binding: 2, visibility: C, buffer: { type: 'uniform' } },
				{ binding: 3, visibility: C, buffer: { type: 'storage' } },
				{ binding: 4, visibility: C, buffer: { type: 'storage' } },
			],
		});
		const module = device.createShaderModule({ label: 'AutoExposure', code: autoExposureWgsl });
		void module.getCompilationInfo().then((info) => {
			for (const m of info.messages) {
				if (m.type === 'error') console.error(`AutoExposure.wgsl:${m.lineNum}:${m.linePos} ${m.message}`);
			}
		});
		const layout = device.createPipelineLayout({ bindGroupLayouts: [this.layout] });
		this.compiled = Promise.all([
			compiler.compute({ label: 'exposureHistogram', layout, compute: { module, entryPoint: 'Histogram' } }),
			compiler.compute({ label: 'eyeAdaptation', layout, compute: { module, entryPoint: 'EyeAdaptation' } }),
		]).then(([histogram, adaptation]) => {
			this.histogramPipeline = histogram;
			this.adaptationPipeline = adaptation;
		});
	}

	// Rebinds after the accumulation buffer is reallocated.
	bind(frameUniforms: GPUBuffer, accumulation: GPUBuffer): void {
		this.bindGroup = this.device.createBindGroup({
			label: 'autoExposure',
			layout: this.layout,
			entries: [
				{ binding: 0, resource: { buffer: frameUniforms } },
				{ binding: 1, resource: { buffer: accumulation } },
				{ binding: 2, resource: { buffer: this.paramsBuffer } },
				{ binding: 3, resource: { buffer: this.histogramBuffer } },
				{ binding: 4, resource: { buffer: this.exposureBuffer } },
			],
		});
	}

	// Updates the exposure buffer from the accumulation (the frame uniforms must hold its
	// pre-exposure) and records a readback; call afterSubmit() once the encoder is submitted.
	encode(encoder: GPUCommandEncoder, input: EyeAdaptationInput, width: number, height: number): void {
		if (!this.bindGroup) return;
		packEyeAdaptationParams(this.params, input);
		this.device.queue.writeBuffer(this.paramsBuffer, 0, this.params);
		encoder.clearBuffer(this.histogramBuffer);
		const pass = encoder.beginComputePass({ label: 'autoExposure' });
		pass.setBindGroup(0, this.bindGroup);
		// metered in Manual too: the compensation and contrast curves key on the scene EV100
		pass.setPipeline(this.histogramPipeline);
		pass.dispatchWorkgroups(Math.ceil(width / 16), Math.ceil(height / 16));
		pass.setPipeline(this.adaptationPipeline);
		pass.dispatchWorkgroups(1);
		pass.end();
		this.recordReadback(encoder);
	}

	private recordReadback(encoder: GPUCommandEncoder): void {
		let readback = this.readbacks.find((r) => r.state === 'idle');
		if (!readback) {
			if (this.readbacks.length >= MAX_READBACKS) return; // all in flight
			readback = {
				buffer: this.device.createBuffer({ label: 'exposureReadback', size: EXPOSURE_BYTES, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ }),
				state: 'idle',
			};
			this.readbacks.push(readback);
		}
		encoder.copyBufferToBuffer(this.exposureBuffer, 0, readback.buffer, 0, EXPOSURE_BYTES);
		readback.state = 'recorded';
	}

	afterSubmit(): void {
		for (const r of this.readbacks) {
			if (r.state !== 'recorded') continue;
			r.state = 'mapping';
			r.buffer
				.mapAsync(GPUMapMode.READ)
				.then(() => {
					if (this.destroyed) return;
					const [exposure, targetExposure, averageLuminance] = new Float32Array(r.buffer.getMappedRange(), 0, 3);
					r.buffer.unmap();
					r.state = 'idle';
					if (Number.isFinite(exposure) && exposure > 0) {
						this.stats = { exposure, targetExposure, averageLuminance };
					}
				})
				.catch(() => {
					r.state = 'idle';
				});
		}
	}

	destroy(): void {
		this.destroyed = true;
		this.exposureBuffer.destroy();
		this.paramsBuffer.destroy();
		this.histogramBuffer.destroy();
		for (const r of this.readbacks) r.buffer.destroy();
	}
}
