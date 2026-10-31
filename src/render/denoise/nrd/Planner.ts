// NRD per-frame planning in TypeScript: common settings, history clears, ping-pongs, REBLUR passes and
// their constant buffers. A port of InstanceImpl::SetCommonSettings / GetComputeDispatches / PushDispatch
// (ThirdParty/NRD/Source/InstanceImpl.cpp) and Update_Reblur / AddSharedConstants_Reblur (Reblur.cpp), as
// configured by wasm/nrd_wasm.cpp. Inputs and outputs match the wasm runtime's ABI (tests/nrd/wasm.ts), and the
// results are equal to its results (tests/nrd): float32 math follows Math32.ts.
import type { Dispatch, InstanceDesc } from '../NrdConfig.mjs';
import {
	type M4, type V4, clamp, decomposeProjection, fromColumns, identity, invertOrtho, lerp, mulMatrix, negate, PROJ_LEFT_HANDED, PROJ_ORTHO,
	radians, rotator, saturate, setw1, sub, transpose, weyl1D,
} from './Math32';
import {
	IN_MV, IN_SIGNAL, NrdInstance, OUT_DIFF_RADIANCE_HITDIST, OUT_VALIDATION, PERMANENT_POOL, REBLUR_CONSTANTS_BYTES, REBLUR_DIFFUSE_SH,
	REBLUR_DIFFUSE_SPECULAR, REBLUR_SPECULAR_SH, VALIDATION_CONSTANTS_BYTES, type DenoiserData, type InternalDispatch, type ResourceDesc,
} from './Instance';

const f = Math.fround;
// nrd::AccumulationMode, nrd::CheckerboardMode, nrd::HitDistanceReconstructionMode
const CONTINUE = 0, CLEAR_AND_RESTART = 2;
const CHECKERBOARD_OFF = 0, CHECKERBOARD_BLACK = 1, CHECKERBOARD_WHITE = 2;
const HITDIST_RECONSTRUCTION_OFF = 0, HITDIST_RECONSTRUCTION_AREA_5X5 = 2;
const REBLUR_MAX_HISTORY_FRAME_NUM = 63;
// Update_Reblur's dispatch enum: local indices within a REBLUR denoiser.
const CLASSIFY_TILES = 0, HITDIST_RECONSTRUCTION = 1, PREPASS = 5, TEMPORAL_ACCUMULATION = 7, HISTORY_FIX = 15, BLUR = 16, POST_BLUR = 17,
	TEMPORAL_STABILIZATION = 19, SPLIT_SCREEN = 20, VALIDATION = 21;
const PROPS: Record<number, { hasDiffuse: boolean; hasSpecular: boolean }> = {
	[REBLUR_DIFFUSE_SH]: { hasDiffuse: true, hasSpecular: false },
	[REBLUR_SPECULAR_SH]: { hasDiffuse: false, hasSpecular: true },
	[REBLUR_DIFFUSE_SPECULAR]: { hasDiffuse: true, hasSpecular: true },
};

/** nrd::CommonSettings: the fields nrd_set_common writes, and the defaults it leaves. */
interface CommonSettings {
	viewToClip: number[]; viewToClipPrev: number[]; worldToView: number[]; worldToViewPrev: number[]; worldPrevToWorld: number[];
	motionVectorScale: [number, number, number]; motionVectorBias: [number, number, number];
	cameraJitter: [number, number]; cameraJitterPrev: [number, number];
	resourceSize: [number, number]; resourceSizePrev: [number, number]; rectSize: [number, number]; rectSizePrev: [number, number];
	viewZScale: number; timeDeltaBetweenFrames: number; denoisingRange: number; disocclusionThreshold: number; disocclusionThresholdAlternate: number;
	cameraAttachedReflectionMaterialID: number; strandMaterialID: number; historyFixAlternatePixelStrideMaterialID: number; strandThickness: number;
	splitScreen: number; printfAt: [number, number]; debug: number; inputRectOrigin: [number, number]; outputRectOrigin: [number, number];
	frameIndex: number; accumulationMode: number; isMotionVectorInWorldSpace: boolean; isHistoryConfidenceAvailable: boolean;
	isDisocclusionThresholdMixAvailable: boolean; enableValidation: boolean;
}

