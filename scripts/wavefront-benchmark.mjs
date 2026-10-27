// Reproducible GPU timings and linear HDR captures for the wavefront experiment.
// Uses the production renderer, a fixed camera, and timestamp queries on tracing passes only.
import { createReadStream, existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
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
	tailStart: Number(option('tail-start', 999)),
	tailThreshold: Number(option('tail-threshold', 0)),
	paired: args.includes('--paired'),
	materialStack: option('material-stack', 'auto') === 'auto' ? null : Number(option('material-stack', 'auto')),
	tailSweep: args.includes('--tail-sweep'),
	subgroups: !args.includes('--disable-subgroups'),
	compaction: option('compaction', 'dense'),
	compactionSweep: args.includes('--compaction-sweep'),
};
if (!['dense', 'queued', 'subgroup', 'adaptive', 'none'].includes(config.compaction)) throw new Error('Invalid compaction mode');
if (config.compaction === 'none' && config.tailThreshold !== 0) throw new Error('Direct dispatch supports fixed tails only');
if (config.materialStack !== null && ![1, 2, 4, 8, 16].includes(config.materialStack)) throw new Error('Invalid material stack capacity');
if (config.paired && config.mode !== 'wavefront') throw new Error('--paired requires --mode wavefront');
if (config.tailSweep && !config.paired) throw new Error('--tail-sweep requires --paired --mode wavefront');
if (config.compactionSweep && (!config.paired || config.tailSweep)) throw new Error('--compaction-sweep requires --paired and cannot combine with --tail-sweep');
config.variants = [{ name: 'wavefront', tailStart: config.tailStart, tailThreshold: config.tailThreshold }];
if (config.tailSweep) {
	config.variants.push({ name: 'staged', tailStart: 999, tailThreshold: 0 },
		...[0, 1, 2, 3].map(tailStart => ({ name: `fixed-${tailStart}`, tailStart, tailThreshold: 0 })),
		...(config.compaction === 'none' ? [] : [8192, 32768, 131072]).map(tailThreshold => ({ name: `adaptive-${tailThreshold}`, tailStart: 0, tailThreshold })));
}
if (config.compactionSweep) {
	for (const compaction of ['dense', 'queued', 'subgroup', 'adaptive', 'none'].filter(mode => mode !== config.compaction
		&& (mode !== 'subgroup' || config.subgroups) && (mode !== 'none' || config.tailThreshold === 0)))
		config.variants.push({ name: `compact-${compaction}`, tailStart: config.tailStart, tailThreshold: config.tailThreshold, compaction });
}
for (const variant of config.variants) variant.compaction ??= config.compaction;
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
const candidateOutput = config.paired ? join(output, 'wavefront') : output;
const referenceOutput = join(output, 'megakernel');
mkdirSync(candidateOutput, { recursive: true });
if (config.paired) mkdirSync(referenceOutput, { recursive: true });
const chrome = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe',
	'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', '/usr/bin/google-chrome', '/usr/bin/chromium']
	.find(p => p && existsSync(p));
if (!chrome) throw new Error('Set CHROME_PATH to a WebGPU-capable browser');
const shaderPath = path => join(root, path);
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
const sourceHashes = () => {
	const paths = ['scripts/wavefront-benchmark.mjs', 'package.json', 'package-lock.json', 'vite.config.ts'];
	const visit = directory => {
		for (const entry of readdirSync(join(root, directory), { withFileTypes: true })) {
			const path = `${directory}/${entry.name}`;
			if (entry.isDirectory()) visit(path);
			else paths.push(path);
		}
	};
	visit('src');
	return Object.fromEntries(paths.sort().map(p => [p, createHash('sha256').update(readFileSync(shaderPath(p))).digest('hex')]));
};
const report = { started: new Date().toISOString(), revision: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim(),
	config, plannedScenes: cases.map(c => c.name), completed: false, browser: await browser.version(),
	sourceHashes: sourceHashes(), results: [] };
