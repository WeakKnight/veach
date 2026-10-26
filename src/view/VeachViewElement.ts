// <veach-view>: the Veach renderer as a custom element. One <canvas>, one WebGPU device, progressive
// path tracing, with a progress bar until the shaders have compiled and the first scene has loaded.
import { OrbitController } from '../render/Camera';
import { AutoExposureMethod } from '../render/AutoExposure';
import { DebugMode, Tonemapper } from '../render/GpuLayout';
import type { SunSettings } from '../render/Environment';
import type { SceneStats } from '../render/GpuScene';
import { Renderer, isPresentationSetting, type InitProgress, type InitStage, type RenderSettings, type RendererStats } from '../render/Renderer';
import { loadGLTF } from '../loaders/GLTFLoader';
import { loadHDR, type HDRImage } from '../loaders/HDRLoader';
import type { SceneDesc } from '../scene/Scene';
import { attachFileDrop, type DroppedFiles } from './fileDrop';

/** Progress until the view is ready: the renderer is created and the first scene has loaded. */
export interface VeachViewProgress {
	stage: InitStage | 'model';
	/** 0..1, or null while the first scene loads (its duration is unknown). */
	progress: number | null;
	message: string;
	/** Seconds since the view was connected. */
	elapsed: number;
}

export interface VeachViewEventMap extends HTMLElementEventMap {
	/** The renderer is created (the shaders have compiled). */
	'veach-ready': CustomEvent<Renderer>;
	/** A scene has loaded. */
	'veach-load': CustomEvent<SceneStats>;
	/** A scene load started (true) or ended (false). */
	'veach-loadingchange': CustomEvent<boolean>;
	/** Every rendered frame. */
	'veach-stats': CustomEvent<RendererStats>;
	/** Renderer creation progress. */
	'veach-progress': CustomEvent<InitProgress>;
	/** A failure: creation (the view then shows its fallback), a scene, an environment or a drop. */
	'veach-error': CustomEvent<Error>;
	/** Files dropped on a `droppable` view, after they were applied. */
	'veach-drop': CustomEvent<DroppedFiles>;
}

const toError = (e: unknown): Error => (e instanceof Error ? e : new Error(String(e)));
const EMPTY_SCENE: SceneDesc = { meshes: [], materials: [], textures: [], instances: [], cameras: [] };

const STYLE = `
:host { display: block; position: relative; overflow: hidden; height: 360px; background: #111; }
:host([hidden]) { display: none; }
canvas { position: absolute; inset: 0; display: block; width: 100%; height: 100%; touch-action: none; outline: none; }
[hidden] { display: none !important; }
.stats {
	position: absolute; top: 8px; left: 8px; padding: 4px 8px; border-radius: 4px; background: rgba(0,0,0,0.55); color: #ddd;
	font: 11px/1.5 ui-monospace, SFMono-Regular, Consolas, monospace; white-space: pre; pointer-events: none;
}
.progress {
	position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); width: min(320px, 80%); padding: 12px 16px;
	border-radius: 6px; background: rgba(0,0,0,0.6); color: #ddd; font: 12px/1.5 system-ui, sans-serif; pointer-events: none;
}
.progress .message { margin-bottom: 8px; white-space: pre; }
.progress .track { height: 4px; border-radius: 2px; background: rgba(255,255,255,0.15); overflow: hidden; }
.progress .fill { height: 100%; border-radius: 2px; background: #8bf; transition: width 0.3s ease-out; }
.progress .fill.indeterminate { width: 30%; animation: indeterminate 1.2s ease-in-out infinite; }
.progress .hint { margin-top: 8px; font-size: 11px; color: #999; }
@keyframes indeterminate { 0% { margin-left: -30%; } 100% { margin-left: 100%; } }
.dropzone {
	position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; background: rgba(40,90,160,0.35);
	border: 3px dashed #8bf; color: #ddd; font: 16px system-ui, sans-serif; pointer-events: none;
}
.fallback {
	position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; padding: 16px; color: #fcc;
	font: 13px system-ui, sans-serif; text-align: center;
}
`;

const BOOLEAN_ATTRIBUTES = ['paused', 'show-stats', 'controls', 'use-scene-camera', 'progress', 'droppable'] as const;

