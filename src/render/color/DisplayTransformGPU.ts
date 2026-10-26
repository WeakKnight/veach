import { displayTransformUniforms, type LUTDisplayTransform } from './LUT';

export interface DisplayTransformGPU {
	texture: GPUTexture;
	uniforms: GPUBuffer;
	destroy(): void;
}

/** The caller validates the descriptor before calling; default resources are tiny and inert. */
export function createDisplayTransformGPU(device: GPUDevice, desc: LUTDisplayTransform | null): DisplayTransformGPU {
	const size = desc?.lut.size ?? 2;
	if (size > device.limits.maxTextureDimension3D) throw new Error('LUT exceeds the GPU 3D texture limit');
	const texture = device.createTexture({ label: 'userDisplayLUT', dimension: '3d', size: [size, size, size], format: 'rgba32float', usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST });
	let uniforms: GPUBuffer | undefined;
	try {
		uniforms = device.createBuffer({ label: 'displayTransform', size: 64, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
		const rgba = new Float32Array(size ** 3 * 4);
		if (desc) for (let i = 0; i < size ** 3; i++) rgba.set(desc.lut.values.subarray(i * 3, i * 3 + 3), i * 4);
		device.queue.writeTexture({ texture }, rgba, { bytesPerRow: size * 16, rowsPerImage: size }, [size, size, size]);
		device.queue.writeBuffer(uniforms, 0, displayTransformUniforms(desc));
		const buffer = uniforms;
		return { texture, uniforms: buffer, destroy: () => { texture.destroy(); buffer.destroy(); } };
	} catch (error) {
		texture.destroy(); uniforms?.destroy(); throw error;
	}
}
