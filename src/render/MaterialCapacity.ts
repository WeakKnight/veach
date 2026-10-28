import { AlphaMode } from '../scene/Scene';
import type { CompiledMaterial } from '../material/Compile';

export const MATERIAL_STACK_CAPACITIES = [0, 1, 2, 4, 8, 16] as const;
export type MaterialStackCapacity = typeof MATERIAL_STACK_CAPACITIES[number];

export function materialStackCapacity(required: number): MaterialStackCapacity {
	if (!Number.isInteger(required) || required < 0 || required > 16) throw new Error(`Invalid material stack requirement: ${required}`);
	return MATERIAL_STACK_CAPACITIES.find(capacity => capacity >= required)!;
}

// Masked emitters evaluate opacity as well as emission during NEE.
export function materialLightCapacity(material: CompiledMaterial): MaterialStackCapacity {
	return materialStackCapacity(Math.max(material.programStackSizes.emission,
		material.alphaMode === AlphaMode.Mask ? material.programStackSizes.opacity : 0));
}

export function materialShadeCapacities(materials: readonly CompiledMaterial[], separateLight = false): MaterialStackCapacity[] {
	const emission = separateLight ? 0 : Math.max(0, ...materials.filter(m => m.emissive).map(materialLightCapacity));
	return materials.map(m => materialStackCapacity(Math.max(m.programStackSizes.surface, emission)));
}
