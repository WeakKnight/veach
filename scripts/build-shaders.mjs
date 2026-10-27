// Compiles the Slang sources under shaders/ to WGSL under src/generated/shaders.
// slangc is taken from $SLANGC, .tools/slang, or PATH; if none is found, the pinned release is
// downloaded into .tools/slang.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { shaderFingerprint } from './shader-fingerprint.mjs';
import { encodeVariant, sourceChecksum } from './material-stack-variants.mjs';

const SLANG_VERSION = '2026.20';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const shaderDir = join(root, 'shaders');
const stackOption = process.argv.indexOf('--material-stack');
const materialStack = stackOption < 0 ? null : Number(process.argv[stackOption + 1]);
if (materialStack !== null && ![1, 2, 4, 8, 16].includes(materialStack)) throw new Error('Material stack must be 1, 2, 4, 8 or 16');
// Investigation variants never overwrite the production fallback.
const outDir = materialStack === null ? join(root, 'src', 'generated', 'shaders') : join(root, '.tools', 'wavefront', `stack-${materialStack}`);
const isWindows = process.platform === 'win32';
const exe = isWindows ? 'slangc.exe' : 'slangc';

// Each program becomes one WGSL module containing all of its entry points.
const programs = [
	{ name: 'OIDNGuides', source: 'Passes/OIDNGuides.slang', entries: [['Prepare', 'compute'], ['Compose', 'compute']] },
	{ name: 'PathTracing', source: 'Passes/PathTracing.slang', entries: [['main', 'compute']] },
	{ name: 'PathTracingEmpty', source: 'Passes/PathTracing.slang', defines: ['VEACH_EMPTY_SCENE=1'], entries: [['main', 'compute']] },
	{ name: 'Wavefront', source: 'Passes/Wavefront.slang', entries: ['Initialize', 'Intersect', 'IntersectOpaque', 'Shade', 'Shadow', 'ShadowOpaque', 'Tail', 'TailOpaque', 'Finalize',
		'IntersectDirect', 'IntersectOpaqueDirect', 'ShadeDirect', 'ShadowDirect', 'ShadowOpaqueDirect'].map(e => [e, 'compute']) },
	{ name: 'WavefrontCompact', source: 'Passes/WavefrontCompact.slang', entries: [['CompactIntersect', 'compute'], ['CompactShade', 'compute']] },
	{ name: 'WavefrontCompactSubgroup', source: 'Passes/WavefrontCompact.slang', defines: ['VEACH_SUBGROUP_COMPACTION=1'], entries: [['CompactIntersect', 'compute'], ['CompactShade', 'compute']] },
	{ name: 'WavefrontCompactDense', source: 'Passes/WavefrontCompact.slang', defines: ['VEACH_DENSE_COMPACTION=1'], entries: [['CompactIntersect', 'compute'], ['CompactShade', 'compute']] },
	{ name: 'WavefrontCompactAdaptive', source: 'Passes/WavefrontCompact.slang', defines: ['VEACH_ADAPTIVE_COMPACTION=1'], entries: [['CompactIntersect', 'compute'], ['CompactShade', 'compute']] },
	{ name: 'Present', source: 'Passes/Present.slang', entries: [['vsMain', 'vertex'], ['fsMain', 'fragment']] },
	{
		name: 'LocalExposure',
		source: 'Passes/LocalExposure.slang',
		entries: ['Initialize', 'DownsampleHalf', 'DownsampleFloat', 'Tail', 'Reconstruct', 'ReconstructFused'].map((e) => [e, 'compute']),
	},
	{ name: 'AutoExposure', source: 'Passes/AutoExposure.slang', entries: [['Histogram', 'compute'], ['EyeAdaptation', 'compute']] },
	{
		name: 'Atmosphere',
		source: 'Passes/Atmosphere.slang',
		entries: ['TransmittanceLut', 'MultiScatteringLut', 'SkyViewSkyRows', 'SkyIrradiance', 'SkyViewGroundRows', 'BakeEnvironment', 'CdfRows', 'CdfMarginal'].map((e) => [e, 'compute']),
	},
];

function onPath(name) {
	const probe = spawnSync(isWindows ? 'where' : 'which', [name], { encoding: 'utf8' });
	return probe.status === 0 ? probe.stdout.split(/\r?\n/)[0].trim() : null;
}

function releaseAssetName() {
	const arch = process.arch === 'arm64' ? 'aarch64' : 'x86_64';
	const os = isWindows ? 'windows' : process.platform === 'darwin' ? 'macos' : 'linux';
	return `slang-${SLANG_VERSION}-${os}-${arch}.zip`;
}

