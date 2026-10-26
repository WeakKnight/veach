// Hash of every source the BSDF test harness is built from, so tests can tell a stale build.
import { createHash } from 'node:crypto';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const SOURCES = [
	['shaders/Common', /\.slang$/],
	['shaders/Materials/BSDF', /\.slang$/],
	['tests/bsdf', /\.(slang|cpp)$/],
	['ThirdParty/openpbr-bsdf', /\.h$/],
	['src/generated/bsdf', /\.bin$/],
];

function listFiles(dir, pattern) {
	return readdirSync(dir)
		.sort()
		.flatMap((name) => {
			const path = join(dir, name);
			if (statSync(path).isDirectory()) {
				return listFiles(path, pattern);
			}
			return pattern.test(name) ? [path] : [];
		});
}

export function bsdfHarnessSourceHash(root) {
	const hash = createHash('sha256');
	for (const [dir, pattern] of SOURCES) {
		for (const file of listFiles(join(root, dir), pattern)) {
			const bytes = readFileSync(file);
			const content = file.endsWith('.bin') ? bytes : Buffer.from(bytes.toString('utf8').replace(/\r\n/g, '\n'));
			hash.update(relative(root, file).replace(/\\/g, '/'));
			hash.update('\0');
			hash.update(content);
			hash.update('\0');
		}
	}
	return hash.digest('hex');
}
