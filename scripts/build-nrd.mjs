// Builds the optional NVIDIA NRD denoiser integration into src/generated/nrd:
//   1. NRD's API-agnostic runtime (pipelines, pools, per-frame dispatches) -> nrd.mjs / nrd.wasm (emsdk)
//   2. Every pipeline the runtime dispatches for REBLUR_DIFFUSE_SPECULAR(_SH) -> WGSL (slangc), one variant per
//      combination of bound storage formats (texture-formats-tier1 and core WebGPU pools)
//   3. Veach's NRD front/back-end passes (shaders/Nrd) -> NrdPasses.wgsl
// NRD and MathLib come from ThirdParty/NRD and ThirdParty/MathLib (unmodified upstream, see VERSION.txt);
// NRD_SDK / NRD_MATHLIB override them with other checkouts. Staged, patched copies go to .tools/nrd/build.
// slangc must emit WGSL texture-formats-tier1 storage formats (shader-slang/slang#13778): SLANGC, else tools/slang.
// --skip-wasm reuses the committed runtime (src/generated/nrd/nrd.mjs) and needs no emsdk.
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { requireEmsdk } from './emsdk.mjs';
import { ACCUMULATION_CLEAR_AND_RESTART, ACCUMULATION_CONTINUE, DENOISERS, DENOISING_RANGE, DESCRIPTOR_TEXTURE, REBLUR_FLOATS, REBLUR_INTS, SHIFT,
	nrdVariantKey, resourceFormat } from '../src/render/denoise/NrdConfig.mjs';
// Run through vite-node (package.json build:nrd), which resolves the TypeScript planner.
import { NrdPlanner } from '../src/render/denoise/nrd/Planner.ts';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const skipWasm = process.argv.includes('--skip-wasm');
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
const SHIFTS = { s: SHIFT.sampler, b: SHIFT.constant, u: SHIFT.storage, t: SHIFT.texture };
const SHIFT_DEFINES = Object.entries(SHIFTS).map(([register, value]) => `NRD_VEACH_SHIFT_${register}=${value}`);
// WebGPU storage format -> Slang [format] name.
const SLANG_FORMATS = {
	r8unorm: 'r8', r8snorm: 'r8_snorm', r8uint: 'r8ui', r8sint: 'r8i', rg8unorm: 'rg8', rg8snorm: 'rg8_snorm', rg8uint: 'rg8ui', rg8sint: 'rg8i',
	rgba8unorm: 'rgba8', rgba8snorm: 'rgba8_snorm', rgba8uint: 'rgba8ui', rgba8sint: 'rgba8i',
	r16float: 'r16f', r16uint: 'r16ui', r16sint: 'r16i', rg16float: 'rg16f', rg16uint: 'rg16ui', rg16sint: 'rg16i',
	rgba16float: 'rgba16f', rgba16uint: 'rgba16ui', rgba16sint: 'rgba16i',
	r32float: 'r32f', r32uint: 'r32ui', r32sint: 'r32i', rg32float: 'rg32f', rg32uint: 'rg32ui', rg32sint: 'rg32i',
	rgba32float: 'rgba32f', rgba32uint: 'rgba32ui', rgba32sint: 'rgba32i',
	rgb10a2unorm: 'rgb10_a2', rgb10a2uint: 'rgb10_a2ui', rg11b10ufloat: 'r11f_g11f_b10f',
};

const sdk = locate(process.env.NRD_SDK, join(root, 'ThirdParty', 'NRD'), 'Include/NRD.h', 'NRD_SDK');
const mathlib = locate(process.env.NRD_MATHLIB, join(root, 'ThirdParty', 'MathLib'), 'ml.h', 'NRD_MATHLIB');
const version = readFileSync(join(sdk, 'Include', 'NRD.h'), 'utf8');
const found = ['MAJOR', 'MINOR', 'BUILD'].map(part => version.match(new RegExp(`NRD_VERSION_${part} (\\d+)`))?.[1]).join('.');
if (found !== NRD_VERSION) console.warn(`[build-nrd] expected NRD ${NRD_VERSION}, found ${found}`);

