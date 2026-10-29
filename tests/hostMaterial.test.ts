import { describe, expect, it } from 'vitest';
import { hostMaterialGraph } from '../src/material/HostMaterial';
import { compileMaterial } from '../src/material/Compile';
import { evaluateCompiled } from '../src/material/Interpreter';
import type { ShadingContext } from '../src/material/Evaluate';
import type { TextureHandle } from '../src/scene/RenderScene';

const context: ShadingContext = { position: [0, 0, 0], uv0: [0, 0], uv1: [0, 0], normal: [0, 0, 1], tangent: [1, 0, 0, 1], sample: () => [0.2, 0.4, 0.6, 0.8] };
const resolve = () => ({ source: 0, colorSpace: 'lin_rec709' as const });

describe('host PBR materials', () => {
	it('uses independent roughness and metallic maps with explicit channels', () => {
		const graph = hostMaterialGraph({ metallic: 1, roughness: 0.5,
			metallicMap: { texture: 1 as TextureHandle, channel: 0 }, roughnessMap: { texture: 2 as TextureHandle, channel: 2 } }, resolve);
		const out = evaluateCompiled(compileMaterial(graph), context);
		expect(out.base_metalness[0]).toBeCloseTo(0.2);
		expect(out.specular_roughness[0]).toBeCloseTo(0.3);
	});

	it('compiles masked textured material and anisotropic normal scale', () => {
		const m = compileMaterial(hostMaterialGraph({ alphaMode: 'mask', opacity: 0.5,
			baseColorMap: { texture: 1 as TextureHandle }, normalMap: { texture: 2 as TextureHandle }, normalScale: [2, -1] }, resolve));
		const out = evaluateCompiled(m, context);
		expect(m.alphaTested).toBe(true); expect(out.geometry_opacity[0]).toBeCloseTo(0.4);
		expect(out.geometry_normal.every(Number.isFinite)).toBe(true);
	});
});
