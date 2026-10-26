// Thin-lens perspective camera and an orbit / pan / dolly controller.
import { mat4, vec3, type Mat4, type Vec3 } from '../math/Math';

export class Camera {
	position: Vec3 = [0, 1, 5];
	target: Vec3 = [0, 0, 0];
	up: Vec3 = [0, 1, 0];
	fovY = (45 * Math.PI) / 180; // radians
	lensRadius = 0;
	focusDistance = 0; // 0 = distance to target

	basis(aspect: number): { forward: Vec3; right: Vec3; up: Vec3 } {
		const forward = vec3.normalize(vec3.sub(this.target, this.position));
		let right = vec3.cross(forward, this.up);
		if (vec3.length(right) < 1e-6) {
			right = vec3.cross(forward, Math.abs(forward[2]) < 0.9 ? [0, 0, 1] : [1, 0, 0]);
		}
		right = vec3.normalize(right);
		const up = vec3.cross(right, forward);
		const h = Math.tan(this.fovY / 2);
		return { forward, right: vec3.scale(right, h * aspect), up: vec3.scale(up, h) };
	}

	// glTF camera node: looks down -Z with +Y up.
	setFromMatrix(m: Mat4, distance = 1): void {
		this.position = mat4.transformPoint(m, [0, 0, 0]);
		const forward = vec3.normalize(mat4.transformVector(m, [0, 0, -1]));
		this.up = vec3.normalize(mat4.transformVector(m, [0, 1, 0]));
		this.target = vec3.add(this.position, vec3.scale(forward, distance));
	}

	// Frames an axis-aligned box from the current viewing direction.
	frame(min: Vec3, max: Vec3, aspect = 1): void {
		const center = vec3.scale(vec3.add(min, max), 0.5);
		const radius = Math.max(vec3.length(vec3.sub(max, min)) * 0.5, 1e-3);
		const fov = Math.min(this.fovY, 2 * Math.atan(Math.tan(this.fovY / 2) * aspect));
		const distance = radius / Math.sin(fov / 2);
		let dir = vec3.sub(this.position, this.target);
		if (vec3.length(dir) < 1e-6) dir = [0, 0.3, 1];
		this.target = center;
		this.position = vec3.add(center, vec3.scale(vec3.normalize(dir), distance));
		this.up = [0, 1, 0];
	}

	get effectiveFocusDistance(): number {
		return this.focusDistance > 0 ? this.focusDistance : vec3.length(vec3.sub(this.target, this.position));
	}
}

export class OrbitController {
	rotateSpeed = 0.005;
	private pointers = new Map<number, { x: number; y: number }>();
	private readonly disposers: (() => void)[] = [];

	constructor(
		private readonly camera: Camera,
		private readonly element: HTMLElement,
		private readonly onChange: () => void,
	) {
		const on = <K extends keyof HTMLElementEventMap>(type: K, fn: (e: HTMLElementEventMap[K]) => void, opts?: AddEventListenerOptions) => {
			element.addEventListener(type, fn as EventListener, opts);
			this.disposers.push(() => element.removeEventListener(type, fn as EventListener));
		};
		on('pointerdown', (e) => {
			element.setPointerCapture(e.pointerId);
			this.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
		});
		on('pointerup', (e) => this.pointers.delete(e.pointerId));
		on('pointercancel', (e) => this.pointers.delete(e.pointerId));
		on('pointermove', (e) => {
			const prev = this.pointers.get(e.pointerId);
			if (!prev) return;
			const dx = e.clientX - prev.x;
			const dy = e.clientY - prev.y;
			this.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
			if (this.pointers.size > 1 || e.buttons & 6 || e.shiftKey) {
				this.pan(dx, dy);
			} else {
				this.orbit(dx, dy);
			}
		});
		on('wheel', (e) => {
			e.preventDefault();
			this.dolly(Math.exp(e.deltaY * 0.001));
		}, { passive: false });
		on('contextmenu', (e) => e.preventDefault());
	}

	orbit(dx: number, dy: number): void {
		const c = this.camera;
		const offset = vec3.sub(c.position, c.target);
		const radius = vec3.length(offset);
		let theta = Math.atan2(offset[0], offset[2]);
		let phi = Math.acos(Math.min(Math.max(offset[1] / radius, -1), 1));
		theta -= dx * this.rotateSpeed;
		phi = Math.min(Math.max(phi - dy * this.rotateSpeed, 1e-3), Math.PI - 1e-3);
		c.position = vec3.add(c.target, [radius * Math.sin(phi) * Math.sin(theta), radius * Math.cos(phi), radius * Math.sin(phi) * Math.cos(theta)]);
		c.up = [0, 1, 0];
		this.onChange();
	}

	pan(dx: number, dy: number): void {
		const c = this.camera;
		const distance = vec3.length(vec3.sub(c.position, c.target));
		const scale = (2 * distance * Math.tan(c.fovY / 2)) / Math.max(this.element.clientHeight, 1);
		const { right, up } = c.basis(1);
		const move = vec3.add(vec3.scale(vec3.normalize(right), -dx * scale), vec3.scale(vec3.normalize(up), dy * scale));
		c.position = vec3.add(c.position, move);
		c.target = vec3.add(c.target, move);
		this.onChange();
	}

	dolly(factor: number): void {
		const c = this.camera;
		const offset = vec3.sub(c.position, c.target);
		c.position = vec3.add(c.target, vec3.scale(offset, factor));
		this.onChange();
	}

	dispose(): void {
		for (const d of this.disposers) d();
	}
}
