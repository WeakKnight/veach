// Compares Veach's WebGPU FSR 3 outputs with the native FidelityFX runtime's for the same captured inputs
// (tools/fsr3-reference/README.md). Usage: node tools/fsr3-reference/compare.mjs [capture-dir]
// Prints per-frame PSNR of the tone-mapped image (x / (1 + x) of pre-exposed radiance), the mean and 99th percentile
// relative error, and writes worst.png (native | WebGPU | 8x difference) for the frame with the lowest PSNR.
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { deflateSync } from 'node:zlib';

const dir = process.argv[2] ?? '.tools/fsr3-capture';
const frames = JSON.parse(readFileSync(join(dir, 'frames.json'), 'utf8'));
const half = new Float32Array(65536);
for (let h = 0; h < 65536; h++) {
	const s = h & 0x8000 ? -1 : 1, e = (h >> 10) & 0x1f, m = h & 0x3ff;
	half[h] = e === 0 ? s * m * 2 ** -24 : e === 31 ? (m ? NaN : s * Infinity) : s * (1 + m / 1024) * 2 ** (e - 15);
}
const decode = file => { const u = new Uint16Array(readFileSync(file).buffer.slice(0)); const f = new Float32Array(u.length); for (let i = 0; i < u.length; i++) f[i] = half[u[i]]; return f; };
const tone = v => v > 0 ? v / (1 + v) : 0;

let worst = null;
const rows = [];
for (let i = 0; i < frames.length; i++) {
	const name = `frame${String(i).padStart(3, '0')}`;
	if (!readdirSync(dir).includes(`${name}.native.bin`)) break;
	const a = decode(join(dir, `${name}.native.bin`)), b = decode(join(dir, `${name}.webgpu.bin`));
	const [w, h] = frames[i].upscaleSize;
	let mse = 0; const rel = [];
	for (let p = 0; p < w * h; p++) {
		for (let c = 0; c < 3; c++) { const d = tone(a[p * 4 + c]) - tone(b[p * 4 + c]); mse += d * d; }
		const la = 0.2126 * a[p * 4] + 0.7152 * a[p * 4 + 1] + 0.0722 * a[p * 4 + 2], lb = 0.2126 * b[p * 4] + 0.7152 * b[p * 4 + 1] + 0.0722 * b[p * 4 + 2];
		rel.push(Math.abs(la - lb) / (Math.abs(la) + 0.01));
	}
	mse /= w * h * 3;
	rel.sort((x, y) => x - y);
	const psnr = 10 * Math.log10(1 / Math.max(mse, 1e-20));
	const row = { frame: i, reset: frames[i].reset, psnr: +psnr.toFixed(2), meanRel: +(rel.reduce((s, v) => s + v, 0) / rel.length).toFixed(5), p99Rel: +rel[Math.floor(rel.length * 0.99)].toFixed(4), maxRel: +rel[rel.length - 1].toFixed(3) };
	rows.push(row);
	if (!worst || psnr < worst.psnr) worst = { psnr, a, b, w, h, frame: i };
}
console.table(rows);
const psnrs = rows.map(r => r.psnr);
console.log(`[fsr3-compare] ${rows.length} frames: PSNR min ${Math.min(...psnrs).toFixed(2)} dB, mean ${(psnrs.reduce((s, v) => s + v, 0) / psnrs.length).toFixed(2)} dB`);

// worst.png: native | WebGPU | |difference| x8, tone mapped, sRGB-ish gamma.
if (worst) {
	const { a, b, w, h } = worst, W = w * 3, png = Buffer.alloc((W * 3 + 1) * h);
	const enc = v => Math.max(0, Math.min(255, Math.round(255 * Math.pow(Math.max(0, Math.min(1, v)), 1 / 2.2))));
	for (let y = 0; y < h; y++) {
		png[y * (W * 3 + 1)] = 0;
		for (let x = 0; x < w; x++) for (let c = 0; c < 3; c++) {
			const p = (y * w + x) * 4 + c, ta = tone(a[p]), tb = tone(b[p]), row = y * (W * 3 + 1) + 1;
			png[row + x * 3 + c] = enc(ta); png[row + (w + x) * 3 + c] = enc(tb); png[row + (2 * w + x) * 3 + c] = enc(Math.abs(ta - tb) * 8);
		}
	}
	const crc = buf => { let c = ~0; for (const byte of buf) { c ^= byte; for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1)); } return ~c >>> 0; };
	const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([len, td, c]); };
	const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2;
	writeFileSync(join(dir, 'worst.png'), Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk('IHDR', ihdr), chunk('IDAT', deflateSync(png)), chunk('IEND', Buffer.alloc(0))]));
	console.log(`[fsr3-compare] worst frame ${worst.frame} -> ${join(dir, 'worst.png')} (native | WebGPU | difference x8)`);
}