async function downloadSlang() {
	const target = join(root, '.tools', 'slang');
	const asset = releaseAssetName();
	const url = `https://github.com/shader-slang/slang/releases/download/v${SLANG_VERSION}/${asset}`;
	console.log(`[build-shaders] downloading ${url}`);
	const response = await fetch(url);
	if (!response.ok) {
		throw new Error(`download failed: ${response.status} ${response.statusText}`);
	}
	mkdirSync(target, { recursive: true });
	const zipPath = join(root, '.tools', asset);
	writeFileSync(zipPath, Buffer.from(await response.arrayBuffer()));
	const unzip = isWindows
		? spawnSync('powershell', ['-NoProfile', '-Command', `Expand-Archive -Force '${zipPath}' '${target}'`], { stdio: 'inherit' })
		: spawnSync('unzip', ['-o', zipPath, '-d', target], { stdio: 'inherit' });
	rmSync(zipPath, { force: true });
	if (unzip.status !== 0) {
		throw new Error('failed to extract slang');
	}
	return join(target, 'bin', exe);
}

async function findSlangc() {
	if (process.env.SLANGC && existsSync(process.env.SLANGC)) {
		return process.env.SLANGC;
	}
	const local = join(root, '.tools', 'slang', 'bin', exe);
	if (existsSync(local)) {
		return local;
	}
	return onPath('slangc') ?? (await downloadSlang());
}

const slangc = await findSlangc();
mkdirSync(outDir, { recursive: true });

let failed = false;
function compile(program, capacity, directory) {
	mkdirSync(directory, { recursive: true });
	const output = join(directory, `${program.name}.wgsl`);
	const args = [join(shaderDir, program.source), '-target', 'wgsl', '-I', shaderDir, '-O2', '-warnings-disable', '41035'];
	for (const define of program.defines ?? []) args.push(`-D${define}`);
	if (capacity !== null) args.push(`-DVEACH_MATERIAL_STACK_SIZE=${capacity}`);
	for (const [entry, stage] of program.entries) {
		args.push('-entry', entry, '-stage', stage);
	}
	args.push('-o', output);

	const result = spawnSync(slangc, args, { encoding: 'utf8' });
	if (result.stdout) process.stdout.write(result.stdout);
	if (result.stderr) process.stderr.write(result.stderr);
	if (result.status !== 0) {
		console.error(`[build-shaders] ${program.name}: slangc failed`);
		failed = true;
		return null;
	}

	const wgsl = readFileSync(output, 'utf8').replaceAll('\r\n', '\n');
	const source = `// Generated from shaders/${program.source} by scripts/build-shaders.mjs. Do not edit.\n${wgsl}`;
	writeFileSync(output, source);
	console.log(`[build-shaders] ${program.name}${capacity === null ? '' : ` stack ${capacity}`}.wgsl (${(wgsl.length / 1024).toFixed(1)} KiB)`);
	return source;
}

const bases = new Map();
for (const program of programs) {
	if (materialStack !== null && !['PathTracing', 'Wavefront'].includes(program.name)) continue;
	bases.set(program.name, compile(program, materialStack, outDir));
}
if (!failed && materialStack === null) {
	const data = {};
	for (const program of programs.filter(p => ['PathTracing', 'Wavefront'].includes(p.name))) {
		const base = bases.get(program.name);
		const variants = {};
		for (const capacity of [1, 2, 4, 8]) {
			const directory = join(root, '.tools/wavefront', `stack-${capacity}`);
			const variant = compile(program, capacity, directory);
			if (variant !== null) variants[capacity] = encodeVariant(base, variant);
		}
		data[program.name] = { length: base.length, checksum: sourceChecksum(base), variants };
	}
	if (!failed) {
		for (const capacity of [1, 2, 4, 8]) writeFileSync(join(root, '.tools/wavefront', `stack-${capacity}`, 'manifest.json'), JSON.stringify({ materialStack: capacity, shaderFingerprint: shaderFingerprint(root) }, null, 2));
		const type = 'export interface MaterialStackVariantData { length: number; checksum: number; variants: Record<number, { sha256: string; edits: [number, string, string][] }> }';
		writeFileSync(join(outDir, 'MaterialStackVariants.ts'), `// Generated by scripts/build-shaders.mjs from independently compiled Slang variants. Do not edit.\n${type}\nexport const materialStackVariants: Record<'PathTracing' | 'Wavefront', MaterialStackVariantData> = ${JSON.stringify(data, null, '\t')};\n`);
	}
}
if (!failed && materialStack !== null) writeFileSync(join(outDir, 'manifest.json'), JSON.stringify({ materialStack, shaderFingerprint: shaderFingerprint(root) }, null, 2));
process.exit(failed ? 1 : 0);
