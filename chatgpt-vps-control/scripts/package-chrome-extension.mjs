import { cp, mkdir, rm, readFile, readdir, stat, writeFile } from "node:fs/promises";
import { readFileSync } from "node:fs";
import { dirname, join, resolve, basename } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const source = join(root, "chrome-platform", "extension");
const dist = join(root, "dist", "chrome-extension");
const manifest = JSON.parse(await readFile(join(source, "manifest.json"), "utf8"));
const version = manifest.version;
const stage = join(dist, `fabushi-chrome-${version}`);
const zipPath = join(dist, `fabushi-chrome-${version}.zip`);
const checksumsPath = join(dist, "SHA256SUMS.txt");
const contentManifestPath = join(dist, `fabushi-chrome-${version}.content-manifest.json`);

const approvedFiles = [
  "manifest.json",
  "app.html",
  "app.css",
  "app.js",
  "service-worker.js",
  "platform-bridge.js",
  "browser-control.js",
  "userscript-core.js",
  "userscript-runner.js",
  "userscript-content.js",
  "userscript.css",
  "userscript/chatgpt-auto-confirm.user.js",
  "marketplace/chatgpt-task-queue.user.js",
];

if (manifest.version !== "0.5.0") throw new Error(`Chrome extension packaging is pinned to 0.5.0; received ${manifest.version}.`);
if (!manifest.permissions?.includes("userScripts")) throw new Error("Fabushi 0.5.0 must expose the integrated userscript runtime.");
if (JSON.stringify(manifest.host_permissions || []) !== JSON.stringify(["<all_urls>"])) {
  throw new Error("Fabushi 0.5.0 must preserve the 0.4.1 all-URL content-script permission used by the existing userscript runner.");
}

await rm(stage, { recursive: true, force: true });
await mkdir(stage, { recursive: true });
for (const relative of approvedFiles) {
  const destination = join(stage, relative);
  await mkdir(dirname(destination), { recursive: true });
  await cp(join(source, relative), destination, { recursive: true });
}

async function listEntries(path, prefix = "") {
  const entries = await readdir(path, { withFileTypes: true });
  const output = [];
  for (const entry of entries) {
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    const absolute = join(path, entry.name);
    if (entry.isDirectory()) output.push(...await listEntries(absolute, relative));
    else output.push(relative);
  }
  return output;
}

const stagedEntries = (await listEntries(stage)).sort();
if (JSON.stringify(stagedEntries) !== JSON.stringify([...approvedFiles].sort())) {
  throw new Error(`Production staging contains unexpected files: ${stagedEntries.join(",")}`);
}

await rm(zipPath, { force: true });
try {
  execFileSync("zip", ["-X", "-q", "-r", zipPath, "."], { cwd: stage, stdio: "inherit" });
} catch (error) {
  throw new Error("Production ZIP creation requires the standard `zip` executable on PATH.", { cause: error });
}

let archivedEntries;
try {
  archivedEntries = execFileSync("unzip", ["-Z1", zipPath], { encoding: "utf8" })
    .split(/\r?\n/)
    .map((entry) => entry.replace(/^\.\//, ""))
    .filter((entry) => entry && !entry.endsWith("/"))
    .sort();
} catch (error) {
  throw new Error("Production ZIP verification requires the standard `unzip` executable on PATH.", { cause: error });
}
if (JSON.stringify(archivedEntries) !== JSON.stringify(stagedEntries)) {
  throw new Error(`ZIP content verification failed. staged=${stagedEntries.join(",")} archived=${archivedEntries.join(",")}`);
}

const archivedManifest = JSON.parse(execFileSync("unzip", ["-p", zipPath, "manifest.json"], { encoding: "utf8" }));
if (archivedManifest.version !== version) throw new Error("ZIP manifest version does not match the source manifest.");
if (!archivedManifest.permissions?.includes("userScripts")) throw new Error("Packaged manifest is missing the integrated userScripts permission.");
if (JSON.stringify(archivedManifest.host_permissions || []) !== JSON.stringify(manifest.host_permissions)) throw new Error("ZIP host permissions differ from source manifest.");
if (!Array.isArray(archivedManifest.content_scripts) || archivedManifest.content_scripts[0]?.js?.[0] !== "userscript-content.js") throw new Error("Packaged manifest is missing the existing userscript content bridge.");

const files = [];
for (const relative of stagedEntries) {
  const path = join(stage, relative);
  files.push({ path: relative, bytes: (await stat(path)).size, sha256: createHash("sha256").update(readFileSync(path)).digest("hex") });
}
const zipBytes = await readFile(zipPath);
const checksum = createHash("sha256").update(zipBytes).digest("hex");
let sourceSha = String(process.env.GITHUB_SHA || "").trim();
if (!/^[0-9a-f]{40}$/i.test(sourceSha)) {
  try { sourceSha = execFileSync("git", ["rev-parse", "HEAD"], { cwd: root, encoding: "utf8" }).trim(); } catch { sourceSha = "unknown"; }
}
const contentManifest = {
  schemaVersion: 1,
  product: "Fabushi Chrome",
  version,
  sourceSha,
  generatedAt: new Date().toISOString(),
  files,
  archive: { name: basename(zipPath), bytes: zipBytes.length, sha256: checksum },
};
await writeFile(contentManifestPath, `${JSON.stringify(contentManifest, null, 2)}\n`, "utf8");
await writeFile(checksumsPath, `${checksum}  ${basename(zipPath)}\n${createHash("sha256").update(JSON.stringify(contentManifest, null, 2) + "\n").digest("hex")}  ${basename(contentManifestPath)}\n`, "utf8");
const bytes = (await stat(zipPath)).size;
console.log(`Packaged Fabushi Chrome ${version}`);
console.log(`Source SHA: ${sourceSha}`);
console.log(`Staging: ${stage}`);
console.log(`ZIP: ${zipPath} (${bytes} bytes)`);
console.log(`SHA-256: ${checksum}`);
console.log(`Content manifest: ${contentManifestPath}`);
console.log(`Verified ZIP files: ${archivedEntries.join(", ")}`);
