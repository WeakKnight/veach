// Minimal viewer: drag & drop glTF / HDR, orbit camera, debug views. No editor UI yet.
import { loadBlend } from '../loaders/blend/BlendLoader';
import { applyBlendSettings } from './BlendSettings';
import { loadGLTF, loadGLTFFromFiles } from '../loaders/GLTFLoader';
import { loadHDR, parseHDR } from '../loaders/HDRLoader';
import { OrbitController } from '../render/Camera';
import { DebugMode, Tonemapper } from '../render/GpuLayout';
import { AutoExposureMethod } from '../render/AutoExposure';
import { LocalExposureMethod, Renderer, type InitProgress } from '../render/Renderer';
import type { BlendScene } from '../loaders/blend/BlendLoader';
import type { SceneDesc } from '../scene/Scene';
import { createRendererConsole } from '../debug/RendererConsole';
import { DebugConsole } from '../view/DebugConsole';

const canvas = document.getElementById('viewport') as HTMLCanvasElement;
const overlay = document.getElementById('overlay')!;
const help = document.getElementById('help')!;
const errorBox = document.getElementById('error')!;
const loading = document.getElementById('loading')!;

// Until the renderer and the URL's model are ready; the shaders compile on a first visit.
const loadingStart = performance.now();
function showProgress(message: string, progress: number | null, shaders = false): void {
	const elapsed = Math.floor((performance.now() - loadingStart) / 1000);
	loading.querySelector<HTMLElement>('.message')!.textContent = elapsed >= 2 ? `${message}  ${elapsed} s` : message;
	loading.querySelector<HTMLElement>('.fill')!.style.width = progress === null ? '100%' : `${Math.max(2, progress * 100)}%`;
	loading.querySelector<HTMLElement>('.hint')!.textContent = shaders && elapsed >= 3 ? 'First load compiles the shaders; later loads use the browser cache.' : '';
}

let sceneName = '(empty)';
let status = '';

function showError(e: unknown): void {
	console.error(e);
	errorBox.textContent = e instanceof Error ? e.message : String(e);
	errorBox.style.display = 'block';
	loading.style.display = 'none';
}

help.textContent = [
	'drag: orbit   shift/right drag: pan   wheel: zoom   F: frame scene',
	'~: rendering console   Tab: complete   name ?: help',
	'0-9: debug view (0 beauty, 1 albedo, 2 shading N, 3 geometry N, 4 uv, 5 instance, 6 material, 7 traversal, 8 emission, 9 virtual texture mip)',
	'[ / ]: exposure (compensation)   A: auto exposure   L: local exposure   V: local exposure EV view   B / N: max bounces   T: tonemap   E: env visible   S: sun   arrows: sun elevation / azimuth   H: hide help',
	'drop .glb/.gltf (with its files) or .hdr; URL: ?model=<url>&env=<url>&sunElevation=<deg>&sunAzimuth=<deg>&exposure=<EV>&autoExposure=0&localExposure=0&highlightContrast=<0..1>&shadowContrast=<0..1>',
].join('\n');

type ParsedModel = { blend: BlendScene } | { gltf: SceneDesc };

async function fetchModel(url: string): Promise<ParsedModel> {
	if (/\.blend$/i.test(url)) {
		const response = await fetch(url);
		if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
		return { blend: loadBlend(new Uint8Array(await response.arrayBuffer())) };
	}
	return { gltf: await loadGLTF(url) };
}

