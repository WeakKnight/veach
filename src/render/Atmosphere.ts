// Physically based sky after Hillaire 2020, "A Scalable and Production Ready Sky and Atmosphere
// Rendering Technique": transmittance, multiple-scattering and sky-view LUTs, and the sky-view LUT
// resampled into an equirect environment map. This is the CPU reference for the GPU bake in
// shaders/Passes/Atmosphere.slang (keep them in sync; tests run against this one); the renderer
// only uses sunTransmittance from here. Distances are in megameters, coefficients per megameter.
// The viewer sits 200 m above a planet with Earth-like Rayleigh, Mie and ozone layers.
import type { HDRImage } from '../loaders/HDRLoader';
import type { Vec3 } from '../math/Math';

const GROUND_RADIUS = 6.36;
const ATMOSPHERE_RADIUS = 6.46;
const VIEW_RADIUS = GROUND_RADIUS + 0.0002;
const GROUND_ALBEDO = 0.3;

const RAYLEIGH_SCATTERING = [5.802, 13.558, 33.1];
const MIE_SCATTERING = 3.996;
const MIE_ABSORPTION = 4.4;
const OZONE_ABSORPTION = [0.65, 1.881, 0.085];
const MIE_G = 0.8;

const TRANSMITTANCE_STEPS = 40;
const MULTI_SCATTERING_STEPS = 20;
const MULTI_SCATTERING_SQRT_DIRECTIONS = 8;
const SKY_VIEW_STEPS = 32;

export const TRANSMITTANCE_LUT_SIZE = [256, 64] as const;
export const MULTI_SCATTERING_LUT_SIZE = [32, 32] as const;
export const SKY_VIEW_LUT_SIZE = [200, 200] as const;

// RGB float texels, row-major.
export interface AtmosphereLut {
	width: number;
	height: number;
	data: Float32Array;
}

const PI = Math.PI;
const HALF_PI = PI / 2;
const ISOTROPIC_PHASE = 1 / (4 * PI);

function rayleighPhase(cosTheta: number): number {
	return (3 / (16 * PI)) * (1 + cosTheta * cosTheta);
}

// Cornette-Shanks
function miePhase(cosTheta: number): number {
	const g2 = MIE_G * MIE_G;
	const num = (1 - g2) * (1 + cosTheta * cosTheta);
	const denom = (2 + g2) * Math.pow(1 + g2 - 2 * MIE_G * cosTheta, 1.5);
	return ((3 / (8 * PI)) * num) / denom;
}

// [rayleigh scattering rgb, mie scattering, extinction rgb] at radius r, written by sampleMedium.
const medium = new Float64Array(7);

function sampleMedium(r: number): void {
	const altitudeKm = Math.max(0, (r - GROUND_RADIUS) * 1000);
	const rayleigh = Math.exp(-altitudeKm / 8);
	const mie = Math.exp(-altitudeKm / 1.2);
	const ozone = Math.max(0, 1 - Math.abs(altitudeKm - 25) / 15);
	const mieExtinction = (MIE_SCATTERING + MIE_ABSORPTION) * mie;
	for (let c = 0; c < 3; c++) {
		const rs = RAYLEIGH_SCATTERING[c] * rayleigh;
		medium[c] = rs;
		medium[4 + c] = rs + mieExtinction + OZONE_ABSORPTION[c] * ozone;
	}
	medium[3] = MIE_SCATTERING * mie;
}

// Distance along a unit ray to a sphere around the planet center: the nearest hit from outside,
// the exit from inside, -1 on a miss.
function intersectSphere(ox: number, oy: number, oz: number, dx: number, dy: number, dz: number, radius: number): number {
	const b = ox * dx + oy * dy + oz * dz;
	const c = ox * ox + oy * oy + oz * oz - radius * radius;
	if (c > 0 && b > 0) return -1;
	const disc = b * b - c;
	if (disc < 0) return -1;
	return disc > b * b ? -b + Math.sqrt(disc) : -b - Math.sqrt(disc);
}

// End of march segment s of n. Quadratic spacing concentrates steps near the start of the ray,
// where the thin Mie layer (1.2 km scale height) lives for rays leaving the ground.
function marchEnd(s: number, n: number, tMax: number): number {
	const x = (s + 1) / n;
	return x * x * tMax;
}

