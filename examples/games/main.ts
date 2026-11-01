import * as THREE from 'three';
import { Renderer, LocalExposureMethod } from '../../src/render/Renderer';
import { ThreeAdapter } from '../../src/three';
import { createRendererConsole } from '../../src/debug/RendererConsole';
import { DebugConsole } from '../../src/view/DebugConsole';
import { GpuProfilerPanel } from '../../src/view/GpuProfilerPanel';
import './style.css';

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const canvas = $<HTMLCanvasElement>('viewport');
const mode = new URLSearchParams(location.search).get('game') === 'race' ? 'race' : 'aim';
document.body.classList.add(mode);
document.querySelector(`[data-game="${mode}"]`)?.classList.add('active');
$('map').style.display = mode === 'race' ? '' : 'none';
$('eyebrow').textContent = mode === 'aim' ? '01 / PRECISION TRAINING' : '02 / TIME ATTACK';
$('title').textContent = mode === 'aim' ? 'AIM LAB' : 'APEX RUN';
$('subtitle').textContent = mode === 'aim' ? 'Find your rhythm. Make every shot count.' : 'One circuit. Three laps. Your best line.';
$('controls').innerHTML = mode === 'aim' ? '<kbd>MOUSE</kbd> AIM &nbsp; <kbd>CLICK</kbd> FIRE &nbsp; <kbd>SPACE</kbd> PAUSE' : '<kbd>W S</kbd> DRIVE &nbsp; <kbd>A D</kbd> STEER &nbsp; <kbd>R</kbd> RESET';
$('controls').insertAdjacentHTML('beforeend', ' &nbsp; <kbd>~</kbd> CONSOLE');
const scene = new THREE.Scene(), camera = new THREE.PerspectiveCamera(55, 1, 0.1, 150);
const box = new THREE.BoxGeometry(1, 1, 1), sphere = new THREE.IcosahedronGeometry(1, 2);
const materials = new Set<THREE.Material>(), geometries = new Set<THREE.BufferGeometry>([box, sphere]);
const pbr = (color: number, roughness = 0.8, metalness = 0) => {
	const m = new THREE.MeshStandardMaterial({ color, roughness, metalness }); materials.add(m); return m;
};
const pale = pbr(0xd2d6bc), dark = pbr(0x233b41), green = pbr(0xb8df76), black = pbr(0x17242a);
function mesh(geometry: THREE.BufferGeometry, material: THREE.Material, position: number[], scale: number[], parent: THREE.Object3D = scene): THREE.Mesh {
	const m = new THREE.Mesh(geometry, material); m.position.fromArray(position); m.scale.fromArray(scale); parent.add(m); return m;
}
const cube = (material: THREE.Material, position: number[], scale: number[], parent: THREE.Object3D = scene) => mesh(box, material, position, scale, parent);
const textureData = new Uint8Array(32 * 32 * 4);
const texture = new THREE.DataTexture(textureData, 32, 32); texture.colorSpace = THREE.SRGBColorSpace; texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
function paintTexture(hits: number) {
	const color = new THREE.Color().setHSL((0.2 + hits * 0.035) % 1, 0.65, 0.65).convertLinearToSRGB();
	for (let y = 0; y < 32; y++) for (let x = 0; x < 32; x++) {
		const i = (y * 32 + x) * 4, stripe = (x + y + hits * 3) % 16 < 8;
		textureData.set(stripe ? [color.r * 255, color.g * 255, color.b * 255, 255] : [28, 48, 53, 255], i);
	}
	texture.needsUpdate = true;
}
paintTexture(0);
const striped = pbr(0xffffff); striped.map = texture;