/**
 * `<veach-view model="scene.glb" environment="studio.hdr" show-stats>`. Register it with
 * `import 'veach/view'` (or `defineVeachView()`), size it with CSS (360px high by default).
 *
 * Attributes: `model` and `environment` (URLs), `paused`, `show-stats`, `droppable` (presence), and
 * `controls`, `use-scene-camera`, `progress` (on unless `="false"`). Objects go through properties:
 * `model` / `environment` also take a loaded `SceneDesc` / `HDRImage`, and `settings` / `sun` take
 * partial render and sun settings.
 */
export class VeachViewElement extends HTMLElement {
	static readonly observedAttributes = ['model', 'environment', ...BOOLEAN_ATTRIBUTES];

	/** Rendered instead of the canvas when WebGPU is unavailable or creation fails. */
	fallback: ((error: Error) => Node | string) | null = null;

	private _model: string | SceneDesc | null = null;
	private _environment: string | HDRImage | null = null;
	private _settings: Partial<RenderSettings> | null = null;
	private _sun: Partial<SunSettings> | null = null;
	private _progress: boolean | ((progress: VeachViewProgress) => Node | string) = true;

	private readonly canvas: HTMLCanvasElement;
	private readonly statsBox: HTMLElement;
	private readonly progressBox: HTMLElement;
	private readonly dropzone: HTMLElement;
	private readonly fallbackBox: HTMLElement;

	private _renderer: Renderer | null = null;
	private generation = 0; // bumped on dispose; late results of an older generation are dropped
	private creating = false;
	private fatal: Error | null = null;
	private init: InitProgress | null = null;
	private firstSceneLoaded = false;
	private loading = false;
	private connectedAt = 0;
	private progressTimer = 0;
	private lastStatsUpdate = 0;
	private orbit: OrbitController | null = null;
	private detachDrop: (() => void) | null = null;
	private prefetch: { url: string; scene: Promise<SceneDesc> } | null = null;
	private loadToken = 0;
	private loadChain: Promise<void> = Promise.resolve();
	private envToken = 0;

	constructor() {
		super();
		const root = this.attachShadow({ mode: 'open' });
		root.innerHTML = `<style>${STYLE}</style><canvas part="canvas"></canvas><div class="stats" part="stats" hidden></div><div class="progress" part="progress" role="progressbar" aria-valuemin="0" aria-valuemax="100" hidden></div><div class="dropzone" part="dropzone" hidden>Drop .glb / .gltf (+ files) or .hdr</div><slot></slot><div class="fallback" part="fallback" hidden></div>`;
		this.canvas = root.querySelector('canvas')!;
		this.statsBox = root.querySelector('.stats')!;
		this.progressBox = root.querySelector('.progress')!;
		this.dropzone = root.querySelector('.dropzone')!;
		this.fallbackBox = root.querySelector('.fallback')!;
	}

	// ---- properties ----

	/** The underlying renderer, null until created. */
	get renderer(): Renderer | null {
		return this._renderer;
	}

	/** glTF / glb URL, or an already loaded scene (e.g. from `loadGLTFFromFiles`). */
	get model(): string | SceneDesc | null {
		return this._model;
	}
	set model(value: string | SceneDesc | null) {
		this._model = value ?? null;
		this.loadModel();
	}

	/** Equirectangular .hdr URL or decoded image; null uses the procedural sky. */
	get environment(): string | HDRImage | null {
		return this._environment;
	}
	set environment(value: string | HDRImage | null) {
		this._environment = value ?? null;
		this.loadEnvironment();
	}

	/** Render settings; changes restart accumulation, except exposure and tone mapping. */
	get settings(): Partial<RenderSettings> | null {
		return this._settings;
	}
	set settings(value: Partial<RenderSettings> | null) {
		this._settings = value;
		this.applySettings();
	}

	/** Sun overrides. By default the sun is on with the procedural sky and off with an HDR. */
	get sun(): Partial<SunSettings> | null {
		return this._sun;
	}
	set sun(value: Partial<SunSettings> | null) {
		this._sun = value;
		this.applySun();
	}

	/** Shown until the view is ready: true (built-in bar), false, or custom content per update. */
	get progress(): boolean | ((progress: VeachViewProgress) => Node | string) {
		return this._progress;
	}
	set progress(value: boolean | ((progress: VeachViewProgress) => Node | string)) {
		this._progress = value;
		this.updateProgress();
	}

	/** Stops the render loop (keeps the last image). */
	get paused(): boolean {
		return this.hasAttribute('paused');
	}
	set paused(value: boolean) {
		this.toggleAttribute('paused', value);
	}

