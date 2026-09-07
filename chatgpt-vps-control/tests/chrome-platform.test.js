import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repo = resolve(root, "..");
const extension = join(root, "chrome-platform", "extension");
const require = createRequire(import.meta.url);
const desktopServer = require(join(repo, "desktop", "electron", "chrome-platform-server.cjs"));

async function source(relative) {
  return readFile(join(extension, relative), "utf8");
}

test("first-class Chrome platform is independent from legacy userscript extension", async () => {
  const manifest = JSON.parse(await source("manifest.json"));
  assert.equal(manifest.manifest_version, 3);
  assert.equal(manifest.action.default_popup, "app.html");
  assert.equal(manifest.background.service_worker, "service-worker.js");
  assert.equal(manifest.permissions.includes("userScripts"), false);
  assert.equal(Boolean(manifest.host_permissions?.length), false);
  const worker = await source("service-worker.js");
  assert.match(worker, /platform-bridge\.js/);
  assert.match(worker, /browser-control\.js/);
  assert.doesNotMatch(worker, /userscripts/i);
});

test("Chrome UI delegates account/product work to desktop Host without credential persistence", async () => {
  const app = await source("app.js");
  const bridge = await source("platform-bridge.js");
  assert.match(bridge, /com\.fabushi\.chrome_platform/);
  assert.match(app, /feature\.auth\.status/);
  assert.match(app, /feature\.marketplace\.browse/);
  assert.match(app, /desktop\.settings\.open/);
  assert.doesNotMatch(`${app}\n${bridge}`, /refreshToken|refresh_token|password\s*[:=]|accessToken\s*[:=]/);
});

test("desktop platform bridge forces Chrome Marketplace platform and blocks secret/session destruction", () => {
  const browse = desktopServer.sanitizeRequest("feature.marketplace.browse", { platform: "desktop", query: "bot" });
  assert.equal(browse.params.platform, "chrome-extension");
  assert.throws(() => desktopServer.sanitizeRequest("feature.execute", { command: { type: "secret.provide" } }), /cannot execute/);
  assert.throws(() => desktopServer.sanitizeRequest("feature.execute", { command: { type: "session.clear" } }), /cannot execute/);
  assert.throws(() => desktopServer.sanitizeRequest("feature.auth.passwordLogin", {}), /not allowed/);
});

test("desktop browser control uses the current Chrome through native messaging and debugger", async () => {
  const browser = await source("browser-control.js");
  assert.match(browser, /com\.fabushi\.chatgpt_computer_control/);
  assert.match(browser, /chrome\.tabs\.query/);
  assert.match(browser, /chrome\.debugger\.attach/);
  assert.match(browser, /claim_tab/);
  assert.match(browser, /cdp/);
  const browserSession = await readFile(join(root, "lib", "browser-session.js"), "utf8");
  assert.match(browserSession, /kind:\s*"extension"/);
  assert.match(browserSession, /listBrowserExtensionConnections/);
});

test("desktop Host process owns and forwards the Chrome platform server", async () => {
  const host = await readFile(join(repo, "desktop", "electron", "host-process.cjs"), "utf8");
  assert.match(host, /createChromePlatformServer/);
  assert.match(host, /chromePlatformServer\.start/);
  assert.match(host, /chromePlatformServer\.broadcastEvent/);
  assert.match(host, /chromePlatformServer\.close/);
});
