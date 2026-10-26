// <veach-view> demo: presets, drag & drop and every render setting, in plain DOM.
import {
	AutoExposureMethod,
	DebugMode,
	LocalExposureMethod,
	LuminanceMethod,
	Tonemapper,
	contrastScaleToEV,
	defaultRenderSettings,
	evaluateCurve,
	type CurveKeys,
	type ExposureStats,
	type HDRImage,
	type RenderSettings,
	type SceneDesc,
	type SceneStats,
} from 'veach';
import { attachFileDrop } from 'veach/view';

const base = import.meta.env.BASE_URL;
const MODELS = [
	{ label: 'Damaged Helmet', url: `${base}samples/DamagedHelmet.glb` },
	{ label: 'Metal / Rough Spheres', url: `${base}samples/MetalRoughSpheres.glb` },
	{ label: 'Transmission', url: `${base}samples/TransmissionTest.glb` },
	{ label: 'Clearcoat', url: `${base}samples/ClearCoatTest.glb` },
	{ label: 'Emissive Strength', url: `${base}samples/EmissiveStrengthTest.glb` },
	{ label: 'Alpha Modes', url: `${base}samples/AlphaBlendModeTest.glb` },
];
const ENVIRONMENTS = [
	{ label: 'Atmosphere + sun', url: null },
	{ label: 'Studio (HDR)', url: `${base}samples/studio_small_09_1k.hdr` },
];
const TONEMAPPERS: [Tonemapper, string][] = [
	[Tonemapper.ACES2, 'ACES 2.0 (SDR sRGB)'],
	[Tonemapper.ACESFilmic, 'ACES filmic fit'],
	[Tonemapper.None, 'None'],
];
// Unreal's Lens|Exposure settings (histogram metering) and the console variable shared with local exposure.
const EXPOSURE_KEYS = [
	'autoExposureMethod',
	'autoExposureBias',
	'autoExposureBiasCurve',
	'autoExposureLowPercent',
	'autoExposureHighPercent',
	'autoExposureMinBrightness',
	'autoExposureMaxBrightness',
	'autoExposureSpeedUp',
	'autoExposureSpeedDown',
	'histogramLogMin',
	'histogramLogMax',
	'autoExposureLuminanceMethod',
] as const satisfies readonly (keyof RenderSettings)[];
// Unreal's Lens|Local Exposure settings used by the Fusion method.
const LOCAL_EXPOSURE_KEYS = [
	'localExposureMethod',
	'localExposureHighlightContrastScale',
	'localExposureShadowContrastScale',
	'localExposureHighlightContrastCurve',
	'localExposureShadowContrastCurve',
	'localExposureFusionTargetLuminance',
	'visualizeLocalExposure',
] as const satisfies readonly (keyof RenderSettings)[];
const defaults = (keys: readonly (keyof RenderSettings)[]): Partial<RenderSettings> => {
	const d = defaultRenderSettings();
	return Object.fromEntries(keys.map((k) => [k, d[k]]));
};
// keys a curve starts with when enabled: [scene EV100, value]
const CONTRAST_CURVE: CurveKeys = [
	[0, 1],
	[12, 0.6],
];
const COMPENSATION_CURVE: CurveKeys = [
	[0, 0],
	[12, 0],
];
const DEBUG_VIEWS = [
	DebugMode.None,
	DebugMode.Albedo,
	DebugMode.ShadingNormal,
	DebugMode.GeometryNormal,
	DebugMode.UV,
	DebugMode.Instance,
	DebugMode.Material,
	DebugMode.Traversal,
	DebugMode.Emission,
	DebugMode.VirtualTexture,
];
const ev = (v: number) => (v > 0 ? Math.log2(v).toFixed(2) : '-inf');

// ---- state ----

const view = document.querySelector('veach-view')!;
const main = document.getElementById('main')!;
const panel = document.getElementById('panel')!;
const loadingBadge = document.getElementById('loading')!;
const errorBadge = document.getElementById('error')!;
const dropzone = document.getElementById('dropzone')!;

