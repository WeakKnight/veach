// Renderer settings for a loaded .blend: world background, sun, color management.
import type { BlendScene } from '../loaders/blend/BlendLoader';
import { translateWorld } from '../loaders/blend/BlendNodes';
import type { Vec3 } from '../math/Math';
import { AutoExposureMethod } from '../render/AutoExposure';
import { Tonemapper } from '../render/GpuLayout';
import { LocalExposureMethod, type Renderer } from '../render/Renderer';

// Veach's outer-space sun irradiance for a Sky Texture sun intensity of 1.
const SKY_SUN_IRRADIANCE = Math.PI;

function setSun(renderer: Renderer, direction: Vec3, irradiance: Vec3, angle: number): void {
	const [x, y, z] = direction;
	renderer.sun.enabled = true;
	renderer.sun.elevation = (Math.asin(Math.max(-1, Math.min(1, y))) * 180) / Math.PI;
	renderer.sun.azimuth = (Math.atan2(x, z) * 180) / Math.PI;
	const peak = Math.max(...irradiance);
	renderer.sun.irradiance = peak;
	renderer.sun.color = peak > 0 ? (irradiance.map((v) => v / peak) as Vec3) : [1, 1, 1];
	renderer.sun.angularDiameter = Math.max((angle * 180) / Math.PI, 0.01);
}

export function applyBlendSettings(renderer: Renderer, blend: BlendScene): string[] {
	const warnings: string[] = [];
	const world = blend.world ? translateWorld(blend.world) : null;
	warnings.push(...(world?.warnings ?? []));
	const s = renderer.settings;
	s.environmentIntensity = 1;
	renderer.sun.enabled = false;

	const sky = world?.sky;
	if (sky) {
		// Sky Texture -> Veach's atmosphere, which follows the sun. A sun lamp takes over the sun; the sky
		// brightness then stays that of the Sky Texture's own sun.
		const elevation = sky.num('sun_elevation', 0, 0.26);
		const rotation = sky.num('sun_rotation', 0, 0);
		const intensity = sky.num('sun_intensity', 0, 1) * world.strength;
		const blenderDir: Vec3 = [Math.sin(rotation) * Math.cos(elevation), Math.cos(rotation) * Math.cos(elevation), Math.sin(elevation)];
		const skyIrradiance = SKY_SUN_IRRADIANCE * intensity;
		renderer.setEnvironment(null);
		if (blend.sun) {
			setSun(renderer, blend.sun.direction, blend.sun.irradiance, blend.sun.angle);
			s.environmentIntensity = skyIrradiance / Math.max(renderer.sun.irradiance, 1e-6);
		} else {
			setSun(renderer, [blenderDir[0], blenderDir[2], -blenderDir[1]], [skyIrradiance, skyIrradiance, skyIrradiance], sky.num('sun_size', 0, 0.01));
			renderer.sun.enabled = sky.num('sun_disc', 0, 1) !== 0;
		}
		if (sky.num('air_density', 0, 1) !== 1 || sky.num('dust_density', 0, 1) !== 1 || sky.num('ozone_density', 0, 1) !== 1) {
			warnings.push('world: Sky Texture air / dust / ozone densities are not supported');
		}
	} else {
		const c = world?.color ?? [0.05, 0.05, 0.05];
		const width = 8;
		const height = 4;
		const data = new Float32Array(width * height * 4);
		for (let i = 0; i < width * height; i++) {
			data.set([c[0], c[1], c[2], 1], i * 4);
		}
		renderer.setEnvironment({ width, height, data });
		if (blend.sun) {
			setSun(renderer, blend.sun.direction, blend.sun.irradiance, blend.sun.angle);
		}
	}

	const view = blend.render.viewTransform;
	s.tonemapper = view === 'Filmic' ? Tonemapper.ACESFilmic : view === 'AgX' ? Tonemapper.ACES2 : Tonemapper.None;
	s.autoExposureMethod = AutoExposureMethod.Manual;
	s.autoExposureBias = blend.render.exposure;
	s.localExposureMethod = LocalExposureMethod.None;
	s.environmentVisible = true;
	s.maxBounces = 12;
	return warnings;
}
