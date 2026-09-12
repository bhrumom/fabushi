#!/usr/bin/env node

import { createHash, generateKeyPairSync } from "node:crypto";
import { createServer } from "node:http";
import { chmod, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(here, "../..");
const extensionRoot = resolve(repositoryRoot, "chatgpt-vps-control");
const packageRoot = join(extensionRoot, "dist", "chrome-extension");
const packageZip = process.env.FABUSHI_CHROME_ZIP
  ? resolve(process.env.FABUSHI_CHROME_ZIP)
  : join(packageRoot, "fabushi-chrome-0.5.0.zip");
const evidenceRoot = resolve(process.env.FABUSHI_CHROME_EVIDENCE_DIR || join(packageRoot, "evidence"));
const journeyId = "CWA-006-chrome-packaged-browser-control";
const sourceSha = String(process.env.GITHUB_SHA || "unknown");
const runId = String(process.env.GITHUB_RUN_ID || "local");
const startedAt = new Date().toISOString();

const { chromium } = await import(pathToFileURL(join(repositoryRoot, "desktop", "node_modules", "playwright", "index.mjs")).href);

function extensionIdFromPublicKey(publicKey) {
  const digest = createHash("sha256").update(Buffer.from(publicKey, "base64")).digest().subarray(0, 16);
  return [...digest]
    .flatMap((byte) => [byte >> 4, byte & 15])
    .map((nibble) => String.fromCharCode(97 + nibble))
    .join("");
}

async function waitFor(check, timeoutMs = 30_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const value = await check();
    if (value) return value;
    await new Promise((resolvePromise) => setTimeout(resolvePromise, 100));
  }
  throw new Error(`Timed out after ${timeoutMs}ms waiting for the packaged Chrome journey.`);
}

async function captureCheckpoint(page, path) {
  let lastError = null;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      // A viewport screenshot is deterministic under xvfb and avoids the
      // transient full-page capture failure seen while Chrome is settling a
      // newly navigated document.
      await page.screenshot({ path, fullPage: false, animations: "disabled" });
      return;
    } catch (error) {
      lastError = error;
      await page.waitForTimeout(250).catch(() => {});
    }
  }
  throw lastError || new Error(`Unable to capture checkpoint: ${path}`);
}

async function writeNativeHostManifest(directory, host) {
  await mkdir(directory, { recursive: true, mode: 0o700 });
  await writeFile(join(directory, `${host.name}.json`), `${JSON.stringify(host, null, 2)}\n`, { mode: 0o600 });
}

