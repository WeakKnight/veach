// External-model test fixture; the renderer also has a bundled copy of this pinned model.
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
export const oidnWeights = resolve('public/samples/oidn/rt_hdr_alb_nrm.tza');
const sha = 'e586ef2ff48d7fbb7611986405220ed8fc5c13ca79bfc40be4dc742fbf959e1a';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
let cached;
try { cached = await readFile(oidnWeights); } catch {}
if (!cached || hash(cached) !== sha) {
	const response = await fetch('https://raw.githubusercontent.com/pissang/oidn-webgpu/aee3d609e1d45eb14da7c3010bb9aa4bd9988d6c/weights/rt_hdr_alb_nrm.tza');
	if (!response.ok) throw new Error(`OIDN weights download: HTTP ${response.status}`);
	const bytes = Buffer.from(await response.arrayBuffer());
	if (hash(bytes) !== sha) throw new Error('OIDN weights SHA-256 mismatch');
	await mkdir(dirname(oidnWeights), { recursive: true });
	await writeFile(oidnWeights, bytes);
}
