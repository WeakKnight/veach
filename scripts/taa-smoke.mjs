// One production aim scene: live rigid motion, history use/reset, exposure and off switch.
import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
const out = resolve('.tools/taa'); mkdirSync(out, { recursive: true });
const executablePath = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe'].find(p => p && existsSync(p));
const browser = await puppeteer.launch({ executablePath, headless: true, protocolTimeout: 180000, args: ['--enable-unsafe-webgpu', '--ignore-gpu-blocklist', '--no-sandbox'] });
const errors = [];
try {
	const page = await browser.newPage(); await page.setViewport({ width: 960, height: 640, deviceScaleFactor: 1 });
	page.on('pageerror', e => errors.push(String(e)));
	page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
	await page.goto('http://127.0.0.1:4177/?game=aim');
	await page.waitForFunction(() => window.__games?.ready && window.__games.renderer.taaStats.historyFrames >= 16, { timeout: 180000 });
	await page.click('#start');
	const start = await page.evaluate(() => window.__games.frame);
	await page.waitForFunction(f => window.__games.frame >= f + 12, {}, start);
	await page.keyboard.press('Backquote');
	const snapshot = () => page.evaluate(async () => {
		const g = window.__games, r = g.renderer, taa = r.taa, history = taa.history[taa.ping];
		const output = r.tracer.presentation, buffer = r.device.createBuffer({ size: output.size + history.size, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST });
		const e = r.device.createCommandEncoder(); e.copyBufferToBuffer(output, 0, buffer, 0, output.size); e.copyBufferToBuffer(history, 0, buffer, output.size, history.size);
		r.device.queue.submit([e.finish()]); await buffer.mapAsync(GPUMapMode.READ);
		const mapped = buffer.getMappedRange(), color = new Float32Array(mapped, 0, output.size / 4), data = new Float32Array(mapped, output.size, history.size / 4);
		let reused = 0, totalAge = 0;
		for (let p = 0; p < data.length; p += 12) { if (data[p + 3] > 1.1) reused++; totalAge += data[p + 3]; }
		const target = g.targets()[0], x = Math.floor(target.x / r.canvas.clientWidth * r.tracer.width), y = Math.floor(target.y / r.canvas.clientHeight * r.tracer.height), p = (y * r.tracer.width + x) * 12;
		const result = { stats: r.taaStats, reused, pixels: data.length / 12, meanAge: totalAge / (data.length / 12), targetAge: data[p + 3], targetInstance: data[p + 7], finite: color.every(Number.isFinite), separatePresentation: output !== r.tracer.accumulation, frame: g.frame, elapsed: g.state.elapsed };
		buffer.destroy(); return result;
	});
	const moving = await snapshot();
	assert(moving.stats.active && moving.separatePresentation && moving.finite);
	assert(moving.reused > moving.pixels * 0.25, 'GPU history was not reused');
	assert(moving.targetInstance > 0 && moving.targetAge > 1.1, 'Moving target did not reproject history');
	// A deliberate displacement larger than the depth/position tolerance distinguishes
	// object reprojection from accidentally reusing nearby stationary history.
	const movedAt = await page.evaluate(() => {
		const g = window.__games;
		g.scene.children.find(object => object.userData.slot === 0).position.x += 1.5;
		return g.frame;
	});
	await page.waitForFunction(f => window.__games.frame > f, {}, movedAt);
	const translated = await snapshot();
	assert(translated.targetAge > 8, 'Large rigid motion lost the target history');
	const command = text => page.evaluate(async text => {
		const result = await window.__games.debugConsole.registry.execute(text);
		if (!result.ok) throw new Error(result.lines.join('\n'));
		return result;
	}, text);
	await command('r.Exposure.Bias 1');
	await page.waitForFunction(f => window.__games.frame > f + 2, {}, moving.frame);
	const exposure = await snapshot(); assert(exposure.stats.historyFrames > moving.stats.historyFrames, 'Exposure reset TAA history');
	await command('r.TAA.Enabled 0');
	await page.waitForFunction(() => !window.__games.renderer.taaStats.active);
	assert(await page.evaluate(() => window.__games.renderer.tracer.presentation === window.__games.renderer.tracer.accumulation));
	await command('r.TAA.Enabled 1');
	await page.waitForFunction(() => window.__games.renderer.taaStats.historyFrames >= 12);
	await command('r.TAA.Reset');
	await page.waitForFunction(() => window.__games.renderer.taaStats.historyFrames >= 3);
	const reset = await snapshot(); assert.equal(reset.stats.resetReason, 'explicit');
	await page.keyboard.type('r.TAA.Stats'); await page.keyboard.press('Enter');
	await page.waitForFunction(() => !document.querySelector('[data-veach-console]').shadowRoot.querySelector('input').readOnly);
	await page.screenshot({ path: resolve(out, 'aim-taa.png') });
	assert.deepEqual(errors, [], 'No GPU/browser errors');
	writeFileSync(resolve(out, 'report.json'), JSON.stringify({ moving, translated, exposure, reset }, null, 2));
	console.log(JSON.stringify({ moving, translated, exposure, reset }, null, 2));
} finally { await browser.close(); }
