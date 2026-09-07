import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import test from "node:test";

import {
  browserExtensionPaths,
  browserExtensionRequest,
  browserExtensionStatus,
  installBrowserExtension,
  listBrowserExtensionConnections,
  startBrowserExtensionBridge,
  stopBrowserExtensionBridgeForTests,
} from "../lib/browser-extension.js";
import { ExtensionCdpClient } from "../lib/browser-session-cdp.js";
import { browserSessionCua, listBrowserSessions } from "../lib/browser-session.js";
import { browserSessionUtility } from "../lib/browser-session-utils.js";

const NATIVE_HOST_NAME = "com.fabushi.chatgpt_computer_control";

function lineClient(socketPath) {
  const net = require("node:net");
  const socket = net.createConnection(socketPath);
  const messages = [];
  let buffer = "";
  const listeners = new Set();
  socket.on("data", (chunk) => {
    buffer += chunk.toString("utf8");
    while (buffer.includes("\n")) {
      const newline = buffer.indexOf("\n");
      const line = buffer.slice(0, newline);
      buffer = buffer.slice(newline + 1);
      if (!line.trim()) continue;
      const message = JSON.parse(line);
      messages.push(message);
      for (const listener of listeners) listener(message);
    }
  });
  return { socket, messages, onMessage(listener) { listeners.add(listener); } };
}

function writeNativeMessage(stream, message) {
  const payload = Buffer.from(JSON.stringify(message), "utf8");
  const header = Buffer.alloc(4);
  header.writeUInt32LE(payload.length, 0);
  stream.write(Buffer.concat([header, payload]));
}

async function waitFor(check, timeout = 2_000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const value = check();
    if (value) return value;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error("Timed out waiting for browser extension test event.");
}

test("browser extension install creates a stable isolated extension and allow-listed native host", async () => {
  const root = await mkdtemp(join(tmpdir(), "browser-extension-install-"));
  const nativeDir = join(root, "native-manifests");
  const oldHome = process.env.COMPUTER_BROWSER_EXTENSION_HOME;
  process.env.COMPUTER_BROWSER_EXTENSION_HOME = join(root, "bridge");
  try {
    const privateHost = join(root, "private-runtime", "scripts", "browser-extension-host.mjs");
    const runtimeInstaller = async () => ({ root: resolve("."), browserHostPath: privateHost });
    const first = await installBrowserExtension({ currentPlatform: "linux", manifestDestinations: [{ browser: "test", directory: nativeDir }], runtimeInstaller });
    const second = await installBrowserExtension({ currentPlatform: "linux", manifestDestinations: [{ browser: "test", directory: nativeDir }], runtimeInstaller });
    assert.equal(first.extensionId, second.extensionId);
    assert.match(first.extensionId, /^[a-p]{32}$/);
    const manifest = JSON.parse(await readFile(join(first.extension, "manifest.json"), "utf8"));
    assert.equal(manifest.manifest_version, 3);
    assert.ok(manifest.permissions.includes("nativeMessaging"));
    assert.ok(manifest.permissions.includes("debugger"));
    assert.ok(manifest.permissions.includes("tabGroups"));
    assert.ok(manifest.permissions.includes("webNavigation"));
    assert.deepEqual(manifest.host_permissions, ["https://chatgpt.com/*", "https://chat.openai.com/*"]);
    const native = JSON.parse(await readFile(join(nativeDir, `${NATIVE_HOST_NAME}.json`), "utf8"));
    assert.deepEqual(native.allowed_origins, [`chrome-extension://${first.extensionId}/`]);
    assert.equal(native.type, "stdio");
    const launcher = await readFile(first.launcher, "utf8");
    assert.ok(launcher.includes(privateHost));
    assert.equal(first.runtime, resolve("."));
    assert.equal((await browserExtensionStatus()).installed, true);
  } finally {
    if (oldHome === undefined) delete process.env.COMPUTER_BROWSER_EXTENSION_HOME; else process.env.COMPUTER_BROWSER_EXTENSION_HOME = oldHome;
    await rm(root, { recursive: true, force: true });
  }
});

