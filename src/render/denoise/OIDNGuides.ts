import wgsl from '../../generated/shaders/OIDNGuides.wgsl?raw';
import type { PipelineCompiler } from '../PipelineCompiler';

/** Caller-owned GPU snapshots, RGBA float32, top row first. Call destroy() after use. */
export interface DenoisingInputs {
	readonly width: number;
	readonly height: number;
	readonly samples: number;
	/** color = scene-linear Rec.709 * preExposure; albedo is linear [0,1]. */
	readonly preExposure: number;
	readonly color: GPUBuffer;
	readonly albedo: GPUBuffer;
	/** World-space averaged shading normal encoded as n * 0.5 + 0.5. */
	readonly normal: GPUBuffer;
	destroy(): void;
}

export class OIDNGuides {
	readonly compiled: Promise<void>;
	private prepare!: GPUComputePipeline;
	private compose!: GPUComputePipeline;
	constructor(private readonly device: GPUDevice, compiler: PipelineCompiler) {
		const module = device.createShaderModule({ label: 'OIDNGuides', code: wgsl });
		this.compiled = Promise.all(['Prepare', 'Compose'].map(entryPoint => compiler.compute({
			label: `oidn${entryPoint}`, layout: 'auto', compute: { module, entryPoint },
		}))).then(([prepare, compose]) => { this.prepare = prepare; this.compose = compose; });
	}

	private dispatch(encoder: GPUCommandEncoder, pipeline: GPUComputePipeline, buffers: Record<number, GPUBuffer>, width: number, height: number): void {
		const bindGroup = this.device.createBindGroup({ layout: pipeline.getBindGroupLayout(0),
			entries: Object.entries(buffers).map(([binding, buffer]) => ({ binding: Number(binding), resource: { buffer } })),
		});
		const pass = encoder.beginComputePass({ label: pipeline.label });
		pass.setPipeline(pipeline); pass.setBindGroup(0, bindGroup);
		pass.dispatchWorkgroups(Math.ceil(width / 8), Math.ceil(height / 8)); pass.end();
	}

	create(encoder: GPUCommandEncoder, uniform: GPUBuffer, accumulation: GPUBuffer, width: number, height: number, samples: number, preExposure: number): DenoisingInputs {
		const buffers: GPUBuffer[] = [];
		try {
			for (const name of ['color', 'albedo', 'normal']) buffers.push(this.device.createBuffer({
				label: `oidn-${name}`, size: width * height * 16, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC,
			}));
			const [color, albedo, normal] = buffers;
			this.dispatch(encoder, this.prepare, { 0: uniform, 1: accumulation, 2: color, 3: albedo, 4: normal }, width, height);
			return { width, height, samples, preExposure, color, albedo, normal, destroy: () => buffers.forEach(b => b.destroy()) };
		} catch (error) { buffers.forEach(b => b.destroy()); throw error; }
	}

	composeOutput(encoder: GPUCommandEncoder, uniform: GPUBuffer, accumulation: GPUBuffer, denoised: GPUBuffer, width: number, height: number): GPUBuffer {
		const output = this.device.createBuffer({ label: 'denoisedPresentation', size: width * height * 48,
			usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC });
		try { this.dispatch(encoder, this.compose, { 0: uniform, 1: accumulation, 5: denoised, 6: output }, width, height); }
		catch (error) { output.destroy(); throw error; }
		return output;
	}
}
