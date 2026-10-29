// Reproducible GPU timings and linear HDR captures for the wavefront experiment.
// Uses the production renderer, a fixed camera, and timestamp queries on tracing passes only.
import { createReadStream, existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';
import { createServer } from 'vite';
import { balancedMeasurementOrder } from './benchmark-order.mjs';

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
	directStages: Number(option('direct-stages', 0)),
	dispatchSweep: args.includes('--dispatch-sweep'),
	packetStages: Number(option('packet-stages', 7)),
	packetSweep: args.includes('--packet-sweep'),
	materialSweep: args.includes('--material-sweep'),
	materialCapacities: option('material-capacities', '1,16').split(',').map(Number),
	sort: option('sort', 'none'),
	sortSize: Number(option('sort-size', 64)),
	sortSweep: args.includes('--sort-sweep'),
	raySortSize: Number(option('ray-sort-size', 0)),
	raySortSweep: args.includes('--ray-sort-sweep'),
	sortIndirect: args.includes('--sort-indirect'),
	sortIndirectSweep: args.includes('--sort-indirect-sweep'),
	spatialQueues: args.includes('--spatial-queues'),
	spatialSweep: args.includes('--spatial-sweep'),
	shadowMode: option('shadow', 'serial'),
	shadowSweep: args.includes('--shadow-sweep'),
	operandMode: Number(option('operand-mode', 0)),
	operandSweep: args.includes('--operand-sweep'),
	operandModes: option('operand-modes', '1,2,3').split(',').map(Number),
	balancedOrder: args.includes('--balanced-order'),
	opcodeMode: option('opcodes', 'full'),
	opaqueMegakernel: args.includes('--opaque-megakernel'),
	opaqueSweep: args.includes('--opaque-sweep'),
	shadeMode: option('shade-mode', 'unified'),
	separateLight: args.includes('--separate-light'),
	batchedShadows: args.includes('--batched-shadows'),
	cyclesSweep: args.includes('--cycles-sweep'),
	shadeSweep: args.includes('--shade-sweep'),
	shadeBuckets: args.includes('--shade-buckets'),
	shadeBucketMode: option('bucket-mode', 'scan'),
	partitionSweep: args.includes('--partition-sweep'),
	bucketSweep: args.includes('--bucket-sweep'),
	opcodeSweep: args.includes('--opcode-sweep'),
	materialLayers: Number(option('material-layers', 0)),
	materialMixed: args.includes('--material-mixed'),
	materialSchedule: option('material-schedule', 'original'),
	scheduleSweep: args.includes('--schedule-sweep'),
	variantWarmup: Number(option('variant-warmup', args.includes('--material-sweep') || args.includes('--opcode-sweep') || args.includes('--schedule-sweep') || args.includes('--spatial-sweep') || args.includes('--operand-sweep') || args.includes('--ray-sort-sweep') || args.includes('--sort-indirect-sweep') || args.includes('--opaque-sweep') || args.includes('--shade-sweep') || args.includes('--bucket-sweep') || args.includes('--partition-sweep') ? 64 : 8)),
};
if (Object.entries(config).filter(([key, value]) => key.endsWith('Sweep') && value).length > 1) throw new Error('Choose one sweep at a time');
if (!['unified', 'split', 'late', 'split-late'].includes(config.shadeMode)) throw new Error('Invalid shade mode');
if ((config.shadeBuckets || config.bucketSweep || config.partitionSweep) && config.shadeMode !== 'unified') throw new Error('Buckets require unified shading');
if (!['scan', 'compact', 'material'].includes(config.shadeBucketMode)) throw new Error('Invalid bucket mode');
if (config.partitionSweep && (!config.paired || config.shadeBuckets)) throw new Error('Partition sweep requires paired unbucketed base');
if ((config.partitionSweep || ((config.shadeBuckets || config.bucketSweep) && config.shadeBucketMode !== 'scan')) && (config.compaction === 'none' || (config.directStages & 2) !== 0)) throw new Error('Compact buckets require queued shading');
if (config.bucketSweep && (!config.paired || config.shadeBuckets)) throw new Error('Bucket sweep requires paired unbucketed base');
if (config.shadeSweep && (!config.paired || config.shadeMode !== 'unified')) throw new Error('Shade sweep requires paired unified base');
if (config.opaqueSweep && (!config.paired || config.opaqueMegakernel)) throw new Error('Opaque sweep requires paired general traversal');
if (config.opaqueMegakernel && config.paired) throw new Error('Use --opaque-sweep to retain a general paired reference');
if (![0, 64, 256].includes(config.raySortSize)) throw new Error('Invalid ray sort size');
if ((config.raySortSize !== 0 || config.raySortSweep) && (config.compaction === 'none' || (config.directStages & 1) !== 0 || config.dispatchSweep || config.compactionSweep)) throw new Error('Ray sorting requires fixed queued intersection');
if (config.sortIndirect && !((config.sort !== 'none' && config.sortSize === 256) || config.raySortSize === 256)) throw new Error('Indirect sorting requires a 256-slot sort');
if (config.raySortSweep && (!config.paired || config.raySortSize !== 0 || config.sortIndirect)) throw new Error('Ray sort sweep requires paired unsorted rays and direct sort dispatch');
if (config.sortIndirectSweep && (!config.paired || config.sortIndirect || !((config.sort !== 'none' && config.sortSize === 256) || config.raySortSize === 256))) throw new Error('Indirect sort sweep requires a paired 256-slot sort with direct dispatch');
if (![0, 1, 2, 3, 4, 5, 6, 7].includes(config.operandMode)) throw new Error('Invalid operand mode');
if (!config.operandModes.length || config.operandModes.some(mode => !Number.isInteger(mode) || mode < 1 || mode > 7) || new Set(config.operandModes).size !== config.operandModes.length) throw new Error('Invalid operand sweep modes');
if (config.operandSweep && (!config.paired || config.operandMode !== 0 || config.tailSweep || config.packetSweep || config.materialSweep || config.sortSweep || config.shadowSweep || config.opcodeSweep || config.scheduleSweep || config.spatialSweep || config.dispatchSweep || config.compactionSweep)) throw new Error('--operand-sweep requires a paired mode-zero base without other sweeps');
if ((config.spatialQueues || config.spatialSweep) && (config.compaction !== 'adaptive' || config.directStages === 7 || config.compactionSweep || config.dispatchSweep)) throw new Error('Spatial queues require fixed adaptive compaction');
if (config.spatialSweep && (!config.paired || config.spatialQueues || config.sort !== 'none' || (config.directStages & 2) !== 0 || config.tailSweep || config.packetSweep || config.materialSweep || config.sortSweep || config.shadowSweep || config.opcodeSweep || config.scheduleSweep)) throw new Error('--spatial-sweep requires a paired unsorted base without other sweeps');
if (!['original', 'optimized'].includes(config.materialSchedule)) throw new Error('Invalid material scheduling');
if (config.scheduleSweep && (!config.paired || config.materialSchedule !== 'original' || config.tailSweep || config.packetSweep || config.materialSweep || config.sortSweep || config.shadowSweep || config.dispatchSweep || config.compactionSweep || config.opcodeSweep)) throw new Error('--schedule-sweep requires a paired original-schedule base without other sweeps');
if (!Number.isInteger(config.materialLayers) || config.materialLayers < 0 || config.materialLayers > 12 || (config.materialMixed && config.materialLayers === 0)) throw new Error('Invalid material stress workload');
if (!config.materialCapacities.length || config.materialCapacities.some(n => ![0, 1, 2, 4, 8, 16].includes(n)) || new Set(config.materialCapacities).size !== config.materialCapacities.length) throw new Error('Invalid material sweep capacities');
if (!['full', 'scene'].includes(config.opcodeMode)) throw new Error('Invalid opcode mode');
if (config.opcodeSweep && (!config.paired || config.tailSweep || config.packetSweep || config.materialSweep || config.sortSweep || config.shadowSweep || config.dispatchSweep || config.compactionSweep || config.opcodeMode !== 'full'))
	throw new Error('--opcode-sweep requires paired full-opcode base and cannot combine with other sweeps');