function defaultCommonSettings(): CommonSettings {
	return {
		viewToClip: new Array(16).fill(0), viewToClipPrev: new Array(16).fill(0), worldToView: new Array(16).fill(0), worldToViewPrev: new Array(16).fill(0),
		worldPrevToWorld: identity().flat(),
		motionVectorScale: [1, 1, 0], motionVectorBias: [0, 0, 0], cameraJitter: [0, 0], cameraJitterPrev: [0, 0],
		resourceSize: [0, 0], resourceSizePrev: [0, 0], rectSize: [0, 0], rectSizePrev: [0, 0],
		viewZScale: 1, timeDeltaBetweenFrames: 0, denoisingRange: 500000, disocclusionThreshold: f(0.01), disocclusionThresholdAlternate: f(0.05),
		cameraAttachedReflectionMaterialID: 999, strandMaterialID: 999, historyFixAlternatePixelStrideMaterialID: 999, strandThickness: f(80e-6),
		splitScreen: 0, printfAt: [9999, 9999], debug: 0, inputRectOrigin: [0, 0], outputRectOrigin: [0, 0],
		frameIndex: 0, accumulationMode: CONTINUE, isMotionVectorInWorldSpace: false, isHistoryConfidenceAvailable: false,
		isDisocclusionThresholdMixAvailable: false, enableValidation: false,
	};
}
const copyCommon = (c: CommonSettings): CommonSettings => structuredClone(c);

/** nrd::ReblurSettings defaults. */
function defaultReblurSettings() {
	return {
		hitDistanceParameters: { A: 3, B: f(0.1), C: 20 }, antilag: { luminanceSigmaScale: 2, luminanceSensitivity: 3 },
		responsiveAccumulation: { roughnessThreshold: 0, minAccumulatedFrameNum: 3 }, convergence: { s: 1, b: f(0.2), p: f(0.8) },
		maxAccumulatedFrameNum: 30, maxFastAccumulatedFrameNum: 6, maxStabilizedFrameNum: REBLUR_MAX_HISTORY_FRAME_NUM, historyFixFrameNum: 3,
		historyFixBasePixelStride: 14, historyFixAlternatePixelStride: 14, fastHistoryClampingSigmaScale: 2,
		diffusePrepassBlurRadius: 30, specularPrepassBlurRadius: 50, minHitDistanceWeight: f(0.1), minBlurRadius: 1, maxBlurRadius: 30,
		lobeAngleFraction: f(0.15), roughnessFraction: f(0.15), planeDistanceSensitivity: f(0.02), fireflySuppressorMinRelativeScale: 2,
		minMaterialForDiffuse: 4, minMaterialForSpecular: 4, checkerboardMode: CHECKERBOARD_OFF, hitDistanceReconstructionMode: HITDIST_RECONSTRUCTION_OFF,
		enableAntiFirefly: true, usePrepassOnlyForSpecularMotionEstimation: false, returnHistoryLengthInsteadOfOcclusion: false,
	};
}
type ReblurSettings = ReturnType<typeof defaultReblurSettings>;

const divideUp = (x: number, y: number) => Math.trunc((x + y - 1) / y) & 0xffff;

/** Little-endian constant buffer, written member by member in declaration order. */
class Constants {
	readonly bytes: Uint8Array;
	private readonly view: DataView;
	private offset = 0;
	constructor(size: number) {
		this.bytes = new Uint8Array(size);
		this.view = new DataView(this.bytes.buffer);
	}
	float(...values: number[]): this { for (const v of values) { this.view.setFloat32(this.offset, v, true); this.offset += 4; } return this; }
	uint(...values: number[]): this { for (const v of values) { this.view.setUint32(this.offset, v >>> 0, true); this.offset += 4; } return this; }
	int(...values: number[]): this { for (const v of values) { this.view.setInt32(this.offset, v | 0, true); this.offset += 4; } return this; }
	matrix(m: M4): this { return this.float(...m.flat()); }
	setInt(offset: number, ...values: number[]): void { values.forEach((v, i) => this.view.setInt32(offset + i * 4, v | 0, true)); }
}

