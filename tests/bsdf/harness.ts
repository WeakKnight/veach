// Packs BSDF test cases in the layout of BSDFHarness.slang / Reference.cpp and runs them through the
// Slang port and the upstream reference (tests/generated/bsdf, built by npm run build:bsdf-harness).
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import createBSDFHarness, { type BSDFHarnessModule } from '../generated/bsdf/BSDFHarness.mjs';

export type Vec2 = [number, number];
export type Vec3 = [number, number, number];

export interface Basis {
	t: Vec3;
	b: Vec3;
	n: Vec3;
}

export interface BSDFInputs {
	baseWeight: number;
	baseColor: Vec3;
	baseDiffuseRoughness: number;
	baseMetalness: number;
	subsurfaceWeight: number;
	subsurfaceColor: Vec3;
	subsurfaceRadius: number;
	subsurfaceRadiusScale: Vec3;
	subsurfaceScatterAnisotropy: number;
	specularWeight: number;
	specularDielectricOnly?: boolean;
	specularColor: Vec3;
	specularRoughness: number;
	specularRoughnessAnisotropy: number;
	specularIor: number;
	specularAnisotropyRotation: Vec2;
	coatWeight: number;
	coatColor: Vec3;
	coatRoughness: number;
	coatRoughnessAnisotropy: number;
	coatIor: number;
	coatDarkening: number;
	coatAnisotropyRotation: Vec2;
	fuzzWeight: number;
	fuzzColor: Vec3;
	fuzzRoughness: number;
	transmissionWeight: number;
	transmissionColor: Vec3;
	transmissionDepth: number;
	transmissionScatter: Vec3;
	transmissionScatterAnisotropy: number;
	transmissionDispersionScale: number;
	transmissionDispersionAbbeNumber: number;
	thinFilmWeight: number;
	thinFilmThickness: number;
	thinFilmIor: number;
	emissionLuminance: number;
	emissionColor: Vec3;
	geometryOpacity: number;
	geometryThinWalled: boolean;
	basis: Basis;
	coatBasis: Basis;
}

export interface BSDFCase {
	inputs: BSDFInputs;
	wo: Vec3;
	wi: Vec3;
	u: Vec3;
	throughput: Vec3;
	wavelengths: Vec3;
	exteriorIor: number;
}

export interface BSDFResult {
	evalDiffuse: Vec3;
	evalSpecular: Vec3;
	pdf: number;
	sampleWi: Vec3;
	sampleDiffuse: Vec3;
	sampleSpecular: Vec3;
	samplePdf: number;
	sampleType: number;
	emission: Vec3;
	extinction: Vec3;
	albedo: Vec3;
	anisotropy: number;
	needsRGBWavelengths: boolean;
	// port only (0 from the reference): smallest GGX alpha of the specular and coat lobes
	minSpecularAlpha: number;
	minCoatAlpha: number;
}

export const CASE_FLOATS = 96;
export const RESULT_FLOATS = 32;
export const RGB_WAVELENGTHS: Vec3 = [620, 540, 450];

export const LOBE_REFLECTION = 1;
export const LOBE_TRANSMISSION = 2;
export const LOBE_DIFFUSE = 4;
export const LOBE_GLOSSY = 8;

export const IDENTITY_BASIS: Basis = { t: [1, 0, 0], b: [0, 1, 0], n: [0, 0, 1] };

export function defaultInputs(): BSDFInputs {
	return {
		baseWeight: 1,
		baseColor: [0.8, 0.8, 0.8],
		baseDiffuseRoughness: 0,
		baseMetalness: 0,
		subsurfaceWeight: 0,
		subsurfaceColor: [0.8, 0.8, 0.8],
		subsurfaceRadius: 1,
		subsurfaceRadiusScale: [1, 0.5, 0.25],
		subsurfaceScatterAnisotropy: 0,
		specularWeight: 1,
		specularColor: [1, 1, 1],
		specularRoughness: 0.3,
		specularRoughnessAnisotropy: 0,
		specularIor: 1.5,
		specularAnisotropyRotation: [1, 0],
		coatWeight: 0,
		coatColor: [1, 1, 1],
		coatRoughness: 0,
		coatRoughnessAnisotropy: 0,
		coatIor: 1.6,
		coatDarkening: 1,
		coatAnisotropyRotation: [1, 0],
		fuzzWeight: 0,
		fuzzColor: [1, 1, 1],
		fuzzRoughness: 0.5,
		transmissionWeight: 0,
		transmissionColor: [1, 1, 1],
		transmissionDepth: 0,
		transmissionScatter: [0, 0, 0],
		transmissionScatterAnisotropy: 0,
		transmissionDispersionScale: 0,
		transmissionDispersionAbbeNumber: 20,
		thinFilmWeight: 0,
		thinFilmThickness: 0.5,
		thinFilmIor: 1.4,
		emissionLuminance: 0,
		emissionColor: [1, 1, 1],
		geometryOpacity: 1,
		geometryThinWalled: false,
		basis: IDENTITY_BASIS,
		coatBasis: IDENTITY_BASIS,
	};
}

