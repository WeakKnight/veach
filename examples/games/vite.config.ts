import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';
const repo = (p: string) => fileURLToPath(new URL(`../../${p}`, import.meta.url));
export default defineConfig({
	root: fileURLToPath(new URL('.', import.meta.url)), base: './', publicDir: false,
	optimizeDeps: { exclude: [repo('src/generated/tinybvh/tinybvh.mjs'), repo('src/generated/nrd/nrd.mjs')] },
	build: { target: 'es2022', outDir: repo('dist-games'), emptyOutDir: true },
	server: { port: 5176, host: '127.0.0.1' }, preview: { port: 4176 },
});
