// Focused regression: real target hits, debris removal and respawn must not reset TAA.
import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
const out = resolve('.tools/taa'); mkdirSync(out, { recursive: true });
const browser = await puppeteer.launch({ executablePath: process.env.CHROME_PATH ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, protocolTimeout: 180000, args: ['--enable-unsafe-webgpu', '--ignore-gpu-blocklist', '--no-sandbox'] });
const errors = [];
try {
	const page = await browser.newPage(); await page.setViewport({ width: 960, height: 640 });
	page.on('pageerror', e => errors.push(String(e)));
	page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
	await page.goto('http://127.0.0.1:4177/?game=aim');
	await page.waitForFunction(() => window.__games?.renderer.taaStats.historyFrames >= 16, { timeout: 180000 });
	await page.evaluate(() => {
		const r = window.__games.renderer, render = r.renderFrame.bind(r);
		window.taaHitHistory = [];
		r.renderFrame = (...args) => { render(...args); window.taaHitHistory.push({ frames: r.taaStats.historyFrames, reason: r.taaStats.resetReason, instances: r.taa.instances.size }); };
	});
	await page.click('#start');
	for (let hit = 1; hit <= 3; hit++) {
		const p = await page.evaluate(() => window.__games.targets()[0]);
		await page.mouse.click(p.x, p.y);
		await page.waitForFunction(n => window.__games.state.hits === n && window.__games.targets().length === 6, { timeout: 30000 }, hit);
	}
	await page.click('#pause');
	const report = await page.evaluate(() => ({ state: window.__games.state, stats: window.__games.renderer.taaStats, history: window.taaHitHistory }));
	assert.equal(report.state.hits, 3);
	assert(report.history.length > 10);
	assert(report.history.every((v, i, a) => !i || v.frames === a[i - 1].frames + 1), 'Target hit/respawn reset TAA');
	assert.deepEqual(errors, []);
	await page.screenshot({ path: resolve(out, 'hits-no-reset.png') });
	writeFileSync(resolve(out, 'hits-no-reset.json'), JSON.stringify(report, null, 2));
	console.log(JSON.stringify({ hits: report.state.hits, framesChecked: report.history.length, first: report.history[0], last: report.history.at(-1), stats: report.stats }, null, 2));
} finally { await browser.close(); }