const settings: Partial<RenderSettings> = {
	...defaults(EXPOSURE_KEYS),
	...defaults(LOCAL_EXPOSURE_KEYS),
	maxBounces: 8,
	resolutionScale: 1,
	maxSamples: 1024,
	tonemapper: Tonemapper.ACES2,
	debugMode: DebugMode.None,
	environmentVisible: true,
};
const sun = { elevation: 45, azimuth: 30 };
let modelUrl = MODELS[0].url;
let envUrl: string | null = ENVIRONMENTS[1].url;
let dropped: { model: { scene: SceneDesc; name: string } | null; env: { image: HDRImage; name: string } | null } = { model: null, env: null };
let useDropped = { model: false, env: false };
let meter: ExposureStats | null = null;
let scene: SceneStats | null = null;

const syncs: (() => void)[] = [];
const infoSyncs: (() => void)[] = []; // read-outs, refreshed with the renderer stats
// Pushes the settings to the view and refreshes every control.
function update(): void {
	view.settings = { ...settings };
	for (const sync of syncs) sync();
}
function setSun(key: 'elevation' | 'azimuth', value: number): void {
	sun[key] = value;
	view.sun = { ...sun };
	update();
}
function set<K extends keyof RenderSettings>(key: K, value: RenderSettings[K]): void {
	settings[key] = value;
	update();
}

// ---- controls ----

function el<K extends keyof HTMLElementTagNameMap>(tag: K, props: Partial<HTMLElementTagNameMap[K]> = {}, ...children: (Node | string)[]): HTMLElementTagNameMap[K] {
	const e = Object.assign(document.createElement(tag), props);
	e.append(...children);
	return e;
}

function section(title: string, ...children: Node[]): HTMLElement {
	return el('section', {}, el('h3', { textContent: title }), ...children);
}

function hint(text: string): HTMLElement {
	return el('p', { className: 'hint', textContent: text });
}

// Shown while visible() holds.
function when(visible: () => boolean, ...children: Node[]): HTMLElement {
	const box = el('div', {}, ...children);
	syncs.push(() => (box.hidden = !visible()));
	return box;
}

function slider(label: string, get: () => number, onChange: (v: number) => void, min: number, max: number, step: number, title = ''): HTMLElement {
	const value = el('span', { className: 'value' });
	const input = el('input', { type: 'range', min: String(min), max: String(max), step: String(step) });
	input.addEventListener('input', () => onChange(Number(input.value)));
	syncs.push(() => {
		input.value = String(get());
		value.textContent = String(get());
	});
	return el('label', { title }, el('span', { className: 'slider-label' }, label, value), input);
}

function settingSlider(label: string, key: keyof RenderSettings, min: number, max: number, step: number, title = ''): HTMLElement {
	return slider(label, () => settings[key] as number, (v) => set(key, v as never), min, max, step, title);
}

function settingSelect<K extends keyof RenderSettings>(label: string, key: K, options: [RenderSettings[K], string][], title = ''): HTMLElement {
	const select = el('select', {}, ...options.map(([v, text]) => el('option', { value: String(v), textContent: text })));
	select.addEventListener('change', () => set(key, Number(select.value) as RenderSettings[K]));
	syncs.push(() => (select.value = String(settings[key])));
	return el('label', { title }, label, select);
}

function settingCheck(label: string, key: keyof RenderSettings, title = ''): HTMLElement {
	const input = el('input', { type: 'checkbox' });
	input.addEventListener('change', () => set(key, input.checked as never));
	syncs.push(() => (input.checked = settings[key] as boolean));
	return el('label', { className: 'check', title }, input, label);
}

// Two-key UCurveFloat over the scene EV100 (linear between keys, clamped outside).
function curveEditor(label: string, key: 'autoExposureBiasCurve' | 'localExposureHighlightContrastCurve' | 'localExposureShadowContrastCurve', initial: CurveKeys, [min, max, step]: [number, number, number], title: string): HTMLElement {
	const keys = () => settings[key] ?? null;
	const setKey = (i: number, j: 0 | 1, v: number) => set(key, keys()!.map((k, n) => (n === i ? (j === 0 ? [v, k[1]] : [k[0], v]) : k)) as CurveKeys);
	const input = el('input', { type: 'checkbox' });
	input.addEventListener('change', () => set(key, input.checked ? initial : null));
	syncs.push(() => (input.checked = keys() !== null));
	const rows = [0, 1].map((i) =>
		el(
			'div',
			{ className: 'row' },
			slider(`Key ${i + 1} EV100`, () => keys()?.[i][0] ?? 0, (v) => setKey(i, 0, v), -4, 20, 0.5),
			slider('value', () => keys()?.[i][1] ?? 0, (v) => setKey(i, 1, v), min, max, step),
		),
	);
	return el('div', {}, el('label', { className: 'check', title }, input, label), when(() => keys() !== null, ...rows));
}

