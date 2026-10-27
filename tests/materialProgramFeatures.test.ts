import { describe, expect, it } from 'vitest';
import { Op } from '../src/material/Bytecode';
import type { CompiledMaterial } from '../src/material/Compile';
import { ALL_MATERIAL_OPCODES, materialOpcodeMask, materialPipelineConstants, materialPipelineKey } from '../src/render/MaterialProgramFeatures';

describe('scene material opcode bounds', () => {
	it('includes all three programs and skips extension operands', () => {
		const material = { surface: 0, opacity: 3, emission: 5, code: new Uint32Array([
			Op.Output | (3 << 16), Op.Noise, Op.Magic, Op.Checker, Op.Transform, 0, 0, 0,
			Op.End, 0, 0, 0,
			Op.Transform, 0, 0, 0, Op.End, 0, 0, 0,
			Op.Noise, 0, 0, 0, Op.Magic, 0, 0, 0, Op.Checker, 0, 0, 0, Op.End, 0, 0, 0,
		]) } as CompiledMaterial;
		expect(materialOpcodeMask([{ ...material, opacity: -1, emission: -1 }])).toEqual([1 | (1 << Op.Output), 0]);
		expect(materialOpcodeMask([material])).toEqual([(1 | (1 << Op.Output) | (1 << Op.Transform)) >>> 0, 7]);
	});

	it('includes fallback and unused materials while ignoring absent programs', () => {
		const absent = { surface: -1, opacity: -1, emission: -1, code: new Uint32Array() } as CompiledMaterial;
		const texture = { ...absent, surface: 0, code: new Uint32Array([Op.Texture, 0, 0, 0, Op.End, 0, 0, 0]) };
		expect(materialOpcodeMask([absent, texture])).toEqual([1 | (1 << Op.Texture), 0]);
	});

	it('separates instruction sets in caches and omits absent overrides', () => {
		expect(materialPipelineKey(4, [1, 0])).not.toBe(materialPipelineKey(4, ALL_MATERIAL_OPCODES));
		expect(materialPipelineKey(0, [1, 0])).toBe(materialPipelineKey(0, ALL_MATERIAL_OPCODES));
		expect(materialPipelineConstants(4, [0x80000001, 7])).toEqual({ '0': 0x80000001, '1': 7, '2': 0 });
		expect(materialPipelineConstants(0, ALL_MATERIAL_OPCODES)).toEqual({});
	});

	it('separates operand modes while sharing constant-only modules', () => {
		const keys = [0, 1, 2, 3, 4, 5, 6, 7].map(mode => materialPipelineKey(4, ALL_MATERIAL_OPCODES, mode));
		expect(new Set(keys).size).toBe(8);
		for (const mode of [0, 1, 2, 3, 4, 5, 6, 7]) {
			expect(materialPipelineConstants(4, ALL_MATERIAL_OPCODES, mode)['2']).toBe(mode);
			expect(materialPipelineConstants(0, ALL_MATERIAL_OPCODES, mode)).toEqual({});
			expect(materialPipelineKey(0, ALL_MATERIAL_OPCODES, mode)).toBe('0');
		}
		for (const mode of [-1, 8, 0.5, Number.NaN]) {
			expect(() => materialPipelineKey(4, ALL_MATERIAL_OPCODES, mode)).toThrow('operand');
			expect(() => materialPipelineConstants(0, ALL_MATERIAL_OPCODES, mode)).toThrow('operand');
		}
	});
});
