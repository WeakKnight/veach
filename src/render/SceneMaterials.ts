// Compiles a scene's material graphs for the GPU (docs/MaterialSystem.md) and answers the host's
// questions about them: texture usage for the virtual texture system, emitted radiance.
import { compileMaterial, type CompiledMaterial, type MaterialCompileOptions } from '../material/Compile';
import { defaultSurfaceValues, type ShadingContext } from '../material/Evaluate';
import { defaultMaterialGraph } from '../material/GLTFMaterial';
import { isConstantProgram, runProgram } from '../material/Interpreter';
import { luminance, type Vec3 } from '../math/Math';
import type { SceneDesc, WrapMode } from '../scene/Scene';
import type { CpuTexture } from './vt/TileSource';
import { materialShadeCapacities, type MaterialStackCapacity } from './MaterialCapacity';

export function sceneShadeCapacities(scene: SceneDesc, materials: readonly CompiledMaterial[], separateLight = false): MaterialStackCapacity[] {
	const capacities = materialShadeCapacities(materials, separateLight), fallback = materials.length - 1;
	return [...new Set(scene.instances.map(instance => {
		const material = scene.meshes[instance.mesh].material;
		return capacities[material >= 0 && material < fallback ? material : fallback];
	}))].sort((a, b) => a - b);
}

export interface TextureUsage {
	srgb: boolean;
	wrapS: WrapMode;
	wrapT: WrapMode;
}

// scene.materials followed by the default material (index scene.materials.length).
export function compileSceneMaterials(scene: SceneDesc, options: MaterialCompileOptions = {}): CompiledMaterial[] {
	return [...scene.materials.map((m) => m.graph), defaultMaterialGraph()].map((graph) => {
		try {
			return compileMaterial(graph, options);
		} catch (e) {
			console.warn(`material ${graph.name}: ${e instanceof Error ? e.message : e}; using the default material`);
			return { ...compileMaterial(defaultMaterialGraph(), options), name: graph.name };
		}
	});
}

// Per texture source: decoded as sRGB if any use is, wrap modes of the first use.
export function textureUsage(materials: readonly CompiledMaterial[]): Map<number, TextureUsage> {
	const usage = new Map<number, TextureUsage>();
	for (const m of materials) {
		for (const t of m.textures) {
			const u = usage.get(t.source);
			usage.set(t.source, { srgb: t.colorspace === 'srgb_texture' || (u?.srgb ?? false), wrapS: u?.wrapS ?? t.wrapS, wrapT: u?.wrapT ?? t.wrapT });
		}
	}
	return usage;
}

// Luminance of the emitted radiance at texture coordinates, or null when the material does not
// emit. Textures without a CPU copy count as white, like invalid texture references on the GPU.
export type EmissionLuminance = ((uv0: [number, number], uv1: [number, number], objectPosition: Vec3) => number) | null;

export function emissionLuminance(m: CompiledMaterial, textureOf: (source: number) => CpuTexture | null): EmissionLuminance {
	if (!m.emissive || m.emission < 0) {
		return null;
	}
	const ctx: ShadingContext = {
		uv0: [0, 0],
		uv1: [0, 0],
		position: [0, 0, 0],
		normal: [0, 0, 1],
		tangent: [0, 0, 0, 0],
		sample: (source, [u, v]) => {
			const t = textureOf(source);
			return t ? [...t.sample(u, v, false), 1] : [1, 1, 1, 1];
		},
	};
	const evaluate = () => {
		const out = defaultSurfaceValues(ctx);
		runProgram(m, m.emission, ctx, out);
		const c = out.emission_color;
		return luminance(c[0], c[1], c[2]) * out.emission_luminance[0];
	};
	if (isConstantProgram(m, m.emission)) {
		const value = evaluate();
		return value > 0 ? () => value : null;
	}
	return (uv0, uv1, objectPosition) => {
		ctx.uv0 = uv0;
		ctx.uv1 = uv1;
		ctx.objectPosition = objectPosition;
		return evaluate();
	};
}