if (!['serial', 'parallel', 'parallel-auto'].includes(config.shadowMode)) throw new Error('Invalid shadow mode');
if (config.shadowSweep && (!config.paired || config.tailSweep || config.packetSweep || config.materialSweep || config.sortSweep || config.dispatchSweep || config.compactionSweep || config.shadowMode !== 'serial'))
	throw new Error('--shadow-sweep requires paired serial base and cannot combine with other sweeps');
if (!['none', 'material', 'program'].includes(config.sort) || ![64, 256].includes(config.sortSize)) throw new Error('Invalid shading sort');
if ((config.sort !== 'none' || config.sortSweep) && (config.compaction === 'none' || (config.directStages & 2) !== 0 || config.dispatchSweep || config.compactionSweep))
	throw new Error('Sorting requires queued shading and a fixed compaction/direct-stage choice');
if (config.sortSweep && (!config.paired || config.tailSweep || config.packetSweep || config.materialSweep || config.sort !== 'none'))
	throw new Error('--sort-sweep requires paired unsorted base and cannot combine with other sweeps');
if (config.materialSweep && (!config.paired || config.tailSweep || config.compactionSweep || config.dispatchSweep || config.packetSweep || config.materialStack !== null))
	throw new Error('--material-sweep requires paired auto capacity and cannot combine with other sweeps');
if (!Number.isInteger(config.packetStages) || config.packetStages < 0 || config.packetStages > 7) throw new Error('Invalid packet stage mask');
if (config.packetSweep && (!config.paired || config.compaction !== 'packet' || config.tailSweep || config.compactionSweep || config.dispatchSweep))
	throw new Error('--packet-sweep requires paired packet compaction and cannot combine with other sweeps');
if (!Number.isInteger(config.directStages) || config.directStages < 0 || config.directStages > 7) throw new Error('Invalid direct stage mask');
if (!['dense', 'queued', 'subgroup', 'adaptive', 'packet', 'none'].includes(config.compaction)) throw new Error('Invalid compaction mode');
if ((config.compaction === 'none' || config.compaction === 'packet' || config.directStages === 7) && config.tailThreshold !== 0) throw new Error('Direct/packet dispatch supports fixed tails only');
if (config.materialStack !== null && ![0, 1, 2, 4, 8, 16].includes(config.materialStack)) throw new Error('Invalid material stack capacity');
if (config.paired && config.mode !== 'wavefront') throw new Error('--paired requires --mode wavefront');
if (config.tailSweep && !config.paired) throw new Error('--tail-sweep requires --paired --mode wavefront');
if (config.compactionSweep && (!config.paired || config.tailSweep)) throw new Error('--compaction-sweep requires --paired and cannot combine with --tail-sweep');
if (config.dispatchSweep && (!config.paired || config.tailSweep || config.compactionSweep || config.compaction === 'none'))
	throw new Error('--dispatch-sweep requires paired queued execution and cannot combine with other sweeps');
