// NRD showcase: live real-time scenes with NRD / TAA-only / NRD debug views, links to the games,
// and the offline captures from scripts/nrd-check.mjs.
import { Renderer } from '../../src/render/Renderer';
import { OrbitController } from '../../src/render/Camera';
import { loadGLTF } from '../../src/loaders/GLTFLoader';
import { loadHDR } from '../../src/loaders/HDRLoader';
import type { HDRImage } from '../../src/loaders/HDRLoader';

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const params = new URLSearchParams(location.search);
const GAMES = params.get('games') ?? `${location.protocol}//${location.hostname}:5176/`;
const HDR = '/samples/studio_small_09_1k.hdr';

interface SceneEntry { name: string; model: string; hdr?: boolean; sun?: [number, number] }
const SCENES: SceneEntry[] = [
	{ name: '头盔 · 室内 HDR', model: '/samples/DamagedHelmet.glb', hdr: true },
	{ name: '头盔 · 低角度太阳', model: '/samples/DamagedHelmet.glb', sun: [8, 60] },
	{ name: '金属/粗糙度球阵', model: '/samples/MetalRoughSpheres.glb', hdr: true },
	{ name: '天鹅绒椅子 (Sheen)', model: '/samples/SheenChair.glb', hdr: true },
	{ name: '清漆 (Clearcoat)', model: '/samples/ClearCoatTest.glb', hdr: true },
	{ name: '透射 (Transmission)', model: '/samples/TransmissionTest.glb', hdr: true },
	{ name: '透明混合 (Alpha)', model: '/samples/AlphaBlendModeTest.glb', sun: [45, 30] },
	{ name: '薄膜干涉 (Iridescence)', model: '/samples/IridescentDishWithOlives.glb', hdr: true },
	{ name: '谷仓灯 (Anisotropy)', model: '/samples/AnisotropyBarnLamp.glb', hdr: true },
];
// enabled = NRD on, nrd = denoiser mode, reJitter (SH only), debug = settings.nrdDebug.
const MODES = [
	{ id: 'nrd', label: 'NRD SH + ReJitter', enabled: true, nrd: 'sh', reJitter: true, debug: 0 },
	{ id: 'sh', label: 'NRD SH（无 ReJitter）', enabled: true, nrd: 'sh', reJitter: false, debug: 0 },
	{ id: 'radiance', label: 'NRD radiance', enabled: true, nrd: 'radiance', reJitter: false, debug: 0 },
	{ id: 'taa', label: '仅 TAA（无降噪）', enabled: false, nrd: 'sh', reJitter: true, debug: 0 },
	{ id: 'noisy', label: 'NRD 输入（噪声）', enabled: true, nrd: 'sh', reJitter: true, debug: 1 },
	{ id: 'diffuse', label: '漫反射通道', enabled: true, nrd: 'sh', reJitter: true, debug: 2 },
	{ id: 'specular', label: '高光通道', enabled: true, nrd: 'sh', reJitter: true, debug: 3 },
	{ id: 'rejitter', label: 'ReJitter 缩放（R 漫反射 / G 高光）', enabled: true, nrd: 'sh', reJitter: true, debug: 5 },
	{ id: 'guides', label: '引导数据', enabled: true, nrd: 'sh', reJitter: true, debug: 4 },
] as const;
type ModeId = typeof MODES[number]['id'];

// ---- tabs -------------------------------------------------------------------------------------
let renderer: Renderer | null = null;
function showTab(id: string) {
	document.querySelectorAll('.tab').forEach(t => t.classList.toggle('active', t.id === id));
	document.querySelectorAll<HTMLAnchorElement>('nav a').forEach(a => a.classList.toggle('active', a.dataset.tab === id));
	// Only the live tab renders; the games run their own devices in other tabs.
	if (renderer) { if (id === 'live') renderer.start(); else renderer.stop(); }
	if (id === 'captures') void loadCaptures();
}
document.querySelectorAll<HTMLAnchorElement>('nav a').forEach(a => a.addEventListener('click', e => { e.preventDefault(); history.replaceState(null, '', `#${a.dataset.tab}`); showTab(a.dataset.tab!); }));
$<HTMLAnchorElement>('game-aim').href = `${GAMES}?game=aim&nrd=1`;
$<HTMLAnchorElement>('game-race').href = `${GAMES}?game=race&nrd=1`;