	/** Small statistics overlay in the top-left corner. */
	get showStats(): boolean {
		return this.hasAttribute('show-stats');
	}
	set showStats(value: boolean) {
		this.toggleAttribute('show-stats', value);
	}

	/** Orbit / pan / zoom with mouse and touch (default true). */
	get controls(): boolean {
		return this.getAttribute('controls') !== 'false';
	}
	set controls(value: boolean) {
		this.setAttribute('controls', String(value));
	}

	/** Use the camera stored in the scene instead of framing its bounds (default true). */
	get useSceneCamera(): boolean {
		return this.getAttribute('use-scene-camera') !== 'false';
	}
	set useSceneCamera(value: boolean) {
		this.setAttribute('use-scene-camera', String(value));
	}

	/** Load dropped .glb / .gltf (+ files) and .hdr files into the view. */
	get droppable(): boolean {
		return this.hasAttribute('droppable');
	}
	set droppable(value: boolean) {
		this.toggleAttribute('droppable', value);
	}

	frameScene(): void {
		this._renderer?.frameScene();
	}

	resetAccumulation(): void {
		this._renderer?.resetAccumulation();
	}

	// ---- lifecycle ----

	connectedCallback(): void {
		// properties set before the element was defined shadow the accessors: re-apply them
		for (const name of ['model', 'environment', 'settings', 'sun', 'progress', 'fallback', 'paused', 'showStats', 'controls', 'useSceneCamera', 'droppable'] as const) {
			if (Object.prototype.hasOwnProperty.call(this, name)) {
				const value = (this as Record<string, unknown>)[name];
				delete (this as Record<string, unknown>)[name];
				(this as Record<string, unknown>)[name] = value;
			}
		}
		this.updateDrop();
		if (this._renderer || this.creating || this.fatal) return;
		this.create();
	}

	disconnectedCallback(): void {
		// a move within the document reconnects in the same task
		queueMicrotask(() => {
			if (!this.isConnected) this.dispose();
		});
	}

	attributeChangedCallback(name: string, oldValue: string | null, value: string | null): void {
		if (oldValue === value) return;
		switch (name) {
			case 'model':
				this.model = value;
				break;
			case 'environment':
				this.environment = value;
				break;
			case 'paused':
				this.updateRunning();
				break;
			case 'show-stats':
				this.statsBox.hidden = !this.showStats;
				break;
			case 'controls':
				this.updateControls();
				break;
			case 'progress':
				this._progress = value !== 'false';
				this.updateProgress();
				break;
			case 'droppable':
				this.updateDrop();
				break;
		}
	}

	private create(): void {
		const generation = this.generation;
		const current = () => generation === this.generation;
		this.creating = true;
		this.connectedAt = performance.now();
		if (typeof this._model === 'string') {
			// fetched and parsed while the shaders compile
			const scene = loadGLTF(this._model);
			scene.catch(() => {}); // reported when the load awaits it
			this.prefetch = { url: this._model, scene };
		}
		this.progressTimer = window.setInterval(() => this.updateProgress(), 500);
		this.updateProgress();
		const onProgress = (p: InitProgress) => {
			if (!current()) return;
			this.init = p;
			this.updateProgress();
			this.emit('veach-progress', p);
		};
		Renderer.create(this.canvas, { onProgress }).then(
			(renderer) => {
				if (!current()) {
					renderer.destroy();
					return;
				}
				this.creating = false;
				this._renderer = renderer;
				renderer.onStats = (s) => this.onStats(s);
				this.applySettings();
				this.applySun();
				this.updateRunning();
				this.updateControls();
				this.updateProgress();
				this.loadModel();
				this.loadEnvironment();
				this.emit('veach-ready', renderer);
			},
			(e: unknown) => {
				if (!current()) return;
				this.creating = false;
				this.fatal = toError(e);
				this.showFallback(this.fatal);
				this.report(this.fatal);
			},
		);
	}

	private dispose(): void {
		this.generation++;
		this.creating = false;
		this.orbit?.dispose();
		this.orbit = null;
		this.detachDrop?.();
		this.detachDrop = null;
		this._renderer?.destroy();
		this._renderer = null;
		this.firstSceneLoaded = false;
		this.init = null;
		this.prefetch = null;
		this.loadToken++;
		this.envToken++;
		window.clearInterval(this.progressTimer);
	}

	// ---- state ----

	private emit<K extends keyof VeachViewEventMap>(type: K, detail: VeachViewEventMap[K] extends CustomEvent<infer D> ? D : never): void {
		this.dispatchEvent(new CustomEvent(type, { detail }));
	}