// Procedural surface detail for the race (RGBA8 DataTextures): value-noise albedo, roughness (G) and tangent-space
// normal maps, so surfaces are not flat diffuse color.
const textures = new Set<THREE.Texture>();
function noise(size: number, seed: number, octaves: number[]): Float32Array {
	const out = new Float32Array(size * size);
	let amplitude = 0;
	for (const [o, cells] of octaves.entries()) {
		const lattice = new Float32Array((cells + 1) * (cells + 1));
		let s = seed * 9301 + o * 49297;
		for (let i = 0; i < lattice.length; i++) { s = (s * 1664525 + 1013904223) >>> 0; lattice[i] = s / 4294967296; }
		for (let i = 0; i <= cells; i++) { lattice[cells * (cells + 1) + i] = lattice[i]; lattice[i * (cells + 1) + cells] = lattice[i * (cells + 1)]; }
		const weight = 1 / (o + 1);
		for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
			const fx = x / size * cells, fy = y / size * cells, ix = Math.floor(fx), iy = Math.floor(fy);
			const tx = (fx - ix) * (fx - ix) * (3 - 2 * (fx - ix)), ty = (fy - iy) * (fy - iy) * (3 - 2 * (fy - iy));
			const at = (i: number, j: number) => lattice[j * (cells + 1) + i];
			const top = at(ix, iy) + (at(ix + 1, iy) - at(ix, iy)) * tx, bottom = at(ix, iy + 1) + (at(ix + 1, iy + 1) - at(ix, iy + 1)) * tx;
			out[y * size + x] += (top + (bottom - top) * ty) * weight;
		}
		amplitude += weight;
	}
	for (let i = 0; i < out.length; i++) out[i] /= amplitude;
	return out;
}
function dataTexture(size: number, pixel: (i: number) => number[], repeat: number, srgb: boolean): THREE.DataTexture {
	const data = new Uint8Array(size * size * 4);
	for (let i = 0; i < size * size; i++) data.set([...pixel(i).map(v => Math.round(THREE.MathUtils.clamp(v, 0, 1) * 255)), 255], i * 4);
	const t = new THREE.DataTexture(data, size, size);
	t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
	t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(repeat, repeat); t.needsUpdate = true;
	textures.add(t);
	return t;
}
// Tangent-space normals of a tileable height field, `strength` scaling its slopes.
function normalTexture(size: number, height: Float32Array, strength: number, repeat: number): THREE.DataTexture {
	const h = (x: number, y: number) => height[((y + size) % size) * size + ((x + size) % size)];
	return dataTexture(size, i => {
		const x = i % size, y = Math.floor(i / size);
		const n = new THREE.Vector3((h(x - 1, y) - h(x + 1, y)) * strength, (h(x, y - 1) - h(x, y + 1)) * strength, 1).normalize();
		return [n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5];
	}, repeat, false);
}
// Surface: albedo noise around `color`, roughness `[min, max]` from a second noise, normals from the albedo noise.
function surface(color: number, size: number, seed: number, cells: number[], contrast: number, roughness: [number, number], bump: number, repeat: number, metalness = 0): THREE.MeshStandardMaterial {
	const base = new THREE.Color(color), detail = noise(size, seed, cells), wear = noise(size, seed + 17, [4, 9]);
	const m = pbr(0xffffff, 1, metalness);
	m.map = dataTexture(size, i => { const k = 1 + (detail[i] - 0.5) * contrast; return [base.r * k, base.g * k, base.b * k].map(v => Math.pow(v, 1 / 2.2)); }, repeat, true);
	m.roughnessMap = dataTexture(size, i => [0, roughness[0] + (roughness[1] - roughness[0]) * wear[i], 0], repeat, false);
	if (bump > 0) m.normalMap = normalTexture(size, detail, bump, repeat);
	return m;
}
let renderer: Renderer, adapter: ThreeAdapter;
let debugConsole: DebugConsole | undefined, consoleBusy = false;
let gpuProfilerPanel: GpuProfilerPanel | undefined;
let sceneSync: Promise<unknown> = Promise.resolve();
let frame = 0, ready = false, playing = false, finished = false, closed = false, lastTime = performance.now(), toastUntil = 0;
const keys = new Set<string>();
let elapsed = 0, hits = 0, shots = 0, combo = 0, score = 0;
type Target = { mesh: THREE.Mesh; base: THREE.Vector3; phase: number };
const targets: Target[] = [], debris: { mesh: THREE.Mesh; velocity: THREE.Vector3; ttl: number }[] = [];
const targetMaterial = pbr(0xff6c41, 0.4, 0.15), targetGeometry = new THREE.SphereGeometry(0.48, 16, 10);
const targetPositions = targetGeometry.getAttribute('position').array.slice();
geometries.add(targetGeometry);
let pendingSpawn = 0;
const raycaster = new THREE.Raycaster(), pointer = new THREE.Vector2();
let speed = 0, yaw = -Math.PI / 2, checkpoint = 0, laps = 0, lapStart = 0, bestLap = Infinity, collisions = 0;
const car = new THREE.Group(), checkpointMarkers: THREE.Mesh[] = [];
let trackRadius = 18;
function toast(text: string, duration = 1.1) { $('toast').textContent = text; toastUntil = performance.now() + duration * 1000; }

