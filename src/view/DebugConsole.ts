import { ConsoleRegistry } from '../debug/ConsoleRegistry';

export interface DebugConsoleOptions {
	onOpenChange?: (open: boolean) => void;
	parent?: HTMLElement;
	historyKey?: string;
}

/** Explicitly mounted UI; importing this module does not touch the DOM. */
export class DebugConsole {
	private readonly host = document.createElement('div');
	private readonly root = this.host.attachShadow({ mode: 'open' });
	private readonly input: HTMLInputElement;
	private readonly log: HTMLElement;
	private readonly suggestions: HTMLElement;
	private readonly status: HTMLElement;
	private readonly abort = new AbortController();
	private state: 'closed' | 'compact' | 'expanded' = 'closed';
	private history: string[] = [];
	private historyIndex = 0;
	private draft = '';
	private completion: { candidates: string[]; index: number } | null = null;
	private previousFocus: HTMLElement | null = null;
	private busy = false;
	private disposed = false;
	private readonly historyKey: string;
	get isOpen(): boolean { return this.state !== 'closed'; }

	constructor(readonly registry: ConsoleRegistry, private readonly options: DebugConsoleOptions = {}) {
		this.historyKey = options.historyKey ?? 'veach.console.history.v1';
		this.host.dataset.veachConsole = '';
		this.host.hidden = true;
		this.root.innerHTML = `<style>
:host{position:fixed;inset:0;z-index:2147483647;color:#e9edf5;font:13px/1.5 ui-monospace,Consolas,monospace;--accent:#c5ed83} :host([hidden]){display:none}
*{box-sizing:border-box} .panel{position:absolute;inset:0 0 auto;background:#10151bf5;border-bottom:1px solid #4c5d70;box-shadow:0 16px 48px #0008;padding:12px 20px;display:flex;flex-direction:column;max-height:46vh} :host([data-expanded]) .panel{height:82vh;max-height:82vh}
header{display:flex;align-items:center;gap:16px;margin-bottom:8px;font-size:11px;color:#9baaba} strong{color:var(--accent);letter-spacing:2px} header span{flex:1} button{font:inherit;border:0;background:none;color:#9baaba;cursor:pointer;padding:5px 10px}
.log{min-height:0;overflow:auto;white-space:pre-wrap;overflow-wrap:anywhere;flex:1;max-height:20vh;padding:0 0 8px} :host([data-expanded]) .log{max-height:none} .line{padding:2px 0} .error{color:#ffa5a0} .prompt{color:var(--accent)}
label{display:flex;gap:10px;padding:10px 0;border-top:1px solid #344253;color:var(--accent)} input{width:100%;border:0;outline:0;background:transparent;color:white;font:inherit;caret-color:var(--accent)}
.suggestions{max-height:16vh;overflow:auto;display:flex;flex-wrap:wrap;gap:3px 14px;color:#a6b6c7;font-size:11px}.suggestions button{padding:2px 0;text-align:left}.suggestions button:hover{color:var(--accent)} .status{font-size:10px;color:#8194a9;padding-top:6px} @media(max-width:600px){.panel{padding:10px}header span{display:none}}
</style><section class="panel" role="dialog" aria-label="Veach rendering console" aria-modal="true">
<header><strong>VEACH CONSOLE</strong><span>~ compact / expand / close · Esc close</span><button type="button" aria-label="Close console">✕</button></header>
<div class="log" role="log" aria-live="polite"></div><label><span>›</span><input aria-label="Console command" autocomplete="off" spellcheck="false" placeholder="r.SHARC.Enabled · help · r.PathTracing.MaxBounces 4"></label>
<div class="suggestions" aria-label="Command suggestions"></div><div class="status">Enter execute · Tab / Shift+Tab complete · ↑↓ history · name ? help</div></section>`;
		this.input = this.root.querySelector('input')!;
		this.log = this.root.querySelector('.log')!;
		this.suggestions = this.root.querySelector('.suggestions')!;
		this.status = this.root.querySelector('.status')!;
		try { const saved: unknown = JSON.parse(localStorage.getItem(this.historyKey) ?? '[]'); if (Array.isArray(saved)) this.history = saved.filter(v => typeof v === 'string').slice(-100); } catch { /* Storage may be unavailable. */ }
		(options.parent ?? document.body).append(this.host);
		this.root.querySelector('header button')!.addEventListener('click', () => this.close());
		this.input.addEventListener('input', () => { this.completion = null; this.historyIndex = this.history.length; this.updateSuggestions(); });
		window.addEventListener('keydown', this.keydown, { capture: true, signal: this.abort.signal });
		window.addEventListener('keyup', e => { if (this.isOpen || e.code === 'Backquote') e.stopImmediatePropagation(); }, { capture: true, signal: this.abort.signal });
		this.host.addEventListener('pointerdown', e => { e.stopPropagation(); if (e.composedPath()[0] === this.host) this.input.focus(); });
		this.host.addEventListener('wheel', e => e.stopPropagation());
		this.write('Type help to list settings, or r.SHARC.Enabled ? for help. Values apply to this session.');
	}
	open(expanded = false): void {
		if (this.disposed) return;
		const wasOpen = this.isOpen;
		if (!wasOpen) { this.previousFocus = document.activeElement as HTMLElement | null; if (document.pointerLockElement) document.exitPointerLock(); }
		this.state = expanded ? 'expanded' : 'compact'; this.host.hidden = false; this.host.toggleAttribute('data-expanded', expanded);
		this.historyIndex = this.history.length; this.input.focus(); this.updateSuggestions();
		if (!wasOpen) this.options.onOpenChange?.(true);
	}
	close(): void {
		if (!this.isOpen) return;
		this.state = 'closed'; this.host.hidden = true; this.previousFocus?.focus(); this.options.onOpenChange?.(false);
	}
	dispose(): void { this.close(); this.disposed = true; this.abort.abort(); this.host.remove(); }
	private readonly keydown = (event: KeyboardEvent): void => {
		if (event.isComposing || event.keyCode === 229) { if (this.isOpen) event.stopImmediatePropagation(); return; }
		if (event.code === 'Backquote' && !event.ctrlKey && !event.altKey && !event.metaKey) {
			event.preventDefault(); event.stopImmediatePropagation();
			if (!event.repeat) { if (!this.isOpen) this.open(); else if (this.state === 'compact') this.open(true); else this.close(); }
			return;
		}
		if (!this.isOpen) return;
		event.stopImmediatePropagation();
		if (event.key === 'Escape') { event.preventDefault(); this.close(); }
		else if (event.key === 'Enter') { event.preventDefault(); void this.submit(); }
		else if (event.key === 'Tab') {
			event.preventDefault();
			if (!this.completion) this.completion = { candidates: this.registry.complete(this.input.value), index: event.shiftKey ? 0 : -1 };
			const c = this.completion;
			if (c.candidates.length) { c.index = (c.index + (event.shiftKey ? -1 : 1) + c.candidates.length) % c.candidates.length; this.input.value = c.candidates[c.index]; this.updateSuggestions(); }
		} else if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
			event.preventDefault();
			if (this.historyIndex === this.history.length) this.draft = this.input.value;
			this.historyIndex = Math.max(0, Math.min(this.history.length, this.historyIndex + (event.key === 'ArrowUp' ? -1 : 1)));
			this.input.value = this.history[this.historyIndex] ?? this.draft; this.completion = null; this.updateSuggestions();
		}
	};
	private write(text: string, kind = ''): void {
		const line = document.createElement('div'); line.className = `line ${kind}`; line.textContent = text; this.log.append(line);
		while (this.log.childElementCount > 300) this.log.firstElementChild!.remove();
		this.log.scrollTop = this.log.scrollHeight;
	}
	private updateSuggestions(): void {
		this.suggestions.replaceChildren();
		for (const text of this.registry.complete(this.input.value).slice(0, 10)) {
			const button = document.createElement('button'); button.type = 'button'; button.textContent = text;
			button.onclick = () => { this.input.value = text; this.completion = null; this.input.focus(); this.updateSuggestions(); };
			this.suggestions.append(button);
		}
	}
	private async submit(): Promise<void> {
		const line = this.input.value.trim();
		if (!line || this.busy) return;
		this.busy = true; this.input.readOnly = true; this.status.textContent = 'Applying command…';
		this.write(`› ${line}`, 'prompt');
		if (this.history.at(-1) !== line) this.history.push(line);
		this.history = this.history.slice(-100); this.historyIndex = this.history.length;
		try { localStorage.setItem(this.historyKey, JSON.stringify(this.history)); } catch { /* History is optional. */ }
		this.input.value = ''; this.draft = ''; this.completion = null;
		try {
			const result = await this.registry.execute(line);
			if (this.disposed) return;
			if (result.clear) this.log.replaceChildren();
			for (const text of result.lines) this.write(text, result.ok ? '' : 'error');
		} finally {
			this.busy = false; this.input.readOnly = false; this.status.textContent = 'Enter execute · Tab / Shift+Tab complete · ↑↓ history · name ? help'; this.updateSuggestions();
		}
	}
}
