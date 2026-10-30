// Headless NRD check: real-time wavefront frames with NRD REBLUR before TAA. Verifies the NRD state,
// that the noisy diffuse/specular split recomposes the raw radiance, finite output and no GPU/console
// errors, and saves screenshots plus a report to .tools/nrd. Runs in SH mode (default) and compares, from
// the same camera start, SH + re-jitter, SH without re-jitter, radiance mode and TAA only, static and in motion.
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';
import { createServer } from 'vite';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = join(root, '.tools', 'nrd');
mkdirSync(outDir, { recursive: true });
const chrome = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe', '/usr/bin/google-chrome'].find(p => p && existsSync(p));
const scenes = {
	helmet: 'model=/samples/DamagedHelmet.glb&env=/samples/studio_small_09_1k.hdr',
	spheres: 'model=/samples/MetalRoughSpheres.glb&env=/samples/studio_small_09_1k.hdr',
	sunset: 'model=/samples/DamagedHelmet.glb&sunElevation=8&sunAzimuth=60',
	alpha: 'model=/samples/AlphaBlendModeTest.glb',
	transmission: 'model=/samples/TransmissionTest.glb&env=/samples/studio_small_09_1k.hdr',
	megakernel: 'model=/samples/DamagedHelmet.glb&integrator=megakernel',
};
const only = process.argv.slice(2);

const server = await createServer({ root, server: { port: 5201, strictPort: false }, logLevel: 'warn' });
await server.listen();
const base = server.resolvedUrls.local[0];
const browser = await puppeteer.launch({ executablePath: chrome, headless: true, protocolTimeout: 300000,
	args: ['--enable-unsafe-webgpu', '--enable-features=Vulkan', '--ignore-gpu-blocklist', '--no-sandbox'] });