function fakeBrowserHostSource({ resultPath, screenshotPath, pidPath }) {
  return `#!/usr/bin/env node
const fs = require("node:fs");
const resultPath = ${JSON.stringify(resultPath)};
const screenshotPath = ${JSON.stringify(screenshotPath)};
const pidPath = ${JSON.stringify(pidPath)};
let buffer = Buffer.alloc(0);
let hello = null;
let selected = null;
let sentList = false;
let phase = "waiting-for-tabs";
let sequence = 0;
const events = [];
const pending = new Map();

try { fs.writeFileSync(pidPath, String(process.pid) + "\\n", { mode: 0o600 }); } catch {}
function record(type, detail = {}) {
  events.push({ type, at: new Date().toISOString(), ...detail });
  try { fs.writeFileSync(resultPath, JSON.stringify({ journeyId: ${JSON.stringify(journeyId)}, sourceSha: ${JSON.stringify(sourceSha)}, runId: ${JSON.stringify(runId)}, events }, null, 2) + "\\n"); } catch {}
}
record("host-started", { pid: process.pid });
process.on("uncaughtException", (error) => {
  record("failure", { message: "uncaughtException: " + (error?.stack || error?.message || String(error)) });
  process.exitCode = 1;
});
process.on("unhandledRejection", (error) => {
  record("failure", { message: "unhandledRejection: " + (error?.stack || error?.message || String(error)) });
  process.exitCode = 1;
});
function send(message) {
  const body = Buffer.from(JSON.stringify(message), "utf8");
  const header = Buffer.alloc(4);
  header.writeUInt32LE(body.length, 0);
  process.stdout.write(Buffer.concat([header, body]));
}
function request(command, params = {}) {
  const requestId = "e2e-" + (++sequence);
  pending.set(requestId, { command, params });
  send({ type: "request", requestId, command, params });
}
function fail(message) {
  record("failure", { message: String(message) });
  process.exitCode = 1;
}
function maybeStartListing(tabs) {
  if (!hello || sentList || !Array.isArray(tabs)) return;
  if (!tabs.some((tab) => /^https?:\\/\\//i.test(String(tab.url || "")))) return;
  sentList = true;
  phase = "list-tabs";
  request("list_tabs");
}
function nextAfterResponse(message, pendingRequest) {
  if (message.ok === false) {
    if (phase === "stale-claim") {
      record("stale-generation-rejected", { error: message.error });
      phase = "claim";
      request("claim_tab", { ...selected, generation: hello.generation });
      return;
    }
    fail(pendingRequest.command + ": " + (message.error || "request failed"));
    return;
  }
  if (phase === "list-tabs") {
    const tabs = message.result?.tabs || [];
    selected = tabs.find((tab) => /^https?:\\/\\//i.test(String(tab.url || "")));
    if (!selected) { fail("list_tabs returned no ordinary HTTP(S) tab"); return; }
    record("list-tabs", { tab: selected });
    phase = "stale-claim";
    request("claim_tab", { targetId: selected.id, title: selected.title, url: selected.url, generation: "stale-generation" });
    return;
  }
  if (phase === "claim") {
    record("claim-tab", { result: message.result });
    phase = "page-enable";
    request("cdp", { targetId: selected.id, method: "Page.enable", params: {} });
    return;
  }
  if (phase === "page-enable") {
    phase = "evaluate";
    request("cdp", { targetId: selected.id, method: "Runtime.evaluate", params: { expression: "document.title", returnByValue: true } });
    return;
  }
  if (phase === "evaluate") {
    record("cdp-evaluate", { result: message.result });
    phase = "screenshot";
    request("cdp", { targetId: selected.id, method: "Page.captureScreenshot", params: { format: "png", fromSurface: true, captureBeyondViewport: false } });
    return;
  }
  if (phase === "screenshot") {
    const data = String(message.result?.data || "");
    if (!data) { fail("Page.captureScreenshot returned no data"); return; }
    try { fs.writeFileSync(screenshotPath, Buffer.from(data, "base64"), { mode: 0o600 }); } catch (error) { fail(error.message); return; }
    record("cdp-screenshot", { bytes: fs.statSync(screenshotPath).size, path: screenshotPath });
    phase = "activate";
    request("tab_action", { targetId: selected.id, action: "activate_tab" });
    return;
  }
  if (phase === "activate") {
    record("tab-action", { action: "activate_tab" });
    phase = "detach";
    request("detach", { targetId: selected.id });
    return;
  }
  if (phase === "detach") {
    record("detach", { result: message.result });
    phase = "complete";
    record("complete", { success: true });
    return;
  }
}
function handle(message) {
  if (message?.type === "hello") {
    hello = message;
    record("hello", { generation: message.generation, tabs: message.tabs || [] });
    send({ type: "hello_ack" });
    maybeStartListing(message.tabs || []);
    return;
  }
  if (message?.type === "tabs") {
    record("tabs-event", { tabs: message.tabs || [] });
    maybeStartListing(message.tabs || []);
    return;
  }
  if (message?.type === "response") {
    const requestInfo = pending.get(String(message.requestId || ""));
    if (!requestInfo) return;
    pending.delete(String(message.requestId));
    nextAfterResponse(message, requestInfo);
  }
}
process.stdin.on("data", (chunk) => {
  buffer = Buffer.concat([buffer, chunk]);
  while (buffer.length >= 4) {
    const length = buffer.readUInt32LE(0);
    if (length > 16 * 1024 * 1024) process.exit(2);
    if (buffer.length < length + 4) return;
    const body = buffer.subarray(4, length + 4);
    buffer = buffer.subarray(length + 4);
    try { handle(JSON.parse(body.toString("utf8"))); } catch (error) { fail(error.message); }
  }
});
process.stdin.on("end", () => { if (phase !== "complete") fail("native messaging stream ended before the journey completed"); });
`;
}

await rm(evidenceRoot, { recursive: true, force: true });
await mkdir(evidenceRoot, { recursive: true, mode: 0o700 });
const tempRoot = await (await import("node:fs/promises")).mkdtemp(join((await import("node:os")).tmpdir(), "fabushi-chrome-packaged-e2e-"));
const profileRoot = join(tempRoot, "profile");
const unpackedRoot = join(tempRoot, "extension");
const resultPath = join(evidenceRoot, "native-journey.json");
const screenshotPath = join(evidenceRoot, "06-cdp-screenshot.png");
const pidPath = join(tempRoot, "native-host.pid");
const hostScript = join(tempRoot, "fake-browser-host.mjs");
let context = null;
let server = null;
let appPage = null;
let fixturePage = null;
let journeyError = null;
const nativeManifestPaths = [];
const steps = [];
const report = {
  schemaVersion: 1,
  journeyId,
  sourceSha,
  runId,
  version: "0.5.0",
  platform: process.platform,
  startedAt,
  steps,
  packageZip,
};