const assertUnchangedSources = () => {
	if (JSON.stringify(sourceHashes()) !== JSON.stringify(report.sourceHashes)) throw new Error('Renderer or benchmark sources changed during measurement');
};
const referenceReport = { ...report, config: { ...config, mode: 'megakernel' }, results: [] };
const variantReports = Object.fromEntries(config.variants.slice(1).map(variant => {
	mkdirSync(join(output, variant.name), { recursive: true });
	return [variant.name, { ...report, config: { ...config, tailStart: variant.tailStart, tailThreshold: variant.tailThreshold, compaction: variant.compaction }, results: [] }];
}));
writeFileSync(join(candidateOutput, 'report.json'), JSON.stringify(report, null, 2));
try {
	for (const c of cases) {
		assertUnchangedSources();
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
			const createShaderModule = GPUDevice.prototype.createShaderModule;
			const observedStackCapacities = {};
			const shaderCompilations = [], pipelineCompilations = [];
			const createComputePipeline = GPUDevice.prototype.createComputePipelineAsync;
			GPUDevice.prototype.createComputePipelineAsync = function(descriptor) {
				const start = performance.now();
				return createComputePipeline.call(this, descriptor).then(pipeline => {
					pipelineCompilations.push({ label: descriptor.label, elapsedMs: performance.now() - start });
					return pipeline;
				});
			};
			GPUDevice.prototype.createShaderModule = function(descriptor) {
				if (descriptor.label === 'PathTracing' || descriptor.label === 'Wavefront') {
					const capacities = [...descriptor.code.matchAll(/var stack_\d+\s*:\s*array<vec4<f32>,\s*i32\((\d+)\)>/g)].map(match => Number(match[1]));
					if (!capacities.length || capacities.some(capacity => capacity !== capacities[0])) throw new Error('Unexpected effective SVM shader capacity');
					observedStackCapacities[descriptor.label] = capacities;
					shaderCompilations.push({ label: descriptor.label, capacities, bytes: descriptor.code.length });
				}
				return createShaderModule.call(this, descriptor);
			};
			const requestDevice = GPUAdapter.prototype.requestDevice;
			let adapterInfo;
			GPUAdapter.prototype.requestDevice = function(descriptor = {}) {
				adapterInfo = { vendor: this.info.vendor, architecture: this.info.architecture, device: this.info.device, description: this.info.description };
				if (!this.features.has('timestamp-query')) throw new Error('This benchmark requires timestamp-query');
				return requestDevice.call(this, { ...descriptor,
					requiredLimits: { ...descriptor.requiredLimits, maxStorageBuffersPerShaderStage: config.storageBuffers },
					requiredFeatures: [...new Set([...(descriptor.requiredFeatures ?? []), 'timestamp-query'])]
						.filter(feature => config.subgroups || feature !== 'subgroups') });
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
			renderer.tracer.materialStackOverride = config.materialStack;
			Object.assign(renderer.settings, { maxSamples: 0, samplesPerFrame: 1, maxBounces: config.bounces,
				autoExposureMethod: AutoExposureMethod.Manual, autoExposureBias: 0, localExposureMethod: LocalExposureMethod.None,
				environmentIntensity: c.environment, fireflyClamp: config.clamp });
			renderer.sun.enabled = c.environment > 0;
			const integratorStart = performance.now();
			if (config.mode !== 'megakernel') await renderer.setIntegrator(config.mode);
			const integratorInitMs = performance.now() - integratorStart;
			const loadStart = performance.now();
			const sceneDescription = await loadGLTF(`/__research/${c.name}.glb`);
			const { compileSceneMaterials } = await import('/src/render/SceneMaterials.ts');
			const compiledMaterials = compileSceneMaterials(sceneDescription);
			const materialStackRequired = Math.max(0, ...compiledMaterials.map(material => material.stackSize));
			// Includes the fallback and unused materials, matching the conservative pipeline bound.
			const materialPrograms = { count: compiledMaterials.length,
				uniqueCodeBlocks: new Set(compiledMaterials.map(material => material.code.join(','))).size,
				constantOnly: compiledMaterials.filter(material => material.stackSize === 0).length,
				textured: compiledMaterials.filter(material => material.textures.length > 0).length,
				stackHistogram: Object.fromEntries([...new Set(compiledMaterials.map(material => material.stackSize))].sort((a, b) => a - b)
					.map(size => [size, compiledMaterials.filter(material => material.stackSize === size).length])) };
			if (config.materialStack !== null && materialStackRequired > config.materialStack) throw new Error(`Scene needs ${materialStackRequired} stack slots; variant has ${config.materialStack}`);
			await renderer.setScene(sceneDescription);
			const loadMs = performance.now() - loadStart;
			if (config.mode !== 'megakernel') {
				renderer.tracer.wavefront.tailStart = config.tailStart;
				renderer.tracer.wavefront.tailThreshold = config.tailThreshold;
				renderer.tracer.wavefront.compaction = config.compaction;
			}
			const materialCapacity = renderer.tracer.materialCapacity;
			const expectedCapacity = config.materialStack ?? [1, 2, 4, 8, 16].find(capacity => capacity >= materialStackRequired);
			if (materialCapacity !== expectedCapacity) throw new Error('Incorrect production material capacity selection');
			for (const label of config.mode === 'wavefront' ? ['PathTracing', 'Wavefront'] : ['PathTracing']) {
				if (!observedStackCapacities[label]?.length || observedStackCapacities[label].some(capacity => capacity !== materialCapacity)) throw new Error(`Incorrect ${label} shader specialization`);
			}
			GPUDevice.prototype.createShaderModule = createShaderModule;
			GPUDevice.prototype.createComputePipelineAsync = createComputePipeline;
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
			renderer.updateStreaming = () => {};
			// Current WebGPU createQuerySet validation caps count at 4096. This covers
			// a 4K image with 262144-path tiles and eight bounces, including adaptive tails.
			const queryCapacity = 4096;
			const queries = device.createQuerySet({ type: 'timestamp', count: queryCapacity });
			const resolved = device.createBuffer({ size: queryCapacity * 8, usage: GPUBufferUsage.QUERY_RESOLVE | GPUBufferUsage.COPY_SRC });
			const readback = device.createBuffer({ size: queryCapacity * 8, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
			const begin = GPUCommandEncoder.prototype.beginComputePass;
			const copyBuffer = GPUCommandEncoder.prototype.copyBufferToBuffer;
			const queueRecordBytes = 48; // Counts plus both indirect argument records.
			const queueReadback = config.diagnose ? device.createBuffer({ size: 4096 * queueRecordBytes, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ }) : null;
			let queueCopies = 0, captureQueues = false, queueSnapshots = [];
			const queuePhases = [];
			GPUCommandEncoder.prototype.copyBufferToBuffer = function(source, sourceOffset, destination, destinationOffset, size) {
				copyBuffer.call(this, source, sourceOffset, destination, destinationOffset, size);
				if (captureQueues && destination.label === 'wavefrontDispatch') {
					if (queueCopies >= 4096) throw new Error('Queue diagnostic capacity exceeded');
					queuePhases.push(labels.at(-1));
					copyBuffer.call(this, source, sourceOffset - 16, queueReadback, queueCopies++ * queueRecordBytes, queueRecordBytes);
				}
			};
			let labels = [], measuring = false;
			GPUCommandEncoder.prototype.beginComputePass = function(descriptor = {}) {
				if (measuring && (descriptor.label === 'pathTracing' || descriptor.label?.startsWith('wavefront.'))) {
					const index = labels.length * 2;
					if (index + 1 >= queryCapacity) throw new Error('Timestamp query capacity exceeded; reduce resolution or bounce count');
					labels.push(descriptor.label);
					descriptor = { ...descriptor, timestampWrites: { querySet: queries, beginningOfPassWriteIndex: index, endOfPassWriteIndex: index + 1 } };
				}
				return begin.call(this, descriptor);
			};
			const repeats = [];
			let candidateHDR, referenceHDR;
			const variantHDRs = new Map();
			let presentationVariant = config.mode;
			const pairedErrors = [];
			for (let repeat = 0; repeat < config.repeats; repeat++) {
				const schedule = config.paired ? [{ name: 'megakernel' }, ...config.variants] : [{ name: config.mode, tailStart: config.tailStart, tailThreshold: config.tailThreshold, compaction: config.compaction }];
				// Rotate the sweep and reverse alternating rounds to avoid always measuring a
				// configuration at the same position relative to GPU warmup and clock changes.
				if (config.tailSweep || config.compactionSweep) schedule.push(...schedule.splice(0, repeat % schedule.length));
				if (config.paired && repeat % 2 !== 0) schedule.reverse();
				for (const variant of schedule) {
					const mode = variant.name === 'megakernel' ? 'megakernel' : 'wavefront';
					presentationVariant = variant.name;
					if (config.paired) {
						await renderer.setIntegrator(mode);
						if (mode === 'wavefront') Object.assign(renderer.tracer.wavefront, { tailStart: variant.tailStart, tailThreshold: variant.tailThreshold, compaction: variant.compaction });
						// Warm each selected pipeline before timing while retaining identical scene/VT data.
						for (let warm = 0; warm < 8; warm++) { renderer.renderFrame(); await device.queue.onSubmittedWorkDone(); }
					}
					renderer.resetAccumulation();
					const timings = [], spanTimings = [], stages = {}, wall = performance.now();
					for (let sample = 0; sample < config.samples; sample++) {
						captureQueues = config.diagnose && sample === 0 && repeat === 0 && variant.name === 'wavefront';
						labels = []; measuring = true;
						renderer.renderFrame();
						captureQueues = false;
						measuring = false;
						if (!labels.length) throw new Error('No trace passes were measured');
						if (mode === 'wavefront' && variant.compaction === 'none' && labels.some(label => label.includes('.Compact')))
							throw new Error('Direct dispatch unexpectedly ran compaction');
						const encoder = device.createCommandEncoder();
						encoder.resolveQuerySet(queries, 0, labels.length * 2, resolved, 0);
						encoder.copyBufferToBuffer(resolved, 0, readback, 0, labels.length * 16);
						device.queue.submit([encoder.finish()]);
						await readback.mapAsync(GPUMapMode.READ);
						const timestamps = new BigUint64Array(readback.getMappedRange());
						let sum = 0;
						for (let i = 0; i < labels.length; i++) {
							if (timestamps[i * 2 + 1] < timestamps[i * 2]) throw new Error('Nonmonotonic GPU timestamps; repeat the measurement');
							const ms = Number(timestamps[i * 2 + 1] - timestamps[i * 2]) / 1e6;
							sum += ms;
							stages[labels[i]] = (stages[labels[i]] ?? 0) + ms;
						}
						timings.push(sum);
						if (timestamps[labels.length * 2 - 1] < timestamps[0]) throw new Error('Nonmonotonic GPU span; repeat the measurement');
						spanTimings.push(Number(timestamps[labels.length * 2 - 1] - timestamps[0]) / 1e6);
						readback.unmap();
					}
					const wallMs = performance.now() - wall;
					const sorted = [...timings].sort((a, b) => a - b);
					const medianMs = (sorted[Math.floor((sorted.length - 1) / 2)] + sorted[Math.floor(sorted.length / 2)]) * 0.5;
					const sortedSpans = [...spanTimings].sort((a, b) => a - b);
					const medianSpanMs = (sortedSpans[Math.floor((sortedSpans.length - 1) / 2)] + sortedSpans[Math.floor(sortedSpans.length / 2)]) * 0.5;
					repeats.push({ mode, variant: variant.name, repeat, medianMs, medianSpanMs, meanMs: timings.reduce((a, b) => a + b) / timings.length, wallMs, timings, spanTimings, stages });
					console.log(`[benchmark] ${c.name}: ${variant.name} repeat ${repeat + 1}, GPU passes ${medianMs.toFixed(3)}, span ${medianSpanMs.toFixed(3)} ms/sample`);
					if (config.paired) {
						const hdr = await renderer.readRadiance();
						if (mode === 'wavefront') {
							variantHDRs.set(variant.name, hdr);
							if (variant.name === 'wavefront') candidateHDR = hdr;
						}
						else referenceHDR = hdr;
					}
				}
				if (config.paired) {
					for (const [variant, candidate] of variantHDRs) {
						let maxError = 0, errorSquared = 0, referenceSquared = 0;
						for (let i = 0; i < candidate.data.length; i++) {
							const a = referenceHDR.data[i], b = candidate.data[i], error = Math.abs(a - b);
							if (!Number.isFinite(a) || !Number.isFinite(b)) throw new Error('Nonfinite paired HDR output');
							maxError = Math.max(maxError, error); errorSquared += error * error; referenceSquared += a * a;
						}
						pairedErrors.push({ repeat, variant, maxError, relativeL2: Math.sqrt(errorSquared / Math.max(referenceSquared, 1e-30)) });
						if (maxError > 1e-5) throw new Error(`${variant} differs from reference by ${maxError}`);
					}
				}
			}
			GPUCommandEncoder.prototype.beginComputePass = begin;
			GPUCommandEncoder.prototype.copyBufferToBuffer = copyBuffer;
			if (queueReadback) {
				await queueReadback.mapAsync(GPUMapMode.READ);
				const counters = new Uint32Array(queueReadback.getMappedRange());
				let tilePathCount = 0;
				for (let i = 0; i < queueCopies; i++) {
					const offset = i * queueRecordBytes / 4, phase = queuePhases[i];
					const active = counters[offset + (phase.includes('CompactIntersect') ? 2 : 0)], shadow = counters[offset + 1];
					if (phase.includes('.Initialize.')) tilePathCount = active;
					const denseBound = config.compaction === 'adaptive' && active > Math.floor(tilePathCount / 2);
					const mainGroups = counters[offset + 4], shadowGroups = counters[offset + 8];
					if (active > tilePathCount || shadow > tilePathCount || mainGroups !== Math.ceil((denseBound ? tilePathCount : active) / 64)
						|| shadowGroups !== Math.ceil(shadow / 64)) throw new Error(`Invalid queue/dispatch bounds after ${phase}`);
					queueSnapshots.push({ phase, tilePathCount, active, shadow, mainA: counters[offset], mainB: counters[offset + 2], mainGroups, shadowGroups });
				}
				queueReadback.unmap(); queueReadback.destroy();
			}
			const hdr = candidateHDR ?? await renderer.readRadiance();
			let finite = true, sum = 0, peak = 0;
			for (const v of hdr.data) { if (!Number.isFinite(v)) finite = false; sum += v; peak = Math.max(peak, v); }
			if (!finite || !(sum > 0)) throw new Error('Invalid or black HDR output');
			let referenceSummary = null;
			if (referenceHDR) {
				let referenceSum = 0, referencePeak = 0;
				for (const value of referenceHDR.data) { referenceSum += value; referencePeak = Math.max(referencePeak, value); }
				referenceSummary = { width: referenceHDR.width, height: referenceHDR.height, samples: referenceHDR.samples,
					elements: referenceHDR.data.length, mean: referenceSum / referenceHDR.data.length, peak: referencePeak };
			}
			const encodeHDR = hdr => {
				const bytes = new Uint8Array(hdr.data.buffer);
				let binary = '';
				for (let i = 0; i < bytes.length; i += 16384) binary += String.fromCharCode(...bytes.subarray(i, i + 16384));
				return btoa(binary);
			};
			const variants = config.variants.slice(1).map(variant => {
				const capture = variantHDRs.get(variant.name);
				let sum = 0, peak = 0;
				for (const value of capture.data) { sum += value; peak = Math.max(peak, value); }
				return { name: variant.name, repeats: repeats.filter(r => r.variant === variant.name),
					pairedErrors: pairedErrors.filter(r => r.variant === variant.name), base64: encodeHDR(capture),
					hdr: { width: capture.width, height: capture.height, samples: capture.samples, elements: capture.data.length, mean: sum / capture.data.length, peak } };
			});
			// Presentation-only lift makes dark interiors inspectable without changing the HDR
			// capture, path sampling, or timed work. No extra sample is traced here.
			renderer.settings.maxSamples = renderer.samples;
			renderer.settings.autoExposureBias = c.presentationExposure;
			renderer.renderFrame();
			await device.queue.onSubmittedWorkDone();
			queries.destroy(); resolved.destroy(); readback.destroy();
			globalThis.benchmarkRenderer = renderer;
			return { adapterInfo, deviceFeatures: [...device.features], initMs, integratorInitMs, loadMs, materialPrograms, materialStackRequired, materialCapacity, observedStackCapacities,
				shaderCompilations, pipelineCompilations, warmFrames: warmFrames + 1,
				presentationIntegrator: renderer.integrator, presentationVariant, presentationExposure: c.presentationExposure, scene: renderer.sceneStats, vt: renderer.virtualTextureStats,
				camera: { position: renderer.camera.position, target: renderer.camera.target, up: renderer.camera.up, fovY: renderer.camera.fovY },
				repeats: repeats.filter(r => r.variant === config.mode), referenceRepeats: repeats.filter(r => r.mode === 'megakernel'), pairedErrors: pairedErrors.filter(r => r.variant === 'wavefront'), variants,
				queueSnapshots, hdr: { width: hdr.width, height: hdr.height, samples: hdr.samples, elements: hdr.data.length, mean: sum / hdr.data.length, peak },
				base64: encodeHDR(hdr), referenceBase64: referenceHDR ? encodeHDR(referenceHDR) : null, referenceSummary };
		}, { c, config });
		const { base64, referenceBase64, referenceRepeats, referenceSummary, variants, ...stats } = result;
		writeFileSync(join(candidateOutput, `${c.name}.f32`), Buffer.from(base64, 'base64'));
		const screenshotOutput = config.paired ? join(output, stats.presentationVariant) : candidateOutput;
		await page.screenshot({ path: join(screenshotOutput, `${c.name}.png`) });
		report.results.push({ name: c.name, file: c.file, sha256: c.sha256, ...stats, errors });
		writeFileSync(join(candidateOutput, 'report.json'), JSON.stringify(report, null, 2));
		if (config.paired) {
			writeFileSync(join(referenceOutput, `${c.name}.f32`), Buffer.from(referenceBase64, 'base64'));
			referenceReport.results.push({ name: c.name, file: c.file, sha256: c.sha256, ...stats, repeats: referenceRepeats, hdr: referenceSummary, errors });
			writeFileSync(join(referenceOutput, 'report.json'), JSON.stringify(referenceReport, null, 2));
		}
		for (const variant of variants) {
			const { name, base64, ...variantStats } = variant;
			writeFileSync(join(output, name, `${c.name}.f32`), Buffer.from(base64, 'base64'));
			variantReports[name].results.push({ name: c.name, file: c.file, sha256: c.sha256, ...stats, ...variantStats, errors });
			writeFileSync(join(output, name, 'report.json'), JSON.stringify(variantReports[name], null, 2));
		}
		if (errors.length) throw new Error(errors.join('\n'));
		await page.evaluate(() => globalThis.benchmarkRenderer.destroy());
		await page.close();
	}
	assertUnchangedSources();
	report.completed = true;
} finally {
	report.finished = new Date().toISOString();
	writeFileSync(join(candidateOutput, 'report.json'), JSON.stringify(report, null, 2));
	if (config.paired) writeFileSync(join(referenceOutput, 'report.json'), JSON.stringify({ ...referenceReport, completed: report.completed, finished: report.finished }, null, 2));
	for (const [name, variantReport] of Object.entries(variantReports)) writeFileSync(join(output, name, 'report.json'), JSON.stringify({ ...variantReport, completed: report.completed, finished: report.finished }, null, 2));
	await browser.close();
	await server.close();
}
console.log(`[benchmark] saved ${output}`);