function sampleLut(lut: AtmosphereLut, u: number, v: number, out: Float64Array, offset = 0): void {
	const { width: w, height: h, data } = lut;
	const x = Math.min(Math.max(u * w - 0.5, 0), w - 1);
	const y = Math.min(Math.max(v * h - 0.5, 0), h - 1);
	const x0 = Math.floor(x);
	const y0 = Math.floor(y);
	const x1 = Math.min(x0 + 1, w - 1);
	const y1 = Math.min(y0 + 1, h - 1);
	const fx = x - x0;
	const fy = y - y0;
	const i00 = (y0 * w + x0) * 3;
	const i10 = (y0 * w + x1) * 3;
	const i01 = (y1 * w + x0) * 3;
	const i11 = (y1 * w + x1) * 3;
	for (let c = 0; c < 3; c++) {
		const top = data[i00 + c] + (data[i10 + c] - data[i00 + c]) * fx;
		const bottom = data[i01 + c] + (data[i11 + c] - data[i01 + c]) * fx;
		out[offset + c] = top + (bottom - top) * fy;
	}
}

// Transmittance and multiple-scattering LUTs share the (cos sun zenith, altitude) parameterization;
// v = sqrt(altitude fraction) puts the lowest row ~6 m up, where the dense Mie layer needs it.
function sampleAltitudeLut(lut: AtmosphereLut, r: number, cosSunZenith: number, out: Float64Array, offset = 0): void {
	const u = 0.5 + 0.5 * cosSunZenith;
	const v = Math.sqrt(Math.max(0, (r - GROUND_RADIUS) / (ATMOSPHERE_RADIUS - GROUND_RADIUS)));
	sampleLut(lut, u, v, out, offset);
}

function texelToAltitudeParams(x: number, y: number, w: number, h: number): { r: number; cosSun: number; sinSun: number } {
	const cosSun = 2 * ((x + 0.5) / w) - 1;
	const v = (y + 0.5) / h;
	const r = GROUND_RADIUS + v * v * (ATMOSPHERE_RADIUS - GROUND_RADIUS);
	return { r, cosSun, sinSun: Math.sqrt(Math.max(0, 1 - cosSun * cosSun)) };
}

// Transmittance from radius r along a direction with the given zenith cosine to the top of the
// atmosphere; zero when the planet blocks it.
function transmittanceToTop(r: number, cosZenith: number, out: Float64Array | Float32Array, offset: number): void {
	const sinZenith = Math.sqrt(Math.max(0, 1 - cosZenith * cosZenith));
	if (intersectSphere(0, r, 0, 0, cosZenith, -sinZenith, GROUND_RADIUS) > 0) {
		out[offset] = out[offset + 1] = out[offset + 2] = 0;
		return;
	}
	const tMax = intersectSphere(0, r, 0, 0, cosZenith, -sinZenith, ATMOSPHERE_RADIUS);
	let d0 = 0;
	let d1 = 0;
	let d2 = 0;
	let t0 = 0;
	for (let s = 0; s < TRANSMITTANCE_STEPS; s++) {
		const t1 = marchEnd(s, TRANSMITTANCE_STEPS, tMax);
		const dt = t1 - t0;
		const t = t0 + 0.5 * dt;
		t0 = t1;
		sampleMedium(Math.hypot(r + t * cosZenith, t * sinZenith));
		d0 += dt * medium[4];
		d1 += dt * medium[5];
		d2 += dt * medium[6];
	}
	out[offset] = Math.exp(-d0);
	out[offset + 1] = Math.exp(-d1);
	out[offset + 2] = Math.exp(-d2);
}

export function buildTransmittanceLut(): AtmosphereLut {
	const [w, h] = TRANSMITTANCE_LUT_SIZE;
	const data = new Float32Array(w * h * 3);
	for (let y = 0; y < h; y++) {
		for (let x = 0; x < w; x++) {
			const { r, cosSun } = texelToAltitudeParams(x, y, w, h);
			transmittanceToTop(r, cosSun, data, (y * w + x) * 3);
		}
	}
	return { width: w, height: h, data };
}

const scratch = new Float64Array(6);

