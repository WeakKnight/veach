// GPU sky bake (shaders/Passes/Atmosphere.slang): the transmittance and multiple-scattering LUTs
// once, then per sun change the sky-view LUT, the equirect environment and its CDF, with no readback.
import atmosphereWgsl from '../generated/shaders/Atmosphere.wgsl?raw';
import type { Vec3 } from '../math/Math';
import { MULTI_SCATTERING_LUT_SIZE, SKY_VIEW_LUT_SIZE, TRANSMITTANCE_LUT_SIZE } from './Atmosphere';
import { Environment } from './Environment';
import type { PipelineCompiler } from './PipelineCompiler';

// ENVIRONMENT_SIZE in Atmosphere.slang
export const SKY_ENVIRONMENT_SIZE = [512, 256] as const;
const UNIFORM_BYTES = 32;

interface Pass {
	pipeline: GPUComputePipeline | null; // null until compiled
	bindGroup: GPUBindGroup;
	workgroups: [number, number];
}

export class AtmosphereBaker {
	readonly environment: Environment;
	private readonly uniformBuffer: GPUBuffer;
	private readonly scratch: GPUBuffer;
	private readonly luts: GPUTexture[];
	private readonly sunPasses: Pass[];
	readonly compiled: Promise<void>; // compiled, and the static LUTs submitted

	constructor(
		private readonly device: GPUDevice,
		compiler: PipelineCompiler,
		private readonly profiler?: import('./GpuProfiler').GpuProfiler,
	) {
		const [envW, envH] = SKY_ENVIRONMENT_SIZE;
		this.environment = Environment.createStorage(device, envW, envH);
		this.uniformBuffer = device.createBuffer({ label: 'atmosphereUniforms', size: UNIFORM_BYTES, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
		this.scratch = device.createBuffer({ label: 'atmosphereScratch', size: (4 + envH) * 4, usage: GPUBufferUsage.STORAGE });
		const lut = (label: string, [w, h]: readonly [number, number]) =>
			device.createTexture({ label, size: [w, h], format: 'rgba32float', usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.STORAGE_BINDING });
		const transmittance = lut('atmosphereTransmittance', TRANSMITTANCE_LUT_SIZE);
		const multiScattering = lut('atmosphereMultiScattering', MULTI_SCATTERING_LUT_SIZE);
		const skyView = lut('atmosphereSkyView', SKY_VIEW_LUT_SIZE);
		this.luts = [transmittance, multiScattering, skyView];

		const module = device.createShaderModule({ label: 'Atmosphere', code: atmosphereWgsl });
		void module.getCompilationInfo().then((info) => {
			for (const m of info.messages) {
				if (m.type === 'error') console.error(`Atmosphere.wgsl:${m.lineNum}:${m.linePos} ${m.message}`);
			}
		});

		// bindings as declared in Atmosphere.slang
		const C = GPUShaderStage.COMPUTE;
		const uniform = { binding: 0, visibility: C, buffer: { type: 'uniform' } } as const;
		const sampled = (binding: number) => ({ binding, visibility: C, texture: { sampleType: 'unfilterable-float' } }) as const;
		const scratch = { binding: 5, visibility: C, buffer: { type: 'storage' } } as const;
		const lutOut = { binding: 6, visibility: C, storageTexture: { access: 'write-only', format: 'rgba32float' } } as const;
		const envOut = { binding: 7, visibility: C, storageTexture: { access: 'write-only', format: 'rgba16float' } } as const;
		const cdfOut = { binding: 8, visibility: C, storageTexture: { access: 'write-only', format: 'r32float' } } as const;
		const resources: Record<number, GPUBindingResource> = {
			0: { buffer: this.uniformBuffer },
			1: transmittance.createView(),
			2: multiScattering.createView(),
			3: skyView.createView(),
			4: this.environment.view(),
			5: { buffer: this.scratch },
			8: this.environment.cdfView(),
		};
		const groups = (size: readonly [number, number], tile: number): [number, number] => [Math.ceil(size[0] / tile), Math.ceil(size[1] / tile)];
		const compiled: Promise<unknown>[] = [];
		const pass = (entryPoint: string, entries: GPUBindGroupLayoutEntry[], workgroups: [number, number], output?: GPUBindingResource): Pass => {
			const layout = device.createBindGroupLayout({ label: entryPoint, entries });
			const bindGroup = device.createBindGroup({
				label: entryPoint,
				layout,
				entries: entries.map((e) => ({ binding: e.binding, resource: e.binding === 6 || e.binding === 7 ? output! : resources[e.binding] })),
			});
			const result: Pass = { pipeline: null, bindGroup, workgroups };
			const pipeline = compiler.compute({ label: entryPoint, layout: device.createPipelineLayout({ bindGroupLayouts: [layout] }), compute: { module, entryPoint } });
			compiled.push(pipeline.then((p) => (result.pipeline = p)));
			return result;
		};

		const [skyW, skyH] = SKY_VIEW_LUT_SIZE;
		const staticPasses = [
			pass('TransmittanceLut', [lutOut], groups(TRANSMITTANCE_LUT_SIZE, 8), transmittance.createView()),
			pass('MultiScatteringLut', [sampled(1), lutOut], groups(MULTI_SCATTERING_LUT_SIZE, 8), multiScattering.createView()),
		];
		const skyViewEntries = [uniform, sampled(1), sampled(2), scratch, lutOut];
		this.sunPasses = [
			pass('SkyViewSkyRows', skyViewEntries, groups([skyW, skyH / 2], 8), skyView.createView()),
			pass('SkyIrradiance', [sampled(3), scratch], [1, 1]),
			pass('SkyViewGroundRows', skyViewEntries, groups([skyW, skyH / 2], 8), skyView.createView()),
			pass('BakeEnvironment', [uniform, sampled(3), envOut], groups(SKY_ENVIRONMENT_SIZE, 8), this.environment.view()),
			pass('CdfRows', [sampled(4), scratch, cdfOut], [Math.ceil(envH / 64), 1]),
			pass('CdfMarginal', [scratch, cdfOut], [1, 1]),
		];
		this.compiled = Promise.all(compiled).then(() => this.submit(staticPasses, 'atmosphereStatic'));
	}

	// sunDir: unit vector toward the sun in the environment map's frame; illuminance: outer-space rgb.
	bake(sunDir: Vec3, illuminance: Vec3): void {
		this.device.queue.writeBuffer(this.uniformBuffer, 0, new Float32Array([...sunDir, 0, ...illuminance, 0]));
		this.submit(this.sunPasses, 'atmosphereSky');
	}

	private submit(passes: Pass[], label: string): void {
		const encoder = this.profiler ? this.profiler.createCommandEncoder({ label }) : this.device.createCommandEncoder({ label });
		const pass = encoder.beginComputePass({ label });
		for (const p of passes) {
			pass.setPipeline(p.pipeline!);
			pass.setBindGroup(0, p.bindGroup);
			pass.dispatchWorkgroups(...p.workgroups);
		}
		pass.end();
		this.device.queue.submit([encoder.finish()]);
	}

	destroy(): void {
		this.environment.destroy();
		this.uniformBuffer.destroy();
		this.scratch.destroy();
		for (const t of this.luts) t.destroy();
	}
}
