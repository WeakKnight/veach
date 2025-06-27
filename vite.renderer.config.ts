import { defineConfig } from 'vite';

// https://vitejs.dev/config
export default defineConfig({
  assetsInclude: ['**/*.wgsl'],
  plugins: [
    {
      name: 'wgsl',
      transform(code, id) {
        if (id.endsWith('.wgsl')) {
          return {
            code: `export default ${JSON.stringify(code)};`,
            map: null
          };
        }
      }
    }
  ]
});
