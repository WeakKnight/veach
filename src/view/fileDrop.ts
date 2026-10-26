// Drag & drop of .glb / .gltf (with its buffers and images) and .hdr files, for <veach-view> or any
// other drop target.
import { loadGLTFFromFiles } from '../loaders/GLTFLoader';
import { parseHDR, type HDRImage } from '../loaders/HDRLoader';
import type { SceneDesc } from '../scene/Scene';

export interface DroppedFiles {
	/** The dropped scene, ready for `view.model`. */
	model: { scene: SceneDesc; name: string } | null;
	/** The dropped environment, ready for `view.environment`. */
	environment: { image: HDRImage; name: string } | null;
}

/** Loads a .glb / .gltf (with the other files it references) and / or an .hdr from a file list. */
export async function loadDroppedFiles(files: File[]): Promise<DroppedFiles> {
	const hdr = files.find((f) => /\.hdr$/i.test(f.name));
	const main = files.find((f) => /\.(glb|gltf)$/i.test(f.name));
	if (!hdr && !main) {
		throw new Error('Drop a .glb, a .gltf with its files, or an .hdr');
	}
	return {
		environment: hdr ? { image: parseHDR(await hdr.arrayBuffer()), name: hdr.name } : null,
		model: main ? { scene: await loadGLTFFromFiles(main, files), name: main.name } : null,
	};
}

export interface FileDropHandlers {
	onDrop: (files: DroppedFiles) => void;
	onDragChange?: (dragging: boolean) => void;
	onLoadingChange?: (loading: boolean) => void;
	onError?: (error: Error) => void;
}

/** Makes `target` accept dropped scenes and environments. Returns a function that detaches it. */
export function attachFileDrop(target: HTMLElement, handlers: FileDropHandlers): () => void {
	const dragOver = (e: DragEvent) => {
		e.preventDefault();
		handlers.onDragChange?.(true);
	};
	const dragLeave = (e: DragEvent) => {
		if (e.relatedTarget instanceof Node && target.contains(e.relatedTarget)) return;
		handlers.onDragChange?.(false);
	};
	const drop = (e: DragEvent) => {
		e.preventDefault();
		handlers.onDragChange?.(false);
		const files = Array.from(e.dataTransfer?.files ?? []);
		handlers.onLoadingChange?.(true);
		loadDroppedFiles(files)
			.then(handlers.onDrop, (error: unknown) => {
				const err = error instanceof Error ? error : new Error(String(error));
				if (handlers.onError) handlers.onError(err);
				else console.error('[veach]', err);
			})
			.finally(() => handlers.onLoadingChange?.(false));
	};
	target.addEventListener('dragover', dragOver);
	target.addEventListener('dragleave', dragLeave);
	target.addEventListener('drop', drop);
	return () => {
		target.removeEventListener('dragover', dragOver);
		target.removeEventListener('dragleave', dragLeave);
		target.removeEventListener('drop', drop);
	};
}
