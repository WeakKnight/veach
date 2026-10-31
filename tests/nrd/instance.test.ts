// Phase 1 of the TypeScript NRD planner migration: instance creation matches the wasm runtime.
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { DENOISERS } from '../../src/render/denoise/NrdConfig.mjs';
import { BLOBS, NrdInstance, REBLUR_CONSTANTS_BYTES } from '../../src/render/denoise/nrd/Instance';
import { wasmModule } from './oracle';
import { createInstance } from './wasm';

const shaders = join(__dirname, '../../ThirdParty/NRD/Shaders');

// C++ layout of NRD_CONSTANT lists: members are declared in decreasing alignment, the struct is 16-aligned.
const SIZES: Record<string, number> = { float4x4: 64, float4: 16, float2: 8, int2: 8, uint2: 8, float: 4, int: 4, uint: 4 };
function constantBytes(constants: string): number {
	const bytes = [...constants.matchAll(/NRD_CONSTANT\(\s*(\w+)\s*,\s*\w+\s*\)/g)].reduce((sum, [, type]) => {
		if (!(type in SIZES)) throw new Error(`Unknown constant type ${type}`);
		return sum + SIZES[type];
	}, 0);
	return Math.ceil(bytes / 16) * 16;
}

describe('NRD TypeScript instance', () => {
	for (const mode of ['radiance', 'sh', 'diffuse-sh'] as const) {
		it(`matches the wasm instance description: ${mode}`, async () => {
			const { desc } = createInstance(await wasmModule(), mode);
			expect(new NrdInstance(DENOISERS[mode]).desc).toEqual(desc);
		});
	}

	it('uses the thread group and constant sizes of the vendored shaders', () => {
		const read = (file: string) => readFileSync(join(shaders, file), 'utf8').replaceAll('\r\n', '\n');
		const shared = read('REBLUR_Config.hlsli').match(/#define REBLUR_SHARED_CONSTANTS \\\n([\s\S]*?)\n\n/)![1];
		expect(constantBytes(shared)).toBe(REBLUR_CONSTANTS_BYTES);
		for (const [blob, [x, y, bytes]] of Object.entries(BLOBS)) {
			const text = read(readdirSync(shaders).find(f => f === `${blob}.resources.hlsli`)!);
			expect([Number(text.match(new RegExp(`#define ${blob}GroupX\\s+(\\d+)`))![1]), Number(text.match(new RegExp(`#define ${blob}GroupY\\s+(\\d+)`))![1])], blob).toEqual([x, y]);
			const block = text.match(/NRD_CONSTANTS_START\(\s*\w+\s*\)([\s\S]*?)NRD_CONSTANTS_END/)![1].replace('REBLUR_SHARED_CONSTANTS', shared);
			expect(constantBytes(block), blob).toBe(bytes);
		}
	});
});
