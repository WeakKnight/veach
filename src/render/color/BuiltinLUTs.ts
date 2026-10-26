import { parseLUT3D, type LUTDisplayTransform } from './LUT';

const loaders = {
	provia: () => import('./looks/provia'),
	astia: () => import('./looks/astia'),
	velvia: () => import('./looks/velvia'),
	classic_chrome: () => import('./looks/classic_chrome'),
	reala_ace: () => import('./looks/reala_ace'),
	pro_negstd: () => import('./looks/pro_negstd'),
	classic_neg: () => import('./looks/classic_neg'),
	eterna: () => import('./looks/eterna'),
	eterna_bb: () => import('./looks/eterna_bb'),
	acros: () => import('./looks/acros'),
};

export type BuiltinLUTId = keyof typeof loaders;
export interface BuiltinLUTInfo { readonly id: BuiltinLUTId; readonly name: string }
export const BUILTIN_LUTS: readonly BuiltinLUTInfo[] = Object.freeze(([
	['provia', 'PROVIA'], ['astia', 'ASTIA'], ['velvia', 'Velvia'], ['classic_chrome', 'CLASSIC CHROME'],
	['reala_ace', 'REALA ACE'], ['pro_negstd', 'PRO Neg.Std'], ['classic_neg', 'CLASSIC Neg.'],
	['eterna', 'ETERNA'], ['eterna_bb', 'ETERNA BB'], ['acros', 'ACROS'],
] as const).map(([id, name]) => Object.freeze({ id, name })));

export interface BuiltinDisplayTransform { type: 'builtin'; preset: BuiltinLUTId }
export type DisplayTransform = LUTDisplayTransform | BuiltinDisplayTransform;
export interface DisplayTransformState {
	readonly type: 'default' | 'builtin' | 'lut';
	readonly preset?: BuiltinLUTId;
	/** LUT transforms suppress local exposure without overwriting the user's settings. */
	readonly localExposure: 'settings' | 'off';
}
export interface DisplayTransformResult extends DisplayTransformState { readonly applied: boolean }

/** Only the selected preset's data is loaded. Each call returns independent mutable LUT data. */
export async function loadBuiltinLUT(id: BuiltinLUTId): Promise<LUTDisplayTransform> {
	if (!Object.hasOwn(loaders, id)) throw new Error(`Unknown built-in LUT: ${id}`);
	const { default: url } = await loaders[id]();
	const response = await fetch(url);
	if (!response.ok) throw new Error(`Failed to load built-in LUT ${id}: ${response.status}`);
	const lut = parseLUT3D(await response.arrayBuffer(), { format: 'float32-le', size: 33, layout: 'rgb-r-fastest' });
	return {
		type: 'lut', lut,
		input: { primaries: 'rec2020', transfer: 'f-log2' },
		// Matches light-lab's stated viewing assumption, not a claim about all vendor LUTs.
		output: { primaries: 'rec709', transfer: { type: 'gamma', exponent: 2.2 } },
		interpolation: 'trilinear', outOfDomain: 'clamp', localExposure: 'off',
	};
}
