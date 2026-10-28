import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer-core';
import { createServer } from 'vite';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..'), out = resolve(root, '.tools/games-smoke');
mkdirSync(out, { recursive: true });
const executablePath = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe', 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', '/usr/bin/google-chrome'].find(p => p && existsSync(p));
assert(executablePath, 'Set CHROME_PATH to a WebGPU browser');
const server = await createServer({ configFile: resolve(root, 'examples/games/vite.config.ts'), server: { port: 5176, strictPort: true } });
await server.listen();
const browser = await puppeteer.launch({ executablePath, headless: true, args: ['--enable-unsafe-webgpu', '--enable-features=Vulkan', '--ignore-gpu-blocklist', '--no-sandbox'] });
const errors = [], report = {};
try {
	const validation = await browser.newPage();
	validation.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });
	validation.on('pageerror', error => errors.push(String(error)));
	await validation.goto('http://127.0.0.1:5176/validation.html');
	await validation.waitForFunction(() => window.__validation?.done, { timeout: 180000 });
	report.validation = await validation.evaluate(() => window.__validation);
	assert(!report.validation.error, report.validation.error);
	await validation.close();
	for (const mode of ['aim', 'race']) {
		const page = await browser.newPage(); await page.setViewport({ width: 1280, height: 800, deviceScaleFactor: 1 });
		page.on('pageerror', e => { errors.push(String(e)); console.error(mode, String(e)); });
		page.on('console', msg => { if (msg.type() === 'error') { errors.push(msg.text()); console.error(mode, msg.text()); } });
		await page.goto(`http://127.0.0.1:5176/?game=${mode}`, { waitUntil: 'networkidle0', timeout: 120000 });
		await page.waitForFunction(() => window.__games?.ready && window.__games.frame > 5, { timeout: 180000 });
		await page.screenshot({ path: resolve(out, `${mode}-ready.png`) });
		await page.click('#start');
		await page.waitForFunction(() => window.__games.state.playing && window.__games.state.elapsed > 0.5);
		if (mode === 'aim') {
			const target = await page.evaluate(() => window.__games.targets()[4]);
			await page.mouse.click(target.x, target.y);
			await page.waitForFunction(() => window.__games.state.hits === 1);
			await page.waitForFunction(() => window.__games.state.elapsed > 1.5);
			const stats = await page.evaluate(() => window.__games.stats);
			assert.equal(stats.gpu.blasBuilds, 0, 'Moving targets reuse BLAS');
			assert.equal(stats.gpu.uploadedBytes.vertices, 0, 'No static vertex upload');
			await page.mouse.click(640, 700);
			assert.equal(await page.evaluate(() => window.__games.state.shots), 2);
		} else {
			const before = await page.evaluate(() => window.__games.state.position);
			await page.keyboard.down('KeyW');
			await page.waitForFunction(() => window.__games.state.speed > 7);
			await page.keyboard.down('KeyA');
			await page.waitForFunction(() => window.__games.state.elapsed > 2);
			await page.keyboard.up('KeyA'); await page.keyboard.up('KeyW');
			const state = await page.evaluate(() => window.__games.state);
			assert(Math.hypot(state.position[0] - before[0], state.position[2] - before[2]) > 2);
			assert.equal((await page.evaluate(() => window.__games.stats)).gpu.blasBuilds, 0);
		}
		if (mode === 'race') {
			await page.keyboard.press('KeyR');
			await page.evaluate(() => {
				const down = new Set();
				const key = (code, value) => { if (down.has(code) === value) return; value ? down.add(code) : down.delete(code); window.dispatchEvent(new KeyboardEvent(value ? 'keydown' : 'keyup', { code })); };
				const drive = () => {
					const g = window.__games, s = g.state;
					if (s.finished) { for (const code of [...down]) key(code, false); return; }
					const a = Math.atan2(s.position[2], s.position[0]) + 0.32;
					const desired = Math.atan2(Math.cos(a) * 18 - s.position[0], Math.sin(a) * 18 - s.position[2]);
					const error = Math.atan2(Math.sin(desired - g.car.rotation.y), Math.cos(desired - g.car.rotation.y));
					key('KeyA', error > 0.025); key('KeyD', error < -0.025); key('KeyW', s.speed < 12); key('KeyS', s.speed > 14);
					requestAnimationFrame(drive);
				}; drive();
			});
			await page.waitForFunction(() => window.__games.state.checkpoint >= 1, { timeout: 30000 });
		}
		await page.screenshot({ path: resolve(out, `${mode}-playing.png`) });
		if (mode === 'race') {
			await page.waitForFunction(() => window.__games.state.finished, { timeout: 90000 });
			assert.equal(await page.evaluate(() => window.__games.state.laps), 3, 'Actual controls complete three laps');
			await page.screenshot({ path: resolve(out, `${mode}-finished.png`) });
			report.raceFinished = await page.evaluate(() => window.__games.state);
			await page.click('#start');
		}
		if (mode === 'aim') {
			await page.waitForFunction(() => window.__games.state.finished, { timeout: 60000 });
			assert.equal(await page.evaluate(() => window.__games.state.hits), 1);
			await page.screenshot({ path: resolve(out, `${mode}-finished.png`) });
			report.aimFinished = await page.evaluate(() => window.__games.state);
			await page.click('#start');
		}
		await page.click('#pause'); const stopped = await page.evaluate(() => window.__games.state.elapsed);
		const frame = await page.evaluate(() => window.__games.frame);
		await page.waitForFunction(f => window.__games.frame >= f + 3, {}, frame);
		assert.equal(await page.evaluate(() => window.__games.state.elapsed), stopped, 'Pause stops simulation');
		await page.click('#reset'); assert.equal(await page.evaluate(() => window.__games.state.finished), false);
		report[mode] = await page.evaluate(() => ({ state: window.__games.state, stats: window.__games.stats, frames: window.__games.frame }));
		await page.close();
	}
	assert.deepEqual(errors, [], 'No WebGPU, shader or browser errors');
	writeFileSync(resolve(out, 'report.json'), JSON.stringify(report, null, 2));
	console.log(JSON.stringify(report, null, 2));
	console.log(`Game smoke passed. Screenshots: ${out}`);
} finally { await browser.close(); await server.close(); }
