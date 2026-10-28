import type { CompiledMaterial } from '../material/Compile';

export const MATERIAL_STACK_CAPACITIES = [0, 1, 2, 4, 8, 16] as const;
export type MaterialStackCapacity = typeof MATERIAL_STACK_CAPACITIES[number];

export function materialStackCapacity(required: number): MaterialStackCapacity {
	if (!Number.isInteger(required) || required < 0 || required > 16) throw new Error(`Invalid material stack requirement: ${required}`);
	return MATERIAL_STACK_CAPACITIES.find(capacity => capacity >= required)!;
}

// NEE evaluates other materials' emission programs inside the same shading kernel.
export function materialShadeCapacities(materials: readonly CompiledMaterial[]): MaterialStackCapacity[] {
	const emission = Math.max(0, ...materials.map(m => m.programStackSizes.emission));
	return materials.map(m => materialStackCapacity(Math.max(m.programStackSizes.surface, emission)));
}
