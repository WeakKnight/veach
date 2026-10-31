// FidelityFX SSSR settings, constants and matrices (docs/Sssr.md). SssrConstants mirrors the struct in
// shaders/Sssr/SssrCallbacks.hlsli (512 bytes, matrices column-major).
import { mat4, vec3, type Mat4, type Vec3 } from '../../math/Math';

export interface SssrCamera { position: Vec3; right: Vec3; up: Vec3; forward: Vec3 }

/** FidelityFX SSSR / reflection denoiser parameters (FfxSssrDispatchDescription names). */
export interface SssrParameters {
	temporalStabilityFactor: number;
	depthBufferThickness: number; // view-space distance, scene units
	roughnessThreshold: number; // squared (alpha) roughness: rougher surfaces use the environment fallback only
	varianceThreshold: number;
	maxTraversalIntersections: number;
	minTraversalOccupancy: number;
	mostDetailedMip: number;
	samplesPerQuad: 1 | 2 | 4;
	temporalVarianceGuidedTracingEnabled: boolean;
}

// The FidelityFX sample's defaults, except the roughness threshold: Veach's interiors are lit indirectly,
// and the unoccluded environment fallback leaks there, so most surfaces trace screen-space rays.
export const SSSR_DEFAULTS: SssrParameters = {
	temporalStabilityFactor: 0.7,
	depthBufferThickness: 0.015,
	roughnessThreshold: 0.6,
	varianceThreshold: 0,
	maxTraversalIntersections: 128,
	minTraversalOccupancy: 4,
	mostDetailedMip: 0,
	samplesPerQuad: 1,
	temporalVarianceGuidedTracingEnabled: true,
};

export const SSSR_CONSTANTS_BYTES = 512;
export const SSSR_NEAR_PLANE = 0.01;
// FidelityFX: the input depth plus 6 downsampled mips at most.
export const sssrDepthMips = (width: number, height: number) => Math.max(1, Math.min(7, Math.ceil(Math.log2(Math.max(width, height)))));

export interface SssrMatrices { view: Mat4; projection: Mat4; viewProjection: Mat4 }

/**
 * View space as NRD's (X right, Y up, Z forward); inverted infinite projection: depth = near / viewZ.
 * `jitter` in [0, 1] is the frame's film jitter: the projection maps pixel centers to the jittered rays
 * the path tracer traced, so FidelityFX's (pixel + 0.5) / size UVs reconstruct the traced depth.
 */
export function sssrMatrices(camera: SssrCamera, jitter: readonly [number, number], width: number, height: number, near = SSSR_NEAR_PLANE): SssrMatrices {
	const x = vec3.normalize(camera.right), y = vec3.normalize(camera.up), z = vec3.normalize(vec3.cross(camera.up, camera.right));
	const view = new Float32Array(16);
	[x, y, z].forEach((axis, row) => {
		for (let c = 0; c < 3; c++) view[c * 4 + row] = axis[c];
		view[12 + row] = -vec3.dot(axis, camera.position);
	});
	view[15] = 1;
	// A pixel ray is forward + ndc.x * right + ndc.y * up (off-axis host projections included).
	const f = [vec3.dot(camera.forward, x), vec3.dot(camera.forward, y), vec3.dot(camera.forward, z)];
	const sx = vec3.length(camera.right), sy = vec3.length(camera.up);
	// The traced ray of pixel p is at NDC ((p + jitter) / size) * (2, -2) + (-1, 1); FidelityFX samples p + 0.5.
	const dx = (2 * (jitter[0] - 0.5)) / width, dy = (-2 * (jitter[1] - 0.5)) / height;
	const projection = new Float32Array(16);
	projection[0] = f[2] / sx; projection[8] = -f[0] / sx - dx;
	projection[5] = f[2] / sy; projection[9] = -f[1] / sy - dy;
	projection[14] = near;
	projection[11] = 1;
	return { view, projection, viewProjection: mat4.multiply(projection, view) };
}

function inverse(m: Mat4): Mat4 {
	const r = mat4.invert(m);
	if (!r) throw new Error('SSSR camera matrix is singular');
	return r;
}

export interface SssrFrameConstants {
	current: SssrMatrices;
	previous: SssrMatrices;
	width: number;
	height: number;
	frameIndex: number;
	parameters: SssrParameters;
	iblFactor: number; // environment intensity * pre-exposure (0 without an environment)
	envRotation: number; // radians
	region: number; // float4 offset of the NRD split region
	debug: number; // Apply: 0 final, 1 reflections only, 2 color input only, 3 camera reconstruction error
	preExposure: number;
	sceneColorHistory: boolean; // the previous frame's scene color is available
	jitterDelta: readonly [number, number]; // current minus previous film jitter, pixels
}

