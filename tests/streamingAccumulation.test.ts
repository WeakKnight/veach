import { describe, expect, it, vi } from 'vitest';
import { Renderer, defaultRenderSettings, type RenderSettings } from '../src/render/Renderer';
import { VT_FEEDBACK_PERIOD, type VirtualTextureUpdate } from '../src/render/vt/VirtualTextureSystem';

// Exercise the renderer's actual streaming/reset integration without creating a GPU device.
function harness(samples = 1, maxSamples = 0) {
	const update = { mapped: 0, coverage: 0, feedbackFrames: 1, pendingFeedback: false };
	const stats = { pendingRequests: 0, uploadsLastFrame: 0 };
	const renderer = Object.assign(Object.create(Renderer.prototype), {
		settings: { ...defaultRenderSettings(), maxSamples }, frameIndex: samples,
		streamedCoverage: 0, quietFeedbackFrames: 0,
		vt: { update: () => update, stats },
	}) as {
		frameIndex: number;
		settings: RenderSettings;
		resetAccumulation(): void;
		updateStreaming(): void;
	};
	const resets = vi.spyOn(renderer, 'resetAccumulation');
	const step = (result: Partial<VirtualTextureUpdate> = {}, pending = 0, uploads = result.mapped ?? 0) => {
		Object.assign(update, { mapped: 0, coverage: 0, feedbackFrames: 1, pendingFeedback: false }, result);
		Object.assign(stats, { pendingRequests: pending, uploadsLastFrame: uploads });
		renderer.updateStreaming();
		if (!maxSamples || renderer.frameIndex < maxSamples) renderer.frameIndex++;
	};
	return { renderer, step, resets };
}

describe('streaming accumulation', () => {
	it('keeps accumulating with continuous uploads and pending zero, including at 1 spp', () => {
		const h = harness();
		for (let i = 0; i < 256; i++) h.step({ mapped: 20, coverage: 0.1 });
		expect(h.renderer.frameIndex).toBe(257);
		expect(h.resets).not.toHaveBeenCalled();
		for (let i = 0; i < VT_FEEDBACK_PERIOD; i++) h.step();
		expect(h.resets).toHaveBeenCalledTimes(1);
		for (let i = 0; i < 64; i++) h.step();
		expect(h.resets).toHaveBeenCalledTimes(1);
		expect(h.renderer.frameIndex).toBe(65);
	});

	it('does not mistake intermittent uploads or stalled pending requests for settled streaming', () => {
		const h = harness();
		for (let i = 0; i < 128; i++) {
			h.step(i % 8 === 0 ? { mapped: 10, coverage: 0.1 } : {});
		}
		for (let i = 0; i < 64; i++) h.step({}, 1);
		expect(h.resets).not.toHaveBeenCalled();
		expect(h.renderer.frameIndex).toBe(193);
	});

	it('waits for completed feedback, not CPU frames while the GPU is busy', () => {
		const h = harness();
		h.step({ mapped: 1, coverage: 1 });
		for (let i = 0; i < 64; i++) h.step({ feedbackFrames: 0, pendingFeedback: true });
		expect(h.resets).not.toHaveBeenCalled();
		for (let i = 0; i < VT_FEEDBACK_PERIOD - 1; i++) h.step();
		expect(h.resets).not.toHaveBeenCalled();
		h.step();
		expect(h.resets).toHaveBeenCalledTimes(1);
	});

	it('includes speculative uploads in the quiet-period check', () => {
		const h = harness();
		h.step({ mapped: 1, coverage: 1 });
		for (let i = 0; i < 32; i++) h.step({}, 0, 5);
		expect(h.resets).not.toHaveBeenCalled();
		for (let i = 0; i < VT_FEEDBACK_PERIOD; i++) h.step();
		expect(h.resets).toHaveBeenCalledTimes(1);
	});

	it('blends in updates below the coverage threshold', () => {
		const h = harness(64);
		h.step({ mapped: 1, coverage: 0.001 });
		for (let i = 0; i < VT_FEEDBACK_PERIOD * 2; i++) h.step();
		expect(h.resets).not.toHaveBeenCalled();
	});

	it('drains readbacks at maxSamples before resetting, even with a 1-sample limit', () => {
		for (const limit of [1, 64]) {
			const h = harness(limit, limit);
			h.step({ mapped: 1, coverage: 1 });
			h.step({ feedbackFrames: 0, pendingFeedback: true });
			expect(h.resets).not.toHaveBeenCalled();
			h.step({ feedbackFrames: 0 });
			expect(h.resets).toHaveBeenCalledTimes(1);
			expect(h.renderer.frameIndex).toBe(1);
		}
	});

	it('clears deferred streaming changes when the camera resets accumulation', () => {
		const h = harness();
		h.step({ mapped: 1, coverage: 1 });
		h.renderer.resetAccumulation();
		for (let i = 0; i < 32; i++) h.step();
		expect(h.resets).toHaveBeenCalledTimes(1);
	});
});
