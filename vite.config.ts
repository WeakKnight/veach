/// <reference types="vitest/config" />
import { defineConfig } from 'vite';

export default defineConfig({
	build: {
		target: 'es2022',
	},
	optimizeDeps: {
		// the Emscripten module locates its .wasm through import.meta.url
		exclude: ['./src/generated/tinybvh/tinybvh.mjs', './src/generated/nrd/nrd.mjs'],
	},
	test: {
		include: ['tests/**/*.test.ts'],
	},
});
