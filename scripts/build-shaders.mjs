// Compiles the Slang sources under shaders/ to WGSL under src/generated/shaders.
// slangc is taken from $SLANGC, .tools/slang, or PATH; if none is found, the pinned release is
// downloaded into .tools/slang.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SLANG_VERSION = '2026.20';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const shaderDir = join(root, 'shaders');
const outDir = join(root, 'src', 'generated', 'shaders');
const isWindows = process.platform === 'win32';
const exe = isWindows ? 'slangc.exe' : 'slangc';

// Each program becomes one WGSL module containing all of its entry points.
const programs = [
	{ name: 'PathTracing', source: 'Passes/PathTracing.slang', entries: [['main', 'compute']] },
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
for (const program of programs) {
	const output = join(outDir, `${program.name}.wgsl`);
	const args = [join(shaderDir, program.source), '-target', 'wgsl', '-I', shaderDir, '-O2', '-warnings-disable', '41035'];
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
		continue;
	}

	const wgsl = readFileSync(output, 'utf8');
	writeFileSync(output, `// Generated from shaders/${program.source} by scripts/build-shaders.mjs. Do not edit.\n${wgsl}`);
	console.log(`[build-shaders] ${program.name}.wgsl (${(wgsl.length / 1024).toFixed(1)} KiB)`);
}

process.exit(failed ? 1 : 0);
