// Randomized BSDF test cases, grouped into material families that each stress one feature.
import { defaultInputs, IDENTITY_BASIS, RGB_WAVELENGTHS, type Basis, type BSDFCase, type BSDFInputs, type Vec2, type Vec3 } from './harness';

export type Random = () => number;

export function rng(seed: number): Random {
	return () => {
		seed = (seed + 0x6d2b79f5) >>> 0;
		let t = seed;
		t = Math.imul(t ^ (t >>> 15), t | 1);
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

const dot = (a: Vec3, b: Vec3) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a: Vec3, b: Vec3): Vec3 => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const scale = (a: Vec3, s: number): Vec3 => [a[0] * s, a[1] * s, a[2] * s];
const sub = (a: Vec3, b: Vec3): Vec3 => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
export const normalize = (a: Vec3): Vec3 => scale(a, 1 / Math.hypot(...a));

export function randomDirection(random: Random): Vec3 {
	const z = random() * 2 - 1;
	const phi = random() * 2 * Math.PI;
	const r = Math.sqrt(Math.max(0, 1 - z * z));
	return [r * Math.cos(phi), r * Math.sin(phi), z];
}

// Direction at a random angle from n (cos uniform in [cosMin, cosMax]).
export function directionAround(random: Random, basis: Basis, cosMin: number, cosMax: number): Vec3 {
	const z = cosMin + (cosMax - cosMin) * random();
	const phi = random() * 2 * Math.PI;
	const r = Math.sqrt(Math.max(0, 1 - z * z));
	return normalize([
		basis.t[0] * r * Math.cos(phi) + basis.b[0] * r * Math.sin(phi) + basis.n[0] * z,
		basis.t[1] * r * Math.cos(phi) + basis.b[1] * r * Math.sin(phi) + basis.n[1] * z,
		basis.t[2] * r * Math.cos(phi) + basis.b[2] * r * Math.sin(phi) + basis.n[2] * z,
	]);
}

export function randomBasis(random: Random): Basis {
	const n = randomDirection(random);
	let t = randomDirection(random);
	t = sub(t, scale(n, dot(t, n)));
	if (Math.hypot(...t) < 1e-3) {
		return randomBasis(random);
	}
	t = normalize(t);
	const b = random() < 0.2 ? cross(t, n) : cross(n, t);
	return { t, b, n };
}

function perturbedBasis(random: Random, basis: Basis, amount: number): Basis {
	const n = normalize([basis.n[0] + (random() - 0.5) * amount, basis.n[1] + (random() - 0.5) * amount, basis.n[2] + (random() - 0.5) * amount]);
	const t = normalize(sub(basis.t, scale(n, dot(basis.t, n))));
	return { t, b: cross(n, t), n };
}

const between = (random: Random, lo: number, hi: number) => lo + (hi - lo) * random();
const color = (random: Random, lo = 0, hi = 1): Vec3 => [between(random, lo, hi), between(random, lo, hi), between(random, lo, hi)];
// Edge values (0 and 1) on purpose: the BSDF branches on them.
const unit = (random: Random) => {
	const r = random();
	return r < 0.1 ? 0 : r < 0.2 ? 1 : random();
};
const maybe = (random: Random, p: number, value: () => number) => (random() < p ? value() : 0);

function rotation(random: Random): Vec2 {
	if (random() < 0.3) {
		return [1, 0];
	}
	const angle = random() * 2 * Math.PI;
	const length = between(random, 0.5, 2);
	return [Math.cos(angle) * length, Math.sin(angle) * length];
}

function specularIor(random: Random) {
	const r = random();
	return r < 0.1 ? between(random, 0.6, 1) : r < 0.2 ? between(random, 2.5, 4) : between(random, 1, 2.5);
}

export type Family = 'opaque' | 'metal' | 'glass' | 'thinWall' | 'coat' | 'fuzz' | 'thinFilm' | 'dispersion' | 'subsurface' | 'everything';
export const FAMILIES: Family[] = ['opaque', 'metal', 'glass', 'thinWall', 'coat', 'fuzz', 'thinFilm', 'dispersion', 'subsurface', 'everything'];

export function randomInputs(random: Random, family: Family): BSDFInputs {
	const i = defaultInputs();
	i.baseWeight = random() < 0.8 ? 1 : random();
	i.baseColor = color(random);
	i.baseDiffuseRoughness = unit(random);
	i.specularColor = random() < 0.6 ? [1, 1, 1] : color(random);
	i.specularWeight = random() < 0.7 ? 1 : between(random, 0, 1.5);
	i.specularRoughness = unit(random);
	i.specularRoughnessAnisotropy = maybe(random, 0.4, () => unit(random));
	i.specularIor = specularIor(random);
	i.specularAnisotropyRotation = rotation(random);
	const all = family === 'everything';
	if (family === 'metal' || (all && random() < 0.5)) {
		i.baseMetalness = family === 'metal' && random() < 0.5 ? 1 : unit(random);
	}
	if (family === 'glass' || family === 'thinWall' || family === 'dispersion' || (all && random() < 0.5)) {
		i.transmissionWeight = random() < 0.6 ? 1 : unit(random);
		i.transmissionColor = color(random, 0.2, 1);
		i.transmissionDepth = maybe(random, 0.5, () => between(random, 0.01, 3));
		i.transmissionScatter = random() < 0.5 ? [0, 0, 0] : color(random);
		i.transmissionScatterAnisotropy = between(random, -0.9, 0.9);
	}
	if (family === 'thinWall' || (all && random() < 0.3)) {
		i.geometryThinWalled = true;
	}
	if (family === 'dispersion' || (all && random() < 0.3)) {
		i.transmissionDispersionScale = unit(random);
		i.transmissionDispersionAbbeNumber = between(random, 5, 80);
	}
	if (family === 'subsurface' || (all && random() < 0.4)) {
		i.subsurfaceWeight = random() < 0.5 ? 1 : unit(random);
		i.subsurfaceColor = color(random);
		i.subsurfaceRadius = between(random, 0, 2);
		i.subsurfaceRadiusScale = color(random);
		i.subsurfaceScatterAnisotropy = between(random, -0.9, 0.9);
		if (random() < 0.3) {
			i.geometryThinWalled = true;
		}
	}
	if (family === 'coat' || (all && random() < 0.5)) {
		i.coatWeight = random() < 0.5 ? 1 : unit(random);
		i.coatColor = color(random, 0.3, 1);
		i.coatRoughness = unit(random);
		i.coatRoughnessAnisotropy = maybe(random, 0.4, () => unit(random));
		i.coatIor = between(random, 1, 2.5);
		i.coatDarkening = unit(random);
		i.coatAnisotropyRotation = rotation(random);
	}
	if (family === 'fuzz' || (all && random() < 0.5)) {
		i.fuzzWeight = random() < 0.5 ? 1 : unit(random);
		i.fuzzColor = color(random);
		i.fuzzRoughness = unit(random);
	}
	if (family === 'thinFilm' || (all && random() < 0.4)) {
		i.thinFilmWeight = random() < 0.5 ? 1 : unit(random);
		i.thinFilmThickness = random() < 0.1 ? 0 : between(random, 0, 2);
		i.thinFilmIor = between(random, 1, 2.5);
		if (random() < 0.3) {
			i.baseMetalness = unit(random);
		}
	}
	if (random() < 0.3) {
		i.emissionLuminance = between(random, 0, 10);
		i.emissionColor = color(random);
	}
	i.basis = random() < 0.2 ? IDENTITY_BASIS : randomBasis(random);
	i.coatBasis = random() < 0.7 ? i.basis : perturbedBasis(random, i.basis, 0.4);
	return i;
}

export function randomCase(random: Random, family: Family): BSDFCase {
	const inputs = randomInputs(random, family);
	// mostly outside, some grazing, some from the inside
	const r = random();
	const wo = r < 0.7 ? directionAround(random, inputs.basis, 0.02, 1) : r < 0.8 ? directionAround(random, inputs.basis, 0, 0.05) : directionAround(random, inputs.basis, -1, -0.02);
	return {
		inputs,
		wo,
		wi: randomDirection(random),
		u: [random(), random(), random()],
		throughput: random() < 0.5 ? [1, 1, 1] : color(random, 0.05, 1),
		wavelengths: random() < 0.5 ? RGB_WAVELENGTHS : [between(random, 380, 780), between(random, 380, 780), between(random, 380, 780)],
		exteriorIor: random() < 0.8 ? 1 : between(random, 1, 1.6),
	};
}