function locate(override, fallback, marker, variable) {
	for (const dir of [override, fallback]) if (dir && existsSync(join(dir, marker))) return resolve(dir);
	console.error(`[build-nrd] ${marker} not found in ${variable} or ${fallback}`);
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

// Resources bind explicitly at register + SHIFT (NRD_VEACH_SHIFT_<register>), the numbering of NRD's SPIR-V build.
// slangc's -fvk-<register>-shift options would override an explicit [[vk::binding]] on the same register class.
// Each output's type comes from NRD_STORAGE_<name> (see declareStorage). Write-only textures get subscript
// stores from shaders/Nrd/WriteOnlyTexture.hlsli.
const RESOURCE_SPACE = 'NRD_MERGE_TOKENS( space, NRD_RESOURCES_SPACE_INDEX )', SAMPLER_SPACE = 'NRD_MERGE_TOKENS( space, NRD_CONSTANT_BUFFER_AND_SAMPLERS_SPACE_INDEX )';
const escape = text => text.replace(/[()]/g, '\\$&');
patch('Shaders/NRD.hlsli', [
	[new RegExp(`(#define NRD_CONSTANTS_START\\( resourceName \\) +)cbuffer resourceName : register\\( NRD_MERGE_TOKENS\\( b, NRD_CONSTANT_BUFFER_REGISTER_INDEX \\), ${escape(SAMPLER_SPACE)} \\) \\{`),
		'$1NRD_VEACH_BINDING( NRD_VEACH_SHIFT_b + NRD_CONSTANT_BUFFER_REGISTER_INDEX, NRD_CONSTANT_BUFFER_AND_SAMPLERS_SPACE_INDEX ) cbuffer resourceName {'],
	[new RegExp(`(#define NRD_INPUT\\( type, dataType, name, reg, binding, policy \\) +)type<dataType> name : register\\( NRD_MERGE_TOKENS\\( reg, binding \\), ${escape(RESOURCE_SPACE)} \\);`),
		'$1NRD_VEACH_BINDING( NRD_VEACH_SHIFT_##reg + binding, NRD_RESOURCES_SPACE_INDEX ) type<dataType> name;'],
	[new RegExp(`(#define NRD_OUTPUT\\( type, dataType, name, reg, binding, policy \\) +)NRD_FORMAT_UNKNOWN type<dataType> name : register\\( NRD_MERGE_TOKENS\\( reg, binding \\), ${escape(RESOURCE_SPACE)} \\);`),
		'$1NRD_VEACH_BINDING( NRD_VEACH_SHIFT_##reg + binding, NRD_RESOURCES_SPACE_INDEX ) NRD_STORAGE_##name<dataType> name;'],
	[new RegExp(`(#define NRD_SAMPLER\\( type, name, reg, binding \\) +)type name : register\\( NRD_MERGE_TOKENS\\( reg, binding \\), ${escape(SAMPLER_SPACE)} \\);`),
		'$1NRD_VEACH_BINDING( NRD_VEACH_SHIFT_##reg + binding, NRD_CONSTANT_BUFFER_AND_SAMPLERS_SPACE_INDEX ) type name;'],
	// Defined outside the resource macros, whose `binding` parameter would replace the attribute name.
	[/^/, '#ifdef __SLANG__\n#include "WriteOnlyTexture.hlsli"\n#define NRD_VEACH_BINDING( index, space ) [[vk::binding( index, space )]]\n#endif\n'],
]);
const outputNames = new Set();
for (const file of readdirSync(join(stage, 'Shaders')).filter(f => /\.hlsli?$/.test(f)))
	for (const [, name] of readFileSync(join(stage, 'Shaders', file), 'utf8').matchAll(/NRD_OUTPUT\( *\w+ *, *\w+ *, *(\w+) *,/g)) if (name !== 'name') outputNames.add(name);

// Emscripten provides clock_gettime.
patch('Source/Timer.cpp', [[/defined\(__linux__\) \|\| defined\(__SCE__\)/g, 'defined(__linux__) || defined(__EMSCRIPTEN__) || defined(__SCE__)']]);

// 2. Runtime -> WASM.
const outDir = join(root, 'src', 'generated', 'nrd');
mkdirSync(outDir, { recursive: true });
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
	// NRD asserts embed __FILE__; a fixed prefix keeps the committed wasm independent of the checkout path.
	`-fmacro-prefix-map=${stage}=nrd`, `-fmacro-prefix-map=${root}=veach`,
	'-sMODULARIZE=1', '-sEXPORT_ES6=1', '-sEXPORT_NAME=createNRDModule',
	'-sENVIRONMENT=web,worker,node', '-sALLOW_MEMORY_GROWTH=1', '-sFILESYSTEM=0',
	`-sEXPORTED_FUNCTIONS=${exported.map(f => `_${f}`).join(',')}`,
	'-sEXPORTED_RUNTIME_METHODS=HEAPU8,HEAPF32,HEAPU32,UTF8ToString',
	'-o', join(outDir, 'nrd.mjs'),
];
if (skipWasm) {
	if (!existsSync(join(outDir, 'nrd.mjs'))) throw new Error('[build-nrd] --skip-wasm needs an existing src/generated/nrd/nrd.mjs');
	console.log('[build-nrd] reusing src/generated/nrd/nrd.mjs');
} else {
	const emsdk = requireEmsdk(root, 'build-nrd');
	console.log('[build-nrd] emcc NRD runtime');
	const em = spawnSync(emsdk.emcc, emArgs, { stdio: 'inherit', env: emsdk.env, shell: emsdk.emcc.endsWith('.bat') });
	if (em.status !== 0) { console.error('[build-nrd] emcc failed'); process.exit(em.status ?? 1); }
}

// 3. Pipelines -> WGSL.
const slangc = findSlangc();
checkSlangc();
// Storage format combinations per shader (binding -> format), from the dispatches NrdDenoiser issues with
// either format set, planned by the TypeScript planner (equal to the wasm runtime's, tests/nrd). A pipeline can run on textures of different formats (Clear, for example).
const variants = new Map(), undispatched = new Set();
let resourcesSpace = null;
for (const mode of Object.keys(DENOISERS)) {
	const planner = new NrdPlanner(DENOISERS[mode]), desc = planner.desc;
	planner.setReblur(REBLUR_FLOATS, REBLUR_INTS);
	if (resourcesSpace !== null && resourcesSpace !== desc.resourcesSpace) throw new Error('[build-nrd] resource spaces differ between modes');
	resourcesSpace = desc.resourcesSpace;
	for (const dispatch of sweepDispatches(planner)) {
		const shader = desc.pipelines[dispatch.pipeline].shader;
		if (!variants.has(shader)) variants.set(shader, new Map());
		const storage = dispatch.resources.filter(resource => resource.descriptor !== DESCRIPTOR_TEXTURE);
		for (const tier1 of [false, true]) {
			const bound = new Map(storage.map((resource, i) => [SHIFT.storage + i, resourceFormat(desc, resource, tier1)]));
			variants.get(shader).set(nrdVariantKey([...bound.values()]), bound);
		}
	}
	for (const { shader } of desc.pipelines) if (!variants.has(shader)) undispatched.add(shader);
}
// With Veach's REBLUR settings, e.g. hit distance reconstruction, split screen and validation stay off.
for (const shader of undispatched) console.log(`[build-nrd] ${shader}: never dispatched, not compiled`);
const shaders = {};
for (const [shader, bindings] of variants) {
	const [file, ...macros] = shader.split('|');
	const source = join(stage, 'Shaders', file), defines = ['NRD_INTERNAL', ...macros];
	// The first pass only analyzes how the shader uses each storage texture.
	const usage = storageUsage(compile(source, [...defines, ...declareStorage(new Map(), null, shader)], 'main'), shader);
	shaders[shader] = {};
	for (const [key, bound] of bindings)
		shaders[shader][key] = verify(compile(source, [...defines, ...declareStorage(usage, bound, shader)], 'main'), usage, bound, shader);
	console.log(`[build-nrd] ${shader}: ${bindings.size} storage format variant${bindings.size > 1 ? 's' : ''}`);
}
writeFileSync(join(outDir, 'NrdShaders.ts'), '// Generated by scripts/build-nrd.mjs from the NVIDIA NRD SDK. Do not edit.\n' +
	'// This software contains source code provided by NVIDIA Corporation.\n' +
	'// Shader -> combination of bound storage formats (nrdVariantKey, NrdConfig.mjs) -> WGSL.\n' +
	`export const NRD_VERSION = '${found}';\n` +
	`export const nrdShaders: Record<string, Record<string, string>> = ${JSON.stringify(shaders, null, '\t')};\n`);

// 4. Veach front/back-end passes (include NRD.hlsli), one module per entry point.
// SH variants (NRD_PASS_SH=1) feed REBLUR_DIFFUSE_SH + REBLUR_SPECULAR_SH and resolve / re-jitter their output.
const passes = Object.fromEntries(['', 'Sh'].flatMap(suffix => ['Prepare', 'Composite'].map(entry => {
	const wgsl = compile(join(root, 'shaders', 'Nrd', 'NrdPasses.slang'), [`NRD_PASS_SH=${suffix ? 1 : 0}`], entry, [join(root, 'shaders')], false);
	if (/texture_storage_2d<\w+, read_write>/.test(wgsl)) throw new Error(`[build-nrd] ${entry}${suffix}: read_write storage texture`);
	return [entry + suffix, wgsl];
})));
writeFileSync(join(outDir, 'NrdPasses.ts'), '// Generated from shaders/Nrd/NrdPasses.slang by scripts/build-nrd.mjs. Do not edit.\n' +
	`export const nrdPasses = ${JSON.stringify(passes, null, '\t')};\n`);
writeFileSync(join(outDir, 'nrd.d.mts'), 'export interface NRDModule {\n' + exported.map(f => `\t_${f}(...args: number[]): number;\n`).join('') +
	'\tHEAPU8: Uint8Array;\n\tHEAPF32: Float32Array;\n\tHEAPU32: Uint32Array;\n\tUTF8ToString(pointer: number): string;\n}\n' +
	'export default function createNRDModule(options?: object): Promise<NRDModule>;\n');
console.log(`[build-nrd] wrote ${outDir}`);

function compile(source, macros, entry, includes = [], nrd = true) {
	const args = [source, '-target', 'wgsl', '-I', join(stage, 'Shaders'), '-I', join(stage, 'MathLib'), '-I', join(root, 'shaders', 'Nrd'), ...includes.flatMap(dir => ['-I', dir]),
		'-O2', '-warnings-disable', '39029', '-matrix-layout-column-major', ...[...macros, ...(nrd ? SHIFT_DEFINES : [])].flatMap(m => ['-D', m]),
		'-entry', entry, '-stage', 'compute'];
	const result = spawnSync(slangc, args, { encoding: 'utf8', maxBuffer: 64 << 20 });
	if (result.status !== 0) throw new Error(`[build-nrd] slangc ${source} ${macros.join(' ')} failed:\n${result.stderr}`);
	return result.stdout.replaceAll('\r\n', '\n');
}

// Topologies NrdDenoiser can reach: history resets, steady frames and a resize, at small resolutions.
function sweepDispatches(planner) {
	const identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
	const viewToClip = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, -0.01, 0];
	const matrices = [...viewToClip, ...viewToClip, ...identity, ...identity];
	const frames = [[64, 64, true], [64, 64, false], [64, 64, false], [64, 64, false], [48, 40, true], [48, 40, false]];
	const dispatches = [];
	let previous = frames[0];
	frames.forEach(([width, height, reset], frameIndex) => {
		const params = [1 / width, 1 / height, 0, 0, 0, 0, 0, DENOISING_RANGE, 0.01, 1, 16.66];
		const ints = [width, height, previous[0], previous[1], frameIndex, reset ? ACCUMULATION_CLEAR_AND_RESTART : ACCUMULATION_CONTINUE, 0];
		dispatches.push(...planner.plan(matrices, params, ints));
		previous = [width, height];
	});
	return dispatches;
}