function spawnTarget() {
	const slot = Array.from({ length: 6 }, (_, i) => i).find(i => !targets.some(t => t.phase === i)) ?? 0;
	const base = new THREE.Vector3((slot % 3 - 1) * 3.4, 1.8 + Math.floor(slot / 3) * 2.5, -4.5);
	const target = mesh(targetGeometry, targetMaterial, base.toArray(), [1, 1, 1]);
	target.userData.slot = slot; targets.push({ mesh: target, base, phase: slot });
}
function buildAim() {
	camera.position.set(0, 3.3, 11); camera.lookAt(0, 3, -5);
	cube(pale, [0, -0.2, -2], [24, 0.4, 28]);
	cube(dark, [0, 3, -6], [16, 6, 0.5]);
	// Trims and caps overhang what they sit on, and crossing grid lines stand at different depths: no coplanar faces.
	for (const x of [-8, 8]) { cube(pale, [x, 1.4, -2], [0.5, 2.8, 9]); cube(green, [x, 2.9, -2], [0.54, 0.14, 9.04]); }
	for (let i = -3; i <= 3; i++) cube(pale, [i * 2.3, 3, -5.7], [0.025, 5.7, 0.05]);
	for (const y of [0.8, 3, 5.5]) cube(pale, [0, y, -5.705], [15.5, 0.025, 0.05]);
	cube(striped, [0, 6.1, -5.7], [16, 0.35, 0.25]);
	for (let z = 2; z > -5; z -= 2) cube(green, [0, 0.015, z], [0.12, 0.025, 0.7]);
	for (const x of [-5.5, 5.5]) { cube(black, [x, 0.7, 4], [1.5, 1.4, 1.8]); cube(striped, [x, 1.43, 4], [1.56, 0.06, 1.86]); }
	for (let i = 0; i < 6; i++) spawnTarget();
}

