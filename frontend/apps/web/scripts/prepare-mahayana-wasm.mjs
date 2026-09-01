import { cp, mkdir, rm } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const appDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(appDir, "../../../../");
const sourceDir = path.join(repoRoot, "fabushi/web/mahayana-wasm");
const targetDir = path.resolve(appDir, "../public/mahayana-wasm");

const requiredFiles = [
  "bootstrap.js",
  "worker.js",
  "mahayana_runtime.js",
  "mahayana_runtime_bg.wasm",
  "official-miniapps/fabushi_official_miniapps.js",
  "official-miniapps/fabushi_official_miniapps_bg.wasm",
];

await rm(targetDir, { recursive: true, force: true });
await mkdir(targetDir, { recursive: true });
for (const relativePath of requiredFiles) {
  const sourcePath = path.join(sourceDir, relativePath);
  const targetPath = path.join(targetDir, relativePath);
  await mkdir(path.dirname(targetPath), { recursive: true });
  await cp(sourcePath, targetPath);
}

console.log(`Prepared Mahayana WebAssembly runtime in ${targetDir}`);