// Storage textures of the WGSL emitted with NRD's own declarations (rgba32float read_write), by HLSL name.
// This pass is analysis only: the generated WGSL comes from the second pass, unedited.
function storageUsage(wgsl, label) {
	const usage = new Map();
	for (const [, binding, group, variable] of wgsl.matchAll(/@binding\((\d+)\) @group\((\d+)\) var (\w+) : texture_storage_2d<\w+, read_write>/g)) {
		if (+group !== resourcesSpace) throw new Error(`[build-nrd] ${label}: ${variable} is in group ${group}`);
		const used = call => new RegExp(`${call}\\(\\(*\\s*${variable}\\b`).test(wgsl);
		usage.set(variable.replace(/_\d+$/, ''), { binding: +binding, loaded: used('textureLoad'), stored: used('textureStore') });
	}
	return usage;
}

// -D NRD_STORAGE_<name> types: write-only, read-only (sampled) or read-write in the bound format. Outputs the
// shader does not use keep NRD's type (as does every output in the analysis pass); slangc removes them.
function declareStorage(usage, bound, label) {
	return [...outputNames].sort().map(name => {
		const use = usage.get(name);
		if (!use) return `NRD_STORAGE_${name}=RWTexture2D`;
		if (use.loaded && !use.stored) return `NRD_STORAGE_${name}=Texture2D`;
		const format = bound.get(use.binding);
		if (!format) throw new Error(`[build-nrd] ${label}: no dispatch binds storage ${use.binding} (${name})`);
		// Only the REBLUR validation overlay reads and writes one texture; Veach never enables it (enableValidation = false).
		if (use.loaded && !format.startsWith('r32')) console.warn(`[build-nrd] ${label}: ${name} is read and written as ${format}; unusable without texture-formats-tier2`);
		return `NRD_STORAGE_${name}=[format("${SLANG_FORMATS[format]}")] ${use.loaded ? 'RWTexture2D' : 'WTexture2D'}`;
	});
}

