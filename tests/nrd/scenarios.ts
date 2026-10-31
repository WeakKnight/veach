// Scripted NRD frame sequences for the planner tests (docs/Nrd.md, TypeScript planner migration).
// drive() reproduces NrdDenoiser.encode's history-reset and frame-index bookkeeping, so every planner sees
// exactly the common settings production would pass for these frames.
import { nrdCommonInputs, type NrdCamera, type NrdFrameState } from '../../src/render/denoise/NrdDenoiser';
import type { NrdMode } from '../../src/render/denoise/NrdConfig.mjs';

export interface ScenarioFrame extends NrdFrameState { reset?: boolean; timeDelta: number }
export interface Scenario { name: string; mode: NrdMode; startFrameIndex?: number; frames: ScenarioFrame[] }
export type CommonInputs = ReturnType<typeof nrdCommonInputs>;

type V3 = [number, number, number];
const sub = (a: V3, b: V3): V3 => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const cross = (a: V3, b: V3): V3 => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const scale = (a: V3, s: number): V3 => [a[0] * s, a[1] * s, a[2] * s];
const normalize = (a: V3): V3 => scale(a, 1 / Math.hypot(...a));

/** Host camera convention: right and up scaled by tan(fovY / 2) (and aspect), forward unit length. */
export function lookAt(position: V3, target: V3, width: number, height: number, fovY = 0.9): NrdCamera {
	const forward = normalize(sub(target, position));
	const right = normalize(cross(forward, [0, 1, 0]));
	const up = cross(right, forward);
	const t = Math.tan(fovY / 2);
	return { position, right: scale(right, t * width / height), up: scale(up, t), forward };
}

const halton = (index: number, base: number) => {
	let f = 1, r = 0;
	for (let i = index; i > 0; i = Math.floor(i / base)) { f /= base; r += f * (i % base); }
	return r;
};

function frames(count: number, at: (i: number) => Omit<ScenarioFrame, 'jitter'>): ScenarioFrame[] {
	return Array.from({ length: count }, (_, i) => ({ ...at(i), jitter: [halton(i + 1, 2), halton(i + 1, 3)] }));
}

const W = 64, H = 40;
const still = (i: number) => ({ camera: lookAt([0, 1.5, 4], [0, 1, 0], W, H), width: W, height: H, timeDelta: 16.666 + (i % 3) });
const orbit = (i: number) => {
	const a = i * 0.07, r = 4 + 0.5 * Math.sin(i * 0.2);
	return { camera: lookAt([r * Math.sin(a), 1.5 + 0.02 * i, r * Math.cos(a)], [0.1 * i, 1, 0], W, H), width: W, height: H, timeDelta: 8 + (i * 7) % 26 };
};

export function scenarios(): Scenario[] {
	const list: Omit<Scenario, 'mode'>[] = [
		// Beyond maxAccumulatedFrameNum (30) and maxStabilizedFrameNum (63); both ping-pong parities.
		{ name: 'steady', frames: frames(70, still) },
		{ name: 'motion', frames: frames(40, orbit) },
		{ name: 'resets', frames: frames(30, i => ({ ...orbit(i), reset: i === 10 || i === 11 || i === 25 })) },
		{ name: 'resize', frames: frames(24, i => {
			const [w, h] = i < 8 ? [W, H] : i < 16 ? [80, 45] : [W, H];
			return { camera: lookAt([0, 1.5, 4], [0, 1, 0], w, h), width: w, height: h, timeDelta: 16.666 };
		}) },
		// Long sessions: the host's frame index grows past 2^32 and is written as uint32.
		{ name: 'wrap', startFrameIndex: 2 ** 32 - 3, frames: frames(8, still) },
		{ name: 'late', startFrameIndex: 1_000_003, frames: frames(8, orbit) },
	];
	return (['radiance', 'sh'] as const).flatMap(mode => list.map(s => ({ ...s, mode })));
}

/** Common settings per frame, as NrdDenoiser.encode computes them (every frame's pipelines are ready). */
export function* drive(scenario: Scenario): Generator<CommonInputs> {
	let previous: NrdFrameState | null = null, needsReset = true, frameIndex = scenario.startFrameIndex ?? 0;
	for (const frame of scenario.frames) {
		const reset = !!frame.reset || needsReset || !previous || previous.width !== frame.width || previous.height !== frame.height;
		needsReset = false;
		yield nrdCommonInputs(frame, previous, frameIndex, reset, frame.timeDelta);
		previous = { camera: frame.camera, jitter: frame.jitter, width: frame.width, height: frame.height };
		frameIndex++;
	}
}
