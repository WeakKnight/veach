// Differential tests of the BSDF (shaders/Materials/BSDF, compiled to C++) against the upstream
// reference it was ported from (ThirdParty/openpbr-bsdf), on randomized material families, plus
// white-furnace energy tests. Rebuild the harness with npm run build:bsdf-harness.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { beforeAll, describe, expect, it } from 'vitest';
import { bsdfHarnessSourceHash } from '../scripts/bsdf-harness-sources.mjs';
import { FAMILIES, randomCase, rng, type Family } from './bsdf/cases';
import { BSDFHarness, defaultInputs, IDENTITY_BASIS, RGB_WAVELENGTHS, type BSDFCase, type BSDFInputs, type BSDFResult, type Vec3 } from './bsdf/harness';

const root = fileURLToPath(new URL('..', import.meta.url));
const CASES_PER_FAMILY = 4000;

// Sampled values of lobes this sharp are ill-conditioned (a last-bit change of the half vector
// moves the pdf by orders of magnitude, in either implementation); only their direction and type
// are compared.
const MIN_CONDITIONED_ALPHA = 1e-2;

let harness: BSDFHarness;

beforeAll(async () => {
	harness = await BSDFHarness.create(root);
});

// Relative to the largest component: colors may have near-zero channels.
function close(a: readonly number[], b: readonly number[], rtol: number, atol: number) {
	const scale = Math.max(...a.map(Math.abs), ...b.map(Math.abs));
	return a.every((x, j) => Math.abs(x - b[j]) <= atol + rtol * scale);
}

const add = (a: Vec3, b: Vec3): Vec3 => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];

interface Mismatch {
	field: string;
	index: number;
	port: number[];
	reference: number[];
}

class Checker {
	readonly mismatches: Mismatch[] = [];
	checked = 0;

	vec(field: string, index: number, port: readonly number[], reference: readonly number[], rtol: number, atol: number) {
		this.checked++;
		if (!close(port, reference, rtol, atol)) {
			this.mismatches.push({ field, index, port: [...port], reference: [...reference] });
		}
	}

	expectClean(family: Family) {
		expect(this.mismatches.slice(0, 5), `${family}: ${this.mismatches.length} of ${this.checked} values differ`).toEqual([]);
	}
}

describe('glTF dielectric-only specular controls', () => {
	const make = (metalness: number, weight: number, color: Vec3, gltf = true, coat = 0): BSDFCase => ({
		inputs: { ...defaultInputs(), baseColor: [0.92, 0.75, 0.4], baseMetalness: metalness,
			specularWeight: weight, specularColor: color, specularDielectricOnly: gltf,
			specularRoughness: 0.3, coatWeight: coat, coatIor: 1.5, coatRoughness: 0.15 },
		wo: [0.6, 0, 0.8], wi: [-0.6, 0, 0.8], u: [0.25, 0.4, 0.6],
		throughput: [1, 1, 1], wavelengths: RGB_WAVELENGTHS, exteriorIor: 1,
	});
	it('keeps pure metal reflection and sampling independent of specular factor/color, including under a coat', () => {
		for (const coat of [0, 1]) {
			const baseline = harness.port([make(1, 1, [1, 1, 1], false, coat)])[0];
			for (const weight of [0, 0.2, 1]) {
				const result = harness.port([make(1, weight, [0.1, 0.5, 0.9], true, coat)])[0];
				expect(result).toEqual(baseline);
				expect(Math.max(...result.evalSpecular)).toBeGreaterThan(0);
			}
		}
	});
	it('preserves dielectric behavior and native OpenPBR metal darkening', () => {
		for (const weight of [0, 0.2, 1]) {
			expect(harness.port([make(0, weight, [0.2, 0.5, 0.9])])[0])
				.toEqual(harness.port([make(0, weight, [0.2, 0.5, 0.9], false)])[0]);
		}
		expect(harness.port([make(1, 0, [1, 1, 1], false)])[0].evalSpecular).toEqual([0, 0, 0]);
	});
	it('keeps the correct metal and dielectric contributions at fractional metalness', () => {
		for (const weight of [0, 0.2, 1]) {
			const metal = harness.port([make(1, 1, [1, 1, 1], false)])[0];
			const dielectric = harness.port([make(0, weight, [0.2, 0.5, 0.9], false)])[0];
			for (const m of [0.1, 0.5, 0.9]) {
				const result = harness.port([make(m, weight, [0.2, 0.5, 0.9])])[0];
				for (const field of ['evalSpecular', 'evalDiffuse'] as const) {
					for (let c = 0; c < 3; c++) expect(result[field][c]).toBeCloseTo(m * metal[field][c] + (1 - m) * dielectric[field][c], 5);
				}
			}
		}
	});
});

