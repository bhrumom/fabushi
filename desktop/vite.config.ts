import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

const here = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig(({ mode }) => {
  // Shared Next/browser modules use process.env.NEXT_PUBLIC_*. Supply only
  // explicitly public settings; never serialize the build machine's environment.
  const publicEnvironment = {
    ...loadEnv(mode, path.resolve(here, '../frontend/apps/web'), 'NEXT_PUBLIC_'),
    ...loadEnv(mode, here, 'NEXT_PUBLIC_'),
    NODE_ENV: mode === 'production' ? 'production' : 'development',
  };
  return {
    plugins: [react()],
    base: './',
    define: { 'process.env': JSON.stringify(publicEnvironment) },
    resolve: {
      alias: {
        '@fabushi/shared': path.resolve(here, '../frontend/packages/shared/src/index.ts'),
        '@fabushi/mcp-app-sdk': path.resolve(here, '../frontend/packages/mcp-app-sdk/src/index.ts'),
        react: path.resolve(here, 'node_modules/react'),
        'react-dom': path.resolve(here, 'node_modules/react-dom'),
        'lucide-react': path.resolve(here, 'node_modules/lucide-react'),
      },
      dedupe: ['react', 'react-dom'],
    },
    server: {
      host: '127.0.0.1',
      port: 1420,
      strictPort: true,
      fs: { allow: [path.resolve(here, '..')] },
    },
    build: { sourcemap: true },
  };
});
