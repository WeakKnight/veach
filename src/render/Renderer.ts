// Public entry point: owns the WebGPU device, the scene and the progressive render loop.
import { BuildQuality, TinyBVH } from '../accel/TinyBVH';
import type { HDRImage } from '../loaders/HDRLoader';
import type { Vec3 } from '../math/Math';
import type { SceneDesc } from '../scene/Scene';
import { sunTransmittance } from './Atmosphere';
import { AtmosphereBaker } from './AtmosphereBaker';
import { loadBSDFTables } from './BSDFTables';
import { AutoExposureMethod, LuminanceMethod, histogramLogMin, luminanceWeights, type ExposureStats } from './AutoExposure';
import { Camera } from './Camera';
import { Environment, defaultSunSettings, sunDirection, sunUniforms, type SunSettings } from './Environment';
import {
	DebugMode,
	FRAME_FLAG_ENVIRONMENT,
	FRAME_FLAG_ENV_IMPORTANCE,
	FRAME_FLAG_ENV_VISIBLE,
	FRAME_FLAG_SUN,
	FRAME_UNIFORM_BYTES,
	Tonemapper,
	packFrameUniforms,
} from './GpuLayout';
import { GpuScene, type SceneStats } from './GpuScene';
import { bakeFusionTables, calibrateZCurve, contrastScaleToEV, evaluateCurve, neutralToneResponse, type CurveKeys, type ZCurve } from './LocalExposureCurve';
import { PathTracer } from './PathTracer';
import { PipelineCompiler } from './PipelineCompiler';
import { compileSceneMaterials, textureUsage } from './SceneMaterials';
import { VT_FEEDBACK_PERIOD, VT_FEEDBACK_SHIFT, VirtualTextureSystem, type VirtualTextureOptions, type VirtualTextureStats } from './vt/VirtualTextureSystem';

// Unreal's ELocalExposureMethod; Fusion runs the fused fine-residual exposure fusion. Bilateral is
// not implemented; None (a Veach addition) skips the pass.
export enum LocalExposureMethod {
	None = -1,
	Fusion = 1,
}

// Unreal's Exposure Weight sigma (hardcoded in PostProcessLocalExposure.usf).
const FUSION_SIGMA = 0.2;

export interface RenderSettings {
	maxBounces: number;
	maxSamples: number; // 0 = unlimited
	samplesPerFrame: number;
	resolutionScale: number;
	debugMode: DebugMode;
	tonemapper: Tonemapper;
	// Unreal's Lens|Exposure post process settings (same names and meaning; display names in
	// quotes). EV100 values assume the default r.EyeAdaptation.LensAttenuation (0.78), where
	// EV100 = log2(luminance). Exposure settings only affect presentation and keep the accumulation.
	autoExposureMethod: AutoExposureMethod; // "Metering Mode"
	autoExposureBias: number; // "Exposure Compensation" (EV): offset from middle grey; Manual exposes by 2^bias
	autoExposureBiasCurve: CurveKeys | null; // "Exposure Compensation Curve": EV added at the scene EV100
	autoExposureLowPercent: number; // "Low Percent": histogram percentile where the metered range starts (1..99)
	autoExposureHighPercent: number; // "High Percent": and ends; brighter outliers are ignored
	autoExposureMinBrightness: number; // "Min Brightness" (EV100 white point); Min = Max disables adaptation
	autoExposureMaxBrightness: number; // "Max Brightness"
	autoExposureSpeedUp: number; // "Speed Up" (f-stops per second)
	autoExposureSpeedDown: number; // "Speed Down"
	histogramLogMin: number; // "Histogram Log Min" (EV100); also the luminance floor of local exposure
	histogramLogMax: number; // "Histogram Log Max"
	autoExposureLuminanceMethod: LuminanceMethod; // r.AutoExposure.LuminanceMethod, shared with local exposure
	// Unreal's Lens|Local Exposure settings that apply to the Fusion method. Brackets are
	// lerp(6, 0, contrast) stops below / above the adapted exposure; the curves multiply the
	// contrast at the scene EV100. Bilateral-only settings (thresholds, detail strength, blurred
	// luminance, middle grey bias) have no Fusion counterpart and are omitted.
	localExposureMethod: LocalExposureMethod; // "Method"
	localExposureHighlightContrastScale: number; // "Highlight Contrast": < 1 enables the darker bracket
	localExposureShadowContrastScale: number; // "Shadow Contrast": < 1 enables the brighter bracket
	localExposureHighlightContrastCurve: CurveKeys | null; // "Highlight Contrast Curve": [scene EV100, multiplier]
	localExposureShadowContrastCurve: CurveKeys | null; // "Shadow Contrast Curve"
	localExposureFusionTargetLuminance: number; // r.LocalExposure.ExposureFusion.TargetLuminance (exposure weight center)
	visualizeLocalExposure: boolean; // Unreal's VisualizeLocalExposure show flag: local exposure EV instead of the image
	fireflyClamp: number; // max pre-exposed sample value after the first bounce, 0 = off
	environmentIntensity: number;
	environmentRotation: number; // degrees
	environmentVisible: boolean;
	background: Vec3;
	bvhQuality: BuildQuality;
	textureMipBias: number; // added to the ray-cone texture LOD
	// Streamed pages restart accumulation only if they cover at least this screen fraction, scaled
	// up by spp / 32 (more samples are worth keeping). Smaller updates blend into the running average.
	streamingResetCoverage: number;
}

