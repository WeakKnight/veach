// Downloads test assets into public/samples (gitignored).
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = join(root, 'public', 'samples');
const khronos = (name) => [`${name}.glb`, `https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/${name}/glTF-Binary/${name}.glb`];

const assets = [
	khronos('DamagedHelmet'),
	khronos('AlphaBlendModeTest'),
	khronos('EmissiveStrengthTest'),
	khronos('TransmissionTest'),
	khronos('ClearCoatTest'),
	khronos('MetalRoughSpheres'),
	khronos('SpecGlossVsMetalRough'),
	khronos('AnisotropyBarnLamp'),
	khronos('SheenChair'),
	khronos('IridescentDishWithOlives'),
	['studio_small_09_1k.hdr', 'https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/1k/studio_small_09_1k.hdr'],
];

mkdirSync(outDir, { recursive: true });
for (const [name, url] of assets) {
	const file = join(outDir, name);
	if (existsSync(file)) {
		console.log(`[fetch-samples] ${name} (cached)`);
		continue;
	}
	const res = await fetch(url);
	if (!res.ok) {
		console.warn(`[fetch-samples] ${name}: HTTP ${res.status}`);
		continue;
	}
	writeFileSync(file, Buffer.from(await res.arrayBuffer()));
	console.log(`[fetch-samples] ${name}`);
}