config.variants = [{ name: 'wavefront', tailStart: config.tailStart, tailThreshold: config.tailThreshold }];
if (config.tailSweep) {
	config.variants.push({ name: 'staged', tailStart: 999, tailThreshold: 0 },
		...[0, 1, 2, 3].map(tailStart => ({ name: `fixed-${tailStart}`, tailStart, tailThreshold: 0 })),
		...(config.compaction === 'none' || config.compaction === 'packet' || config.directStages === 7 ? [] : [8192, 32768, 131072]).map(tailThreshold => ({ name: `adaptive-${tailThreshold}`, tailStart: 0, tailThreshold })));
}
if (config.compactionSweep) {
	for (const compaction of ['dense', 'queued', 'subgroup', 'adaptive', 'packet', 'none'].filter(mode => mode !== config.compaction
		&& (mode !== 'subgroup' || config.subgroups) && (!['none', 'packet'].includes(mode) || config.tailThreshold === 0)))
		config.variants.push({ name: `compact-${compaction}`, tailStart: config.tailStart, tailThreshold: config.tailThreshold, compaction });
}
if (config.dispatchSweep) {
	for (let directStages = 0; directStages < 8; directStages++) {
		if (directStages !== config.directStages && (directStages !== 7 || config.tailThreshold === 0))
			config.variants.push({ name: `dispatch-${directStages}`, tailStart: config.tailStart, tailThreshold: config.tailThreshold, directStages });
	}
}
if (config.packetSweep) {
	for (let packetStages = 0; packetStages < 8; packetStages++) {
		if (packetStages !== config.packetStages) config.variants.push({ name: `packet-${packetStages}`, tailStart: config.tailStart, tailThreshold: config.tailThreshold, packetStages });
	}
}
if (config.materialSweep) {
	for (const materialStack of config.materialCapacities) for (const mode of ['megakernel', 'wavefront'])
		config.variants.push({ name: `${mode}-stack-${materialStack}`, mode, materialStack, tailStart: config.tailStart, tailThreshold: config.tailThreshold });
}
if (config.sortSweep) {
	for (const sort of ['material', 'program']) for (const sortSize of [64, 256])
		config.variants.push({ name: `sort-${sort}-${sortSize}`, sort, sortSize, tailStart: config.tailStart, tailThreshold: config.tailThreshold });
}
if (config.spatialSweep) {
	config.variants.push({ name: 'spatial-queues', spatialQueues: true, tailStart: config.tailStart, tailThreshold: config.tailThreshold });
	for (const sort of ['material', 'program']) for (const spatialQueues of [false, true])
		config.variants.push({ name: `spatial-${sort}-256-${spatialQueues ? 'physical' : 'inherited'}`, sort, sortSize: 256, spatialQueues,
			tailStart: config.tailStart, tailThreshold: config.tailThreshold });
}
if (config.shadowSweep) {
	for (const shadowMode of ['parallel', 'parallel-auto'])
		config.variants.push({ name: `shadow-${shadowMode}`, shadowMode, tailStart: config.tailStart, tailThreshold: config.tailThreshold });
}
if (config.opcodeSweep) {
	for (const mode of ['megakernel', 'wavefront'])
		config.variants.push({ name: `${mode}-opcodes`, mode, opcodeMode: 'scene', tailStart: config.tailStart, tailThreshold: config.tailThreshold });
}
if (config.scheduleSweep) {
	for (const mode of ['megakernel', 'wavefront'])
		config.variants.push({ name: `${mode}-scheduled`, mode, materialSchedule: 'optimized', tailStart: config.tailStart, tailThreshold: config.tailThreshold });
}
if (config.operandSweep) {
	for (const operandMode of config.operandModes) for (const mode of ['megakernel', 'wavefront'])
		config.variants.push({ name: `${mode}-operands-${operandMode}`, mode, operandMode, tailStart: config.tailStart, tailThreshold: config.tailThreshold });
}
if (config.raySortSweep) {
	for (const [raySortSize, sortIndirect] of [[64, false], [256, false], [256, true]])
		config.variants.push({ name: `rays-${raySortSize}${sortIndirect ? '-indirect' : ''}`, raySortSize, sortIndirect, tailStart: config.tailStart, tailThreshold: config.tailThreshold });
}
if (config.sortIndirectSweep) config.variants.push({ name: 'sort-indirect', sortIndirect: true, tailStart: config.tailStart, tailThreshold: config.tailThreshold });
if (config.opaqueSweep) config.variants.push({ name: 'megakernel-opaque', mode: 'megakernel', opaqueMegakernel: true, tailStart: config.tailStart, tailThreshold: config.tailThreshold });
if (config.shadeSweep) for (const shadeMode of ['split', 'late', 'split-late'])
	config.variants.push({ name: `shade-${shadeMode}`, shadeMode, tailStart: config.tailStart, tailThreshold: config.tailThreshold });
