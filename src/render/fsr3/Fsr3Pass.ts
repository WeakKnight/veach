// Veach's FSR3 integration (docs/Fsr3.md): converts the realtime frame (the TAA input layout and TAA motion) into
// FidelityFX's input textures, runs the upscaler and writes the presentation layout at the upscaled size.
import { fsr3Shaders } from '../../generated/fsr3/Fsr3Shaders';
import { vec3, type Vec3 } from '../../math/Math';
import type { Fsr3Dispatch } from './Fsr3Config';
import { Fsr3Upscaler, createPipeline, type Fsr3Inputs, type Pipeline } from './Fsr3Upscaler';

export interface Fsr3Stats { active: boolean; reason: string | null; frames: number; renderSize: [number, number]; upscaleSize: [number, number]; bytes: number }
export interface Fsr3Camera { right: Vec3; up: Vec3; forward: Vec3 }
export interface Fsr3Frame {
	frame: GPUBuffer; // FrameUniforms at the render size (jitter in temporal.xy)
	color: GPUBuffer; // TAA input layout: three float4 per pixel
	motion: GPUBuffer; // TAA motion: two float4 per pixel
	renderSize: [number, number];
	upscaleSize: [number, number];
	jitter: [number, number]; // FSR jitter offset in pixels (fsr3JitterOffset)
	camera: Fsr3Camera;
	reset: boolean;
	frameTimeDelta: number; // milliseconds
	preExposure: number;
	sharpness: number;
}

// FSR input depth = FSR3_NEAR_PLANE / viewZ (inverted, infinite); near only scales FidelityFX's depth conversion.
export const FSR3_NEAR_PLANE = 0.01;

export class Fsr3Pass {
	stats: Fsr3Stats = { active: false, reason: 'not-rendered', frames: 0, renderSize: [0, 0], upscaleSize: [0, 0], bytes: 0 };
	private upscaler: Fsr3Upscaler | null = null;
	private inputs: { color: GPUTexture; depth: GPUTexture; motion: GPUTexture } | null = null;
	private output: { texture: GPUTexture; buffer: GPUBuffer } | null = null;
	private readonly params: GPUBuffer;
	/**
	 * Validation (scripts/fsr3-reference): called after each dispatch with FidelityFX's exact inputs, output and
	 * dispatch description, in the frame's encoder. The textures allow COPY_SRC.
	 */
	capture: ((encoder: GPUCommandEncoder, textures: Fsr3Inputs, dispatch: Fsr3Dispatch) => void) | null = null;

