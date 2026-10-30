import { createReadStream, existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';
const repo = (p: string) => fileURLToPath(new URL(`../../${p}`, import.meta.url));
// NRD showcase: live scenes plus the screenshots written by `npm run check:nrd` (.tools/nrd, served at /captures).
export default defineConfig({
	root: fileURLToPath(new URL('.', import.meta.url)), base: './', publicDir: repo('public'),
	optimizeDeps: { exclude: [repo('src/generated/tinybvh/tinybvh.mjs'), repo('src/generated/nrd/nrd.mjs')] },
	build: { target: 'es2022', outDir: repo('dist-nrd'), emptyOutDir: true },
	server: { port: 5178, host: '127.0.0.1' },
	plugins: [{
		name: 'nrd-captures',
		configureServer(server) {
			server.middlewares.use('/captures', (req, res, next) => {
				const name = decodeURIComponent((req.url ?? '').split('?')[0]).replace(/^\/+/, '');
				const file = join(repo('.tools/nrd'), name);
				if (!/^[\w.-]+\.(png|json)$/.test(name) || !existsSync(file)) return next();
				res.setHeader('Content-Type', name.endsWith('.png') ? 'image/png' : 'application/json');
				res.setHeader('Cache-Control', 'no-store');
				createReadStream(file).pipe(res);
			});
		},
	}],
});