function button(text: string | (() => string), onClick: () => void): HTMLButtonElement {
	const b = el('button', { onclick: onClick });
	if (typeof text === 'string') b.textContent = text;
	else syncs.push(() => (b.textContent = text()));
	return b;
}

function info(lines: () => [string, string][]): HTMLElement {
	const dl = el('dl');
	const sync = () => dl.replaceChildren(...lines().flatMap(([t, d]) => [el('dt', { textContent: t }), el('dd', { textContent: d })]));
	syncs.push(sync);
	infoSyncs.push(sync);
	return dl;
}

// ---- panel ----

const DROPPED = '__dropped';
const modelSelect = el('select');
const envSelect = el('select');
modelSelect.addEventListener('change', () => {
	if (modelSelect.value === DROPPED) return;
	useDropped.model = false;
	modelUrl = modelSelect.value;
	view.model = modelUrl;
	update();
});
envSelect.addEventListener('change', () => {
	if (envSelect.value === DROPPED) return;
	useDropped.env = false;
	envUrl = envSelect.value || null;
	view.environment = envUrl;
	update();
});
let optionsKey = '';
syncs.push(() => {
	// options change only with a drop (rebuilding them would close an open select)
	const key = `${dropped.model?.name}|${dropped.env?.name}`;
	if (key !== optionsKey) {
		optionsKey = key;
		rebuildOptions();
	}
	modelSelect.value = useDropped.model ? DROPPED : modelUrl;
	envSelect.value = useDropped.env ? DROPPED : (envUrl ?? '');
});
function rebuildOptions(): void {
	modelSelect.replaceChildren(...MODELS.map((m) => el('option', { value: m.url, textContent: m.label })), ...(dropped.model ? [el('option', { value: DROPPED, textContent: `Dropped: ${dropped.model.name}` })] : []));
	envSelect.replaceChildren(...ENVIRONMENTS.map((e) => el('option', { value: e.url ?? '', textContent: e.label })), ...(dropped.env ? [el('option', { value: DROPPED, textContent: `Dropped: ${dropped.env.name}` })] : []));
}
const environmentIsSky = () => (useDropped.env ? null : envUrl) === null;
const sceneEV = () => (meter && meter.averageLuminance > 0 ? Math.log2(meter.averageLuminance / 0.18) : null);
const bracket = (scale: number, curve: CurveKeys | null | undefined) => {
	const e = sceneEV();
	return contrastScaleToEV(scale * (curve?.length && e !== null ? evaluateCurve(curve, e) : 1));
};
const histogram = () => settings.autoExposureMethod === AutoExposureMethod.Histogram;

