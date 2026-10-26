// The core entry (`@tianyuliwiwo/veach`) must load without a DOM (Node, SSR, workers); the DOM-dependent
// <veach-view> lives in `@tianyuliwiwo/veach/view`.
import { describe, expect, it } from 'vitest';

describe('package entry points', () => {
	it('imports the core entry without a DOM', async () => {
		expect(typeof (globalThis as { HTMLElement?: unknown }).HTMLElement).toBe('undefined');
		const core = await import('../src/index');
		expect(typeof core.Renderer.create).toBe('function');
		expect(typeof core.loadGLTF).toBe('function');
		expect('VeachViewElement' in core).toBe(false);
	});
});
