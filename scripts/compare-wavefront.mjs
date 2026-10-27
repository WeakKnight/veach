// Compare saved linear HDR captures and repeated GPU timings. No tone mapping or denoising.
import { readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const [referencePath, candidatePath] = process.argv.slice(2);
if (!referencePath || !candidatePath) throw new Error('Usage: node scripts/compare-wavefront.mjs REFERENCE CANDIDATE');
const reference = JSON.parse(readFileSync(join(referencePath, 'report.json'), 'utf8'));
const candidate = JSON.parse(readFileSync(join(candidatePath, 'report.json'), 'utf8'));
for (const key of ['width', 'height', 'samples', 'bounces']) {
	if (reference.config[key] !== candidate.config[key]) throw new Error(`Mismatched ${key}`);
}
if ((reference.config.clamp ?? 0) !== (candidate.config.clamp ?? 0)) throw new Error('Mismatched firefly clamp');
const median = values => [...values].sort((a, b) => a - b)[Math.floor(values.length / 2)];
const results = [];
for (const c of candidate.results) {
	const r = reference.results.find(r => r.name === c.name);
	if (!r || r.sha256 !== c.sha256 || JSON.stringify(r.camera) !== JSON.stringify(c.camera)) throw new Error(`Mismatched input for ${c.name}`);
	const rb = readFileSync(join(referencePath, `${c.name}.f32`));
	const cb = readFileSync(join(candidatePath, `${c.name}.f32`));
	if (rb.length !== cb.length) throw new Error(`Mismatched HDR size for ${c.name}`);
	const a = new Float32Array(rb.buffer, rb.byteOffset, rb.length / 4);
	const b = new Float32Array(cb.buffer, cb.byteOffset, cb.length / 4);
	let sumSquared = 0, refSquared = 0, sumAbs = 0, maxAbs = 0, changed = 0, refSum = 0, candidateSum = 0;
	const errors = new Float32Array(a.length);
	for (let i = 0; i < a.length; i++) {
		if (!Number.isFinite(a[i]) || !Number.isFinite(b[i])) throw new Error(`Nonfinite HDR in ${c.name}`);
		const e = Math.abs(a[i] - b[i]);
		errors[i] = e;
		sumSquared += e * e; refSquared += a[i] * a[i]; sumAbs += e; maxAbs = Math.max(e, maxAbs);
		if (e > 1e-6) changed++;
		refSum += a[i]; candidateSum += b[i];
	}
	errors.sort();
	const referenceMs = median(r.repeats.map(x => x.medianMs)), candidateMs = median(c.repeats.map(x => x.medianMs));
	const referenceSpanMs = median(r.repeats.map(x => x.medianSpanMs ?? x.medianMs));
	const candidateSpanMs = median(c.repeats.map(x => x.medianSpanMs ?? x.medianMs));
	const result = { name: c.name, referenceMs, candidateMs, speedup: referenceMs / candidateMs,
		referenceSpanMs, candidateSpanMs, spanSpeedup: referenceSpanMs / candidateSpanMs,
		rmse: Math.sqrt(sumSquared / a.length), relativeL2: Math.sqrt(sumSquared / Math.max(refSquared, 1e-30)),
		meanAbsoluteError: sumAbs / a.length, p99AbsoluteError: errors[Math.floor(errors.length * 0.99)], maxAbsoluteError: maxAbs,
		changedFraction: changed / a.length, meanRatio: candidateSum / refSum };
	results.push(result);
	console.log(JSON.stringify(result));
}
writeFileSync(join(candidatePath, 'comparison.json'), JSON.stringify({ reference: resolve(referencePath), candidate: resolve(candidatePath), results }, null, 2));
