// GPU regression tests for stage boundaries, queue padding, AOVs and integrator switching.
// Compare production kernels in the same renderer with identical seeds and texture residency.
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';
import { createServer } from 'vite';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const tailOption = process.argv.indexOf('--tail-start');
const tailStart = tailOption < 0 ? 999 : Number(process.argv[tailOption + 1]);
const thresholdOption = process.argv.indexOf('--tail-threshold');
const tailThreshold = thresholdOption < 0 ? 0 : Number(process.argv[thresholdOption + 1]);
if (!Number.isInteger(tailStart) || tailStart < 0) throw new Error('Invalid tail start');
const output = join(root, `.tools/wavefront/correctness-tail-${tailStart}-${tailThreshold}`);
mkdirSync(output, { recursive: true });
const chrome = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe',
	'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', '/usr/bin/google-chrome', '/usr/bin/chromium'].find(p => p && existsSync(p));
if (!chrome) throw new Error('Set CHROME_PATH');
const server = await createServer({ root, logLevel: 'warn', server: { port: 5205, strictPort: false } });
await server.listen();
const browser = await puppeteer.launch({ executablePath: chrome, headless: true, protocolTimeout: 1800000,
	args: ['--enable-unsafe-webgpu', '--ignore-gpu-blocklist', '--no-sandbox'] });
