// One aim scene: GPU motion versus independent Three.js projection, with no timing sweep.
import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
const out = resolve('.tools/motion'); mkdirSync(out, { recursive: true });
const executablePath = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe'].find(p => p && existsSync(p));
const browser = await puppeteer.launch({ executablePath, headless: true, protocolTimeout: 180000, args: ['--enable-unsafe-webgpu', '--ignore-gpu-blocklist', '--no-sandbox'] });
const errors = [];
try {
	const page = await browser.newPage(); await page.setViewport({ width: 960, height: 640, deviceScaleFactor: 1 });
	page.on('pageerror', e => errors.push(String(e)));
	page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
	await page.goto('http://127.0.0.1:4177/?game=aim');
	await page.waitForFunction(() => window.__games?.ready && window.__games.renderer.taaStats.historyFrames >= 8, { timeout: 180000 });
	await page.keyboard.press('Backquote');
	const report = await page.evaluate(async () => {
		const g = window.__games, r = g.renderer, taa = r.taa;
		let report;
		// The game's executor holds its normal loop while this deterministic sequence runs.
		g.debugConsole.registry.register({ name: 'r.Test.Motion', help: 'Focused motion check', run: async () => {
			let frame = g.frame;
			const draw = async () => {
				await g.adapter.sync(g.scene, g.camera);
				r.renderFrame({ scene: g.adapter.scene, view: g.adapter.view(g.camera), frameIndex: frame++ });
				const motion = r.motionVectorBuffer, history = taa.history[taa.ping], output = r.tracer.presentation;
				const b = r.device.createBuffer({ size: motion.size + history.size + output.size, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST });
				const e = r.device.createCommandEncoder();
				e.copyBufferToBuffer(motion, 0, b, 0, motion.size);
				e.copyBufferToBuffer(history, 0, b, motion.size, history.size);
				e.copyBufferToBuffer(output, 0, b, motion.size + history.size, output.size);
				r.device.queue.submit([e.finish()]); await b.mapAsync(GPUMapMode.READ);
				const data = b.getMappedRange();
				const result = { motion: new Float32Array(data.slice(0, motion.size)), history: new Float32Array(data.slice(motion.size, motion.size + history.size)), output: new Float32Array(data.slice(motion.size + history.size)), frames: r.taaStats.historyFrames };
				b.destroy(); return result;
			};
			const width = r.tracer.width, height = r.tracer.height;
			const maxMotion = data => { let max = 0; for (let i = 0; i < data.length; i += 8) if (data[i + 3]) max = Math.max(max, Math.hypot(data[i], data[i + 1])); return max; };
			const stationary = await draw(), stationary2 = await draw();
			const target = g.scene.children.find(o => o.userData.slot === 0);
			const oldObject = target.matrixWorld.clone(), oldCamera = g.camera.clone();
			target.position.x += 0.8; target.rotation.y += 0.2; target.scale.y *= 1.1;
			const moved = await draw();
			const projected = target.position.clone().project(g.camera);
			const px = Math.floor((projected.x + 1) * width / 2), py = Math.floor((1 - projected.y) * height / 2), p = py * width + px;
			const point = target.position.clone().fromArray(moved.history, p * 12 + 4);
			point.applyMatrix4(target.matrixWorld.clone().invert()).applyMatrix4(oldObject).project(oldCamera);
			const expected = [(point.x + 1) * width / 2 - (px + taa.jitter[0]), (1 - point.y) * height / 2 - (py + taa.jitter[1])];
			const actual = Array.from(moved.motion.slice(p * 8, p * 8 + 2));
			const cameraBefore = g.camera.clone();
			g.camera.position.x += 0.3; g.camera.rotation.y += 0.03;
			g.camera.setViewOffset(960, 640, 13, -7, 960, 640);
			const camera = await draw(), matrix = cameraBefore.projectionMatrix.clone().multiply(cameraBefore.matrixWorldInverse).elements;
			let maxCameraError = 0, checked = 0, skyChecked = 0;
			for (let y = 3; y < height; y += 7) for (let x = 3; x < width; x += 7) {
				const i = y * width + x; if (!camera.motion[i * 8 + 3]) continue;
				const h = i * 12, w = camera.history[h + 7] ? 1 : 0, xyz = camera.history.subarray(h + 4, h + 7);
				const q = [0, 1, 3].map(row => matrix[row] * xyz[0] + matrix[4 + row] * xyz[1] + matrix[8 + row] * xyz[2] + matrix[12 + row] * w);
				const mx = (q[0] / q[2] + 1) * width / 2 - (x + taa.jitter[0]), my = (1 - q[1] / q[2]) * height / 2 - (y + taa.jitter[1]);
				maxCameraError = Math.max(maxCameraError, Math.abs(mx - camera.motion[i * 8]), Math.abs(my - camera.motion[i * 8 + 1]));
				checked++; if (!w) skyChecked++;
			}
			r.settings.taaMotionVectorDebug = true;
			const debug = await draw();
			let debugError = 0;
			for (let i = 0; i < width * height; i++) {
				const m = i * 8, o = i * 12, expected = debug.motion[m + 3] ? [Math.max(0, Math.min(1, 0.5 + debug.motion[m] / 64)), Math.max(0, Math.min(1, 0.5 + debug.motion[m + 1] / 64)), 0.5] : [1, 0, 1];
				for (let c = 0; c < 3; c++) debugError = Math.max(debugError, Math.abs(expected[c] - debug.output[o + c]));
			}
			r.settings.taaMotionVectorDebug = false;
			const restored = await draw();
			report = { stationaryMaxPixels: Math.max(maxMotion(stationary.motion), maxMotion(stationary2.motion)), rigid: { actual, expected, valid: moved.motion[p * 8 + 3], instance: moved.history[p * 12 + 7] }, camera: { maxErrorPixels: maxCameraError, checked, skyChecked }, debugError, frames: [stationary.frames, stationary2.frames, moved.frames, camera.frames, debug.frames, restored.frames], finite: [stationary, moved, camera, debug, restored].every(s => s.motion.every(Number.isFinite) && s.output.every(Number.isFinite)) };
			return 'complete';
		} });
		const result = await g.debugConsole.registry.execute('r.Test.Motion');
		if (!result.ok) throw new Error(result.lines.join('\n'));
		return report;
	});
	assert(report.finite);
	assert(report.stationaryMaxPixels < 0.002, 'Jitter produced false motion');
	assert(report.rigid.valid && report.rigid.instance > 0);
	assert(Math.abs(report.rigid.actual[0]) > 1, 'Rigid test must produce significant motion');
	assert(report.rigid.actual.every((v, i) => Math.abs(v - report.rigid.expected[i]) < 0.002), 'Rigid motion differs from Three.js projection');
	assert(report.camera.checked > 100 && report.camera.skyChecked > 0 && report.camera.maxErrorPixels < 0.002, 'Camera/sky/off-axis projection mismatch');
	assert(report.debugError < 1e-6);
	assert(report.frames.every((n, i, a) => !i || n === a[i - 1] + 1), 'Motion/debug reset TAA');
	await page.evaluate(async () => {
		const g = window.__games;
		await g.debugConsole.registry.execute('r.TAA.MotionVectors 1');
		// Keep rendering motion for the capture; the console has paused game animation.
		const original = g.renderer.renderFrame.bind(g.renderer);
		g.renderer.renderFrame = frame => { original(frame); g.camera.rotation.y += 0.003; };
	});
	const at = await page.evaluate(() => window.__games.frame);
	await page.waitForFunction(f => window.__games.frame > f + 3, {}, at);
	await page.screenshot({ path: resolve(out, 'motion.png') });
	assert.deepEqual(errors, [], 'GPU/browser errors');
	writeFileSync(resolve(out, 'report.json'), JSON.stringify(report, null, 2)); console.log(JSON.stringify(report, null, 2));
} finally { await browser.close(); }
