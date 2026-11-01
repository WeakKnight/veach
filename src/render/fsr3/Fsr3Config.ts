// FidelityFX FSR 3.1.4 upscaler host math (docs/Fsr3.md): a float32-faithful port of the CPU parts of
// ThirdParty/FidelityFX/host/ffx_fsr3upscaler.cpp (dispatch constants, jitter), ffx_spd.h ffxSpdSetup and
// ffx_fsr1.h FsrRcasCon. Fsr3UpscalerConstants mirrors cbFSR3Upscaler in shaders/Fsr3/Fsr3Callbacks.hlsli.

const f32 = Math.fround;
const FLT_EPSILON = 1.1920928955078125e-7;

export const FSR3_CONSTANTS_BYTES = 160; // 37 32-bit words, padded to 16 bytes
export const FSR3_SPD_CONSTANTS_BYTES = 32;
export const FSR3_RCAS_CONSTANTS_BYTES = 16;

// ffx_fsr3upscaler.cpp halton(), in float32 like the C++.
function halton(index: number, base: number): number {
	let f = 1, result = 0;
	for (let current = index; current > 0;) {
		f = f32(f / base);
		result = f32(result + f32(f * (current % base)));
		current = Math.floor(f32(current / base));
	}
	return result;
}

/** ffxFsr3UpscalerGetJitterPhaseCount. */
export function fsr3JitterPhaseCount(renderWidth: number, displayWidth: number): number {
	return Math.trunc(f32(8 * f32(Math.pow(f32(displayWidth / renderWidth), 2))));
}

/** ffxFsr3UpscalerGetJitterOffset: pixel offset in [-0.5, 0.5]; FSR samples pixel p at p + 0.5 - jitter. */
export function fsr3JitterOffset(index: number, phaseCount: number): [number, number] {
	if (phaseCount <= 0) throw new Error('FSR3 jitter phase count must be positive');
	const i = (index % phaseCount) + 1;
	return [f32(halton(i, 2) - 0.5), f32(halton(i, 3) - 0.5)];
}

/** ffx_spd.h ffxSpdSetup for the rectangle (0, 0, width, height), mips from the size (capped at 12). */
export function fsr3SpdSetup(width: number, height: number): { dispatch: [number, number]; numWorkGroups: number; mips: number } {
	const dispatch: [number, number] = [Math.floor((width - 1) / 64) + 1, Math.floor((height - 1) / 64) + 1];
	return { dispatch, numWorkGroups: dispatch[0] * dispatch[1], mips: Math.min(Math.floor(Math.log2(Math.max(width, height))), 12) };
}

// IEEE half bits, round to nearest even (ffxF32ToF16 is exact for the sharpness values RCAS uses).
function halfBits(value: number): number {
	const f = new Float32Array([value]), u = new Uint32Array(f.buffer)[0];
	const sign = (u >>> 16) & 0x8000, exponent = ((u >>> 23) & 0xff) - 127 + 15, mantissa = u & 0x7fffff;
	if (exponent <= 0) return sign;
	if (exponent >= 31) return sign | 0x7c00;
	let h = sign | (exponent << 10) | (mantissa >>> 13);
	const rest = mantissa & 0x1fff;
	if (rest > 0x1000 || (rest === 0x1000 && (h & 1))) h++;
	return h;
}

/** FsrRcasCon with FSR3's remapping: sharpness 0 (none) .. 1 (maximum) -> stops 2 .. 0. */
export function fsr3RcasConstants(sharpness: number): Uint32Array<ArrayBuffer> {
	const stops = f32(f32(-2 * sharpness) + 2);
	const linear = f32(Math.pow(2, -stops));
	const out = new Uint32Array(4);
	out[0] = new Uint32Array(new Float32Array([linear]).buffer)[0];
	out[1] = halfBits(linear) | (halfBits(linear) << 16);
	return out;
}

/** FfxFsr3UpscalerDispatchDescription fields Veach uses. */
export interface Fsr3Dispatch {
	renderSize: [number, number];
	upscaleSize: [number, number];
	jitter: [number, number]; // FSR jitter offset (fsr3JitterOffset)
	motionVectorScale: [number, number]; // motion vectors are previous - current in render pixels: (1, 1)
	reset: boolean;
	frameTimeDelta: number; // milliseconds
	preExposure: number;
	cameraNear: number;
	cameraFar: number;
	cameraFovAngleVertical: number; // radians
	viewSpaceToMetersFactor: number;
	sharpness: number; // 0..1; 0 disables RCAS (enableSharpening = false)
}

// cbFSR3Upscaler word offsets (Fsr3UpscalerConstants in ffx_fsr3upscaler_private.h).
const W = {
	renderSize: 0, previousFrameRenderSize: 2, upscaleSize: 4, previousFrameUpscaleSize: 6, maxRenderSize: 8, maxUpscaleSize: 10,
	deviceToViewDepth: 12, jitter: 16, previousFrameJitter: 18, motionVectorScale: 20, downscaleFactor: 22, motionVectorJitterCancellation: 24,
	tanHalfFOV: 26, jitterPhaseCount: 27, deltaTime: 28, deltaPreExposure: 29, viewSpaceToMetersFactor: 30, frameIndex: 31,
	velocityFactor: 32, reactivenessScale: 33, shadingChangeScale: 34, accumulationAddedPerFrame: 35, minDisocclusionAccumulation: 36,
} as const;

