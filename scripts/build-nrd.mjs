// Builds the optional NVIDIA NRD denoiser integration into src/generated/nrd:
//   1. NRD's API-agnostic runtime (pipelines, pools, per-frame dispatches) -> nrd.mjs / nrd.wasm (emsdk)
//   2. Every pipeline the runtime reports for REBLUR_DIFFUSE_SPECULAR(_SH) -> WGSL (slangc)
//   3. Veach's NRD front/back-end passes (shaders/Nrd) -> NrdPasses.wgsl
// The NRD SDK is not vendored. Set NRD_SDK (NRD checkout) and NRD_MATHLIB (MathLib checkout), or place them in
// .tools/nrd/NRD and .tools/nrd/MathLib. Staged, patched copies are written to .tools/nrd/build.
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { requireEmsdk } from './emsdk.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const NRD_VERSION = '4.18.0';
// NRD_NORMAL_ENCODING = RGBA16_SNORM (stored as rgba16float, writable without texture-formats-tier1),
// NRD_ROUGHNESS_ENCODING = LINEAR. WGSL has no quad intrinsics.
const CONFIG = {
	NRD_NORMAL_ENCODING: 4,
	NRD_ROUGHNESS_ENCODING: 1,
	NRD_SUPPORTS_VIEWPORT_OFFSET: 0,
	NRD_SUPPORTS_CHECKERBOARD: 1,
	NRD_SUPPORTS_HISTORY_CONFIDENCE: 0,
	NRD_SUPPORTS_DISOCCLUSION_THRESHOLD_MIX: 0,
	NRD_SUPPORTS_ANTIFIREFLY: 1,
	NRD_SUPPORTS_QUAD_INTRINSICS: 0,
	REBLUR_PERFORMANCE_MODE: 0,
};
// Same register shifts as NRD's SPIR-V build: samplers 0+, constants 2, storage textures 3+, textures 20+.
const SHIFTS = { s: 0, b: 2, u: 3, t: 20 };
// nrd::Denoiser values per instance. SH mode uses separate diffuse and specular denoisers: the combined
// REBLUR_DIFFUSE_SPECULAR_SH temporal accumulation writes 9 storage textures, WebGPU allows at most 8.
const DENOISERS = { radiance: [6], sh: [2, 5] };

const sdk = locate(process.env.NRD_SDK, join(root, '.tools', 'nrd', 'NRD'), 'Include/NRD.h', 'NRD_SDK');
const mathlib = locate(process.env.NRD_MATHLIB, join(root, '.tools', 'nrd', 'MathLib'), 'ml.h', 'NRD_MATHLIB');
const version = readFileSync(join(sdk, 'Include', 'NRD.h'), 'utf8');
const found = ['MAJOR', 'MINOR', 'BUILD'].map(part => version.match(new RegExp(`NRD_VERSION_${part} (\\d+)`))?.[1]).join('.');
if (found !== NRD_VERSION) console.warn(`[build-nrd] expected NRD ${NRD_VERSION}, found ${found}`);

function locate(override, fallback, marker, variable) {
	for (const dir of [override, fallback]) if (dir && existsSync(join(dir, marker))) return resolve(dir);
	console.error(`[build-nrd] ${marker} not found. Set ${variable} or check out the sources into ${fallback}`);
	process.exit(1);
}

// 1. Stage and patch.
const stage = join(root, '.tools', 'nrd', 'build');
rmSync(stage, { recursive: true, force: true });
for (const dir of ['Include', 'Source', 'Shaders', 'Resources']) cpSync(join(sdk, dir), join(stage, dir), { recursive: true });
// MathLib does not know the wasm target; Emscripten maps SSE4.2 intrinsics onto wasm SIMD.
cpSync(mathlib, join(stage, 'MathLib'), { recursive: true, filter: source => !source.includes('.git') });
const mlHeader = join(stage, 'MathLib', 'ml.h');
const ml = readFileSync(mlHeader, 'utf8');
const mlPatched = ml.replace('#elif (defined(__x86_64__) || defined(__SCE__))', '#elif defined(__EMSCRIPTEN__)\n#    include <nmmintrin.h>\n#elif (defined(__x86_64__) || defined(__SCE__))');
if (mlPatched === ml) throw new Error('[build-nrd] MathLib patch did not apply');
writeFileSync(mlHeader, mlPatched);
writeFileSync(join(stage, 'Shaders', 'NRDConfig.hlsli'), Object.entries(CONFIG).map(([k, v]) => `#define ${k} ${v}\n`).join(''));
// The runtime only needs the ShaderConstant type when no shader blobs are embedded.
mkdirSync(join(stage, 'ShaderMake'), { recursive: true });
writeFileSync(join(stage, 'ShaderMake', 'ShaderBlob.h'), '#pragma once\nnamespace ShaderMake { struct ShaderConstant { const char* name; const char* value; }; }\n');

