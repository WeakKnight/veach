// GPU/CPU color parity and public API lifecycle checks, using the real present shader.
import assert from 'node:assert/strict';
import { resolve } from 'node:path';
import { createServer } from 'vite';
import puppeteer from 'puppeteer-core';

const server = await createServer({ root: resolve('.'), logLevel: 'warn', server: { port: 5208 },
	plugins: [{ name: 'lut-test-page', configureServer(s) { s.middlewares.use('/__lut-smoke', (_req, res) => { res.setHeader('Content-Type','text/html');res.end('<!doctype html><head><link rel="icon" href="data:,"></head><body></body>'); }); } }] });
await server.listen();
const browser = await puppeteer.launch({ executablePath: process.env.CHROME_PATH ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true,
	args: ['--enable-unsafe-webgpu', '--enable-features=Vulkan', '--ignore-gpu-blocklist', '--no-sandbox'] });
try {
	const page = await browser.newPage();
	const errors = [];
	page.on('pageerror', e => errors.push(String(e)));
	page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
	// A blank document on the Vite origin, without starting the demo renderer.
	await page.goto(server.resolvedUrls.local[0] + '__lut-smoke');
	const result = await page.evaluate(async () => {
		const api = await import('/src/index.ts');
		document.body.replaceChildren();
		const canvas = document.createElement('canvas'); canvas.style.cssText = 'width:64px;height:16px'; document.body.append(canvas);
		const r = await api.Renderer.create(canvas, { denoiser: null });
		const check = (condition, message) => { if (!condition) throw new Error(message); };
		Object.assign(r.settings, { maxSamples: 1, autoExposureMethod: api.AutoExposureMethod.Manual, autoExposureBias: 0 });
		r.renderFrame(); await r.device.queue.onSubmittedWorkDone();
		const samples = r.samples;
		const inputs = [[0,0,0], [0.18,0.18,0.18], [1,1,1], [10,1,0.1], [-0.01,0.2,0.9], [100,100,100], [0.01,0.8,0.1], [0.002,0.004,0.008]];
		const format = navigator.gpu.getPreferredCanvasFormat();
		const target = r.device.createTexture({ size: [64,16], format, usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.COPY_SRC });
		const readback = r.device.createBuffer({ size: 256*16, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
		// Fill accumulation via compute (storage buffers do not require COPY_DST), not via the tone mapper.
		const module = r.device.createShaderModule({ code: `@group(0) @binding(0) var<storage,read_write> a:array<vec4f>;
const colors=array<vec3f,8>(${inputs.map(c=>`vec3f(${c.map(v=>v.toFixed(7)).join(',')})`).join(',')});
@compute @workgroup_size(64) fn main(@builtin(global_invocation_id) id:vec3u){if(id.x<1024u){a[id.x*3u]=vec4f(colors[(id.x%64u)/8u],1);}}` });
		const pipeline = await r.device.createComputePipelineAsync({ layout:'auto', compute:{ module,entryPoint:'main' } });
		const bind = r.device.createBindGroup({ layout:pipeline.getBindGroupLayout(0), entries:[{binding:0,resource:{buffer:r.tracer.accumulation}}] });
		async function pixels() {
			const encoder=r.device.createCommandEncoder(); const pass=encoder.beginComputePass();pass.setPipeline(pipeline);pass.setBindGroup(0,bind);pass.dispatchWorkgroups(16);pass.end();
			r.tracer.encodePresent(encoder,target.createView());encoder.copyTextureToBuffer({texture:target},{buffer:readback,bytesPerRow:256},{width:64,height:16});r.device.queue.submit([encoder.finish()]);
			await readback.mapAsync(GPUMapMode.READ);const bytes=new Uint8Array(readback.getMappedRange()).slice();readback.unmap();return bytes;
		}
		const srgb = x => {x=Math.min(1,Math.max(0,x));return x<=0.0031308?12.92*x:1.055*x**(1/2.4)-0.055;};
		let maxError=0;
		async function compare(desc) {
			await r.setDisplayTransform(desc); r.renderFrame();
			const bytes=await pixels();
			for(let i=0;i<inputs.length;i++){
				const expected=api.evaluateDisplayTransform(desc,inputs[i]).map(v=>Math.round(srgb(v)*255));
				for(let c=0;c<3;c++){const actual=bytes[(i*8+4)*4+(format.startsWith('bgra')?2-c:c)];const error=Math.abs(actual-expected[c]);maxError=Math.max(maxError,error);check(error<=2,`GPU mismatch sample ${i}, channel ${c}: ${actual} vs ${expected[c]}`);}
			}
			check(r.samples===samples,'LUT swap reset accumulation');
			check(r.displayTransform.localExposure==='off','LUT did not suppress local exposure');
		}
		for(const look of api.BUILTIN_LUTS) await compare(await api.loadBuiltinLUT(look.id));
		const values=new Float32Array(24);for(let i=0;i<8;i++)values.set([i&1,(i>>1)&1,(i>>2)&1],i*3);
		for(const transfer of ['linear','srgb',{type:'gamma',exponent:2.2}]) await compare({type:'lut',lut:{size:2,values,domainMin:[0,0,0],domainMax:[1,1,1]},input:{primaries:'rec709',transfer},output:{primaries:'rec2020',transfer:'linear'}});
		await r.setDisplayTransform({type:'builtin',preset:'astia'});
		let rejected=false;try{await r.setDisplayTransform({type:'lut',lut:{size:33,values,domainMin:[0,0,0],domainMax:[1,1,1]},input:{primaries:'rec709',transfer:'linear'},output:{primaries:'rec709',transfer:'linear'}});}catch{rejected=true;}
		check(rejected&&r.displayTransform.preset==='astia','Invalid transform replaced the previous one');
		const stale=r.setDisplayTransform({type:'builtin',preset:'velvia'});const latest=r.setDisplayTransform(null);await Promise.all([stale,latest]);
		check(r.displayTransform.type==='default'&&r.displayTransform.localExposure==='settings','Latest request did not restore ACES/local exposure');
		check(r.settings.tonemapper===api.Tonemapper.ACES2&&r.samples===samples,'Default or accumulation changed');
		const pending=r.setDisplayTransform({type:'builtin',preset:'acros'});r.destroy();check(!(await pending).applied,'Disposed renderer accepted pending upload');
		target.destroy();readback.destroy();canvas.remove();
		await import('/src/view/index.ts');
		const view=document.createElement('veach-view');view.style.cssText='width:64px;height:32px';
		view.displayTransform={type:'builtin',preset:'astia'};
		const applied=new Promise((resolve,reject)=>{view.addEventListener('veach-displaychange',e=>resolve(e.detail),{once:true});view.addEventListener('veach-error',e=>{e.preventDefault();reject(e.detail);},{once:true});});
		document.body.append(view);check((await applied).preset==='astia','Initial custom-element LUT was not applied');
		check((await view.setDisplayTransform(null)).type==='default','Custom-element reset failed');
		view.remove();
		return {presets:api.BUILTIN_LUTS.length,maxError,samples,lifecycle:'passed',component:'passed'};
	});
	assert.deepEqual(errors,[]);console.log(JSON.stringify(result));
} finally {await browser.close();await server.close();}
