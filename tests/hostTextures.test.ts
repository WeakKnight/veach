import { beforeEach, describe, expect, it, vi } from 'vitest';
import { HostTextureSystem, type PreparedHostTextures } from '../src/render/vt/HostTextureSystem';
import { RenderScene } from '../src/scene/RenderScene';

beforeEach(() => {
	vi.stubGlobal('GPUTextureUsage', { TEXTURE_BINDING: 4, COPY_DST: 2 });
	vi.stubGlobal('GPUBufferUsage', { COPY_DST: 8, MAP_READ: 1 });
	vi.stubGlobal('GPUMapMode', { READ: 1 });
});

function fixture() {
	const uploads: { label: string; bytes: Uint8Array }[] = [];
	const maps: (() => void)[] = [];
	const device = {
		limits: { maxTextureDimension2D: 8192 },
		createTexture: ({ size, label }: { size: number[]; label: string }) => ({ width: size[0], height: size[1], label, destroy: vi.fn() }),
		createBuffer: ({ size }: GPUBufferDescriptor) => ({ size, destroy: vi.fn(), unmap: vi.fn(),
			mapAsync: () => new Promise<void>(resolve => maps.push(resolve)),
			getMappedRange: () => { const bytes = new ArrayBuffer(size); new Uint32Array(bytes)[0] = 1; return bytes; } }),
		queue: { writeTexture: ({ texture }: { texture: GPUTexture }, bytes: ArrayBufferView) => uploads.push({ label: texture.label, bytes: new Uint8Array(bytes.buffer, bytes.byteOffset, bytes.byteLength).slice() }) },
	} as unknown as GPUDevice;
	const system = new HostTextureSystem(device, { physicalTilesPerRow: 2, speculativeFill: false });
	let plan!: PreparedHostTextures;
	const scene = new RenderScene(async snapshot => { plan = await system.prepare(snapshot); plan.publish(); }, () => system.destroy());
	return { system, scene, uploads, maps, plan: () => plan };
}

describe('persistent host virtual textures', () => {
	it('preserves residency and uploads only the changed source', async () => {
		const f = fixture(), u = f.scene.beginUpdate();
		const red = u.createTexture({ source: { width: 1, height: 1, data: new Uint8Array([255, 0, 0, 255]) }, colorSpace: 'srgb' });
		const blue = u.createTexture({ source: { width: 1, height: 1, data: new Uint8Array([0, 0, 255, 255]) }, colorSpace: 'srgb' });
		const m = u.createMaterial({ baseColorMap: { texture: red }, emissionMap: { texture: blue } }); await u.commit();
		expect(f.system.stats.totalUploads).toBe(2);
		const descriptor = f.plan().descriptorOf(f.plan().resolve({ texture: blue }).source);
		const uniform = f.scene.beginUpdate(); uniform.setMaterial(m, { roughness: 0.2, baseColorMap: { texture: red }, emissionMap: { texture: blue } }); await uniform.commit();
		expect(f.system.stats.totalUploads).toBe(2);
		const pixels = f.scene.beginUpdate(); pixels.setTexture(red, { source: { width: 1, height: 1, data: new Uint8Array([0, 255, 0, 255]) }, colorSpace: 'srgb' }); await pixels.commit();
		expect(f.system.stats.totalUploads).toBe(3);
		expect(f.plan().descriptorOf(f.plan().resolve({ texture: blue }).source)).toEqual(descriptor);
		expect([...f.uploads.filter(u => u.label === 'host:vtPhysical').at(-1)!.bytes.slice(0, 4)]).toEqual([0, 255, 0, 255]);
		f.scene.dispose();
	});

	it('uses independent bordered variants for different wrap modes', async () => {
		const f = fixture(), u = f.scene.beginUpdate();
		const t = u.createTexture({ source: { width: 2, height: 1, data: new Uint8Array([255, 0, 0, 255, 0, 0, 255, 255]) }, colorSpace: 'linear' });
		u.createMaterial({ baseColorMap: { texture: t, wrapU: 'repeat' }, emissionMap: { texture: t, wrapU: 'clamp' } }); await u.commit();
		const a = f.plan().resolve({ texture: t, wrapU: 'repeat' }), b = f.plan().resolve({ texture: t, wrapU: 'clamp' });
		expect(a.source).not.toBe(b.source); expect(f.system.stats.textures).toBe(2);
		const tiles = f.uploads.filter(u => u.label === 'host:vtPhysical');
		expect([...tiles[0].bytes.slice(4, 8)]).not.toEqual([...tiles[1].bytes.slice(4, 8)]);
		f.scene.dispose();
	});

	it('discards stale feedback after texture replacement at a recycled address', async () => {
		const f = fixture(), u = f.scene.beginUpdate();
		const t = u.createTexture({ source: { width: 256, height: 256, data: new Uint8Array(256 * 256 * 4) }, colorSpace: 'linear' });
		const m = u.createMaterial({ baseColorMap: { texture: t } }); await u.commit();
		f.system.recordFeedbackReadback({ copyTextureToBuffer: vi.fn() } as unknown as GPUCommandEncoder, { width: 1, height: 1 } as GPUTexture);
		f.system.afterSubmit();
		const replace = f.scene.beginUpdate(); replace.releaseTexture(t);
		const next = replace.createTexture({ source: { width: 256, height: 256, data: new Uint8Array(256 * 256 * 4) }, colorSpace: 'linear' });
		replace.setMaterial(m, { baseColorMap: { texture: next } }); await replace.commit();
		const before = f.system.stats.totalUploads;
		f.maps[0](); await Promise.resolve(); await Promise.resolve();
		expect(f.system.update().feedbackFrames).toBe(0);
		expect(f.system.stats.totalUploads).toBe(before);
		f.scene.dispose();
	});

	it('reclaims released tails and refuses overcommitted tail capacity', async () => {
		const f = fixture(), u = f.scene.beginUpdate();
		const t = u.createTexture({ source: { width: 1, height: 1, data: new Uint8Array(4) }, colorSpace: 'linear' });
		const m = u.createMaterial({ baseColorMap: { texture: t } }); await u.commit();
		const release = f.scene.beginUpdate(); release.releaseMaterial(m); release.releaseTexture(t); await release.commit();
		expect(f.system.stats.textures).toBe(0); expect(f.system.stats.residentPages).toBe(0);
		const tooMany = f.scene.beginUpdate();
		for (let i = 0; i < 4; i++) {
			const id = tooMany.createTexture({ source: { width: 1, height: 1, data: new Uint8Array(4) }, colorSpace: 'linear' });
			tooMany.createMaterial({ baseColorMap: { texture: id } });
		}
		await expect(tooMany.commit()).rejects.toThrow('mip tails');
		expect(f.scene.stats.textures).toBe(0); f.scene.dispose();
	});
});