test("private browser bridge authenticates native hosts and correlates extension requests", async () => {
  const root = await mkdtemp(join(tmpdir(), "browser-extension-bridge-"));
  const oldHome = process.env.COMPUTER_BROWSER_EXTENSION_HOME;
  const oldSessions = process.env.COMPUTER_BROWSER_SESSION_DIR;
  process.env.COMPUTER_BROWSER_EXTENSION_HOME = root;
  process.env.COMPUTER_BROWSER_SESSION_DIR = join(root, "sessions");
  const paths = browserExtensionPaths();
  try {
    await mkdir(root, { recursive: true });
    await writeFile(paths.secret, "test-secret-at-least-thirty-two-characters\n", { mode: 0o600 });
    await startBrowserExtensionBridge();
    const client = lineClient(paths.socket);
    await new Promise((resolve, reject) => { client.socket.once("connect", resolve); client.socket.once("error", reject); });
    client.socket.write(`${JSON.stringify({ type: "hello", secret: "test-secret-at-least-thirty-two-characters", instanceId: "instance-test-123", generation: "generation-test-123", browser: "Test Chrome", tabs: [{ id: "7", title: "Signed in", url: "https://example.test/", owner: "user", retained: true }] })}\n`);
    await waitFor(() => client.messages.find((message) => message.type === "hello_ack"));
    assert.equal(listBrowserExtensionConnections()[0].tabs[0].id, "7");
    assert.equal(listBrowserExtensionConnections()[0].generation, "generation-test-123");
    const sessions = await listBrowserSessions();
    const extension = sessions.find((session) => session.kind === "extension");
    assert.ok(extension);
    assert.equal(extension.targets[0].owner, "user");
    assert.match(extension.targets[0].claim, /^[A-Za-z0-9_-]{40,}$/);
    const pending = browserExtensionRequest("instance-test-123", "cdp", { targetId: "7", method: "Page.enable" });
    const request = await waitFor(() => client.messages.find((message) => message.type === "request"));
    client.socket.write(`${JSON.stringify({ type: "response", requestId: request.requestId, ok: true, result: { enabled: true } })}\n`);
    assert.deepEqual(await pending, { enabled: true });

    const extensionCdp = new ExtensionCdpClient("instance-test-123", "7");
    const childPending = extensionCdp.sendSession("child-session-7", "Runtime.evaluate", { expression: "document.title" });
    const childRequest = await waitFor(() => client.messages.find((message) => message.type === "request" && message.params?.sessionId === "child-session-7"));
    assert.equal(childRequest.params.targetId, "7");
    assert.equal(childRequest.params.method, "Runtime.evaluate");
    client.socket.write(`${JSON.stringify({ type: "response", requestId: childRequest.requestId, ok: true, result: { result: { value: "child-frame" } } })}\n`);
    assert.equal((await childPending).result.value, "child-frame");

    const attachPending = extensionCdp.attachFrameTarget("oopif-target-7", "parent-session-7");
    const attachRequest = await waitFor(() => client.messages.find((message) => message.type === "request" && message.command === "cdp_auto_attach_frame"));
    assert.equal(attachRequest.params.targetId, "7");
    assert.equal(attachRequest.params.frameTargetId, "oopif-target-7");
    assert.equal(attachRequest.params.parentSessionId, "parent-session-7");
    client.socket.write(`${JSON.stringify({ type: "response", requestId: attachRequest.requestId, ok: true, result: { sessionId: "oopif-session-7" } })}\n`);
    assert.deepEqual(await attachPending, { sessionId: "oopif-session-7" });

    let captureAttempts = 0;
    const cdpRequests = [];
    client.onMessage((message) => {
      if (message.type !== "request") return;
      let result = {};
      let ok = true;
      let error = "";
      if (message.command === "list_tabs") result = { tabs: [{ id: "7", title: "Signed in", url: "https://example.test/", owner: "user", retained: true }] };
      if (message.command === "cdp") {
        cdpRequests.push(message.params);
        if (message.params?.method === "Runtime.evaluate") result = { result: { value: "signed-in page text" } };
        if (message.params?.method === "Page.captureScreenshot") {
          captureAttempts += 1;
          if (captureAttempts === 1) { ok = false; error = "CDP Page.captureScreenshot timed out."; }
          else result = { data: Buffer.from("test-png").toString("base64") };
        }
      }
      client.socket.write(`${JSON.stringify({ type: "response", requestId: message.requestId, ok, ...(ok ? { result } : { error }) })}\n`);
    });
    const exported = await browserSessionUtility({ name: extension.name, action: "export_text", targetId: extension.targets[0].id, targetClaim: extension.targets[0].claim });
    assert.equal(exported.text, "signed-in page text");

    const cua = await browserSessionCua({ name: extension.name, targetId: extension.targets[0].id, targetClaim: extension.targets[0].claim, actions: [{ action: "move", x: 10, y: 10 }] });
    assert.equal(cua.actionCount, 1);
    assert.equal(cua.screenshot?.mimeType, "image/png");
    assert.equal(captureAttempts, 2);
    assert.ok(cdpRequests.some((request) => request.method === "Page.bringToFront"));
    assert.equal(cdpRequests.filter((request) => request.method === "Page.captureScreenshot").at(-1)?.params?.fromSurface, false);
    client.socket.end();
  } finally {
    await stopBrowserExtensionBridgeForTests().catch(() => {});
    if (oldHome === undefined) delete process.env.COMPUTER_BROWSER_EXTENSION_HOME; else process.env.COMPUTER_BROWSER_EXTENSION_HOME = oldHome;
    if (oldSessions === undefined) delete process.env.COMPUTER_BROWSER_SESSION_DIR; else process.env.COMPUTER_BROWSER_SESSION_DIR = oldSessions;
    await rm(root, { recursive: true, force: true });
  }
});