export function packSssrConstants(c: SssrFrameConstants): ArrayBuffer {
	const data = new ArrayBuffer(SSSR_CONSTANTS_BYTES), f = new Float32Array(data), u = new Uint32Array(data);
	const { current, previous, parameters: p } = c;
	[inverse(current.viewProjection), current.projection, inverse(current.projection), current.view, inverse(current.view), previous.viewProjection]
		.forEach((m, i) => f.set(m, i * 16));
	u.set([c.width, c.height], 96); f.set([1 / c.width, 1 / c.height], 98);
	f.set([1 / c.width, 1 / c.height, 1, 0], 100); // motion vector scale (pixels -> UV), normals unpack mul / add
	u.set([0, 1], 104); f.set([c.iblFactor, p.temporalStabilityFactor], 106); // roughness channel, perceptual roughness
	f.set([p.depthBufferThickness, p.roughnessThreshold, p.varianceThreshold], 108); u[111] = c.frameIndex >>> 0;
	u.set([p.maxTraversalIntersections, p.minTraversalOccupancy, p.mostDetailedMip, p.samplesPerQuad, Number(p.temporalVarianceGuidedTracingEnabled), c.region], 112);
	f[118] = c.envRotation; u[119] = c.debug;
	f[120] = SSSR_NEAR_PLANE; f[121] = c.preExposure; u[122] = Number(c.sceneColorHistory);
	f.set(c.jitterDelta, 124);
	return data;
}

/**
 * Split-sum GGX environment BRDF (Karis 2013) with height-correlated Smith masking: specular = F0 * x + y,
 * by (N.V, perceptual roughness) at texel centers, alpha = roughness^2. Row-major RG, `size` x `size`.
 */
export function brdfLut(size = 32, samples = 512): Float32Array<ArrayBuffer> {
	const out = new Float32Array(size * size * 2);
	const radicalInverse = (i: number) => {
		let bits = i >>> 0;
		bits = ((bits << 16) | (bits >>> 16)) >>> 0;
		bits = (((bits & 0x55555555) << 1) | ((bits & 0xaaaaaaaa) >>> 1)) >>> 0;
		bits = (((bits & 0x33333333) << 2) | ((bits & 0xcccccccc) >>> 2)) >>> 0;
		bits = (((bits & 0x0f0f0f0f) << 4) | ((bits & 0xf0f0f0f0) >>> 4)) >>> 0;
		bits = (((bits & 0x00ff00ff) << 8) | ((bits & 0xff00ff00) >>> 8)) >>> 0;
		return bits / 4294967296;
	};
	for (let j = 0; j < size; j++) {
		const roughness = (j + 0.5) / size, alpha = Math.max(roughness * roughness, 1e-4), a2 = alpha * alpha;
		for (let i = 0; i < size; i++) {
			const nv = (i + 0.5) / size, vx = Math.sqrt(1 - nv * nv), vz = nv;
			const lambdaV = (Math.sqrt(a2 + (1 - a2) * nv * nv) - nv) / (2 * nv);
			let scale = 0, bias = 0;
			for (let s = 0; s < samples; s++) {
				// GGX half-vector sample, pdf(h) = D * N.H.
				const u1 = (s + 0.5) / samples, u2 = radicalInverse(s);
				const cosH = Math.sqrt((1 - u1) / (1 + (a2 - 1) * u1)), sinH = Math.sqrt(1 - cosH * cosH), phi = 2 * Math.PI * u2;
				const hx = sinH * Math.cos(phi), hz = cosH;
				const vh = vx * hx + vz * hz;
				const lz = 2 * vh * hz - vz;
				if (lz <= 0 || vh <= 0) continue;
				const nl = lz;
				const lambdaL = (Math.sqrt(a2 + (1 - a2) * nl * nl) - nl) / (2 * nl);
				const g = 1 / (1 + lambdaV + lambdaL);
				// f * N.L / pdf(l) without F, with pdf(l) = D * N.H / (4 V.H).
				const weight = (g * vh) / (hz * nv);
				const fc = (1 - vh) ** 5;
				scale += weight * (1 - fc);
				bias += weight * fc;
			}
			out[(j * size + i) * 2] = scale / samples;
			out[(j * size + i) * 2 + 1] = bias / samples;
		}
	}
	return out;
}