const errors = [];
try {
	const page = await browser.newPage();
	await page.setViewport({ width: 640, height: 640, deviceScaleFactor: 1 });
	page.on('pageerror', e => errors.push(String(e)));
	page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); if (msg.text().startsWith('[correctness]')) console.log(msg.text()); });
	await page.goto(server.resolvedUrls.local[0] + 'scripts/benchmark.html');
	const results = await page.evaluate(async ({ tailStart, tailThreshold }) => {
		const api = await import('/src/index.ts');
		const check = (value, message) => { if (!value) throw new Error(message); };
		const requestDevice = GPUAdapter.prototype.requestDevice;
		GPUAdapter.prototype.requestDevice = function(descriptor = {}) {
			return requestDevice.call(this, { ...descriptor, requiredLimits: { ...descriptor.requiredLimits, maxStorageBuffersPerShaderStage: 8 } });
		};
		const canvas = document.querySelector('canvas');
		canvas.style.cssText = 'width:129px;height:97px';
		const r = await api.Renderer.create(canvas, { denoiser: null });
		GPUAdapter.prototype.requestDevice = requestDevice;
		check(r.device.limits.maxStorageBuffersPerShaderStage === 8, 'Storage binding budget was not enforced');
		Object.assign(r.settings, { maxSamples: 0, samplesPerFrame: 1, autoExposureMethod: api.AutoExposureMethod.Manual,
			autoExposureBias: 0, localExposureMethod: api.LocalExposureMethod.None, textureMipBias: -16 });
		const originalUpdate = r.updateStreaming;
		const results = [];
		async function snapshot() {
			const bytes = r.tracer.width * r.tracer.height * 48;
			const buffer = r.device.createBuffer({ size: bytes, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
			const encoder = r.device.createCommandEncoder();
			encoder.copyBufferToBuffer(r.tracer.accumulation, 0, buffer, 0, bytes);
			r.device.queue.submit([encoder.finish()]);
			await buffer.mapAsync(GPUMapMode.READ);
			const values = new Float32Array(buffer.getMappedRange()).slice();
			buffer.unmap(); buffer.destroy();
			return values;
		}
		async function render(mode, config) {
			await r.setIntegrator(mode);
			if (mode === 'wavefront') Object.assign(r.tracer.wavefront, { tailStart, tailThreshold });
			Object.assign(r.settings, { maxBounces: config.bounces, fireflyClamp: config.clamp ?? 0, maxSamples: config.samples });
			r.resetAccumulation();
			while (r.samples < config.samples) {
				r.renderFrame();
				await r.device.queue.onSubmittedWorkDone();
			}
			const values = await snapshot();
			check(r.samples === config.samples, 'Wrong sample count');
			const hdr = await r.readRadiance();
			check(hdr.data.length === config.width * config.height * 3, 'Readback includes scratch data or wrong dimensions');
			const before = r.samples;
			r.settings.autoExposureBias = 1;
			r.renderFrame();
			await r.device.queue.onSubmittedWorkDone();
			check(r.samples === before, 'Presentation reset accumulation');
			const unchanged = await snapshot();
			check(unchanged.every((v, i) => v === values[i]), 'Presentation modified accumulated radiance or guides');
			r.settings.autoExposureBias = 0;
			return values;
		}
		const scenes = [
			{ name: 'empty', file: null, configurations: [
				{ width: 1, height: 1, bounces: 0, samples: 2 },
				{ width: 7, height: 5, bounces: 8, samples: 4 },
				{ width: 513, height: 513, bounces: 1, samples: 2 },
			] },
			{ name: 'alpha', file: 'AlphaBlendModeTest.glb', configurations: [
				{ width: 129, height: 97, bounces: 0, samples: 4 },
				{ width: 129, height: 97, bounces: 8, samples: 16, clamp: 2 },
			] },
			{ name: 'transmission', file: 'TransmissionTest.glb', configurations: [
				{ width: 129, height: 97, bounces: 8, samples: 8 },
			] },
			{ name: 'clearcoat', file: 'ClearCoatTest.glb', configurations: [
				{ width: 131, height: 99, bounces: 4, samples: 8, clamp: 1 },
			] },
			{ name: 'emissive', file: 'EmissiveStrengthTest.glb', configurations: [
				{ width: 129, height: 97, bounces: 8, samples: 8 },
			] },
			{ name: 'analytic', file: 'MetalRoughSpheres.glb', analytic: true, configurations: [
				{ width: 129, height: 97, bounces: 4, samples: 8, clamp: 2 },
			] },
		];
		try {
			for (const scene of scenes) {
				await r.setIntegrator('megakernel');
				r.updateStreaming = originalUpdate;
				canvas.style.width = '129px'; canvas.style.height = '97px'; r.resize();
				const desc = scene.file ? await api.loadGLTF(`/samples/${scene.file}`) : { meshes: [], materials: [], textures: [], instances: [], cameras: [] };
				if (scene.analytic) {
					desc.lights = [true, false].map((castShadow, i) => ({ type: i === 0 ? 'point' : 'area', position: [i === 0 ? -2 : 2, 3, 3], direction: [0, -0.7, -0.7],
						power: [300, 200, 100], radius: 0.1, spotAngle: 1, spotBlend: 0.2, sizeU: [1, 0, 0], sizeV: [0, 0.7, -0.7], ellipse: false, visibleToCamera: true, castShadow }));
				}
				await r.setScene(desc);
				Object.assign(r.settings, { maxSamples: 0, maxBounces: 8, fireflyClamp: 0 });
				let quiet = 0;
				for (let frame = 0; frame < 512; frame++) {
					r.renderFrame(); await r.device.queue.onSubmittedWorkDone();
					await new Promise(resolve => setTimeout(resolve, 0));
					const vt = r.virtualTextureStats;
					quiet = !vt || (vt.uploadsLastFrame === 0 && vt.pendingRequests === 0) ? quiet + 1 : 0;
					if (frame >= 63 && quiet >= 32) break;
				}
				check(quiet >= 32, `${scene.name}: texture warmup did not settle`);
				r.updateStreaming = () => {};
				for (const config of scene.configurations) {
					canvas.style.width = `${config.width}px`; canvas.style.height = `${config.height}px`; r.resize();
					const reference = await render('megakernel', config);
					const candidate = await render('wavefront', config);
					let maxError = 0, squared = 0, refSquared = 0;
					for (let i = 0; i < reference.length; i++) {
						check(Number.isFinite(candidate[i]) && Number.isFinite(reference[i]), `${scene.name}: nonfinite output`);
						const error = Math.abs(reference[i] - candidate[i]);
						maxError = Math.max(maxError, error); squared += error * error; refSquared += reference[i] * reference[i];
					}
					const relativeL2 = Math.sqrt(squared / Math.max(refSquared, 1e-30));
					const result = { scene: scene.name, ...config, maxError, relativeL2 };
					results.push(result);
					console.log(`[correctness] ${JSON.stringify(result)}`);
					check(maxError <= 1e-5, `${scene.name}: GPU integrators differ by ${maxError}`);
					// Switch back on the same renderer and make sure reallocation/reset is complete.
					await r.setIntegrator('megakernel');
					check(r.samples === 0, 'Integrator switch failed to reset samples');
				}
			}
		} finally { r.destroy(); }
		return results;
	}, { tailStart, tailThreshold });
	writeFileSync(join(output, 'report.json'), JSON.stringify({ browser: await browser.version(), tailStart, tailThreshold, results, errors }, null, 2));
	if (errors.length) throw new Error(errors.join('\n'));
	console.log(`[correctness] ${results.length} GPU regression cases passed`);
} finally { await browser.close(); await server.close(); }