// REBLUR_SHARED_CONSTANTS: 892 bytes; byte offsets of the int2 members individual passes override.
const SHARED_CONSTANTS_BYTES = 892;
const G_DISPATCH_INPUT_RECT_ORIGIN = 6 * 64 + 12 * 16 + 13 * 8, G_DISPATCH_OUTPUT_RECT_ORIGIN = G_DISPATCH_INPUT_RECT_ORIGIN + 8;

/** NRD's Timer: milliseconds between SaveCurrentTime calls, from the same clock as Emscripten's CLOCK_REALTIME. */
class Timer {
	private time: number;
	delta = 1;
	constructor(private readonly now: () => number) { this.time = this.ticks(); }
	private ticks(): number { return Math.round(this.now() * 1_000_000); }
	update(): void { this.delta = f((this.ticks() - this.time) * (1 / 1000000)); }
	save(): void { this.time = this.ticks(); }
}

export class NrdPlanner {
	readonly instance: NrdInstance;
	private readonly input = defaultCommonSettings(); // wasm Context::common, written by every plan()
	private common = defaultCommonSettings(); // InstanceImpl::m_CommonSettings
	private readonly reblur = new Map<number, ReblurSettings>();
	private readonly timer: Timer;
	private viewToClip: M4 = identity(); private viewToClipPrev: M4 = identity();
	private worldToView: M4 = identity(); private worldToViewPrev: M4 = identity();
	private viewToWorld: M4 = identity(); private viewToWorldPrev: M4 = identity();
	private worldToClip: M4 = identity(); private worldToClipPrev: M4 = identity();
	private worldPrevToWorld: M4 = identity();
	private rotatorPre: V4 = [0, 0, 0, 0]; private rotatorMain: V4 = [0, 0, 0, 0]; private rotatorPost: V4 = [0, 0, 0, 0];
	private frustum: V4 = [0, 0, 0, 0]; private frustumPrev: V4 = [0, 0, 0, 0];
	private cameraDelta: V4 = [0, 0, 0, 0]; private viewDirection: V4 = [0, 0, 0, 0]; private viewDirectionPrev: V4 = [0, 0, 0, 0];
	private splitScreenPrev = 0;
	private orthoMode = 0;
	private checkerboardResolveAccumSpeed = 0;
	private jitterDelta = 0;
	private timeDelta = 0;
	private timeDeltaSmoothed = f(16.66);
	private frameRateScale = 0;
	private frameRateScaleSmoothed = 1;
	private projectY = 0;
	private isFirstUse = true;

	/** `denoisers`: nrd::Denoiser values, identifiers = indices. `now`: wall clock in ms for timeDelta 0. */
	constructor(denoisers: readonly number[], now: () => number = Date.now) {
		this.instance = new NrdInstance(denoisers);
		this.timer = new Timer(now);
		for (const d of this.instance.denoisers) this.reblur.set(d.identifier, defaultReblurSettings());
	}

	get desc(): InstanceDesc { return this.instance.desc; }

	/** nrd_set_reblur: the same settings for every denoiser (all REBLUR). */
	setReblur(floats: ArrayLike<number>, ints: ArrayLike<number>): void {
		const v = Array.from(floats, f), u = Array.from(ints, x => x >>> 0);
		for (const settings of this.reblur.values()) {
			settings.hitDistanceParameters = { A: v[0], B: v[1], C: v[2] };
			[settings.fastHistoryClampingSigmaScale, settings.diffusePrepassBlurRadius, settings.specularPrepassBlurRadius, settings.minBlurRadius,
				settings.maxBlurRadius, settings.lobeAngleFraction, settings.roughnessFraction, settings.planeDistanceSensitivity] = v.slice(3, 11);
			[settings.maxAccumulatedFrameNum, settings.maxFastAccumulatedFrameNum, settings.maxStabilizedFrameNum, settings.historyFixFrameNum,
				settings.checkerboardMode, settings.hitDistanceReconstructionMode] = u.slice(0, 6);
			settings.enableAntiFirefly = u[6] !== 0;
		}
	}

