// Library build (the veach npm package): `veach` (core) and `veach/view`
// (<veach-view>) as ES modules in dist-lib/. Shaders, the tinybvh wasm and the BSDF tables are
// inlined, so consumers need no asset handling.
import { defineConfig } from 'vite';

export default defineConfig({
	publicDir: false,
	build: {
		target: 'es2022',
		outDir: 'dist-lib',
		emptyOutDir: true,
		sourcemap: true,
		lib: {
			entry: { index: 'src/index.ts', view: 'src/view/index.ts' },
			formats: ['es'],
		},
	},
});
