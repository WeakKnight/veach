// Browser GPU checks for raster visibility, matching shared-jitter ray tracing.
import { createServer } from 'vite';
import puppeteer from 'puppeteer-core';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve('.'), out = resolve('.tools/visibility/check');
mkdirSync(out, { recursive: true });
const option = (name, fallback) => { const i = process.argv.indexOf(`--${name}`); return i < 0 ? fallback : process.argv[i + 1]; };
const only = option('only', '').split(',').filter(Boolean);
const samples = Number(option('samples', '16'));
const seed = Number(option('seed', '0'));
const maxRelativeError = Number(option('max-relative-error', '1e30'));
const width = Number(option('width', '129')), height = Number(option('height', '97'));
const chrome = [process.env.CHROME_PATH, 'C:/Program Files/Google/Chrome/Application/chrome.exe', 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].find(p => p && existsSync(p));
const server = await createServer({ root, logLevel: 'warn', server: { port: 5207, strictPort: false, hmr: false } });
await server.listen();
const browser = await puppeteer.launch({ executablePath: chrome, headless: true, protocolTimeout: 1800000, args: ['--enable-unsafe-webgpu', '--ignore-gpu-blocklist', '--no-sandbox'] });
const errors = [], report = { completed: false, results: [], errors };
try {
	const page = await browser.newPage();
	page.on('pageerror', e => errors.push(String(e)));
	page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); if (m.text().startsWith('[visibility]')) console.log(m.text()); });
	await page.exposeFunction('saveVisibilityScreenshot', async name => page.screenshot({ path: resolve(out, `${name}-${width}x${height}-${samples}-seed${seed}.png`) }));
	await page.goto(server.resolvedUrls.local[0] + 'scripts/benchmark.html');
	report.results = await page.evaluate(async ({ only, samples, width, height, seed, maxRelativeError }) => {
		const api = await import('/src/index.ts');
		const { cyclesFixture } = await import('/scripts/wavefront-cycles-fixtures.ts');
		const requestDevice = GPUAdapter.prototype.requestDevice;
		GPUAdapter.prototype.requestDevice = function(d = {}) { return requestDevice.call(this, { ...d, requiredLimits: { ...d.requiredLimits, maxStorageBuffersPerShaderStage: 8 } }); };
		const canvas = document.querySelector('canvas'); canvas.style.cssText = `width:${width}px;height:${height}px`;
		const r = await api.Renderer.create(canvas, { denoiser: null });
		GPUAdapter.prototype.requestDevice = requestDevice;
		const check = (ok, message) => { if (!ok) throw new Error(message); };
		Object.assign(r.settings, { maxSamples: 0, maxBounces: 3, autoExposureMethod: api.AutoExposureMethod.Manual, autoExposureBias: 0, localExposureMethod: api.LocalExposureMethod.None });
		r.tracer.sharedPrimaryJitter = true;
		const writeUniforms = r.writeUniforms.bind(r);
		if (seed) r.writeUniforms = (...args) => { writeUniforms(...args); new Uint32Array(r.uniformData)[19] ^= seed; r.device.queue.writeBuffer(r.tracer.uniformBuffer, 0, r.uniformData); };
		const results = [], begin = GPUCommandEncoder.prototype.beginComputePass;
		let capture = false, captures = [], draws = 0, inspectPipeline;
		const inspectCode = (await import('/src/generated/shaders/PrimaryVisibilityCheck.wgsl?raw')).default;
		const draw = GPURenderPassEncoder.prototype.drawIndirect;
		GPURenderPassEncoder.prototype.drawIndirect = function(...args) { draws++; return draw.apply(this, args); };
		GPUCommandEncoder.prototype.beginComputePass = function(d = {}) {
			if (capture && d.label === 'wavefront.CompactIntersect.b0') {
				const cap = r.tracer.wavefront.capacity(r.tracer.width * r.tracer.height), header = r.tracer.width * r.tracer.height * 48 + 48;
				const inspect = begin.call(this, { label: 'check.primaryAttributes' });
				inspect.setPipeline(inspectPipeline); inspect.setBindGroup(0, r.tracer.sceneBindGroup);
				inspect.setBindGroup(1, r.tracer.wavefront.group, [captures.length * (r.settings.maxBounces + 1) * r.tracer.wavefront.alignment]);
				inspect.dispatchWorkgroups(Math.ceil(cap / 64)); inspect.end();
				const buffer = r.device.createBuffer({ size: cap * 112, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
				for (const [i, field] of [0, 8, 9, 10, 11, 12, 13].entries()) this.copyBufferToBuffer(r.tracer.accumulation, header + field * cap * 16, buffer, i * cap * 16, cap * 16);
				// Initialize clears the shadow mask; restore it after diagnostic scratch use.
				this.clearBuffer(r.tracer.accumulation, header + 11 * cap * 16, cap * 16);
				captures.push({ cap, buffer });
			}
			return begin.call(this, d);
		};
		async function read(buffer) {
			await buffer.mapAsync(GPUMapMode.READ); const data = buffer.getMappedRange().slice(0); buffer.destroy(); return data;
		}
		async function render(mode) {
			await r.setPrimaryVisibility(mode); r.resetAccumulation(); captures = []; draws = 0;
			capture = true; r.renderFrame(); capture = false;
			const hits = [];
			for (const { cap, buffer } of captures) hits.push({ cap, data: await read(buffer) });
			for (let i = 1; i < samples; i++) r.renderFrame();
			const bytes = r.tracer.width * r.tracer.height * 48;
			const buffer = r.device.createBuffer({ size: bytes, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ });
			const encoder = r.device.createCommandEncoder(); encoder.copyBufferToBuffer(r.tracer.accumulation, 0, buffer, 0, bytes); r.device.queue.submit([encoder.finish()]);
			return { hits, image: new Float32Array(await read(buffer)), stats: await r.readPrimaryVisibilityStats(), draws };
		}
		const cases = ['opaque-shadow', 'mixed-alpha', 'deep-alpha', 'masked-emitter', 'blend', 'near-clip', 'negative-scale', 'backface', 'thin-triangles', 'analytic-camera', 'empty', 'dof', 'MetalRoughSpheres.glb', 'TransmissionTest.glb', 'AlphaBlendModeTest.glb', 'EmissiveStrengthTest.glb'];
		try {
			for (const name of cases.filter(n => !only.length || only.includes(n))) {
				let desc = name.endsWith('.glb') ? await api.loadGLTF(`/samples/${name}`) : cyclesFixture(['mixed-alpha', 'deep-alpha', 'masked-emitter'].includes(name) ? name : 'opaque-shadow');
				if (name === 'empty') desc = { meshes: [], materials: [], textures: [], instances: [], cameras: [] };
				if (name === 'blend') { desc = cyclesFixture('mixed-alpha'); desc.materials[1].graph.alphaMode = 2; }
				if (name === 'near-clip') {
					const m = desc.meshes[0]; for (let i = 0; i < m.positions.length; i += 3) { m.positions[i] *= 0.001; m.positions[i + 1] *= 0.001; m.positions[i + 2] = 5 - 0.00005; }
				}
				if (name === 'analytic-camera') { desc.lights[0].radius = 0.35; desc.lights[0].visibleToCamera = true; }
				if (name === 'negative-scale') { desc.instances[1].transform[0] = -1.7; desc.instances[1].transform[5] = 0.6; }
				if (name === 'backface') for (const mesh of desc.meshes) for (let i=0;i<mesh.indices.length;i+=3) [mesh.indices[i+1],mesh.indices[i+2]]=[mesh.indices[i+2],mesh.indices[i+1]];
				if (name === 'thin-triangles') {
					const positions=[], indices=[];
					for(let i=0;i<100;i++){const x=(i%10-5)*0.2,y=(Math.floor(i/10)-5)*0.2;positions.push(x,y,2,x+0.002,y,2,x,y+0.08,2);indices.push(i*3,i*3+1,i*3+2);}
					Object.assign(desc.meshes[1],{positions:new Float32Array(positions),indices:new Uint32Array(indices),uv0:null});
				}
				await r.setScene(desc);
				if (desc.instances.length) inspectPipeline ??= await r.device.createComputePipelineAsync({ layout: r.tracer.wavefront.pipelineLayout,
					compute: { module: r.device.createShaderModule({ code: inspectCode }), entryPoint: 'InspectPrimarySurface' } });
				r.camera.lensRadius = name === 'dof' ? 0.05 : 0;
				// Pin the deterministic fixtures' camera; frameScene is used only for assets without cameras.
				if (desc.cameras.length) { r.camera.setFromMatrix(desc.cameras[0].transform, 5); r.camera.fovY = desc.cameras[0].yfov; }
				await r.setPrimaryVisibility('ray-traced');
				let settled = 0;
				for (let i = 0; i < 256; i++) {
					r.renderFrame(); await r.device.queue.onSubmittedWorkDone();
					const vt = r.virtualTextureStats;
					settled = !vt || (vt.pendingRequests === 0 && vt.uploadsLastFrame === 0) ? settled + 1 : 0;
					if (i >= 23 && settled >= 6) break;
				}
				check(settled >= 6, `${name}: texture residency did not settle`);
				const textureResidency = r.virtualTextureStats;
				const updateStreaming = r.updateStreaming; r.updateStreaming = () => {};
				const reference = await render('ray-traced'), raster = await render('rasterized');
				r.updateStreaming = updateStreaming;
				const basis = r.camera.basis(r.tracer.width / r.tracer.height);
				const cross = (a,b) => [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
				const dot = (a,b) => a.reduce((sum,v,i)=>sum+v*b[i],0);
				const ru=cross(basis.up,basis.forward), uf=cross(basis.forward,basis.right), fr=cross(basis.right,basis.up);
				function edgeDistance(instance, primitive, u, v) {
					const inst=desc.instances[instance], mesh=desc.meshes[inst.mesh], m=inst.transform;
					const world=[0,1,2].map(c=>{const i=mesh.indices[primitive*3+c]*3, p=mesh.positions; return [0,1,2].map(a=>m[a]*p[i]+m[4+a]*p[i+1]+m[8+a]*p[i+2]+m[12+a]);});
					const project=p=>{const d=p.map((x,a)=>x-r.camera.position[a]), z=dot(d,fr);return [dot(d,ru)/z*r.tracer.width/2,dot(d,uf)/z*r.tracer.height/2];};
					const point=project(world[0].map((x,a)=>x*(1-u-v)+world[1][a]*u+world[2][a]*v)), vertices=world.map(project);
					return Math.min(...vertices.map((a,i)=>{const b=vertices[(i+1)%3];return Math.abs((point[0]-a[0])*(b[1]-a[1])-(point[1]-a[1])*(b[0]-a[0]))/Math.max(1e-20,Math.hypot(b[0]-a[0],b[1]-a[1]));}));
				}
				let mismatches = 0, depthTies = 0, boundaryMismatches = 0, interiorMismatches = 0, hitCount = 0, maxDistance = 0, maxBarycentric = 0;
				const attributeErrors = { uv: 0, normal: 0, material: 0, shadingNormal: 0 };
				for (let tile = 0; tile < reference.hits.length; tile++) {
					const a = reference.hits[tile], b = raster.hits[tile], af = new Float32Array(a.data), au = new Uint32Array(a.data), bf = new Float32Array(b.data), bu = new Uint32Array(b.data);
					for (let i = 0; i < a.cap; i++) {
						const activeA = au[i * 4 + 3] !== 0, activeB = bu[i * 4 + 3] !== 0, h = a.cap * 4 + i * 4, id = a.cap * 8 + i * 4;
						if (!activeA && !activeB) continue;
						const same = activeA === activeB && au[h + 3] === bu[h + 3] && au[id] === bu[id];
						if (!same) {
							mismatches++;
							
							// Edge classification in projected pixels is refined by the diagnostic fixture tests.
							const tie = activeA && activeB && Math.abs(af[h]-bf[h]) <= 2e-6*Math.max(Math.abs(af[h]),Math.abs(bf[h]));
							const edge = Math.min(activeA ? edgeDistance(au[h+3],au[id],af[h+1],af[h+2]) : Infinity, activeB ? edgeDistance(bu[h+3],bu[id],bf[h+1],bf[h+2]) : Infinity);
							if (tie) depthTies++; else if (edge <= 1/128) boundaryMismatches++; else interiorMismatches++;
							if (!tie && edge > 1/128) console.log('[visibility] unexplained ' + JSON.stringify({name,i,edge,a:[au[h+3],au[id],...af.slice(h,h+3)],b:[bu[h+3],bu[id],...bf.slice(h,h+3)]}));
							continue;
						}
						hitCount++; maxDistance = Math.max(maxDistance, Math.abs(af[h] - bf[h]) / Math.max(Math.abs(af[h]), 1e-8));
						maxBarycentric = Math.max(maxBarycentric, Math.abs(af[h + 1] - bf[h + 1]), Math.abs(af[h + 2] - bf[h + 2]));
						for (const [j, key] of Object.keys(attributeErrors).entries()) for (let c = 0; c < 4; c++) {
							const at = (3 + j) * a.cap * 4 + i * 4 + c;
							check(Number.isFinite(af[at]) && Number.isFinite(bf[at]), `${name}: nonfinite primary ${key}`);
							attributeErrors[key] = Math.max(attributeErrors[key], Math.abs(af[at] - bf[at]));
						}
					}
				}
				let sum = 0, norm = 0, maxError = 0;
				for (let i = 0; i < reference.image.length; i++) {
					check(Number.isFinite(raster.image[i]), `${name}: nonfinite output`);
					const d = reference.image[i] - raster.image[i]; sum += d * d; norm += reference.image[i] ** 2; maxError = Math.max(maxError, Math.abs(d));
				}
				const aovErrors = {};
				for (const [field, key] of ['hdr', 'albedo', 'normal'].entries()) {
					let error = 0, energy = 0;
					for (let pixel = 0; pixel < width * height; pixel++) for (let c = 0; c < 3; c++) {
						const at = pixel * 12 + field * 4 + c, d = reference.image[at] - raster.image[at]; error += d*d; energy += reference.image[at] ** 2;
					}
					aovErrors[key] = Math.sqrt(error / Math.max(energy, 1e-20));
				}
				const result = { name, width, height, samples, seed, hitCount, mismatches, depthTies, boundaryMismatches, interiorMismatches, maxDistance, maxBarycentric, attributeErrors, aovErrors, textureResidency, relativeL2: Math.sqrt(sum / Math.max(norm, 1e-20)), maxError, stats: raster.stats, draws: raster.draws };
				console.log('[visibility] ' + JSON.stringify(result)); results.push(result);
				check(interiorMismatches === 0 && maxDistance <= 2e-5 && maxBarycentric <= 2e-5, `${name}: primary visibility mismatch`);
				check(Object.values(attributeErrors).every(v => v <= 2e-5), `${name}: primary attribute mismatch`);
				check(Object.values(aovErrors).every(v => v <= maxRelativeError), `${name}: HDR/AOV convergence exceeded ${maxRelativeError}`);
				check(raster.draws === (['empty', 'dof'].includes(name) ? 0 : samples), `${name}: expected one geometry draw per sample`);
				await globalThis.saveVisibilityScreenshot(name);
				if (name === 'near-clip') check(raster.stats.nearClipFallback, 'Near clip fallback not exercised');
			}
		} finally { GPUCommandEncoder.prototype.beginComputePass = begin; GPURenderPassEncoder.prototype.drawIndirect = draw; r.destroy(); }
		return results;
	}, { only, samples, width, height, seed, maxRelativeError });
	report.completed = true;
	if (errors.length) throw new Error(errors.join('\n'));
} catch (error) { report.failure = String(error); throw error; }
finally { writeFileSync(resolve(out, `report-${width}x${height}-${samples}-seed${seed}${only.length ? '-' + only.join('_').replaceAll('.', '-') : ''}.json`), JSON.stringify(report, null, 2)); await browser.close(); await server.close(); }
