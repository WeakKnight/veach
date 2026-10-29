import { createServer } from 'vite';
import puppeteer from 'puppeteer-core';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
const root = resolve('.'), output = resolve('.tools/visibility/host'); mkdirSync(output, { recursive: true });
const chrome = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe', 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].find(p => p && existsSync(p));
const server = await createServer({ root, logLevel: 'warn', server: { port: 5209, strictPort: false, hmr: false } }); await server.listen();
const browser = await puppeteer.launch({ executablePath: chrome, headless: true, protocolTimeout: 1800000, args: ['--enable-unsafe-webgpu', '--ignore-gpu-blocklist', '--no-sandbox'] });
const report = { completed: false, results: [], errors: [] };
try {
	const page = await browser.newPage(); page.on('pageerror', e => report.errors.push(String(e))); page.on('console', m => { if (m.type() === 'error') report.errors.push(m.text()); });
	await page.goto(server.resolvedUrls.local[0] + 'scripts/benchmark.html');
	report.results = await page.evaluate(async () => {
		const api = await import('/src/index.ts'), { mat4 } = await import('/src/math/Math.ts');
		const canvas = document.querySelector('canvas'); canvas.style.cssText = 'width:129px;height:97px';
		const r = await api.Renderer.create(canvas, { denoiser: null });
		Object.assign(r.settings, { maxSamples: 0, maxBounces: 2, autoExposureMethod: api.AutoExposureMethod.Manual, localExposureMethod: api.LocalExposureMethod.None });
		r.tracer.sharedPrimaryJitter = true;
		const scene = r.createScene(), tx = scene.beginUpdate();
		const quad = () => ({ positions: new Float32Array([-1,-1,0,1,-1,0,1,1,0,-1,1,0]), indices: new Uint32Array([0,1,2,0,2,3]), uv0: new Float32Array([0,0,1,0,1,1,0,1]) });
		const geometry = tx.createGeometry(quad()), material = tx.createMaterial({ baseColor: [0.7,0.3,0.1], doubleSided: true });
		const first = tx.addInstance({ geometry, materials: [material], worldMatrix: mat4.identity() });
		const back = mat4.identity(); back[12] = 1.4; back[14] = -0.5;
		const second = tx.addInstance({ geometry, materials: [material], worldMatrix: back }); await tx.commit();
		const world = mat4.identity(); world[14] = 5;
		const projection = new Float32Array(16); projection[0] = 2; projection[5] = 2.5; projection[8] = 0.23; projection[9] = -0.17; projection[10] = -1; projection[11] = -1; projection[14] = -0.02;
		const frame = { scene, frameIndex: 31, view: { worldFromCamera: world, clipFromView: projection } }, results = [];
		async function render(mode) {
			await r.setPrimaryVisibility(mode); r.renderFrame(frame);
			const bytes = r.tracer.width*r.tracer.height*48, buffer=r.device.createBuffer({size:bytes,usage:GPUBufferUsage.MAP_READ|GPUBufferUsage.COPY_DST});
			const encoder=r.device.createCommandEncoder();encoder.copyBufferToBuffer(r.tracer.accumulation,0,buffer,0,bytes);r.device.queue.submit([encoder.finish()]);
			await buffer.mapAsync(GPUMapMode.READ);const data=new Float32Array(buffer.getMappedRange().slice(0));buffer.destroy();
			return { data, stats: await r.readPrimaryVisibilityStats() };
		}
		async function compare(name) {
			const a=await render('ray-traced'), b=await render('rasterized'); let sum=0,norm=0,max=0;
			for(let i=0;i<a.data.length;i++){const d=a.data[i]-b.data[i];if(!Number.isFinite(d))throw new Error(name+': nonfinite output');sum+=d*d;norm+=a.data[i]*a.data[i];max=Math.max(max,Math.abs(d));}
			const relativeL2=Math.sqrt(sum/Math.max(norm,1e-20));
			if(relativeL2>0.002)throw new Error(`${name}: ${relativeL2}`);
			results.push({name,relativeL2,max,stats:b.stats,updates:r.hostSceneStats(scene)});
		}
		try {
			await compare('off-axis');
			world[0]=world[5]=world[10]=0.1;world[14]=0.00005;await compare('scaled-camera-near-clip');
			if(!results.at(-1).stats.nearClipFallback)throw new Error('World-space near guard missed scaled camera');
			world[0]=world[5]=world[10]=10;world[14]=0.0002;await compare('scaled-camera-outside-near');
			if(results.at(-1).stats.nearClipFallback)throw new Error('World-space near guard over-expanded with camera scale');
			world[0]=world[5]=world[10]=1;world[14]=5;
			let update=scene.beginUpdate(), m=mat4.identity();m[0]=-1.2;m[5]=0.7;m[12]=0.27;update.setInstanceTransform(first,m);await update.commit();await compare('negative-nonuniform-transform');
			update=scene.beginUpdate();update.setMaterial(material,{opacity:0.3,alphaMode:'mask',alphaCutoff:0.5});await update.commit();await compare('opaque-to-mask');
			update=scene.beginUpdate();update.setMaterial(material,{opacity:1,alphaMode:'opaque'});update.removeInstance(first);await update.commit();await compare('sparse-instance-removal');
			update=scene.beginUpdate();const replacement=quad();replacement.positions[0]=-1.7;replacement.positions[4]=0.7;update.setGeometry(geometry,replacement);await update.commit();await compare('geometry-replacement');
			update=scene.beginUpdate();update.updateGeometryAttributes(geometry,{uv0:new Float32Array([0,0,2,0,2,2,0,2])});await update.commit();await compare('attribute-update');
			update=scene.beginUpdate();for(let i=0;i<1024;i++){const q=mat4.identity();q[12]=100+i;update.addInstance({geometry,materials:[material],worldMatrix:q});}await update.commit();await compare('buffer-growth-offscreen-culling');
			if(results.at(-1).stats.visibleClusters>=results.at(-1).stats.clusterInstances)throw new Error('Frustum culling did not reject offscreen instances');
			canvas.style.cssText='width:513px;height:513px';r.resize();await compare('resize-multiple-tiles');
			await r.setIntegrator('megakernel');const fallback=await render('rasterized');if(fallback.stats.reason!=='integrator')throw new Error('Megakernel fallback failed');
			await r.setIntegrator('wavefront');r.settings.debugMode=7;const debug=await render('rasterized');if(debug.stats.reason!=='debug-view')throw new Error('Debug fallback failed');
			results.push({name:'fallback-modes',integrator:fallback.stats.reason,debug:debug.stats.reason});
		} finally { scene.dispose(); r.destroy(); }
		return results;
	});
	report.completed = true; if (report.errors.length) throw new Error(report.errors.join('\n'));
	console.log(JSON.stringify(report.results, null, 2));
} catch(error) { report.failure=String(error);throw error; }
finally { writeFileSync(resolve(output,'report.json'),JSON.stringify(report,null,2));await browser.close();await server.close(); }
