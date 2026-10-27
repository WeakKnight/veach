// Alternate the two integrators per scene, reversing order on successive rounds.
// Individual reports/captures remain available; aggregate reports use the same comparison tool.
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const option = (name, fallback) => { const i = args.indexOf(`--${name}`); return i < 0 ? fallback : args[i + 1]; };
const output = resolve(option('out', '.tools/wavefront/ab'));
const rounds = Number(option('rounds', 2));
if (!Number.isInteger(rounds) || rounds < 1) throw new Error('Invalid rounds');
const scenes = option('only', 'classroom,breakfast-room,bmw-m6,glass-of-water,veach-mis').split(',');
const pass = args.filter((_, i) => !['--out', '--rounds', '--only'].includes(args[i]) && !['--out', '--rounds', '--only'].includes(args[i - 1]));
const aggregate = {};
for (let round = 0; round < rounds; round++) {
	for (const scene of scenes) {
		const order = round % 2 === 0 ? ['megakernel', 'wavefront'] : ['wavefront', 'megakernel'];
		for (const mode of order) {
			const folder = join(output, `round-${round}`, scene, mode);
			console.log(`[ab] round ${round + 1}/${rounds} ${scene} ${mode}`);
			const result = spawnSync(process.execPath, ['scripts/wavefront-benchmark.mjs', ...pass, '--mode', mode, '--only', scene, '--out', folder], { cwd: root, stdio: 'inherit' });
			if (result.status !== 0) process.exit(result.status ?? 1);
			const report = JSON.parse(readFileSync(join(folder, 'report.json'), 'utf8'));
			const sample = report.results[0];
			if (!sample) throw new Error(`Missing result for ${scene}`);
			aggregate[mode] ??= { ...report, results: [] };
			const existing = aggregate[mode].results.find(r => r.name === scene);
			if (existing) existing.repeats.push(...sample.repeats);
			else aggregate[mode].results.push(sample);
			const target = join(output, mode);
			mkdirSync(target, { recursive: true });
			copyFileSync(join(folder, `${scene}.f32`), join(target, `${scene}.f32`));
			copyFileSync(join(folder, `${scene}.png`), join(target, `${scene}.png`));
			writeFileSync(join(target, 'report.json'), JSON.stringify(aggregate[mode], null, 2));
		}
	}
}
const comparison = spawnSync(process.execPath, ['scripts/compare-wavefront.mjs', join(output, 'megakernel'), join(output, 'wavefront')], { cwd: root, stdio: 'inherit' });
process.exit(comparison.status ?? 1);