// Lambertian ground lit by the attenuated sun, per unit sun illuminance.
function groundRadiance(transmittance: AtmosphereLut, px: number, py: number, pz: number, sx: number, sy: number, sz: number, out: Float64Array): void {
	const r = Math.hypot(px, py, pz);
	const cosSun = (px * sx + py * sy + pz * sz) / r;
	if (cosSun <= 0) {
		out[0] = out[1] = out[2] = 0;
		return;
	}
	sampleAltitudeLut(transmittance, GROUND_RADIUS, cosSun, out);
	const k = (GROUND_ALBEDO / PI) * cosSun;
	out[0] *= k;
	out[1] *= k;
	out[2] *= k;
}

// Psi_ms (paper Eq. 10): second-order luminance with an isotropic phase, divided by 1 - f_ms.
export function buildMultiScatteringLut(transmittance: AtmosphereLut): AtmosphereLut {
	const [w, h] = MULTI_SCATTERING_LUT_SIZE;
	const data = new Float32Array(w * h * 3);
	const n = MULTI_SCATTERING_SQRT_DIRECTIONS;
	const invDirections = 1 / (n * n);
	const lum = new Float64Array(3);
	const fms = new Float64Array(3);
	const tr = new Float64Array(3);
	for (let y = 0; y < h; y++) {
		for (let x = 0; x < w; x++) {
			const { r, cosSun, sinSun } = texelToAltitudeParams(x, y, w, h);
			const sy = cosSun;
			const sz = -sinSun;
			lum.fill(0);
			fms.fill(0);
			// symmetric about the sun plane, so half the azimuths suffice
			for (let i = 0; i < n; i++) {
				const theta = (PI * (i + 0.5)) / n;
				for (let j = 0; j < n; j++) {
					const cosPhi = 1 - (2 * (j + 0.5)) / n;
					const sinPhi = Math.sqrt(1 - cosPhi * cosPhi);
					const dx = sinPhi * Math.sin(theta);
					const dy = cosPhi;
					const dz = sinPhi * Math.cos(theta);
					const groundDist = intersectSphere(0, r, 0, dx, dy, dz, GROUND_RADIUS);
					const tMax = groundDist > 0 ? groundDist : intersectSphere(0, r, 0, dx, dy, dz, ATMOSPHERE_RADIUS);
					let t0 = 0;
					tr.fill(1);
					for (let s = 0; s < MULTI_SCATTERING_STEPS; s++) {
						const t1 = marchEnd(s, MULTI_SCATTERING_STEPS, tMax);
						const dt = t1 - t0;
						const t = t0 + 0.5 * dt;
						t0 = t1;
						const px = t * dx;
						const py = r + t * dy;
						const pz = t * dz;
						const pr = Math.hypot(px, py, pz);
						sampleMedium(pr);
						sampleAltitudeLut(transmittance, pr, (py * sy + pz * sz) / pr, scratch);
						for (let c = 0; c < 3; c++) {
							const ext = medium[4 + c];
							const segment = Math.exp(-dt * ext);
							const scattering = medium[c] + medium[3];
							const integral = (1 - segment) / ext;
							fms[c] += tr[c] * scattering * integral * invDirections;
							lum[c] += tr[c] * scattering * ISOTROPIC_PHASE * scratch[c] * integral * invDirections;
							tr[c] *= segment;
						}
					}
					if (groundDist > 0) {
						groundRadiance(transmittance, groundDist * dx, r + groundDist * dy, groundDist * dz, 0, sy, sz, scratch);
						for (let c = 0; c < 3; c++) lum[c] += tr[c] * scratch[c] * invDirections;
					}
				}
			}
			const k = (y * w + x) * 3;
			for (let c = 0; c < 3; c++) {
				data[k + c] = lum[c] / (1 - fms[c]);
			}
		}
	}
	return { width: w, height: h, data };
}

// Altitude of the geometric horizon seen from the viewer (slightly below 0).
const HORIZON_ALTITUDE = -Math.acos(GROUND_RADIUS / VIEW_RADIUS);