// ---- live -------------------------------------------------------------------------------------
const canvas = $<HTMLCanvasElement>('viewport');
const badge = $('badge'), statsBox = $('stats'), errorBox = $('error'), loading = $('loading');
let mode: ModeId = (params.get('mode') as ModeId) ?? 'nrd';
let held = false;
let current = -1;
let hdr: Promise<HDRImage> | null = null;

function progress(message: string, fraction: number) {
	loading.style.display = 'grid';
	loading.querySelector('p')!.textContent = message;
	loading.querySelector<HTMLElement>('.bar span')!.style.width = `${Math.max(2, fraction * 100)}%`;
}
function fail(error: unknown) {
	console.error(error);
	errorBox.textContent = String(error instanceof Error ? error.message : error);
	errorBox.style.display = 'block';
	loading.style.display = 'none';
}

function applyMode() {
	if (!renderer) return;
	const m = MODES.find(x => x.id === (held ? 'taa' : mode))!;
	// Selecting a mode loads it once (its pipelines compile on first use; the noisy split shows meanwhile).
	if (m.enabled && renderer.settings.nrdMode !== m.nrd) void renderer.setNrd(true, m.nrd).catch(fail);
	renderer.settings.nrdEnabled = m.enabled;
	renderer.settings.nrdReJitter = m.reJitter;
	renderer.settings.nrdDebug = m.debug;
	document.querySelectorAll<HTMLButtonElement>('#modes button').forEach(b => b.classList.toggle('active', b.dataset.mode === mode));
	badge.textContent = held ? '仅 TAA（按住 C）' : m.label;
	badge.className = m.enabled ? 'nrd' : 'off';
}

for (const m of MODES) {
	const b = document.createElement('button');
	b.textContent = m.label; b.dataset.mode = m.id;
	b.onclick = () => { mode = m.id; applyMode(); };
	$('modes').append(b);
}
SCENES.forEach((s, i) => {
	const b = document.createElement('button');
	b.textContent = s.name; b.dataset.index = String(i);
	b.onclick = () => void openScene(i);
	$('scenes').append(b);
});
window.addEventListener('keydown', e => { if (e.code === 'KeyC' && !e.repeat && !held) { held = true; applyMode(); } });
window.addEventListener('keyup', e => { if (e.code === 'KeyC') { held = false; applyMode(); } });
window.addEventListener('blur', () => { if (held) { held = false; applyMode(); } });

const resolution = $<HTMLSelectElement>('resolution');
function applyResolution() { if (renderer) renderer.settings.resolutionScale = Number(resolution.value) / (devicePixelRatio || 1); }
resolution.onchange = applyResolution;

async function openScene(index: number) {
	if (!renderer || index === current) return;
	const entry = SCENES[index];
	const buttons = document.querySelectorAll<HTMLButtonElement>('#scenes button');
	buttons.forEach(b => { b.disabled = true; b.classList.toggle('active', Number(b.dataset.index) === index); });
	errorBox.style.display = 'none';
	try {
		progress(`加载 ${entry.name}…`, 0.3);
		const desc = await loadGLTF(entry.model);
		progress(`准备场景管线 ${entry.name}…`, 0.6);
		if (entry.hdr) { hdr ??= loadHDR(HDR); renderer.setEnvironment(await hdr); renderer.sun.enabled = false; }
		else { renderer.setEnvironment(null); renderer.sun.enabled = true; [renderer.sun.elevation, renderer.sun.azimuth] = entry.sun ?? [45, 30]; }
		await renderer.setScene(desc);
		renderer.resetTaa();
		current = index;
		history.replaceState(null, '', `?scene=${index}${location.hash}`);
		loading.style.display = 'none';
	} catch (error) { fail(error); }
	finally { buttons.forEach(b => { b.disabled = false; }); }
}

