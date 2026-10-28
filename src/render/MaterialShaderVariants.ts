import { materialStackVariants, type MaterialStackVariantData } from '../generated/shaders/MaterialStackVariants';

export const MATERIAL_STACK_CAPACITIES = [0, 1, 2, 4, 8, 16] as const;
export type MaterialStackCapacity = typeof MATERIAL_STACK_CAPACITIES[number];

export function materialStackCapacity(required: number): MaterialStackCapacity {
	if (!Number.isInteger(required) || required < 0 || required > 16) throw new Error(`Invalid material stack requirement: ${required}`);
	return MATERIAL_STACK_CAPACITIES.find(capacity => capacity >= required)!;
}

// Restore exact Slang output from generated edits, sharing the large common module in the bundle.
// WGSL pipeline overrides cannot size function-scope arrays, so these are shader-module variants.
export function specializeMaterialShader(code: string, program: 'PathTracing' | 'Wavefront', capacity: MaterialStackCapacity): string {
	return restoreMaterialShaderVariant(code, capacity, materialStackVariants[program]);
}

export function restoreMaterialShaderVariant(code: string, capacity: MaterialStackCapacity, data: MaterialStackVariantData): string {
	const source = code.replaceAll('\r\n', '\n');
	if (capacity === 16) return source;
	let checksum = 2166136261;
	for (let i = 0; i < source.length; i++) checksum = Math.imul(checksum ^ source.charCodeAt(i), 16777619) >>> 0;
	if (source.length !== data.length || checksum !== data.checksum) throw new Error('Stale material shader variants; run build:shaders');
	const variant = data.variants[capacity];
	if (!variant) throw new Error(`Unsupported material stack capacity: ${capacity}`);
	const parts: string[] = [];
	let cursor = 0;
	for (const [offset, oldLength, newText] of variant.edits) {
		if (offset < cursor || oldLength < 0 || offset + oldLength > source.length) throw new Error('Invalid generated material shader variant');
		parts.push(source.slice(cursor, offset), newText);
		cursor = offset + oldLength;
	}
	parts.push(source.slice(cursor));
	return parts.join('');
}
