// Compiles wasm/tinybvh_wasm.cpp into an ES module + .wasm under src/generated/tinybvh.
// Requires emsdk: set EMSDK, or install it into .tools/emsdk (see README).
import { spawnSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { requireEmsdk } from './emsdk.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const emsdk = requireEmsdk(root, 'build-wasm');

// --debug: optimized build with symbols and runtime assertions into .tools/tinybvh-debug.
const debug = process.argv.includes('--debug');
const outDir = debug ? join(root, '.tools', 'tinybvh-debug') : join(root, 'src', 'generated', 'tinybvh');
mkdirSync(outDir, { recursive: true });

const args = [
	join(root, 'wasm', 'tinybvh_wasm.cpp'),
	'-I', join(root, 'ThirdParty', 'tinybvh'),
	...(debug ? ['-O3', '-g', '-sASSERTIONS=2', '-sSTACK_OVERFLOW_CHECK=2'] : ['-O3']),
	'-std=c++20',
	'-Wno-#warnings',
	'-sMODULARIZE=1',
	'-sEXPORT_ES6=1',
	'-sEXPORT_NAME=createTinyBVHModule',
	'-sENVIRONMENT=web,worker,node',
	'-sALLOW_MEMORY_GROWTH=1',
	'-sMAXIMUM_MEMORY=4GB',
	'-sFILESYSTEM=0',
	'-sEXPORTED_RUNTIME_METHODS=HEAPU8,HEAPF32,HEAPU32',
	'-o', join(outDir, 'tinybvh.mjs'),
];

console.log(`[build-wasm] ${emsdk.emcc} ${args.join(' ')}`);
const result = spawnSync(emsdk.emcc, args, { stdio: 'inherit', env: emsdk.env, shell: emsdk.emcc.endsWith('.bat') });
if (result.status !== 0) {
	console.error('[build-wasm] emcc failed');
	process.exit(result.status ?? 1);
}
console.log(`[build-wasm] wrote ${outDir}`);
