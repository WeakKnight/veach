// Validate each sweep variant and summarize paired GPU spans without mixing schedules.
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const directory = process.argv[2];
if (!directory) throw new Error('Usage: node scripts/compare-wavefront-sweep.mjs SWEEP_DIRECTORY');
const referencePath = join(directory, 'megakernel');
const reference = JSON.parse(readFileSync(join(referencePath, 'report.json'), 'utf8'));
if (!reference.completed || JSON.stringify(reference.plannedScenes) !== JSON.stringify(reference.results.map(r => r.name))) throw new Error('Reference sweep did not complete all planned scenes');
const variants = [];
const expectedVariants = new Set(reference.config.variants.map(variant => variant.name));
for (const entry of readdirSync(directory, { withFileTypes: true })) {
	if (!entry.isDirectory() || entry.name === 'megakernel') continue;
	const candidatePath = join(directory, entry.name);
	if (!existsSync(join(candidatePath, 'report.json'))) continue;
	if (!expectedVariants.has(entry.name)) throw new Error(`Unexpected sweep variant: ${entry.name}`);
	const report = JSON.parse(readFileSync(join(candidatePath, 'report.json'), 'utf8'));
	if (report.browser !== reference.browser || JSON.stringify(report.sourceHashes) !== JSON.stringify(reference.sourceHashes)) {
		throw new Error(`Inconsistent browser/source identity for ${entry.name}`);
	}
	if (!report.completed || JSON.stringify(report.results.map(r => r.name)) !== JSON.stringify(reference.plannedScenes)) throw new Error(`Incomplete sweep: ${entry.name}`);
	const result = spawnSync(process.execPath, ['scripts/compare-wavefront.mjs', referencePath, candidatePath], { cwd: root, encoding: 'utf8' });
	if (result.status !== 0) throw new Error(result.stderr || `Comparison failed: ${entry.name}`);
	const comparison = JSON.parse(readFileSync(join(candidatePath, 'comparison.json'), 'utf8'));
	for (const scene of comparison.results) {
		if (scene.maxAbsoluteError > 1e-5) throw new Error(`Image mismatch: ${entry.name}/${scene.name}`);
		const measured = report.results.find(r => r.name === scene.name);
		if (measured.errors.length || measured.pairedErrors.length !== report.config.repeats || measured.pairedErrors.some(r => r.maxError > 1e-5)) {
			throw new Error(`Invalid per-round evidence: ${entry.name}/${scene.name}`);
		}
	}
	variants.push({ name: entry.name, tailStart: report.config.tailStart, tailThreshold: report.config.tailThreshold,
		compaction: report.config.compaction, results: comparison.results });
}
if (variants.length !== expectedVariants.size) throw new Error('Missing sweep variants');
const summary = { directory: resolve(directory), reference: reference.results.map(r => r.name), variants };
writeFileSync(join(directory, 'sweep-comparison.json'), JSON.stringify(summary, null, 2));
console.table(variants.map(variant => ({ variant: variant.name, ...Object.fromEntries(variant.results.map(scene =>
	[scene.name, `${scene.candidateSpanMs.toFixed(3)} ms (${scene.spanSpeedup.toFixed(2)}x)`])) })));
