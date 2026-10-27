// Correlate external NVIDIA CSV samples with completed benchmark measurement blocks.
// Clock observations explain operating conditions; they do not measure register use.
import { existsSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const [directory, utcOffset] = process.argv.slice(2);
if (!directory || !/^[+-]\d{2}:\d{2}$/.test(utcOffset ?? ''))
	throw new Error('Usage: node scripts/analyze-gpu-telemetry.mjs DIRECTORY CSV_UTC_OFFSET (e.g. +08:00)');
const root = resolve(directory);
const samples = readFileSync(join(root, 'gpu-telemetry.csv'), 'utf8').trim().split(/\r?\n/).slice(1).map(line => {
	const [timestamp, index, pstate, sm, memory, temperature, power, utilization] = line.split(',').map(v => v.trim());
	const time = Date.parse(timestamp.replaceAll('/', '-').replace(' ', 'T') + utcOffset);
	return { time, index: Number(index), pstate, sm: parseFloat(sm), memory: parseFloat(memory),
		temperature: parseFloat(temperature), power: parseFloat(power), utilization: parseFloat(utilization) };
});
if (!samples.length || samples.some(s => [s.time, s.index, s.sm, s.memory, s.temperature, s.power, s.utilization].some(v => !Number.isFinite(v))))
	throw new Error('Missing or invalid telemetry samples');
const devices = [...new Set(samples.map(s => s.index))];
if (devices.length !== 1) throw new Error('Select one GPU in the telemetry capture before correlation');
const blocks = [];
for (const entry of readdirSync(root, { withFileTypes: true })) {
	const path = join(root, entry.name, 'report.json');
	if (!entry.isDirectory() || !existsSync(path)) continue;
	const report = JSON.parse(readFileSync(path, 'utf8'));
	if (!report.completed) throw new Error(`Incomplete benchmark: ${entry.name}`);
	for (const scene of report.results) for (const repeat of scene.repeats) {
		const start = repeat.measurementStartedAt, end = repeat.measurementFinishedAt;
		if (!Number.isFinite(start) || !Number.isFinite(end) || end < start) throw new Error('Missing measurement interval');
		const observed = samples.filter(s => s.time >= start && s.time <= end);
		const range = key => observed.length ? [Math.min(...observed.map(s => s[key])), Math.max(...observed.map(s => s[key]))] : null;
		blocks.push({ scene: scene.name, variant: entry.name, repeat: repeat.repeat, start, end, spanMs: repeat.medianSpanMs,
			samples: observed.length, pstate: [...new Set(observed.map(s => s.pstate))], smMHz: range('sm'), memoryMHz: range('memory'),
			temperatureC: range('temperature'), powerW: range('power'), utilizationPercent: range('utilization') });
	}
}
if (!blocks.length) throw new Error('No measured blocks');
writeFileSync(join(root, 'telemetry-summary.json'), JSON.stringify({ utcOffset, deviceIndex: devices[0], blocks }, null, 2));
console.table(blocks.map(b => ({ scene: b.scene, variant: b.variant, round: b.repeat + 1, spanMs: b.spanMs.toFixed(3),
	samples: b.samples, smMHz: b.smMHz?.join('..') ?? 'unobserved', memoryMHz: b.memoryMHz?.join('..') ?? 'unobserved',
	temperatureC: b.temperatureC?.join('..') ?? 'unobserved' })));