panel.append(
	section('Scene', modelSelect, envSelect, hint('Or drop a .glb / .gltf (with its files) / .hdr onto the viewport.')),
	when(
		environmentIsSky,
		section(
			'Sun',
			hint('The atmosphere follows the sun.'),
			slider('Elevation (°)', () => sun.elevation, (v) => setSun('elevation', v), -10, 90, 1),
			slider('Azimuth (°)', () => sun.azimuth, (v) => setSun('azimuth', v), 0, 360, 5),
		),
	),
	section(
		'Camera',
		hint('Drag to orbit, right-drag / shift-drag to pan, wheel to zoom.'),
		el(
			'div',
			{ className: 'row' },
			button('Frame scene', () => view.frameScene()),
			button(
				() => (view.paused ? 'Resume' : 'Pause'),
				() => ((view.paused = !view.paused), update()),
			),
		),
	),
	section(
		'Exposure',
		hint("Unreal's Lens | Exposure (EV100, lens attenuation 0.78). Applied at present time; changes keep the accumulated samples."),
		settingSelect('Metering Mode', 'autoExposureMethod', [
			[AutoExposureMethod.Histogram, 'Auto Exposure Histogram'],
			[AutoExposureMethod.Manual, 'Manual'],
		], 'Luminance computation method'),
		settingSlider('Exposure Compensation', 'autoExposureBias', -15, 15, 0.25, 'Logarithmic adjustment for the exposure. 0: no adjustment, -1: 2x darker, 1: 2x brighter. Histogram: relative to middle grey; Manual: the exposure itself.'),
		curveEditor('Exposure Compensation Curve', 'autoExposureBiasCurve', COMPENSATION_CURVE, [-15, 15, 0.25], 'Exposure compensation (EV, added) based on the scene EV100, to calibrate the exposure by the average scene luminance.'),
		when(
			histogram,
			settingSlider('Min Brightness', 'autoExposureMinBrightness', -10, 20, 0.5, 'Auto exposure minimum adaptation (EV100). The exposure is chosen so the average luminance maps to middle grey; Min = Max disables eye adaptation.'),
			settingSlider('Max Brightness', 'autoExposureMaxBrightness', -10, 20, 0.5, 'Auto exposure maximum adaptation (EV100).'),
			settingSlider('Speed Up', 'autoExposureSpeedUp', 0.02, 20, 0.02, 'In f-stops per second, should be > 0.'),
			settingSlider('Speed Down', 'autoExposureSpeedDown', 0.02, 20, 0.02, 'In f-stops per second, should be > 0.'),
			el('h4', { textContent: 'Advanced' }),
			settingSlider('Low Percent', 'autoExposureLowPercent', 0, 100, 1, 'Eye adaptation adapts to the histogram average between Low and High Percent: x percent of the pixels are darker than where the range starts. Clamped to 1..99; good values 70..80.'),
			settingSlider('High Percent', 'autoExposureHighPercent', 0, 100, 1, 'Where the metered range ends; brighter pixels are ignored. Higher values give bright spots more priority but are less stable. Good values 80..95.'),
			settingSlider('Histogram Log Min', 'histogramLogMin', -16, 8, 1, 'Histogram min value (EV100), kept 1 below Log Max. Also the luminance floor of local exposure (EyeAdaptation_LuminanceMin).'),
			settingSlider('Histogram Log Max', 'histogramLogMax', -8, 24, 1, 'Histogram max value (EV100).'),
		),
		el('h4', { textContent: 'Console variables' }),
		settingSelect('r.AutoExposure.LuminanceMethod', 'autoExposureLuminanceMethod', [
			[LuminanceMethod.Uniform, '0: Uniform'],
			[LuminanceMethod.NTSC, '1: NTSC'],
			[LuminanceMethod.Rec709, '2: Working color space'],
		], 'Luminance weights of the histogram, also used by local exposure (CalculateEyeAdaptationLuminance).'),
		info(() =>
			meter
				? [
						['Scene EV100', sceneEV()?.toFixed(2) ?? '-'],
						['Exposure', `${ev(meter.exposure)} EV`],
						['Target', `${ev(meter.targetExposure)} EV`],
					]
				: [],
		),
		button('Reset exposure', () => (Object.assign(settings, defaults(EXPOSURE_KEYS)), update())),
	),
	section(
		'Local Exposure',
		hint("Unreal's Lens | Local Exposure, Fusion method. Bilateral-only settings (thresholds, detail strength, blurred luminance, middle grey bias) do not apply to Fusion."),
		settingSelect('Method', 'localExposureMethod', [
			[LocalExposureMethod.Fusion, 'Fusion (Experimental)'],
			[LocalExposureMethod.None, 'None'],
		], 'Local exposure algorithm. Fusion: fuse multiple exposures according to quality measures.'),
		when(
			() => settings.localExposureMethod === LocalExposureMethod.Fusion,
			settingSlider('Highlight Contrast', 'localExposureHighlightContrastScale', 0, 1, 0.05, 'Values below 1 enable local exposure: fuses an exposure lerp(6, 0, contrast) stops darker. Good values 0.6..1.'),
			settingSlider('Shadow Contrast', 'localExposureShadowContrastScale', 0, 1, 0.05, 'Values below 1 enable local exposure: fuses an exposure lerp(6, 0, contrast) stops brighter. Good values 0.6..1.'),
			curveEditor('Highlight Contrast Curve', 'localExposureHighlightContrastCurve', CONTRAST_CURVE, [0, 2, 0.05], 'Highlight contrast multiplier based on the scene EV100, to calibrate local exposure by the average scene luminance.'),
			curveEditor('Shadow Contrast Curve', 'localExposureShadowContrastCurve', CONTRAST_CURVE, [0, 2, 0.05], 'Shadow contrast multiplier based on the scene EV100.'),
			el('h4', { textContent: 'Console variables' }),
			settingSlider('r.LocalExposure.ExposureFusion.TargetLuminance', 'localExposureFusionTargetLuminance', 0.1, 0.9, 0.01, 'Target luminance (lightness) used to determine the weight of each exposure. The weight sigma is fixed at 0.2 as in Unreal.'),
			settingCheck('Visualize Local Exposure', 'visualizeLocalExposure', 'Show flag: local exposure in EV, black -6, grey 0, white +6.'),
			info(() => [
				['Highlight bracket', `-${bracket(settings.localExposureHighlightContrastScale!, settings.localExposureHighlightContrastCurve).toFixed(2)} EV`],
				['Shadow bracket', `+${bracket(settings.localExposureShadowContrastScale!, settings.localExposureShadowContrastCurve).toFixed(2)} EV`],
			]),
		),
		button('Reset local exposure', () => (Object.assign(settings, defaults(LOCAL_EXPOSURE_KEYS)), update())),
	),
	section(
		'Rendering',
		settingSlider('Max bounces', 'maxBounces', 1, 16, 1),
		settingSlider('Resolution scale', 'resolutionScale', 0.25, 1, 0.25),
		settingSlider('Sample limit', 'maxSamples', 16, 4096, 16),
		settingSelect('Tonemapper', 'tonemapper', TONEMAPPERS),
		settingSelect('View', 'debugMode', DEBUG_VIEWS.map((d) => [d, d === DebugMode.None ? 'Beauty' : DebugMode[d]])),
		settingCheck('Show environment', 'environmentVisible'),
	),
	el(
		'section',
		{ className: 'info' },
		el('h3', { textContent: 'Scene info' }),
		info(() =>
			scene && scene.triangles > 0
				? [
						['Triangles', scene.triangles.toLocaleString()],
						['Instances', String(scene.instances)],
						['Emissive tris', scene.emissiveTriangles.toLocaleString()],
						['BVH nodes', `${scene.bvhNodes.toLocaleString()} (${scene.buildMs.toFixed(0)} ms)`],
					]
				: [['', 'No scene loaded.']],
		),
	),
);