if (config.bucketSweep) config.variants.push({ name: 'shade-buckets', shadeBuckets: true, tailStart: config.tailStart, tailThreshold: config.tailThreshold });
if (config.bucketSweep && config.sort === 'none' && config.compaction !== 'none' && (config.directStages & 2) === 0) {
	for (const shadeBuckets of [false, true]) config.variants.push({ name: shadeBuckets ? 'buckets-program' : 'sort-program', shadeBuckets,
		sort: 'program', sortSize: 256, tailStart: config.tailStart, tailThreshold: config.tailThreshold });
}
if (config.partitionSweep) for (const shadeBucketMode of ['scan', 'compact']) config.variants.push({ name: `buckets-${shadeBucketMode}`, shadeBuckets: true, shadeBucketMode, tailStart: config.tailStart, tailThreshold: config.tailThreshold });
if (config.cyclesSweep) {
	if (!config.paired || config.separateLight || config.batchedShadows) throw new Error('Cycles sweep requires paired unmodified base');
	for (const [name, separateLight, batchedShadows] of [['separate-light', true, false], ['batched-shadows', false, true], ['cycles-stages', true, true]])
		config.variants.push({ name, separateLight, batchedShadows, tailStart: config.tailStart, tailThreshold: config.tailThreshold });
}
for (const variant of config.variants) {
	variant.separateLight ??= config.separateLight;
	variant.batchedShadows ??= config.batchedShadows;
	variant.shadeBucketMode ??= config.shadeBucketMode;
	variant.shadeBuckets ??= config.shadeBuckets;
	variant.shadeMode ??= config.shadeMode;
	variant.mode ??= 'wavefront';
	variant.materialStack ??= config.materialStack;
	variant.opaqueMegakernel ??= config.opaqueMegakernel;
	variant.compaction ??= config.compaction;
	variant.directStages ??= config.directStages;
	variant.packetStages ??= config.packetStages;
	variant.sort ??= config.sort;
	variant.sortSize ??= config.sortSize;
	variant.raySortSize ??= config.raySortSize;
	variant.sortIndirect ??= config.sortIndirect;
	variant.spatialQueues ??= config.spatialQueues;
	variant.shadowMode ??= config.shadowMode;
	variant.opcodeMode ??= config.opcodeMode;
	variant.operandMode ??= config.operandMode;
	variant.materialSchedule ??= config.materialSchedule;
}
for (const key of ['width', 'height', 'warmup', 'variantWarmup', 'samples', 'repeats', 'bounces']) {
	if (!Number.isInteger(config[key]) || config[key] < (key === 'bounces' ? 0 : 1)) throw new Error(`Invalid ${key}`);
}
const measurementVariants = ['megakernel', ...config.variants.map(v => v.name)];
if (config.balancedOrder && (!config.paired || config.repeats % measurementVariants.length !== 0)) throw new Error(`--balanced-order requires paired repeats in multiples of ${measurementVariants.length}`);
config.measurementOrders = config.balancedOrder ? Array.from({ length: config.repeats }, (_, repeat) => balancedMeasurementOrder(measurementVariants, repeat)) : null;
const cases = [
	...(args.includes('--cycles-fixtures') ? ['deep-alpha', 'masked-emitter', 'mixed-alpha', 'opaque-shadow'].map(name => ({ name, fixture: name, file: 'scripts/wavefront-cycles-fixtures.ts', environment: 0, presentationExposure: 0 })) : []),
	{ name: 'classroom', file: 'classroom/gltf/classroom_extended.glb', environment: 1, presentationExposure: 4 },
	{ name: 'breakfast-room', file: 'breakfast-room/gltf/breakfast_room_extended.glb', environment: 1, presentationExposure: 6 },
	{ name: 'bmw-m6', file: 'bmw-m6/gltf/bmw_m6_extended.glb', environment: 1, presentationExposure: 2 },
	{ name: 'glass-of-water', file: 'glass-of-water/gltf/glass_of_water_extended.glb', environment: 0, presentationExposure: 0 },
	{ name: 'veach-mis', file: 'veach-mis/gltf/veach_mis_extended.glb', environment: 0, presentationExposure: 0 },
].filter(c => option('only', '').split(',').filter(Boolean).length === 0 || option('only', '').split(',').includes(c.name));
if (!cases.length) throw new Error('No selected scenes');
for (const c of cases) {
	c.path = join(c.fixture ? root : scenesRoot, c.file);
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
	root, server: { port: 5201, strictPort: false, hmr: false }, logLevel: 'warn',
	plugins: [{ name: 'research-scenes', configureServer(server) {
		server.middlewares.use((req, res, next) => {
			const c = cases.find(c => req.url === `/__research/${c.name}.glb`);
			if (!c || c.fixture) return next();
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
	const paths = ['scripts/wavefront-benchmark.mjs', 'scripts/benchmark-order.mjs', 'scripts/wavefront-material-stress.ts', 'scripts/wavefront-material-variants.ts', 'scripts/wavefront-cycles-fixtures.ts', 'package.json', 'package-lock.json', 'vite.config.ts'];
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
	return [variant.name, { ...report, config: { ...config, mode: variant.mode, opaqueMegakernel: variant.opaqueMegakernel, materialStack: variant.materialStack, tailStart: variant.tailStart, tailThreshold: variant.tailThreshold, compaction: variant.compaction, directStages: variant.directStages, packetStages: variant.packetStages, sort: variant.sort, sortSize: variant.sortSize, raySortSize: variant.raySortSize, sortIndirect: variant.sortIndirect, separateLight: variant.separateLight, batchedShadows: variant.batchedShadows, shadeMode: variant.shadeMode, shadeBuckets: variant.shadeBuckets, shadeBucketMode: variant.shadeBucketMode, spatialQueues: variant.spatialQueues, shadowMode: variant.shadowMode, operandMode: variant.operandMode, opcodeMode: variant.opcodeMode, materialSchedule: variant.materialSchedule }, results: [] }];
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
			const pipelineConstants = new WeakMap();
			const sceneMaterials = new WeakMap(), createBindGroup = GPUDevice.prototype.createBindGroup;
			GPUDevice.prototype.createBindGroup = function(descriptor) {
				const group = createBindGroup.call(this, descriptor);
				if (descriptor.label === 'scene') sceneMaterials.set(group, descriptor.entries.find(e => e.binding === 6).resource.buffer);
				return group;
			};
			const createComputePipeline = GPUDevice.prototype.createComputePipelineAsync;
			GPUDevice.prototype.createComputePipelineAsync = function(descriptor) {
				const start = performance.now();
				return createComputePipeline.call(this, descriptor).then(pipeline => {
					pipelineConstants.set(pipeline, descriptor.compute.constants ?? {});
					pipelineCompilations.push({ label: descriptor.label, constants: descriptor.compute.constants ?? {}, elapsedMs: performance.now() - start });
					return pipeline;
				});
			};
			GPUDevice.prototype.createShaderModule = function(descriptor) {
				if (descriptor.label === 'PathTracing' || descriptor.label === 'PathTracingOpaque' || descriptor.label === 'Wavefront') {
					const capacities = [...descriptor.code.matchAll(/var stack_\d+\s*:\s*array<vec4<f32>,\s*i32\((\d+)\)>/g)].map(match => Number(match[1]));
					if (!capacities.length) capacities.push(0); // Constant-only modules have no SVM stack.
					if (capacities.some(capacity => capacity !== capacities[0])) throw new Error('Unexpected effective SVM shader capacity');
					observedStackCapacities[descriptor.label] = [...new Set([...(observedStackCapacities[descriptor.label] ?? []), ...capacities])];
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
			// Load the production-order scene before selecting the scheduled buffer. Its
			// original stack may exceed a forced capacity valid only for the scheduled DAG.
			renderer.tracer.materialStackOverride = config.materialSchedule === 'optimized' ? null : config.materialStack;
			renderer.tracer.materialOpcodeSpecialization = config.opcodeMode === 'scene';
			renderer.tracer.materialOperandMode = config.operandMode;
			renderer.tracer.opaqueMegakernel = config.opaqueMegakernel;
			Object.assign(renderer.settings, { maxSamples: 0, samplesPerFrame: 1, maxBounces: config.bounces,
				autoExposureMethod: AutoExposureMethod.Manual, autoExposureBias: 0, localExposureMethod: LocalExposureMethod.None,
				environmentIntensity: c.environment, fireflyClamp: config.clamp });
			renderer.sun.enabled = c.environment > 0;
			const integratorStart = performance.now();
			if (config.mode !== 'megakernel') await renderer.setIntegrator(config.mode);
			const integratorInitMs = performance.now() - integratorStart;
			const loadStart = performance.now();
			const sceneDescription = c.fixture ? (await import('/scripts/wavefront-cycles-fixtures.ts')).cyclesFixture(c.fixture) : await loadGLTF(`/__research/${c.name}.glb`);
			const { applyMaterialStress } = await import('/scripts/wavefront-material-stress.ts');
			const materialStress = applyMaterialStress(sceneDescription, config.materialLayers, config.materialMixed);
			const { compileSceneMaterials } = await import('/src/render/SceneMaterials.ts');
			const compiledMaterials = compileSceneMaterials(sceneDescription, { schedule: config.materialSchedule === 'optimized' });
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
			let materialVariants = null, currentMaterialSchedule = config.materialSchedule;
			if (config.scheduleSweep || config.materialSchedule === 'optimized') {
				const { materialScheduleVariants } = await import('/scripts/wavefront-material-variants.ts');
				materialVariants = materialScheduleVariants(renderer.device, sceneDescription, renderer.vt.descriptorOf, renderer.scene.materials);
				const material = materialVariants[currentMaterialSchedule];
				Object.assign(renderer.scene, { materials: material.buffer, materialStackSize: material.stack, materialShadeCapacities: material.shadeCapacities, materialSurfaceCapacity: material.surfaceCapacity, materialLightCapacity: material.lightCapacity, materialSurfaceCapacities: material.surfaceCapacities, materialOpacityCapacity: material.opacityCapacity, materialOpcodes: material.opcodes });
				renderer.tracer.materialStackOverride = config.materialStack;
				await renderer.tracer.prepareScene(renderer.scene);
				renderer.bindScene();
			}
			const loadMs = performance.now() - loadStart;
			if (config.mode !== 'megakernel') {
				await renderer.tracer.wavefront.prepareShadeMode(config.shadeMode, renderer.tracer.materialCapacity, renderer.tracer.materialOpcodes, renderer.tracer.boundMaterialOperandMode);
				renderer.tracer.wavefront.tailStart = config.tailStart;
				renderer.tracer.wavefront.tailThreshold = config.tailThreshold;
				renderer.tracer.wavefront.compaction = config.compaction;
				renderer.tracer.wavefront.directStages = config.directStages;
				renderer.tracer.wavefront.packetStages = config.packetStages;
				renderer.tracer.wavefront.sort = config.sort;
				renderer.tracer.wavefront.sortSize = config.sortSize;
				renderer.tracer.wavefront.raySortSize = config.raySortSize;
				renderer.tracer.wavefront.sortIndirect = config.sortIndirect;
				renderer.tracer.wavefront.shadeMode = config.shadeMode;
				if (config.shadeBuckets) await renderer.tracer.wavefront.prepareBuckets(renderer.scene.materialShadeCapacities, renderer.tracer.materialCapacity, renderer.tracer.materialOpcodes, renderer.tracer.boundMaterialOperandMode, config.shadeBucketMode);
				renderer.tracer.wavefront.shadeBuckets = config.shadeBuckets;
				renderer.tracer.wavefront.shadeBucketMode = config.shadeBucketMode;
				renderer.tracer.wavefront.spatialQueues = config.spatialQueues;
				renderer.tracer.wavefront.shadowMode = config.shadowMode;
			}
			const materialCapacity = renderer.tracer.materialCapacity;
			const expectedCapacity = config.materialStack ?? [0, 1, 2, 4, 8, 16].find(capacity => capacity >= materialStackRequired);
			if (materialCapacity !== expectedCapacity) throw new Error('Incorrect production material capacity selection');
			const initialMegakernel = renderer.tracer.boundOpaqueMegakernel ? 'PathTracingOpaque' : 'PathTracing';
			for (const label of config.mode === 'wavefront' ? [initialMegakernel, 'Wavefront'] : [initialMegakernel]) {
				if (!observedStackCapacities[label]?.includes(materialCapacity)) throw new Error(`Missing ${label} shader specialization`);
			}
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
			const setPipeline = GPUComputePassEncoder.prototype.setPipeline;
			const tracedPasses = new WeakSet();
			const shadePasses = new WeakMap();
			const sortPasses = new WeakMap();
			let observedPipelines = new Set(), observedConstants = new Map();
			let observedSortDispatches = new Set();
			const dispatchDirect = GPUComputePassEncoder.prototype.dispatchWorkgroups;
			const dispatchIndirect = GPUComputePassEncoder.prototype.dispatchWorkgroupsIndirect;
			GPUComputePassEncoder.prototype.dispatchWorkgroups = function(x, y, z) {
				const size = sortPasses.get(this);
				if (size) {
					if (size !== 256 || renderer.tracer.wavefront.sortIndirect) throw new Error('Wrong direct sort dispatch');
					observedSortDispatches.add('256:direct');
				}
				return dispatchDirect.call(this, x, y, z);
			};
			GPUComputePassEncoder.prototype.dispatchWorkgroupsIndirect = function(buffer, offset) {
				const size = sortPasses.get(this);
				if (size) {
					if (buffer !== renderer.tracer.wavefront.indirect || offset !== (size === 64 ? 0 : 32)
						|| (size === 256 && !renderer.tracer.wavefront.sortIndirect)) throw new Error('Wrong indirect sort dispatch');
					observedSortDispatches.add(`${size}:indirect`);
				}
				return dispatchIndirect.call(this, buffer, offset);
			};
			let observedMaterialSchedules = new Set();
			const setBindGroup = GPUComputePassEncoder.prototype.setBindGroup;
			GPUComputePassEncoder.prototype.setBindGroup = function(index, group, ...offsets) {
				if (index === 0 && tracedPasses.has(this)) {
					const expected = materialVariants?.[currentMaterialSchedule].buffer ?? renderer.scene.materials;
					if (sceneMaterials.get(group) !== expected) throw new Error('Wrong bound material bytecode schedule');
					observedMaterialSchedules.add(currentMaterialSchedule);
				}
				return setBindGroup.call(this, index, group, ...offsets);
			};
			GPUComputePassEncoder.prototype.setPipeline = function(pipeline) {
				if (tracedPasses.has(this)) {
					const bucket = /^wavefront\.Shade(?:Bucket(?:Direct|Compact)?|SurfaceBucket|SurfaceCompact)\.stack(\d+)$/.exec(pipeline.label);
					const wf = renderer.tracer.wavefront, stage = pipeline.label.split('.')[1];
					const surfaceCapacity = wf?.separateLight ? renderer.scene.materialSurfaceCapacity : renderer.tracer.materialCapacity;
					const caps = wf?.separateLight ? renderer.scene.materialSurfaceCapacities : renderer.scene.materialShadeCapacities;
					const actualCapacity = bucket ? Number(bucket[1]) : stage.startsWith('ShadeSurface') ? surfaceCapacity
						: stage.startsWith('ShadeLight') ? renderer.scene.materialLightCapacity
						: stage === 'ShadowAlpha' ? renderer.scene.materialOpacityCapacity
						: /^(ShadowClassify|CompactShadowAlpha)/.test(stage) ? 0 : renderer.tracer.materialCapacity;
					if (bucket && (!renderer.tracer.wavefront.shadeBuckets || !(renderer.tracer.wavefront.shadeBucketMode === 'material'
						? actualCapacity === surfaceCapacity : caps.includes(actualCapacity)))) throw new Error('Unexpected shading bucket');
					if (!pipeline.label.endsWith(`.stack${actualCapacity}`)) throw new Error(`Wrong tracing pipeline: ${pipeline.label}`);
					const constants = pipelineConstants.get(pipeline) ?? {};
					if ('0' in constants && (constants['0'] !== renderer.tracer.materialOpcodes[0] || constants['1'] !== renderer.tracer.materialOpcodes[1])) throw new Error('Wrong bound opcode specialization');
					const usesMaterial = pipeline.label.startsWith('pathTracing.') || /^wavefront\.(Shade\w*|Tail|TailOpaque|Intersect|IntersectDirect|Shadow|ShadowDirect)\./.test(pipeline.label);
					if (usesMaterial && actualCapacity > 0 && constants['2'] !== renderer.tracer.boundMaterialOperandMode) throw new Error('Wrong bound operand mode');
					const bounce = shadePasses.get(this);
					if (bounce !== undefined) {
						const wf = renderer.tracer.wavefront, mode = wf.shadeMode;
						const expected = wf.separateLight ? `ShadeSurface${bucket ? (wf.shadeBucketMode === 'material' ? 'Compact' : 'Bucket') : ''}${wf.compaction === 'none' || (wf.directStages & 2) !== 0 ? 'Direct' : ''}` : `Shade${bucket ? `Bucket${wf.shadeBucketMode !== 'scan' ? 'Compact' : ''}` : ''}${mode.startsWith('split') ? (bounce === 0 ? 'Primary' : 'Secondary') : ''}${mode.endsWith('late') ? 'Late' : ''}${wf.compaction === 'none' || (wf.directStages & 2) !== 0 ? 'Direct' : ''}`;
						if (pipeline.label !== `wavefront.${expected}.stack${actualCapacity}`) throw new Error('Wrong bound shading phase');
					}
					observedConstants.set(pipeline.label, constants);
					observedPipelines.add(pipeline.label);
				}
				return setPipeline.call(this, pipeline);
			};
			const copyBuffer = GPUCommandEncoder.prototype.copyBufferToBuffer;
			const queueRecordBytes = 48; // Counts plus both indirect argument records.
			const queueReadback = config.diagnose ? device.createBuffer({ size: 4096 * queueRecordBytes, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ }) : null;
			let queueCopies = 0, captureQueues = false, queueSnapshots = [];
			const queuePhases = [];
			GPUCommandEncoder.prototype.copyBufferToBuffer = function(source, sourceOffset, destination, destinationOffset, size) {
				copyBuffer.call(this, source, sourceOffset, destination, destinationOffset, size);
				if (captureQueues && destination.label === 'wavefrontDispatch' && destinationOffset === 0 && size === 32) {
					if (queueCopies >= 4096) throw new Error('Queue diagnostic capacity exceeded');
					queuePhases.push(labels.at(-1));
					copyBuffer.call(this, source, sourceOffset - 16, queueReadback, queueCopies++ * queueRecordBytes, queueRecordBytes);
				}
			};
			let labels = [], measuring = false;
			GPUCommandEncoder.prototype.beginComputePass = function(descriptor = {}) {
				const trace = measuring && (descriptor.label === 'pathTracing' || descriptor.label?.startsWith('wavefront.'));
				if (trace) {
					const index = labels.length * 2;
					if (index + 1 >= queryCapacity) throw new Error('Timestamp query capacity exceeded; reduce resolution or bounce count');
					labels.push(descriptor.label);
					descriptor = { ...descriptor, timestampWrites: { querySet: queries, beginningOfPassWriteIndex: index, endOfPassWriteIndex: index + 1 } };
				}
				const pass = begin.call(this, descriptor);
				if (trace) tracedPasses.add(pass);
				const shadeMatch = /^wavefront\.Shade(?:Bucket(?:Compact)?\d+)?\.b(\d+)/.exec(descriptor.label ?? '');
				if (shadeMatch) shadePasses.set(pass, Number(shadeMatch[1]));
				const sortMatch = trace && /^wavefront\.Sort(?:Material|Program|Direction)(64|256)\./.exec(descriptor.label);
				if (sortMatch) sortPasses.set(pass, Number(sortMatch[1]));
				return pass;
			};
			const repeats = [];
			let candidateHDR, referenceHDR;
			const variantHDRs = new Map();
			let presentationVariant = config.mode;
			const pairedErrors = [];
			for (let repeat = 0; repeat < config.repeats; repeat++) {
				const schedule = config.paired ? [{ name: 'megakernel' }, ...config.variants] : [{ name: config.mode, tailStart: config.tailStart, tailThreshold: config.tailThreshold, compaction: config.compaction, directStages: config.directStages, packetStages: config.packetStages, sort: config.sort, sortSize: config.sortSize, raySortSize: config.raySortSize, sortIndirect: config.sortIndirect, separateLight: config.separateLight, batchedShadows: config.batchedShadows, shadeMode: config.shadeMode, shadeBuckets: config.shadeBuckets, shadeBucketMode: config.shadeBucketMode, spatialQueues: config.spatialQueues, shadowMode: config.shadowMode, opcodeMode: config.opcodeMode }];
				// Legacy sweeps rotate/reverse each round. Balanced sweeps cover every position
				// once per full cycle and reverse alternate cycles.
				if (config.balancedOrder) {
					const order = config.measurementOrders[repeat];
					schedule.sort((a, b) => order.indexOf(a.name) - order.indexOf(b.name));
				} else {
					if (config.tailSweep || config.compactionSweep || config.dispatchSweep || config.packetSweep || config.materialSweep || config.sortSweep || config.shadowSweep || config.opcodeSweep || config.scheduleSweep || config.spatialSweep || config.operandSweep || config.raySortSweep || config.sortIndirectSweep || config.opaqueSweep || config.shadeSweep || config.bucketSweep || config.partitionSweep) schedule.push(...schedule.splice(0, repeat % schedule.length));
					if (config.paired && repeat % 2 !== 0) schedule.reverse();
				}
				for (const [measurementPosition, variant] of schedule.entries()) {
					const mode = variant.mode ?? (variant.name === 'megakernel' ? 'megakernel' : 'wavefront');
					presentationVariant = variant.name;
					if (config.paired) {
						const requestedSchedule = variant.materialSchedule ?? config.materialSchedule;
						const material = materialVariants?.[requestedSchedule];
						const requiredStack = material?.stack ?? materialStackRequired;
						const requestedStack = variant.materialStack ?? config.materialStack;
						if (requestedStack !== null && requestedStack < requiredStack) throw new Error(`Material sweep needs at least ${requiredStack} stack slots`);
						const requestedOpcodes = (variant.opcodeMode ?? config.opcodeMode) === 'scene';
						const requestedOperands = variant.operandMode ?? config.operandMode;
						const requestedOpaque = variant.opaqueMegakernel ?? config.opaqueMegakernel;
						if (renderer.tracer.materialStackOverride !== requestedStack || renderer.tracer.materialOpcodeSpecialization !== requestedOpcodes || currentMaterialSchedule !== requestedSchedule || renderer.tracer.materialOperandMode !== requestedOperands || renderer.tracer.opaqueMegakernel !== requestedOpaque) {
							if (material) Object.assign(renderer.scene, { materials: material.buffer, materialStackSize: material.stack, materialShadeCapacities: material.shadeCapacities, materialSurfaceCapacity: material.surfaceCapacity, materialLightCapacity: material.lightCapacity, materialSurfaceCapacities: material.surfaceCapacities, materialOpacityCapacity: material.opacityCapacity, materialOpcodes: material.opcodes });
							currentMaterialSchedule = requestedSchedule;
							renderer.tracer.materialStackOverride = requestedStack;
							renderer.tracer.materialOpcodeSpecialization = requestedOpcodes;
							renderer.tracer.materialOperandMode = requestedOperands;
							renderer.tracer.opaqueMegakernel = requestedOpaque;
							await renderer.tracer.prepareScene(renderer.scene);
							renderer.bindScene();
						}
						const expectedStack = requestedStack ?? [0, 1, 2, 4, 8, 16].find(n => n >= requiredStack);
						if (renderer.tracer.boundMaterialOperandMode !== requestedOperands) throw new Error('Operand sweep selected the wrong mode');
						if (renderer.tracer.materialCapacity !== expectedStack) throw new Error('Material sweep selected the wrong capacity');
						if (renderer.tracer.boundOpaqueMegakernel !== (requestedOpaque && renderer.scene.instanceCount > 0 && !renderer.scene.hasAlphaTested)) throw new Error('Wrong bound opaque traversal selection');
						await renderer.setIntegrator(mode);
						await renderer.setSeparateLight(mode === 'wavefront' && !!variant.separateLight);
						await renderer.setBatchedShadows(mode === 'wavefront' && !!variant.batchedShadows);
						if (mode === 'wavefront') await renderer.tracer.wavefront.prepareShadeMode(variant.shadeMode, renderer.tracer.materialCapacity, renderer.tracer.materialOpcodes, renderer.tracer.boundMaterialOperandMode);
						if (mode === 'wavefront' && variant.shadeBuckets) await renderer.tracer.wavefront.prepareBuckets(renderer.scene.materialShadeCapacities, renderer.tracer.materialCapacity, renderer.tracer.materialOpcodes, renderer.tracer.boundMaterialOperandMode, variant.shadeBucketMode);
						if (mode === 'wavefront') Object.assign(renderer.tracer.wavefront, { tailStart: variant.tailStart, tailThreshold: variant.tailThreshold, compaction: variant.compaction, directStages: variant.directStages, packetStages: variant.packetStages, sort: variant.sort, sortSize: variant.sortSize, raySortSize: variant.raySortSize, sortIndirect: variant.sortIndirect, separateLight: variant.separateLight, batchedShadows: variant.batchedShadows, shadeMode: variant.shadeMode, shadeBuckets: variant.shadeBuckets, shadeBucketMode: variant.shadeBucketMode, spatialQueues: variant.spatialQueues, shadowMode: variant.shadowMode });
						// Warm each selected pipeline before timing while retaining identical scene/VT data.
						for (let warm = 0; warm < config.variantWarmup; warm++) { renderer.renderFrame(); await device.queue.onSubmittedWorkDone(); }
					}
					renderer.resetAccumulation();
					if (mode === 'wavefront' && (renderer.tracer.wavefront.shadeMode !== variant.shadeMode || renderer.tracer.wavefront.shadeBuckets !== variant.shadeBuckets || renderer.tracer.wavefront.shadeBucketMode !== variant.shadeBucketMode)) throw new Error('Requested shading mode was not selected');
					observedPipelines = new Set(); observedConstants = new Map(); observedMaterialSchedules = new Set();
					observedSortDispatches = new Set();
					const measurementStartedAt = Date.now();
					const timings = [], spanTimings = [], stages = {}, wall = performance.now();
					for (let sample = 0; sample < config.samples; sample++) {
						captureQueues = config.diagnose && sample === 0 && repeat === 0 && variant.name === 'wavefront';
						labels = []; measuring = true;
						renderer.renderFrame();
						captureQueues = false;
						measuring = false;
						if (!labels.length) throw new Error('No trace passes were measured');
						if (mode === 'wavefront' && (variant.compaction === 'none' || variant.directStages === 7) && labels.some(label => label.includes('.Compact') && !label.includes('.CompactShadowAlpha')))
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
					const measurementFinishedAt = Date.now();
					const wallMs = performance.now() - wall;
					const sorted = [...timings].sort((a, b) => a - b);
					const medianMs = (sorted[Math.floor((sorted.length - 1) / 2)] + sorted[Math.floor(sorted.length / 2)]) * 0.5;
					const sortedSpans = [...spanTimings].sort((a, b) => a - b);
					const medianSpanMs = (sortedSpans[Math.floor((sortedSpans.length - 1) / 2)] + sortedSpans[Math.floor(sortedSpans.length / 2)]) * 0.5;
					if (observedMaterialSchedules.size !== 1) throw new Error('Material schedule binding was not exercised');
					if (mode === 'megakernel') {
						const expected = `pathTracing.${renderer.tracer.boundOpaqueMegakernel ? 'opaque.' : ''}stack${renderer.tracer.materialCapacity}`;
						if (observedPipelines.size !== 1 || !observedPipelines.has(expected)) throw new Error('Wrong measured megakernel traversal pipeline');
						const shader = renderer.tracer.boundOpaqueMegakernel ? 'PathTracingOpaque' : 'PathTracing';
						if (!observedStackCapacities[shader]?.includes(renderer.tracer.materialCapacity)) throw new Error('Wrong measured shader capacity');
					}
					if (mode === 'wavefront' && config.bounces > 0 && (variant.tailStart > 1 || variant.tailThreshold > 0)) {
						const directions = [...observedPipelines].filter(label => label.startsWith('wavefront.SortDirection'));
						if (directions.length !== (variant.raySortSize ? 1 : 0) || directions.some(label => !label.startsWith(`wavefront.SortDirection${variant.raySortSize}.`))) throw new Error('Wrong direction sort pipeline');
					}
					if (mode === 'wavefront' && config.bounces > 0 && variant.tailStart > 0) {
						const spatial = [...observedPipelines].some(label => label.includes('.CompactShadeSpatial.'));
						if (spatial !== variant.spatialQueues) throw new Error('Wrong spatial queue pipeline');
					}
					if (mode === 'wavefront' && (variant.tailStart > 0 || variant.tailThreshold > 0)) {
						const caps = variant.separateLight ? renderer.scene.materialSurfaceCapacities : renderer.scene.materialShadeCapacities;
						const shadeCapacity = variant.separateLight ? renderer.scene.materialSurfaceCapacity : renderer.tracer.materialCapacity;
						const expected = variant.shadeBuckets ? (variant.shadeBucketMode === 'material'
							? [shadeCapacity] : !(caps.length === 1 && caps[0] === shadeCapacity) ? caps : []) : [];
						const actual = [...observedPipelines].filter(x => /^wavefront\.Shade(?:Bucket|SurfaceBucket|SurfaceCompact)/.test(x)).map(x => Number(x.split('.stack')[1])).sort((a,b) => a-b);
						if (JSON.stringify(actual) !== JSON.stringify(expected)) throw new Error('Missing or duplicate shading bucket');
					}
					repeats.push({ separateLight: mode === 'wavefront' && renderer.tracer.separateLight, batchedShadows: mode === 'wavefront' && renderer.tracer.batchedShadows, materialLightCapacity: renderer.scene.materialLightCapacity, materialSurfaceCapacity: renderer.scene.materialSurfaceCapacity, materialOpacityCapacity: renderer.scene.materialOpacityCapacity, shadeBucketMode: mode === 'wavefront' ? renderer.tracer.wavefront.shadeBucketMode : null, shadeBuckets: mode === 'wavefront' && renderer.tracer.wavefront.shadeBuckets, materialShadeCapacities: renderer.scene.materialShadeCapacities, shadeMode: mode === 'wavefront' ? renderer.tracer.wavefront.shadeMode : null, measurementPosition, measurementStartedAt, measurementFinishedAt, mode, opaqueMegakernel: renderer.tracer.boundOpaqueMegakernel, operandMode: renderer.tracer.boundMaterialOperandMode, materialSchedule: currentMaterialSchedule, boundMaterialSchedules: [...observedMaterialSchedules], materialStackRequired: renderer.scene.materialStackSize, materialCapacity: renderer.tracer.materialCapacity, pipelineLabels: [...observedPipelines], sortDispatches: [...observedSortDispatches], opcodeConstants: Object.fromEntries(observedConstants), materialOpcodes: renderer.tracer.materialOpcodes, variant: variant.name, repeat, medianMs, medianSpanMs, meanMs: timings.reduce((a, b) => a + b) / timings.length, wallMs, timings, spanTimings, stages });
					console.log(`[benchmark] ${c.name}: ${variant.name} repeat ${repeat + 1}, GPU passes ${medianMs.toFixed(3)}, span ${medianSpanMs.toFixed(3)} ms/sample`);
					if (config.paired) {
						const hdr = await renderer.readRadiance();
						if (variant.name !== 'megakernel') {
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
			GPUComputePassEncoder.prototype.setPipeline = setPipeline;
			GPUComputePassEncoder.prototype.dispatchWorkgroups = dispatchDirect;
			GPUComputePassEncoder.prototype.dispatchWorkgroupsIndirect = dispatchIndirect;
			GPUCommandEncoder.prototype.copyBufferToBuffer = copyBuffer;
			GPUDevice.prototype.createShaderModule = createShaderModule;
			GPUDevice.prototype.createComputePipelineAsync = createComputePipeline;
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
					const sortGroups = counters[offset + 3];
					if (sortGroups !== (config.sortIndirect ? Math.ceil(active / 256) : 0)) throw new Error(`Invalid sort bound after ${phase}`);
					if (active > tilePathCount || shadow > tilePathCount || mainGroups !== Math.ceil((denseBound ? tilePathCount : active) / 64)
						|| shadowGroups !== Math.ceil(shadow / 64)) throw new Error(`Invalid queue/dispatch bounds after ${phase}`);
					const mainPacket = config.compaction === 'packet' && (config.packetStages & (phase.includes('CompactIntersect') ? 2 : 1));
					const shadowPacket = config.compaction === 'packet' && (config.packetStages & 4);
					queueSnapshots.push({ countUnit: mainPacket ? 'retained-slots' : 'active-paths',
						shadowCountUnit: shadowPacket ? 'retained-slots' : 'active-paths', phase, tilePathCount, active, shadow,
						mainA: counters[offset], mainB: counters[offset + 2], mainGroups, shadowGroups, sortGroups });
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
				return { name: variant.name, materialCapacity: repeats.find(r => r.variant === variant.name).materialCapacity, repeats: repeats.filter(r => r.variant === variant.name),
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
			if (materialVariants) for (const variant of Object.values(materialVariants)) if (variant.buffer !== renderer.scene.materials) variant.buffer.destroy();
			return { adapterInfo, deviceFeatures: [...device.features], initMs, integratorInitMs, loadMs, materialStress, materialPrograms, materialStackRequired, materialCapacity, observedStackCapacities,
				shaderCompilations, pipelineCompilations, warmFrames: warmFrames + 1,
				presentationIntegrator: renderer.integrator, presentationVariant, presentationExposure: c.presentationExposure, scene: renderer.sceneStats, vt: renderer.virtualTextureStats,
				camera: { position: renderer.camera.position, target: renderer.camera.target, up: renderer.camera.up, fovY: renderer.camera.fovY },
				repeats: repeats.filter(r => r.variant === config.mode), referenceRepeats: repeats.filter(r => r.variant === 'megakernel'), pairedErrors: pairedErrors.filter(r => r.variant === 'wavefront'), variants,
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
