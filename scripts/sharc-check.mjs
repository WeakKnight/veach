// One small integration scene: cache warmup, early termination, invalidation and off switch.
import { createServer } from 'vite';
import puppeteer from 'puppeteer-core';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
const out = resolve('.tools/sharc'); mkdirSync(out, { recursive: true });
const chrome = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe'].find(p => p && existsSync(p));
const server = await createServer({ server: { port: 5211, strictPort: false, hmr: false }, logLevel: 'warn' }); await server.listen();
const browser = await puppeteer.launch({ executablePath: chrome, headless: true, protocolTimeout: 180000, args: ['--enable-unsafe-webgpu', '--ignore-gpu-blocklist', '--no-sandbox'] });
const errors = [];
try {
	const page = await browser.newPage();
	await page.exposeFunction('captureSharc', async name => {
		const canvas = await page.$('canvas');
		await canvas.screenshot({ path: resolve(out, `${name}.png`) });
	});
	page.on('pageerror', e => errors.push(String(e))); page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
	await page.goto(server.resolvedUrls.local[0] + 'scripts/benchmark.html');
	const result = await page.evaluate(async () => {
		const api = await import('/src/index.ts'), { GraphBuilder } = await import('/src/material/Graph.ts');
		const request = GPUAdapter.prototype.requestDevice;
		GPUAdapter.prototype.requestDevice = function(d = {}) { return request.call(this, { ...d, requiredLimits: { ...d.requiredLimits, maxStorageBuffersPerShaderStage: 8 } }); };
		const canvas = document.querySelector('canvas'); canvas.style.cssText = 'width:128px;height:96px';
		const r = await api.Renderer.create(canvas, { denoiser: null }); GPUAdapter.prototype.requestDevice = request;
		Object.assign(r.settings, { maxSamples: 0, maxBounces: 8, autoExposureMethod: api.AutoExposureMethod.Manual, localExposureMethod: api.LocalExposureMethod.None });
		const material = (color, emission = 0) => {
			const b = new GraphBuilder(), surface = b.node('open_pbr_surface', 'surfaceshader', { base_color: color, specular_weight: 0, specular_roughness: 1, emission_luminance: emission, emission_color: [1,1,1] });
			return { ...api.defaultMaterial(), graph: { name: 'cache-check', nodes: b.nodes, surface: surface.node, alphaMode: 0, alphaCutoff: 0.5, doubleSided: true } };
		};
		const meshes = [], plane = (p, material) => meshes.push({ name: 'wall', positions: new Float32Array(p), indices: new Uint32Array([0,1,2,0,2,3]), normals: null, tangents: null, uv0: null, uv1: null, material });
		plane([-2,-2,-2,2,-2,-2,2,2,-2,-2,2,-2],0);
		plane([-2,-2,2,-2,-2,-2,-2,2,-2,-2,2,2],1);
		plane([2,-2,-2,2,-2,2,2,2,2,2,2,-2],2);
		plane([-2,-2,2,2,-2,2,2,-2,-2,-2,-2,-2],0);
		plane([-2,2,-2,2,2,-2,2,2,2,-2,2,2],0);
		plane([-.5,1.99,-.5,.5,1.99,-.5,.5,1.99,.5,-.5,1.99,.5],3);
		await r.setScene({ meshes, materials: [material([.7,.7,.7]), material([.7,.12,.08]), material([.08,.6,.15]), material([0,0,0],10)], textures: [], instances: meshes.map((_,mesh)=>({ mesh, transform: api.mat4.identity() })), cameras: [] });
		r.camera.position=[0,0,5]; r.camera.target=[0,0,0]; r.camera.fovY=.75;
		const frame = async () => { r.renderFrame(); await r.device.queue.onSubmittedWorkDone(); };
		async function image() {
			const buffer=r.device.createBuffer({size:128*96*48,usage:GPUBufferUsage.COPY_DST|GPUBufferUsage.MAP_READ});
			const e=r.device.createCommandEncoder();e.copyBufferToBuffer(r.tracer.accumulation,0,buffer,0,buffer.size);r.device.queue.submit([e.finish()]);await buffer.mapAsync(GPUMapMode.READ);
			const values=Array.from(new Float32Array(buffer.getMappedRange()));buffer.destroy();return values;
		}
		const check=(ok,message)=>{if(!ok)throw new Error(message);};
		try {
			await r.setSharc(false); // Explicit reference, independent of production defaults.
			for(let i=0;i<16;i++)await frame(); const reference=await image();
			await window.captureSharc('reference');
			await r.setSharc(true,{voxelSize:.3,minSamples:4,historyFrames:8});
			await frame(); const cold=await r.readSharcStats(); check(cold.cacheHits===0,'Cold cache must not terminate paths');
			for(let i=0;i<48;i++)await frame();
			r.resetAccumulation(); for(let i=0;i<16;i++)await frame();
			const warm=await r.readSharcStats(), cached=await image();
			await window.captureSharc('cached');
			check(warm.active && warm.cacheHits>0 && warm.acceptedUpdates>0,'Cache was not populated/queried');
			check(warm.averageSegments<cold.averageSegments,'Cache did not reduce traced segments');
			check(cached.every(Number.isFinite),'Nonfinite cache output');
			let error=0,norm=0;for(let i=0;i<cached.length;i+=12)for(let c=0;c<3;c++){error+=(cached[i+c]-reference[i+c])**2;norm+=reference[i+c]**2;}
			const before=warm.epoch;r.settings.autoExposureBias=1;await frame();const presentation=await r.readSharcStats();check(presentation.epoch===before+1,'Presentation invalidated cache');
			r.settings.environmentIntensity*=2;r.resetAccumulation();await frame();const lighting=await r.readSharcStats();check(lighting.epoch===1&&lighting.cacheHits===0,'Lighting change retained stale cache');
			await r.setSharc(false);await frame();check(!r.sharcStats.active&&r.sharcStats.bytes===0,'Disabled cache retained work allocation');
			return {cold,warm,presentationEpoch:presentation.epoch,lighting,relativeHdrL2:Math.sqrt(error/Math.max(norm,1e-20)),off:r.sharcStats};
		} finally { r.destroy(); }
	});
	if(errors.length)throw new Error(errors.join('\n'));
	writeFileSync(resolve(out,'check.json'),JSON.stringify(result,null,2)); console.log(JSON.stringify(result,null,2));
} finally { await browser.close(); await server.close(); }
