import { readFile, access } from "node:fs/promises";
import { constants } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const extension = join(root, "extension");
const manifestPath = join(extension, "manifest.json");
const manifest = JSON.parse(await readFile(manifestPath, "utf8"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}
async function mustExist(relative) {
  await access(join(extension, relative), constants.R_OK);
}

assert(manifest.manifest_version === 3, "manifest_version must be 3");
assert(manifest.action?.default_popup === "app.html", "action.default_popup must be app.html");
assert(manifest.background?.service_worker === "service-worker.js", "background.service_worker must be service-worker.js");
assert(manifest.background?.type === "module", "background service worker must be a module");
assert(Array.isArray(manifest.permissions) && manifest.permissions.includes("storage"), "storage permission is required");
assert(Array.isArray(manifest.host_permissions), "host_permissions must be an array");
assert(manifest.host_permissions.every((origin) => ["https://chatgpt.com/*", "https://chat.openai.com/*"].includes(origin)), "host permissions must remain restricted to approved ChatGPT origins");

for (const relative of [manifest.action.default_popup, manifest.background.service_worker, "app.css", "app.js", "background.js", "userscripts.js"]) await mustExist(relative);
const serviceWorker = await readFile(join(extension, manifest.background.service_worker), "utf8");
assert(serviceWorker.includes('import "./background.js"'), "service worker must import background.js");
assert(serviceWorker.includes('import "./userscripts.js"'), "service worker must preserve existing userscripts runtime import");
const appHtml = await readFile(join(extension, "app.html"), "utf8");
for (const required of ["Fabushi", "Chats", "Mini Apps", "Marketplace", "app-search", "loading-state", "empty-state"]) assert(appHtml.includes(required), `app.html missing required UI marker: ${required}`);
assert(!/<script[^>]+src=["']https?:\/\//i.test(appHtml), "remote scripts are not allowed in app.html");
assert(!/<link[^>]+href=["']https?:\/\//i.test(appHtml), "remote stylesheets are not allowed in app.html");

for (const relative of ["app.js", "background.js", "service-worker.js", "userscripts.js"]) execFileSync(process.execPath, ["--check", join(extension, relative)], { stdio: "inherit" });
console.log(`Chrome extension validation passed: ${manifest.name} ${manifest.version}`);