describe('BSDF harness', () => {
	it('is built from the current sources', () => {
		const built = JSON.parse(readFileSync(join(root, 'tests', 'generated', 'bsdf', 'BSDFHarness.json'), 'utf8')).sourceHash;
		expect(built, 'stale BSDF harness: run npm run build:bsdf-harness').toBe(bsdfHarnessSourceHash(root));
	});
});

describe.each(FAMILIES)('BSDF matches the reference: %s', (family) => {
	let cases: BSDFCase[];
	let port: BSDFResult[];
	let reference: BSDFResult[];

	beforeAll(() => {
		const random = rng(0x5eed + FAMILIES.indexOf(family));
		cases = Array.from({ length: CASES_PER_FAMILY }, () => randomCase(random, family));
		port = harness.port(cases);
		reference = harness.reference(cases);
	});

	it('prepares the same volume, emission and wavelength needs', () => {
		const check = new Checker();
		port.forEach((p, n) => {
			const r = reference[n];
			check.vec('emission', n, p.emission, r.emission, 2e-5, 0);
			check.vec('extinction', n, p.extinction, r.extinction, 1e-6, 0);
			check.vec('albedo', n, p.albedo, r.albedo, 1e-6, 0);
			check.vec('anisotropy', n, [p.anisotropy], [r.anisotropy], 1e-6, 0);
			check.vec('needsRGBWavelengths', n, [+p.needsRGBWavelengths], [+r.needsRGBWavelengths], 0, 0);
		});
		check.expectClean(family);
	});

	it('evaluates the same value and pdf', () => {
		const check = new Checker();
		port.forEach((p, n) => {
			const r = reference[n];
			check.vec('evalDiffuse', n, p.evalDiffuse, r.evalDiffuse, 1e-4, 1e-7);
			check.vec('evalSpecular', n, p.evalSpecular, r.evalSpecular, 1e-4, 1e-7);
			check.vec('pdf', n, [p.pdf], [r.pdf], 1e-4, 1e-7);
		});
		check.expectClean(family);
	});

	it('samples the same lobe and direction', () => {
		const check = new Checker();
		port.forEach((p, n) => {
			const r = reference[n];
			check.vec('sampleType', n, [p.sampleType], [r.sampleType], 0, 0);
			if (p.sampleType === r.sampleType && p.samplePdf > 0) {
				// u.x picks the lobe and is remapped by its probability, which amplifies rounding ~1000x
				check.vec('sampleWi', n, p.sampleWi, r.sampleWi, 0, 1e-3);
			}
		});
		// lobe selection may flip right at a probability boundary
		const flips = check.mismatches.filter((m) => m.field === 'sampleType').length;
		expect(flips, `${family}: lobe selection differs`).toBeLessThanOrEqual(CASES_PER_FAMILY * 1e-3);
		expect(check.mismatches.filter((m) => m.field !== 'sampleType').slice(0, 5)).toEqual([]);
	});

	it('samples weights and pdfs consistent with the reference', () => {
		// Compare at the port's direction so diverging directions do not count.
		const atPortWi = harness.reference(cases.map((c, n) => ({ ...c, wi: port[n].samplePdf > 0 ? port[n].sampleWi : c.wi })));
		const check = new Checker();
		port.forEach((p, n) => {
			const r = reference[n];
			if (p.samplePdf <= 0 || p.sampleType !== r.sampleType || Math.min(p.minSpecularAlpha, p.minCoatAlpha) < MIN_CONDITIONED_ALPHA) {
				return;
			}
			check.vec('samplePdf', n, [p.samplePdf], [r.samplePdf], 2e-3, 1e-6);
			check.vec('sampleWeight', n, [...p.sampleDiffuse, ...p.sampleSpecular], [...r.sampleDiffuse, ...r.sampleSpecular], 2e-3, 1e-6);
			const f = add(p.sampleDiffuse, p.sampleSpecular).map((w) => w * p.samplePdf);
			check.vec('samplePdfAtWi', n, [p.samplePdf], [atPortWi[n].pdf], 2e-3, 1e-6);
			check.vec('sampleValueAtWi', n, f, add(atPortWi[n].evalDiffuse, atPortWi[n].evalSpecular), 2e-3, 1e-6);
		});
		check.expectClean(family);
	});
});

