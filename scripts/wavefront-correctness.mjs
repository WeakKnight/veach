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
const operandOption = process.argv.indexOf('--operand-mode');
const operandMode = operandOption < 0 ? 0 : Number(process.argv[operandOption + 1]);
if (![0, 1, 2, 3, 4, 5, 6, 7].includes(operandMode)) throw new Error('Invalid operand mode');
const shadeBuckets = process.argv.includes('--shade-buckets');
const bucketModeOption = process.argv.indexOf('--bucket-mode');
const shadeBucketMode = bucketModeOption < 0 ? 'scan' : process.argv[bucketModeOption + 1];
if (!['scan', 'compact'].includes(shadeBucketMode)) throw new Error('Invalid bucket mode');
if (shadeBuckets && shadeBucketMode === 'compact' && (compaction === 'none' || (directStages & 2) !== 0)) throw new Error('Compact buckets require queued shading');
const shadeOption = process.argv.indexOf('--shade-mode');
const shadeMode = shadeOption < 0 ? 'unified' : process.argv[shadeOption + 1];
if (!['unified', 'split', 'late', 'split-late'].includes(shadeMode)) throw new Error('Invalid shade mode');
if (shadeBuckets && shadeMode !== 'unified') throw new Error('Buckets require unified shading');
const opaqueMegakernel = process.argv.includes('--opaque-megakernel');
const spatialQueues = process.argv.includes('--spatial-queues');
if (spatialQueues && (compaction !== 'adaptive' || directStages === 7)) throw new Error('Spatial queues require adaptive compaction');
const packetSweep = process.argv.includes('--packet-sweep');
const shadowOption = process.argv.indexOf('--shadow');
const shadowMode = shadowOption < 0 ? 'serial' : process.argv[shadowOption + 1];
if (!['serial', 'parallel', 'parallel-auto'].includes(shadowMode)) throw new Error('Invalid shadow mode');
const sortOption = process.argv.indexOf('--sort');
const sort = sortOption < 0 ? 'none' : process.argv[sortOption + 1];
const sortSizeOption = process.argv.indexOf('--sort-size');
const sortSize = sortSizeOption < 0 ? 64 : Number(process.argv[sortSizeOption + 1]);
const raySortOption = process.argv.indexOf('--ray-sort-size');
const raySortSize = raySortOption < 0 ? 0 : Number(process.argv[raySortOption + 1]);
const sortIndirect = process.argv.includes('--sort-indirect');
if (![0, 64, 256].includes(raySortSize)) throw new Error('Invalid ray sort size');
if (raySortSize !== 0 && (compaction === 'none' || (directStages & 1) !== 0 || process.argv.includes('--dispatch-sweep'))) throw new Error('Ray sorting requires queued intersection');
if (sortIndirect && !((sort !== 'none' && sortSize === 256) || raySortSize === 256)) throw new Error('Indirect sorting requires a 256-slot sort');
if (!['none', 'material', 'program'].includes(sort) || ![64, 256].includes(sortSize)) throw new Error('Invalid shading sort');
if (sort !== 'none' && (compaction === 'none' || (directStages & 2) !== 0 || process.argv.includes('--dispatch-sweep'))) throw new Error('Sorting requires queued shading');
if (!Number.isInteger(packetStages) || packetStages < 0 || packetStages > 7) throw new Error('Invalid packet stage mask');
const dispatchSweep = process.argv.includes('--dispatch-sweep');
if (spatialQueues && dispatchSweep) throw new Error('Spatial queues require a fixed direct-stage choice');
if (!Number.isInteger(directStages) || directStages < 0 || directStages > 7) throw new Error('Invalid direct stage mask');
if (packetSweep && (compaction !== 'packet' || dispatchSweep)) throw new Error('Packet sweep requires packet compaction and cannot combine with dispatch sweep');
if (dispatchSweep && compaction === 'none') throw new Error('Dispatch sweep requires a compaction mode');
if (!['dense', 'queued', 'subgroup', 'adaptive', 'packet', 'none'].includes(compaction)) throw new Error('Invalid compaction mode');
if ((compaction === 'none' || compaction === 'packet' || directStages === 7) && tailThreshold !== 0) throw new Error('Direct/packet dispatch supports fixed tails only');
if (!Number.isInteger(tailStart) || tailStart < 0) throw new Error('Invalid tail start');
const output = join(root, `.tools/wavefront/correctness-tail-${tailStart}-${tailThreshold}${only.length ? '-selected' : ''}${disableSubgroups ? '-no-subgroups' : ''}-${compaction}${packetSweep ? '-packet-sweep' : packetStages !== 7 ? `-packet-${packetStages}` : ''}${dispatchSweep ? '-dispatch-sweep' : directStages ? `-direct-${directStages}` : ''}${sort !== 'none' ? `-sort-${sort}-${sortSize}` : ''}${raySortSize ? `-rays-${raySortSize}` : ''}${sortIndirect ? '-sort-indirect' : ''}${spatialQueues ? '-spatial' : ''}${opaqueMegakernel ? '-opaque' : ''}${shadeBuckets ? `-buckets${shadeBucketMode === 'compact' ? '-compact' : ''}` : ''}-shade-${shadeMode}-operands-${operandMode}${shadowMode !== 'serial' ? `-shadow-${shadowMode}` : ''}`);
mkdirSync(output, { recursive: true });
const chrome = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe',
	'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', '/usr/bin/google-chrome', '/usr/bin/chromium'].find(p => p && existsSync(p));