// ---- view ----

const showError = (message: string | null) => {
	errorBadge.hidden = message === null;
	errorBadge.textContent = message ?? '';
};
view.fallback = (e) => el('div', { className: 'fallback' }, el('h2', { textContent: 'WebGPU unavailable' }), el('p', { textContent: e.message }), el('p', { textContent: 'Use a recent Chrome or Edge with hardware acceleration enabled.' }));
view.addEventListener('veach-load', (e) => {
	scene = e.detail;
	showError(null);
	update();
});
view.addEventListener('veach-loadingchange', (e) => (loadingBadge.hidden = !e.detail));
view.addEventListener('veach-error', (e) => {
	e.preventDefault(); // shown here instead of the console
	showError(e.detail.message);
});
let lastMeter = 0;
view.addEventListener('veach-stats', (e) => {
	const now = performance.now();
	if (now - lastMeter < 250) return;
	lastMeter = now;
	meter = e.detail.exposure;
	for (const sync of infoSyncs) sync();
});

// a drop switches the view to the dropped file until another preset is picked
attachFileDrop(main, {
	onDrop: (files) => {
		if (files.model) {
			dropped.model = files.model;
			useDropped.model = true;
			view.model = files.model.scene;
		}
		if (files.environment) {
			dropped.env = files.environment;
			useDropped.env = true;
			view.environment = files.environment.image;
		}
		update();
	},
	onDragChange: (dragging) => {
		main.classList.toggle('dragging', dragging);
		dropzone.hidden = !dragging;
	},
	onLoadingChange: (loading) => (loadingBadge.hidden = !loading),
	onError: (e) => showError(e.message),
});

view.model = modelUrl;
view.environment = envUrl;
view.sun = { ...sun };
update();
