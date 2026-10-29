import { isPresentationSetting, type Renderer, type RenderSettings } from '../render/Renderer';
import { BUILTIN_LUTS, type BuiltinLUTId } from '../render/color/BuiltinLUTs';
import type { CurveKeys } from '../render/LocalExposureCurve';
import type { SharcSettings } from '../render/SharcCache';
import { ConsoleRegistry, consoleBoolean, consoleEnum, consoleNumber, consoleVector, type ConsoleValueType, type ConsoleExecutor } from './ConsoleRegistry';

const curve: ConsoleValueType<CurveKeys | null> = {
	usage: 'null or [[EV,value],[EV,value],...] with strictly increasing EV', parse(text) {
		const value: unknown = JSON.parse(text);
		if (value === null) return null;
		if (!Array.isArray(value) || value.length === 0 || value.length > 64 || !value.every((p, i) => Array.isArray(p) && p.length === 2 && p.every(v => typeof v === 'number' && Number.isFinite(v)) && (!i || p[0] > value[i - 1][0]))) throw new Error('Expected null or ordered finite [EV,value] pairs (maximum 64)');
		return value as CurveKeys;
	},
};
interface SettingDescriptor { name: string; help: string; type: ConsoleValueType<unknown> }
// Exhaustive: adding a RenderSettings field requires a console binding here.
export const renderConsoleSettings = {
	accumulation: { name: 'r.Accumulation.Enabled', help: 'Static viewer progressive accumulation. Host game frames always remain independent.', type: consoleBoolean },
	taaEnabled: { name: 'r.TAA.Enabled', help: 'TAA when progressive accumulation is off; enabled by default for host games.', type: consoleBoolean },
	taaNewFrameWeight: { name: 'r.TAA.NewFrameWeight', help: 'Current-frame weight (higher is more responsive).', type: consoleNumber(0.001, 1) },
	taaColorClampingFactor: { name: 'r.TAA.ColorClampingFactor', help: 'PQ neighborhood standard-deviation multiplier; lower rejects history more strongly.', type: consoleNumber(0.01, 10) },
	taaMaximumRadiance: { name: 'r.TAA.MaximumRadiance', help: 'Scene-linear PQ range, independent of presentation exposure.', type: consoleNumber(1, 1e8) },
	taaMotionVectorDebug: { name: 'r.TAA.MotionVectors', help: 'Visualize active TAA motion: gray=zero, R/G=signed X/Y (+/-32 pixels), magenta=unavailable. Keeps history.', type: consoleBoolean },
	maxBounces: { name: 'r.PathTracing.MaxBounces', help: 'Maximum continuation bounces. Resets accumulation.', type: consoleNumber(0, 128, true) },
	maxSamples: { name: 'r.PathTracing.MaxSamples', help: 'Progressive sample limit; 0 unlimited. Host games use samples per frame.', type: consoleNumber(0, 1000000, true) },
	samplesPerFrame: { name: 'r.PathTracing.SamplesPerFrame', help: 'Samples per rendered frame.', type: consoleNumber(1, 64, true) },
	resolutionScale: { name: 'r.Resolution.Scale', help: 'Internal resolution scale; 0.5 is half width and height.', type: consoleNumber(0.1, 2) },
	debugMode: { name: 'r.Debug.Mode', help: 'Render debug view; SHARC and raster primary fall back when needed.', type: consoleEnum({ None: 0, Albedo: 1, ShadingNormal: 2, GeometryNormal: 3, UV: 4, Instance: 5, Material: 6, Traversal: 7, Emission: 8, VirtualTexture: 9 }) },
	tonemapper: { name: 'r.Tonemapper.Mode', help: 'Tone mapping; overridden while a display LUT is active.', type: consoleEnum({ None: 0, ACESFilmic: 1, ACES2: 2 }) },
	autoExposureMethod: { name: 'r.Exposure.Method', help: 'Histogram metering or manual exposure.', type: consoleEnum({ Histogram: 0, Manual: 2 }) },
	autoExposureBias: { name: 'r.Exposure.Bias', help: 'Exposure compensation in EV; preserves accumulation.', type: consoleNumber(-32, 32) },
	autoExposureBiasCurve: { name: 'r.Exposure.BiasCurve', help: 'Compensation curve: [scene EV100, compensation EV].', type: curve },
	autoExposureLowPercent: { name: 'r.Exposure.LowPercent', help: 'Low histogram percentile; must be below HighPercent.', type: consoleNumber(1, 99) },
	autoExposureHighPercent: { name: 'r.Exposure.HighPercent', help: 'High histogram percentile; must be above LowPercent.', type: consoleNumber(1, 99) },
	autoExposureMinBrightness: { name: 'r.Exposure.MinBrightness', help: 'Minimum metering EV100; <= MaxBrightness.', type: consoleNumber(-32, 32) },
	autoExposureMaxBrightness: { name: 'r.Exposure.MaxBrightness', help: 'Maximum metering EV100; >= MinBrightness.', type: consoleNumber(-32, 32) },
	autoExposureSpeedUp: { name: 'r.Exposure.SpeedUp', help: 'Adaptation speed upward, stops/second.', type: consoleNumber(0, 100) },
	autoExposureSpeedDown: { name: 'r.Exposure.SpeedDown', help: 'Adaptation speed downward, stops/second.', type: consoleNumber(0, 100) },
	histogramLogMin: { name: 'r.Exposure.HistogramLogMin', help: 'Histogram lower EV100 bound; below HistogramLogMax.', type: consoleNumber(-32, 32) },
	histogramLogMax: { name: 'r.Exposure.HistogramLogMax', help: 'Histogram upper EV100 bound; above HistogramLogMin.', type: consoleNumber(-32, 32) },
	autoExposureLuminanceMethod: { name: 'r.Exposure.LuminanceMethod', help: 'Luminance weighting, shared with local exposure.', type: consoleEnum({ Uniform: 0, NTSC: 1, Rec709: 2 }) },
	localExposureMethod: { name: 'r.LocalExposure.Method', help: 'Local exposure method; LUTs can suppress it.', type: consoleEnum({ None: -1, Fusion: 1 }) },
	localExposureHighlightContrastScale: { name: 'r.LocalExposure.HighlightContrast', help: 'Highlight contrast scale; 1 disables its bracket.', type: consoleNumber(0, 1) },
	localExposureShadowContrastScale: { name: 'r.LocalExposure.ShadowContrast', help: 'Shadow contrast scale; 1 disables its bracket.', type: consoleNumber(0, 1) },
	localExposureHighlightContrastCurve: { name: 'r.LocalExposure.HighlightCurve', help: 'Highlight multiplier curve: [scene EV100, multiplier].', type: curve },
	localExposureShadowContrastCurve: { name: 'r.LocalExposure.ShadowCurve', help: 'Shadow multiplier curve: [scene EV100, multiplier].', type: curve },
	localExposureFusionTargetLuminance: { name: 'r.LocalExposure.TargetLuminance', help: 'Exposure fusion target luminance.', type: consoleNumber(0.001, 1) },
	visualizeLocalExposure: { name: 'r.LocalExposure.Visualize', help: 'Show local exposure EV instead of color.', type: consoleBoolean },
	fireflyClamp: { name: 'r.PathTracing.FireflyClamp', help: 'Pre-exposed indirect contribution limit; 0 off. Nonzero disables SHARC queries.', type: consoleNumber(0, 1e6) },
	environmentIntensity: { name: 'r.Environment.Intensity', help: 'Environment radiance multiplier.', type: consoleNumber(0, 1e6) },
	environmentRotation: { name: 'r.Environment.Rotation', help: 'Environment rotation in degrees.', type: consoleNumber(-36000, 36000) },
	environmentVisible: { name: 'r.Environment.Visible', help: 'Show the environment to the primary camera.', type: consoleBoolean },
	background: { name: 'r.Environment.Background', help: 'RGB background when the environment is hidden.', type: consoleVector },
	bvhQuality: { name: 'r.BVH.Quality', help: 'Applies on next static scene build; does not rebuild loaded scenes or override host scene options.', type: consoleEnum({ Fast: 0, High: 1 }) },
	textureMipBias: { name: 'r.Texture.MipBias', help: 'Ray-cone texture mip bias.', type: consoleNumber(-16, 16) },
	streamingResetCoverage: { name: 'r.Texture.StreamingResetCoverage', help: 'Coverage threshold for progressive accumulation resets on page uploads.', type: consoleNumber(0, 1) },
} satisfies Record<keyof RenderSettings, SettingDescriptor>;