function packCase(out: Float32Array, offset: number, c: BSDFCase) {
	const i = c.inputs;
	let o = offset;
	const f = (v: number) => {
		out[o++] = v;
	};
	const v = (values: readonly number[]) => values.forEach(f);
	const basis = (b: Basis) => {
		v(b.t);
		v(b.b);
		v(b.n);
	};
	f(i.baseWeight);
	v(i.baseColor);
	f(i.baseDiffuseRoughness);
	f(i.baseMetalness);
	f(i.subsurfaceWeight);
	v(i.subsurfaceColor);
	f(i.subsurfaceRadius);
	v(i.subsurfaceRadiusScale);
	f(i.subsurfaceScatterAnisotropy);
	f(i.specularWeight);
	v(i.specularColor);
	f(i.specularRoughness);
	f(i.specularRoughnessAnisotropy);
	f(i.specularIor);
	v(i.specularAnisotropyRotation);
	f(i.coatWeight);
	v(i.coatColor);
	f(i.coatRoughness);
	f(i.coatRoughnessAnisotropy);
	f(i.coatIor);
	f(i.coatDarkening);
	v(i.coatAnisotropyRotation);
	f(i.fuzzWeight);
	v(i.fuzzColor);
	f(i.fuzzRoughness);
	f(i.transmissionWeight);
	v(i.transmissionColor);
	f(i.transmissionDepth);
	v(i.transmissionScatter);
	f(i.transmissionScatterAnisotropy);
	f(i.transmissionDispersionScale);
	f(i.transmissionDispersionAbbeNumber);
	f(i.thinFilmWeight);
	f(i.thinFilmThickness);
	f(i.thinFilmIor);
	f(i.emissionLuminance);
	v(i.emissionColor);
	f(i.geometryOpacity);
	f(i.geometryThinWalled ? 1 : 0);
	basis(i.basis);
	basis(i.coatBasis);
	v(c.wo);
	v(c.wi);
	v(c.u);
	v(c.throughput);
	v(c.wavelengths);
	f(c.exteriorIor);
	f(i.specularDielectricOnly ? 1 : 0);
	if (o - offset > CASE_FLOATS) {
		throw new Error('case layout overflow');
	}
}

function unpackResult(r: Float32Array, offset: number): BSDFResult {
	const v3 = (k: number): Vec3 => [r[offset + k], r[offset + k + 1], r[offset + k + 2]];
	return {
		evalDiffuse: v3(0),
		evalSpecular: v3(3),
		pdf: r[offset + 6],
		sampleWi: v3(7),
		sampleDiffuse: v3(10),
		sampleSpecular: v3(13),
		samplePdf: r[offset + 16],
		sampleType: r[offset + 17],
		emission: v3(18),
		extinction: v3(21),
		albedo: v3(24),
		anisotropy: r[offset + 27],
		needsRGBWavelengths: r[offset + 28] !== 0,
		minSpecularAlpha: r[offset + 29],
		minCoatAlpha: r[offset + 30],
	};
}

export class BSDFHarness {
	private constructor(
		private readonly module: BSDFHarnessModule,
		private readonly tables: number,
	) {}

	static async create(root: string): Promise<BSDFHarness> {
		const module = await createBSDFHarness();
		const bytes = readFileSync(join(root, 'src', 'generated', 'bsdf', 'BSDFTables.bin'));
		const tables = module._malloc(bytes.byteLength);
		new Uint8Array(module.HEAPF32.buffer, tables, bytes.byteLength).set(bytes);
		return new BSDFHarness(module, tables);
	}

	reference(cases: readonly BSDFCase[]): BSDFResult[] {
		return this.run(cases, (c, r, n) => this.module._RunReference(c, r, n));
	}

	port(cases: readonly BSDFCase[]): BSDFResult[] {
		return this.run(cases, (c, r, n) => this.module._RunPort(c, r, n, this.tables));
	}

	private run(cases: readonly BSDFCase[], fn: (cases: number, results: number, count: number) => void): BSDFResult[] {
		const m = this.module;
		const casePtr = m._malloc(cases.length * CASE_FLOATS * 4);
		const resultPtr = m._malloc(cases.length * RESULT_FLOATS * 4);
		try {
			const packed = new Float32Array(cases.length * CASE_FLOATS);
			cases.forEach((c, n) => packCase(packed, n * CASE_FLOATS, c));
			m.HEAPF32.set(packed, casePtr / 4);
			fn(casePtr, resultPtr, cases.length);
			const results = m.HEAPF32.slice(resultPtr / 4, resultPtr / 4 + cases.length * RESULT_FLOATS);
			return cases.map((_, n) => unpackResult(results, n * RESULT_FLOATS));
		} finally {
			m._free(casePtr);
			m._free(resultPtr);
		}
	}
}
