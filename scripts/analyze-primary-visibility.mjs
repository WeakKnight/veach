import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const path = resolve(process.argv[2] ?? '.tools/visibility/benchmark/report.json');
const report = JSON.parse(readFileSync(path, 'utf8'));
if (!report.completed || report.errors.length) throw new Error('A complete, error-free benchmark report is required');
const median = values => [...values].sort((a, b) => a - b)[Math.floor(values.length / 2)];
const geometricMean = values => Math.exp(values.reduce((sum, v) => sum + Math.log(v), 0) / values.length);
const rows = [];
for (const scene of report.cases) for (const [width, height] of report.config.resolutions) {
	const measurements = scene.measurements.filter(m => m.width === width && m.height === height);
	const variants = Object.fromEntries(['default', 'shared-reference', 'rasterized'].map(mode => {
		const rounds = measurements.filter(m => m.mode === mode).sort((a, b) => a.round - b.round);
		if (rounds.length !== report.config.rounds) throw new Error(`Missing rounds: ${scene.name}/${width}/${mode}`);
		return [mode, rounds];
	}));
	const reference = variants.default, shared = variants['shared-reference'], raster = variants.rasterized;
	const gpuMs = Object.fromEntries(Object.entries(variants).map(([k, v]) => [k, median(v.map(m => m.gpuMs))]));
	const primaryMs = Object.fromEntries(Object.entries(variants).map(([k, v]) => [k, median(v.map(m => m.primaryMs))]));
	const pairedRatio = median(raster.map((m, i) => m.gpuMs / reference[i].gpuMs));
	const sharedRatio = median(raster.map((m, i) => m.gpuMs / shared[i].gpuMs));
	const primaryRatio = median(raster.map((m, i) => m.primaryMs / shared[i].primaryMs));
	const primaryDefaultRatio = median(raster.map((m, i) => m.primaryMs / reference[i].primaryMs));
	const deltaMs = median(raster.map((m, i) => m.gpuMs - reference[i].gpuMs));
	const stats = raster.at(-1).stats;
	rows.push({ scene: scene.name, width, height, hasAlphaTested: raster[0].hasAlphaTested, gpuMs, primaryMs, pairedRatio, sharedRatio, primaryRatio, primaryDefaultRatio, deltaMs,
		cpuMs: Object.fromEntries(Object.entries(variants).map(([k, v]) => [k, median(v.map(m => m.cpuMs))])),
		bufferBytes: Object.fromEntries(Object.entries(variants).map(([k, v]) => [k, median(v.map(m => m.bufferBytes))])),
		primaryKernelMs: Object.fromEntries(Object.entries(variants).map(([k, v]) => [k, median(v.map(m => m.primaryKernelMs))])),
		stageMs: Object.fromEntries(Object.entries(variants).map(([mode, rounds]) => [mode,
			Object.fromEntries(Object.keys(rounds[0].stages).map(stage => [stage, median(rounds.map(m => m.stages[stage]))]))])),
		paddingFraction: stats.vertexSlots ? stats.paddingVertexSlots / stats.vertexSlots : 0,
		fallbackFraction: stats.fallbackPixels / (width * height), stats });
}
const opaque = rows.filter(r => r.hasAlphaTested === false);
if (!opaque.length) throw new Error('No opaque benchmark cases');
const alpha = rows.filter(r => ['mixed-alpha', 'deep-alpha'].includes(r.scene));
if (alpha.length !== report.config.resolutions.length * 2) throw new Error('Mixed and deep alpha are required at every resolution');
const primaryReduction = 1 - geometricMean(opaque.map(r => r.primaryDefaultRatio));
const completeReduction = 1 - geometricMean(opaque.map(r => r.pairedRatio));
const alphaFailures = alpha.filter(r => r.deltaMs > Math.max(r.gpuMs.default * 0.05, 0.1));
const gate = { primaryReduction, completeReduction, alphaFailures: alphaFailures.map(r => `${r.scene}/${r.width}x${r.height}`),
	performancePassed: primaryReduction >= 0.2 && completeReduction >= 0.05 && alphaFailures.length === 0 };
writeFileSync(resolve(dirname(path), 'summary.json'), JSON.stringify({ gate, rows }, null, 2));
const pct = n => `${(n * 100).toFixed(1)}%`, ms = n => n.toFixed(3);
const lines = ['# Primary visibility measurements', '',
	`${report.config.rounds} alternating rounds; ${report.config.warmup} warmup and ${report.config.samples} measured samples per variant. Values are medians of round medians. Changes use median paired ratios. GPU times are milliseconds per sample.`, '',
	'| Scene | Resolution | Default RT | Shared-jitter RT | Raster | Total change vs default | Primary change vs shared RT | Fallback pixels | Padding |',
	'|---|---|---:|---:|---:|---:|---:|---:|---:|',
	...rows.map(r => `| ${r.scene} | ${r.width}×${r.height} | ${ms(r.gpuMs.default)} | ${ms(r.gpuMs['shared-reference'])} | ${ms(r.gpuMs.rasterized)} | ${pct(r.pairedRatio - 1)} | ${pct(r.primaryRatio - 1)} | ${pct(r.fallbackFraction)} | ${pct(r.paddingFraction)} |`), '',
	'## Performance gate', '', `- Opaque primary reduction: ${pct(primaryReduction)} (requires at least 20%).`,
	`- Opaque complete-sample reduction versus original default: ${pct(completeReduction)} (requires at least 5%).`,
	`- Alpha regression failures: ${gate.alphaFailures.join(', ') || 'none'} (limit max(5%, 0.1 ms/sample)).`,
	`- Performance gate: **${gate.performancePassed ? 'PASS' : 'FAIL'}**. Correctness remains a separate required gate.`, '',
	'Full JSON includes CPU submission medians, stage timings, allocation sizes, useful/padded vertex slots, and alpha/numerical/sparse fallback counts.', ''];
writeFileSync(resolve(dirname(path), 'summary.md'), lines.join('\n'));
console.log(JSON.stringify(gate, null, 2));