export function defaultRenderSettings(): RenderSettings {
	return {
		maxBounces: 8,
		maxSamples: 0,
		samplesPerFrame: 1,
		resolutionScale: 1,
		debugMode: DebugMode.None,
		tonemapper: Tonemapper.ACES2,
		autoExposureMethod: AutoExposureMethod.Histogram,
		autoExposureBias: 0,
		autoExposureBiasCurve: null,
		autoExposureLowPercent: 10,
		autoExposureHighPercent: 90,
		autoExposureMinBrightness: -10,
		autoExposureMaxBrightness: 20,
		autoExposureSpeedUp: 3,
		autoExposureSpeedDown: 1,
		histogramLogMin: -10,
		histogramLogMax: 20,
		autoExposureLuminanceMethod: LuminanceMethod.Uniform,
		localExposureMethod: LocalExposureMethod.Fusion,
		localExposureHighlightContrastScale: 0.8,
		localExposureShadowContrastScale: 0.8,
		localExposureHighlightContrastCurve: null,
		localExposureShadowContrastCurve: null,
		localExposureFusionTargetLuminance: 0.5,
		visualizeLocalExposure: false,
		fireflyClamp: 0,
		environmentIntensity: 1,
		environmentRotation: 0,
		environmentVisible: true,
		background: [0.05, 0.05, 0.05],
		bvhQuality: BuildQuality.High,
		textureMipBias: 0,
		streamingResetCoverage: 0.02,
	};
}

// Applied when presenting (the accumulation is pre-exposed), so changing them keeps the samples.
export function isPresentationSetting(key: keyof RenderSettings): boolean {
	return key === 'tonemapper' || key.startsWith('autoExposure') || key.startsWith('histogramLog') || key.startsWith('localExposure') || key === 'visualizeLocalExposure';
}

// Renderer.create progress. Without a browser pipeline cache (first visit, new shaders) compiling
// the shaders takes most of the time.
export type InitStage = 'device' | 'resources' | 'shaders' | 'scene';

export interface InitProgress {
	stage: InitStage;
	progress: number; // 0..1 over the whole initialization
	message: string;
}

export interface RendererCreateOptions {
	onProgress?: (progress: InitProgress) => void;
}

// Readable names of the pipelines still compiling, for progress messages.
function pendingPipelines(labels: string[]): string {
	if (labels.includes('pathTracing')) return labels.length > 1 ? `path tracer and ${labels.length - 1} more` : 'path tracer';
	return `${labels.length} pipeline${labels.length === 1 ? '' : 's'}`;
}

