// Reproducible GPU timings and linear HDR captures for the wavefront experiment.
// Uses the production renderer, a fixed camera, and timestamp queries on tracing passes only.
import { createReadStream, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';
import { createServer } from 'vite';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const option = (name, fallback) => {
	const i = args.indexOf(`--${name}`);
	if (i < 0) return fallback;
	if (!args[i + 1] || args[i + 1].startsWith('--')) throw new Error(`--${name} requires a value`);
	return args[i + 1];
};
const scenesRoot = resolve(option('scenes', 'E:/GitHub/gltf-research-scenes/scenes'));
const output = resolve(option('out', join(root, '.tools/wavefront', new Date().toISOString().replaceAll(':', '-'))));
const config = {
	width: Number(option('width', 640)), height: Number(option('height', 360)),
	warmup: Number(option('warmup', 64)), samples: Number(option('samples', 32)),
	repeats: Number(option('repeats', 3)), bounces: Number(option('bounces', 8)),
	mode: option('mode', 'megakernel'),
	diagnose: args.includes('--diagnose'),
	storageBuffers: Number(option('storage-buffers', 8)),
	clamp: Number(option('clamp', 0)),
};
for (const key of ['width', 'height', 'warmup', 'samples', 'repeats', 'bounces']) {
	if (!Number.isInteger(config[key]) || config[key] < (key === 'bounces' ? 0 : 1)) throw new Error(`Invalid ${key}`);
}
const cases = [
	{ name: 'classroom', file: 'classroom/gltf/classroom_extended.glb', environment: 1, presentationExposure: 4 },
	{ name: 'breakfast-room', file: 'breakfast-room/gltf/breakfast_room_extended.glb', environment: 1, presentationExposure: 6 },
	{ name: 'bmw-m6', file: 'bmw-m6/gltf/bmw_m6_extended.glb', environment: 1, presentationExposure: 2 },
	{ name: 'glass-of-water', file: 'glass-of-water/gltf/glass_of_water_extended.glb', environment: 0, presentationExposure: 0 },
	{ name: 'veach-mis', file: 'veach-mis/gltf/veach_mis_extended.glb', environment: 0, presentationExposure: 0 },
].filter(c => option('only', '').split(',').filter(Boolean).length === 0 || option('only', '').split(',').includes(c.name));
if (!cases.length) throw new Error('No selected scenes');
for (const c of cases) {
	c.path = join(scenesRoot, c.file);
	c.sha256 = createHash('sha256').update(readFileSync(c.path)).digest('hex');
}
mkdirSync(output, { recursive: true });
const chrome = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe',
	'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', '/usr/bin/google-chrome', '/usr/bin/chromium']
	.find(p => p && existsSync(p));
if (!chrome) throw new Error('Set CHROME_PATH to a WebGPU-capable browser');
const server = await createServer({
	root, server: { port: 5201, strictPort: false }, logLevel: 'warn',
	plugins: [{ name: 'research-scenes', configureServer(server) {
		server.middlewares.use((req, res, next) => {
			const c = cases.find(c => req.url === `/__research/${c.name}.glb`);
			if (!c) return next();
			res.setHeader('Content-Type', 'model/gltf-binary');
			createReadStream(c.path).pipe(res);
		});
	} }],
});
await server.listen();
const browser = await puppeteer.launch({ executablePath: chrome, headless: true, protocolTimeout: 1800000,
	args: ['--enable-unsafe-webgpu', '--ignore-gpu-blocklist', '--no-sandbox', '--disable-background-timer-throttling'],
});
const report = { started: new Date().toISOString(), revision: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim(),
	config, browser: await browser.version(),
	sourceHashes: Object.fromEntries(['src/generated/shaders/PathTracing.wgsl', 'src/generated/shaders/Wavefront.wgsl',
		'src/generated/shaders/WavefrontCompact.wgsl', 'src/render/Wavefront.ts', 'src/render/PathTracer.ts', 'src/render/Renderer.ts']
		.filter(p => existsSync(join(root, p))).map(p => [p, createHash('sha256').update(readFileSync(join(root, p))).digest('hex')])), results: [] };