	/** nrd_set_common + nrd_dispatches; throws on invalid common settings, where NRD's asserts fire. */
	plan(matrices: ArrayLike<number>, params: ArrayLike<number>, ints: ArrayLike<number>): Dispatch[] {
		const c = this.input, p = Array.from(params, f), n = Array.from(ints, x => x >>> 0), m = Array.from(matrices, f);
		c.viewToClip = m.slice(0, 16); c.viewToClipPrev = m.slice(16, 32); c.worldToView = m.slice(32, 48); c.worldToViewPrev = m.slice(48, 64);
		c.motionVectorScale = [p[0], p[1], p[2]];
		c.cameraJitter = [p[3], p[4]]; c.cameraJitterPrev = [p[5], p[6]];
		c.denoisingRange = p[7]; c.disocclusionThreshold = p[8]; c.viewZScale = p[9]; c.timeDeltaBetweenFrames = p[10];
		c.resourceSize = [n[0] & 0xffff, n[1] & 0xffff]; c.rectSize = [n[0] & 0xffff, n[1] & 0xffff];
		c.resourceSizePrev = [n[2] & 0xffff, n[3] & 0xffff]; c.rectSizePrev = [n[2] & 0xffff, n[3] & 0xffff];
		c.frameIndex = n[4]; c.accumulationMode = n[5]; c.enableValidation = n[6] !== 0;
		if (!this.setCommonSettings(c)) throw new Error('NRD common settings rejected');
		return this.dispatches();
	}

