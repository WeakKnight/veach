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
const onlyOption = process.argv.indexOf('--only');
const only = onlyOption < 0 ? [] : process.argv[onlyOption + 1].split(',');
const disableSubgroups = process.argv.includes('--disable-subgroups');
const compactionOption = process.argv.indexOf('--compaction');
const compaction = compactionOption < 0 ? 'dense' : process.argv[compactionOption + 1];
const directOption = process.argv.indexOf('--direct-stages');
const directStages = directOption < 0 ? 0 : Number(process.argv[directOption + 1]);
const packetOption = process.argv.indexOf('--packet-stages');
const packetStages = packetOption < 0 ? 7 : Number(process.argv[packetOption + 1]);
const packetSweep = process.argv.includes('--packet-sweep');
if (!Number.isInteger(packetStages) || packetStages < 0 || packetStages > 7) throw new Error('Invalid packet stage mask');
const dispatchSweep = process.argv.includes('--dispatch-sweep');
if (!Number.isInteger(directStages) || directStages < 0 || directStages > 7) throw new Error('Invalid direct stage mask');
if (packetSweep && (compaction !== 'packet' || dispatchSweep)) throw new Error('Packet sweep requires packet compaction and cannot combine with dispatch sweep');
if (dispatchSweep && compaction === 'none') throw new Error('Dispatch sweep requires a compaction mode');
if (!['dense', 'queued', 'subgroup', 'adaptive', 'packet', 'none'].includes(compaction)) throw new Error('Invalid compaction mode');
if ((compaction === 'none' || compaction === 'packet' || directStages === 7) && tailThreshold !== 0) throw new Error('Direct/packet dispatch supports fixed tails only');
if (!Number.isInteger(tailStart) || tailStart < 0) throw new Error('Invalid tail start');
const output = join(root, `.tools/wavefront/correctness-tail-${tailStart}-${tailThreshold}${only.length ? '-selected' : ''}${disableSubgroups ? '-no-subgroups' : ''}-${compaction}${packetSweep ? '-packet-sweep' : packetStages !== 7 ? `-packet-${packetStages}` : ''}${dispatchSweep ? '-dispatch-sweep' : directStages ? `-direct-${directStages}` : ''}`);
mkdirSync(output, { recursive: true });
const chrome = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe',
	'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', '/usr/bin/google-chrome', '/usr/bin/chromium'].find(p => p && existsSync(p));
if (!chrome) throw new Error('Set CHROME_PATH');
const server = await createServer({ root, logLevel: 'warn', server: { port: 5205, strictPort: false } });
await server.listen();
const browser = await puppeteer.launch({ executablePath: chrome, headless: true, protocolTimeout: 1800000,
	args: ['--enable-unsafe-webgpu', '--ignore-gpu-blocklist', '--no-sandbox'] });
