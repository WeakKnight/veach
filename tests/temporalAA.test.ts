import { expect, it } from 'vitest';
import { temporalInverse, temporalJitter } from '../src/render/TemporalAA';
import { vec3 } from '../src/math/Math';

it('inverts an off-axis, scaled ray basis for reprojection', () => {
	const camera = { position: [0, 0, 0] as [number, number, number], right: [2, 0, 0] as [number, number, number], up: [0, 3, 0] as [number, number, number], forward: [0.4, -0.2, -1] as [number, number, number] };
	const ray = vec3.add(vec3.add(camera.forward, vec3.scale(camera.right, 0.7)), vec3.scale(camera.up, -0.3));
	const q = temporalInverse(camera).map(r => vec3.dot(r, ray));
	expect(q[0] / q[2]).toBeCloseTo(0.7, 12); expect(q[1] / q[2]).toBeCloseTo(-0.3, 12);
	const samples = Array.from({ length: 32 }, (_, i) => temporalJitter(i));
	expect(samples.every(v => v.every(x => x > 0 && x < 1))).toBe(true);
	expect(new Set(samples.map(v => v.join(','))).size).toBe(32);
	expect(temporalJitter(32)).toEqual(temporalJitter(0));
});