	private setCommonSettings(input: CommonSettings): boolean {
		this.splitScreenPrev = this.common.splitScreen;
		const isNewFrame = this.isFirstUse || this.common.frameIndex !== input.frameIndex;
		const s = this.common = copyCommon(input);
		if (this.isFirstUse) s.accumulationMode = CLEAR_AND_RESTART;
		if (s.accumulationMode !== CONTINUE) {
			this.splitScreenPrev = 0;
			s.resourceSizePrev = [...s.resourceSize];
			s.rectSizePrev = [...s.rectSize];
			s.cameraJitterPrev = [...s.cameraJitter];
		}

		const inRange = (x: number) => x >= -0.5 && x <= 0.5;
		const isValid = s.viewZScale > 0 && s.resourceSize[0] !== 0 && s.resourceSize[1] !== 0 && s.resourceSizePrev[0] !== 0 && s.resourceSizePrev[1] !== 0
			&& s.rectSize[0] !== 0 && s.rectSize[1] !== 0 && s.rectSizePrev[0] !== 0 && s.rectSizePrev[1] !== 0
			&& s.inputRectOrigin[0] + s.rectSize[0] <= s.resourceSize[0] && s.inputRectOrigin[1] + s.rectSize[1] <= s.resourceSize[1]
			&& s.outputRectOrigin[0] + s.rectSize[0] <= s.resourceSize[0] && s.outputRectOrigin[1] + s.rectSize[1] <= s.resourceSize[1]
			&& ((s.motionVectorScale[0] !== 0 && s.motionVectorScale[1] !== 0) || s.isMotionVectorInWorldSpace)
			&& inRange(s.cameraJitter[0]) && inRange(s.cameraJitter[1]) && inRange(s.cameraJitterPrev[0]) && inRange(s.cameraJitterPrev[1])
			&& s.denoisingRange > 0 && s.disocclusionThreshold > 0 && s.disocclusionThresholdAlternate > 0
			// NRD_SUPPORTS_VIEWPORT_OFFSET = 0, NRD_SUPPORTS_HISTORY_CONFIDENCE = 0, NRD_SUPPORTS_DISOCCLUSION_THRESHOLD_MIX = 0
			&& s.inputRectOrigin.every(o => o === 0) && s.outputRectOrigin.every(o => o === 0)
			&& !s.isHistoryConfidenceAvailable && !s.isDisocclusionThresholdMixAvailable;

		// Rotators (respecting sample pattern symmetry): Weyl sequences of 1 / sqrt(2) and 1 / sqrt(3).
		const anglePre = weyl1D(f(1 / f(Math.sqrt(2))), s.frameIndex), angle = weyl1D(f(1 / f(Math.sqrt(3))), s.frameIndex);
		const quarter = radians(90);
		this.rotatorPre = rotator(f(anglePre * quarter));
		this.rotatorMain = rotator(f(angle * quarter));
		this.rotatorPost = rotator(f(f(angle * quarter) + radians(22.5)));

		this.viewToClip = fromColumns(s.viewToClip);
		this.viewToClipPrev = fromColumns(s.viewToClipPrev);
		this.worldToView = fromColumns(s.worldToView);
		this.worldToViewPrev = fromColumns(s.worldToViewPrev);
		this.worldPrevToWorld = fromColumns(s.worldPrevToWorld);

		// Convert to left-handed view space.
		if (!(decomposeProjection(this.viewToClip).flags & PROJ_LEFT_HANDED)) {
			this.viewToClip[2] = negate(this.viewToClip[2]);
			this.viewToClipPrev[2] = negate(this.viewToClipPrev[2]);
			const negateRow2 = (m: M4) => { const t = transpose(m); t[2] = negate(t[2]); return transpose(t); };
			this.worldToView = negateRow2(this.worldToView);
			this.worldToViewPrev = negateRow2(this.worldToViewPrev);
		}

		// Camera-relative matrices: the current camera at the origin, the previous one at the delta.
		this.viewToWorld = invertOrtho(this.worldToView);
		this.viewToWorldPrev = invertOrtho(this.worldToViewPrev);
		const translationDelta = sub(this.viewToWorldPrev[3], this.viewToWorld[3]);
		this.viewToWorld[3] = setw1([0, 0, 0, 0]);
		this.worldToView = invertOrtho(this.viewToWorld);
		this.viewToWorldPrev[3] = setw1(translationDelta);
		this.worldToViewPrev = invertOrtho(this.viewToWorldPrev);
		this.worldToClip = mulMatrix(this.viewToClip, this.worldToView);
		this.worldToClipPrev = mulMatrix(this.viewToClipPrev, this.worldToViewPrev);

		const projection = decomposeProjection(this.viewToClip);
		this.frustum = projection.frustum;
		this.projectY = projection.project[1];
		this.orthoMode = projection.flags & PROJ_ORTHO ? -1 : 0;
		this.frustumPrev = decomposeProjection(this.viewToClipPrev).frustum;
		this.viewDirection = negate(this.viewToWorld[2]);
		this.viewDirectionPrev = negate(this.viewToWorldPrev[2]);
		this.cameraDelta = [translationDelta[0], translationDelta[1], translationDelta[2], 0];

		if (isNewFrame) {
			this.timer.update();
			this.timer.save();
		}
		this.timeDelta = s.timeDeltaBetweenFrames > 0 ? s.timeDeltaBetweenFrames : this.timer.delta;
		this.frameRateScale = clamp(f(f(16.66) / this.timeDelta), 0.25, 4);
		if (isNewFrame) {
			if (this.isFirstUse || s.accumulationMode !== CONTINUE) this.timeDeltaSmoothed = this.timeDelta;
			else {
				const smoothedFPSprev = f(1000 / this.timeDeltaSmoothed), n = f(smoothedFPSprev * f(0.2));
				this.timeDeltaSmoothed = f(this.timeDeltaSmoothed + f(f(this.timeDelta - this.timeDeltaSmoothed) / f(1 + n)));
			}
		}
		this.frameRateScaleSmoothed = clamp(f(f(16.66) / this.timeDeltaSmoothed), 0.25, 4);
		const dx = Math.abs(f(s.cameraJitter[0] - s.cameraJitterPrev[0])), dy = Math.abs(f(s.cameraJitter[1] - s.cameraJitterPrev[1]));
		this.jitterDelta = Math.max(dx, dy);
		const fps = f(this.frameRateScale * 60), quarterFps = f(fps * 0.25);
		this.checkerboardResolveAccumSpeed = lerp(f(quarterFps / f(1 + quarterFps)), 0.5, this.jitterDelta);
		this.isFirstUse = false;
		return isValid;
	}

