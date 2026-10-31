// Builds the FidelityFX SSSR integration into src/generated/sssr (docs/Sssr.md):
//   1. shaders/Sssr/SssrPasses.slang -> WGSL, one module per pass (SssrShaders.ts)
//   2. the 1 spp blue noise sampler tables of ThirdParty/FidelityFX/host -> SssrBlueNoise.bin (uint8:
//      sobol 256x256, then the scrambling tile 512x256)
// The FidelityFX GPU headers are staged to .tools/sssr/gpu with one WGSL patch: WGSL atomics need atomic<T>
// storage, so classify's groupshared tile counter becomes Atomic<uint> (the vendored copy stays unmodified).
// slangc must lower WaveActiveCountBits / WavePrefixCountBits (shader-slang/slang#13649) and bool lane reads to WGSL and
// support -wgsl-diagnostic (shader-slang/slang#13660): SLANGC, else tools/slang (tools/slang/README.md).
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const ffx = join(root, 'ThirdParty', 'FidelityFX');
const stage = join(root, '.tools', 'sssr');
const outDir = join(root, 'src', 'generated', 'sssr');
const slangc = findSlangc();

// Pass name -> SSSR_PASS value (SssrPasses.slang).
const PASSES = {
	Prepare: 1, Downsample: 2, ClassifyTiles: 3, PrepareBlueNoise: 4, PrepareIndirectArgs: 5, Intersect: 6,
	Reproject: 7, Prefilter: 8, ResolveTemporal: 9, Apply: 10, EnvironmentDownsample: 11,
};
const DEFINES = ['FFX_GPU=1', 'FFX_HLSL=1', 'FFX_HALF=0', 'FFX_HLSL_SM=62', 'FFX_WAVE=1', 'FFX_SSSR_OPTION_INVERTED_DEPTH=1'];

// 1. Stage and patch the GPU headers.
rmSync(join(stage, 'gpu'), { recursive: true, force: true });
mkdirSync(stage, { recursive: true });
cpSync(join(ffx, 'gpu'), join(stage, 'gpu'), { recursive: true });
patch(join(stage, 'gpu', 'sssr', 'ffx_sssr_classify_tiles.h'), [
	['FFX_GROUPSHARED FfxUInt32 g_TileCount;', 'FFX_GROUPSHARED Atomic<FfxUInt32> g_TileCount;'],
	['    g_TileCount = 0;', '    g_TileCount.store(0u);'],
	['FFX_ATOMIC_ADD(g_TileCount, 1);', 'g_TileCount.add(1u);'],
	['&& g_TileCount > 0)', '&& g_TileCount.load() > 0u)'],
]);

const shaders = Object.fromEntries(Object.entries(PASSES).map(([name, pass]) => {
	const wgsl = compile([...DEFINES, `SSSR_PASS=${pass}`], name);
	if (/texture_storage_2d<\w+, read_write>/.test(wgsl)) throw new Error(`[build-sssr] ${name}: read_write storage texture`);
	return [name, wgsl];
}));
mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, 'SssrShaders.ts'), '// Generated from shaders/Sssr/SssrPasses.slang and the AMD FidelityFX SDK (MIT, ThirdParty/FidelityFX)\n' +
	'// by scripts/build-sssr.mjs. Do not edit.\n' +
	`export const sssrShaders: Record<string, string> = ${JSON.stringify(shaders, null, '\t')};\n`);

// 2. Blue noise sampler tables.
const tables = readFileSync(join(ffx, 'host', 'samplerBlueNoiseErrorDistribution_128x128_OptimizedFor_2d2d2d2d_1spp.cpp'), 'utf8');
const table = (name, length) => {
	const match = tables.match(new RegExp(`static const int ${name}\\[[^\\]]+\\] = \\{([^}]*)\\}`));
	if (!match) throw new Error(`[build-sssr] table ${name} not found`);
	const values = match[1].split(',').map(v => v.trim()).filter(Boolean).map(Number);
	if (values.length !== length || values.some(v => !Number.isInteger(v) || v < 0 || v > 255)) throw new Error(`[build-sssr] table ${name}: expected ${length} bytes`);
	return values;
};
writeFileSync(join(outDir, 'SssrBlueNoise.bin'), Uint8Array.from([...table('sobol_256spp_256d', 256 * 256), ...table('scramblingTile', 128 * 128 * 8)]));
console.log(`[build-sssr] wrote ${outDir}`);

function patch(file, replacements) {
	let text = readFileSync(file, 'utf8').replaceAll('\r\n', '\n');
	for (const [from, to] of replacements) {
		const count = text.split(from).length - 1;
		if (count !== 1) throw new Error(`[build-sssr] ${file}: expected one '${from}', found ${count}`);
		text = text.replace(from, to);
	}
	writeFileSync(file, text);
}

function compile(macros, label) {
	const args = [join(root, 'shaders', 'Sssr', 'SssrPasses.slang'), '-target', 'wgsl', '-I', join(stage, 'gpu'), '-I', join(root, 'shaders', 'Sssr'),
		'-I', join(root, 'shaders', 'Nrd'), '-I', join(root, 'shaders'), '-O2', '-matrix-layout-column-major',
		// HLSL wave operations may run in divergent control flow (Intersect's raymarch loop); WGSL needs the opt-out.
		'-wgsl-diagnostic', 'off:subgroup_uniformity',
		// FidelityFX code: implicit conversions, macro redefinitions, non-short-circuiting ?:, unreachable code, uninitialized values.
		'-warnings-disable', '15205,15400,30056,30081,39029,41000,41018,41035', ...macros.flatMap(m => ['-D', m]), '-entry', 'main', '-stage', 'compute'];
	const result = spawnSync(slangc, args, { encoding: 'utf8', maxBuffer: 64 << 20 });
	if (result.status !== 0) throw new Error(`[build-sssr] slangc ${label} failed:\n${result.stderr}`);
	if (result.stderr.trim()) console.warn(`[build-sssr] ${label}:\n${result.stderr.trim()}`);
	return result.stdout.replaceAll('\r\n', '\n');
}

function findSlangc() {
	const exe = process.platform === 'win32' ? 'slangc.exe' : 'slangc';
	for (const candidate of [process.env.SLANGC, join(root, 'tools', 'slang', 'bin', exe)]) if (candidate && existsSync(candidate)) return candidate;
	console.error('[build-sssr] slangc with WGSL wave count intrinsics not found: set SLANGC (tools/slang/README.md)');
	process.exit(1);
}
