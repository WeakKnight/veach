import { describe, expect, it } from 'vitest';
import { Atmosphere, sunTransmittance } from '../src/render/Atmosphere';
import type { Vec3 } from '../src/math/Math';

const deg = (d: number) => (d * Math.PI) / 180;
const sunAt = (elevation: number, azimuth: number): Vec3 => [
	Math.cos(deg(elevation)) * Math.sin(deg(azimuth)),
	Math.sin(deg(elevation)),
	Math.cos(deg(elevation)) * Math.cos(deg(azimuth)),
];
const luminance = (c: Vec3) => 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
const white: Vec3 = [1, 1, 1];

describe('atmosphere', () => {
	const start = performance.now();
	const atmosphere = new Atmosphere();
	const lutMs = performance.now() - start;

	it('matches the analytic zenith transmittance at the viewer', () => {
		// optical depth from 200 m: Rayleigh 8 km and Mie 1.2 km scale heights, 15 km of ozone tent
		const rayleigh = Math.exp(-0.2 / 8) * 0.008;
		const mie = Math.exp(-0.2 / 1.2) * 0.0012 * (3.996 + 4.4);
		const expected = [5.802, 13.558, 33.1].map((s, c) => Math.exp(-(s * rayleigh + mie + [0.65, 1.881, 0.085][c] * 0.015)));
		const t = sunTransmittance([0, 1, 0]);
		for (let c = 0; c < 3; c++) expect(t[c]).toBeCloseTo(expected[c], 2);
	});

	it('reddens and dims the sun toward the horizon and blocks it below', () => {
		const noon = sunTransmittance(sunAt(60, 0));
		const low = sunTransmittance(sunAt(2, 0));
		expect(low[0] / low[2]).toBeGreaterThan(3 * (noon[0] / noon[2]));
		expect(luminance(low)).toBeLessThan(luminance(noon));
		expect(sunTransmittance(sunAt(-5, 0))).toEqual([0, 0, 0]);
	});

	it('produces a blue zenith that is brighter toward the sun', () => {
		const sun = sunAt(30, 40);
		const zenith = atmosphere.skyRadiance([0, 1, 0], sun, white);
		expect(zenith[2]).toBeGreaterThan(zenith[1]);
		expect(zenith[1]).toBeGreaterThan(zenith[0]);
		const towardSun = atmosphere.skyRadiance(sunAt(20, 40), sun, white);
		const awayFromSun = atmosphere.skyRadiance(sunAt(20, 220), sun, white);
		expect(luminance(towardSun)).toBeGreaterThan(1.5 * luminance(awayFromSun));
	});

	it('lights the ground with the sun and the sky', () => {
		const sun = sunAt(45, 0);
		const t = sunTransmittance(sun);
		const nadir = atmosphere.skyRadiance([0, -1, 0], sun, white);
		const direct = t.map((v) => (0.3 / Math.PI) * v * Math.sin(deg(45)));
		// the blue sky adds more blue than red
		const skyFraction = nadir.map((v, c) => v / direct[c] - 1);
		expect(skyFraction[0]).toBeGreaterThan(0.02);
		expect(skyFraction[2]).toBeGreaterThan(2 * skyFraction[0]);
		expect(skyFraction[2]).toBeLessThan(1);
		const twilight = atmosphere.skyRadiance([0, -1, 0], sunAt(-2, 0), white);
		expect(luminance(twilight)).toBeGreaterThan(0);
	});

	it('darkens after sunset', () => {
		const day = atmosphere.skyRadiance([0, 1, 0], sunAt(45, 0), white);
		const night = atmosphere.skyRadiance([0, 1, 0], sunAt(-15, 0), white);
		expect(luminance(night)).toBeLessThan(1e-3 * luminance(day));
	});

	it('bakes the equirect map with the shader mapping', () => {
		const sun = sunAt(10, 90); // toward +X
		const env = atmosphere.bakeEnvironment(sun, [2, 2, 2], 64);
		expect(env.width).toBe(64);
		expect(env.height).toBe(32);
		// u = atan2(z, x) / 2pi - 0.25, so +X is at u = 0.75 and -X at u = 0.25
		const texel = (u: number, v: number): Vec3 => {
			const i = (Math.floor(v * env.height) * env.width + Math.floor(u * env.width)) * 4;
			return [env.data[i], env.data[i + 1], env.data[i + 2]];
		};
		const row = 0.42; // ~14 degrees above the horizon
		expect(luminance(texel(0.75, row))).toBeGreaterThan(2 * luminance(texel(0.25, row)));
		const direct = atmosphere.skyRadiance([0, 1, 0], sun, [2, 2, 2]);
		const top = texel(0.5, 0);
		for (let c = 0; c < 3; c++) expect(top[c]).toBeCloseTo(direct[c], 2);
		for (const v of env.data) expect(Number.isFinite(v) && v >= 0).toBe(true);
	});

	it('builds the LUTs and a sky quickly', () => {
		const t0 = performance.now();
		atmosphere.bakeEnvironment(sunAt(33, 10), white);
		const skyMs = performance.now() - t0;
		console.log(`[atmosphere] static LUTs ${lutMs.toFixed(0)} ms, sky-view + 512x256 bake ${skyMs.toFixed(0)} ms`);
		expect(lutMs).toBeLessThan(2000);
		expect(skyMs).toBeLessThan(1000);
	});
});