test("native messaging host reconnects and re-registers after the local bridge restarts", async () => {
  const root = await mkdtemp(join(tmpdir(), "browser-extension-reconnect-"));
  const oldHome = process.env.COMPUTER_BROWSER_EXTENSION_HOME;
  process.env.COMPUTER_BROWSER_EXTENSION_HOME = root;
  const paths = browserExtensionPaths();
  let host;
  try {
    await mkdir(root, { recursive: true });
    await writeFile(paths.secret, "reconnect-secret-at-least-thirty-two-characters\n", { mode: 0o600 });
    await startBrowserExtensionBridge();
    host = spawn(process.execPath, [resolve("scripts/browser-extension-host.mjs")], { env: { ...process.env, COMPUTER_BROWSER_EXTENSION_HOME: root }, stdio: ["pipe", "pipe", "pipe"] });
    host.stdout.resume();
    host.stderr.resume();
    writeNativeMessage(host.stdin, { type: "hello", instanceId: "instance-reconnect-123", generation: "generation-reconnect-123", browser: "Test Chrome", tabs: [{ id: "11", title: "Reconnect", url: "https://example.test/" }] });
    await waitFor(() => listBrowserExtensionConnections().find((item) => item.instanceId === "instance-reconnect-123"));
    await stopBrowserExtensionBridgeForTests();
    await startBrowserExtensionBridge();
    const reconnected = await waitFor(() => listBrowserExtensionConnections().find((item) => item.instanceId === "instance-reconnect-123"), 4_000);
    assert.equal(reconnected.tabs[0].id, "11");
  } finally {
    host?.kill();
    await stopBrowserExtensionBridgeForTests().catch(() => {});
    if (oldHome === undefined) delete process.env.COMPUTER_BROWSER_EXTENSION_HOME; else process.env.COMPUTER_BROWSER_EXTENSION_HOME = oldHome;
    await rm(root, { recursive: true, force: true });
  }
});

test("packaged extension contains no remotely hosted executable code", async () => {
  const manifest = JSON.parse(await readFile(resolve("extension/manifest.json"), "utf8"));
  const serviceWorker = await readFile(resolve("extension/service-worker.js"), "utf8");
  const background = await readFile(resolve("extension/background.js"), "utf8");
  const appHtml = await readFile(resolve("extension/app.html"), "utf8");
  assert.equal(manifest.background.service_worker, "service-worker.js");
  assert.equal(manifest.background.type, "module");
  assert.match(serviceWorker, /import "\.\/background\.js"/);
  assert.match(serviceWorker, /import "\.\/userscripts\.js"/);
  assert.doesNotMatch(`${serviceWorker}\n${background}\n${appHtml}`, /eval\s*\(|new Function\s*\(|<script[^>]+src=["']https?:\/\//i);
  assert.match(background, /claim_tab/);
  assert.match(background, /chrome\.debugger\.sendCommand/);
  assert.match(background, /sessionId/);
  assert.match(background, /Target\.setAutoAttach/);
  assert.match(background, /cdp_auto_attach_frame/);
  assert.match(background, /chrome\.storage\.session/);
  assert.match(background, /onCreatedNavigationTarget/);
  assert.match(background, /ensureAutomationGroup/);
  assert.match(background, /HEARTBEAT_ALARM/);
});

test("extension app is the popup and Marketplace filters userscripts to chrome-extension", async () => {
  const manifest = JSON.parse(await readFile(resolve("extension/manifest.json"), "utf8"));
  const appHtml = await readFile(resolve("extension/app.html"), "utf8");
  const appJs = await readFile(resolve("extension/app.js"), "utf8");

  assert.equal(manifest.action.default_popup, "app.html");
  assert.match(appHtml, /Fabushi/);
  assert.match(appHtml, /Chats/);
  assert.match(appHtml, /Mini Apps/);
  assert.match(appHtml, /Marketplace/);
  assert.match(appHtml, /app-search/);
  assert.match(appHtml, /loading-state/);
  assert.match(appHtml, /empty-state/);
  assert.match(appHtml, /error-state/);
  assert.match(appHtml, /data-platform="chrome-extension"/);
  assert.match(appJs, /MARKETPLACE_SECTION/);
  assert.match(appJs, /item\.kind === "userscript"/);
  assert.match(appJs, /currentPlatform === "chrome-extension"/);
  assert.match(appJs, /item\.surfaces\.length === 1/);
  assert.match(appJs, /normalizedSearchText/);
  assert.match(appJs, /getVisibleMarketplaceItems/);
});