const patch = (file, edits) => {
	const path = join(stage, file);
	let text = readFileSync(path, 'utf8');
	for (const [from, to] of edits) {
		const next = text.replace(from, to);
		if (next === text) throw new Error(`[build-nrd] patch did not apply to ${file}: ${from}`);
		text = next;
	}
	writeFileSync(path, text);
};
// WGSL textureLoad has no texel offset.
for (const file of readdirSync(join(stage, 'Shaders')).filter(f => /\.hlsli?$/.test(f))) {
	const path = join(stage, 'Shaders', file);
	const text = readFileSync(path, 'utf8');
	const next = text.replace(/\.Load\( *([\w.]+) *, *int2\(([^()]*)\) *\)/g, '.Load( $1 + int3( int2( $2 ), 0 ) )');
	if (next !== text) writeFileSync(path, next);
}
// WGSL atomics require atomic<T> storage.
patch('Shaders/REBLUR_ClassifyTiles.cs.hlsl', [
	['groupshared int s_Sum;', 'groupshared Atomic<int> s_Sum;'],
	['s_Sum = 0;', 's_Sum.store( 0 );'],
	['InterlockedAdd( s_Sum, sum );', 's_Sum.add( sum );'],
	[/s_Sum == /g, 's_Sum.load() == '],
]);

// Emscripten provides clock_gettime.
patch('Source/Timer.cpp', [[/defined\(__linux__\) \|\| defined\(__SCE__\)/g, 'defined(__linux__) || defined(__EMSCRIPTEN__) || defined(__SCE__)']]);

// 2. Runtime -> WASM.
const outDir = join(root, 'src', 'generated', 'nrd');
mkdirSync(outDir, { recursive: true });
const emsdk = requireEmsdk(root, 'build-nrd');
const defines = [
	...Object.entries(CONFIG).map(([k, v]) => `-D${k}=${v}`),
	'-DNRD_EMBEDS_DXBC_SHADERS=0', '-DNRD_EMBEDS_DXIL_SHADERS=0', '-DNRD_EMBEDS_SPIRV_SHADERS=0',
	`-DSPIRV_SREG_OFFSET=${SHIFTS.s}`, `-DSPIRV_BREG_OFFSET=${SHIFTS.b}`, `-DSPIRV_UREG_OFFSET=${SHIFTS.u}`, `-DSPIRV_TREG_OFFSET=${SHIFTS.t}`,
	'-DNRD_API=extern "C"',
];
const sources = ['InstanceImpl.cpp', 'Reblur.cpp', 'Relax.cpp', 'Sigma.cpp', 'Reference.cpp', 'Wrapper.cpp', 'Timer.cpp'].map(f => join(stage, 'Source', f));
const exported = ['nrd_version', 'nrd_create', 'nrd_destroy', 'nrd_instance_desc', 'nrd_set_common', 'nrd_set_reblur', 'nrd_dispatches', 'nrd_malloc', 'nrd_free'];
const emArgs = [
	join(root, 'wasm', 'nrd_wasm.cpp'), ...sources,
	'-I', join(stage, 'Include'), '-I', join(stage, 'Source'), '-I', stage, '-I', join(stage, 'MathLib'),
	...defines,
	'-O3', '-std=c++17', '-msimd128', '-msse4.2', '-fno-exceptions', '-Wno-#warnings', '-Wno-unused-command-line-argument',
	'-sMODULARIZE=1', '-sEXPORT_ES6=1', '-sEXPORT_NAME=createNRDModule',
	'-sENVIRONMENT=web,worker,node', '-sALLOW_MEMORY_GROWTH=1', '-sFILESYSTEM=0',
	`-sEXPORTED_FUNCTIONS=${exported.map(f => `_${f}`).join(',')}`,
	'-sEXPORTED_RUNTIME_METHODS=HEAPU8,HEAPF32,HEAPU32,UTF8ToString',
	'-o', join(outDir, 'nrd.mjs'),
];
console.log('[build-nrd] emcc NRD runtime');
const em = spawnSync(emsdk.emcc, emArgs, { stdio: 'inherit', env: emsdk.env, shell: emsdk.emcc.endsWith('.bat') });
if (em.status !== 0) { console.error('[build-nrd] emcc failed'); process.exit(em.status ?? 1); }

