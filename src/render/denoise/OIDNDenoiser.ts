import type { UNet } from 'oidn-webgpu';

export interface OIDNDenoiserOptions {
	type: 'oidn';
	/** Optional URL or TZA bytes. Omit to use the bundled HDR albedo + normal model. */
	weights?: string | ArrayBuffer;
	maxTileSize?: number;
	precision?: 'auto' | 'fp16' | 'fp32';
}

export interface DenoisingState {
	readonly status: 'disabled' | 'loading' | 'idle' | 'denoising' | 'ready' | 'error';
	readonly progress: number;
	readonly samples: number;
	readonly durationMs?: number;
	readonly error?: string;
}

export function validateDenoiserOptions(options: OIDNDenoiserOptions): OIDNDenoiserOptions {
	if (options.type !== 'oidn' || (options.weights !== undefined && !(typeof options.weights === 'string' && options.weights.trim() || options.weights instanceof ArrayBuffer && options.weights.byteLength > 0))) throw new Error('OIDN weights must be a URL or nonempty TZA ArrayBuffer');
	const size = options.maxTileSize ?? 256;
	if (!Number.isInteger(size) || size < 32 || size > 512 || size % 16 !== 0) throw new Error('OIDN maxTileSize must be a multiple of 16 from 32 to 512');
	if (!['auto', 'fp16', 'fp32'].includes(options.precision ?? 'auto')) throw new Error('Invalid OIDN precision');
	return { ...options, maxTileSize: size, weights: typeof options.weights === 'string' ? options.weights : options.weights?.slice(0) };
}

/** Lazy inference and model data; disabled renderers download neither. */
export async function loadOIDN(device: GPUDevice, options: OIDNDenoiserOptions, signal: AbortSignal): Promise<UNet> {
	const { parseTZA, UNet } = await import('oidn-webgpu');
	signal.throwIfAborted();
	let bytes = options.weights ?? (await import('./BuiltinOIDN')).default;
	signal.throwIfAborted();
	if (typeof bytes === 'string') {
		const response = await fetch(bytes, { signal });
		if (!response.ok) throw new Error(`OIDN weights: HTTP ${response.status}`);
		bytes = await response.arrayBuffer();
	}
	signal.throwIfAborted();
	const model = new UNet(parseTZA(bytes), device, { hdr: true, aux: true, hdrTransfer: 'pu',
		maxTileSize: options.maxTileSize, precision: options.precision ?? 'auto', dynamicTile: false });
	try { await model.prepare(); return model; }
	catch (error) { model.dispose(); throw error; }
}