// Sky-view v is quadratic in altitude on either side of the horizon (paper Section 5.3).
function skyViewVToAltitude(v: number): number {
	if (v >= 0.5) {
		const c = 2 * v - 1;
		return HORIZON_ALTITUDE + (HALF_PI - HORIZON_ALTITUDE) * c * c;
	}
	const c = 1 - 2 * v;
	return HORIZON_ALTITUDE - (HALF_PI + HORIZON_ALTITUDE) * c * c;
}

function altitudeToSkyViewV(altitude: number): number {
	if (altitude >= HORIZON_ALTITUDE) {
		return 0.5 + 0.5 * Math.sqrt(Math.min(1, (altitude - HORIZON_ALTITUDE) / (HALF_PI - HORIZON_ALTITUDE)));
	}
	return 0.5 - 0.5 * Math.sqrt(Math.min(1, (HORIZON_ALTITUDE - altitude) / (HALF_PI + HORIZON_ALTITUDE)));
}

// Sky luminance per unit sun illuminance as seen from the viewer: u is the azimuth relative to the
// sun (0.5 = toward it), v the remapped altitude. Single scattering + Psi_ms; the ground below the
// horizon is Lambertian, lit by the attenuated sun and by the sky irradiance integrated from the
// rows above the horizon (built first, top down).
export function buildSkyViewLut(transmittance: AtmosphereLut, multiScattering: AtmosphereLut, sunElevation: number): AtmosphereLut {
	const [w, h] = SKY_VIEW_LUT_SIZE;
	const data = new Float32Array(w * h * 3);
	const sy = Math.sin(sunElevation);
	const sz = -Math.cos(sunElevation);
	const lum = new Float64Array(3);
	const tr = new Float64Array(3);
	const skyIrradiance = new Float64Array(3);
	for (let y = h - 1; y >= 0; y--) {
		const altitude = skyViewVToAltitude((y + 0.5) / h);
		const cosAlt = Math.cos(altitude);
		const dy = Math.sin(altitude);
		for (let x = 0; x < w; x++) {
			const azimuth = ((x + 0.5) / w - 0.5) * 2 * PI;
			const dx = cosAlt * Math.sin(azimuth);
			const dz = -cosAlt * Math.cos(azimuth);
			const cosTheta = dy * sy + dz * sz;
			const phaseR = rayleighPhase(cosTheta);
			const phaseM = miePhase(cosTheta);
			const groundDist = intersectSphere(0, VIEW_RADIUS, 0, dx, dy, dz, GROUND_RADIUS);
			const tMax = groundDist > 0 ? groundDist : intersectSphere(0, VIEW_RADIUS, 0, dx, dy, dz, ATMOSPHERE_RADIUS);
			lum.fill(0);
			tr.fill(1);
			let t0 = 0;
			for (let s = 0; s < SKY_VIEW_STEPS; s++) {
				const t1 = marchEnd(s, SKY_VIEW_STEPS, tMax);
				const dt = t1 - t0;
				const t = t0 + 0.5 * dt;
				t0 = t1;
				const px = t * dx;
				const py = VIEW_RADIUS + t * dy;
				const pz = t * dz;
				const pr = Math.hypot(px, py, pz);
				const cosSun = (py * sy + pz * sz) / pr;
				sampleMedium(pr);
				sampleAltitudeLut(transmittance, pr, cosSun, scratch, 0);
				sampleAltitudeLut(multiScattering, pr, cosSun, scratch, 3);
				for (let c = 0; c < 3; c++) {
					const ext = medium[4 + c];
					const segment = Math.exp(-dt * ext);
					const inScattering = medium[c] * (phaseR * scratch[c] + scratch[3 + c]) + medium[3] * (phaseM * scratch[c] + scratch[3 + c]);
					lum[c] += (tr[c] * inScattering * (1 - segment)) / ext;
					tr[c] *= segment;
				}
			}
			if (groundDist > 0) {
				groundRadiance(transmittance, groundDist * dx, VIEW_RADIUS + groundDist * dy, groundDist * dz, 0, sy, sz, scratch);
				for (let c = 0; c < 3; c++) lum[c] += tr[c] * (scratch[c] + (GROUND_ALBEDO / PI) * skyIrradiance[c]);
			}
			const k = (y * w + x) * 3;
			data[k] = lum[0];
			data[k + 1] = lum[1];
			data[k + 2] = lum[2];
		}
		if (y >= h / 2) {
			// row solid angle times cos to the up normal
			const dAltitude = skyViewVToAltitude((y + 1) / h) - skyViewVToAltitude(y / h);
			const weight = Math.max(0, dy) * cosAlt * dAltitude * ((2 * PI) / w);
			for (let x = 0; x < w; x++) {
				const k = (y * w + x) * 3;
				for (let c = 0; c < 3; c++) skyIrradiance[c] += data[k + c] * weight;
			}
		}
	}
	return { width: w, height: h, data };
}

