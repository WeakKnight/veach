import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config
export default defineConfig(async () => {
  const { default: slang } = await import('vite-slang');
  
  return {
    assetsInclude: ['**/*.wgsl'],
    plugins: [
      react(),
      slang(),
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
  };
});
