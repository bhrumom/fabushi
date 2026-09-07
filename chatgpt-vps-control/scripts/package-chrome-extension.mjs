import { cp, mkdir, rm, readFile, readdir, stat } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const source = join(root, "extension");
const dist = join(root, "dist", "chrome-extension");
const manifest = JSON.parse(await readFile(join(source, "manifest.json"), "utf8"));
const version = manifest.version;
const stage = join(dist, `fabushi-${version}`);
const zipPath = join(dist, `fabushi-${version}.zip`);

const approvedFiles = [
  "manifest.json",
  "app.html",
  "app.css",
  "app.js",
  "service-worker.js",
  "background.js",
  "userscripts.js",
  "marketplace",
];

await rm(stage, { recursive: true, force: true });
await mkdir(stage, { recursive: true });
for (const relative of approvedFiles) {
  const from = join(source, relative);
  const to = join(stage, relative);
  await cp(from, to, { recursive: true });
}

function listEntries(path, prefix = "") {
  return readdir(path, { withFileTypes: true }).then(async (entries) => {
    const output = [];
    for (const entry of entries) {
      const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
      const absolute = join(path, entry.name);
      if (entry.isDirectory()) output.push(...await listEntries(absolute, relative));
      else output.push(relative);
    }
    return output;
  });
}

const stagedEntries = (await listEntries(stage)).sort();
if (stagedEntries.some((name) => name.startsWith("popup."))) throw new Error("legacy popup files must not be included in the production package");
await rm(zipPath, { force: true });
try {
  execFileSync("zip", ["-X", "-q", "-r", zipPath, "."], { cwd: stage, stdio: "inherit" });
} catch (error) {
  throw new Error("Production ZIP creation requires the standard `zip` executable on PATH.", { cause: error });
}
const bytes = (await stat(zipPath)).size;
console.log(`Packaged Fabushi Chrome extension ${version}`);
console.log(`Staging: ${stage}`);
console.log(`ZIP: ${zipPath} (${bytes} bytes)`);
console.log(`Files: ${stagedEntries.join(", ")}`);