// Auto orbit around the target at a constant angular speed (degrees per second).
let lastTime = 0;
function orbitStep(time: number) {
	const dt = lastTime ? Math.min(0.1, (time - lastTime) / 1000) : 0;
	lastTime = time;
	if (renderer && $<HTMLInputElement>('orbit').checked) {
		const c = renderer.camera, a = Number($<HTMLInputElement>('orbit-speed').value) * 15 * dt * Math.PI / 180;
		const o = c.position.map((v, i) => v - c.target[i]);
		c.position = [c.target[0] + o[0] * Math.cos(a) + o[2] * Math.sin(a), c.position[1], c.target[2] - o[0] * Math.sin(a) + o[2] * Math.cos(a)];
	}
	requestAnimationFrame(orbitStep);
}

$('profile').onclick = async () => {
	if (!renderer) return;
	const p = renderer.gpuProfiler, out = $('profile-out');
	if (p.status === 'unsupported') { out.textContent = '设备不支持 timestamp-query'; return; }
	p.capture();
	for (let i = 0; i < 100 && p.status !== 'ready' && p.status !== 'error'; i++) await new Promise(r => setTimeout(r, 50));
	if (!p.report) { out.textContent = p.error ?? p.status; return; }
	type Node = { name: string; ms: number; children: Node[] };
	const lines = [`总计 ${p.report.totalMs.toFixed(2)} ms`];
	const walk = (nodes: Node[], depth: number) => nodes.forEach(n => {
		if (depth === 0 || n.name === 'NRD') lines.push(`${'  '.repeat(depth)}${n.name}  ${n.ms.toFixed(2)} ms`);
		if (depth < 1) walk(n.children, depth + 1);
	});
	walk(p.report.roots as Node[], 0);
	out.textContent = lines.join('\n');
};

async function initLive() {
	try {
		renderer = await Renderer.create(canvas, { denoiser: null, onProgress: p => progress(p.message, p.progress * 0.5) });
		Object.assign(globalThis, { veach: renderer });
		renderer.settings.accumulation = false; // real-time: 1 spp per frame, TAA history
		applyResolution();
		progress('加载 NRD（WASM + REBLUR 管线）…', 0.5);
		await renderer.setNrd(true, 'sh');
		new OrbitController(renderer.camera, canvas, () => {});
		applyMode();
		renderer.onStats = s => {
			const n = renderer!.nrdStats;
			statsBox.textContent = [
				`${s.width}×${s.height}  ${s.frameMs.toFixed(1)} ms/帧`,
				`NRD ${n.mode === 'sh' ? 'SH' : 'radiance'} ${n.active ? '运行中' : `未运行 (${n.reason})`}`,
				n.active ? `REBLUR ${n.dispatches} dispatch · 历史 ${n.frames} 帧` : '',
				`NRD 纹理 ${(n.bytes / 2 ** 20).toFixed(0)} MB`,
				`TAA 历史 ${renderer!.taaStats.historyFrames} 帧`,
			].filter(Boolean).join('\n');
		};
		renderer.start();
		requestAnimationFrame(orbitStep);
		await openScene(Math.min(SCENES.length - 1, Math.max(0, Number(params.get('scene') ?? 0))));
		if (location.hash.slice(1) !== 'live' && location.hash) showTab(location.hash.slice(1));
	} catch (error) { fail(error); }
}