// 3. Pipelines -> WGSL.
const { default: createNRDModule } = await import(pathToFileURL(join(outDir, 'nrd.mjs')).href);
const module = await createNRDModule();
const slangc = findSlangc();
const shaders = {};
for (const [name, denoiser] of Object.entries(DENOISERS)) {
	const list = module._nrd_malloc(denoiser.length * 4);
	module.HEAPU32.set(denoiser, list >> 2);
	const context = module._nrd_create(list, denoiser.length);
	module._nrd_free(list);
	if (!context) throw new Error(`[build-nrd] nrd_create(${name}) failed`);
	const desc = JSON.parse(module.UTF8ToString(module._nrd_instance_desc(context)));
	for (const { shader } of desc.pipelines) {
		if (shaders[shader]) continue;
		const [file, ...macros] = shader.split('|');
		shaders[shader] = postprocess(compile(join(stage, 'Shaders', file), ['NRD_INTERNAL', ...macros], 'main'), shader);
		console.log(`[build-nrd] ${shader}`);
	}
	module._nrd_destroy(context);
}
writeFileSync(join(outDir, 'NrdShaders.ts'), '// Generated by scripts/build-nrd.mjs from the NVIDIA NRD SDK. Do not edit.\n' +
	'// This software contains source code provided by NVIDIA Corporation.\n' +
	`export const NRD_VERSION = '${found}';\n` +
	`export const nrdShaders: Record<string, string> = ${JSON.stringify(shaders, null, '\t')};\n`);

// 4. Veach front/back-end passes (include NRD.hlsli), one module per entry point.
// SH variants (NRD_PASS_SH=1) feed REBLUR_DIFFUSE_SH + REBLUR_SPECULAR_SH and resolve / re-jitter their output.
const passes = Object.fromEntries(['', 'Sh'].flatMap(suffix => ['Prepare', 'Composite'].map(entry =>
	[entry + suffix, postprocess(compile(join(root, 'shaders', 'Nrd', 'NrdPasses.slang'), [`NRD_PASS_SH=${suffix ? 1 : 0}`], entry, [join(root, 'shaders')], false), entry + suffix)])));
writeFileSync(join(outDir, 'NrdPasses.ts'), '// Generated from shaders/Nrd/NrdPasses.slang by scripts/build-nrd.mjs. Do not edit.\n' +
	`export const nrdPasses = ${JSON.stringify(passes, null, '\t')};\n`);
writeFileSync(join(outDir, 'nrd.d.mts'), 'export interface NRDModule {\n' + exported.map(f => `\t_${f}(...args: number[]): number;\n`).join('') +
	'\tHEAPU8: Uint8Array;\n\tHEAPF32: Float32Array;\n\tHEAPU32: Uint32Array;\n\tUTF8ToString(pointer: number): string;\n}\n' +
	'export default function createNRDModule(options?: object): Promise<NRDModule>;\n');
console.log(`[build-nrd] wrote ${outDir}`);

function compile(source, macros, entry, includes = [], shift = true) {
	const args = [source, '-target', 'wgsl', '-I', join(stage, 'Shaders'), '-I', join(stage, 'MathLib'), ...includes.flatMap(dir => ['-I', dir]),
		'-O2', '-warnings-disable', '39029', '-matrix-layout-column-major', ...macros.flatMap(m => ['-D', m]),
		...(shift ? Object.entries(SHIFTS).flatMap(([register, value]) => [`-fvk-${register}-shift`, String(value), 'all']) : []),
		'-entry', entry, '-stage', 'compute'];
	const result = spawnSync(slangc, args, { encoding: 'utf8', maxBuffer: 64 << 20 });
	if (result.status !== 0) throw new Error(`[build-nrd] slangc ${source} ${macros.join(' ')} failed:\n${result.stderr}`);
	return result.stdout.replaceAll('\r\n', '\n');
}

// Storage textures become write-only or read-only when used one way (any format), read_write only for
// r32 formats. The host substitutes each storage format at pipeline creation from the bound texture.
function postprocess(wgsl, label) {
	return wgsl.replace(/var (\w+) : texture_storage_2d<(\w+), read_write>/g, (match, name, format) => {
		const used = call => new RegExp(`${call}\\(\\(*\\s*${name}\\b`).test(wgsl);
		const loaded = used('textureLoad'), stored = used('textureStore');
		// Only the REBLUR validation overlay does this; Veach never enables it (enableValidation = false).
		if (loaded && stored && !format.startsWith('r32')) console.warn(`[build-nrd] ${label}: ${name} is read and written as ${format}; unusable without texture-formats-tier2`);
		return loaded && stored ? match : `var ${name} : texture_storage_2d<${format}, ${loaded ? 'read' : 'write'}>`;
	});
}

function findSlangc() {
	const exe = process.platform === 'win32' ? 'slangc.exe' : 'slangc';
	for (const candidate of [process.env.SLANGC, join(root, '.tools', 'slang', 'bin', exe)]) if (candidate && existsSync(candidate)) return candidate;
	console.error('[build-nrd] slangc not found: set SLANGC or run npm run build:shaders once');
	process.exit(1);
}
