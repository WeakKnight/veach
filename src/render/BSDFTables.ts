// BSDF energy compensation and sheen LTC tables (src/generated/bsdf/BSDFTables.bin, built by
// scripts/build-bsdf-tables.mjs): one 32x32x72 r32float volume, read with textureLoad by
// shaders/Materials/BSDF/EnergyTables.slang.
export const BSDF_TABLE_SIZE = 32;
export const BSDF_TABLE_SLICES = 72;

export async function loadBSDFTables(): Promise<ArrayBuffer> {
	const response = await fetch(new URL('../generated/bsdf/BSDFTables.bin', import.meta.url));
	if (!response.ok) {
		throw new Error(`Failed to load the BSDF tables: ${response.status} ${response.statusText}`);
	}
	const data = await response.arrayBuffer();
	if (data.byteLength !== BSDF_TABLE_SIZE * BSDF_TABLE_SIZE * BSDF_TABLE_SLICES * 4) {
		throw new Error(`BSDF tables have an unexpected size (${data.byteLength} bytes)`);
	}
	return data;
}

export function createBSDFTablesTexture(device: GPUDevice, data: ArrayBuffer): GPUTexture {
	const size = { width: BSDF_TABLE_SIZE, height: BSDF_TABLE_SIZE, depthOrArrayLayers: BSDF_TABLE_SLICES };
	const texture = device.createTexture({
		label: 'bsdfTables',
		size,
		dimension: '3d',
		format: 'r32float',
		usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
	});
	device.queue.writeTexture({ texture }, data, { bytesPerRow: BSDF_TABLE_SIZE * 4, rowsPerImage: BSDF_TABLE_SIZE }, size);
	return texture;
}
