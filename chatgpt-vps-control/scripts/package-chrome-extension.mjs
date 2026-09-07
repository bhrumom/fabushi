import { cp, mkdir, rm, readFile, readdir, stat, writeFile } from "node:fs/promises";
import { dirname, join, resolve, basename } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const source = join(root, "chrome-platform", "extension");
const dist = join(root, "dist", "chrome-extension");
const manifest = JSON.parse(await readFile(join(source, "manifest.json"), "utf8"));
const version = manifest.version;
const stage = join(dist, `fabushi-${version}`);
const zipPath = join(dist, `fabushi-${version}.zip`);
const checksumsPath = join(dist, "SHA256SUMS.txt");

const approvedFiles = [
  "manifest.json",
  "app.html",
  "app.css",
  "app.js",
  "service-worker.js",
  "platform-bridge.js",
  "browser-control.js",
];

await rm(stage, { recursive: true, force: true });
await mkdir(stage, { recursive: true });
for (const relative of approvedFiles) await cp(join(source, relative), join(stage, relative), { recursive: true });

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
if (stagedEntries.some((name) => /(?:^|\/)(?:popup|userscripts)(?:\.|$)/i.test(name) || /\.user\.js$/i.test(name) || name.startsWith("marketplace/"))) {
  throw new Error("Legacy popup/userscript assets must not be included in the first-class Fabushi Chrome platform package.");
}
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
if (archivedManifest.permissions?.includes("userScripts")) throw new Error("Packaged manifest unexpectedly requests userScripts.");
if (archivedManifest.host_permissions?.length) throw new Error("Packaged manifest unexpectedly carries legacy host permissions.");

const zipBytes = await readFile(zipPath);
const checksum = createHash("sha256").update(zipBytes).digest("hex");
await writeFile(checksumsPath, `${checksum}  ${basename(zipPath)}\n`, "utf8");
const bytes = (await stat(zipPath)).size;
console.log(`Packaged first-class Fabushi Chrome platform ${version}`);
console.log(`Staging: ${stage}`);
console.log(`ZIP: ${zipPath} (${bytes} bytes)`);
console.log(`SHA-256: ${checksum}`);
console.log(`Verified ZIP files: ${archivedEntries.join(", ")}`);
