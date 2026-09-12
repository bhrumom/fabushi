import { access, readFile } from "node:fs/promises";
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
const paths = await readFile(join(root, "lib", "browser-extension-paths.js"), "utf8");
const desktopServer = await readFile(join(root, "..", "desktop", "electron", "chrome-platform-server.cjs"), "utf8");
const desktopHost = await readFile(join(root, "..", "desktop", "electron", "host-process.cjs"), "utf8");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}
async function mustExist(relative) {
  await access(join(extension, relative), constants.R_OK);
}

const requiredPermissions = ["alarms", "debugger", "downloads", "nativeMessaging", "scripting", "storage", "tabGroups", "tabs", "userScripts", "webNavigation"];
assert(manifest.manifest_version === 3, "manifest_version must be 3");
assert(manifest.name === "Fabushi" && manifest.short_name === "Fabushi", "the shipped extension must use the Fabushi identity");
assert(manifest.version === "0.5.0", "Fabushi Chrome release must be version 0.5.0");
assert(manifest.minimum_chrome_version === "120", "Chrome 120 is the supported minimum for MV3 debugger/userScripts behavior");
assert(manifest.action?.default_popup === "app.html", "action.default_popup must be app.html");
assert(manifest.background?.service_worker === "service-worker.js", "background.service_worker must be service-worker.js");
assert(manifest.background?.type === "module", "background service worker must be a module");
for (const permission of requiredPermissions) assert(manifest.permissions?.includes(permission), `manifest is missing required permission ${permission}`);
assert(JSON.stringify(manifest.host_permissions || []) === JSON.stringify(["<all_urls>"]), "host permissions must preserve the existing 0.4.1 userscript runner content bridge");
assert(Array.isArray(manifest.content_scripts) && manifest.content_scripts.some((item) => item.js?.includes("userscript-content.js") && item.matches?.includes("<all_urls>")), "manifest must preserve the 0.4.1 userscript content bridge");
assert(releaseReadme.includes(`Production candidate: **${manifest.version}**`), "Chrome Web Store README production candidate must match manifest.version");
assert(releaseReadme.includes("Every Chrome Web Store update must increment"), "release docs must preserve the monotonic version gate");

for (const relative of [manifest.action.default_popup, manifest.background.service_worker, "app.css", "app.js", "platform-bridge.js", "browser-control.js", "userscript-core.js", "userscript-runner.js", "userscript-content.js", "userscript.css", "userscript/chatgpt-auto-confirm.user.js", "marketplace/chatgpt-task-queue.user.js"]) await mustExist(relative);
const serviceWorker = await readFile(join(extension, manifest.background.service_worker), "utf8");
assert(serviceWorker.includes('import "./platform-bridge.js"'), "service worker must load the product bridge");
assert(serviceWorker.includes('import "./browser-control.js"'), "service worker must load the browser-control bridge");
assert(serviceWorker.includes('import "./userscript-runner.js"'), "service worker must load the existing userscript runtime");