export interface RendererConsoleOptions {
	/** Hosts can wait for an in-flight scene sync and suspend submissions around a command. */
	execute?: ConsoleExecutor;
	/** Host camera projection, when the renderer's own camera is not used. */
	cameraFov?: { get: () => number; set: (degrees: number) => void };
}
export function createRendererConsole(renderer: Renderer, options: RendererConsoleOptions = {}): ConsoleRegistry {
	const registry = new ConsoleRegistry(options.execute);
	function bind<T>(name: string, help: string, type: ConsoleValueType<T>, get: () => T, set: (v: T) => unknown | Promise<unknown>): void {
		registry.register({ name, help, usage: type.usage, choices: type.choices, get, set: async input => { await set(type.parse(input)); } });
	}
	for (const key of Object.keys(renderConsoleSettings) as (keyof RenderSettings)[]) {
		const d = renderConsoleSettings[key];
		bind(d.name, d.help, d.type, () => renderer.settings[key], value => {
			const s = { ...renderer.settings, [key]: value };
			if (s.autoExposureLowPercent >= s.autoExposureHighPercent) throw new Error('LowPercent must be below HighPercent');
			if (s.autoExposureMinBrightness > s.autoExposureMaxBrightness) throw new Error('MinBrightness must be <= MaxBrightness');
			if (s.histogramLogMin >= s.histogramLogMax) throw new Error('HistogramLogMin must be below HistogramLogMax');
			Object.assign(renderer.settings, { [key]: value });
			if (!isPresentationSetting(key) && !['maxSamples', 'samplesPerFrame', 'bvhQuality', 'streamingResetCoverage'].includes(key)) renderer.resetAccumulation();
		});
	}
	bind('r.Renderer.Integrator', 'Integrator selection; waits for pipeline preparation.', consoleEnum({ wavefront: 'wavefront', megakernel: 'megakernel' } as const), () => renderer.integrator, v => renderer.setIntegrator(v));
	bind('r.PrimaryVisibility.Mode', 'Primary visibility selection; necessary correctness fallbacks remain enabled.', consoleEnum({ auto: 'auto', 'ray-traced': 'ray-traced', rasterized: 'rasterized' } as const), () => renderer.primaryVisibility, v => renderer.setPrimaryVisibility(v));
	bind('r.SHARC.Enabled', 'Enable spatial radiance cache; query r.SHARC.Stats for actual execution and fallback reason.', consoleBoolean, () => renderer.sharcEnabled, v => renderer.setSharc(v));
	const sharcTypes: Record<keyof SharcSettings, ConsoleValueType<number>> = {
		voxelSize: consoleNumber(0, 1e6), capacity: consoleNumber(4096, 262144, true), roughnessThreshold: consoleNumber(0.3, 1),
		minSamples: consoleNumber(1, 512, true), historyFrames: consoleNumber(1, 64, true), maxAge: consoleNumber(1, 1024, true),
	};
	for (const key of Object.keys(sharcTypes) as (keyof SharcSettings)[]) bind(`r.SHARC.${key[0].toUpperCase()}${key.slice(1)}`, `SHARC ${key}; resets history. Capacity must be a power of two; voxel size 0 is automatic.`, sharcTypes[key], () => renderer.sharcSettings[key], v => renderer.setSharc(renderer.sharcEnabled, { [key]: v }));
	bind('r.Wavefront.SeparateLight', 'Separate NEE emitter material evaluation.', consoleBoolean, () => renderer.separateLight, v => renderer.setSeparateLight(v));
	bind('r.Wavefront.BatchedShadows', 'Opaque fast shadow classification with an alpha-only queue.', consoleBoolean, () => renderer.batchedShadows, v => renderer.setBatchedShadows(v));
	bind('r.Denoiser.Enabled', 'OIDN for converged static scenes; not used for host game frames.', consoleBoolean, () => renderer.denoising.status !== 'disabled', v => renderer.setDenoiser(v ? { type: 'oidn' } : null));
	const presets = Object.fromEntries(['default', ...BUILTIN_LUTS.map(p => p.id)].map(p => [p, p]));
	bind('r.Tonemapper.LUT', 'Built-in display LUT or default. Preserves accumulation.', consoleEnum(presets), () => renderer.displayTransform.preset ?? renderer.displayTransform.type,
		v => renderer.setDisplayTransform(v === 'default' ? null : { type: 'builtin', preset: v as BuiltinLUTId }));
	const sunTypes = { enabled: consoleBoolean, elevation: consoleNumber(-90, 90), azimuth: consoleNumber(-36000, 36000), irradiance: consoleNumber(0, 1e6), angularDiameter: consoleNumber(0.001, 180), color: consoleVector };
	for (const key of Object.keys(sunTypes) as (keyof typeof sunTypes)[]) bind(`r.Sun.${key[0].toUpperCase()}${key.slice(1)}`, `Sun ${key}${key === 'elevation' || key === 'azimuth' || key === 'angularDiameter' ? ' in degrees' : ''}.`, sunTypes[key] as ConsoleValueType<unknown>, () => renderer.sun[key], v => { Object.assign(renderer.sun, { [key]: v }); renderer.resetAccumulation(); });
	bind('r.Camera.FOV', 'Vertical field of view in degrees.', consoleNumber(1, 170), () => options.cameraFov?.get() ?? renderer.camera.fovY * 180 / Math.PI,
		v => { if (options.cameraFov) options.cameraFov.set(v); else renderer.camera.fovY = v * Math.PI / 180; renderer.resetAccumulation(); });
	if (!options.cameraFov) {
		bind('r.Camera.LensRadius', 'Depth-of-field lens radius; 0 pinhole.', consoleNumber(0, 100), () => renderer.camera.lensRadius, v => { renderer.camera.lensRadius = v; renderer.resetAccumulation(); });
		bind('r.Camera.FocusDistance', 'Focus distance; 0 uses camera-to-target distance.', consoleNumber(0, 1e6), () => renderer.camera.focusDistance, v => { renderer.camera.focusDistance = v; renderer.resetAccumulation(); });
	}
	const command = (name: string, help: string, run: () => unknown | Promise<unknown>) => registry.register({ name, help, run: input => { if (input) throw new Error(`${name} takes no arguments`); return run(); } });
	command('r.SHARC.Stats', 'Read GPU cache hit, segment and update counters; explicit readback.', () => renderer.readSharcStats());
	command('r.SHARC.Reset', 'Discard cache history and accumulated image.', () => { renderer.resetSharc(); return 'Cache reset'; });
	command('r.PrimaryVisibility.Stats', 'Read actual primary visibility and fallback counters.', () => renderer.readPrimaryVisibilityStats());
	command('r.Accumulation.Reset', 'Restart image sampling.', () => { renderer.resetAccumulation(); return 'Accumulation reset'; });
	command('r.TAA.Reset', 'Discard temporal history, for example after a camera cut.', () => { renderer.resetTaa(); return 'TAA history reset'; });
	command('r.TAA.Stats', 'Actual TAA mode, history frames, reset reason and memory.', () => renderer.taaStats);
	command('r.Renderer.Stats', 'Renderer, scene, streaming and denoising status.', () => ({ samples: renderer.samples, scene: renderer.sceneStats, textures: renderer.virtualTextureStats, exposure: renderer.exposureStats, denoising: renderer.denoising, sharc: renderer.sharcStats }));
	return registry;
}