function radicalInverse(k: number, base: number) {
	let result = 0;
	for (let f = 1 / base; k > 0; k = Math.floor(k / base), f /= base) {
		result += (k % base) * f;
	}
	return result;
}

// Mean sample weight (the directional albedo) at view angle cosTheta, from a Halton sequence.
function furnace(impl: 'port' | 'reference', inputs: BSDFInputs, cosTheta: number, n = 8192) {
	const sinTheta = Math.sqrt(1 - cosTheta * cosTheta);
	const cases: BSDFCase[] = Array.from({ length: n }, (_, k) => ({
		inputs,
		wo: [sinTheta, 0, cosTheta],
		wi: [0, 0, 1],
		u: [(k + 0.5) / n, radicalInverse(k, 2), radicalInverse(k, 3)],
		throughput: [1, 1, 1],
		wavelengths: RGB_WAVELENGTHS,
		exteriorIor: 1,
	}));
	let total = 0;
	for (const r of harness[impl](cases)) {
		if (r.samplePdf > 0) {
			total += (r.sampleDiffuse[1] + r.sampleSpecular[1]);
		}
	}
	return total / n;
}

const white = (patch: Partial<BSDFInputs>): BSDFInputs => ({
	...defaultInputs(),
	baseColor: [1, 1, 1],
	basis: IDENTITY_BASIS,
	coatBasis: IDENTITY_BASIS,
	...patch,
});

// White, non-absorbing configurations: the layering conserves and preserves energy.
const LOSSLESS: Record<string, (roughness: number) => BSDFInputs> = {
	metal: (r) => white({ baseMetalness: 1, specularRoughness: r }),
	diffuse: (r) => white({ specularWeight: 0, baseDiffuseRoughness: r }),
	dielectricOverDiffuse: (r) => white({ specularRoughness: r, baseDiffuseRoughness: r }),
	glass: (r) => white({ transmissionWeight: 1, specularRoughness: r }),
	coatOverDielectric: (r) => white({ specularRoughness: r, coatWeight: 1, coatRoughness: r }),
	coatOverMetal: (r) => white({ baseMetalness: 1, specularRoughness: r, coatWeight: 1, coatRoughness: 0.2 }),
	fuzzOverDielectric: (r) => white({ specularRoughness: r, fuzzWeight: 1, fuzzRoughness: r }),
};

// Thin walls approximate: rough window transmission loses energy, white thin-wall subsurface gains
// it (both as in the reference); only parity is checked.
const APPROXIMATE: Record<string, (roughness: number) => BSDFInputs> = {
	thinWallGlass: (r) => white({ transmissionWeight: 1, specularRoughness: r, geometryThinWalled: true }),
	thinWallSubsurface: (r) => white({ subsurfaceWeight: 1, subsurfaceColor: [1, 1, 1], specularRoughness: r, geometryThinWalled: true }),
};

describe('BSDF white furnace', () => {
	const angles = [0.2, 0.6, 1];
	const roughnesses = [0.1, 0.5, 0.9];

	it.each(Object.entries(LOSSLESS))('%s reflects and transmits all energy', (_, make) => {
		for (const roughness of roughnesses) {
			for (const cosTheta of angles) {
				const albedo = furnace('port', make(roughness), cosTheta);
				expect(albedo, `roughness ${roughness}, cos ${cosTheta}`).toBeCloseTo(1, 1.7);
				expect(Math.abs(albedo - furnace('reference', make(roughness), cosTheta))).toBeLessThan(1e-5);
			}
		}
	});

	it.each(Object.entries(APPROXIMATE))('%s matches the reference albedo', (_, make) => {
		for (const roughness of roughnesses) {
			for (const cosTheta of angles) {
				const albedo = furnace('port', make(roughness), cosTheta);
				expect(Math.abs(albedo - furnace('reference', make(roughness), cosTheta)), `roughness ${roughness}, cos ${cosTheta}`).toBeLessThan(1e-5);
			}
		}
	});
});