writeFileSync(join(output, 'report.json'), JSON.stringify(report, null, 2));
try {
	for (const c of cases) {
		console.log(`[benchmark] ${c.name}: loading ${config.mode}`);
		const page = await browser.newPage();
		await page.setViewport({ width: config.width, height: config.height, deviceScaleFactor: 1 });
		const errors = [];
		page.on('console', msg => {
			if (msg.type() === 'error') errors.push(msg.text());
			if (msg.text().startsWith('[benchmark]')) console.log(msg.text());
		});
		page.on('pageerror', e => errors.push(String(e)));
		// A blank module page avoids the viewer's animation loop and denoiser.
		await page.goto(`${server.resolvedUrls.local[0]}scripts/benchmark.html`);
		const result = await page.evaluate(async ({ c, config }) => {
			const requestDevice = GPUAdapter.prototype.requestDevice;
			let adapterInfo;
			GPUAdapter.prototype.requestDevice = function(descriptor = {}) {
				adapterInfo = { vendor: this.info.vendor, architecture: this.info.architecture, device: this.info.device, description: this.info.description };
				if (!this.features.has('timestamp-query')) throw new Error('This benchmark requires timestamp-query');
				return requestDevice.call(this, { ...descriptor,
					requiredLimits: { ...descriptor.requiredLimits, maxStorageBuffersPerShaderStage: config.storageBuffers },
					requiredFeatures: [...new Set([...(descriptor.requiredFeatures ?? []), 'timestamp-query'])] });
			};
			const { Renderer, LocalExposureMethod } = await import('/src/render/Renderer.ts');
			const { AutoExposureMethod } = await import('/src/render/AutoExposure.ts');
			const { loadGLTF } = await import('/src/loaders/GLTFLoader.ts');
			const canvas = document.querySelector('canvas');
			canvas.style.width = `${config.width}px`;
			canvas.style.height = `${config.height}px`;
			const initStart = performance.now();
			const renderer = await Renderer.create(canvas, { denoiser: null });
			GPUAdapter.prototype.requestDevice = requestDevice;
			const initMs = performance.now() - initStart;
			if (config.mode !== 'megakernel') {
				if (!renderer.setIntegrator) throw new Error('Wavefront integration is not implemented in this revision');
				await renderer.setIntegrator(config.mode);
			}
			Object.assign(renderer.settings, { maxSamples: 0, samplesPerFrame: 1, maxBounces: config.bounces,
				autoExposureMethod: AutoExposureMethod.Manual, autoExposureBias: 0, localExposureMethod: LocalExposureMethod.None,
				environmentIntensity: c.environment, fireflyClamp: config.clamp });
			renderer.sun.enabled = c.environment > 0;
			const loadStart = performance.now();
			await renderer.setScene(await loadGLTF(`/__research/${c.name}.glb`));
			const loadMs = performance.now() - loadStart;
			const device = renderer.device;
			let quiet = 0, warmFrames = 0;
			for (; warmFrames < Math.max(config.warmup, 512); warmFrames++) {
				renderer.renderFrame();
				await device.queue.onSubmittedWorkDone();
				await new Promise(resolve => setTimeout(resolve, 0));
				const vt = renderer.virtualTextureStats;
				quiet = !vt || (vt.uploadsLastFrame === 0 && vt.pendingRequests === 0) ? quiet + 1 : 0;
				if (warmFrames + 1 >= config.warmup && quiet >= 32) break;
			}
			if (quiet < 32) throw new Error(`Textures did not settle after ${warmFrames + 1} frames`);
			console.log(`[benchmark] ${c.name}: warmed ${warmFrames + 1} frames, measuring`);
			// Lock residency during A/B measurements; warmup above uses the normal streaming path.
			const updateStreaming = renderer.updateStreaming;
			renderer.updateStreaming = () => {};
			const queries = device.createQuerySet({ type: 'timestamp', count: 2048 });
			const resolved = device.createBuffer({ size: 2048 * 8, usage: GPUBufferUsage.QUERY_RESOLVE | GPUBufferUsage.COPY_SRC });
			const readback = device.createBuffer({ size: 2048 * 8, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
			const begin = GPUCommandEncoder.prototype.beginComputePass;
			const copyBuffer = GPUCommandEncoder.prototype.copyBufferToBuffer;
			const queueReadback = config.diagnose ? device.createBuffer({ size: 65536, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ }) : null;
			let queueCopies = 0, captureQueues = false, queueSnapshots = [];
			GPUCommandEncoder.prototype.copyBufferToBuffer = function(source, sourceOffset, destination, destinationOffset, size) {
				copyBuffer.call(this, source, sourceOffset, destination, destinationOffset, size);
				if (captureQueues && destination.label === 'wavefrontDispatch') {
					if (queueCopies >= 4096) throw new Error('Queue diagnostic capacity exceeded');
					copyBuffer.call(this, source, sourceOffset - 16, queueReadback, queueCopies++ * 16, 16);
				}
			};
			let labels = [], measuring = false;
			GPUCommandEncoder.prototype.beginComputePass = function(descriptor = {}) {
				if (measuring && (descriptor.label === 'pathTracing' || descriptor.label?.startsWith('wavefront.'))) {
					const index = labels.length * 2;
					if (index + 1 >= 2048) throw new Error('Timestamp query capacity exceeded');
					labels.push(descriptor.label);
					descriptor = { ...descriptor, timestampWrites: { querySet: queries, beginningOfPassWriteIndex: index, endOfPassWriteIndex: index + 1 } };
				}
				return begin.call(this, descriptor);
			};
			const repeats = [];
			for (let repeat = 0; repeat < config.repeats; repeat++) {
				renderer.resetAccumulation();
				const timings = [], spanTimings = [], stages = {}, wall = performance.now();
				for (let sample = 0; sample < config.samples; sample++) {
					captureQueues = config.diagnose && sample === 0 && repeat === 0;
					labels = []; measuring = true;
					renderer.renderFrame();
					captureQueues = false;
					measuring = false;
					if (!labels.length) throw new Error('No trace passes were measured');
					const encoder = device.createCommandEncoder();
					encoder.resolveQuerySet(queries, 0, labels.length * 2, resolved, 0);
					encoder.copyBufferToBuffer(resolved, 0, readback, 0, labels.length * 16);
					device.queue.submit([encoder.finish()]);
					await readback.mapAsync(GPUMapMode.READ);
					const timestamps = new BigUint64Array(readback.getMappedRange());
					let sum = 0;
					for (let i = 0; i < labels.length; i++) {
						const ms = Number(timestamps[i * 2 + 1] - timestamps[i * 2]) / 1e6;
						sum += ms;
						stages[labels[i]] = (stages[labels[i]] ?? 0) + ms;
					}
					timings.push(sum);
					spanTimings.push(Number(timestamps[labels.length * 2 - 1] - timestamps[0]) / 1e6);
					readback.unmap();
				}
				const wallMs = performance.now() - wall;
				const sorted = [...timings].sort((a, b) => a - b);
				const medianMs = sorted[Math.floor(sorted.length / 2)];
				const sortedSpans = [...spanTimings].sort((a, b) => a - b);
				const medianSpanMs = sortedSpans[Math.floor(sortedSpans.length / 2)];
				repeats.push({ medianMs, medianSpanMs, meanMs: timings.reduce((a, b) => a + b) / timings.length, wallMs, timings, spanTimings, stages });
				console.log(`[benchmark] ${c.name}: repeat ${repeat + 1}, GPU passes ${medianMs.toFixed(3)}, span ${medianSpanMs.toFixed(3)} ms/sample`);
			}
			GPUCommandEncoder.prototype.beginComputePass = begin;
			GPUCommandEncoder.prototype.copyBufferToBuffer = copyBuffer;
			if (queueReadback) {
				await queueReadback.mapAsync(GPUMapMode.READ);
				const counters = new Uint32Array(queueReadback.getMappedRange());
				for (let i = 0; i < queueCopies; i++) queueSnapshots.push({ active: counters[i * 4], shadow: counters[i * 4 + 1] });
				queueReadback.unmap(); queueReadback.destroy();
			}
			renderer.updateStreaming = updateStreaming;
			const hdr = await renderer.readRadiance();
			let finite = true, sum = 0, peak = 0;
			for (const v of hdr.data) { if (!Number.isFinite(v)) finite = false; sum += v; peak = Math.max(peak, v); }
			if (!finite || !(sum > 0)) throw new Error('Invalid or black HDR output');
			const bytes = new Uint8Array(hdr.data.buffer);
			let binary = '';
			for (let i = 0; i < bytes.length; i += 16384) binary += String.fromCharCode(...bytes.subarray(i, i + 16384));
			// Presentation-only lift makes dark interiors inspectable without changing the HDR
			// capture, path sampling, or timed work. No extra sample is traced here.
			renderer.settings.maxSamples = renderer.samples;
			renderer.settings.autoExposureBias = c.presentationExposure;
			renderer.renderFrame();
			await device.queue.onSubmittedWorkDone();
			queries.destroy(); resolved.destroy(); readback.destroy();
			globalThis.benchmarkRenderer = renderer;
			return { adapterInfo, initMs, loadMs, warmFrames: warmFrames + 1, presentationExposure: c.presentationExposure, scene: renderer.sceneStats, vt: renderer.virtualTextureStats,
				camera: { position: renderer.camera.position, target: renderer.camera.target, up: renderer.camera.up, fovY: renderer.camera.fovY },
				repeats, queueSnapshots, hdr: { width: hdr.width, height: hdr.height, samples: hdr.samples, elements: hdr.data.length, mean: sum / hdr.data.length, peak },
				base64: btoa(binary) };
		}, { c, config });
		const { base64, ...stats } = result;
		writeFileSync(join(output, `${c.name}.f32`), Buffer.from(base64, 'base64'));
		await page.screenshot({ path: join(output, `${c.name}.png`) });
		report.results.push({ name: c.name, file: c.file, sha256: c.sha256, ...stats, errors });
		writeFileSync(join(output, 'report.json'), JSON.stringify(report, null, 2));
		if (errors.length) throw new Error(errors.join('\n'));
		await page.evaluate(() => globalThis.benchmarkRenderer.destroy());
		await page.close();
	}
} finally {
	report.finished = new Date().toISOString();
	writeFileSync(join(output, 'report.json'), JSON.stringify(report, null, 2));
	await browser.close();
	await server.close();
}
console.log(`[benchmark] saved ${output}`);
