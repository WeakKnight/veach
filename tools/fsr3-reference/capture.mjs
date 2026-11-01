// Captures FSR 3 inputs, dispatch descriptions and Veach's WebGPU outputs from a live realtime session, for the
// native FidelityFX reference (tools/fsr3-reference/README.md). Needs the dev server (npm run dev, port 5173).
// Usage: node tools/fsr3-reference/capture.mjs [out-dir] [frames] [query]
import puppeteer from 'puppeteer-core';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const out = process.argv[2] ?? '.tools/fsr3-capture';
const frames = Number(process.argv[3] ?? 24);
const query = process.argv[4] ?? 'model=/samples/DamagedHelmet.glb&mode=realtime';
const chrome = process.env.CHROME ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe';
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });

const browser = await puppeteer.launch({ executablePath: chrome, headless: true, protocolTimeout: 900000,
	args: ['--enable-unsafe-webgpu', '--enable-features=Vulkan', '--ignore-gpu-blocklist', '--no-sandbox'] });
try {
	const page = await browser.newPage();
	const errors = [];
	page.on('pageerror', e => errors.push(String(e)));
	page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
	await page.exposeFunction('saveCapture', (name, base64) => writeFileSync(join(out, name), Buffer.from(base64, 'base64')));
	await page.setViewport({ width: 640, height: 400, deviceScaleFactor: 1 });
	await page.goto(`http://localhost:5173/?${query}`);
	await page.waitForFunction(() => globalThis.veach?.fsrStats?.frames > 30, { timeout: 600000, polling: 500 });
	const meta = await page.evaluate(async count => {
		const veach = globalThis.veach, fsr = veach.fsr, device = veach.device;
		const toBase64 = bytes => { let s = ''; for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000)); return btoa(s); };
		// Tightly packed rows of a texture copy (bytesPerRow aligned to 256).
		const readback = (encoder, texture, bpp) => {
			const row = Math.ceil(texture.width * bpp / 256) * 256;
			const buffer = device.createBuffer({ size: row * texture.height, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
			encoder.copyTextureToBuffer({ texture }, { buffer, bytesPerRow: row }, [texture.width, texture.height]);
			return async () => {
				await buffer.mapAsync(GPUMapMode.READ);
				const mapped = new Uint8Array(buffer.getMappedRange()), packed = new Uint8Array(texture.width * bpp * texture.height);
				for (let y = 0; y < texture.height; y++) packed.set(mapped.subarray(y * row, y * row + texture.width * bpp), y * texture.width * bpp);
				buffer.destroy();
				return packed;
			};
		};
		const frames = [], pending = [];
		// A fresh FidelityFX context with a history reset, like a new native context, then a slow orbit.
		fsr.restart();
		veach.resetTaa();
		const camera = veach.camera, target = camera.target, start = [...camera.position];
		const radius = Math.hypot(start[0] - target[0], start[2] - target[2]), angle0 = Math.atan2(start[0] - target[0], start[2] - target[2]);
		let index = 0;
		await new Promise(resolve => {
			fsr.capture = (encoder, textures, dispatch) => {
				const i = index++;
				if (i >= count) return;
				const reads = [readback(encoder, textures.color, 8), readback(encoder, textures.depth, 4), readback(encoder, textures.motion, 8), readback(encoder, textures.output, 8)];
				frames.push({ ...dispatch, renderSize: [...dispatch.renderSize], upscaleSize: [...dispatch.upscaleSize], jitter: [...dispatch.jitter] });
				// The frame's encoder is submitted before this timeout runs.
				pending.push(new Promise(done => setTimeout(async () => {
					await device.queue.onSubmittedWorkDone();
					const [color, depth, motion, output] = await Promise.all(reads.map(read => read()));
					const name = `frame${String(i).padStart(3, '0')}`;
					await Promise.all([saveCapture(`${name}.color.bin`, toBase64(color)), saveCapture(`${name}.depth.bin`, toBase64(depth)),
						saveCapture(`${name}.motion.bin`, toBase64(motion)), saveCapture(`${name}.webgpu.bin`, toBase64(output))]);
					done();
				}, 0)));
				const a = angle0 + (i + 1) * 0.01;
				camera.position = [target[0] + radius * Math.sin(a), start[1], target[2] + radius * Math.cos(a)];
				if (i + 1 === count) { fsr.capture = null; resolve(); }
			};
		});
		await Promise.all(pending);
		camera.position = start;
		return frames;
	}, frames);
	// One line per frame for the native reader: render w h, upscale w h, jitter x y, reset, frame time delta (ms),
	// pre-exposure, near, far, vertical FOV (radians), view-space-to-meters, sharpness.
	writeFileSync(join(out, 'frames.txt'), meta.map(f => [...f.renderSize, ...f.upscaleSize, ...f.jitter, Number(f.reset), f.frameTimeDelta, f.preExposure,
		f.cameraNear, f.cameraFar, f.cameraFovAngleVertical, f.viewSpaceToMetersFactor, f.sharpness].map(v => Number.isInteger(v) ? v : v.toPrecision(9)).join(' ')).join('\n') + '\n');
	writeFileSync(join(out, 'frames.json'), JSON.stringify(meta, null, 1));
	console.log(`[fsr3-capture] ${meta.length} frames, render ${meta[0].renderSize.join('x')} -> ${meta[0].upscaleSize.join('x')}, errors ${JSON.stringify(errors)} -> ${out}`);
} finally { await browser.close(); }
