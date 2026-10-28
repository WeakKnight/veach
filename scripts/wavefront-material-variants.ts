// Benchmark fixture: switch only instruction scheduling while retaining geometry,
// lights and virtual-texture residency. Each variant owns one material buffer.
import { compileSceneMaterials, sceneShadeCapacities } from '../src/render/SceneMaterials';
import { packMaterialData } from '../src/render/GpuLayout';
import { materialOpcodeMask } from '../src/render/MaterialProgramFeatures';
import type { SceneDesc } from '../src/scene/Scene';
import type { VirtualTextureSystem } from '../src/render/vt/VirtualTextureSystem';

export function materialScheduleVariants(device: GPUDevice, scene: SceneDesc, descriptorOf: VirtualTextureSystem['descriptorOf'], originalBuffer: GPUBuffer) {
	const original = compileSceneMaterials(scene, { schedule: false });
	const optimized = compileSceneMaterials(scene, { schedule: true });
	for (let i = 0; i < original.length; i++) {
		const a = original[i], b = optimized[i];
		if (a.alphaTested !== b.alphaTested || a.emissive !== b.emissive || JSON.stringify(a.textures) !== JSON.stringify(b.textures))
			throw new Error('Material scheduling changed scene/texture metadata');
	}
	const data = packMaterialData(optimized, descriptorOf);
	const buffer = device.createBuffer({ label: 'optimizedMaterialSchedule', size: Math.max(16, Math.ceil(data.byteLength / 16) * 16),
		usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST, mappedAtCreation: true });
	new Uint32Array(buffer.getMappedRange()).set(data); buffer.unmap();
	const entry = (materials: typeof original, buffer: GPUBuffer) => ({ buffer,
		shadeCapacities: sceneShadeCapacities(scene, materials), stack: Math.max(0, ...materials.map(m => m.stackSize)), opcodes: materialOpcodeMask(materials) });
	return { original: entry(original, originalBuffer), optimized: entry(optimized, buffer) };
}
