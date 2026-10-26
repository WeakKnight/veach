// Equirectangular environment map + importance sampling CDF, and the analytic sun.
// Row 0 of the map is the top (+Y); u = atan2(z, x) / 2pi - 0.25 (see Common/Math.slang).
import { luminance, type Vec3 } from '../math/Math';
import type { HDRImage } from '../loaders/HDRLoader';

const f32Scratch = new Float32Array(1);
const u32Scratch = new Uint32Array(f32Scratch.buffer);

export function floatToHalf(value: number): number {
	f32Scratch[0] = value;
	const x = u32Scratch[0];
	const sign = (x >>> 16) & 0x8000;
	const exp = (x >>> 23) & 0xff;
	let mant = x & 0x7fffff;
	if (exp === 0xff) {
		return sign | 0x7c00 | (mant ? 0x200 : 0);
	}
	let e = exp - 127 + 15;
	if (e >= 0x1f) {
		return sign | 0x7bff; // clamp to max finite half
	}
	if (e <= 0) {
		if (e < -10) return sign;
		mant |= 0x800000;
		const shift = 14 - e;
		let half = mant >>> shift;
		if ((mant >>> (shift - 1)) & 1) half++;
		return sign | half;
	}
	let half = sign | (e << 10) | (mant >>> 13);
	if (mant & 0x1000) {
		half++; // round to nearest (carry into the exponent is correct)
		e = (half >>> 10) & 0x1f;
		if (e === 0x1f) return sign | 0x7bff;
	}
	return half;
}

// Conditional CDF rows (W + 1 entries each) followed by the marginal row (H + 1 entries).
// Returns null when the map is black.
export function buildEnvironmentCdf(img: HDRImage): { data: Float32Array<ArrayBuffer>; texWidth: number; texHeight: number } | null {
	const { width: W, height: H, data } = img;
	const texWidth = Math.max(W, H) + 1;
	const texHeight = H + 1;
	const cdf = new Float32Array(texWidth * texHeight);
	const rowSums = new Float64Array(H);
	for (let y = 0; y < H; y++) {
		const cosElevation = Math.cos(((y + 0.5) / H - 0.5) * Math.PI);
		let sum = 0;
		const row = y * texWidth;
		cdf[row] = 0;
		for (let x = 0; x < W; x++) {
			const i = (y * W + x) * 4;
			sum += Math.max(luminance(data[i], data[i + 1], data[i + 2]), 0) * cosElevation;
			cdf[row + x + 1] = sum;
		}
		rowSums[y] = sum;
		for (let x = 1; x <= W; x++) {
			cdf[row + x] = sum > 0 ? cdf[row + x] / sum : x / W;
		}
		cdf[row + W] = 1;
	}
	const marginal = H * texWidth;
	let total = 0;
	for (let y = 0; y < H; y++) {
		total += rowSums[y];
		cdf[marginal + y + 1] = total;
	}
	if (!(total > 0)) {
		return null;
	}
	for (let y = 1; y <= H; y++) {
		cdf[marginal + y] /= total;
	}
	cdf[marginal + H] = 1;
	return { data: cdf, texWidth, texHeight };
}

export class Environment {
	private constructor(
		readonly texture: GPUTexture,
		readonly cdfTexture: GPUTexture,
		readonly width: number,
		readonly height: number,
		readonly importance: boolean,
	) {}

	readonly view = () => this.texture.createView();
	readonly cdfView = () => this.cdfTexture.createView();

	static create(device: GPUDevice, img: HDRImage): Environment {
		const { width, height, data } = img;
		const half = new Uint16Array(width * height * 4);
		for (let i = 0; i < half.length; i++) {
			half[i] = floatToHalf(data[i]);
		}
		const texture = device.createTexture({
			label: 'environment',
			size: [width, height],
			format: 'rgba16float',
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
		});
		device.queue.writeTexture({ texture }, half, { bytesPerRow: width * 8 }, [width, height]);

		const cdf = buildEnvironmentCdf(img);
		const cdfW = cdf?.texWidth ?? 1;
		const cdfH = cdf?.texHeight ?? 1;
		const cdfTexture = device.createTexture({
			label: 'environmentCdf',
			size: [cdfW, cdfH],
			format: 'r32float',
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
		});
		device.queue.writeTexture({ texture: cdfTexture }, cdf?.data ?? new Float32Array([0]), { bytesPerRow: cdfW * 4 }, [cdfW, cdfH]);
		return new Environment(texture, cdfTexture, width, height, cdf !== null);
	}

	// Map and CDF written by compute passes (AtmosphereBaker). Black rows get a uniform CDF, so
	// importance sampling stays valid without knowing the contents on the host.
	static createStorage(device: GPUDevice, width: number, height: number): Environment {
		const texture = device.createTexture({
			label: 'environment',
			size: [width, height],
			format: 'rgba16float',
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.COPY_SRC,
		});
		const cdfTexture = device.createTexture({
			label: 'environmentCdf',
			size: [Math.max(width, height) + 1, height + 1],
			format: 'r32float',
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.COPY_SRC,
		});
		return new Environment(texture, cdfTexture, width, height, true);
	}

	destroy(): void {
		this.texture.destroy();
		this.cdfTexture.destroy();
	}
}

export interface SunSettings {
	enabled: boolean;
	elevation: number; // degrees above the horizon
	azimuth: number; // degrees, 0 = +Z, 90 = +X
	// Irradiance at normal incidence outside the atmosphere. With the procedural sky it also lights
	// the sky, and the atmosphere attenuates and reddens the sun; pi makes a white Lambertian under
	// an overhead sun (before the atmosphere) reflect radiance 1.
	irradiance: number;
	angularDiameter: number; // degrees
	color: Vec3;
}

export function defaultSunSettings(): SunSettings {
	return { enabled: true, elevation: 45, azimuth: 30, irradiance: Math.PI, angularDiameter: 1, color: [1, 1, 1] };
}

// Unit vector toward the sun.
export function sunDirection(sun: SunSettings): Vec3 {
	const el = (sun.elevation * Math.PI) / 180;
	const az = (sun.azimuth * Math.PI) / 180;
	return [Math.cos(el) * Math.sin(az), Math.sin(el), Math.cos(el) * Math.cos(az)];
}

export function sunUniforms(sun: SunSettings, transmittance: Vec3 = [1, 1, 1]): { direction: Vec3; cosAngle: number; radiance: Vec3; solidAngle: number } {
	const halfAngle = Math.max((sun.angularDiameter * Math.PI) / 360, 1e-4);
	const cosAngle = Math.cos(halfAngle);
	const solidAngle = 2 * Math.PI * (1 - cosAngle);
	const scale = sun.irradiance / solidAngle;
	const radiance: Vec3 = [sun.color[0] * transmittance[0] * scale, sun.color[1] * transmittance[1] * scale, sun.color[2] * transmittance[2] * scale];
	return { direction: sunDirection(sun), cosAngle, radiance, solidAngle };
}
