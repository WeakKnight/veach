// Loaded only when the internal opaque-megakernel experiment is requested.
import source from '../generated/shaders/PathTracingOpaque.wgsl?raw';
import { opaqueMaterialStackVariants } from '../generated/shaders/OpaqueMaterialStackVariants';
import { restoreMaterialShaderVariant, type MaterialStackCapacity } from './MaterialShaderVariants';

export function opaqueMaterialShader(capacity: MaterialStackCapacity): string {
	return restoreMaterialShaderVariant(source, capacity, opaqueMaterialStackVariants);
}
