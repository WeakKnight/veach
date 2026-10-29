import { describe, expect, it, vi } from 'vitest';
import { ConsoleRegistry, consoleNumber } from '../src/debug/ConsoleRegistry';
import { createRendererConsole, renderConsoleSettings } from '../src/debug/RendererConsole';
import { defaultRenderSettings, type Renderer } from '../src/render/Renderer';
import { defaultSharcSettings } from '../src/render/SharcCache';

describe('runtime rendering console', () => {
	it('queries, completes and parses case-insensitive typed values without evaluating input', async () => {
		let value = 8;
		const registry = new ConsoleRegistry();
		registry.register({ name: 'r.Path.Bounces', help: 'Bounce limit', usage: '0..128', get: () => value, set: s => { value = consoleNumber(0, 128, true).parse(s); } });
		expect((await registry.execute('R.PATH.BOUNCES=4')).lines).toEqual(['r.Path.Bounces = 4']);
		expect(registry.complete('r.pa')).toEqual(['r.Path.Bounces']);
		expect((await registry.execute('r.Path.Bounces?')).lines).toContain('Bounce limit');
		for (const input of ['NaN', '-1', '2.5', '4; alert(1)', 'Infinity']) expect((await registry.execute(`r.Path.Bounces ${input}`)).ok).toBe(false);
		expect(value).toBe(4);
		expect((await registry.execute('r.unknown')).ok).toBe(false);
	});
	it('serializes asynchronous pipeline commands and recovers after rejection', async () => {
		const events: string[] = [];
		let release!: () => void;
		const barrier = new Promise<void>(resolve => { release = resolve; });
		const registry = new ConsoleRegistry();
		registry.register({ name: 'r.Test.Async', help: '', run: async input => { events.push(input); if (input === 'first') await barrier; else if (input === 'bad') throw new Error('Rejected'); events.push(`${input}:done`); } });
		const first = registry.execute('r.Test.Async first'), second = registry.execute('r.Test.Async second');
		await Promise.resolve(); expect(events).toEqual(['first']);
		release(); await Promise.all([first, second]); expect(events).toEqual(['first', 'first:done', 'second', 'second:done']);
		expect((await registry.execute('r.Test.Async bad')).ok).toBe(false);
		expect((await registry.execute('r.Test.Async last')).ok).toBe(true);
	});
	it('covers public settings, preserves presentation accumulation and rejects invalid paired ranges before mutation', async () => {
		const reset = vi.fn(), settings = defaultRenderSettings();
		const renderer = { settings, resetAccumulation: reset } as unknown as Renderer;
		const registry = createRendererConsole(renderer);
		expect(Object.keys(renderConsoleSettings).sort()).toEqual(Object.keys(settings).sort());
		await registry.execute('r.Exposure.Bias 2'); await registry.execute('r.LocalExposure.Method None');
		expect(settings.autoExposureBias).toBe(2); expect(reset).not.toHaveBeenCalled();
		expect((await registry.execute('r.Exposure.LowPercent 99')).ok).toBe(false);
		expect(settings.autoExposureLowPercent).toBe(10);
		await registry.execute('r.PathTracing.MaxBounces 4'); expect(reset).toHaveBeenCalledTimes(1);
		expect(settings.maxBounces).toBe(4);
	});
	it('reads current SHARC configuration and routes host FOV to the host camera', async () => {
		let fov = 55;
		const options = { ...defaultSharcSettings }, setSharc = vi.fn(async (_enabled, v) => Object.assign(options, v));
		const renderer = { settings: defaultRenderSettings(), sharcSettings: options, sharcEnabled: true, setSharc, resetAccumulation: vi.fn() } as unknown as Renderer;
		const registry = createRendererConsole(renderer, { cameraFov: { get: () => fov, set: v => { fov = v; } } });
		await registry.execute('r.SHARC.VoxelSize 0.2');
		expect(setSharc).toHaveBeenCalledWith(true, { voxelSize: 0.2 });
		options.voxelSize = 0.4;
		expect((await registry.execute('r.SHARC.VoxelSize')).lines).toEqual(['r.SHARC.VoxelSize = 0.4']);
		await registry.execute('r.Camera.FOV 75'); expect(fov).toBe(75);
		expect(registry.list().some(e => e.name === 'r.Camera.LensRadius')).toBe(false);
	});
});