const report = {};
let failures = 0;
try {
	for (const [name, query] of Object.entries(scenes)) {
		if (only.length && !only.includes(name)) continue;
		const page = await browser.newPage();
		await page.setViewport({ width: 960, height: 640, deviceScaleFactor: 1 });
		const errors = [];
		page.on('pageerror', e => errors.push(String(e)));
		page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') errors.push(`${m.type()}: ${m.text()}`); });
		const frames = async count => {
			const start = await page.evaluate(() => globalThis.veach.nrdStats.frames + globalThis.veach.taaStats.historyFrames);
			await page.waitForFunction((s, n) => globalThis.veach.nrdStats.frames + globalThis.veach.taaStats.historyFrames >= s + n, { timeout: 120000 }, start, count);
		};
		const shot = async label => {
			const file = join(outDir, `${name}-${label}.png`);
			await page.screenshot({ path: file });
			return file;
		};
		try {
			await page.goto(`${base}?${query}&nrd=1`, { waitUntil: 'load' });
			if (name === 'megakernel') await page.waitForFunction(() => globalThis.veach?.taaStats.historyFrames >= 30, { timeout: 240000 });
			else await page.waitForFunction(() => globalThis.veach?.nrdStats.frames >= 60, { timeout: 240000 });
			const device = await page.evaluate(() => ({ features: [...globalThis.veach.device.features].filter(f => /float32|tier1|f16/.test(f)),
				storageTextures: globalThis.veach.device.limits.maxStorageTexturesPerShaderStage, sampledTextures: globalThis.veach.device.limits.maxSampledTexturesPerShaderStage }));
			const stats = await page.evaluate(() => globalThis.veach.nrdStats);
			await shot('nrd');
			if (name === 'megakernel') {
				const finite = await page.evaluate(() => globalThis.veach.tracer.presentation !== null);
				const ok = !stats.active && stats.reason === 'integrator' && finite && errors.length === 0;
				report[name] = { ok, stats, errors };
				console.log(`${ok ? 'ok  ' : 'FAIL'} ${name} ${JSON.stringify({ stats, errors })}`);
				if (!ok) failures++;
				continue;
			}
			// Split identity: with debug 1 the composite is bypass + noisy diffuse + noisy specular.
			await page.evaluate(() => { globalThis.veach.settings.nrdDebug = 1; });
			await frames(4);
			const identity = await page.evaluate(async () => {
				const r = globalThis.veach, accumulation = r.tracer.accumulation, composite = r.nrd.composite;
				const bytes = r.tracer.width * r.tracer.height * 48;
				const staging = r.device.createBuffer({ size: bytes * 2, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST });
				const encoder = r.device.createCommandEncoder();
				encoder.copyBufferToBuffer(accumulation, 0, staging, 0, bytes); encoder.copyBufferToBuffer(composite, 0, staging, bytes, bytes);
				r.device.queue.submit([encoder.finish()]);
				await staging.mapAsync(GPUMapMode.READ);
				const raw = new Float32Array(staging.getMappedRange(0, bytes)).slice(), split = new Float32Array(staging.getMappedRange(bytes, bytes)).slice();
				staging.destroy();
				let maxError = 0, sum = 0, finite = true;
				for (let p = 0; p < raw.length; p += 12) for (let c = 0; c < 3; c++) {
					const a = raw[p + c], b = split[p + c];
					finite &&= Number.isFinite(b);
					const error = Math.abs(a - b) / Math.max(1e-3, Math.abs(a));
					maxError = Math.max(maxError, error); sum += a;
				}
				return { maxRelativeError: maxError, meanRadiance: sum / (raw.length / 4), finite };
			});
			for (const [debug, label] of [[2, 'diffuse'], [3, 'specular'], [4, 'guides'], [5, 'rejitter-scale']]) {
				await page.evaluate(d => { globalThis.veach.settings.nrdDebug = d; }, debug);
				await frames(3);
				await shot(label);
			}
			await page.evaluate(() => { globalThis.veach.settings.nrdDebug = 0; });
			const profile = await page.evaluate(async () => {
				const p = globalThis.veach.gpuProfiler;
				p.capture();
				for (let i = 0; i < 200 && p.status !== 'ready' && p.status !== 'error'; i++) await new Promise(r => setTimeout(r, 50));
				const scopes = p.report?.scopes ?? p.report?.passes ?? null;
				return { status: p.status, error: p.error, report: p.report ? JSON.parse(JSON.stringify(p.report)) : null, scopes };
			});
			const finite = await page.evaluate(async () => {
				const r = globalThis.veach, output = r.tracer.presentation;
				const staging = r.device.createBuffer({ size: output.size, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST });
				const encoder = r.device.createCommandEncoder(); encoder.copyBufferToBuffer(output, 0, staging, 0, output.size);
				r.device.queue.submit([encoder.finish()]); await staging.mapAsync(GPUMapMode.READ);
				const data = new Float32Array(staging.getMappedRange()); let ok = true;
				for (let i = 0; i < data.length; i++) ok &&= Number.isFinite(data[i]);
				staging.destroy(); return ok;
			});
			// From the same start: settle 30 frames (static shot), then orbit 40 frames (0.75 degrees each).
			const orbit = async (config, label) => {
				await page.evaluate(async ({ nrd, mode, reJitter }) => {
					const r = globalThis.veach, c = r.camera;
					globalThis.__nrdStart ??= { position: [...c.position] };
					c.position = [...globalThis.__nrdStart.position];
					if (nrd) await r.setNrd(true, mode); else r.settings.nrdEnabled = false;
					r.settings.nrdReJitter = reJitter;
				}, config);
				// A newly selected mode compiles its REBLUR pipelines lazily (noisy split meanwhile).
				if (config.nrd) await page.waitForFunction(() => globalThis.veach.nrdStats.reason === null, { timeout: 120000 });
				await page.evaluate(() => globalThis.veach.resetTaa());
				// Every mode restarts its history (TAA reset also restarts NRD) and settles equally long.
				await page.waitForFunction(() => globalThis.veach.taaStats.historyFrames >= 60, { timeout: 120000 });
				await shot(`${label}-static`);
				await page.evaluate(() => new Promise(done => {
					const r = globalThis.veach, c = r.camera;
					let left = 40;
					const step = () => {
						const o = c.position.map((v, i) => v - c.target[i]), a = 0.75 * Math.PI / 180;
						c.position = [c.target[0] + o[0] * Math.cos(a) + o[2] * Math.sin(a), c.position[1], c.target[2] - o[0] * Math.sin(a) + o[2] * Math.cos(a)];
						if (--left > 0) requestAnimationFrame(step); else done();
					};
					requestAnimationFrame(step);
				}));
				await shot(label);
			};
			await orbit({ nrd: true, mode: 'sh', reJitter: true }, 'sh');
			await orbit({ nrd: true, mode: 'sh', reJitter: false }, 'sh-norejitter');
			await orbit({ nrd: true, mode: 'radiance', reJitter: false }, 'radiance');
			const radiance = await page.evaluate(() => globalThis.veach.nrdStats);
			await orbit({ nrd: false, mode: 'sh', reJitter: true }, 'taa');
			const ok = stats.active && stats.reason === null && stats.mode === 'sh' && stats.dispatches > 0 && radiance.active && radiance.mode === 'radiance'
				&& identity.finite && identity.maxRelativeError < 1e-2 && finite && errors.length === 0;
			report[name] = { ok, device, stats, radiance, identity, finite, profile, errors };
			console.log(`${ok ? 'ok  ' : 'FAIL'} ${name} ${JSON.stringify({ stats, radiance, identity, finite, errors })}`);
			if (!ok) failures++;
		} catch (error) {
			failures++;
			report[name] = { ok: false, error: String(error), errors };
			console.log(`FAIL ${name} ${error} ${JSON.stringify(errors)}`);
			await shot('error').catch(() => {});
		} finally { await page.close(); }
	}
} finally {
	writeFileSync(join(outDir, 'report.json'), JSON.stringify(report, null, 2));
	await browser.close();
	await server.close();
}
process.exit(failures ? 1 : 0);