async function main(): Promise<void> {
	const params = new URLSearchParams(location.search);
	const model = params.get('model');
	const env = params.get('env');
	// fetched and parsed while the shaders compile; errors surface when awaited below
	const pendingModel = model ? fetchModel(model) : null;
	const pendingEnv = env ? loadHDR(env) : null;
	pendingModel?.catch(() => {});
	pendingEnv?.catch(() => {});
	let latestProgress: InitProgress = { stage: 'device', progress: 0, message: 'Starting' };
	const ticker = setInterval(() => showProgress(latestProgress.message, latestProgress.progress, latestProgress.stage === 'shaders'), 500);
	const renderer = await Renderer.create(canvas, {
		onProgress: (p) => {
			latestProgress = p;
			showProgress(p.message, p.progress, p.stage === 'shaders');
		},
	}).finally(() => clearInterval(ticker));
	(globalThis as unknown as { veach: Renderer }).veach = renderer;
	// Empty-scene selection is cheap; scene loading prepares the required pipelines together.
	const integrator = params.get('integrator');
	if (integrator === 'wavefront' || integrator === 'megakernel') await renderer.setIntegrator(integrator);
	const primaryVisibility = params.get('primaryVisibility');
	if (primaryVisibility === 'auto' || primaryVisibility === 'ray-traced' || primaryVisibility === 'rasterized') await renderer.setPrimaryVisibility(primaryVisibility);
	if (params.get('sharc') === '0') await renderer.setSharc(false);
	new OrbitController(renderer.camera, canvas, () => renderer.resetAccumulation());

	const reset = () => renderer.resetAccumulation();

	renderer.onStats = (s) => {
		const sc = s.scene;
		const vt = s.virtualTexture;
		const mode = DebugMode[renderer.settings.debugMode];
		const exposure =
			renderer.settings.autoExposureMethod === AutoExposureMethod.Histogram
				? `auto ${Math.log2(renderer.exposureStats.exposure).toFixed(1)} EV (comp ${renderer.exposureCompensation().toFixed(1)})`
				: `manual ${renderer.exposureCompensation().toFixed(1)} EV`;
		const localExposure =
			renderer.settings.localExposureMethod === LocalExposureMethod.Fusion
				? (({ highlightEV, shadowEV }) => `local -${highlightEV.toFixed(1)}/+${shadowEV.toFixed(1)} EV`)(renderer.localExposureBrackets())
				: 'local off';
		overlay.textContent = [
			`Veach WebGPU path tracer  (tinybvh ${renderer.tinybvhVersion})`,
			`${sceneName}${status ? '  ' + status : ''}`,
			sc ? `${sc.triangles.toLocaleString()} tris  ${sc.instances} instances  ${sc.emissiveTriangles} emissive  BVH ${sc.bvhNodes.toLocaleString()} nodes (${sc.buildMs.toFixed(0)} ms)` : '',
			`${s.width}x${s.height}  spp ${s.frameIndex}  ${s.frameMs.toFixed(1)} ms  view ${mode}  ${Tonemapper[renderer.settings.tonemapper]}  ${exposure}  ${localExposure}  bounces ${renderer.settings.maxBounces}  sun ${renderer.sun.enabled ? `${renderer.sun.elevation}° el ${renderer.sun.azimuth}° az` : 'off'}`,
			vt && vt.textures > 0 ? `VT ${vt.textures} textures  pages ${vt.residentPages}/${vt.physicalPages}  pending ${vt.pendingRequests}  uploads ${vt.totalUploads}  evictions ${vt.evictions}` : '',
		].join('\n');
	};

	async function withStatus<T>(label: string, fn: () => Promise<T>): Promise<T | undefined> {
		status = label;
		errorBox.style.display = 'none';
		try {
			return await fn();
		} catch (e) {
			showError(e);
			return undefined;
		} finally {
			status = '';
		}
	}

	async function openBlend(bytes: ArrayBuffer | BlendScene): Promise<void> {
		const blend = bytes instanceof ArrayBuffer ? loadBlend(new Uint8Array(bytes)) : bytes;
		for (const w of [...blend.warnings, ...applyBlendSettings(renderer, blend)]) console.warn(`blend: ${w}`);
		await renderer.setScene(blend.scene);
	}

	async function openModelUrl(url: string, parsed = fetchModel(url)): Promise<void> {
		await withStatus(`loading ${url}...`, async () => {
			const m = await parsed;
			if ('blend' in m) {
				await openBlend(m.blend);
			} else {
				await renderer.setScene(m.gltf);
			}
			sceneName = url.split('/').pop() ?? url;
		});
	}

	async function openEnvUrl(url: string, image = loadHDR(url)): Promise<void> {
		await withStatus(`loading ${url}...`, async () => {
			renderer.setEnvironment(await image);
			renderer.sun.enabled = false;
		});
	}

	if (model || env) showProgress('Loading the scene', null);
	if (env && pendingEnv) await openEnvUrl(env, pendingEnv);
	if (model && pendingModel) await openModelUrl(model, pendingModel);
	loading.style.display = 'none';
	if (params.has('spp')) renderer.settings.maxSamples = Number(params.get('spp'));
	if (params.has('debug')) renderer.settings.debugMode = Number(params.get('debug')) as DebugMode;
	if (params.has('tonemap')) renderer.settings.tonemapper = Number(params.get('tonemap')) as Tonemapper;
	if (params.has('sunElevation')) renderer.sun.elevation = Number(params.get('sunElevation'));
	if (params.has('sunAzimuth')) renderer.sun.azimuth = Number(params.get('sunAzimuth'));
	if (params.has('exposure')) renderer.settings.autoExposureBias = Number(params.get('exposure'));
	if (params.has('autoExposure')) renderer.settings.autoExposureMethod = params.get('autoExposure') === '0' ? AutoExposureMethod.Manual : AutoExposureMethod.Histogram;
	if (params.has('localExposure')) renderer.settings.localExposureMethod = params.get('localExposure') === '0' ? LocalExposureMethod.None : LocalExposureMethod.Fusion;
	if (params.has('highlightContrast')) renderer.settings.localExposureHighlightContrastScale = Number(params.get('highlightContrast'));
	if (params.has('shadowContrast')) renderer.settings.localExposureShadowContrastScale = Number(params.get('shadowContrast'));
	if (params.has('visualizeLocalExposure')) renderer.settings.visualizeLocalExposure = params.get('visualizeLocalExposure') !== '0';

	window.addEventListener('dragover', (e) => {
		e.preventDefault();
		document.body.classList.add('dragging');
	});
	window.addEventListener('dragleave', () => document.body.classList.remove('dragging'));
	window.addEventListener('drop', async (e) => {
		e.preventDefault();
		document.body.classList.remove('dragging');
		const files = Array.from(e.dataTransfer?.files ?? []);
		const hdr = files.find((f) => /\.hdr$/i.test(f.name));
		const main = files.find((f) => /\.(glb|gltf)$/i.test(f.name));
		const blend = files.find((f) => /\.blend$/i.test(f.name));
		if (blend) {
			await withStatus(`loading ${blend.name}...`, async () => {
				await openBlend(await blend.arrayBuffer());
				sceneName = blend.name;
			});
			return;
		}
		if (hdr) {
			await withStatus(`loading ${hdr.name}...`, async () => {
				renderer.setEnvironment(parseHDR(await hdr.arrayBuffer()));
				renderer.sun.enabled = false;
			});
		}
		if (main) {
			await withStatus(`loading ${main.name}...`, async () => {
				await renderer.setScene(await loadGLTFFromFiles(main, files));
				sceneName = main.name;
			});
		}
	});

	window.addEventListener('keydown', (e) => {
		const s = renderer.settings;
		// exposure and tone mapping are applied at present time and keep the accumulation
		if (e.key === '[' || e.key === ']') {
			s.autoExposureBias += e.key === '[' ? -0.5 : 0.5;
			return;
		} else if (e.key === 'a' || e.key === 'A') {
			s.autoExposureMethod = s.autoExposureMethod === AutoExposureMethod.Histogram ? AutoExposureMethod.Manual : AutoExposureMethod.Histogram;
			return;
		} else if (e.key === 'l' || e.key === 'L') {
			s.localExposureMethod = s.localExposureMethod === LocalExposureMethod.Fusion ? LocalExposureMethod.None : LocalExposureMethod.Fusion;
			return;
		} else if (e.key === 'v' || e.key === 'V') {
			s.visualizeLocalExposure = !s.visualizeLocalExposure;
			return;
		} else if (e.key === 't' || e.key === 'T') {
			const order = [Tonemapper.ACES2, Tonemapper.ACESFilmic, Tonemapper.None];
			s.tonemapper = order[(order.indexOf(s.tonemapper) + 1) % order.length];
			return;
		}
		if (e.key >= '0' && e.key <= '9') {
			s.debugMode = Number(e.key) as DebugMode;
		} else if (e.key === 'b' || e.key === 'B') {
			s.maxBounces = Math.max(1, s.maxBounces - 1);
		} else if (e.key === 'n' || e.key === 'N') {
			s.maxBounces = Math.min(64, s.maxBounces + 1);
		} else if (e.key === 'e' || e.key === 'E') {
			s.environmentVisible = !s.environmentVisible;
		} else if (e.key === 's' || e.key === 'S') {
			renderer.sun.enabled = !renderer.sun.enabled;
		} else if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
			const sun = renderer.sun;
			sun.elevation = Math.min(90, Math.max(-10, sun.elevation + (e.key === 'ArrowUp' ? 2 : -2)));
		} else if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
			const sun = renderer.sun;
			sun.azimuth = (sun.azimuth + (e.key === 'ArrowRight' ? 10 : 350)) % 360;
		} else if (e.key === 'f' || e.key === 'F') {
			renderer.frameScene();
		} else if (e.key === 'h' || e.key === 'H') {
			help.style.display = help.style.display === 'none' ? '' : 'none';
			return;
		} else {
			return;
		}
		reset();
	});

	renderer.start();
	const debugConsole = new DebugConsole(createRendererConsole(renderer, { execute: async action => {
		renderer.stop();
		try { return await action(); } finally { renderer.start(); }
	} }));
	window.addEventListener('pagehide', () => debugConsole.dispose(), { once: true });
}

main().catch(showError);