	private constructor(private readonly device: GPUDevice, private readonly ffx: Awaited<ReturnType<typeof Fsr3Upscaler.compile>>,
		private readonly veach: { inputs: Pipeline; output: Pipeline }) {
		this.params = device.createBuffer({ label: 'fsr3.veachParams', size: 32, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
		device.queue.writeBuffer(this.params, 0, new Float32Array([FSR3_NEAR_PLANE, 0, 0, 0]));
	}

	static unsupportedReason(device: GPUDevice): string | null { return Fsr3Upscaler.unsupportedReason(device); }

	static async create(device: GPUDevice): Promise<Fsr3Pass> {
		const reason = Fsr3Pass.unsupportedReason(device);
		if (reason) throw new Error(`FSR3 is unsupported on this device: ${reason}`);
		const [ffx, inputs, output] = await Promise.all([Fsr3Upscaler.compile(device), createPipeline(device, 'fsr3.VeachInputs', fsr3Shaders.VeachInputs),
			createPipeline(device, 'fsr3.VeachOutput', fsr3Shaders.VeachOutput)]);
		return new Fsr3Pass(device, ffx, { inputs, output });
	}

	/** Returns the presentation buffer (three float4 per pixel at the upscaled size, radiance first). */
	encode(encoder: GPUCommandEncoder, f: Fsr3Frame): GPUBuffer {
		const [rw, rh] = f.renderSize, [uw, uh] = f.upscaleSize;
		let reset = f.reset;
		if (!this.upscaler || this.upscaler.maxRenderSize[0] !== rw || this.upscaler.maxRenderSize[1] !== rh || this.upscaler.maxUpscaleSize[0] !== uw || this.upscaler.maxUpscaleSize[1] !== uh) {
			this.release();
			const T = GPUTextureUsage, usage = T.TEXTURE_BINDING | T.STORAGE_BINDING | T.COPY_SRC;
			const texture = (label: string, format: GPUTextureFormat, w: number, h: number) => this.device.createTexture({ label: `fsr3.${label}`, size: [w, h], format, usage });
			this.inputs = { color: texture('inputColor', 'rgba16float', rw, rh), depth: texture('inputDepth', 'r32float', rw, rh), motion: texture('inputMotion', 'rg32float', rw, rh) };
			this.output = { texture: texture('output', 'rgba16float', uw, uh),
				buffer: this.device.createBuffer({ label: 'fsr3.presentation', size: uw * uh * 48, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC }) };
			this.upscaler = Fsr3Upscaler.withPipelines(this.device, this.ffx, [rw, rh], [uw, uh]);
			reset = true;
		}
		const run = (label: string, p: Pipeline, entries: Record<number, GPUBindingResource>, size: [number, number]) => {
			const pass = encoder.beginComputePass({ label });
			pass.setPipeline(p.pipeline);
			pass.setBindGroup(0, this.device.createBindGroup({ label, layout: p.layout, entries: p.declarations.map(d => ({ binding: d.binding, resource: entries[d.binding] })) }));
			pass.dispatchWorkgroups(Math.ceil(size[0] / 8), Math.ceil(size[1] / 8));
			pass.end();
		};
		const inputs = this.inputs!, output = this.output!;
		run('fsr3.veachInputs', this.veach.inputs, { 0: { buffer: f.frame }, 1: { buffer: this.params }, 2: { buffer: f.color }, 3: { buffer: f.motion },
			4: inputs.color.createView(), 5: inputs.depth.createView(), 6: inputs.motion.createView() }, f.renderSize);
		// The path tracer's camera: a pixel ray is forward + ndc.x * right + ndc.y * up.
		const forward = vec3.length(f.camera.forward);
		const dispatch: Fsr3Dispatch = {
			renderSize: f.renderSize, upscaleSize: f.upscaleSize, jitter: f.jitter, motionVectorScale: [1, 1], reset,
			frameTimeDelta: f.frameTimeDelta, preExposure: f.preExposure, cameraNear: FSR3_NEAR_PLANE, cameraFar: 1e6,
			cameraFovAngleVertical: 2 * Math.atan(vec3.length(f.camera.up) / forward), viewSpaceToMetersFactor: 1, sharpness: f.sharpness,
		};
		this.upscaler!.dispatch(encoder, { ...inputs, output: output.texture }, dispatch);
		this.capture?.(encoder, { ...inputs, output: output.texture }, dispatch);
		run('fsr3.veachOutput', this.veach.output, { 2: output.texture.createView(), 3: { buffer: output.buffer } }, f.upscaleSize);
		this.stats = { active: true, reason: null, frames: reset ? 1 : this.stats.frames + 1, renderSize: [rw, rh], upscaleSize: [uw, uh],
			bytes: this.upscaler!.bytes + output.buffer.size + (rw * rh * (8 + 4 + 8)) + uw * uh * 8 };
		return output.buffer;
	}

	/** Discards the FidelityFX context: the next frame starts a fresh one (first execution), as a new FfxContext. */
	restart(): void { this.release(); }

	suspend(reason: string): void {
		if (this.stats.active || this.stats.reason !== reason) this.stats = { ...this.stats, active: false, reason, frames: 0 };
	}

	private release(): void {
		this.upscaler?.destroy();
		for (const t of [this.inputs?.color, this.inputs?.depth, this.inputs?.motion, this.output?.texture]) t?.destroy();
		this.output?.buffer.destroy();
		this.upscaler = null; this.inputs = null; this.output = null;
	}

	destroy(): void { this.release(); this.params.destroy(); }
}