// ---- captures ---------------------------------------------------------------------------------
let capturesLoaded = false;
const CAPTURE_PAIRS: [string, string, string, string, string][] = [
	['运动 · SH+ReJitter vs radiance', 'sh', 'SH + ReJitter', 'radiance', 'radiance'],
	['静止 · SH+ReJitter vs radiance', 'sh-static', 'SH + ReJitter', 'radiance-static', 'radiance'],
	['静止 · ReJitter 开 vs 关', 'sh-static', 'SH + ReJitter', 'sh-norejitter-static', 'SH 无 ReJitter'],
	['运动 · SH+ReJitter vs 仅 TAA', 'sh', 'SH + ReJitter', 'taa', '仅 TAA'],
	['拆分通道', 'diffuse', '漫反射', 'specular', '高光'],
	['ReJitter 缩放 / 引导数据', 'rejitter-scale', 'ReJitter 缩放', 'guides', '引导数据'],
];
const SCENE_NAMES: Record<string, string> = { helmet: '头盔 · HDR', spheres: '金属/粗糙度球阵', sunset: '头盔 · 低角度太阳', alpha: '透明混合', transmission: '透射' };
async function loadCaptures() {
	if (capturesLoaded) return;
	capturesLoaded = true;
	const list = $('capture-list');
	let report: Record<string, { ok: boolean; stats?: { dispatches: number; bytes: number }; radiance?: { dispatches: number }; identity?: { maxRelativeError: number } }> = {};
	try { report = await (await fetch('/captures/report.json')).json(); }
	catch { list.innerHTML = '<p class="hint">没有找到截图，请先运行 <code>npm run check:nrd</code>。</p>'; return; }
	const exists = async (file: string) => (await fetch(`/captures/${file}`, { method: 'HEAD' })).ok;
	const groups = [...Object.keys(report).filter(k => report[k].stats?.dispatches), 'games-aim'];
	for (const name of groups) {
		const section = document.createElement('div');
		section.className = 'scene';
		const r = report[name];
		section.innerHTML = `<h2>${name === 'games-aim' ? '小游戏 · AIM LAB（托管帧）' : SCENE_NAMES[name] ?? name}</h2>` +
			(r ? `<div class="meta">${r.ok ? '✓ 通过' : '✗ 失败'} · SH ${r.stats?.dispatches} / radiance ${r.radiance?.dispatches} dispatch/帧 · 拆分重组误差 ${r.identity?.maxRelativeError.toExponential(1)}</div>` : '');
		const pairs = document.createElement('div');
		pairs.className = 'pairs';
		const candidates = name === 'games-aim' ? [['运行中', 'nrd', 'NRD + TAA', 'taa', '仅 TAA'] as const] : CAPTURE_PAIRS;
		for (const [title, a, la, b, lb] of candidates) {
			const fa = `${name}-${a}.png`, fb = `${name}-${b}.png`;
			if (!(await exists(fa)) || !(await exists(fb))) continue;
			const pair = document.createElement('div');
			pair.className = 'pair';
			pair.innerHTML = `<h4>${title}</h4><div class="imgs"><figure><img loading="lazy" src="/captures/${fa}"><figcaption>${la}</figcaption></figure><figure><img loading="lazy" src="/captures/${fb}"><figcaption>${lb}</figcaption></figure></div>`;
			pair.querySelectorAll('figure').forEach(f => f.addEventListener('click', () => openWipe(`/captures/${fa}`, la, `/captures/${fb}`, lb)));
			pairs.append(pair);
		}
		if (pairs.children.length) { section.append(pairs); list.append(section); }
	}
}
const lightbox = $('lightbox'), wipe = $<HTMLInputElement>('wipe');
function openWipe(a: string, la: string, b: string, lb: string) {
	$<HTMLImageElement>('wipe-a').src = a; $<HTMLImageElement>('wipe-b').src = b;
	lightbox.querySelector('.l')!.textContent = `← ${la}`; lightbox.querySelector('.r')!.textContent = `${lb} →`;
	wipe.value = '50'; wipe.oninput!(new Event('input'));
	lightbox.classList.add('open');
}
wipe.oninput = () => { lightbox.querySelector<HTMLElement>('.clip')!.style.clipPath = `inset(0 0 0 ${wipe.value}%)`; };
lightbox.addEventListener('click', e => { if (e.target === lightbox) lightbox.classList.remove('open'); });
window.addEventListener('keydown', e => { if (e.key === 'Escape') lightbox.classList.remove('open'); });

if (location.hash && location.hash !== '#live') showTab(location.hash.slice(1));
void initLive();
