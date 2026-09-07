import { readFile, access, readdir } from "node:fs/promises";
import { constants } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const extension = join(root, "chrome-platform", "extension");
const manifestPath = join(extension, "manifest.json");
const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
const releaseReadme = await readFile(join(root, "docs", "chrome-web-store", "README.md"), "utf8");
const installer = await readFile(join(root, "lib", "browser-extension-install.js"), "utf8");
const desktopServer = await readFile(join(root, "..", "desktop", "electron", "chrome-platform-server.cjs"), "utf8");
const desktopHost = await readFile(join(root, "..", "desktop", "electron", "host-process.cjs"), "utf8");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}
async function mustExist(relative) {
  await access(join(extension, relative), constants.R_OK);
}

assert(manifest.manifest_version === 3, "manifest_version must be 3");
assert(/^\d+\.\d+\.\d+(?:\.\d+)?$/.test(manifest.version), "manifest.version must be Chrome Web Store compatible");
assert(releaseReadme.includes(`Production candidate: **${manifest.version}**`), "Chrome Web Store README production candidate must match the first-class platform manifest.version");
assert(releaseReadme.includes("Every Chrome Web Store update must increment"), "release docs must preserve the Web Store monotonic version gate");
assert(manifest.action?.default_popup === "app.html", "action.default_popup must be app.html");
assert(manifest.background?.service_worker === "service-worker.js", "background.service_worker must be service-worker.js");
assert(manifest.background?.type === "module", "background service worker must be a module");
assert(Array.isArray(manifest.permissions) && manifest.permissions.includes("nativeMessaging"), "nativeMessaging permission is required for desktop session bridge");
assert(manifest.permissions.includes("debugger") && manifest.permissions.includes("tabs"), "debugger and tabs permissions are required to control the user's existing Chrome");
assert(!manifest.permissions.includes("userScripts"), "first-class Fabushi Chrome platform must not request userScripts permission");
assert(!manifest.host_permissions || manifest.host_permissions.length === 0, "first-class Fabushi Chrome platform must not carry legacy ChatGPT-only host permissions");

for (const relative of [manifest.action.default_popup, manifest.background.service_worker, "app.css", "app.js", "platform-bridge.js", "browser-control.js"]) await mustExist(relative);
const entries = await readdir(extension, { withFileTypes: true });
assert(!entries.some((entry) => entry.name === "marketplace" || entry.name === "userscripts.js" || entry.name === "popup.html" || entry.name === "popup.js"), "new Chrome platform source must be independent from legacy extension/userscript assets");

const serviceWorker = await readFile(join(extension, manifest.background.service_worker), "utf8");
assert(serviceWorker.includes('import "./platform-bridge.js"'), "service worker must load desktop platform bridge");
assert(serviceWorker.includes('import "./browser-control.js"'), "service worker must load existing-Chrome control bridge");
assert(!serviceWorker.includes("userscripts"), "new service worker must not load legacy userscript runtime");

const appHtml = await readFile(join(extension, "app.html"), "utf8");
for (const required of ["Fabushi", "聊天", "小程序", "Marketplace", "浏览器", "设置", "search", "open-desktop-settings"]) {
  assert(appHtml.includes(required), `app.html missing required first-class platform marker: ${required}`);
}
assert(appHtml.startsWith("<!doctype html>"), "app.html must declare HTML5 doctype");
assert(/<html\b[^>]*>[\s\S]*<head\b[^>]*>[\s\S]*<\/head>[\s\S]*<body\b[^>]*>[\s\S]*<\/body>[\s\S]*<\/html>\s*$/i.test(appHtml), "app.html must contain complete html/head/body structure");
assert(!/<script[^>]+src=["']https?:\/\//i.test(appHtml), "remote scripts are not allowed in app.html");
assert(!/<link[^>]+href=["']https?:\/\//i.test(appHtml), "remote stylesheets are not allowed in app.html");
assert(!/\bon\w+\s*=/i.test(appHtml), "inline event handlers are not allowed in app.html");

const localRefs = [...appHtml.matchAll(/(?:src|href)=["']([^"']+)["']/gi)]
  .map((match) => match[1])
  .filter((value) => !value.startsWith("#") && !/^[a-z]+:/i.test(value));
for (const relative of localRefs) await mustExist(relative.replace(/^\.\//, ""));

const platformBridge = await readFile(join(extension, "platform-bridge.js"), "utf8");
const browserControl = await readFile(join(extension, "browser-control.js"), "utf8");
assert(platformBridge.includes('com.fabushi.chrome_platform'), "platform bridge must use its independent native host");
assert(platformBridge.includes("desktop.settings.open"), "platform bridge must support native desktop settings request through generic desktop request routing");
assert(browserControl.includes('com.fabushi.chatgpt_computer_control'), "browser control must preserve the local browser-control native host contract");
assert(browserControl.includes("chrome.debugger.attach"), "browser control must operate the user's existing Chrome through chrome.debugger");

assert(installer.includes('join(runtimeRoot, "chrome-platform", "extension")'), "installer must stage new first-class Chrome platform source");
assert(installer.includes('com.fabushi.chrome_platform'), "installer must register platform native host");
assert(desktopServer.includes("credentialBoundary: 'desktop-host'"), "desktop platform server must keep account credential ownership in desktop Host");
assert(desktopServer.includes("FORBIDDEN_EXTENSION_COMMANDS"), "desktop platform server must enforce extension safety boundary");
assert(desktopHost.includes("createChromePlatformServer"), "desktop Host process must start the Chrome platform server");

for (const relative of ["app.js", "platform-bridge.js", "browser-control.js", "service-worker.js"]) {
  execFileSync(process.execPath, ["--check", join(extension, relative)], { stdio: "inherit" });
}
execFileSync(process.execPath, ["--check", join(root, "scripts", "chrome-platform-host.mjs")], { stdio: "inherit" });
execFileSync(process.execPath, ["--check", join(root, "..", "desktop", "electron", "chrome-platform-server.cjs")], { stdio: "inherit" });

console.log(`Fabushi Chrome platform validation passed: ${manifest.name} ${manifest.version}`);
console.log(`Release version contract passed: manifest ${manifest.version} == documented production candidate`);
console.log("Credential boundary passed: desktop Host owns account session; extension receives only product results/events");
console.log("Legacy userscript separation passed: no userScripts permission or userscript runtime in production source");
console.log(`Validated local app resources: ${localRefs.join(", ")}`);