// The active checkpoint glows; passed ones are glossy paint.
const markerOn = pbr(0x9fe05a, 0.35), markerOff = pbr(0xff6a3a, 0.3);
markerOn.emissive.setHex(0x7dff3a); markerOn.emissiveIntensity = 2.5;
function buildRace() {
	// Normal maps need tangents; the shared box and the track ring have indices and UVs.
	box.computeTangents();
	// Surfaces sit on distinct heights (grass top -0.05, asphalt 0, paint 0.012..0.04, markers to 0.09), so no two
	// faces are coplanar: coplanar faces flicker between hits (z-fighting).
	const grass = surface(0x5f7f45, 256, 1, [8, 24, 64], 0.45, [0.75, 0.98], 3, 80);
	cube(grass, [0, -0.3, 0], [160, 0.5, 160]);
	const ring = new THREE.RingGeometry(14, 22, 192, 4); ring.rotateX(-Math.PI / 2); ring.computeTangents(); geometries.add(ring);
	// Asphalt: fine aggregate, a polished racing line (smoother, darker) and worn patches.
	const asphalt = surface(0x34393d, 256, 2, [16, 48, 128], 0.3, [0.3, 0.75], 2.5, 48);
	mesh(ring, asphalt, [0, 0, 0], [1, 1, 1]);
	// Kerb barriers: alternating glossy red and white paint over a concrete base, bases sunk into the grass.
	const kerbRed = pbr(0xc8202a, 0.3), kerbWhite = pbr(0xf2f2ec, 0.32);
	for (const radius of [13.7, 22.3]) {
		const red = new THREE.InstancedMesh(box, kerbRed, 36), white = new THREE.InstancedMesh(box, kerbWhite, 36);
		for (let i = 0; i < 72; i++) {
			const a = i / 72 * Math.PI * 2;
			const m = new THREE.Matrix4().compose(new THREE.Vector3(Math.cos(a) * radius, 0.2, Math.sin(a) * radius), new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), -a), new THREE.Vector3(0.35, 0.5, 1));
			(i % 2 ? white : red).setMatrixAt(i >> 1, m);
		}
		scene.add(red, white);
	}
	// Lane paint: slightly raised, semi-gloss.
	const paint = pbr(0xeeeee6, 0.45);
	const stripe = new THREE.InstancedMesh(box, paint, 48);
	for (let i = 0; i < 48; i++) {
		const a = i / 48 * Math.PI * 2;
		stripe.setMatrixAt(i, new THREE.Matrix4().compose(new THREE.Vector3(Math.cos(a) * trackRadius, 0.026, Math.sin(a) * trackRadius), new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), -a), new THREE.Vector3(0.1, 0.028, 0.65)));
	}
	scene.add(stripe);
	for (let i = 0; i < 4; i++) {
		const a = Math.PI + i * Math.PI / 2;
		// Wider than the lane stripe under it and higher: the stripe stays inside, no shared faces.
		const marker = cube(i === 0 ? markerOn : markerOff, [Math.cos(a) * 18, 0.05, Math.sin(a) * 18], [8, 0.08, 0.4]); marker.rotation.y = -a; checkpointMarkers.push(marker);
	}
	// Trees: rough bark, foliage with leafy albedo and normal variation; trunks start below the grass.
	const bark = surface(0x5a4130, 128, 3, [6, 20], 0.6, [0.8, 0.95], 4, 2);
	const leaves = pbr(0x5d8f3a, 0.6);
	for (let i = 0; i < 12; i++) {
		const a = i * 2.4, radius = 6 + (i % 3) * 1.5;
		cube(bark, [Math.cos(a) * radius, 0.95, Math.sin(a) * radius], [0.35, 2.1, 0.35]);
		mesh(sphere, leaves, [Math.cos(a) * radius, 2.5, Math.sin(a) * radius], [1.2, 1.6, 1.2]);
	}
	// Pit buildings: concrete with a glass window band (proud of the wall) and a cap that overhangs on every side.
	const concrete = surface(0xc9cbc2, 256, 4, [12, 40], 0.12, [0.55, 0.9], 0.8, 2);
	const glass = pbr(0x0e1a20, 0.04);
	for (const x of [-26, 26]) {
		cube(concrete, [x, 1.5, 0], [3, 3, 15]);
		cube(striped, [x, 3.1, 0], [3.2, 0.2, 15.2]);
		cube(glass, [x - Math.sign(x) * 1.52, 1.9, 0], [0.06, 0.9, 13]);
	}
	// Start gantry: brushed steel; the beam is narrower than the posts it rests in.
	const steel = pbr(0xc9ccd1, 0.28, 1);
	cube(steel, [-1, 3.8, 18], [0.3, 0.35, 9.4]);
	for (const z of [13.5, 22.5]) cube(steel, [-1, 1.9, z], [0.4, 3.8, 0.4]);
	// Car: metallic paint, dark glass cabin, rubber tires, chrome trim, head and tail lights.
	const carPaint = pbr(0xff5a1f, 0.22, 0.45), carGlass = pbr(0x081014, 0.03), rubber = pbr(0x141618, 0.85);
	const chrome = pbr(0xe8e8e8, 0.08, 1), headlight = pbr(0xffffff, 0.2), taillight = pbr(0x330000, 0.3);
	headlight.emissive.setHex(0xfff1d6); headlight.emissiveIntensity = 6;
	taillight.emissive.setHex(0xff1a10); taillight.emissiveIntensity = 3;
	scene.add(car); cube(carPaint, [0, 0.55, 0], [1.35, 0.45, 2.4], car); cube(carGlass, [0, 0.95, -0.1], [1.1, 0.5, 1.1], car);
	cube(kerbWhite, [0, 0.79, 0.82], [0.16, 0.05, 0.7], car);
	for (const x of [-0.7, 0.7]) for (const z of [-0.75, 0.75]) cube(rubber, [x, 0.35, z], [0.3, 0.55, 0.55], car);
	cube(chrome, [0, 0.6, 1.22], [1, 0.14, 0.06], car);
	for (const x of [-0.45, 0.45]) { cube(headlight, [x, 0.66, 1.215], [0.22, 0.08, 0.04], car); cube(taillight, [x, 0.66, -1.215], [0.26, 0.08, 0.04], car); }
	resetCar();
}
function resetCar() { car.position.set(0, 0, 18); yaw = -Math.PI / 2; speed = 0; car.rotation.y = yaw; updateRaceCamera(1); }
function updateRaceCamera(blend: number) {
	const forward = new THREE.Vector3(Math.sin(yaw), 0, Math.cos(yaw));
	const desired = car.position.clone().addScaledVector(forward, -8).add(new THREE.Vector3(0, 5.4, 0));
	camera.position.lerp(desired, blend); camera.lookAt(car.position.clone().addScaledVector(forward, 4).add(new THREE.Vector3(0, 0.5, 0)));
}
if (mode === 'aim') buildAim(); else buildRace();