	private dispatches(): Dispatch[] {
		const active: Dispatch[] = [], s = this.common, instance = this.instance;
		if (s.accumulationMode === CLEAR_AND_RESTART) {
			for (const clear of instance.clearResources) {
				const internal = instance.dispatches[instance.clearDispatch[clear.isInteger ? 1 : 0]];
				const type = clear.resource.type;
				const isInput = type >= IN_MV && type <= IN_SIGNAL, isOutput = type >= OUT_DIFF_RADIANCE_HITDIST && type <= OUT_VALIDATION;
				const useRect = isInput || isOutput || type === PERMANENT_POOL;
				const w = useRect ? s.rectSize[0] : divideUp(s.resourceSize[0], clear.downsampleFactor);
				const h = useRect ? s.rectSize[1] : divideUp(s.resourceSize[1], clear.downsampleFactor);
				const origin = isInput ? s.inputRectOrigin : useRect ? s.outputRectOrigin : [0, 0];
				const constants = new Constants(internal.constantBytes).int(w, h, origin[0], origin[1]);
				active.push(this.dispatch(internal, [clear.resource], w, h, constants.bytes));
			}
		}
		for (const denoiser of instance.denoisers) {
			for (let i = 0; i < denoiser.pingPongCount; i++) {
				const pingPong = instance.pingPongs[denoiser.pingPongOffset + i], resource = instance.resources[pingPong.resource];
				[resource.index, pingPong.swapWith] = [pingPong.swapWith, resource.index];
			}
			this.updateReblur(denoiser, active);
		}
		return active;
	}

	private dispatch(internal: InternalDispatch, resources: ResourceDesc[], w: number, h: number, constants: Uint8Array): Dispatch {
		return { pipeline: internal.pipeline, width: divideUp(w, internal.numThreads[0]), height: divideUp(h, internal.numThreads[1]),
			constants, resources: resources.map(r => ({ descriptor: r.descriptor, type: r.type, index: r.index })), name: internal.name };
	}

	private pushReblur(denoiser: DenoiserData, local: number, active: Dispatch[], settings: ReblurSettings, edit?: (c: Constants) => void): void {
		const internal = this.instance.dispatches[denoiser.dispatchOffset + local];
		const d = internal.downsampleFactor, w = divideUp(this.common.rectSize[0], d), h = divideUp(this.common.rectSize[1], d);
		const constants = this.sharedConstants(settings, internal.constantBytes);
		edit?.(constants);
		const resources = this.instance.resources.slice(internal.resourceOffset, internal.resourceOffset + internal.resourceCount);
		active.push(this.dispatch(internal, resources, w, h, constants.bytes));
	}

