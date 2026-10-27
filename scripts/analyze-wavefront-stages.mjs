// Attribute measured GPU time before choosing the next optimization experiment.
import { readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const directory = process.argv[2];
if (!directory) throw new Error('Usage: node scripts/analyze-wavefront-stages.mjs REPORT_DIRECTORY');
const report = JSON.parse(readFileSync(join(directory, 'report.json'), 'utf8'));
const results = report.results.map(scene => {
	const stages = {}, bounces = {};
	let samples = 0, total = 0;
	for (const repeat of scene.repeats) {
		if (!repeat.timings?.length || !repeat.stages) throw new Error(`Missing per-stage measurements: ${scene.name}`);
		const stageTotal = Object.values(repeat.stages).reduce((sum, value) => sum + value, 0);
		const measured = repeat.timings.reduce((sum, value) => sum + value, 0);
		if (Math.abs(stageTotal - measured) > 1e-6) throw new Error(`Stage attribution does not sum to GPU timings: ${scene.name}`);
		samples += repeat.timings.length;
		total += stageTotal;
		for (const [label, milliseconds] of Object.entries(repeat.stages)) {
			const [, stage, bounce] = label.split('.');
			if (!stage || !bounce) throw new Error(`Not a wavefront stage: ${label}`);
			stages[stage] = (stages[stage] ?? 0) + milliseconds;
			bounces[bounce] = (bounces[bounce] ?? 0) + milliseconds;
		}
	}
	const summarize = values => Object.entries(values).map(([name, milliseconds]) => ({ name,
		meanMs: milliseconds / samples, fraction: milliseconds / total })).sort((a, b) => b.meanMs - a.meanMs);
	return { scene: scene.name, samples, meanGpuMs: total / samples, stages: summarize(stages), bounces: summarize(bounces) };
});
writeFileSync(join(directory, 'stage-analysis.json'), JSON.stringify({ source: resolve(directory), results }, null, 2));
for (const result of results) console.log(JSON.stringify(result));
