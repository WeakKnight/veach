// Headless WebGPU smoke test: renders sample scenes in Chrome and saves screenshots to
// .tools/smoke. Fails on WebGPU / shader / console errors. Run `npm run fetch-samples` first.
import { createReadStream, existsSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';
import { createServer } from 'vite';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = join(root, '.tools', 'smoke');
mkdirSync(outDir, { recursive: true });

function findChrome() {
	const candidates = [
		process.env.CHROME_PATH,
		'C:/Program Files/Google/Chrome/Application/chrome.exe',
		'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
		'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
		'/usr/bin/google-chrome',
		'/usr/bin/chromium',
	].filter(Boolean);
	return candidates.find((p) => existsSync(p));
}

const cases = [
	{ name: 'empty-sky', query: 'spp=16' },
	{ name: 'sky-sunset', query: 'sunElevation=2&sunAzimuth=180&spp=16' },
	{ name: 'helmet', query: 'model=/samples/DamagedHelmet.glb&spp=64' },
	{ name: 'helmet-sunset', query: 'model=/samples/DamagedHelmet.glb&sunElevation=4&sunAzimuth=60&spp=64' },
	{ name: 'helmet-sunset-local-off', query: 'model=/samples/DamagedHelmet.glb&sunElevation=4&sunAzimuth=60&localExposure=0&spp=64' },
	{ name: 'helmet-sunset-local-ev', query: 'model=/samples/DamagedHelmet.glb&sunElevation=4&sunAzimuth=60&visualizeLocalExposure=1&spp=64' },
	{ name: 'helmet-hdr', query: 'model=/samples/DamagedHelmet.glb&env=/samples/studio_small_09_1k.hdr&spp=64' },
	{ name: 'helmet-hdr-filmic', query: 'model=/samples/DamagedHelmet.glb&env=/samples/studio_small_09_1k.hdr&tonemap=1&spp=64' },
	{ name: 'helmet-albedo', query: 'model=/samples/DamagedHelmet.glb&debug=1&spp=1' },
	{ name: 'helmet-normal', query: 'model=/samples/DamagedHelmet.glb&debug=2&spp=1' },
	{ name: 'helmet-traversal', query: 'model=/samples/DamagedHelmet.glb&debug=7&spp=1' },
	{ name: 'helmet-vt', query: 'model=/samples/DamagedHelmet.glb&debug=9&spp=1' },
	{ name: 'spheres', query: 'model=/samples/MetalRoughSpheres.glb&env=/samples/studio_small_09_1k.hdr&spp=64' },
	{ name: 'alpha', query: 'model=/samples/AlphaBlendModeTest.glb&spp=64' },
	{ name: 'emissive', query: 'model=/samples/EmissiveStrengthTest.glb&spp=64' },
	{ name: 'transmission', query: 'model=/samples/TransmissionTest.glb&env=/samples/studio_small_09_1k.hdr&spp=64' },
	{ name: 'clearcoat', query: 'model=/samples/ClearCoatTest.glb&env=/samples/studio_small_09_1k.hdr&spp=64' },
	{ name: 'spec-gloss', query: 'model=/samples/SpecGlossVsMetalRough.glb&env=/samples/studio_small_09_1k.hdr&spp=64' },
	{ name: 'anisotropy', query: 'model=/samples/AnisotropyBarnLamp.glb&env=/samples/studio_small_09_1k.hdr&spp=64' },
	{ name: 'sheen', query: 'model=/samples/SheenChair.glb&env=/samples/studio_small_09_1k.hdr&spp=64' },
	{ name: 'iridescence', query: 'model=/samples/IridescentDishWithOlives.glb&env=/samples/studio_small_09_1k.hdr&spp=64' },
];
const only = process.argv.slice(2);
const integratorFlag = only.indexOf('--integrator');
let integrator = 'megakernel';
if (integratorFlag >= 0) {
	integrator = only[integratorFlag + 1];
	if (!['megakernel', 'wavefront'].includes(integrator)) throw new Error('--integrator must be megakernel or wavefront');
	only.splice(integratorFlag, 2);
}
const wavefrontTuning = {};
const compactionFlag = only.indexOf('--compaction');
if (compactionFlag >= 0) {
	const mode = only[compactionFlag + 1];
	if (integrator !== 'wavefront' || !['dense', 'queued', 'subgroup'].includes(mode)) throw new Error('--compaction requires wavefront and dense, queued or subgroup');
	wavefrontTuning.compaction = mode;
	only.splice(compactionFlag, 2);
}
for (const [flag, name] of [['--tail-start', 'tailStart'], ['--tail-threshold', 'tailThreshold']]) {
	const index = only.indexOf(flag);
	if (index < 0) continue;
	const value = Number(only[index + 1]);
	if (integrator !== 'wavefront' || !Number.isInteger(value) || value < 0) throw new Error(`${flag} requires wavefront and a nonnegative integer`);
	wavefrontTuning[name] = value;
	only.splice(index, 2);
}
const modelFlag = only.indexOf('--model');
let customModel;
if (modelFlag >= 0) {
	if (!only[modelFlag + 1]) throw new Error('--model requires a local .glb path');
	customModel = resolve(only[modelFlag + 1]);
	if (!existsSync(customModel) || !customModel.toLowerCase().endsWith('.glb')) throw new Error('--model requires an existing .glb file');
	only.splice(modelFlag, 2);
	cases.push({
		name: 'custom-model', query: 'model=/__smoke_model.glb', target: 128,
		viewport: { width: 1793, height: 1100 }, allowStreaming: true,
	});
}

const chrome = findChrome();
if (!chrome) {
	console.error('[smoke] Chrome not found; set CHROME_PATH');
	process.exit(1);
}

const server = await createServer({
	root, server: { port: 5199, strictPort: false }, logLevel: 'warn',
	optimizeDeps: { entries: [join(root, 'index.html')] },
	plugins: customModel ? [{
		name: 'smoke-model',
		configureServer(server) {
			// Run before Vite's HTML fallback, serving only the explicitly supplied file.
			server.middlewares.use('/__smoke_model.glb', (_req, res) => {
				res.setHeader('Content-Type', 'model/gltf-binary');
				createReadStream(customModel).pipe(res);
			});
		},
	}] : [],
});
await server.listen();
const base = server.resolvedUrls.local[0];

const browser = await puppeteer.launch({
	executablePath: chrome,
	headless: true,
	args: ['--enable-unsafe-webgpu', '--enable-features=Vulkan', '--ignore-gpu-blocklist', '--no-sandbox'],
});

let failures = 0;
try {
	for (const c of cases) {
		if (only.length && !only.includes(c.name)) continue;
		const page = await browser.newPage();
		await page.setViewport(c.viewport ?? { width: 640, height: 480 });
		const errors = [];
		page.on('console', (msg) => {
			if (msg.type() === 'error') errors.push(msg.text());
		});
		page.on('pageerror', (e) => errors.push(String(e)));
		const target = c.target ?? Number(new URLSearchParams(c.query).get('spp') ?? 16);
		const start = Date.now();
		await page.goto(`${base}?${c.query}&integrator=${integrator}`, { waitUntil: 'load' });
		try {
			if (Object.keys(wavefrontTuning).length) {
				// The first frame proves initial scene loading is complete. Empty scenes need
				// no wavefront kernels; geometry scenes must receive tuning after preparation.
				await page.waitForFunction(() => globalThis.veach?.samples > 0, { timeout: 120000 });
				await page.evaluate(tuning => {
					if (globalThis.veach.tracer.wavefront) Object.assign(globalThis.veach.tracer.wavefront, tuning);
					globalThis.veach.resetAccumulation();
				}, wavefrontTuning);
			}
			// converged and virtual texture streaming settled (no uploads for several polls)
			await page.waitForFunction(
				({ n, allowStreaming }) => {
					const m = globalThis.veach;
					const vt = m?.virtualTextureStats;
					const settled = m && m.samples >= n && (allowStreaming || !vt || (vt.pendingRequests === 0 && vt.uploadsLastFrame === 0));
					globalThis.__settled = settled ? (globalThis.__settled ?? 0) + 1 : 0;
					return globalThis.__settled >= 10;
				},
				{ timeout: 120000, polling: 100 },
				{ n: target, allowStreaming: c.allowStreaming ?? false },
			);
			// one more frame so the present pass shows the final accumulation
			await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
		} catch {
			errors.push(`timed out waiting for ${target} samples`);
		}
		const errorText = await page.$eval('#error', (el) => (el.style.display === 'block' ? el.textContent : ''));
		if (errorText) errors.push(errorText);
		const stats = await page.evaluate(() => {
			const m = globalThis.veach;
			return m ? { samples: m.samples, scene: m.sceneStats, vt: m.virtualTextureStats } : null;
		});
		await page.screenshot({ path: join(outDir, `${c.name}.png`) });
		const ms = Date.now() - start;
		const tris = stats?.scene?.triangles ?? 0;
		if (c.name === 'custom-model' && tris === 0) errors.push('custom model did not load any triangles');
		if (errors.length) {
			failures++;
			console.log(`[smoke] FAIL ${c.name} (${ms} ms)\n  ${errors.join('\n  ')}`);
		} else {
			const vt = stats?.vt;
			const vtText = vt?.textures ? `, VT ${vt.residentPages}/${vt.physicalPages} pages (${vt.totalUploads} uploads)` : '';
			console.log(`[smoke] ok   ${c.name}: ${stats?.samples} spp, ${tris} tris${vtText}, ${ms} ms`);
		}
		await page.close();
	}
} finally {
	await browser.close();
	await server.close();
}
console.log(`[smoke] screenshots in ${outDir}`);
process.exit(failures ? 1 : 0);