	private updateReblur(denoiser: DenoiserData, active: Dispatch[]): void {
		const settings = this.reblur.get(denoiser.identifier)!, props = PROPS[denoiser.denoiser], s = this.common;
		const push = (local: number, edit?: (c: Constants) => void) => this.pushReblur(denoiser, local, active, settings, edit);
		const enableHitDistanceReconstruction = settings.hitDistanceReconstructionMode !== HITDIST_RECONSTRUCTION_OFF && settings.checkerboardMode === CHECKERBOARD_OFF;
		const skipTemporalStabilization = settings.maxStabilizedFrameNum === 0;
		const skipPrePass = (settings.diffusePrepassBlurRadius === 0 || !props.hasDiffuse) && (settings.specularPrepassBlurRadius === 0 || !props.hasSpecular)
			&& settings.checkerboardMode === CHECKERBOARD_OFF;

		if (s.splitScreen >= 1) {
			push(SPLIT_SCREEN);
			return;
		}
		push(CLASSIFY_TILES);
		if (enableHitDistanceReconstruction) {
			const local = HITDIST_RECONSTRUCTION + (settings.hitDistanceReconstructionMode === HITDIST_RECONSTRUCTION_AREA_5X5 ? 2 : 0) + (!skipPrePass ? 1 : 0);
			push(local, c => c.setInt(G_DISPATCH_OUTPUT_RECT_ORIGIN, ...(skipPrePass ? s.outputRectOrigin : [0, 0])));
		}
		if (!skipPrePass) push(PREPASS + (enableHitDistanceReconstruction ? 1 : 0), c => c.setInt(G_DISPATCH_INPUT_RECT_ORIGIN, ...(enableHitDistanceReconstruction ? [0, 0] : s.inputRectOrigin)));
		const afterPrepass = !skipPrePass || enableHitDistanceReconstruction;
		push(TEMPORAL_ACCUMULATION + (s.isDisocclusionThresholdMixAvailable ? 4 : 0) + (s.isHistoryConfidenceAvailable ? 2 : 0) + (afterPrepass ? 1 : 0),
			c => c.setInt(G_DISPATCH_INPUT_RECT_ORIGIN, ...(afterPrepass ? s.outputRectOrigin : s.inputRectOrigin)));
		push(HISTORY_FIX);
		push(BLUR);
		push(POST_BLUR + (skipTemporalStabilization ? 0 : 1));
		if (!skipTemporalStabilization) push(TEMPORAL_STABILIZATION);
		if (s.splitScreen > 0) push(SPLIT_SCREEN);
		if (s.enableValidation) push(VALIDATION, c => c.setInt(SHARED_CONSTANTS_BYTES, props.hasDiffuse ? 1 : 0, props.hasSpecular ? 1 : 0));
	}