	private report(error: Error): void {
		const handled = !this.dispatchEvent(new CustomEvent('veach-error', { detail: error, cancelable: true }));
		if (!handled) console.error('[veach-view]', error);
	}

	private applySettings(): void {
		const renderer = this._renderer;
		const settings = this._settings;
		if (!renderer || !settings) return;
		const key = (v: unknown) => JSON.stringify(v);
		const changed = (Object.keys(settings) as (keyof RenderSettings)[]).filter((k) => key(settings[k]) !== key(renderer.settings[k]));
		Object.assign(renderer.settings, settings);
		if (changed.some((k) => !isPresentationSetting(k))) renderer.resetAccumulation();
	}

	private applySun(): void {
		const renderer = this._renderer;
		const sun = this._sun;
		if (!renderer || !sun) return;
		const changed = (Object.keys(sun) as (keyof SunSettings)[]).some((k) => JSON.stringify(sun[k]) !== JSON.stringify(renderer.sun[k]));
		Object.assign(renderer.sun, sun);
		if (changed) renderer.resetAccumulation();
	}

	private updateRunning(): void {
		if (!this._renderer) return;
		if (this.paused) this._renderer.stop();
		else this._renderer.start();
	}

	private updateControls(): void {
		const renderer = this._renderer;
		if (renderer && this.controls && !this.orbit) {
			this.orbit = new OrbitController(renderer.camera, this.canvas, () => renderer.resetAccumulation());
		} else if (!(renderer && this.controls) && this.orbit) {
			this.orbit.dispose();
			this.orbit = null;
		}
	}

	private updateDrop(): void {
		if (this.droppable && this.isConnected && !this.detachDrop) {
			this.detachDrop = attachFileDrop(this, {
				onDrop: (files) => {
					if (files.environment) this.environment = files.environment.image;
					if (files.model) this.model = files.model.scene;
					this.emit('veach-drop', files);
				},
				onDragChange: (dragging) => (this.dropzone.hidden = !dragging),
				onError: (e) => this.report(e),
			});
		} else if (!this.droppable && this.detachDrop) {
			this.detachDrop();
			this.detachDrop = null;
			this.dropzone.hidden = true;
		}
	}

	// Scene loads are serialized; a newer model supersedes any load still in flight.
	private loadModel(): void {
		const renderer = this._renderer;
		if (!renderer) return;
		const token = ++this.loadToken;
		const desc = this._model ?? EMPTY_SCENE;
		this.setLoading(true);
		this.loadChain = this.loadChain.then(async () => {
			try {
				const prefetched = this.prefetch;
				this.prefetch = null;
				const scene = typeof desc === 'string' ? await (prefetched?.url === desc ? prefetched.scene : loadGLTF(desc)) : desc;
				if (token !== this.loadToken) return;
				const stats = await renderer.setScene(scene, { useSceneCamera: this.useSceneCamera });
				if (token !== this.loadToken) return;
				this.emit('veach-load', stats);
			} catch (e) {
				if (token === this.loadToken) this.report(toError(e));
			} finally {
				if (token === this.loadToken) {
					this.firstSceneLoaded = true;
					this.setLoading(false);
					this.updateProgress();
				}
			}
		});
	}

	private loadEnvironment(): void {
		const renderer = this._renderer;
		if (!renderer) return;
		const token = ++this.envToken;
		const environment = this._environment;
		void (async () => {
			try {
				const image = typeof environment === 'string' ? await loadHDR(environment) : environment;
				if (token !== this.envToken) return;
				renderer.setEnvironment(image);
				renderer.sun.enabled = this._sun?.enabled ?? !image;
				renderer.resetAccumulation();
			} catch (e) {
				if (token === this.envToken) this.report(toError(e));
			}
		})();
	}

	private setLoading(loading: boolean): void {
		if (this.loading === loading) return;
		this.loading = loading;
		this.emit('veach-loadingchange', loading);
	}

	// ---- overlays ----