// Transmittance from the viewer toward the sun (unit vector, +Y up); attenuates the sun light.
export function sunTransmittance(sunDir: Vec3): Vec3 {
	const out = new Float64Array(3);
	transmittanceToTop(VIEW_RADIUS, sunDir[1], out, 0);
	return [out[0], out[1], out[2]];
}

// Owns the sun-independent LUTs and caches the sky-view LUT per sun elevation.
export class Atmosphere {
	readonly transmittance: AtmosphereLut;
	readonly multiScattering: AtmosphereLut;
	private skyView: AtmosphereLut | null = null;
	private skyViewElevation = NaN;

	constructor() {
		this.transmittance = buildTransmittanceLut();
		this.multiScattering = buildMultiScatteringLut(this.transmittance);
	}

	skyViewLut(sunDir: Vec3): AtmosphereLut {
		const elevation = Math.asin(Math.min(1, Math.max(-1, sunDir[1])));
		if (!this.skyView || elevation !== this.skyViewElevation) {
			this.skyView = buildSkyViewLut(this.transmittance, this.multiScattering, elevation);
			this.skyViewElevation = elevation;
		}
		return this.skyView;
	}

	// Sky radiance (no sun disk) along unit direction dir, scaled by the sun illuminance.
	skyRadiance(dir: Vec3, sunDir: Vec3, illuminance: Vec3): Vec3 {
		const out = new Float64Array(3);
		this.lookupSkyView(this.skyViewLut(sunDir), dir[0], dir[1], dir[2], sunDir, out);
		return [out[0] * illuminance[0], out[1] * illuminance[1], out[2] * illuminance[2]];
	}

	// Equirect environment (row 0 = +Y, same mapping as Common/Math.slang) of the sky lit by the sun.
	bakeEnvironment(sunDir: Vec3, illuminance: Vec3, width = 512): HDRImage {
		const lut = this.skyViewLut(sunDir);
		const height = width / 2;
		const data = new Float32Array(width * height * 4);
		const out = new Float64Array(3);
		for (let y = 0; y < height; y++) {
			const elevation = (0.5 - (y + 0.5) / height) * PI;
			const cosEl = Math.cos(elevation);
			const dy = Math.sin(elevation);
			for (let x = 0; x < width; x++) {
				const azimuth = ((x + 0.5) / width + 0.25) * 2 * PI;
				this.lookupSkyView(lut, Math.cos(azimuth) * cosEl, dy, Math.sin(azimuth) * cosEl, sunDir, out);
				const i = (y * width + x) * 4;
				data[i] = out[0] * illuminance[0];
				data[i + 1] = out[1] * illuminance[1];
				data[i + 2] = out[2] * illuminance[2];
				data[i + 3] = 1;
			}
		}
		return { width, height, data };
	}

	private lookupSkyView(lut: AtmosphereLut, dx: number, dy: number, dz: number, sunDir: Vec3, out: Float64Array): void {
		const altitude = Math.asin(Math.min(1, Math.max(-1, dy)));
		// azimuth relative to the sun's horizontal direction; arbitrary when either is vertical
		let fx = sunDir[0];
		let fz = sunDir[2];
		const fLen = Math.hypot(fx, fz);
		if (fLen > 1e-6) {
			fx /= fLen;
			fz /= fLen;
		} else {
			fx = 0;
			fz = -1;
		}
		const forward = dx * fx + dz * fz;
		const right = dz * fx - dx * fz;
		const azimuth = forward === 0 && right === 0 ? 0 : Math.atan2(right, forward);
		sampleLut(lut, azimuth / (2 * PI) + 0.5, altitudeToSkyViewV(altitude), out);
	}
}
