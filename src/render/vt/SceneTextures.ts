import type { VirtualTextureSystem } from './VirtualTextureSystem';

/** Shared binding/feedback contract for imported and persistent host scenes. */
export type SceneTextures = Pick<VirtualTextureSystem,
	'physical' | 'pageTable' | 'pageTableWidth' | 'tilesPerRow' | 'invPhysicalSize' | 'stats'
	| 'nextFeedbackJitter' | 'update' | 'recordFeedbackReadback' | 'afterSubmit' | 'destroy'>;
