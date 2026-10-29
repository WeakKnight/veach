// Browser-only integration assertions; read actual scene-linear GPU output through the public API.
import * as THREE from 'three';
import { Renderer, LocalExposureMethod } from '../../src/render/Renderer';
import { AutoExposureMethod } from '../../src/render/AutoExposure';
import { ThreeAdapter } from '../../src/three';

function check(value: boolean, message: string): asserts value { if (!value) throw new Error(message); }
async function run() {
	const renderer = await Renderer.create(document.getElementById('viewport') as HTMLCanvasElement, { denoiser: null });
	const checks: string[] = [];
	try {
		check(renderer.integrator === 'wavefront', 'Host validation must exercise the default wavefront integrator');
		checks.push('default wavefront integrator');
		renderer.settings.resolutionScale = 1; renderer.settings.maxBounces = 2;
		renderer.settings.autoExposureMethod = AutoExposureMethod.Manual; renderer.settings.localExposureMethod = LocalExposureMethod.None;
		renderer.settings.environmentIntensity = 0; renderer.settings.environmentVisible = false; renderer.settings.background = [0, 0, 0]; renderer.sun.enabled = false;
		const root = new THREE.Scene(), camera = new THREE.PerspectiveCamera(50, 256 / 192, 0.1, 100);
		camera.position.z = 5;
		const geometry = new THREE.PlaneGeometry(2, 2), material = new THREE.MeshBasicMaterial({ color: 0xff0000 });
		const mesh = new THREE.Mesh(geometry, material); root.add(mesh);
		const adapter = new ThreeAdapter(renderer);
		let frame = 0;
		const render = async () => {
			await adapter.sync(root, camera);
			renderer.renderFrame({ scene: adapter.scene, view: adapter.view(camera), frameIndex: frame++, samplesPerPixel: 1 });
			return renderer.readRadiance();
		};
		const center = (r: Awaited<ReturnType<typeof render>>) => [...r.data.slice(((r.height >> 1) * r.width + (r.width >> 1)) * 3, ((r.height >> 1) * r.width + (r.width >> 1)) * 3 + 3)];
		const red = center(await render()); check(red[0] > 0.9 && red[1] < 0.01, `Red emission missing: ${red}`);
		for (let i = 0; i < 8; i++) await render();
		material.color.setHex(0x00ff00);
		const green = center(await render()); check(green[0] < 0.01 && green[1] > 0.9, `Previous frame leaked into new material: ${green}`);
		check(renderer.hostSceneStats(adapter.scene)!.blasBuilds === 0 && renderer.hostSceneStats(adapter.scene)!.tlasBuilds === 0, 'Material update rebuilt acceleration'); checks.push('material update / no cross-frame accumulation');
		mesh.position.x = 4; const moved = center(await render()); check(moved.every(x => x < 0.001), 'Moved geometry left a stale image');
		check(renderer.hostSceneStats(adapter.scene)!.blasBuilds === 0 && renderer.hostSceneStats(adapter.scene)!.tlasBuilds === 1, 'Transform did not preserve BLAS'); checks.push('transform / TLAS / no trails');
		mesh.position.x = 0; material.color.setHex(0xffffff);
		const pixels = new Uint8Array([0, 0, 255, 255]), texture = new THREE.DataTexture(pixels, 1, 1); material.map = texture;
		const blue = center(await render()); check(blue[2] > 0.9 && blue[0] < 0.01, `Texture registration failed: ${blue}`);
		pixels.set([255, 0, 255, 255]); texture.needsUpdate = true;
		const magenta = center(await render()); check(magenta[0] > 0.9 && magenta[2] > 0.9 && magenta[1] < 0.01, `Texture update is stale: ${magenta}`); checks.push('texture create / version update / material relocation');
		material.alphaTest = 0.5; pixels[3] = 0; texture.needsUpdate = true;
		const masked = center(await render()); check(masked.every(x => x < 0.001), 'Mask change did not update traversal flags');
		material.alphaTest = 0; texture.image = { width: 2, height: 2, data: new Uint8Array([255, 0, 255, 255, 255, 0, 255, 255, 255, 0, 255, 255, 255, 0, 255, 255]) }; texture.needsUpdate = true;
		const resized = center(await render()); check(resized[0] > 0.9 && resized[2] > 0.9, 'Resized texture descriptor is stale');
		check(renderer.hostSceneStats(adapter.scene)!.blasBuilds === 0, 'Texture resize rebuilt BLAS'); checks.push('alpha traversal / resized texture');
		const position = geometry.getAttribute('position');
		for (let i = 0; i < position.count; i++) position.setX(i, position.getX(i) + 4); position.needsUpdate = true;
		const deformed = center(await render()); check(deformed.every(x => x < 0.001), 'Position edit did not rebuild BLAS');
		check(renderer.hostSceneStats(adapter.scene)!.blasBuilds === 1, 'Position edit rebuilt wrong number of BLAS'); checks.push('geometry deformation');
		for (let i = 0; i < position.count; i++) position.setX(i, position.getX(i) - 4); position.needsUpdate = true;
		const second = new THREE.Mesh(geometry, material); second.position.x = -3; root.add(second); await render();
		root.remove(mesh); await render(); check(adapter.scene.stats.geometries === 1, 'Shared geometry released too early');
		second.position.x = 0; const shared = center(await render()); check(shared[0] > 0.9, 'Sparse instance slot traversal failed'); checks.push('shared resource removal / sparse TLAS slots');
		root.remove(second); await render(); check(adapter.scene.stats.instances === 0 && adapter.scene.stats.textures === 0, 'Last reference did not release resources'); checks.push('last reference release / empty rendering');
		adapter.dispose();
		const empty = renderer.createScene(); await empty.beginUpdate().commit();
		renderer.renderFrame({ scene: empty, view: { worldFromCamera: new Float32Array(camera.matrixWorld.elements), clipFromView: new Float32Array(camera.projectionMatrix.elements) }, frameIndex: 0 });
		await renderer.device.queue.onSubmittedWorkDone(); empty.dispose(); checks.push('empty initial scene / dispose');
		texture.dispose(); geometry.dispose(); material.dispose();
		Object.assign(window, { __validation: { done: true, checks } });
	} finally { renderer.destroy(); }
}
run().catch(error => { console.error(error); Object.assign(window, { __validation: { done: true, error: String(error) } }); });