function step(name, detail = {}) {
  const value = { name, at: new Date().toISOString(), ...detail };
  steps.push(value);
  return value;
}

try {
  await mkdir(unpackedRoot, { recursive: true });
  execFileSync("unzip", ["-q", packageZip, "-d", unpackedRoot]);
  const manifestPath = join(unpackedRoot, "manifest.json");
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
  const { publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const publicKeyBase64 = publicKey.export({ type: "spki", format: "der" }).toString("base64");
  const extensionId = extensionIdFromPublicKey(publicKeyBase64);
  manifest.key = publicKeyBase64;
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600 });
  const hostSource = fakeBrowserHostSource({ resultPath, screenshotPath, pidPath });
  await writeFile(hostScript, hostSource, { mode: 0o700 });
  await chmod(hostScript, 0o700);
  const nativeHost = {
    name: "com.fabushi.browser_control",
    description: "Fabushi packaged journey test host",
    path: hostScript,
    type: "stdio",
    allowed_origins: [`chrome-extension://${extensionId}/`],
  };
  const home = homedir();
  for (const directory of [
    join(home, ".config", "google-chrome", "NativeMessagingHosts"),
    join(home, ".config", "chromium", "NativeMessagingHosts"),
    // Chrome for Testing uses a product-specific profile root on some Linux
    // runners. Keep these exact test-only manifests scoped to the ephemeral
    // host and remove them in finally below.
    join(home, ".config", "google-chrome-for-testing", "NativeMessagingHosts"),
    join(home, ".config", "chrome-for-testing", "NativeMessagingHosts"),
    ...(process.env.XDG_CONFIG_HOME ? [join(resolve(process.env.XDG_CONFIG_HOME), "google-chrome", "NativeMessagingHosts")] : []),
    ...(process.env.XDG_CONFIG_HOME ? [join(resolve(process.env.XDG_CONFIG_HOME), "chromium", "NativeMessagingHosts")] : []),
  ]) {
    await writeNativeHostManifest(directory, nativeHost);
    nativeManifestPaths.push(join(directory, `${nativeHost.name}.json`));
  }
  step("native-host-setup", {
    host: nativeHost.name,
    home,
    envHome: process.env.HOME || null,
    xdgConfigHome: process.env.XDG_CONFIG_HOME || null,
    manifests: nativeManifestPaths,
    hostScript,
  });

  server = createServer((request, response) => {
    response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
    response.end("<!doctype html><title>Fabushi E2E</title><main><h1>Fabushi packaged journey</h1><button id=continue>Continue</button></main>");
  });
  await new Promise((resolvePromise, rejectPromise) => {
    server.once("error", rejectPromise);
    server.listen(0, "127.0.0.1", () => { server.off("error", rejectPromise); resolvePromise(); });
  });
  const address = server.address();
  const fixtureUrl = `http://127.0.0.1:${address.port}/fixture`;

  context = await chromium.launchPersistentContext(profileRoot, {
    headless: false,
    viewport: { width: 1280, height: 800 },
    recordVideo: { dir: evidenceRoot, size: { width: 1280, height: 800 } },
    args: [
      `--disable-extensions-except=${unpackedRoot}`,
      `--load-extension=${unpackedRoot}`,
      "--no-first-run",
      "--no-default-browser-check",
      "--disable-background-networking",
      `--enable-logging=stderr`,
      `--log-file=${join(evidenceRoot, "chrome.log")}`,
    ],
  });
  context.on("serviceworker", (worker) => {
    step("service-worker-start", { url: worker.url() });
    worker.on("console", (message) => step("service-worker-console", { type: message.type(), text: message.text() }));
    worker.on("pageerror", (error) => step("service-worker-pageerror", { error: error?.message || String(error) }));
  });
  await context.tracing.start({ screenshots: true, snapshots: true, sources: true });
  fixturePage = context.pages()[0] || await context.newPage();
  fixturePage.on("console", (message) => step("fixture-console", { type: message.type(), text: message.text() }));
  fixturePage.on("pageerror", (error) => step("fixture-pageerror", { error: error?.message || String(error) }));
  await fixturePage.goto(fixtureUrl, { waitUntil: "domcontentloaded" });
  await captureCheckpoint(fixturePage, join(evidenceRoot, "01-startup-fixture.png"));
  step("startup", { url: fixtureUrl });

  // The generated manifest key gives us the extension origin before the
  // worker is first woken. Playwright only reports currently-running workers,
  // so waiting for that transient object would make a healthy MV3 extension
  // look broken after an idle/awake transition. Keep a short diagnostic wait,
  // then navigate using the deterministic origin and let app traffic wake it.
  await waitFor(() => context.serviceWorkers().find((worker) => worker.url().startsWith("chrome-extension://")), 10_000)
    .then(() => step("service-worker-ready"))
    .catch((error) => step("service-worker-not-observed", { error: error?.message || String(error) }));
  const extensionOrigin = `chrome-extension://${extensionId}`;
  appPage = await context.newPage();
  appPage.on("console", (message) => step("app-console", { type: message.type(), text: message.text() }));
  appPage.on("pageerror", (error) => step("app-pageerror", { error: error?.message || String(error) }));
  await appPage.goto(`${extensionOrigin}/app.html`, { waitUntil: "domcontentloaded" });
  await appPage.getByText("Marketplace", { exact: true }).first().waitFor({ state: "visible", timeout: 10_000 });
  await captureCheckpoint(appPage, join(evidenceRoot, "02-fabushi-shell.png"));
  step("fabushi-shell", { extensionId, origin: extensionOrigin });
  await appPage.locator('[data-view="browser"]').first().click();
  await appPage.getByText("当前 Chrome", { exact: true }).waitFor({ state: "visible", timeout: 5_000 });
  await captureCheckpoint(appPage, join(evidenceRoot, "03-browser-view.png"));
  step("browser-view");
  const browserStatus = await appPage.evaluate(() => new Promise((resolvePromise) => {
    chrome.runtime.sendMessage({ type: "fabushi.browser.status" }, (response) => {
      const runtimeError = chrome.runtime.lastError;
      resolvePromise({ response: response || null, error: runtimeError?.message || null });
    });
  }));
  step("browser-status", browserStatus);

  const nativeResult = await waitFor(async () => {
    try {
      const parsed = JSON.parse(await readFile(resultPath, "utf8"));
      return parsed.events?.some((event) => event.type === "complete") ? parsed : null;
    } catch { return null; }
  }, 45_000);
  if (nativeResult.events.some((event) => event.type === "failure")) throw new Error("Packaged native browser journey reported a failure.");
  await captureCheckpoint(fixturePage, join(evidenceRoot, "05-after-browser-control.png"));
  step("browser-control", { events: nativeResult.events.map((event) => event.type) });
  report.nativeJourney = nativeResult;
} catch (error) {
  journeyError = error instanceof Error ? error : new Error(String(error));
  report.error = journeyError.message;
  step("failure", { error: journeyError.message });
} finally {
  try { await context?.tracing.stop({ path: join(evidenceRoot, "trace.zip") }); } catch (error) { report.traceError = String(error); }
  const videos = [fixturePage?.video(), appPage?.video()].filter(Boolean);
  try { await context?.close(); } catch (error) { report.closeError = String(error); }
  for (const video of videos) {
    try { report.video = await video.path(); break; } catch {}
  }
  try { server?.close(); } catch {}
  try {
    const pid = Number((await readFile(pidPath, "utf8")).trim());
    if (Number.isInteger(pid) && pid > 1) process.kill(pid, "SIGTERM");
  } catch {}
  for (const manifestPath of nativeManifestPaths) await rm(manifestPath, { force: true }).catch(() => {});
  report.finishedAt = new Date().toISOString();
  await writeFile(join(evidenceRoot, "journey-report.json"), `${JSON.stringify(report, null, 2)}\n`, { mode: 0o600 });
  const html = `<!doctype html><meta charset="utf-8"><title>${journeyId}</title><h1>${journeyId}</h1><p>source=${sourceSha} run=${runId} version=0.5.0</p><p>status=${journeyError ? "failed" : "passed"}</p><pre>${JSON.stringify(report, null, 2).replaceAll("&", "&amp;").replaceAll("<", "&lt;")}</pre>`;
  await writeFile(join(evidenceRoot, "playwright-report.html"), html, { mode: 0o600 });
  await rm(tempRoot, { recursive: true, force: true }).catch(() => {});
}

if (journeyError) throw journeyError;
console.log(`Packaged Chrome journey passed: ${journeyId}`);
