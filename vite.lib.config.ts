// Library build (the @tianyuliwiwo/veach npm package): `@tianyuliwiwo/veach` (core) and `@tianyuliwiwo/veach/view`
// (<veach-view>) as ES modules in dist-lib/. Shaders, the tinybvh wasm and the BSDF tables are
// inlined, so consumers need no asset handling.
import { defineConfig } from 'vite';

export default defineConfig({
	publicDir: false,
	build: {
		target: 'es2022',
		outDir: 'dist-lib',
		emptyOutDir: true,
		// Release packages contain compiled code only; maps embed the original TypeScript.
		sourcemap: false,
		minify: 'esbuild',
		lib: {
			entry: { index: 'src/index.ts', view: 'src/view/index.ts' },
			formats: ['es'],
		},
	},
});
