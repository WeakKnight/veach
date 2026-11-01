// Builds the FidelityFX FSR 3.1.4 upscaler integration into src/generated/fsr3 (docs/Fsr3.md):
// shaders/Fsr3/Fsr3Passes.slang -> WGSL, one module per pass (Fsr3Shaders.ts). The FidelityFX GPU headers are used
// unmodified from ThirdParty/FidelityFX/gpu; Veach's callbacks (shaders/Fsr3/Fsr3Callbacks.hlsli) replace the
// HLSL resource callbacks. Permutation (ffx_fsr3upscaler.cpp getPipelinePermutationFlags with Veach's context flags
// HIGH_DYNAMIC_RANGE | DEPTH_INVERTED | DEPTH_INFINITE | AUTO_EXPOSURE, render-size motion vectors, no LUT on
// wave32 hardware): HDR input, low resolution motion vectors, inverted depth, reference Lanczos reprojection, FP32.
// slangc: SLANGC, else tools/slang (tools/slang/README.md).
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = join(root, 'src', 'generated', 'fsr3');
const slangc = findSlangc();

// Pass name -> FSR3_PASS value (Fsr3Passes.slang).
const PASSES = {
	PrepareInputs: 1, LumaPyramid: 2, LumaPyramidTail: 3, ShadingChangePyramid: 4, ShadingChange: 5, PrepareReactivity: 6,
	LumaInstability: 7, Accumulate: 8, AccumulateSharpen: 9, Rcas: 10, VeachInputs: 11, VeachOutput: 12,
};
const DEFINES = ['FFX_GPU=1', 'FFX_HLSL=1', 'FFX_HALF=0', 'FFX_HLSL_SM=62',
	'FFX_FSR3UPSCALER_OPTION_HDR_COLOR_INPUT=1', 'FFX_FSR3UPSCALER_OPTION_LOW_RESOLUTION_MOTION_VECTORS=1',
	'FFX_FSR3UPSCALER_OPTION_JITTERED_MOTION_VECTORS=0', 'FFX_FSR3UPSCALER_OPTION_INVERTED_DEPTH=1',
	'FFX_FSR3UPSCALER_OPTION_REPROJECT_USE_LANCZOS_TYPE=0', 'FFX_FSR3UPSCALER_OPTION_UPSAMPLE_USE_LANCZOS_TYPE=2'];

const shaders = Object.fromEntries(Object.entries(PASSES).map(([name, pass]) => {
	const wgsl = compile([...DEFINES, `FSR3_PASS=${pass}`], name);
	const readWrite = [...wgsl.matchAll(/texture_storage_2d<(\w+), read_write>/g)].map(m => m[1]);
	if (readWrite.some(format => format !== 'r32float')) throw new Error(`[build-fsr3] ${name}: read_write storage texture outside core WebGPU (${readWrite})`);
	return [name, wgsl];
}));
mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, 'Fsr3Shaders.ts'), '// Generated from shaders/Fsr3/Fsr3Passes.slang and the AMD FidelityFX SDK (MIT, ThirdParty/FidelityFX)\n' +
	'// by scripts/build-fsr3.mjs. Do not edit.\n' +
	`export const fsr3Shaders: Record<string, string> = ${JSON.stringify(shaders, null, '\t')};\n`);
console.log(`[build-fsr3] wrote ${outDir}`);

function compile(macros, label) {
	const args = [join(root, 'shaders', 'Fsr3', 'Fsr3Passes.slang'), '-target', 'wgsl', '-I', join(root, 'ThirdParty', 'FidelityFX', 'gpu'),
		'-I', join(root, 'shaders', 'Fsr3'), '-I', join(root, 'shaders', 'Nrd'), '-I', join(root, 'shaders'), '-O2', '-matrix-layout-column-major',
		// FidelityFX code: implicit conversions, macro redefinitions, non-short-circuiting ?:, unreachable code, uninitialized values.
		'-warnings-disable', '15205,15400,30056,30081,39029,41000,41012,41016,41018,41035', ...macros.flatMap(m => ['-D', m]), '-entry', 'main', '-stage', 'compute'];
	const result = spawnSync(slangc, args, { encoding: 'utf8', maxBuffer: 64 << 20 });
	if (result.status !== 0) throw new Error(`[build-fsr3] slangc ${label} failed:\n${result.stderr}`);
	if (result.stderr.trim()) console.warn(`[build-fsr3] ${label}:\n${result.stderr.trim()}`);
	return result.stdout.replaceAll('\r\n', '\n');
}

function findSlangc() {
	const exe = process.platform === 'win32' ? 'slangc.exe' : 'slangc';
	for (const candidate of [process.env.SLANGC, join(root, 'tools', 'slang', 'bin', exe)]) if (candidate && existsSync(candidate)) return candidate;
	console.error('[build-fsr3] slangc not found: set SLANGC (tools/slang/README.md)');
	process.exit(1);
}
