import { defineConfig } from "vite";

export default defineConfig({
  define: {
    "process.env.NEXT_PUBLIC_MAHAYANA_HOST_MODE": JSON.stringify(
      process.env.NEXT_PUBLIC_MAHAYANA_HOST_MODE ?? "",
    ),
  },
  esbuild: {
    jsx: "automatic",
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
    sourcemap: false,
    target: "es2022",
  },
  server: {
    strictPort: true,
  },
});
