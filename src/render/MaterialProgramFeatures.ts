import type { CompiledMaterial } from '../material/Compile';
import { programOps } from '../material/Interpreter';
import type { MaterialStackCapacity } from './MaterialShaderVariants';

export type MaterialOpcodeMask = readonly [number, number];
export const ALL_MATERIAL_OPCODES: MaterialOpcodeMask = [0xffffffff, 0xffffffff];

// Include all programs, unused materials and the fallback, matching the stack bound.
// Walking decoded instructions avoids interpreting extension operands as opcodes.
export function materialOpcodeMask(materials: readonly CompiledMaterial[]): MaterialOpcodeMask {
	const mask: [number, number] = [0, 0];
	for (const material of materials) {
		for (const offset of [material.surface, material.opacity, material.emission]) {
			if (offset < 0) continue;
			for (const opcode of programOps(material, offset)) {
				if (opcode < 0 || opcode >= 64) throw new Error(`Unsupported material opcode: ${opcode}`);
				mask[opcode >>> 5] = (mask[opcode >>> 5] | (1 << (opcode & 31))) >>> 0;
			}
		}
	}
	return mask;
}

export function materialPipelineKey(capacity: MaterialStackCapacity, mask: MaterialOpcodeMask): string {
	return capacity === 0 ? '0' : `${capacity}/${mask[0]}/${mask[1]}`;
}

// IDs match MaterialProgram.slang. Capacity zero contains no guarded opcode cases,
// so Slang removes these override declarations and they must not be supplied.
export function materialPipelineConstants(capacity: MaterialStackCapacity, mask: MaterialOpcodeMask): Record<string, number> {
	return capacity === 0 ? {} : { '0': mask[0], '1': mask[1] };
}
