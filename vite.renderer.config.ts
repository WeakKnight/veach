import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config
export default defineConfig({
  assetsInclude: ['**/*.wgsl'],
  plugins: [
    react(),
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