export interface RendererStats {
	frameIndex: number;
	width: number;
	height: number;
	frameMs: number;
	exposure: ExposureStats; // read back from the GPU, a few frames old
	scene: SceneStats | null;
	virtualTexture: VirtualTextureStats | null;
}

export class Renderer {
	readonly camera = new Camera();
	readonly settings: RenderSettings = defaultRenderSettings();
	readonly sun: SunSettings = defaultSunSettings();
	onStats: ((stats: RendererStats) => void) | null = null;

	private scene: GpuScene | null = null;
	private vt: VirtualTextureSystem | null = null;
	virtualTextureOptions: VirtualTextureOptions = {};
	private readonly sky: AtmosphereBaker;
	private hdrEnvironment: Environment | null = null;
	private skyKey = ''; // sun and rotation the sky was last baked for
	private sunTransmittance: Vec3 = [1, 1, 1];
	private frameIndex = 0;
	// Scale applied to radiance before accumulation, fixed per accumulation (Unreal's path tracer
	// BaseExposure): the last exposure read back when the accumulation started.
	private preExposure = 1;
	private forceExposureTarget = true; // jump to the metered exposure (startup, new scene)
	private lastExposureTime = 0;
	private readonly zCurves = new Map<Tonemapper, ZCurve | null>(); // fitted per tone mapper
	private fusionTablesKey = '';
	private streamedCoverage = 0; // coverage of pages mapped since the last accumulation reset
	private quietFeedbackFrames = 0; // completed feedback frames since the last upload or pending request
	private running = false;
	private rafHandle = 0;
	private lastFrameTime = 0;
	private frameMs = 0;
	private readonly uniformData = new ArrayBuffer(FRAME_UNIFORM_BYTES);
	private readonly resizeObserver: ResizeObserver | null = null;

	private constructor(
		readonly device: GPUDevice,
		readonly canvas: HTMLCanvasElement,
		private readonly context: GPUCanvasContext,
		private readonly tracer: PathTracer,
		private readonly bvh: TinyBVH,
		compiler: PipelineCompiler,
	) {
		this.sky = new AtmosphereBaker(device, compiler);
		if (typeof ResizeObserver !== 'undefined') {
			this.resizeObserver = new ResizeObserver(() => this.resize());
			this.resizeObserver.observe(canvas);
		}
		this.resize();
	}

	// Resolves once every pipeline has compiled (asynchronously, in parallel) and an empty scene is
	// bound; options.onProgress follows the stages.
	static async create(canvas: HTMLCanvasElement, options: RendererCreateOptions = {}): Promise<Renderer> {
		const report = (stage: InitStage, progress: number, message: string) => options.onProgress?.({ stage, progress, message });
		report('device', 0, 'Requesting the WebGPU device');
		if (!navigator.gpu) {
			throw new Error('WebGPU is not available in this browser');
		}
		const adapter = await navigator.gpu.requestAdapter({ powerPreference: 'high-performance' });
		if (!adapter) {
			throw new Error('No WebGPU adapter found');
		}
		const device = await adapter.requestDevice({
			label: 'Veach',
			requiredLimits: {
				maxStorageBufferBindingSize: adapter.limits.maxStorageBufferBindingSize,
				maxBufferSize: adapter.limits.maxBufferSize,
				maxStorageBuffersPerShaderStage: Math.max(8, Math.min(adapter.limits.maxStorageBuffersPerShaderStage, 10)),
			},
		});
		device.lost.then((info) => {
			// 'destroyed' is Renderer.destroy (or a failed create), not an error
			if (info.reason !== 'destroyed') console.error(`WebGPU device lost: ${info.reason} ${info.message}`);
		});
		device.addEventListener('uncapturederror', (e) => console.error('WebGPU error:', (e as GPUUncapturedErrorEvent).error.message));

		const context = canvas.getContext('webgpu');
		if (!context) {
			throw new Error('Failed to create a WebGPU canvas context');
		}
		const format = navigator.gpu.getPreferredCanvasFormat();
		context.configure({ device, format, alphaMode: 'opaque' });
		try {
			report('resources', 0.05, 'Loading the BVH builder and BSDF tables');
			const [bvh, bsdfTables] = await Promise.all([TinyBVH.create(), loadBSDFTables()]);
			const compiler = new PipelineCompiler(device);
			const tracer = new PathTracer(device, format, bsdfTables, compiler);
			const renderer = new Renderer(device, canvas, context, tracer, bvh, compiler);
			const SHADERS_START = 0.1;
			const SHADERS_END = 0.95;
			await compiler.wait((fraction, pending) =>
				report('shaders', SHADERS_START + (SHADERS_END - SHADERS_START) * fraction, pending.length ? `Compiling shaders: ${pendingPipelines(pending)}` : 'Shaders compiled'),
			);
			await Promise.all([tracer.compiled, renderer.sky.compiled]);
			report('scene', SHADERS_END, 'Preparing the scene');
			await renderer.setScene({ meshes: [], materials: [], textures: [], instances: [], cameras: [] }, { frameCamera: false });
			report('scene', 1, 'Ready');
			return renderer;
		} catch (e) {
			device.destroy();
			throw e;
		}
	}

