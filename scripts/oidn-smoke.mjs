import './fetch-oidn-weights.mjs';
import assert from 'node:assert/strict';
import { resolve } from 'node:path';
import { createServer } from 'vite';
import puppeteer from 'puppeteer-core';

const server = await createServer({ root: resolve('.'), logLevel: 'warn', server: { port: 5209 },
	plugins: [{ name: 'oidn-test-page', configureServer(s) { s.middlewares.use('/__oidn-smoke', (_req, res) => { res.setHeader('Content-Type', 'text/html'); res.end('<!doctype html><head><link rel="icon" href="data:,"></head><body></body>'); }); } }] });
await server.listen();
const browser = await puppeteer.launch({ executablePath: process.env.CHROME_PATH ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true,
	args: ['--enable-unsafe-webgpu', '--enable-features=Vulkan', '--ignore-gpu-blocklist', '--no-sandbox'] });
try {
	const page = await browser.newPage(); page.setDefaultTimeout(180000);
	const errors = [];
	page.on('pageerror', e => errors.push(String(e)));
	page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
	await page.goto(server.resolvedUrls.local[0] + '__oidn-smoke');
	const result = await page.evaluate(async () => {
		const api = await import('/src/index.ts');
		const check = (ok, message) => { if (!ok) throw new Error(message); };
		const canvas = document.createElement('canvas'); canvas.style.cssText = 'width:64px;height:48px'; document.body.append(canvas);
		const r = await api.Renderer.create(canvas, { denoiser: null });
		Object.assign(r.settings, { maxSamples: 1, autoExposureMethod: api.AutoExposureMethod.Manual, autoExposureBias: 0 });
		r.renderFrame(); await r.device.queue.onSubmittedWorkDone();
		// Synthetic noisy, constant-light surface with an albedo edge, plus special guide pixels.
		const module = r.device.createShaderModule({ code: `@group(0) @binding(0) var<storage,read_write> a:array<vec4f>;
@compute @workgroup_size(64) fn main(@builtin(global_invocation_id) t:vec3u){let i=t.x;if(i>=3072u){return;}let x=i%64u;let y=i/64u;
let v=select(0.25,0.75,x>=32u);let noise=select(-0.16,0.16,((x+y)%2u)==0u);
a[i*3u]=vec4f(vec3f(v+noise),1);a[i*3u+1u]=vec4f(vec3f(v),1);a[i*3u+2u]=vec4f(0,0,1,1);
if(i==0u){a[1]=vec4f(-1,2,0.4,1);a[2]=vec4f(0,0,0,1);}
if(i==1u){a[5]=vec4f(-0.5,0.25,0.5,1);}}` });
		const pipeline = await r.device.createComputePipelineAsync({ layout: 'auto', compute: { module, entryPoint: 'main' } });
		const bind = r.device.createBindGroup({ layout: pipeline.getBindGroupLayout(0), entries: [{ binding: 0, resource: { buffer: r.tracer.accumulation } }] });
		const encoder = r.device.createCommandEncoder(); const pass = encoder.beginComputePass(); pass.setPipeline(pipeline); pass.setBindGroup(0, bind); pass.dispatchWorkgroups(48); pass.end(); r.device.queue.submit([encoder.finish()]);
		async function read(buffer) {
			const staging = r.device.createBuffer({ size: buffer.size, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
			const e = r.device.createCommandEncoder(); e.copyBufferToBuffer(buffer, 0, staging, 0, buffer.size); r.device.queue.submit([e.finish()]);
			await staging.mapAsync(GPUMapMode.READ); const values = new Float32Array(staging.getMappedRange()).slice(); staging.unmap(); staging.destroy(); return values;
		}
		const guides = r.createDenoisingInputs();
		const alb = await read(guides.albedo), nrm = await read(guides.normal);
		check(alb[0]===0 && alb[1]===1 && Math.abs(alb[2]-.4)<1e-6, 'albedo guide range');
		check(nrm[0]===.5 && nrm[1]===.5 && nrm[2]===.5, 'background normal encoding');
		check(nrm[4]===.25 && nrm[5]===.625 && nrm[6]===.75, 'averaged normal was renormalized or misencoded');
		guides.destroy();
		const raw = await r.readRadiance();
		check(r.denoising.status==='disabled', 'Explicit null should disable OIDN');
		const options = { type: 'oidn', weights: '/samples/oidn/rt_hdr_alb_nrm.tza', maxTileSize: 256 };
		await r.setDenoiser(options);
		async function settle() {
			const deadline = performance.now()+150000;
			while(r.denoising.status!=='ready') {
				r.renderFrame();
				check(r.denoising.status!=='error',r.denoising.error);
				check(performance.now()<deadline, 'OIDN timeout: '+JSON.stringify(r.denoising));
				await new Promise(resolve=>setTimeout(resolve,16));
			}
		}
		await settle();
		const state = r.denoising, output = await r.readRadiance({ denoised: true }), rawAfter = await r.readRadiance();
		check(r.samples===1 && rawAfter.data.every((v,i)=>v===raw.data[i]), 'denoising changed accumulation');
		check(output.data.every(v=>Number.isFinite(v)&&v>=0), 'invalid HDR output');
		let noisyError=0, denoisedError=0;
		for(let y=8;y<40;y++)for(let x=8;x<56;x++){if(Math.abs(x-32)<5)continue;const i=(y*64+x)*3;const target=x<32?.25:.75;noisyError+=(raw.data[i]-target)**2;denoisedError+=(output.data[i]-target)**2;}
		check(denoisedError<noisyError*.6, `Denoising did not reduce noise: ${denoisedError}/${noisyError}`);
		for(let i=0;i<5;i++) r.renderFrame(); check(r.denoising===state, 'repeated inference at maxSamples');
		await r.setDisplayTransform({type:'builtin',preset:'astia'}); r.settings.autoExposureBias=1; r.renderFrame();
		check(r.denoising===state && r.samples===1, 'presentation settings invalidated denoising');
		let rejected=false; try { await r.setDenoiser({ ...options, maxTileSize: 3 }); } catch { rejected=true; }
		check(rejected && r.denoising===state, 'invalid options replaced working denoiser');
		// A later accumulation cannot accept an older in-flight result.
		r.resetAccumulation(); r.renderFrame(); r.streamingPending=false; r.maybeDenoise();
		check(r.denoising.status==='denoising', 'reset did not allow another execution');
		r.resetAccumulation(); canvas.style.cssText='width:63px;height:47px'; r.resize(); r.settings.maxSamples=0;
		while(r.denoiseJob) await new Promise(resolve=>setTimeout(resolve,16));
		check(r.denoising.status==='idle' && !r.denoisedBuffer, 'stale result survived reset');
		r.renderFrame(); check(r.denoising.status==='idle', 'unlimited sampling triggered OIDN');
		await r.setDenoiser(null); check(r.denoising.status==='disabled', 'disable failed');
		rejected=false; try { await r.setDenoiser({type:'oidn',weights:new ArrayBuffer(3)}); } catch { rejected=true; }
		check(rejected && r.denoising.status==='error' && !r.denoisedBuffer, 'bad weights did not fall back to raw image');
		const old=r.setDenoiser(options); const clear=r.setDenoiser(null); check(!(await old)&&(await clear), 'latest model request did not win');
		await r.setDenoiser(options); r.settings.maxSamples=r.samples; r.streamingPending=false; r.maybeDenoise(); r.destroy();
		await new Promise(resolve=>setTimeout(resolve,100));
		// No options: built-in model and the 128-sample limit must work together.
		const defaults = await api.Renderer.create(canvas);
		check(defaults.settings.maxSamples===128, 'Default sample limit');
		defaults.start();
		const deadline=performance.now()+150000;
		while(defaults.denoising.status!=='ready') {
			check(defaults.denoising.status!=='error', defaults.denoising.error);
			check(performance.now()<deadline,'Default denoising timed out');
			await new Promise(resolve=>setTimeout(resolve,16));
		}
		check(defaults.samples===128,'Default convergence count'); defaults.destroy();
		return { guides:'passed', lifecycle:'passed', noiseRatio:denoisedError/noisyError, durationMs:state.durationMs, samplesPreserved:1 };
	});
	assert.deepEqual(errors, []); console.log(JSON.stringify(result));
} finally { await browser.close(); await server.close(); }