// The declared storage must be exactly what NrdDenoiser binds: older slangc emits unsupported formats as rgba32float.
function verify(wgsl, usage, bound, label) {
	const declared = new Map([...wgsl.matchAll(/@binding\((\d+)\) @group\(\d+\) var \w+ : (?:texture_storage_2d<(\w+), (\w+)>|texture_2d<\w+>)/g)]
		.map(([, binding, format, access]) => [+binding, format ? `${format}, ${access}` : 'sampled']));
	for (const [name, use] of usage) {
		const expected = use.loaded && !use.stored ? 'sampled' : `${bound.get(use.binding)}, ${use.loaded ? 'read_write' : 'write'}`;
		const found = declared.get(use.binding) ?? 'nothing';
		if (found !== expected) throw new Error(`[build-nrd] ${label}: ${name} at ${use.binding} is ${found}, expected ${expected}`);
	}
	return wgsl;
}

// Fails early when slangc predates shader-slang/slang#13778 instead of emitting rgba32float for tier1 formats.
function checkSlangc() {
	const dir = join(root, '.tools', 'nrd');
	mkdirSync(dir, { recursive: true });
	const probe = join(dir, 'slangc-tier1-probe.slang');
	writeFileSync(probe, '[format("r16f")] WTexture2D<float> t;\n[numthreads(1, 1, 1)] void main(uint3 id : SV_DispatchThreadID) { t.Store(id.xy, 0.0); }\n');
	const result = spawnSync(slangc, [probe, '-target', 'wgsl', '-entry', 'main', '-stage', 'compute'], { encoding: 'utf8' });
	if (result.status !== 0 || !result.stdout.includes('texture_storage_2d<r16float, write>')) {
		console.error(`[build-nrd] ${slangc} does not emit WGSL texture-formats-tier1 storage formats.\n` +
			'Use tools/slang (Windows) or build slangc with shader-slang/slang#13778 and set SLANGC (tools/slang/README.md).');
		process.exit(1);
	}
}

function findSlangc() {
	const exe = process.platform === 'win32' ? 'slangc.exe' : 'slangc';
	// tools/slang: committed Windows build with WGSL tier1 storage formats (tools/slang/README.md).
	for (const candidate of [process.env.SLANGC, join(root, 'tools', 'slang', 'bin', exe), join(root, '.tools', 'slang', 'bin', exe)]) if (candidate && existsSync(candidate)) return candidate;
	console.error('[build-nrd] slangc not found: set SLANGC or run npm run build:shaders once');
	process.exit(1);
}
