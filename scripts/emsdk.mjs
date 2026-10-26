// Locates emsdk ($EMSDK or .tools/emsdk) for the wasm build scripts.
import { existsSync } from 'node:fs';
import { join } from 'node:path';

export function findEmsdk(root) {
	const isWindows = process.platform === 'win32';
	const candidates = [process.env.EMSDK, join(root, '.tools', 'emsdk')].filter(Boolean);
	const names = isWindows ? ['em++.exe', 'em++.bat'] : ['em++'];
	for (const dir of candidates) {
		for (const name of names) {
			const emcc = join(dir, 'upstream', 'emscripten', name);
			if (existsSync(emcc)) {
				return { dir, emcc, env: { ...process.env, EMSDK: dir, EM_CONFIG: join(dir, '.emscripten') } };
			}
		}
	}
	return null;
}

export function requireEmsdk(root, tag) {
	const emsdk = findEmsdk(root);
	if (!emsdk) {
		console.error(`[${tag}] emsdk not found. Set EMSDK or run:`);
		console.error('  git clone https://github.com/emscripten-core/emsdk .tools/emsdk');
		console.error('  .tools/emsdk/emsdk install latest && .tools/emsdk/emsdk activate latest');
		process.exit(1);
	}
	return emsdk;
}
