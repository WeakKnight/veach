export type PrimaryVisibilityMode = 'auto' | 'ray-traced' | 'rasterized';

// Enabled by user choice during iteration; correctness fallbacks remain active.
export const AUTO_RASTER_PRIMARY = true;

export interface PrimaryVisibilityStats {
	requested: PrimaryVisibilityMode;
	actual: 'ray-traced' | 'rasterized';
	reason: string | null;
	drawCalls: number;
	clusterInstances: number;
	scratchBytes: number;
	textureBytes: number;
	visibleClusters?: number;
	vertexSlots?: number;
	usefulVertexSlots?: number;
	paddingVertexSlots?: number;
	numericalFallbackPixels?: number;
	sparseFallbackPixels?: number;
	fallbackPixels?: number;
	alphaFallbackPixels?: number;
	nearClipFallback?: boolean;
}
