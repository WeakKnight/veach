// FidelityFX FSR 3 host math (docs/Fsr3.md): jitter, SPD setup, RCAS and the cbFSR3Upscaler layout and state.
import { describe, expect, it } from 'vitest';
import { FSR3_CONSTANTS_BYTES, Fsr3ConstantState, fsr3JitterOffset, fsr3JitterPhaseCount, fsr3RcasConstants, fsr3SpdSetup, type Fsr3Dispatch } from '../../src/render/fsr3/Fsr3Config';

describe('FSR 3 jitter', () => {
	it('uses FidelityFX phase counts: 8 * (display / render)^2, truncated', () => {
		expect(fsr3JitterPhaseCount(448, 640)).toBe(16);
		expect(fsr3JitterPhaseCount(1344, 1920)).toBe(16);
		expect(fsr3JitterPhaseCount(1280, 1920)).toBe(18);
		expect(fsr3JitterPhaseCount(1920, 1920)).toBe(8);
	});

	it('is the Halton (2, 3) sequence from index 1, centered, never zero', () => {
		expect(fsr3JitterOffset(0, 16)).toEqual([0, Math.fround(Math.fround(1 / 3) - 0.5)]);
		expect(fsr3JitterOffset(1, 16)).toEqual([-0.25, Math.fround(Math.fround(2 / 3) - 0.5)]);
		expect(fsr3JitterOffset(16, 16)).toEqual(fsr3JitterOffset(0, 16));
		for (let i = 0; i < 16; i++) {
			const [x, y] = fsr3JitterOffset(i, 16);
			expect(Math.abs(x) <= 0.5 && Math.abs(y) <= 0.5 && (x !== 0 || y !== 0)).toBe(true);
		}
	});
});

describe('FSR 3 dispatch helpers', () => {
	it('sets up SPD over 64x64 tiles', () => {
		expect(fsr3SpdSetup(448, 280)).toEqual({ dispatch: [7, 5], numWorkGroups: 35, mips: 8 });
		expect(fsr3SpdSetup(64, 64)).toEqual({ dispatch: [1, 1], numWorkGroups: 1, mips: 6 });
		expect(fsr3SpdSetup(8192, 8192).mips).toBe(12);
	});

	it('packs FsrRcasCon for the remapped sharpness', () => {
		const con = fsr3RcasConstants(0.8); // 0.4 stops
		const linear = new Float32Array(con.buffer, 0, 1)[0];
		expect(linear).toBeCloseTo(Math.pow(2, -0.4), 6);
		expect(con[1] & 0xffff).toBe(con[1] >>> 16);
		expect(con[1] & 0xffff).toBe(0x3a10); // half(0.7579) = 0x3A10
		expect([con[2], con[3]]).toEqual([0, 0]);
	});
});

describe('FSR 3 constants', () => {
	const dispatch = (over: Partial<Fsr3Dispatch> = {}): Fsr3Dispatch => ({
		renderSize: [448, 280], upscaleSize: [640, 400], jitter: [0.25, -0.125], motionVectorScale: [1, 1], reset: false, frameTimeDelta: 16,
		preExposure: 2, cameraNear: 0.01, cameraFar: 1e6, cameraFovAngleVertical: Math.PI / 4, viewSpaceToMetersFactor: 1, sharpness: 0.8, ...over,
	});

	it('lays out cbFSR3Upscaler like ffx_fsr3upscaler_private.h', () => {
		const state = new Fsr3ConstantState([448, 280], [640, 400]);
		expect(state.update(dispatch())).toBe(true); // first execution resets
		expect(state.words.byteLength).toBe(FSR3_CONSTANTS_BYTES);
		const i = new Int32Array(state.words), f = new Float32Array(state.words);
		expect([...i.subarray(0, 12)]).toEqual([448, 280, 0, 0, 640, 400, 0, 0, 448, 280, 640, 400]);
		// inverted infinite depth: viewZ = near / (depth + FLT_EPSILON)
		expect(f[12]).toBe(-Math.fround(1.1920928955078125e-7));
		expect(f[13]).toBe(Math.fround(0.01));
		expect(f[15]).toBeCloseTo(Math.tan(Math.PI / 8), 6);
		expect(f[14]).toBeCloseTo(Math.tan(Math.PI / 8) * 448 / 280, 6);
		expect([f[16], f[17], f[18], f[19]]).toEqual([0.25, -0.125, 0, 0]);
		expect([f[20], f[21]]).toEqual([Math.fround(1 / 448), Math.fround(1 / 280)]);
		expect([f[22], f[23]]).toEqual([Math.fround(0.7), Math.fround(0.7)]);
		expect(f[27]).toBe(16); // jitter phase count
		expect(f[28]).toBeCloseTo(0.016, 7); // seconds
		expect([f[29], f[30], f[31]]).toEqual([1, 1, 0]); // delta pre-exposure, meters, frame index
		expect([f[32], f[33], f[34], f[35], f[36]]).toEqual([1, 1, 1, Math.fround(1 / 3), Math.fround(-1 / 3)]);
	});

	it('tracks previous jitter, sizes, frame index and pre-exposure changes', () => {
		const state = new Fsr3ConstantState([448, 280], [640, 400]);
		state.update(dispatch());
		expect(state.update(dispatch({ jitter: [-0.375, 0.5], preExposure: 4 }))).toBe(false);
		const i = new Int32Array(state.words), f = new Float32Array(state.words);
		expect([f[16], f[17], f[18], f[19]]).toEqual([-0.375, 0.5, 0.25, -0.125]);
		expect([i[2], i[3], i[6], i[7]]).toEqual([448, 280, 640, 400]);
		expect([f[29], f[31]]).toEqual([2, 1]);
		expect(state.update(dispatch({ reset: true }))).toBe(true);
		expect(f[31]).toBe(0);
	});

	it('moves the jitter phase count one step per frame toward a new ratio', () => {
		const state = new Fsr3ConstantState([640, 400], [640, 400]);
		state.update(dispatch());
		const f = new Float32Array(state.words);
		state.update(dispatch({ renderSize: [320, 200] })); // target 32
		expect(f[27]).toBe(17);
		state.update(dispatch({ renderSize: [320, 200] }));
		expect(f[27]).toBe(18);
	});
});
