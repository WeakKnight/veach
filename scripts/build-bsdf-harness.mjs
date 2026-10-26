// Builds the differential BSDF test harness (tests/bsdf) into tests/generated/bsdf: the Slang BSDF
// compiled to C++ and the upstream reference, linked into one Node wasm module.
// Requires slangc (run build:shaders once), emsdk (see build-wasm) and GLM ($GLM_DIR or .tools/glm,
// cloned when missing).
import { spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { bsdfHarnessSourceHash } from './bsdf-harness-sources.mjs';
import { requireEmsdk } from './emsdk.mjs';

const GLM_TAG = '1.0.1';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const isWindows = process.platform === 'win32';
const workDir = join(root, '.tools', 'bsdf-harness');
const outDir = join(root, 'tests', 'generated', 'bsdf');

function run(tag, command, args, options = {}) {
	console.log(`[build-bsdf-harness] ${tag}`);
	const result = spawnSync(command, args, { stdio: 'inherit', shell: command.endsWith('.bat'), ...options });
	if (result.status !== 0) {
		console.error(`[build-bsdf-harness] ${tag} failed`);
		process.exit(result.status ?? 1);
	}
}

function findSlangc() {
	const exe = isWindows ? 'slangc.exe' : 'slangc';
	const candidates = [process.env.SLANGC, join(root, '.tools', 'slang', 'bin', exe)].filter(Boolean);
	const found = candidates.find((path) => existsSync(path));
	if (!found) {
		console.error('[build-bsdf-harness] slangc not found; run npm run build:shaders once or set SLANGC');
		process.exit(1);
	}
	return found;
}

function findGlm() {
	const dir = process.env.GLM_DIR ?? join(root, '.tools', 'glm');
	if (!existsSync(join(dir, 'glm', 'glm.hpp'))) {
		run('clone glm', 'git', ['clone', '--depth', '1', '--branch', GLM_TAG, 'https://github.com/g-truc/glm', dir]);
	}
	return dir;
}

if (!existsSync(join(root, 'src', 'generated', 'bsdf', 'BSDFTables.bin'))) {
	run('tables', process.execPath, [join(root, 'scripts', 'build-bsdf-tables.mjs')]);
}

const slangc = findSlangc();
const slangInclude = join(dirname(dirname(slangc)), 'include');
const glm = findGlm();
const emsdk = requireEmsdk(root, 'build-bsdf-harness');
mkdirSync(workDir, { recursive: true });
mkdirSync(outDir, { recursive: true });

run('slangc -> C++', slangc, [
	join(root, 'tests', 'bsdf', 'BSDFHarness.slang'),
	'-target', 'cpp',
	'-I', join(root, 'shaders'),
	'-entry', 'Run', '-stage', 'compute',
	'-O2',
	'-warnings-disable', '41035',
	'-o', join(workDir, 'BSDFHarness.cpp'),
]);

// No fast-math: both implementations must round like the GPU's IEEE float (wasm never contracts to FMA).
run('em++', emsdk.emcc, [
	join(root, 'tests', 'bsdf', 'Reference.cpp'),
	join(root, 'tests', 'bsdf', 'Port.cpp'),
	'-I', join(root, 'ThirdParty', 'openpbr-bsdf'),
	'-I', glm,
	'-I', workDir,
	'-I', slangInclude,
	'-O2',
	'-std=c++20',
	'-w',
	'-sMODULARIZE=1',
	'-sEXPORT_ES6=1',
	'-sEXPORT_NAME=createBSDFHarness',
	'-sENVIRONMENT=node',
	'-sALLOW_MEMORY_GROWTH=1',
	'-sFILESYSTEM=0',
	'-sEXPORTED_FUNCTIONS=_RunReference,_RunPort,_malloc,_free',
	'-sEXPORTED_RUNTIME_METHODS=HEAPF32',
	'-o', join(workDir, 'BSDFHarness.mjs'),
], { env: emsdk.env });

// Keep intermediate linker/optimizer writes out of the watched test directory, and leave
// the committed harness intact if compilation fails.
for (const file of ['BSDFHarness.mjs', 'BSDFHarness.wasm']) {
	copyFileSync(join(workDir, file), join(outDir, file));
}

writeFileSync(
	join(outDir, 'BSDFHarness.d.mts'),
	`// Type declarations for the Emscripten module produced by scripts/build-bsdf-harness.mjs.
export interface BSDFHarnessModule {
	HEAPF32: Float32Array;
	_malloc(bytes: number): number;
	_free(ptr: number): void;
	_RunReference(cases: number, results: number, count: number): void;
	_RunPort(cases: number, results: number, count: number, tables: number): void;
}

export default function createBSDFHarness(options?: Record<string, unknown>): Promise<BSDFHarnessModule>;
`,
);
writeFileSync(join(outDir, 'BSDFHarness.json'), `${JSON.stringify({ sourceHash: bsdfHarnessSourceHash(root) }, null, '\t')}\n`);
console.log(`[build-bsdf-harness] wrote ${outDir}`);