	private onStats(s: RendererStats): void {
		this.emit('veach-stats', s);
		const now = performance.now();
		if (!this.showStats || now - this.lastStatsUpdate < 250) return;
		this.lastStatsUpdate = now;
		const settings = this._renderer?.settings;
		const sc = s.scene;
		const vt = s.virtualTexture;
		this.statsBox.textContent = [
			`${s.width}x${s.height}  ${s.frameIndex} spp  ${s.frameMs.toFixed(1)} ms${this.loading ? '  loading...' : ''}`,
			sc && sc.triangles > 0 ? `${sc.triangles.toLocaleString()} tris  ${sc.instances} inst  ${sc.emissiveTriangles} emissive` : '',
			vt && vt.textures > 0 ? `VT ${vt.residentPages}/${vt.physicalPages} pages  ${vt.pendingRequests} pending` : '',
			settings && settings.debugMode !== DebugMode.None ? `view ${DebugMode[settings.debugMode]}` : '',
			settings
				? `${Tonemapper[settings.tonemapper]}  ${settings.autoExposureMethod === AutoExposureMethod.Histogram ? `auto ${Math.log2(s.exposure.exposure).toFixed(1)} EV (bias ${settings.autoExposureBias.toFixed(1)})` : `manual ${settings.autoExposureBias.toFixed(1)} EV`}`
				: '',
		]
			.filter(Boolean)
			.join('\n');
		this.statsBox.hidden = false;
	}

	private currentProgress(): VeachViewProgress {
		const elapsed = Math.floor((performance.now() - this.connectedAt) / 1000);
		if (this._renderer) return { stage: 'model', progress: null, message: 'Loading the scene', elapsed };
		const init = this.init;
		return { stage: init?.stage ?? 'device', progress: init?.progress ?? 0, message: init?.message ?? 'Starting', elapsed };
	}

	private updateProgress(): void {
		const ready = this._renderer !== null && this.firstSceneLoaded;
		const visible = !ready && !this.fatal && this._progress !== false && (this.creating || this._renderer !== null);
		this.progressBox.hidden = !visible;
		if (ready || this.fatal) window.clearInterval(this.progressTimer);
		if (!visible) return;
		const p = this.currentProgress();
		if (p.progress === null) this.progressBox.removeAttribute('aria-valuenow');
		else this.progressBox.setAttribute('aria-valuenow', String(Math.round(p.progress * 100)));
		if (typeof this._progress === 'function') {
			this.progressBox.replaceChildren(this._progress(p));
			return;
		}
		if (!this.progressBox.firstElementChild?.classList.contains('message')) {
			this.progressBox.innerHTML = '<div class="message"></div><div class="track"><div class="fill"></div></div><div class="hint"></div>';
		}
		const [message, track, hint] = Array.from(this.progressBox.children) as HTMLElement[];
		const fill = track.firstElementChild as HTMLElement;
		message.textContent = p.elapsed >= 2 ? `${p.message}  ${p.elapsed} s` : p.message;
		fill.classList.toggle('indeterminate', p.progress === null);
		fill.style.width = p.progress === null ? '' : `${Math.max(2, p.progress * 100)}%`;
		hint.textContent = p.stage === 'shaders' && p.elapsed >= 3 ? 'First load compiles the shaders; later loads use the browser cache.' : '';
	}

	private showFallback(error: Error): void {
		this.canvas.hidden = true;
		this.statsBox.hidden = true;
		this.progressBox.hidden = true;
		window.clearInterval(this.progressTimer);
		this.fallbackBox.replaceChildren(this.fallback ? this.fallback(error) : `Veach: ${error.message}`);
		this.fallbackBox.hidden = false;
	}
}

// Typed listeners for the veach-* events.
export interface VeachViewElement {
	addEventListener<K extends keyof VeachViewEventMap>(type: K, listener: (this: VeachViewElement, ev: VeachViewEventMap[K]) => unknown, options?: boolean | AddEventListenerOptions): void;
	addEventListener(type: string, listener: EventListenerOrEventListenerObject, options?: boolean | AddEventListenerOptions): void;
	removeEventListener<K extends keyof VeachViewEventMap>(type: K, listener: (this: VeachViewElement, ev: VeachViewEventMap[K]) => unknown, options?: boolean | EventListenerOptions): void;
	removeEventListener(type: string, listener: EventListenerOrEventListenerObject, options?: boolean | EventListenerOptions): void;
}

/** Registers the element (as `<veach-view>` unless another tag is given); safe to call repeatedly. */
export function defineVeachView(tagName = 'veach-view'): void {
	if (customElements.get(tagName)) return;
	// one constructor per tag: other tags get a subclass
	customElements.define(tagName, tagName === 'veach-view' ? VeachViewElement : class extends VeachViewElement {});
}

declare global {
	interface HTMLElementTagNameMap {
		'veach-view': VeachViewElement;
	}
}