function showCard(tag: string, title: string, copy: string, button: string) {
	$('overlay').classList.remove('hidden'); $('card-tag').textContent = tag; $('card-title').textContent = title; $('card-copy').textContent = copy; $('start').textContent = button;
}
function begin() {
	if (!ready || debugConsole?.isOpen || gpuProfilerPanel?.isOpen) return;
	if (finished) restart();
	playing = true; lastTime = performance.now(); $('overlay').classList.add('hidden'); document.body.classList.add('playing'); $('pause').textContent = 'PAUSE';
}
function pause() {
	if (!ready || finished) return;
	if (!playing) { begin(); return; }
	playing = false; keys.clear(); document.body.classList.remove('playing'); $('pause').textContent = 'RESUME';
	showCard('TAKE A BREATH', 'Session paused', 'Your session is right where you left it.', 'RESUME');
}
function restart() {
	elapsed = hits = shots = combo = score = laps = checkpoint = lapStart = collisions = 0; bestLap = Infinity; finished = false; pendingSpawn = 0;
	for (const d of debris) scene.remove(d.mesh); debris.length = 0;
	if (mode === 'aim') {
		for (const t of targets) scene.remove(t.mesh); targets.length = 0; for (let i = 0; i < 6; i++) spawnTarget();
		targetMaterial.color.setHex(0xff6c41); targetGeometry.getAttribute('position').array.set(targetPositions); targetGeometry.getAttribute('position').needsUpdate = true;
	}
	else { resetCar(); checkpointMarkers.forEach((m, i) => { m.material = i === 0 ? markerOn : markerOff; }); }
	paintTexture(0); begin();
}
function finish() {
	playing = false; finished = true; document.body.classList.remove('playing'); keys.clear();
	showCard('SESSION COMPLETE', mode === 'aim' ? `${score} POINTS` : `${elapsed.toFixed(2)} SECONDS`, mode === 'aim'
		? `${hits} hits · ${shots ? Math.round(hits / shots * 100) : 0}% accuracy. Ready to beat your score?`
		: `Three laps complete. Best lap ${bestLap.toFixed(2)}s · ${collisions} barrier contacts.`, 'PLAY AGAIN');
}
$('start').onclick = begin; $('pause').onclick = pause; $('reset').onclick = restart;
// NRD loads once; afterwards switching only toggles the setting, keeping its textures and pipelines.
const denoiser = $<HTMLSelectElement>('denoiser');
if (new URLSearchParams(location.search).get('nrd') === '1') {
	denoiser.value = 'nrd';
	document.querySelectorAll<HTMLAnchorElement>('a[href^="?game="]').forEach(a => { a.href += '&nrd=1'; });
}
async function applyDenoiser() {
	if (!renderer) return;
	const value = denoiser.value;
	try {
		// Each mode loads once; switching back and forth keeps its resources. SSSR (the realtime default, diffuse
		// ray traced lighting + FidelityFX reflections) takes precedence over NRD, so the other modes disable it.
		const nrd = value !== 'taa' && value !== 'sssr';
		if (nrd) await renderer.setNrd(true, value === 'radiance' ? 'radiance' : 'sh');
		renderer.settings.sssrEnabled = value === 'sssr';
		renderer.settings.nrdEnabled = nrd;
		renderer.settings.nrdDebug = value === 'noisy' ? 1 : 0;
	} catch (error) { denoiser.value = 'taa'; toast(`NRD UNAVAILABLE: ${String(error).replace(/^Error: /, '')}`); }
}
denoiser.onchange = () => { void applyDenoiser(); };
// Quality presets choose FSR 3's render resolution; the presentation stays at full resolution (1 = native AA).
$<HTMLSelectElement>('quality').onchange = event => { if (renderer) renderer.settings.upscaleRenderScale = Number((event.target as HTMLSelectElement).value); };
window.addEventListener('keydown', e => {
	if (debugConsole?.isOpen || gpuProfilerPanel?.isOpen || consoleBusy || (e.target instanceof HTMLElement && e.target.matches('input,textarea,select,[contenteditable]'))) return;
	if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) e.preventDefault();
	if (e.code === 'Space' && !e.repeat) pause();
	if (e.code === 'KeyR' && !e.repeat && ready) { if (mode === 'race' && playing) { resetCar(); checkpoint = 0; lapStart = elapsed; checkpointMarkers.forEach((m, i) => { m.material = i === 0 ? markerOn : markerOff; }); toast('BACK ON TRACK'); } else restart(); }
	keys.add(e.code);
});
window.addEventListener('keyup', e => keys.delete(e.code));
window.addEventListener('blur', () => { keys.clear(); if (playing) pause(); });
document.addEventListener('visibilitychange', () => { if (document.hidden && playing) pause(); });
canvas.addEventListener('pointermove', e => {
	$('crosshair').style.left = `${e.clientX}px`; $('crosshair').style.top = `${e.clientY}px`;
});
canvas.addEventListener('pointerdown', e => {
	if (mode !== 'aim' || !playing || debugConsole?.isOpen || gpuProfilerPanel?.isOpen || consoleBusy || e.button !== 0) return;
	const rect = canvas.getBoundingClientRect(); pointer.set((e.clientX - rect.left) / rect.width * 2 - 1, 1 - (e.clientY - rect.top) / rect.height * 2);
	camera.updateMatrixWorld(); scene.updateMatrixWorld(); raycaster.setFromCamera(pointer, camera);
	shots++; const hit = raycaster.intersectObjects(targets.map(t => t.mesh), false)[0];
	if (!hit) { combo = 0; toast('MISS', 0.4); return; }
	const index = targets.findIndex(t => t.mesh === hit.object), target = targets.splice(index, 1)[0]; scene.remove(target.mesh); pendingSpawn++;
	hits++; combo++; score += 100 + Math.min(combo - 1, 10) * 10; paintTexture(hits);
	targetMaterial.color.setHSL(0.04 + (hits % 5) * 0.025, 0.95, 0.6);
	const positions = targetGeometry.getAttribute('position');
	for (let i = 0; i < positions.array.length; i++) positions.array[i] = targetPositions[i] * (0.92 + (hits % 3) * 0.04);
	positions.needsUpdate = true;
	for (let i = 0; i < 5; i++) {
		const piece = mesh(box, green, target.mesh.position.toArray(), [0.1, 0.1, 0.1]);
		debris.push({ mesh: piece, velocity: new THREE.Vector3((i - 2) * 2, 2 + i * 0.3, 2 - i * 0.5), ttl: 0.32 });
	}
	toast(combo > 1 ? `${combo} HIT STREAK` : '+100', 0.6);
});

