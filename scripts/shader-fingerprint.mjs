import { createHash } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

// Include relative paths as well as bytes so renamed/added imports invalidate experiments.
export function shaderFingerprint(root) {
	const hash = createHash('sha256');
	function visit(relative) {
		const entries = readdirSync(join(root, relative), { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name));
		for (const entry of entries) {
			const path = `${relative}/${entry.name}`;
			if (entry.isDirectory()) visit(path);
			else if (entry.name.endsWith('.slang')) hash.update(path).update('\0').update(readFileSync(join(root, path))).update('\0');
		}
	}
	visit('shaders');
	return hash.digest('hex');
}