const errors = [];
const report = { started: new Date().toISOString(), completed: false, browser: await browser.version(), tailStart, tailThreshold, only, directStages, dispatchSweep, packetStages, packetSweep, results: [], errors };
writeFileSync(join(output, 'report.json'), JSON.stringify(report, null, 2));
try {
	const page = await browser.newPage();
	await page.setViewport({ width: 640, height: 640, deviceScaleFactor: 1 });
	page.on('pageerror', e => errors.push(String(e)));
	page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); if (msg.text().startsWith('[correctness]')) console.log(msg.text()); });
	await page.goto(server.resolvedUrls.local[0] + 'scripts/benchmark.html');
	const results = await page.evaluate(async ({ tailStart, tailThreshold, only, disableSubgroups, compaction, directStages, dispatchSweep, packetStages, packetSweep }) => {
		const api = await import('/src/index.ts');
		const check = (value, message) => { if (!value) throw new Error(message); };
		const requestDevice = GPUAdapter.prototype.requestDevice;
		GPUAdapter.prototype.requestDevice = function(descriptor = {}) {
			return requestDevice.call(this, { ...descriptor,
				requiredFeatures: (descriptor.requiredFeatures ?? []).filter(feature => !disableSubgroups || feature !== 'subgroups'),
				requiredLimits: { ...descriptor.requiredLimits, maxStorageBuffersPerShaderStage: 8 } });
		};
		const canvas = document.querySelector('canvas');
		canvas.style.cssText = 'width:129px;height:97px';
		const r = await api.Renderer.create(canvas, { denoiser: null });
		GPUAdapter.prototype.requestDevice = requestDevice;
		check(r.device.limits.maxStorageBuffersPerShaderStage === 8, 'Storage binding budget was not enforced');
		check(!disableSubgroups || !r.device.features.has('subgroups'), 'Subgroups were not disabled');
		check(compaction !== 'subgroup' || r.device.features.has('subgroups'), 'Subgroup compaction is unavailable');
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
		async function render(mode, config, capacity = null, stageMask = directStages, packetMask = packetStages) {
			r.tracer.materialStackOverride = capacity;
			await r.tracer.prepareScene(r.scene);
			r.bindScene();
			const expectedCapacity = capacity ?? [0, 1, 2, 4, 8, 16].find(n => n >= r.scene.materialStackSize);
			check(r.tracer.materialCapacity === expectedCapacity, 'Incorrect material capacity selection');
			await r.setIntegrator(mode);
			if (mode === 'wavefront' && r.tracer.wavefront) Object.assign(r.tracer.wavefront, { tailStart, tailThreshold, compaction, directStages: stageMask, packetStages: packetMask });
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
			{ name: 'empty-analytic', file: null, emptyAnalytic: true, configurations: [
				{ width: 129, height: 97, bounces: 8, samples: 8 },
			] },
			{ name: 'alpha', file: 'AlphaBlendModeTest.glb', configurations: [
				{ width: 129, height: 97, bounces: 0, samples: 4 },
				{ width: 129, height: 97, bounces: 8, samples: 16, clamp: 2 },
			] },
			{ name: 'constant-alpha', file: 'AlphaBlendModeTest.glb', constant: true, configurations: [
				{ width: 7, height: 5, bounces: 8, samples: 8 },
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
				{ width: 513, height: 513, bounces: 1, samples: 2 },
			] },
			{ name: 'helmet', file: 'DamagedHelmet.glb', configurations: [
				{ width: 129, height: 97, bounces: 4, samples: 8 },
			] },
			{ name: 'specgloss', file: 'SpecGlossVsMetalRough.glb', configurations: [
				{ width: 129, height: 97, bounces: 4, samples: 8 },
			] },
			{ name: 'anisotropy', file: 'AnisotropyBarnLamp.glb', configurations: [
				{ width: 129, height: 97, bounces: 4, samples: 8 },
			] },
			{ name: 'empty-return', file: null, configurations: [
				{ width: 129, height: 97, bounces: 8, samples: 4 },
			] },
		];
		const selectedScenes = scenes.filter(scene => !only.length || only.includes(scene.name));
		check(selectedScenes.length > 0, 'No selected correctness scenes');
		try {
			for (const scene of selectedScenes) {
				// Load with wavefront selected to cover deferred compilation and changes in
				// scratch allocation as geometry arrives, changes capacity, or disappears.
				await r.setIntegrator('wavefront');
				r.updateStreaming = originalUpdate;
				canvas.style.width = '129px'; canvas.style.height = '97px'; r.resize();
				const desc = scene.file ? await api.loadGLTF(`/samples/${scene.file}`) : { meshes: [], materials: [], textures: [], instances: [], cameras: [] };
				if (scene.analytic) {
					desc.lights = [true, false].map((castShadow, i) => ({ type: i === 0 ? 'point' : 'area', position: [i === 0 ? -2 : 2, 3, 3], direction: [0, -0.7, -0.7],
						power: [300, 200, 100], radius: 0.1, spotAngle: 1, spotBlend: 0.2, sizeU: [1, 0, 0], sizeV: [0, 0.7, -0.7], ellipse: false, visibleToCamera: true, castShadow }));
				}
				if (scene.emptyAnalytic) {
					desc.cameras = [{ name: 'lights', yfov: 0.7, transform: new Float32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 5, 1]) }];
					desc.lights = [false, true].map((area, i) => ({ type: area ? 'area' : 'point', position: [i === 0 ? -0.7 : 0.7, 0, 0], direction: [0, 0, 1],
						power: [50, 30, 10], radius: 0.4, spotAngle: 1, spotBlend: 0.2, sizeU: [0.6, 0, 0], sizeV: [0, 0.6, 0], ellipse: false, visibleToCamera: true, castShadow: true }));
				}
				if (scene.constant) {
					const { AlphaMode } = await import('/src/scene/Scene.ts');
					desc.materials.forEach((material, i) => {
						material.graph = { name: `constant-${i}`, surface: 0, alphaMode: i % 2 ? AlphaMode.Blend : AlphaMode.Mask,
							alphaCutoff: 0.5, doubleSided: true, nodes: [{ category: 'open_pbr_surface', type: 'surfaceshader', inputs: {
								base_color: { value: [0.7, 0.2, 0.1] }, specular_roughness: { value: [0.15 + 0.1 * (i % 5)] },
								geometry_opacity: { value: [(i % 4) / 3] }, geometry_thin_walled: { value: [1] },
								transmission_weight: { value: [0.5] }, coat_weight: { value: [0.3] },
								emission_luminance: { value: [0.1] }, emission_color: { value: [1, 0.2, 0.1] },
							} }] };
					});
					const { compileSceneMaterials } = await import('/src/render/SceneMaterials.ts');
					const constantMaterials = compileSceneMaterials(desc).slice(0, -1);
					// Opacity 1 is the default and is removed by constant folding.
					check(constantMaterials.every((m, i) => m.stackSize === 0 && m.alphaTested === (i % 4 !== 3) && m.emissive),
						`Constant graph metadata: ${JSON.stringify(constantMaterials.map(m => ({ name: m.name, stack: m.stackSize, alpha: m.alphaTested, emissive: m.emissive })))}`);
				}
				await r.setScene(desc);
				if (scene.constant) check(r.scene.materialStackSize === 0 && r.tracer.materialCapacity === 0, 'Constant material specialization was not exercised');
				Object.assign(r.settings, { maxSamples: 0, maxBounces: 8, fireflyClamp: 0, environmentIntensity: scene.emptyAnalytic ? 0 : 1 });
				r.sun.enabled = !scene.emptyAnalytic;
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
					const reference = await render('megakernel', config, 16);
					if (scene.emptyAnalytic) check(reference.some((value, i) => i % 12 < 3 && value > 0), 'Empty analytic-light test did not see a light');
					const masks = dispatchSweep ? Array.from({ length: tailThreshold === 0 ? 8 : 7 }, (_, i) => i) : [directStages];
					const packetMasks = packetSweep ? Array.from({ length: 8 }, (_, i) => i) : [packetStages];
					for (const { mode, stageMask, packetMask } of [{ mode: 'megakernel', stageMask: 0, packetMask: packetStages }, ...packetMasks.flatMap(packetMask => masks.map(stageMask => ({ mode: 'wavefront', stageMask, packetMask })))]) {
						const candidate = await render(mode, config, null, stageMask, packetMask);
						let maxError = 0, squared = 0, refSquared = 0;
						for (let i = 0; i < reference.length; i++) {
							check(Number.isFinite(candidate[i]) && Number.isFinite(reference[i]), `${scene.name}: nonfinite output`);
							const error = Math.abs(reference[i] - candidate[i]);
							maxError = Math.max(maxError, error); squared += error * error; refSquared += reference[i] * reference[i];
						}
						const relativeL2 = Math.sqrt(squared / Math.max(refSquared, 1e-30));
						const result = { scene: scene.name, mode, compaction, directStages: stageMask, packetStages: packetMask, subgroups: r.device.features.has('subgroups'), materialCapacity: r.tracer.materialCapacity, ...config, maxError, relativeL2 };
						results.push(result);
						console.log(`[correctness] ${JSON.stringify(result)}`);
						check(maxError <= 1e-5, `${scene.name}: GPU integrators differ by ${maxError}`);
					}
					// Switch back on the same renderer and make sure reallocation/reset is complete.
					await r.setIntegrator('megakernel');
					check(r.samples === 0, 'Integrator switch failed to reset samples');
				}
			}
		} finally { r.destroy(); }
		return results;
	}, { tailStart, tailThreshold, only, disableSubgroups, compaction, directStages, dispatchSweep, packetStages, packetSweep });
	if (errors.length) throw new Error(errors.join('\n'));
	Object.assign(report, { completed: true, results, finished: new Date().toISOString() });
	writeFileSync(join(output, 'report.json'), JSON.stringify(report, null, 2));
	console.log(`[correctness] ${results.length} GPU regression cases passed`);
} catch (error) {
	writeFileSync(join(output, 'report.json'), JSON.stringify({ ...report, completed: false, failure: String(error), finished: new Date().toISOString() }, null, 2));
	throw error;
} finally { await browser.close(); await server.close(); }
