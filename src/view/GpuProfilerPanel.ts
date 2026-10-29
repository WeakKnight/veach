import type { GpuProfiler, GpuProfileNode } from '../render/GpuProfiler';

/** Explicitly mounted UI; core renderer has no keyboard or DOM side effects. */
export class GpuProfilerPanel {
	private readonly host = document.createElement('div');
	private readonly root = this.host.attachShadow({ mode: 'open' });
	private readonly abort = new AbortController();
	private readonly unsubscribe: () => void;
	private previousFocus: HTMLElement | null = null;
	private disposed = false;
	get isOpen(): boolean { return !this.host.hidden; }

	constructor(private readonly profiler: GpuProfiler, private readonly options: { onOpenChange?: (open: boolean) => void } = {}) {
		this.host.hidden = true; this.host.dataset.veachGpuProfiler = '';
		this.root.innerHTML = `<style>
:host{position:fixed;inset:4vh 4vw;z-index:10001;font:13px/1.5 system-ui,sans-serif;color:#e5edf3;display:block}:host([hidden]){display:none}
*{box-sizing:border-box}.panel{height:100%;background:#111a23f5;border:1px solid #445463;border-radius:14px;box-shadow:0 24px 100px #0009;display:flex;flex-direction:column;overflow:hidden}
header{padding:18px 22px;display:flex;gap:16px;align-items:center;border-bottom:1px solid #364553}h2{margin:0;font-size:18px;letter-spacing:.06em}.tag{color:#a9bfce;margin-right:auto;font-size:12px}
button,select{font:inherit;color:inherit;border:1px solid #607283;background:#243341;border-radius:6px;padding:7px 12px;cursor:pointer}button:hover{background:#3b5264}button:focus-visible,select:focus-visible,summary:focus-visible{outline:2px solid #c6f56c;outline-offset:2px}button:disabled{opacity:.5;cursor:wait}
.status{padding:10px 22px;color:#c6f56c}.stats{padding:0 22px 12px;font-size:15px}.stats strong{font-size:25px;color:#fff}.body{overflow:auto;padding:0 22px 22px;display:grid;grid-template-columns:minmax(0,3fr) minmax(0,2fr);gap:24px}h3{color:#a9bfce;font-size:12px;letter-spacing:.1em;text-transform:uppercase}table{width:100%;border-collapse:collapse;font-variant-numeric:tabular-nums}td,th{padding:6px 8px;border-bottom:1px solid #ffffff12;text-align:right}td:first-child,th:first-child{text-align:left;overflow-wrap:anywhere}th{color:#a9bfce;font-size:11px}
summary,.leaf{padding:5px 8px;border-bottom:1px solid #ffffff12;cursor:pointer;font-variant-numeric:tabular-nums}summary:hover,.leaf:hover{background:#ffffff09}.metric{float:right;color:#c6f56c;font-variant-numeric:tabular-nums}details>div{margin-left:16px;border-left:1px solid #344655}.leaf{cursor:default}.bar{height:3px;background:#b4df63;margin-top:4px;max-width:100%}footer{margin-top:auto;border-top:1px solid #364553;padding:10px 22px;color:#9fb1be;font-size:12px}.warning{color:#ffcc87}@media(max-width:760px){:host{inset:2vh 2vw}.body{grid-template-columns:1fr}header{flex-wrap:wrap}.tag{display:none}}
</style><section class="panel" role="dialog" aria-modal="false" aria-label="GPU profiler">
<header><h2>GPU PROFILER</h2><span class="tag">Ctrl + Shift + , · 单帧捕获</span><select aria-label="排序"><option value="time">按耗时排序</option><option value="order">按提交顺序</option></select><button class="capture">重新捕获</button><button class="close" aria-label="关闭 GPU profiler">关闭</button></header>
<div class="status" role="status"></div><div class="stats"></div><div class="body"><section><h3>阶段与弹射 · 累计 GPU 时间</h3><div class="tree"></div></section><section><h3>热点 · 合并同名 Pass</h3><table><thead><tr><th>Pass</th><th>次数</th><th>ms</th><th>占比</th></tr></thead><tbody></tbody></table></section></div>
<footer>父级汇总子 Pass；不要重复相加。帧跨度还包含 Pass 间隙和提交等待。浏览器会量化时间戳，极短 Pass 可能显示 0。</footer></section>`;
		document.body.append(this.host);
		this.root.querySelector('.close')!.addEventListener('click', () => this.close());
		this.root.querySelector('.capture')!.addEventListener('click', () => this.profiler.capture());
		this.root.querySelector('select')!.addEventListener('change', () => this.render());
		this.host.addEventListener('pointerdown', event => event.stopPropagation());
		this.host.addEventListener('wheel', event => event.stopPropagation());
		window.addEventListener('keydown', event => {
			if (event.code === 'Comma' && event.ctrlKey && event.shiftKey && !event.altKey && !event.metaKey) {
				event.preventDefault(); event.stopImmediatePropagation();
				if (!event.repeat) this.open();
			} else if (this.isOpen && event.key === 'Escape') { event.preventDefault(); event.stopImmediatePropagation(); this.close(); }
		}, { capture: true, signal: this.abort.signal });
		this.unsubscribe = profiler.subscribe(() => { if (this.isOpen) this.render(); });
	}
	open(): void {
		if (this.disposed) return;
		if (!this.isOpen) {
			this.previousFocus = document.activeElement as HTMLElement | null;
			this.host.hidden = false; this.options.onOpenChange?.(true);
			if (document.pointerLockElement) document.exitPointerLock();
		}
		this.profiler.capture(); this.render();
		this.root.querySelector<HTMLButtonElement>('.close')!.focus();
	}
	close(): void {
		if (!this.isOpen) return;
		this.host.hidden = true; this.profiler.cancelPending(); this.previousFocus?.focus(); this.options.onOpenChange?.(false);
	}
	private render(): void {
		const p = this.profiler, report = p.report;
		const messages = { unsupported: '此设备或浏览器不支持 GPU timestamp-query，无法提供真实 GPU 耗时。', idle: '准备捕获', waiting: '等待下一渲染帧…', recording: '正在捕获 GPU Pass…', reading: '正在异步读取 GPU 时间戳…', ready: '捕获完成 · 画面继续运行，数据保持到下一次捕获', error: `捕获失败：${p.error ?? ''}` };
		this.root.querySelector('.status')!.textContent = messages[p.status];
		this.root.querySelector<HTMLButtonElement>('.capture')!.disabled = !p.supported || ['waiting', 'recording', 'reading'].includes(p.status);
		const stats = this.root.querySelector('.stats')!, tree = this.root.querySelector('.tree')!, table = this.root.querySelector('tbody')!;
		stats.replaceChildren(); tree.replaceChildren(); table.replaceChildren();
		if (!report) return;
		const total = document.createElement('strong'); total.textContent = `${report.totalMs.toFixed(3)} ms`;
		stats.append(total, ` Pass 合计 · 跨度 ${report.spanMs.toFixed(3)} ms · ${report.width}×${report.height} · ${report.samples} samples · ${report.passes.length} passes · ${report.integrator} · #${report.id}`);
		if (report.dropped || report.invalid || !report.samples) {
			const warning = document.createElement('div'); warning.className = 'warning';
			warning.textContent = `${report.dropped ? `查询容量不足或已有计时，遗漏 ${report.dropped} 个 Pass。` : ''}${report.invalid ? `${report.invalid} 个时间戳无效。` : ''}${!report.samples ? '本帧没有路径采样，仅包含呈现工作。' : ''}`;
			stats.append(warning);
		}
		const byTime = this.root.querySelector<HTMLSelectElement>('select')!.value === 'time';
		const nodes = (parent: Element, entries: GpuProfileNode[], depth: number) => {
			for (const node of byTime ? [...entries].sort((a, b) => b.ms - a.ms) : entries) {
				const element = document.createElement(node.children.length ? 'details' : 'div');
				const row = document.createElement(node.children.length ? 'summary' : 'div');
				if (element instanceof HTMLDetailsElement) element.open = depth < 1;
				row.className = node.children.length ? '' : 'leaf';
				const metric = document.createElement('span'); metric.className = 'metric'; metric.textContent = `${node.ms.toFixed(3)} ms · ${node.count}×`;
				row.append(metric, document.createTextNode(node.name)); element.append(row);
				if (node.children.length) { const children = document.createElement('div'); nodes(children, node.children, depth + 1); element.append(children); }
				parent.append(element);
			}
		};
		nodes(tree, report.roots, 0);
		for (const hot of report.hotspots) {
			const row = document.createElement('tr'), percent = report.totalMs ? hot.ms / report.totalMs * 100 : 0;
			for (const text of [hot.name, String(hot.count), hot.ms.toFixed(3), `${percent.toFixed(1)}%`]) { const cell = document.createElement('td'); cell.textContent = text; row.append(cell); }
			const bar = document.createElement('div'); bar.className = 'bar'; bar.style.width = `${percent}%`; row.firstElementChild!.append(bar); table.append(row);
		}
	}
	dispose(): void { this.close(); this.disposed = true; this.unsubscribe(); this.abort.abort(); this.host.remove(); }
}
