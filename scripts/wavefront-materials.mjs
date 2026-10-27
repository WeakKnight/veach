// CPU inspection of the fixed performance scenes: distinguish real VM stack use from
// the capacity compiled into the generic shader, and estimate shader grouping opportunities.
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer } from 'vite';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const option = (name, fallback) => { const index = args.indexOf(`--${name}`); return index < 0 ? fallback : args[index + 1]; };
const scenes = resolve(option('scenes', 'E:/GitHub/gltf-research-scenes/scenes'));
const output = resolve(option('out', join(root, '.tools/wavefront/materials.json')));
const server = await createServer({ root, server: { middlewareMode: true }, logLevel: 'error' });
const hash = value => createHash('sha256').update(value).digest('hex');
try {
	const { parseGLTF } = await server.ssrLoadModule('/src/loaders/GLTFLoader.ts');
	const { compileSceneMaterials } = await server.ssrLoadModule('/src/render/SceneMaterials.ts');
	const { programOps } = await server.ssrLoadModule('/src/material/Interpreter.ts');
	const { Op } = await server.ssrLoadModule('/src/material/Bytecode.ts');
	const results = [];
	for (const [name, file] of [['classroom', 'classroom'], ['breakfast-room', 'breakfast_room'],
		['bmw-m6', 'bmw_m6'], ['glass-of-water', 'glass_of_water'], ['veach-mis', 'veach_mis']]) {
		const bytes = readFileSync(join(scenes, name, 'gltf', `${file}_extended.glb`));
		const scene = await parseGLTF(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
		const compiled = compileSceneMaterials(scene);
		const instanced = new Set(scene.instances.map(instance => {
			const material = scene.meshes[instance.mesh].material;
			return material >= 0 && material < scene.materials.length ? material : compiled.length - 1;
		}));
		const materials = compiled.map((material, index) => {
			const instructions = material.surface < 0 ? [] : programOps(material, material.surface);
			const opcodes = [...new Set([material.surface, material.opacity, material.emission]
				.filter(offset => offset >= 0).flatMap(offset => programOps(material, offset)))].sort((a, b) => a - b);
			return { index, name: material.name, instanced: instanced.has(index), stack: material.stackSize,
				opcodes: opcodes.map(op => Op[op]),
				surfaceInstructions: instructions.length, textures: material.textures.length,
				textureInstructions: instructions.filter(op => op === Op.Texture).length,
				proceduralInstructions: instructions.filter(op => [Op.Noise, Op.Magic, Op.Checker].includes(op)).length,
				codeHash: hash(material.code) };
		});
		const active = materials.filter(material => material.instanced);
		const stackHistogram = {};
		for (const material of active) stackHistogram[material.stack] = (stackHistogram[material.stack] ?? 0) + 1;
		const result = { name, sha256: hash(bytes), totalMaterials: materials.length, instancedMaterials: active.length,
			uniqueCode: new Set(active.map(material => material.codeHash)).size, stackHistogram,
			opcodes: [...new Set(materials.flatMap(material => material.opcodes))].sort(), materials };
		results.push(result);
		console.log(JSON.stringify({ ...result, materials: undefined }));
	}
	mkdirSync(dirname(output), { recursive: true });
	writeFileSync(output, JSON.stringify({ results }, null, 2));
} finally { await server.close(); }
