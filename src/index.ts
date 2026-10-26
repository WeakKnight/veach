/// <reference types="@webgpu/types" preserve="true" />
// Public API for `@tianyuliwiwo/veach`. Add supported exports here deliberately and document them in
// docs/PublicAPI.md. Implementation paths are not package entry points.

// Renderer lifecycle, settings and progress.
export {
	LocalExposureMethod,
	Renderer,
	defaultRenderSettings,
	isPresentationSetting,
	type InitProgress,
	type InitStage,
	type RenderSettings,
	type RendererCreateOptions,
	type RendererStats,
} from './render/Renderer';
export { AutoExposureMethod, LuminanceMethod, exponentialAdaptationM, histogramLogMin, luminanceWeights, type ExposureStats } from './render/AutoExposure';
export type { OIDNDenoiserOptions, DenoisingState } from './render/denoise/OIDNDenoiser';
export type { DenoisingInputs } from './render/denoise/OIDNGuides';
export { contrastScaleToEV, evaluateCurve, type CurveKeys } from './render/LocalExposureCurve';
// Camera and environment controls.
export { Camera, OrbitController } from './render/Camera';
export { DebugMode, Tonemapper } from './render/GpuLayout';
export { defaultSunSettings, sunDirection, type SunSettings } from './render/Environment';
export type { SceneStats } from './render/GpuScene';
// Asset loading and application-owned scene descriptions.
export { loadGLTF, loadGLTFFromFiles, parseGLTF, type GLTFLoadOptions } from './loaders/GLTFLoader';
export { loadHDR, parseHDR, type HDRImage } from './loaders/HDRLoader';
export {
	AlphaMode,
	WrapMode,
	defaultMaterial,
	sceneBounds,
	type CameraDesc,
	type InstanceDesc,
	type LightDesc,
	type MaterialDesc,
	type MaterialTextures,
	type MeshDesc,
	type SceneDesc,
	type TextureBinding,
	type TextureSource,
} from './scene/Scene';

// Advanced utilities retained as part of the public API.
export { EOTF, OutputTransform, SDR_REC709_SRGB, type Chromaticities, type OutputTransformDesc } from './render/aces/ACES2';
export { TONE_LUT_SIZE, bakeToneLUT, packToneLUT, sampleToneLUT, type ToneLUT } from './render/aces/ToneLUT';
export { parseLUT3D, parseCubeLUT, validateLUT3D, sampleLUT3D, evaluateDisplayTransform,
	type LUT3D, type BinaryLUTOptions, type LUTDisplayTransform, type ColorPrimaries, type InputTransfer, type DisplayTransfer } from './render/color/LUT';
export { BUILTIN_LUTS, loadBuiltinLUT, type BuiltinLUTId, type BuiltinLUTInfo,
	type DisplayTransform, type BuiltinDisplayTransform, type DisplayTransformState, type DisplayTransformResult } from './render/color/BuiltinLUTs';
export { TinyBVH, BuildQuality } from './accel/TinyBVH';
export { mat4, vec3, type Mat4, type Vec3 } from './math/Math';