	get tinybvhVersion(): string {
		return this.bvh.version;
	}

	get sceneStats(): SceneStats | null {
		return this.scene?.stats ?? null;
	}

	get virtualTextureStats(): VirtualTextureStats | null {
		return this.vt?.stats ?? null;
	}

	// Last exposure read back from the GPU, a few frames behind the displayed one.
	get exposureStats(): ExposureStats {
		return this.tracer.autoExposure.stats;
	}

	get samples(): number {
		return this.frameIndex;
	}

	// Scene-linear radiance of the accumulation (before exposure and tone mapping), RGB rows from the
	// top, for comparisons against offline references.
	async readRadiance(): Promise<{ width: number; height: number; samples: number; data: Float32Array }> {
		const accum = this.tracer.accumulation;
		const { width, height } = this.tracer;
		const samples = this.frameIndex;
		const preExposure = this.preExposure;
		if (!accum) {
			return { width: 0, height: 0, samples: 0, data: new Float32Array(0) };
		}
		const staging = this.device.createBuffer({ label: 'radianceReadback', size: accum.size, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
		const encoder = this.device.createCommandEncoder({ label: 'radianceReadback' });
		encoder.copyBufferToBuffer(accum, 0, staging, 0, accum.size);
		this.device.queue.submit([encoder.finish()]);
		await staging.mapAsync(GPUMapMode.READ);
		const texels = new Float32Array(staging.getMappedRange());
		const data = new Float32Array(width * height * 3);
		// radiance is the first of three float4 per pixel
		for (let i = 0; i < width * height; i++) {
			for (let c = 0; c < 3; c++) {
				data[i * 3 + c] = texels[i * 12 + c] / preExposure;
			}
		}
		staging.unmap();
		staging.destroy();
		return { width, height, samples, data };
	}

	async setScene(desc: SceneDesc, options: { frameCamera?: boolean; useSceneCamera?: boolean } = {}): Promise<SceneStats> {
		const materials = compileSceneMaterials(desc);
		const vt = await VirtualTextureSystem.create(this.device, desc, textureUsage(materials), this.virtualTextureOptions);
		const scene = GpuScene.build(this.device, this.bvh, desc, vt, materials, { quality: this.settings.bvhQuality });
		this.scene?.destroy();
		this.vt?.destroy();
		this.scene = scene;
		this.vt = vt;
		this.forceExposureTarget = true;

		const aspect = this.tracer.width / Math.max(this.tracer.height, 1);
		const cam = desc.cameras[0];
		if (options.useSceneCamera !== false && cam) {
			const distance = Math.max(0.1, Math.hypot(...scene.boundsMax.map((v, i) => v - scene.boundsMin[i])) * 0.5);
			this.camera.setFromMatrix(cam.transform, distance);
			this.camera.fovY = cam.yfov;
		} else if (options.frameCamera !== false && scene.instanceCount > 0) {
			this.camera.frame(scene.boundsMin, scene.boundsMax, aspect);
		}
		this.bindScene();
		return scene.stats;
	}

	frameScene(): void {
		if (this.scene && this.scene.instanceCount > 0) {
			this.camera.frame(this.scene.boundsMin, this.scene.boundsMax, this.tracer.width / Math.max(this.tracer.height, 1));
			this.resetAccumulation();
		}
	}

	// null switches to the procedural atmosphere, which follows the sun settings.
	setEnvironment(image: HDRImage | null): void {
		this.hdrEnvironment?.destroy();
		this.hdrEnvironment = image ? Environment.create(this.device, image) : null;
		this.bindScene();
	}

	// The procedural sky pairs with the analytic sun; HDR maps usually contain their own sun.
	get usingProceduralSky(): boolean {
		return this.hdrEnvironment === null;
	}

	private get environment(): Environment {
		return this.hdrEnvironment ?? this.sky.environment;
	}

	private currentSkyKey(): string {
		const { elevation, azimuth, irradiance, color } = this.sun;
		return `${elevation},${azimuth},${irradiance},${color.join(',')},${this.settings.environmentRotation}`;
	}

	// Rebakes the sky on the GPU (in place, so bindings stay valid) when its inputs change. The sky
	// is lit by the sun even when the sun light itself is disabled.
	private updateSky(): void {
		if (!this.usingProceduralSky || this.skyKey === this.currentSkyKey()) return;
		this.skyKey = this.currentSkyKey();
		const sun = sunDirection(this.sun);
		this.sunTransmittance = sunTransmittance(sun);
		// the path tracer looks the map up at RotateY(dir, -rotation)
		const rotation = (this.settings.environmentRotation * Math.PI) / 180;
		const s = Math.sin(-rotation);
		const c = Math.cos(-rotation);
		const local: Vec3 = [c * sun[0] + s * sun[2], sun[1], -s * sun[0] + c * sun[2]];
		this.sky.bake(local, this.sun.color.map((v) => v * this.sun.irradiance) as Vec3);
		this.resetAccumulation();
	}

	private bindScene(): void {
		if (this.scene && this.vt) {
			this.tracer.setScene(this.scene, this.environment, this.vt);
		}
		this.resetAccumulation();
	}

	resetAccumulation(): void {
		this.frameIndex = 0;
		this.streamedCoverage = 0;
		this.quietFeedbackFrames = 0;
	}

	// Decides whether newly streamed texture pages are worth discarding the accumulation for.
	private updateStreaming(): void {
		if (!this.vt) return;
		const { mapped, coverage, feedbackFrames, pendingFeedback } = this.vt.update();
		if (mapped > 0) this.streamedCoverage += coverage;
		const quiet = this.vt.stats.uploadsLastFrame === 0 && this.vt.stats.pendingRequests === 0;
		this.quietFeedbackFrames = quiet ? this.quietFeedbackFrames + feedbackFrames : 0;
		if (this.streamedCoverage <= 0) return;
		// Pending=0 only describes the last batch. Wait for a quiet feedback cycle instead of
		// resetting every upload (or every 30 frames) when the working set exceeds the cache.
		// At maxSamples no new feedback is generated: drain the outstanding readbacks instead.
		const settled = quiet && (this.quietFeedbackFrames >= VT_FEEDBACK_PERIOD || (this.converged && !pendingFeedback));
		if (!settled) return;
		const threshold = this.settings.streamingResetCoverage * Math.max(1, this.frameIndex / 32);
		if (this.frameIndex <= 4 || this.streamedCoverage >= threshold) {
			this.resetAccumulation();
		} else {
			// below threshold: keep the samples, the sharper pages blend in
			this.streamedCoverage = 0;
			this.quietFeedbackFrames = 0;
		}
	}

	resize(): void {
		const dpr = globalThis.devicePixelRatio ?? 1;
		const scale = this.settings.resolutionScale;
		const width = Math.max(1, Math.round((this.canvas.clientWidth || this.canvas.width) * dpr * scale));
		const height = Math.max(1, Math.round((this.canvas.clientHeight || this.canvas.height) * dpr * scale));
		if (this.canvas.width !== width || this.canvas.height !== height || this.tracer.width !== width || this.tracer.height !== height) {
			this.canvas.width = width;
			this.canvas.height = height;
			this.tracer.resize(width, height);
			this.resetAccumulation();
		}
	}

	private writeUniforms(feedbackJitter = 0): void {
		const s = this.settings;
		const scene = this.scene;
		const aspect = this.tracer.width / this.tracer.height;
		const basis = this.camera.basis(aspect);
		const sun = sunUniforms(this.sun, this.usingProceduralSky ? this.sunTransmittance : undefined);
		let flags = FRAME_FLAG_ENVIRONMENT;
		if (this.environment.importance) flags |= FRAME_FLAG_ENV_IMPORTANCE;
		if (s.environmentVisible) flags |= FRAME_FLAG_ENV_VISIBLE;
		if (this.sun.enabled && Math.max(...sun.radiance) > 0) flags |= FRAME_FLAG_SUN;
		packFrameUniforms(this.uniformData, {
			cameraPosition: this.camera.position,
			lensRadius: this.camera.lensRadius,
			cameraRight: basis.right,
			focusDistance: this.camera.effectiveFocusDistance,
			cameraUp: basis.up,
			cameraForward: basis.forward,
			width: this.tracer.width,
			height: this.tracer.height,
			frameIndex: this.frameIndex,
			seed: Math.imul(this.frameIndex + 1, 0x9e3779b9),
			maxBounces: s.maxBounces,
			debugMode: s.debugMode,
			flags,
			tonemapper: s.tonemapper,
			instanceCount: scene?.instanceCount ?? 0,
			lightCount: scene?.lightCount ?? 0,
			tlasPrimOffset: scene?.tlasPrimOffset ?? 0,
			analyticLightCount: scene?.analyticLightCount ?? 0,
			envCdfWidth: this.environment.width,
			envCdfHeight: this.environment.height,
			sunDirection: sun.direction,
			sunCosAngle: sun.cosAngle,
			sunRadiance: sun.radiance,
			sunSolidAngle: sun.solidAngle,
			envIntensity: s.environmentIntensity,
			envRotation: (s.environmentRotation * Math.PI) / 180,
			preExposure: this.preExposure,
			fireflyClamp: s.fireflyClamp,
			background: s.background,
			vtTilesPerRow: this.vt?.tilesPerRow ?? 1,
			vtPageTableWidth: this.vt?.pageTableWidth ?? 1,
			vtFeedbackJitter: feedbackJitter,
			vtFeedbackShift: VT_FEEDBACK_SHIFT,
			vtInvPhysicalSize: this.vt?.invPhysicalSize ?? 1,
			pixelSpreadAngle: Math.atan((2 * Math.tan(this.camera.fovY / 2)) / this.tracer.height),
			vtMipBias: s.textureMipBias,
		});
		this.device.queue.writeBuffer(this.tracer.uniformBuffer, 0, this.uniformData);
	}

	get converged(): boolean {
		return this.settings.maxSamples > 0 && this.frameIndex >= this.settings.maxSamples;
	}

	// Traces samplesPerFrame samples (unless converged) and presents the accumulation.
	renderFrame(): void {
		this.resize();
		if (!this.tracer.ready) {
			return;
		}
		this.updateSky();
		this.updateStreaming();
		if (this.frameIndex === 0) {
			this.preExposure = this.nextPreExposure();
		}
		const samples = this.settings.debugMode !== DebugMode.None ? 1 : Math.max(1, this.settings.samplesPerFrame);
		for (let i = 0; i < samples && !this.converged; i++) {
			this.writeUniforms(this.vt?.nextFeedbackJitter() ?? 0);
			const encoder = this.device.createCommandEncoder({ label: 'trace' });
			this.tracer.encodeTrace(encoder);
			const feedback = this.tracer.feedback;
			if (this.vt && feedback && i === samples - 1) {
				this.vt.recordFeedbackReadback(encoder, feedback);
			}
			this.device.queue.submit([encoder.finish()]);
			this.frameIndex++;
		}
		this.vt?.afterSubmit();
		// present reads the tonemapping settings from the uniforms; frameIndex there is unused
		this.writeUniforms();
		const encoder = this.device.createCommandEncoder({ label: 'present' });
		const now = performance.now();
		const deltaTime = this.lastExposureTime ? Math.min((now - this.lastExposureTime) / 1000, 1) : 0;
		this.lastExposureTime = now;
		// debug views are not exposed; keep the adapted state for when they are left
		const exposed = this.settings.debugMode === DebugMode.None;
		if (exposed) {
			this.encodeEyeAdaptation(encoder, deltaTime);
		}
		// after eye adaptation, which provides its base exposure (Unreal's AddLocalExposureFusionPass)
		this.encodeLocalExposure(encoder, exposed);
		this.tracer.encodePresent(encoder, this.context.getCurrentTexture().createView());
		this.device.queue.submit([encoder.finish()]);
		if (exposed) {
			this.tracer.autoExposure.afterSubmit();
		}
	}

	private zCurve(tonemapper: Tonemapper): ZCurve | null {
		if (!this.zCurves.has(tonemapper)) {
			let curve: ZCurve | null = null;
			try {
				curve = calibrateZCurve(neutralToneResponse(tonemapper));
				if (curve.maxLightnessError > 0.2) throw new Error(`poor fit (max lightness error ${curve.maxLightnessError.toFixed(3)})`);
			} catch (e) {
				console.warn(`Local exposure disabled for ${Tonemapper[tonemapper]}: ${(e as Error).message}`);
				curve = null;
			}
			this.zCurves.set(tonemapper, curve);
		}
		return this.zCurves.get(tonemapper)!;
	}

	// Scene EV100 the Unreal curves key on: last average luminance / 0.18 (the saturation luminance).
	get sceneEV100(): number | null {
		const average = this.exposureStats.averageLuminance;
		return average > 0 ? Math.log2(average / 0.18) : null;
	}

	// Unreal's GetAutoExposureCompensationFromSettings / FromCurve, in EV.
	exposureCompensation(): number {
		const s = this.settings;
		const ev = this.sceneEV100;
		return s.autoExposureBias + (s.autoExposureBiasCurve?.length && ev !== null ? evaluateCurve(s.autoExposureBiasCurve, ev) : 0);
	}

	// Unreal's GetLocalExposureParameters: contrasts times their curves at the scene EV100, then
	// lerp(6, 0, contrast) stops.
	localExposureBrackets(): { highlightEV: number; shadowEV: number } {
		const s = this.settings;
		let highlight = s.localExposureHighlightContrastScale;
		let shadow = s.localExposureShadowContrastScale;
		const ev = this.sceneEV100;
		if (ev !== null) {
			if (s.localExposureHighlightContrastCurve?.length) highlight *= evaluateCurve(s.localExposureHighlightContrastCurve, ev);
			if (s.localExposureShadowContrastCurve?.length) shadow *= evaluateCurve(s.localExposureShadowContrastCurve, ev);
		}
		return { highlightEV: contrastScaleToEV(highlight), shadowEV: contrastScaleToEV(shadow) };
	}

	private encodeLocalExposure(encoder: GPUCommandEncoder, exposed: boolean): void {
		const s = this.settings;
		const localExposure = this.tracer.localExposure;
		// as in Unreal, the pass only runs when it can change the image (or is visualized)
		let enabled =
			exposed &&
			s.localExposureMethod === LocalExposureMethod.Fusion &&
			(s.visualizeLocalExposure || s.localExposureHighlightContrastScale !== 1 || s.localExposureShadowContrastScale !== 1 || !!s.localExposureHighlightContrastCurve?.length || !!s.localExposureShadowContrastCurve?.length);
		const curve = enabled ? this.zCurve(s.tonemapper) : null;
		enabled &&= curve !== null;
		if (enabled && curve) {
			const { highlightEV, shadowEV } = this.localExposureBrackets();
			const brackets = { highlightEV, shadowEV, sigma: FUSION_SIGMA, targetLightness: s.localExposureFusionTargetLuminance };
			const key = `${s.tonemapper},${highlightEV.toFixed(3)},${shadowEV.toFixed(3)},${brackets.targetLightness}`;
			if (key !== this.fusionTablesKey) {
				if (!this.fusionTablesKey.startsWith(`${s.tonemapper},`) || !localExposure.calibrated) localExposure.setCurve(curve);
				const { forward, reduced } = bakeFusionTables(curve, brackets);
				localExposure.setTables(forward, reduced);
				this.fusionTablesKey = key;
			}
		}
		localExposure.encode(encoder, {
			enabled,
			visualize: s.visualizeLocalExposure,
			luminanceWeights: luminanceWeights(s.autoExposureLuminanceMethod),
			// Unreal's EyeAdaptation_LuminanceMin: the bottom of the histogram
			luminanceMin: Math.pow(2, histogramLogMin(s)),
		});
	}

	// Unreal's UpdatePreExposure: global exposure times the average local exposure, which Unreal
	// only measures for the bilateral method and is 1 for Fusion.
	private nextPreExposure(): number {
		const s = this.settings;
		const exposure = s.autoExposureMethod === AutoExposureMethod.Histogram ? this.tracer.autoExposure.stats.exposure : Math.pow(2, this.exposureCompensation());
		return Number.isFinite(exposure) && exposure > 0 ? exposure : 1;
	}

	private encodeEyeAdaptation(encoder: GPUCommandEncoder, deltaTime: number): void {
		const s = this.settings;
		this.tracer.autoExposure.encode(
			encoder,
			{
				method: s.autoExposureMethod,
				exposureCompensation: this.exposureCompensation(),
				minBrightness: s.autoExposureMinBrightness,
				maxBrightness: s.autoExposureMaxBrightness,
				histogramLogMin: s.histogramLogMin,
				histogramLogMax: s.histogramLogMax,
				lowPercent: s.autoExposureLowPercent,
				highPercent: s.autoExposureHighPercent,
				speedUp: s.autoExposureSpeedUp,
				speedDown: s.autoExposureSpeedDown,
				deltaTime,
				forceTarget: this.forceExposureTarget,
				luminanceMethod: s.autoExposureLuminanceMethod,
			},
			this.tracer.width,
			this.tracer.height,
		);
		this.forceExposureTarget = false;
	}

	start(): void {
		if (this.running) return;
		this.running = true;
		const loop = (time: number) => {
			if (!this.running) return;
			this.frameMs = this.lastFrameTime ? time - this.lastFrameTime : 0;
			this.lastFrameTime = time;
			this.renderFrame();
			this.onStats?.({ frameIndex: this.frameIndex, width: this.tracer.width, height: this.tracer.height, frameMs: this.frameMs, exposure: this.exposureStats, scene: this.sceneStats, virtualTexture: this.virtualTextureStats });
			this.rafHandle = requestAnimationFrame(loop);
		};
		this.rafHandle = requestAnimationFrame(loop);
	}

	stop(): void {
		this.running = false;
		cancelAnimationFrame(this.rafHandle);
	}

	destroy(): void {
		this.stop();
		this.resizeObserver?.disconnect();
		this.scene?.destroy();
		this.vt?.destroy();
		this.hdrEnvironment?.destroy();
		this.sky.destroy();
		this.tracer.destroy();
		this.device.destroy();
	}
}