	/** AddSharedConstants_Reblur into a zeroed buffer of the pass's constant size. */
	private sharedConstants(settings: ReblurSettings, bytes: number): Constants {
		const s = this.common;
		const [resourceW, resourceH] = s.resourceSize, [resourceWprev, resourceHprev] = s.resourceSizePrev;
		const [rectW, rectH] = s.rectSize, [rectWprev, rectHprev] = s.rectSizePrev;
		const isRectChanged = rectW !== rectWprev || rectH !== rectHprev;
		const isHistoryReset = s.accumulationMode !== CONTINUE;
		const unproject = f(1 / f(f(0.5 * rectH) * this.projectY));
		const worstResolutionScale = Math.min(f(rectW / resourceW), f(rectH / resourceH));
		const maxBlurRadius = f(settings.maxBlurRadius * worstResolutionScale);
		const diffusePrepassBlurRadius = f(settings.diffusePrepassBlurRadius * worstResolutionScale);
		const specularPrepassBlurRadius = f(settings.specularPrepassBlurRadius * worstResolutionScale);
		const disocclusionThresholdBonus = f(f(1 + this.jitterDelta) / rectH);
		const stabilizationStrength = f(f(settings.maxStabilizedFrameNum) / f(1 + f(settings.maxStabilizedFrameNum)));
		const maxAccumulatedFrameNum = Math.min(settings.maxAccumulatedFrameNum, REBLUR_MAX_HISTORY_FRAME_NUM);
		const [diffCheckerboard, specCheckerboard] = settings.checkerboardMode === CHECKERBOARD_BLACK ? [0, 1] : settings.checkerboardMode === CHECKERBOARD_WHITE ? [1, 0] : [2, 2];
		const blurRadius = Math.max(maxBlurRadius, settings.minBlurRadius);
		const h = settings.hitDistanceParameters, a = settings.antilag, cv = settings.convergence;

		if (bytes !== REBLUR_CONSTANTS_BYTES && bytes !== VALIDATION_CONSTANTS_BYTES) throw new Error(`Unexpected REBLUR constant size ${bytes}`);
		return new Constants(bytes)
			.matrix(this.worldToClip).matrix(this.viewToClip).matrix(this.viewToWorld).matrix(this.worldToViewPrev).matrix(this.worldToClipPrev).matrix(this.worldPrevToWorld)
			.float(...this.rotatorPre, ...this.rotatorMain, ...this.rotatorPost, ...this.frustum, ...this.frustumPrev, ...this.cameraDelta)
			.float(h.A, h.B, h.C, 0, ...this.viewDirection, ...this.viewDirectionPrev)
			.float(...s.motionVectorScale, s.isMotionVectorInWorldSpace ? 1 : 0, ...s.motionVectorBias, 0, cv.s, cv.b, cv.p, 0)
			.float(a.luminanceSigmaScale, a.luminanceSensitivity, resourceW, resourceH, f(1 / resourceW), f(1 / resourceH), f(1 / resourceWprev), f(1 / resourceHprev))
			.float(rectW, rectH, f(1 / rectW), f(1 / rectH), rectWprev, rectHprev, f(rectW / resourceW), f(rectH / resourceH))
			.float(f(rectWprev / resourceWprev), f(rectHprev / resourceHprev), ...s.cameraJitter)
			.uint(...s.printfAt).int(...s.inputRectOrigin, ...s.outputRectOrigin, 0, 0, 0, 0, rectW - 1, rectH - 1)
			.float(f(s.disocclusionThreshold + disocclusionThresholdBonus), f(s.disocclusionThresholdAlternate + disocclusionThresholdBonus),
				s.cameraAttachedReflectionMaterialID, s.strandMaterialID, s.strandThickness, isHistoryReset ? 0 : stabilizationStrength, s.debug,
				this.orthoMode, unproject, s.denoisingRange, settings.planeDistanceSensitivity, this.frameRateScale, this.frameRateScaleSmoothed,
				settings.minBlurRadius, blurRadius, diffusePrepassBlurRadius, specularPrepassBlurRadius,
				isHistoryReset ? 0 : maxAccumulatedFrameNum, isHistoryReset ? 0 : settings.maxFastAccumulatedFrameNum, settings.enableAntiFirefly ? 1 : 0,
				f(settings.lobeAngleFraction * settings.lobeAngleFraction), settings.roughnessFraction, settings.historyFixFrameNum,
				settings.historyFixBasePixelStride, settings.historyFixAlternatePixelStride, s.historyFixAlternatePixelStrideMaterialID,
				lerp(3, settings.fastHistoryClampingSigmaScale, saturate(f(blurRadius / 2))), f(Math.min(rectW, rectH) * unproject),
				settings.usePrepassOnlyForSpecularMotionEstimation ? 0 : 1, s.splitScreen, this.splitScreenPrev, this.checkerboardResolveAccumSpeed,
				s.viewZScale, settings.fireflySuppressorMinRelativeScale, settings.minHitDistanceWeight, settings.minMaterialForDiffuse,
				settings.minMaterialForSpecular, f(1 / Math.max(settings.responsiveAccumulation.roughnessThreshold, f(1e-3))))
			.uint(settings.responsiveAccumulation.minAccumulatedFrameNum, s.isHistoryConfidenceAvailable ? 1 : 0, s.isDisocclusionThresholdMixAvailable ? 1 : 0,
				diffCheckerboard, specCheckerboard, s.frameIndex, isRectChanged ? 1 : 0, isHistoryReset ? 1 : 0, settings.returnHistoryLengthInsteadOfOcclusion ? 1 : 0);
	}
}