/** Persistent state of FfxFsr3UpscalerContext_Private the constants derive from (Veach's context flags). */
export class Fsr3ConstantState {
	readonly words = new ArrayBuffer(FSR3_CONSTANTS_BYTES);
	private readonly i = new Int32Array(this.words);
	private readonly f = new Float32Array(this.words);
	private firstExecution = true;
	private preExposure = 0;
	private previousFramePreExposure = 0;

	constructor(readonly maxRenderSize: [number, number], readonly maxUpscaleSize: [number, number]) {
		// fsr3upscalerCreate
		this.i.set(maxUpscaleSize, W.maxUpscaleSize);
		this.f[W.velocityFactor] = 1;
		this.f[W.reactivenessScale] = 1;
		this.f[W.shadingChangeScale] = 1;
		this.f[W.accumulationAddedPerFrame] = 1 / 3;
		this.f[W.minDisocclusionAccumulation] = -1 / 3;
	}

	get frameIndex(): number { return this.f[W.frameIndex]; }

	/** fsr3upscalerDispatch's constant updates; returns whether the history resets (params.reset or first execution). */
	update(d: Fsr3Dispatch): boolean {
		const i = this.i, f = this.f;
		const reset = d.reset || this.firstExecution;
		this.firstExecution = false;
		f[W.previousFrameJitter] = f[W.jitter]; f[W.previousFrameJitter + 1] = f[W.jitter + 1];
		f[W.jitter] = d.jitter[0]; f[W.jitter + 1] = d.jitter[1];
		i[W.previousFrameRenderSize] = i[W.renderSize]; i[W.previousFrameRenderSize + 1] = i[W.renderSize + 1];
		i[W.renderSize] = d.renderSize[0]; i[W.renderSize + 1] = d.renderSize[1];
		i.set(this.maxRenderSize, W.maxRenderSize);
		// compute the horizontal FOV for the shader from the vertical one
		const aspectRatio = f32(d.renderSize[0] / d.renderSize[1]);
		const cameraAngleHorizontal = f32(f32(Math.atan(f32(f32(Math.tan(f32(d.cameraFovAngleVertical / 2))) * aspectRatio))) * 2);
		f[W.tanHalfFOV] = f32(Math.tan(f32(cameraAngleHorizontal * 0.5)));
		f[W.viewSpaceToMetersFactor] = d.viewSpaceToMetersFactor > 0 ? d.viewSpaceToMetersFactor : 1;
		this.setupDeviceDepthToViewSpaceDepthParams(d);
		i[W.previousFrameUpscaleSize] = i[W.upscaleSize]; i[W.previousFrameUpscaleSize + 1] = i[W.upscaleSize + 1];
		if (d.upscaleSize[0] === 0 && d.upscaleSize[1] === 0) i.set(this.maxUpscaleSize, W.upscaleSize);
		else i.set(d.upscaleSize, W.upscaleSize);
		f[W.downscaleFactor] = f32(i[W.renderSize] / i[W.upscaleSize]);
		f[W.downscaleFactor + 1] = f32(i[W.renderSize + 1] / i[W.upscaleSize + 1]);
		// calculate pre-exposure relevant factors
		f[W.deltaPreExposure] = 1;
		this.previousFramePreExposure = this.preExposure;
		this.preExposure = d.preExposure !== 0 ? f32(d.preExposure) : 1;
		if (this.previousFramePreExposure > 0) f[W.deltaPreExposure] = f32(this.preExposure / this.previousFramePreExposure);
		// render-resolution motion vectors (no FFX_FSR3UPSCALER_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS), no jitter cancellation
		f[W.motionVectorScale] = f32(d.motionVectorScale[0] / i[W.renderSize]);
		f[W.motionVectorScale + 1] = f32(d.motionVectorScale[1] / i[W.renderSize + 1]);
		// lock data, assuming jitter sequence length computation for now
		const jitterPhaseCount = fsr3JitterPhaseCount(d.renderSize[0], i[W.upscaleSize]);
		if (reset || f[W.jitterPhaseCount] === 0) f[W.jitterPhaseCount] = jitterPhaseCount;
		else if (jitterPhaseCount > f[W.jitterPhaseCount]) f[W.jitterPhaseCount]++;
		else if (jitterPhaseCount < f[W.jitterPhaseCount]) f[W.jitterPhaseCount]--;
		// convert delta time to seconds and clamp to [0, 1]
		f[W.deltaTime] = Math.max(0, Math.min(1, f32(d.frameTimeDelta / 1000)));
		f[W.frameIndex] = reset ? 0 : f[W.frameIndex] + 1;
		return reset;
	}

	// FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED | FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE
	private setupDeviceDepthToViewSpaceDepthParams(d: Fsr3Dispatch): void {
		const f = this.f;
		// inverted: near and far swap; inverted infinite: c = FLT_EPSILON, e = the smaller plane (near)
		const fMax = Math.min(d.cameraNear, d.cameraFar);
		f[W.deviceToViewDepth] = f32(-1 * f32(FLT_EPSILON));
		f[W.deviceToViewDepth + 1] = f32(fMax);
		const aspect = f32(d.renderSize[0] / d.renderSize[1]);
		const half = f32(0.5 * d.cameraFovAngleVertical);
		const cotHalfFovY = f32(f32(Math.cos(half)) / f32(Math.sin(half)));
		const a = f32(cotHalfFovY / aspect), b = cotHalfFovY;
		f[W.deviceToViewDepth + 2] = f32(1 / a);
		f[W.deviceToViewDepth + 3] = f32(1 / b);
	}
}