if (!chrome) throw new Error('Set CHROME_PATH');
const server = await createServer({ root, logLevel: 'warn', server: { port: 5205, strictPort: false, hmr: false } });
await server.listen();
const browser = await puppeteer.launch({ executablePath: chrome, headless: true, protocolTimeout: 1800000,
	args: ['--enable-unsafe-webgpu', '--ignore-gpu-blocklist', '--no-sandbox'] });
const errors = [];
const report = { started: new Date().toISOString(), completed: false, browser: await browser.version(), tailStart, tailThreshold, only, directStages, dispatchSweep, packetStages, packetSweep, sort, sortSize, raySortSize, sortIndirect, shadeMode, shadeBuckets, shadeBucketMode, spatialQueues, operandMode, opaqueMegakernel, shadowMode, results: [], errors };
writeFileSync(join(output, 'report.json'), JSON.stringify(report, null, 2));
try {
	const page = await browser.newPage();
	await page.setViewport({ width: 640, height: 640, deviceScaleFactor: 1 });
	page.on('pageerror', e => errors.push(String(e)));
	page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); if (msg.text().startsWith('[correctness]')) console.log(msg.text()); });
	await page.goto(server.resolvedUrls.local[0] + 'scripts/benchmark.html');
	const results = await page.evaluate(async ({ tailStart, tailThreshold, only, disableSubgroups, compaction, directStages, dispatchSweep, packetStages, packetSweep, sort, sortSize, raySortSize, sortIndirect, shadeMode, shadeBuckets, shadeBucketMode, spatialQueues, operandMode, opaqueMegakernel, shadowMode }) => {
		const api = await import('/src/index.ts');
		const check = (value, message) => { if (!value) throw new Error(message); };
		const createBuffer = GPUDevice.prototype.createBuffer;
		GPUDevice.prototype.createBuffer = function(descriptor) {
			// Diagnostic readback only; production indirect/material buffers need no COPY_SRC usage.
			return createBuffer.call(this, ['wavefrontDispatch', 'materialData', 'optimizedMaterialSchedule'].includes(descriptor.label)
				? { ...descriptor, usage: descriptor.usage | GPUBufferUsage.COPY_SRC } : descriptor);
		};
		const pipelineOpcodes = new WeakMap(), createPipeline = GPUDevice.prototype.createComputePipelineAsync;
		const sceneMaterials = new WeakMap(), createBindGroup = GPUDevice.prototype.createBindGroup;
		GPUDevice.prototype.createBindGroup = function(descriptor) {
			const group = createBindGroup.call(this, descriptor);
			if (descriptor.label === 'scene') sceneMaterials.set(group, descriptor.entries.find(e => e.binding === 6).resource.buffer);
			return group;
		};
		GPUDevice.prototype.createComputePipelineAsync = function(descriptor) {
			return createPipeline.call(this, descriptor).then(pipeline => {
				pipelineOpcodes.set(pipeline, descriptor.compute.constants ?? {});
				return pipeline;
			});
		};
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
		let sortMaterialOf = [], sortPrograms = new Uint32Array();
		let materialHeaderCount = 0;
		let bucketVerification = { passes: 0, entries: 0, emptyBuckets: 0, dispatches: 0 };
		let sortVerification = { passes: 0, entries: 0, reordered: 0, directionPasses: 0, indirect256Passes: 0 };
		let shadePipelines = [], shadowPipelines = [], compactPipelines = [], megakernelPipelines = [];
		let opcodeConstants = [];
		let materialVariants = null;
		const releaseUnusedMaterials = () => {
			if (materialVariants) for (const variant of Object.values(materialVariants)) if (variant.buffer !== r.scene.materials) variant.buffer.destroy();
			materialVariants = null;
		};
		async function renderSortCheckedFrame() {
			const captures = [];
			const begin = GPUCommandEncoder.prototype.beginComputePass;
			GPUCommandEncoder.prototype.beginComputePass = function(descriptor = {}) {
				if (!descriptor.label?.startsWith('wavefront.Sort')) return begin.call(this, descriptor);
				const direction = descriptor.label.startsWith('wavefront.SortDirection');
				const size = direction ? raySortSize : sortSize;
				const wantsIndirect = size === 64 || sortIndirect;
				const argumentOffset = size === 64 ? 0 : 32;
				const pixels = r.tracer.width * r.tracer.height;
				const cap = r.tracer.wavefront.capacity(pixels), header = pixels * 48;
				const queue = header + 48 + cap * 336 + (direction ? 0 : Math.ceil(cap / 4) * 16);
				const buffer = r.device.createBuffer({ size: 64 + cap * 40, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
				this.copyBufferToBuffer(r.tracer.accumulation, header, buffer, 0, 48);
				this.copyBufferToBuffer(r.tracer.accumulation, header + 48, buffer, 48, cap * 16);
				this.copyBufferToBuffer(r.tracer.accumulation, header + 48 + cap * (direction ? 48 : 128), buffer, 48 + cap * 16, cap * 16);
				this.copyBufferToBuffer(r.tracer.accumulation, queue, buffer, 48 + cap * 32, cap * 4);
				if (wantsIndirect) this.copyBufferToBuffer(r.tracer.wavefront.indirect, argumentOffset, buffer, 48 + cap * 40, 12);
				const pass = begin.call(this, descriptor), end = pass.end.bind(pass), encoder = this;
				const capture = { buffer, cap, label: descriptor.label, direction, size, wantsIndirect, argumentOffset, dispatch: null };
				const directDispatch = pass.dispatchWorkgroups.bind(pass), indirectDispatch = pass.dispatchWorkgroupsIndirect.bind(pass);
				pass.dispatchWorkgroups = (x, y = 1, z = 1) => {
					capture.dispatch = { indirect: false, x, y, z };
					directDispatch(x, y, z);
				};
				pass.dispatchWorkgroupsIndirect = (argumentsBuffer, offset) => {
					check(argumentsBuffer === r.tracer.wavefront.indirect, 'Wrong indirect argument buffer');
					capture.dispatch = { indirect: true, offset };
					indirectDispatch(argumentsBuffer, offset);
				};
				pass.end = () => {
					end();
					encoder.copyBufferToBuffer(r.tracer.accumulation, queue, buffer, 48 + cap * 36, cap * 4);
				};
				captures.push(capture);
				return pass;
			};
			try { r.renderFrame(); }
			finally { GPUCommandEncoder.prototype.beginComputePass = begin; }
			try {
				for (const { buffer, cap, label, direction, size, wantsIndirect, argumentOffset, dispatch } of captures) {
					await buffer.mapAsync(GPUMapMode.READ);
					const words = new Uint32Array(buffer.getMappedRange());
					const count = words[direction ? 0 : 2];
					check(count <= cap, `${label}: oversized queue`);
					check(dispatch?.indirect === wantsIndirect, `${label}: wrong sort dispatch mode`);
					if (wantsIndirect) {
						check(dispatch.offset === argumentOffset, `${label}: wrong indirect offset`);
						const argumentsWords = words.subarray(12 + cap * 10, 15 + cap * 10);
						const groups = size === 64 ? words[4] : Math.ceil(count / 256);
						check(argumentsWords[0] === groups && argumentsWords[1] === 1 && argumentsWords[2] === 1, `${label}: wrong GPU dispatch arguments`);
						if (size === 256) check(words[3] === groups, `${label}: wrong 256-slot header bound`);
					} else check(dispatch.x >= Math.ceil(count / size) && dispatch.x <= Math.ceil(cap / size) && dispatch.y === 1 && dispatch.z === 1, `${label}: invalid direct bound`);
					const before = words.subarray(12 + cap * 8, 12 + cap * 8 + count);
					const after = words.subarray(12 + cap * 9, 12 + cap * 9 + count);
					check(new Set(before).size === count && before.every(i => i < cap), `${label}: invalid input permutation`);
					const key = index => {
						if (words[12 + index * 4 + 3] === 0) return 0xffffffff;
						if (direction) {
							const offset = 12 + cap * 4 + index * 4;
							return (words[offset] >>> 31) | ((words[offset + 1] >>> 31) << 1) | ((words[offset + 2] >>> 31) << 2);
						}
						const instance = words[12 + cap * 4 + index * 4 + 3];
						check(instance < sortMaterialOf.length, `${label}: invalid hit instance`);
						const material = sortMaterialOf[instance];
						return sort === 'material' ? material : sortPrograms[material * 8];
					};
					for (let offset = 0; offset < count; offset += size) {
						const expected = [...before.subarray(offset, Math.min(count, offset + size))].sort((a, b) => key(a) - key(b) || a - b);
						for (let i = 0; i < expected.length; i++) {
							check(after[offset + i] === expected[i], `${label}: incorrect sorted permutation at ${offset + i}`);
							sortVerification.reordered += Number(before[offset + i] !== after[offset + i]);
						}
					}
					sortVerification.passes++; sortVerification.entries += count;
					sortVerification.directionPasses += Number(direction);
					sortVerification.indirect256Passes += Number(size === 256 && wantsIndirect);
					buffer.unmap();
				}
			} finally { for (const { buffer } of captures) buffer.destroy(); }
		}
		async function renderBucketCheckedFrame() {
			const captures = [], capacities = [0, 1, 2, 4, 8, 16];
			const begin = GPUCommandEncoder.prototype.beginComputePass;
			let current = null;
			GPUCommandEncoder.prototype.beginComputePass = function(descriptor = {}) {
				const label = descriptor.label ?? '';
				const partition = /^wavefront\.(CountBuckets|PrefixBuckets|ScatterBuckets)\.b/.exec(label);
				const shade = /^wavefront\.ShadeBucketCompact(\d+)\.b/.exec(label);
				if (!partition && !shade) return begin.call(this, descriptor);
				if (partition?.[1] === 'CountBuckets') {
					const pixels = r.tracer.width * r.tracer.height, cap = r.tracer.wavefront.capacity(pixels), header = pixels * 48;
					const queueA = header + 48 + cap * 336, stride = Math.ceil(cap / 4) * 16;
					const buffer = r.device.createBuffer({ size: 352 + cap * 40 + materialHeaderCount * 32,
						usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
					current = { buffer, cap, header, queueA, stride, ops: [], copiedArguments: false };
					captures.push(current);
					this.copyBufferToBuffer(r.tracer.accumulation, header, buffer, 0, 48);
					this.copyBufferToBuffer(r.tracer.accumulation, header + 48, buffer, 48, cap * 16);
					this.copyBufferToBuffer(r.tracer.accumulation, header + 48 + cap * 128, buffer, 48 + cap * 16, cap * 16);
					this.copyBufferToBuffer(r.tracer.accumulation, queueA + stride, buffer, 48 + cap * 32, cap * 4);
					this.copyBufferToBuffer(r.tracer.wavefront.indirect, 0, buffer, 336 + cap * 40, 16);
					this.copyBufferToBuffer(sceneMaterials.get(r.tracer.sceneBindGroup), 0, buffer, 352 + cap * 40, materialHeaderCount * 32);
				}
				check(current !== null, 'Bucket stage without CountBuckets');
				const capture = current, { buffer, cap, queueA, stride } = capture;
				if (shade && !capture.copiedArguments) {
					this.copyBufferToBuffer(r.tracer.wavefront.indirect, 48, buffer, 240 + cap * 40, 96);
					capture.copiedArguments = true;
				}
				const pass = begin.call(this, descriptor), end = pass.end.bind(pass), encoder = this;
				const direct = pass.dispatchWorkgroups.bind(pass), indirect = pass.dispatchWorkgroupsIndirect.bind(pass);
				const stage = partition?.[1] ?? 'Shade', capacity = shade ? Number(shade[1]) : null;
				pass.dispatchWorkgroups = (x, y = 1, z = 1) => {
					capture.ops.push({ stage, capacity, x, y, z }); direct(x, y, z);
				};
				pass.dispatchWorkgroupsIndirect = (args, offset) => {
					check(args === r.tracer.wavefront.indirect, 'Wrong bucket indirect buffer');
					capture.ops.push({ stage, capacity, offset }); indirect(args, offset);
				};
				if (stage === 'ScatterBuckets') pass.end = () => {
					end();
					encoder.copyBufferToBuffer(r.tracer.accumulation, queueA + 2 * stride, buffer, 48 + cap * 36, cap * 4);
					encoder.copyBufferToBuffer(r.tracer.accumulation, queueA + 3 * stride, buffer, 48 + cap * 40, 192);
				};
				return pass;
			};
			try {
				if (sort !== 'none' || raySortSize !== 0) await renderSortCheckedFrame();
				else { r.renderFrame(); await r.device.queue.onSubmittedWorkDone(); }
			} finally { GPUCommandEncoder.prototype.beginComputePass = begin; }
			try {
				for (const { buffer, cap, ops, copiedArguments } of captures) {
					await buffer.mapAsync(GPUMapMode.READ);
					const data = buffer.getMappedRange(), header = new Uint32Array(data, 0, 12), count = header[2];
					const active = new Uint32Array(data, 48, cap * 4), hit = new Uint32Array(data, 48 + cap * 16, cap * 4);
					const input = new Uint32Array(data, 48 + cap * 32, cap), output = new Uint32Array(data, 48 + cap * 36, cap);
					const metadata = new Uint32Array(data, 48 + cap * 40, 48), args = new Uint32Array(data, 240 + cap * 40, 24);
					const mainArgs = new Uint32Array(data, 336 + cap * 40, 4), materials = new Uint32Array(data, 352 + cap * 40, materialHeaderCount * 8);
					check(count <= cap && mainArgs[0] * 64 >= count && mainArgs[1] === 1 && mainArgs[2] === 1, `Invalid partition input dispatch: count=${count}, capacity=${cap}, args=${[...mainArgs]}`);
					const expected = new Map(), seen = new Set();
					const capacityOf = path => {
						const material = sortMaterialOf[hit[path * 4 + 3]];
						check(Number.isInteger(material) && material >= 0 && material < materialHeaderCount, 'Invalid bucket hit material');
						return (materials[material * 8 + 3] >>> 16) & 31;
					};
					for (let i = 0; i < count; i++) {
						const path = input[i]; check(path < cap, 'Invalid input path');
						if (active[path * 4 + 3] === 0) continue;
						check(!expected.has(path), 'Duplicate input path'); expected.set(path, i);
					}
					let total = 0;
					for (let bucket = 0; bucket < 6; bucket++) {
						const size = metadata[bucket * 4], offset = metadata[bucket * 4 + 1], cursor = metadata[bucket * 4 + 2];
						check(offset === total && cursor === size && total + size <= cap, 'Invalid bucket count/prefix/scatter cursor');
						const wanted = [Math.ceil(size / 64), 1, 1, 0];
						check(wanted.every((value, i) => metadata[24 + bucket * 4 + i] === value && args[bucket * 4 + i] === value), 'Invalid bucket indirect arguments');
						const groupLast = new Map();
						for (let i = offset; i < offset + size; i++) {
							const path = output[i];
							check(expected.has(path) && !seen.has(path) && capacityOf(path) === capacities[bucket], 'Wrong bucket membership or duplicate path');
							seen.add(path);
							const position = expected.get(path), group = Math.floor(position / 64);
							check(position > (groupLast.get(group) ?? -1), 'Bucket scatter lost local ordering');
							groupLast.set(group, position);
						}
						total += size; bucketVerification.emptyBuckets += Number(size === 0);
					}
					check(total === expected.size && seen.size === expected.size && copiedArguments, 'Bucket partition omitted paths or argument copy');
					check(ops.length === 3 + r.scene.materialShadeCapacities.length && ops[0].stage === 'CountBuckets' && ops[0].offset === 0
						&& ops[1].stage === 'PrefixBuckets' && ops[1].x === 1 && ops[1].y === 1 && ops[1].z === 1
						&& ops[2].stage === 'ScatterBuckets' && ops[2].offset === 0, 'Wrong partition dispatch sequence');
					ops.slice(3).forEach((op, i) => check(op.stage === 'Shade' && op.capacity === r.scene.materialShadeCapacities[i]
						&& op.offset === 48 + capacities.indexOf(op.capacity) * 16, 'Wrong compact shading indirect offset'));
					bucketVerification.passes++; bucketVerification.entries += total; bucketVerification.dispatches += ops.length - 3;
					buffer.unmap();
				}
			} finally { for (const { buffer } of captures) buffer.destroy(); }
		}
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
			const material = materialVariants[capacity === null ? 'optimized' : 'original'];
			Object.assign(r.scene, { materials: material.buffer, materialStackSize: material.stack, materialShadeCapacities: material.shadeCapacities, materialOpcodes: material.opcodes });
			r.tracer.materialStackOverride = capacity;
			r.tracer.materialOpcodeSpecialization = capacity === null;
			r.tracer.materialOperandMode = capacity === null ? operandMode : 0;
			r.tracer.opaqueMegakernel = capacity === null && opaqueMegakernel;
			await r.tracer.prepareScene(r.scene);
			r.bindScene();
			check(sceneMaterials.get(r.tracer.sceneBindGroup) === material.buffer, 'Wrong bound material bytecode schedule');
			const expectedCapacity = capacity ?? [0, 1, 2, 4, 8, 16].find(n => n >= r.scene.materialStackSize);
			check(r.tracer.materialCapacity === expectedCapacity, 'Incorrect material capacity selection');
			await r.setIntegrator(mode);
			if (mode === 'wavefront' && r.tracer.wavefront) await r.tracer.wavefront.prepareShadeMode(shadeMode, r.tracer.materialCapacity, r.tracer.materialOpcodes, r.tracer.boundMaterialOperandMode);
			if (mode === 'wavefront' && r.tracer.wavefront && shadeBuckets) await r.tracer.wavefront.prepareBuckets(r.scene.materialShadeCapacities, r.tracer.materialCapacity, r.tracer.materialOpcodes, r.tracer.boundMaterialOperandMode, shadeBucketMode);
			if (mode === 'wavefront' && r.tracer.wavefront) Object.assign(r.tracer.wavefront, { tailStart, tailThreshold, compaction, directStages: stageMask, packetStages: packetMask, sort, sortSize, raySortSize, sortIndirect, shadeMode, shadeBuckets, shadeBucketMode, spatialQueues, shadowMode });
			Object.assign(r.settings, { maxBounces: config.bounces, fireflyClamp: config.clamp ?? 0, maxSamples: config.samples });
			r.resetAccumulation();
			sortVerification = { passes: 0, entries: 0, reordered: 0, directionPasses: 0, indirect256Passes: 0 };
			bucketVerification = { passes: 0, entries: 0, emptyBuckets: 0, dispatches: 0 };
			const observedShading = new Set(), observedMegakernel = new Set(), observedShadows = new Set(), observedCompaction = new Set(), observedOpcodes = new Set(), setPipeline = GPUComputePassEncoder.prototype.setPipeline;
			const beginShadePass = GPUCommandEncoder.prototype.beginComputePass, shadePasses = new WeakMap();
			GPUCommandEncoder.prototype.beginComputePass = function(descriptor = {}) {
				const pass = beginShadePass.call(this, descriptor);
				const match = /^wavefront\.Shade(?:Bucket(?:Compact)?\d+)?\.b(\d+)/.exec(descriptor.label ?? '');
				if (match) shadePasses.set(pass, Number(match[1]));
				return pass;
			};
			GPUComputePassEncoder.prototype.setPipeline = function(pipeline) {
				const bounce = shadePasses.get(this);
				if (bounce !== undefined) {
					const bucket = /^wavefront\.ShadeBucket(?:Direct|Compact)?\.stack(\d+)$/.exec(pipeline.label);
					const actualCapacity = bucket ? Number(bucket[1]) : expectedCapacity;
					check(!bucket || (shadeBuckets && r.scene.materialShadeCapacities.includes(actualCapacity)), 'Unexpected shading bucket');
					const expected = `Shade${bucket ? `Bucket${shadeBucketMode === 'compact' ? 'Compact' : ''}` : ''}${shadeMode.startsWith('split') ? (bounce === 0 ? 'Primary' : 'Secondary') : ''}${shadeMode.endsWith('late') ? 'Late' : ''}${compaction === 'none' || (stageMask & 2) !== 0 ? 'Direct' : ''}`;
					check(pipeline.label === `wavefront.${expected}.stack${actualCapacity}`, 'Wrong bound shading phase');
					observedShading.add(pipeline.label);
				}
				if (pipeline.label.startsWith('pathTracing.')) {
					const opaque = capacity === null && opaqueMegakernel && r.scene.instanceCount > 0 && !r.scene.hasAlphaTested;
					const expected = r.scene.instanceCount === 0 && capacity === null ? 'pathTracing.empty' : `pathTracing.${opaque ? 'opaque.' : ''}stack${expectedCapacity}`;
					check(pipeline.label === expected, 'Wrong megakernel traversal pipeline');
					observedMegakernel.add(pipeline.label);
				}
				if (pipeline.label.startsWith('wavefront.CompactShade')) observedCompaction.add(pipeline.label);
				if (pipeline.label.startsWith('wavefront.Shadow')) observedShadows.add(pipeline.label);
				const constants = pipelineOpcodes.get(pipeline) ?? {};
				if ('0' in constants) {
					check(constants['0'] === r.tracer.materialOpcodes[0] && constants['1'] === r.tracer.materialOpcodes[1], 'Wrong bound opcode specialization');
					check(constants['2'] === (capacity === null ? operandMode : 0), 'Wrong bound operand mode');
					observedOpcodes.add(JSON.stringify(constants));
				}
				return setPipeline.call(this, pipeline);
			};
			try {
				while (r.samples < config.samples) {
					if (r.samples === 0 && mode === 'wavefront' && shadeBuckets && shadeBucketMode === 'compact') await renderBucketCheckedFrame();
					else if (r.samples === 0 && mode === 'wavefront' && (sort !== 'none' || raySortSize !== 0)) await renderSortCheckedFrame();
					else r.renderFrame();
					await r.device.queue.onSubmittedWorkDone();
				}
			} finally { GPUComputePassEncoder.prototype.setPipeline = setPipeline; GPUCommandEncoder.prototype.beginComputePass = beginShadePass; }
			shadePipelines = [...observedShading];
			if (mode === 'wavefront' && r.scene.instanceCount > 0 && (tailStart > 0 || tailThreshold > 0)) {
				const caps = r.scene.materialShadeCapacities;
				const expected = shadeBuckets && !(caps.length === 1 && caps[0] === expectedCapacity) ? caps : [];
				const actual = shadePipelines.filter(x => x.startsWith('wavefront.ShadeBucket')).map(x => Number(x.split('.stack')[1])).sort((a,b) => a-b);
				check(JSON.stringify(actual) === JSON.stringify(expected), 'Missing or duplicate shading bucket');
				if (shadeBucketMode === 'compact') check((bucketVerification.passes > 0) === (expected.length > 0), 'Compact bucket diagnostics were not exercised');
			}
			if (mode === 'wavefront' && r.scene.instanceCount > 0 && (tailStart > 0 || tailThreshold > 0)) check(shadePipelines.length > 0, 'Shading kernels were not exercised');
			megakernelPipelines = [...observedMegakernel];
			if (mode === 'megakernel') check(megakernelPipelines.length === 1, 'Megakernel pipeline was not exercised');
			shadowPipelines = [...observedShadows];
			compactPipelines = [...observedCompaction];
			if (mode === 'wavefront' && config.bounces > 0 && (tailStart > 1 || tailThreshold > 0) && r.scene.instanceCount > 0)
				check((sortVerification.directionPasses > 0) === (raySortSize !== 0), 'Wrong direction sorting execution');
			if (mode === 'wavefront' && config.bounces > 0 && tailStart > 0 && r.scene.instanceCount > 0)
				check(compactPipelines.some(label => label.includes('.CompactShadeSpatial.')) === spatialQueues, 'Wrong spatial queue pipeline');
			opcodeConstants = [...observedOpcodes].map(value => JSON.parse(value));
			if (r.scene.instanceCount > 0 && r.tracer.materialCapacity > 0) check(opcodeConstants.length === 1, 'SVM opcode constants were not exercised');
			const expectedShadow = r.scene.hasAlphaTested ? 'Shadow' : shadowMode === 'serial' ? 'ShadowOpaque'
				: shadowMode === 'parallel-auto' && r.scene.lightCount === 0 ? 'ShadowOpaqueParallelSky' : 'ShadowOpaqueParallel';
			const suffix = compaction === 'none' || (stageMask & 4) !== 0 ? 'Direct' : '';
			check(shadowPipelines.every(label => label === `wavefront.${expectedShadow}${suffix}.stack${r.tracer.materialCapacity}`), 'Wrong shadow pipeline');
			if (mode === 'wavefront' && config.bounces > 0 && tailStart > 0 && r.scene.instanceCount > 0) check(shadowPipelines.length > 0, 'Shadow stage was not exercised');
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
			{ name: 'opaque-shadows', file: 'MetalRoughSpheres.glb', configurations: [
				{ width: 7, height: 5, bounces: 8, samples: 8 },
				{ width: 129, height: 97, bounces: 8, samples: 16, clamp: 2 },
			] },
			{ name: 'procedural', file: 'MetalRoughSpheres.glb', procedural: true, configurations: [
				{ width: 7, height: 5, bounces: 8, samples: 8 },
				{ width: 129, height: 97, bounces: 8, samples: 16, clamp: 2 },
			] },
			{ name: 'material-stress', file: 'MetalRoughSpheres.glb', stressLayers: 8, configurations: [
				{ width: 7, height: 5, bounces: 8, samples: 8 },
				{ width: 129, height: 97, bounces: 8, samples: 16, clamp: 2 },
			] },
			{ name: 'bucket-mixed', file: 'MetalRoughSpheres.glb', bucketMixed: true, configurations: [
				{ width: 129, height: 97, bounces: 8, samples: 16, clamp: 2 },
				{ width: 513, height: 513, bounces: 2, samples: 2 },
			] },
			{ name: 'bucket-emission', file: 'EmissiveStrengthTest.glb', bucketEmission: true, configurations: [
				{ width: 129, height: 97, bounces: 8, samples: 16, clamp: 2 },
				{ width: 513, height: 513, bounces: 2, samples: 2 },
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
				releaseUnusedMaterials();
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
				if (scene.procedural) {
					const { GraphBuilder } = await import('/src/material/Graph.ts');
					const { AlphaMode } = await import('/src/scene/Scene.ts');
					desc.materials.forEach((material, i) => {
						const b = new GraphBuilder();
						const p = b.node('position', 'vector3', {});
						const object = b.node('veach_world_to_object', 'vector3', { in: p });
						const noise = b.math('veach_blender_noise', 'color3', { in: object, params: [3, 0.625, 2.25, 0.375], normalize: 1 });
						const magic = b.math('veach_blender_magic', 'color4', { in: object, distortion: 1 + i % 3, depth: 3 });
						const checker = b.math('veach_blender_checker', 'float', { in: b.mul(object, 3) });
						material.graph = { name: `procedural-${i}`, nodes: b.nodes,
							surface: b.node('open_pbr_surface', 'surfaceshader', {
								base_color: b.saturate(noise), specular_roughness: b.add(0.1, b.mul(checker, 0.7)),
								fuzz_weight: 0.3, fuzz_color: b.saturate(b.convert(magic, 'color3')),
							}).node, alphaMode: AlphaMode.Opaque, alphaCutoff: 0.5, doubleSided: false };
					});
				}
				if (scene.stressLayers) {
					const { applyMaterialStress } = await import('/scripts/wavefront-material-stress.ts');
					applyMaterialStress(desc, scene.stressLayers);
				}
				if (scene.bucketMixed) {
					const { stressMaterial } = await import('/scripts/wavefront-material-stress.ts');
					const { defaultMaterialGraph } = await import('/src/material/GLTFMaterial.ts');
					// This asset shares one material across five meshes. Give the meshes
					// explicit capacity classes so the fixture actually executes several buckets.
					desc.materials = Array.from({ length: 4 }, () => ({ ...desc.materials[0] }));
					desc.materials.forEach((material, i) => {
						const layers = [0, 1, 3, 8][i % 4];
						material.graph = layers ? stressMaterial(defaultMaterialGraph(), layers) : defaultMaterialGraph();
					});
					desc.meshes.forEach((mesh, i) => { mesh.material = i % 4; });
				}
				if (scene.bucketEmission) {
					const { GraphBuilder } = await import('/src/material/Graph.ts');
					const { AlphaMode } = await import('/src/scene/Scene.ts');
					const { stressMaterial } = await import('/scripts/wavefront-material-stress.ts');
					desc.materials.forEach((material, i) => {
						const b = new GraphBuilder(), uv = b.node('texcoord', 'vector2', { index: 0 });
						const emission = i % 3 === 0 ? b.mul(10, b.add(1, b.mul(b.extract(uv, 0), b.extract(uv, 1)))) : 0;
						const surface = b.node('open_pbr_surface', 'surfaceshader', { base_color: [0.7, 0.5, 0.3], specular_roughness: 0.4, emission_luminance: emission });
						material.graph = { name: `bucket-light-${i}`, nodes: b.nodes, surface: surface.node, alphaMode: AlphaMode.Opaque, alphaCutoff: 0.5, doubleSided: true };
						if (i === 0) material.graph = stressMaterial(material.graph, 8);
					});
				}
				await r.setScene(desc);
				const { materialScheduleVariants } = await import('/scripts/wavefront-material-variants.ts');
				materialVariants = materialScheduleVariants(r.device, desc, r.vt.descriptorOf, r.scene.materials);
				if (scene.bucketMixed) check(materialVariants.optimized.shadeCapacities.includes(0) && materialVariants.optimized.shadeCapacities.length >= 2, `Mixed bucket fixture lost constant or complex materials: ${materialVariants.optimized.shadeCapacities}`);
				if (scene.bucketEmission) {
					const { compileSceneMaterials } = await import('/src/render/SceneMaterials.ts');
					const compiled = compileSceneMaterials(desc, { schedule: true });
					const floor = Math.max(...compiled.map(m => m.programStackSizes.emission));
					check(floor > 0 && compiled.some(m => m.programStackSizes.surface === 0) && r.scene.lightCount > 0, 'Emission-floor fixture was not exercised');
					check(materialVariants.optimized.shadeCapacities.length >= 2 && materialVariants.optimized.shadeCapacities.every(c => c >= floor), 'Invalid cross-material emission floor');
				}
				if (scene.stressLayers) check(materialVariants.original.stack >= scene.stressLayers && r.scene.materialOpcodes[1] === 1,
					'Material stress regression did not exercise the large procedural stack');
				if (scene.procedural) check((r.scene.materialOpcodes[1] & 7) === 7 && (r.scene.materialOpcodes[0] >>> 31) === 1,
					'Procedural regression did not compile Transform/Noise/Magic/Checker');
				materialHeaderCount = desc.materials.length + 1;
				if (sort !== 'none' || (shadeBuckets && shadeBucketMode === 'compact')) {
					const { compileSceneMaterials } = await import('/src/render/SceneMaterials.ts');
					const { packMaterialData } = await import('/src/render/GpuLayout.ts');
					const compiled = compileSceneMaterials(desc, { schedule: true });
					// Texture descriptor contents do not affect packed program offsets.
					sortPrograms = packMaterialData(compiled, () => null);
					sortMaterialOf = desc.instances.map(instance => {
						const material = desc.meshes[instance.mesh].material;
						return material >= 0 && material < desc.materials.length ? material : compiled.length - 1;
					});
				}
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
					const masks = dispatchSweep ? Array.from({ length: tailThreshold === 0 ? 8 : 7 }, (_, i) => i)
						.filter(mask => !(shadeBuckets && shadeBucketMode === 'compact') || (mask & 2) === 0) : [directStages];
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
						const result = { scene: scene.name, mode, compaction, directStages: stageMask, packetStages: packetMask, sort, sortSize, raySortSize, sortIndirect, shadeMode, shadeBuckets, shadeBucketMode, spatialQueues, operandMode, opaqueMegakernel, shadowMode, shadePipelines, shadowPipelines, compactPipelines, megakernelPipelines, sortVerification, bucketVerification, opcodeConstants, materialSchedules: { original: materialVariants.original.stack, optimized: materialVariants.optimized.stack }, subgroups: r.device.features.has('subgroups'), materialCapacity: r.tracer.materialCapacity, materialShadeCapacities: r.scene.materialShadeCapacities, ...config, maxError, relativeL2 };
						results.push(result);
						console.log(`[correctness] ${JSON.stringify(result)}`);
						check(maxError <= 1e-5, `${scene.name}: GPU integrators differ by ${maxError}`);
					}
					// Switch back on the same renderer and make sure reallocation/reset is complete.
					await r.setIntegrator('megakernel');
					check(r.samples === 0, 'Integrator switch failed to reset samples');
				}
			}
		} finally { releaseUnusedMaterials(); r.destroy(); GPUDevice.prototype.createComputePipelineAsync = createPipeline; GPUDevice.prototype.createBindGroup = createBindGroup; GPUDevice.prototype.createBuffer = createBuffer; }
		return results;
	}, { tailStart, tailThreshold, only, disableSubgroups, compaction, directStages, dispatchSweep, packetStages, packetSweep, sort, sortSize, raySortSize, sortIndirect, shadeMode, shadeBuckets, shadeBucketMode, spatialQueues, operandMode, opaqueMegakernel, shadowMode });
	if (errors.length) throw new Error(errors.join('\n'));
	Object.assign(report, { completed: true, results, finished: new Date().toISOString() });
	writeFileSync(join(output, 'report.json'), JSON.stringify(report, null, 2));
	console.log(`[correctness] ${results.length} GPU regression cases passed`);
} catch (error) {
	writeFileSync(join(output, 'report.json'), JSON.stringify({ ...report, completed: false, failure: String(error), finished: new Date().toISOString() }, null, 2));
	throw error;
} finally { await browser.close(); await server.close(); }