const appHtml = await readFile(join(extension, "app.html"), "utf8");
const appJs = await readFile(join(extension, "app.js"), "utf8");
for (const required of ["Fabushi", "聊天", "小程序", "Marketplace", "浏览器", "设置", "search", "open-desktop-settings"]) assert(appHtml.includes(required), `app.html missing product marker: ${required}`);
assert(appHtml.startsWith("<!doctype html>"), "app.html must declare HTML5 doctype");
assert(!/<script[^>]+src=["']https?:\/\//i.test(appHtml), "remote scripts are not allowed in app.html");
assert(!/<link[^>]+href=["']https?:\/\//i.test(appHtml), "remote stylesheets are not allowed in app.html");
assert(!/\bon\w+\s*=/i.test(appHtml), "inline event handlers are not allowed in app.html");
assert(appJs.includes("feature.marketplace.browse"), "Fabushi Chrome must expose Marketplace through the desktop bridge");
assert(appJs.includes("chatgpt-auto-confirm") && appJs.includes("import-userscript"), "Fabushi Chrome must preserve the existing bundled userscript runner UI");
assert(appJs.includes("userscript-chatgpt-task-queue") && appJs.includes("marketplace/chatgpt-task-queue.user.js"), "Fabushi Chrome must expose the bundled Task Queue userscript through the same runner");
assert(appJs.includes("fabushi.userscript.install") && appJs.includes("fabushi.userscript.setEnabled") && appJs.includes("fabushi.userscript.uninstall"), "userscript UI must expose install, enable/disable, and uninstall controls");

const userscript = await readFile(join(extension, "userscript/chatgpt-auto-confirm.user.js"), "utf8");
assert(userscript.includes("// @match        https://chatgpt.com/*") && userscript.includes("// @match        https://chat.openai.com/*"), "bundled userscript must declare approved hosts");
const taskQueue = await readFile(join(extension, "marketplace/chatgpt-task-queue.user.js"), "utf8");
assert(taskQueue.includes("// @match        https://chatgpt.com/*") && taskQueue.includes("// @match        https://chat.openai.com/*"), "bundled Task Queue userscript must declare approved hosts");
assert(!/https?:\/\/[^\s"']+\.js/i.test(`${serviceWorker}\n${appHtml}\n${appJs}\n${userscript}\n${taskQueue}`), "production extension must not load executable JavaScript from a remote URL");

const platformBridge = await readFile(join(extension, "platform-bridge.js"), "utf8");
const browserControl = await readFile(join(extension, "browser-control.js"), "utf8");
assert(platformBridge.includes("com.fabushi.chrome_platform"), "product bridge must use com.fabushi.chrome_platform");
assert(browserControl.includes("com.fabushi.browser_control"), "browser bridge must use the new Fabushi browser-control host");
assert(!browserControl.includes("com.fabushi.chatgpt_computer_control"), "production browser bridge must not use the legacy host");
for (const command of ["list_tabs", "claim_tab", "cdp", "cdp_auto_attach_frame", "downloads", "tab_action", "create_tab", "cleanup_tabs", "detach"]) assert(browserControl.includes(`\"${command}\"`), `browser bridge is missing command ${command}`);
for (const action of ["activate_tab", "close_tab", "navigate", "reload", "back", "forward", "retain_tab", "release_tab"]) assert(browserControl.includes(`\"${action}\"`), `browser bridge is missing action ${action}`);
assert(browserControl.includes("Target.attachedToTarget") && browserControl.includes("Target.detachedFromTarget"), "browser bridge must forward CDP child-session events");
assert(browserControl.includes("generation") && browserControl.includes("The browser extension generation changed"), "claims must fail closed on stale extension generations");
assert(browserControl.includes("chrome.debugger.attach"), "browser bridge must use Chrome Debugger API");

assert(paths.includes('NATIVE_HOST_NAME = "com.fabushi.browser_control"'), "native host identity must be renamed to Fabushi browser_control");
assert(installer.includes('join(runtimeRoot, "chrome-platform", "extension")'), "installer must stage the first-class Chrome platform source");
assert(paths.includes('NATIVE_HOST_NAME = "com.fabushi.browser_control"') && installer.includes("CHROME_PLATFORM_NATIVE_HOST_NAME"), "installer must register both stable Fabushi native hosts");
assert(installer.includes("unregisterLegacyNativeMessaging") && installer.includes("quarantineLegacyBrowserExtension"), "installer must provide exact legacy-host cleanup after UI migration");
assert(desktopServer.includes("credentialBoundary: 'desktop-host'"), "desktop server must keep account credentials in the desktop Host");
assert(desktopServer.includes("FORBIDDEN_EXTENSION_COMMANDS"), "desktop server must enforce the extension safety boundary");
assert(desktopServer.includes("FABUSHI_CHROME_EXTENSION_ID") && desktopServer.includes("requires the published extension ID"), "desktop server must fail closed until the published Fabushi extension ID is configured");
assert(desktopHost.includes("createChromePlatformServer") && desktopHost.includes("chromePlatformServer.broadcastEvent"), "desktop Host must own and forward the Chrome platform server");

for (const relative of ["app.js", "platform-bridge.js", "browser-control.js", "userscript-core.js", "userscript-runner.js", "userscript-content.js", "service-worker.js"]) execFileSync(process.execPath, ["--check", join(extension, relative)], { stdio: "inherit" });
execFileSync(process.execPath, ["--check", join(root, "scripts", "chrome-platform-host.mjs")], { stdio: "inherit" });
execFileSync(process.execPath, ["--check", join(root, "scripts", "package-chrome-extension.mjs")], { stdio: "inherit" });
execFileSync(process.execPath, ["--check", join(root, "scripts", "chrome-extension-e2e.mjs")], { stdio: "inherit" });
execFileSync(process.execPath, ["--check", join(root, "..", "desktop", "electron", "chrome-platform-server.cjs")], { stdio: "inherit" });

console.log(`Fabushi Chrome platform validation passed: ${manifest.name} ${manifest.version}`);
console.log("Command/event parity passed: list_tabs, claim_tab, cdp, cdp_auto_attach_frame, downloads, tab_action, create_tab, cleanup_tabs, detach");
console.log("Credential boundary passed: desktop Host owns account session; extension receives only product results/events");
console.log("Integrated userscript boundary passed: existing runner, bundled sources, explicit install controls, and no remote executable code");