function tick(dt: number) {
	if (performance.now() > toastUntil) $('toast').textContent = '';
	if (playing && !debugConsole?.isOpen && !consoleBusy) {
		elapsed += dt;
		if (mode === 'aim') {
			for (const t of targets) { t.mesh.position.x = t.base.x + Math.sin(elapsed * 1.5 + t.phase) * 0.55; t.mesh.position.y = t.base.y + Math.cos(elapsed + t.phase) * 0.15; }
			for (let i = debris.length - 1; i >= 0; i--) { const d = debris[i]; d.ttl -= dt; d.mesh.position.addScaledVector(d.velocity, dt); d.velocity.y -= dt * 8; d.mesh.rotation.x += dt * 5; if (d.ttl <= 0) { scene.remove(d.mesh); debris.splice(i, 1); } }
			if (!debris.length && pendingSpawn) { while (pendingSpawn > 0) { spawnTarget(); pendingSpawn--; } }
			if (elapsed >= 45) finish();
		} else {
			const throttle = keys.has('KeyW') || keys.has('ArrowUp'), brake = keys.has('KeyS') || keys.has('ArrowDown');
			const steer = Number(keys.has('KeyA') || keys.has('ArrowLeft')) - Number(keys.has('KeyD') || keys.has('ArrowRight'));
			speed = THREE.MathUtils.clamp(speed + (Number(throttle) * 11 - Number(brake) * 16 - speed * 0.32) * dt, -5, 22);
			yaw += steer * dt * Math.min(Math.abs(speed) / 6, 1.4) * Math.sign(speed || 1);
			car.position.x += Math.sin(yaw) * speed * dt; car.position.z += Math.cos(yaw) * speed * dt; car.rotation.y = yaw;
			const radius = Math.hypot(car.position.x, car.position.z);
			if (radius < 14.6 || radius > 21.4) { const clamped = THREE.MathUtils.clamp(radius, 14.6, 21.4); car.position.multiplyScalar(clamped / radius); if (Math.abs(speed) > 5) { collisions++; toast('BARRIER CONTACT', 0.6); } speed *= 0.65; }
			const targetAngle = Math.PI + checkpoint * Math.PI / 2;
			const target = new THREE.Vector3(Math.cos(targetAngle) * 18, 0, Math.sin(targetAngle) * 18);
			if (car.position.distanceTo(target) < 4.2 && speed > 1) {
				checkpointMarkers[checkpoint].material = markerOff; checkpoint++;
				if (checkpoint === 4) { checkpoint = 0; laps++; bestLap = Math.min(bestLap, elapsed - lapStart); lapStart = elapsed; paintTexture(laps); toast(`LAP ${laps} COMPLETE`); if (laps >= 3) finish(); }
				else toast('CHECKPOINT', 0.5);
				checkpointMarkers[checkpoint].material = markerOn;
			}
			updateRaceCamera(1 - Math.exp(-dt * 7));
		}
	}
	$('label1').textContent = mode === 'aim' ? 'SCORE' : 'SPEED'; $('value1').textContent = mode === 'aim' ? String(score).padStart(4, '0') : `${Math.round(Math.abs(speed) * 5)} KM/H`;
	$('label2').textContent = mode === 'aim' ? 'ACCURACY' : 'LAP'; $('value2').textContent = mode === 'aim' ? `${shots ? Math.round(hits / shots * 100) : 100}%` : `${Math.min(laps + 1, 3)} / 3`;
	$('label3').textContent = mode === 'aim' ? 'TIME LEFT' : 'TIME'; $('value3').textContent = mode === 'aim' ? `${Math.max(0, 45 - elapsed).toFixed(1)}s` : `${elapsed.toFixed(1)}s`;
	const marker = document.getElementById('map-car')!; marker.setAttribute('cx', String(60 + car.position.x / 18 * 39)); marker.setAttribute('cy', String(60 + car.position.z / 18 * 39));
}

