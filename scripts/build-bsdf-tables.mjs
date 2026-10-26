// Packs the BSDF energy tables and the sheen LTC fit (ThirdParty/openpbr-bsdf/impl/data) into
// src/generated/bsdf/BSDFTables.bin: a 32x32x72 r32float volume, x fastest, in the slice layout of
// shaders/Materials/BSDF/EnergyTables.slang. Energy entries stay raw 16-bit unorm integers.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dataDir = join(root, 'ThirdParty', 'openpbr-bsdf', 'impl', 'data');
const outFile = join(root, 'src', 'generated', 'bsdf', 'BSDFTables.bin');

const N = 32;
const SLICES = 72;
const SLICE = N * N;

function readNumbers(name) {
	const text = readFileSync(join(dataDir, name), 'utf8').replace(/\/\/.*$/gm, '');
	return text.match(/-?\d+(\.\d+)?(e-?\d+)?/gi).map(Number);
}

function readUnorm(name, expected) {
	const values = readNumbers(name);
	if (values.length !== expected || values.some((v) => !Number.isInteger(v) || v < 0 || v > 65535)) {
		throw new Error(`${name}: expected ${expected} unorm16 values, got ${values.length}`);
	}
	return values;
}

function readLTC() {
	const text = readFileSync(join(dataDir, 'openpbr_ltc_data.h'), 'utf8');
	const entries = [...text.matchAll(/vec3\(\s*([^,]+),\s*([^,]+),\s*([^)]+)\)/g)].map((m) => [m[1], m[2], m[3]].map(Number));
	if (entries.length !== SLICE || entries.some((e) => e.some((v) => !Number.isFinite(v)))) {
		throw new Error(`openpbr_ltc_data.h: expected ${SLICE} vec3 entries, got ${entries.length}`);
	}
	return entries;
}

const tables = new Float32Array(SLICE * SLICES);

// 3D [x][y][z] -> slice firstSlice + x, row y, texel z; 2D [x][y] -> row x, texel y.
function put3D(firstSlice, values) {
	tables.set(values, firstSlice * SLICE);
}
function put2D(slice, values) {
	tables.set(values, slice * SLICE);
}

put3D(0, readUnorm('openpbr_ideal_dielectric_energy_complement_data.h', N * N * N));
put3D(32, readUnorm('openpbr_opaque_dielectric_energy_complement_data.h', N * N * N));
put2D(64, readUnorm('openpbr_ideal_dielectric_avg_energy_complement_data.h', N * N));
put2D(65, readUnorm('openpbr_ideal_dielectric_reflection_ratio_data.h', N * N));
put2D(66, readUnorm('openpbr_opaque_dielectric_avg_energy_complement_data.h', N * N));
put2D(67, readUnorm('openpbr_ideal_metal_energy_complement_data.h', N * N));
put2D(68, readUnorm('openpbr_ideal_metal_avg_energy_complement_data.h', N));

// LTC [alpha row][cos column], one slice per coefficient.
readLTC().forEach((coefficients, index) => {
	coefficients.forEach((value, c) => {
		tables[(69 + c) * SLICE + index] = value;
	});
});

mkdirSync(dirname(outFile), { recursive: true });
writeFileSync(outFile, new Uint8Array(tables.buffer));
console.log(`[build-bsdf-tables] wrote ${outFile} (${tables.byteLength} bytes)`);
