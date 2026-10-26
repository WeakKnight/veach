// <veach-view> demo: resolves `@tianyuliwiwo/veach` / `@tianyuliwiwo/veach/view` to the sources and serves the
// repo's public/ (samples).
import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';

const repo = (p: string) => fileURLToPath(new URL(`../../${p}`, import.meta.url));

export default defineConfig({
	root: fileURLToPath(new URL('.', import.meta.url)),
	base: './',
	publicDir: repo('public'),
	resolve: {
		alias: [
			{ find: /^@tianyuliwiwo\/veach\/view$/, replacement: repo('src/view/index.ts') },
			{ find: /^@tianyuliwiwo\/veach$/, replacement: repo('src/index.ts') },
		],
	},
	optimizeDeps: {
		exclude: [repo('src/generated/tinybvh/tinybvh.mjs')],
	},
	build: {
		target: 'es2022',
		outDir: repo('dist-view-demo'),
		emptyOutDir: true,
	},
	server: { port: 5174 },
	preview: { port: 4174 },
});