async function loop(now: number) {
	if (closed) return;
	const dt = Math.min((now - lastTime) / 1000, 0.25); lastTime = now;
	if (consoleBusy) { requestAnimationFrame(loop); return; }
	try {
		const steps = Math.max(1, Math.ceil(dt / 0.02)); for (let i = 0; i < steps; i++) tick(dt / steps);
		camera.aspect = canvas.clientWidth / canvas.clientHeight; camera.updateProjectionMatrix();
		sceneSync = adapter.sync(scene, camera);
		await sceneSync;
		if (closed) return;
		if (consoleBusy) { requestAnimationFrame(loop); return; }
		renderer.renderFrame({ scene: adapter.scene, view: adapter.view(camera), frameIndex: frame++ });
		requestAnimationFrame(loop);
	} catch (error) { showError(error); }
}
function showError(error: unknown) {
	if (closed) return;
	console.error(error); playing = false; showCard('UNABLE TO CONTINUE', 'Renderer needs attention', String(error), 'RELOAD');
	$<HTMLButtonElement>('start').disabled = false; $('start').onclick = () => location.reload();
}

async function init() {
	renderer = await Renderer.create(canvas, {
		denoiser: null,
		onProgress: p => { $('card-copy').textContent = p.progress === 1 ? 'Renderer ready; preparing the game scene' : p.message; $('load-progress').style.width = `${p.progress * 25}%`; },
		onSceneProgress: p => { $('card-copy').textContent = p.message; $('load-progress').style.width = `${25 + p.progress * 75}%`; },
	});
	if (closed) { renderer.destroy(); return; }
	renderer.settings.realtimeMaxBounces = 3; renderer.settings.upscaleRenderScale = 0.5; renderer.settings.localExposureMethod = LocalExposureMethod.None;
	renderer.settings.renderMode = 'realtime';
	// A lower sun: longer shadows and grazing highlights on the glossy surfaces.
	renderer.sun.elevation = mode === 'race' ? 38 : 55; renderer.sun.azimuth = mode === 'race' ? 35 : 20;
	adapter = new ThreeAdapter(renderer); await adapter.sync(scene, camera);
	gpuProfilerPanel = new GpuProfilerPanel(renderer.gpuProfiler, { onOpenChange: () => keys.clear() });
	debugConsole = new DebugConsole(createRendererConsole(renderer, {
		cameraFov: { get: () => camera.fov, set: degrees => { camera.fov = degrees; camera.updateProjectionMatrix(); } },
		execute: async action => {
			consoleBusy = true;
			try { await sceneSync; if (closed) throw new Error('Game was closed'); return await action(); }
			finally { consoleBusy = false; lastTime = performance.now(); }
		},
	}), { onOpenChange: open => { keys.clear(); lastTime = performance.now(); document.body.classList.toggle('console-open', open); } });
	await applyDenoiser();
	ready = true; for (const id of ['start', 'pause', 'reset']) $<HTMLButtonElement>(id).disabled = false;
	$('load-progress').style.width = '100%';
	showCard(mode === 'aim' ? '45 SECOND DRILL' : 'THREE LAP CHALLENGE', mode === 'aim' ? 'Fast hands. Clear mind.' : 'Find the perfect line.', mode === 'aim' ? 'Click the moving targets. Build a streak for bonus points. Six targets, forty-five seconds, no second chances.' : 'W to accelerate, S to brake. A and D to steer. Follow the green checkpoint and finish three laps. R puts you back on track.', 'START SESSION');
	Object.assign(window, { __games: {
		get ready() { return ready; }, get frame() { return frame; }, get state() { return { mode, playing, finished, elapsed, hits, shots, score, laps, checkpoint, speed, collisions, position: car.position.toArray() }; },
		get stats() { return { resources: adapter.scene.stats, gpu: renderer.hostSceneStats(adapter.scene), revision: adapter.scene.revision }; },
		targets: () => targets.map(t => { const p = t.mesh.position.clone().project(camera); return { x: (p.x + 1) / 2 * canvas.clientWidth, y: (1 - p.y) / 2 * canvas.clientHeight }; }),
		// Explicit test surface: real host objects, no alternate rendering path.
		scene, camera, renderer, adapter, texture, car, debugConsole, gpuProfilerPanel,
	} });
	lastTime = performance.now(); requestAnimationFrame(loop);
}
window.addEventListener('pagehide', () => { closed = true; gpuProfilerPanel?.dispose(); debugConsole?.dispose(); adapter?.dispose(); renderer?.destroy(); for (const g of geometries) g.dispose(); for (const m of materials) m.dispose(); texture.dispose(); for (const t of textures) t.dispose(); });
window.addEventListener('pageshow', event => { if (event.persisted) location.reload(); });
init().catch(showError);
