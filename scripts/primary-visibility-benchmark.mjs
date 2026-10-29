// Paired primary-visibility measurements. Includes raster passes and queue/copy gaps
// in the complete GPU span; does not infer a speedup from draw-call counts.
import { createServer } from 'vite';
import puppeteer from 'puppeteer-core';
import { createReadStream, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { shaderFingerprint } from './shader-fingerprint.mjs';
import { resolve } from 'node:path';
const option = (name, fallback) => { const i = process.argv.indexOf(`--${name}`); return i < 0 ? fallback : process.argv[i + 1]; };
const root = resolve('.'), output = resolve(option('output', '.tools/visibility/benchmark'));
mkdirSync(output, { recursive: true });
const config = { rounds: Number(option('rounds', '5')), warmup: Number(option('warmup', '64')), samples: Number(option('samples', '128')),
	resolutions: option('resolutions', '640x360,1280x720,1920x1080').split(',').map(s => s.split('x').map(Number)) };
const files = { classroom: 'classroom/gltf/classroom_extended.glb', breakfast: 'breakfast-room/gltf/breakfast_room_extended.glb', bmw: 'bmw-m6/gltf/bmw_m6_extended.glb', glass: 'glass-of-water/gltf/glass_of_water_extended.glb', mis: 'veach-mis/gltf/veach_mis_extended.glb' };
const only = option('only', '').split(',').filter(Boolean);
const cases = [...Object.keys(files), 'opaque-shadow', 'mixed-alpha', 'deep-alpha', 'many-instances', 'offscreen-instances'].filter(n => !only.length || only.includes(n));
const server = await createServer({ root, logLevel: 'warn', server: { port: 5208, strictPort: false, hmr: false }, plugins: [{ name: 'visibility-research', configureServer(s) {
	s.middlewares.use('/__visibility', (req, res, next) => { const name = req.url?.slice(1).split('?')[0]; if (!files[name]) return next();
		const path = resolve(option('scenes', 'E:/GitHub/gltf-research-scenes/scenes'), files[name]);
		if (!existsSync(path)) { res.statusCode = 404; res.end(path); return; } res.setHeader('Content-Type', 'model/gltf-binary'); createReadStream(path).pipe(res); });
} }] });
await server.listen();
const chrome = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe', 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].find(p => p && existsSync(p));
const browser = await puppeteer.launch({ executablePath: chrome, headless: true, protocolTimeout: 3600000, args: ['--enable-unsafe-webgpu', '--ignore-gpu-blocklist', '--no-sandbox', '--disable-background-timer-throttling'] });
const fingerprint = () => {
	const hash = createHash('sha256').update(shaderFingerprint(root));
	for (const path of ['Wavefront', 'PathTracer', 'Renderer', 'VisibilityBuffer', 'VisibilityClusters', 'PrimaryVisibility', 'GpuScene', 'HostGpuScene', 'GpuLayout'])
		hash.update(readFileSync(resolve(root, 'src/render', path + '.ts')));
	return hash.update(readFileSync(resolve(root, 'scripts/primary-visibility-benchmark.mjs'))).digest('hex');
};
const report = { config, startedAt: new Date().toISOString(), browser: await browser.version(), sourceFingerprint: fingerprint(), completed: false, cases: [], errors: [] };
const save = () => writeFileSync(resolve(output, 'report.json'), JSON.stringify(report, null, 2));
try {
	for (const name of cases) {
		const page = await browser.newPage();
		page.on('pageerror', e => report.errors.push(String(e)));
		page.on('console', m => { if (m.type() === 'error') report.errors.push(m.text()); if (m.text().startsWith('[visibility-bench]')) console.log(m.text()); });
		await page.goto(server.resolvedUrls.local[0] + 'scripts/benchmark.html');
		const result = await page.evaluate(async ({ name, external, config }) => {
			const api = await import('/src/index.ts'), { cyclesFixture } = await import('/scripts/wavefront-cycles-fixtures.ts');
			const requestDevice = GPUAdapter.prototype.requestDevice;
			GPUAdapter.prototype.requestDevice = function(d = {}) { return requestDevice.call(this, { ...d, requiredFeatures: [...new Set([...(d.requiredFeatures ?? []), 'timestamp-query'])], requiredLimits: { ...d.requiredLimits, maxStorageBuffersPerShaderStage: 8 } }); };
			const canvas = document.querySelector('canvas'); canvas.style.cssText = 'width:640px;height:360px';
			const r = await api.Renderer.create(canvas, { denoiser: null }); GPUAdapter.prototype.requestDevice = requestDevice;
			Object.assign(r.settings, { maxSamples: 0, maxBounces: 8, autoExposureMethod: api.AutoExposureMethod.Manual, localExposureMethod: api.LocalExposureMethod.None, environmentIntensity: ['glass', 'mis'].includes(name) ? 0 : 1 });
			r.sun.enabled = !['glass', 'mis'].includes(name);
			const desc = external ? await api.loadGLTF('/__visibility/' + name) : cyclesFixture(['mixed-alpha', 'deep-alpha'].includes(name) ? name : 'opaque-shadow');
			if (name.includes('instances')) {
				desc.meshes = [desc.meshes[1]];
				desc.instances = Array.from({ length: 10000 }, (_, i) => { const m = new Float32Array([1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]);
					m[0] = m[5] = 0.015; m[12] = (i % 100 - 50) * 0.03 + (name.startsWith('offscreen') && i > 99 ? 100 : 0); m[13] = (Math.floor(i / 100) - 50) * 0.03;
					return { mesh: 0, transform: m }; });
			}
			await r.setScene(desc);
			if (desc.cameras.length) { r.camera.setFromMatrix(desc.cameras[0].transform, 5); r.camera.fovY = desc.cameras[0].yfov; }
			const device = r.device, queryCapacity = 4096;
			const queries = device.createQuerySet({ type: 'timestamp', count: queryCapacity });
			const resolved = device.createBuffer({ size: queryCapacity * 8, usage: GPUBufferUsage.QUERY_RESOLVE | GPUBufferUsage.COPY_SRC });
			const readback = device.createBuffer({ size: queryCapacity * 8, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
			const beginCompute = GPUCommandEncoder.prototype.beginComputePass, beginRender = GPUCommandEncoder.prototype.beginRenderPass;
			let measuring = false, labels = [];
			function stamp(d) {
				if (!measuring || !/^(visibility\.|wavefront\.)/.test(d.label ?? '')) return d;
				const i = labels.length * 2; if (i + 1 >= queryCapacity) throw new Error('Timestamp query capacity exceeded');
				labels.push(d.label); return { ...d, timestampWrites: { querySet: queries, beginningOfPassWriteIndex: i, endOfPassWriteIndex: i + 1 } };
			}
			GPUCommandEncoder.prototype.beginComputePass = function(d = {}) { return beginCompute.call(this, stamp(d)); };
			GPUCommandEncoder.prototype.beginRenderPass = function(d) { return beginRender.call(this, stamp(d)); };
			const measurements = [];
			const median = values => { const s = [...values].sort((a,b)=>a-b); return s[Math.floor(s.length/2)]; };
			try {
				for (const [width, height] of config.resolutions) {
					canvas.style.cssText = `width:${width}px;height:${height}px`; r.resize();
					for (let i = 0; i < config.warmup; i++) { r.renderFrame(); await device.queue.onSubmittedWorkDone(); }
					const updateStreaming = r.updateStreaming; r.updateStreaming = () => {};
					for (let round = 0; round < config.rounds; round++) {
						const order = round % 2 ? ['rasterized', 'shared-reference', 'default'] : ['default', 'shared-reference', 'rasterized'];
						for (const mode of order) {
							await r.setPrimaryVisibility(mode === 'rasterized' ? 'rasterized' : 'ray-traced'); r.tracer.sharedPrimaryJitter = mode !== 'default'; r.resetAccumulation();
							for (let i = 0; i < config.warmup; i++) { r.renderFrame(); await device.queue.onSubmittedWorkDone(); }
							const spans = [], cpu = [], primary = [], primaryKernels = [], stages = {};
							for (let sample = 0; sample < config.samples; sample++) {
								labels = []; measuring = true; const start = performance.now(); r.renderFrame(); cpu.push(performance.now()-start); measuring = false;
								const encoder = device.createCommandEncoder(); encoder.resolveQuerySet(queries, 0, labels.length * 2, resolved, 0);
								encoder.copyBufferToBuffer(resolved, 0, readback, 0, labels.length * 16); device.queue.submit([encoder.finish()]);
								await readback.mapAsync(GPUMapMode.READ); const t = new BigUint64Array(readback.getMappedRange());
								spans.push(Number(t[labels.length*2-1]-t[0])/1e6); let p = 0, primarySpan = 0, primaryStart = null;
								for (let i=0;i<labels.length;i++) {
									const ms=Number(t[i*2+1]-t[i*2])/1e6, label=labels[i], stage=label.replace(/\.b\d+$/, '');
									(stages[stage] ??= []).push(ms);
									if (/^visibility\.|^wavefront\.(ResolvePrimaryVisibility|CompactPrimaryFallback|PrimaryFallbackArguments|PrimaryTraceFallback(?:Sparse)?)\.|^wavefront\.Intersect\.b0$/.test(label)) p+=ms;
									if (label === 'visibility.cull' || label === 'wavefront.ResolvePrimaryVisibility.b0') primaryStart = t[i*2];
									if (label === 'visibility.raster' || label === 'wavefront.PrimaryTraceFallbackSparse.b0') {
										if (primaryStart === null) throw new Error('Missing primary stage start');
										primarySpan += Number(t[i*2+1] - primaryStart) / 1e6; primaryStart = null;
									}
									if (label === 'wavefront.Intersect.b0') primarySpan += ms;
								}
								primary.push(primarySpan); primaryKernels.push(p); readback.unmap();
							}
							const stats = await r.readPrimaryVisibilityStats();
							const measurement = { width,height,round,mode,gpuMs:median(spans),cpuMs:median(cpu),primaryMs:median(primary),primaryKernelMs:median(primaryKernels),stages:Object.fromEntries(Object.entries(stages).map(([k,v])=>[k,median(v)])),stats, hasAlphaTested: r.scene.hasAlphaTested,
								bufferBytes: ['nodes','tris','instances','vertices','indices','materials','lights'].reduce((sum,k)=>sum+r.scene[k].size,0)+r.tracer.accumulation.size };
							measurements.push(measurement); console.log('[visibility-bench] '+JSON.stringify({name,width,height,round,mode,gpuMs:measurement.gpuMs,primaryMs:measurement.primaryMs,stats}));
						}
					}
					r.updateStreaming = updateStreaming;
				}
				const info = device.adapterInfo;
				return { name, adapter: info ? { vendor: info.vendor, architecture: info.architecture, device: info.device, description: info.description } : null, scene: r.sceneStats, measurements };
			} finally { GPUCommandEncoder.prototype.beginComputePass=beginCompute;GPUCommandEncoder.prototype.beginRenderPass=beginRender;queries.destroy();resolved.destroy();readback.destroy();r.destroy(); }
		}, { name, external: name in files, config });
		report.cases.push(result); save(); await page.close();
	}
	if (fingerprint() !== report.sourceFingerprint) throw new Error('Renderer sources changed during measurement');
	report.completed = true; if (report.errors.length) throw new Error(report.errors.join('\n'));
} catch (error) { report.failure = String(error); throw error; }
finally { save(); await browser.close(); await server.close(); }
