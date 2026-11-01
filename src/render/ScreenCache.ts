// Screen-space L1 radiance cache of realtime SSSR frames (docs/ScreenCache.md): constants of
// shaders/Passes/WavefrontScreenCache.slang. The textures are the previous frame's SSSR inputs (SssrReflections.history).
import type { Mat4 } from '../math/Math';

export const SCREEN_CACHE_CONSTANTS_BYTES = 160;
export const SCREEN_CACHE_TRACE = 1;
export const SCREEN_CACHE_HITS = 2;

export interface ScreenCacheSettings {
	trace: boolean; // screen trace of the primary diffuse continuation before the BVH
	hits: boolean; // previous-frame lookups at traced hits
	thickness: number; // accepted distance behind the depth buffer, fraction of view depth
	iterations: number; // hierarchical march steps
	confidence: number; // history confidence, scales every lookup's acceptance probability
}

export const SCREEN_CACHE_DEFAULTS: ScreenCacheSettings = { trace: true, hits: true, thickness: 0.03, iterations: 48, confidence: 0.95 };

/** The previous frame's SSSR inputs, read before this frame's SSSR overwrites them. */
export interface ScreenCacheHistory {
	depth: GPUTexture; // closest-depth hierarchy (r32float mips): near / viewZ
	normal: GPUTexture; // rgba16float world normal, w: roughness (+2 metal), -1 emissive
	color: GPUTexture; // rgba16float linear scene color
	previous: Mat4; // the previous frame's world -> clip (column-major)
	near: number;
}

export interface ScreenCacheFrame extends ScreenCacheHistory {
	current: Mat4; // this frame's world -> clip (column-major)
	mode: number; // SCREEN_CACHE_TRACE | SCREEN_CACHE_HITS
	settings: ScreenCacheSettings;
}

/** ScreenCacheConstants: matrices as rows, so the shader needs no matrix layout convention. */
export function packScreenCacheConstants(frame: ScreenCacheFrame | null): ArrayBuffer {
	const data = new ArrayBuffer(SCREEN_CACHE_CONSTANTS_BYTES), f = new Float32Array(data), u = new Uint32Array(data);
	if (!frame) return data;
	const rows = (m: Mat4, offset: number) => {
		for (let r = 0; r < 4; r++) for (let c = 0; c < 4; c++) f[offset + r * 4 + c] = m[c * 4 + r];
	};
	rows(frame.previous, 0);
	rows(frame.current, 16);
	u.set([frame.mode, frame.depth.width, frame.depth.height, frame.depth.mipLevelCount], 32);
	const s = frame.settings;
	f.set([frame.near, Math.max(1e-4, s.thickness), Math.max(1, Math.min(256, Math.round(s.iterations))), Math.max(0, Math.min(1, s.confidence))], 36);
	return data;
}
