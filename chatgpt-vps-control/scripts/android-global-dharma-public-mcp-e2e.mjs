#!/usr/bin/env node
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { appendFileSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

const origin = String(process.env.FABUSHI_MCP_ORIGIN || "https://fabushi-mcp.ombhrum.com").replace(/\/$/u, "");
const mcpUrl = `${origin}/mcp`;
const username = String(process.env.FABUSHI_CI_TEST_USERNAME || "").trim();
const password = String(process.env.FABUSHI_CI_TEST_PASSWORD || "");
const expectedDeviceId = String(process.env.EXPECTED_DEVICE_ID || process.env.DEVICE_ID || "").trim();
const evidenceDir = String(process.env.EVIDENCE_DIR || "").trim();
const tracePath = evidenceDir ? join(evidenceDir, "ci-public-mcp-driver.jsonl") : "";
const stepDir = evidenceDir ? join(evidenceDir, "steps") : "";

if (!username || !password) throw new Error("managed Fabushi test account credentials are required");
if (!/^gha-[0-9]+-[0-9]+-interactive$/u.test(expectedDeviceId)) {
  throw new Error("EXPECTED_DEVICE_ID must be a protected Android interactive Runner id");
}
if (!evidenceDir) throw new Error("EVIDENCE_DIR is required");
mkdirSync(stepDir, { recursive: true });

function record(phase, data = {}) {
  const row = { timestamp: new Date().toISOString(), phase, deviceId: expectedDeviceId, ...data };
  appendFileSync(tracePath, `${JSON.stringify(row)}\n`, "utf8");
  process.stdout.write(`[android-global-dharma] ${phase} ${JSON.stringify(data)}\n`);
}

function screenshot(name) {
  const output = execFileSync("adb", ["exec-out", "screencap", "-p"], { encoding: null, maxBuffer: 20 * 1024 * 1024 });
  writeFileSync(join(stepDir, `${name}.png`), output);
  record("screenshot", { name });
}

function adb(...args) {
  return execFileSync("adb", args, { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 }).trim();
}

function uiXml() {
  adb("shell", "uiautomator", "dump", "/sdcard/fabushi-window.xml");
  return adb("exec-out", "cat", "/sdcard/fabushi-window.xml");
}

function xmlDecode(value) {
  return String(value || "")
    .replaceAll("&quot;", '"')
    .replaceAll("&apos;", "'")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&amp;", "&");
}

function findUiNodeByText(fragment) {
  const xml = uiXml();
  const nodes = [...xml.matchAll(/<node\b[^>]*>/gu)].map((match) => match[0]);
  for (const node of nodes) {
    const text = xmlDecode(/\btext="([^"]*)"/u.exec(node)?.[1] || "");
    const desc = xmlDecode(/\bcontent-desc="([^"]*)"/u.exec(node)?.[1] || "");
    if (!text.includes(fragment) && !desc.includes(fragment)) continue;
    const bounds = /\bbounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/u.exec(node);
    if (!bounds) continue;
    return {
      text,
      desc,
      x: Math.round((Number(bounds[1]) + Number(bounds[3])) / 2),
      y: Math.round((Number(bounds[2]) + Number(bounds[4])) / 2),
    };
  }
  return null;
}

async function waitForUiText(fragment, timeoutMs = 30_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const node = findUiNodeByText(fragment);
    if (node) return node;
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`UI text did not appear: ${fragment}`);
}

async function tapUiText(fragment, screenshotName) {
  const node = await waitForUiText(fragment);
  adb("shell", "input", "tap", String(node.x), String(node.y));
  record("ui-tap", { fragment, x: node.x, y: node.y });
  await new Promise((resolve) => setTimeout(resolve, 900));
  if (screenshotName) screenshot(screenshotName);
}

const redirectUri = "http://127.0.0.1/callback";
const verifier = "v".repeat(64);
const challenge = createHash("sha256").update(verifier).digest("base64url");

async function authorizeMcp() {
  record("oauth-start");
  const registrationResponse = await fetch(`${origin}/oauth/register`, {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify({ redirect_uris: [redirectUri] }),
  });
  if (!registrationResponse.ok) throw new Error(`dynamic client registration failed: HTTP ${registrationResponse.status}`);
  const registration = await registrationResponse.json();
  if (!registration?.client_id) throw new Error("dynamic client registration returned no client_id");

  const authorizeUrl = new URL(`${origin}/oauth/authorize`);
  authorizeUrl.search = new URLSearchParams({
    client_id: registration.client_id,
    redirect_uri: redirectUri,
    response_type: "code",
    state: "ci-android-global-dharma-e2e",
    scope: "devices.read devices.control",
    resource: mcpUrl,
    code_challenge: challenge,
    code_challenge_method: "S256",
  }).toString();
  const authorizeResponse = await fetch(authorizeUrl, { redirect: "manual" });
  if (authorizeResponse.status !== 302) throw new Error(`authorization start failed: HTTP ${authorizeResponse.status}`);
  const loginLocation = authorizeResponse.headers.get("location");
  if (!loginLocation) throw new Error("authorization start returned no Fabushi login URL");
  const loginUrl = new URL(loginLocation);
  if (loginUrl.hostname !== "api.ombhrum.com" || loginUrl.pathname !== "/api/auth/browser/portal") {
    throw new Error("authorization did not redirect to the canonical Fabushi login portal");
  }
  const attemptId = loginUrl.searchParams.get("attemptId") || "";
  const ticket = loginUrl.searchParams.get("ticket") || "";
  if (!attemptId || !ticket) throw new Error("Fabushi login portal URL is missing attempt binding");

  const passwordResponse = await fetch(new URL("/api/auth/browser/password", loginUrl.origin), {
    method: "POST",
    redirect: "manual",
    headers: { "content-type": "application/x-www-form-urlencoded;charset=UTF-8" },
    body: new URLSearchParams({ attemptId, ticket, username, password }),
  });
  if (![200, 302, 303].includes(passwordResponse.status)) {
    throw new Error(`Fabushi browser password login failed: HTTP ${passwordResponse.status}`);
  }
  const passwordBody = await passwordResponse.text();
  const passwordRedirect = passwordResponse.headers.get("location") || "";
  const completionMatch = `${passwordRedirect}\n${passwordBody}`.match(/https:\/\/fabushi-mcp\.ombhrum\.com\/oauth\/fabushi\/complete\?request_id=([A-Za-z0-9_-]{32,128})/u);
  if (!completionMatch) throw new Error("Fabushi browser login did not return to the MCP completion endpoint");
  const requestId = completionMatch[1];

  let authorization = null;
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const response = await fetch(`${origin}/oauth/fabushi/status?request_id=${encodeURIComponent(requestId)}`, {
      headers: { accept: "application/json" },
      cache: "no-store",
    });
    if (!response.ok) throw new Error(`MCP authorization status failed: HTTP ${response.status}`);
    authorization = await response.json();
    if (authorization.status === "completed") break;
    if (["failed", "expired", "cancelled"].includes(authorization.status)) {
      throw new Error(`MCP authorization ended as ${authorization.status}`);
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  if (authorization?.status !== "completed" || !authorization.redirectUrl) {
    throw new Error("MCP authorization did not complete in time");
  }
  const callback = new URL(authorization.redirectUrl);
  const code = callback.searchParams.get("code") || "";
  if (!code) throw new Error("MCP callback did not contain an authorization code");

  const tokenResponse = await fetch(`${origin}/oauth/token`, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded", accept: "application/json" },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      client_id: registration.client_id,
      redirect_uri: redirectUri,
      resource: mcpUrl,
      code,
      code_verifier: verifier,
    }),
  });
  if (!tokenResponse.ok) throw new Error(`MCP token exchange failed: HTTP ${tokenResponse.status}`);
  const tokens = await tokenResponse.json();
  if (!tokens?.access_token) throw new Error("MCP token exchange returned no access token");
  record("oauth-complete");
  return tokens.access_token;
}

function parseRelay(result, toolName) {
  const structured = result?.structuredContent && typeof result.structuredContent === "object"
    ? result.structuredContent
    : {};
  if (String(structured.status || "") !== "completed") {
    throw new Error(`device_call ${toolName} did not complete: ${JSON.stringify(structured).slice(0, 1200)}`);
  }
  if (typeof structured.resultJson !== "string" || !structured.resultJson) {
    throw new Error(`device_call ${toolName} returned no resultJson`);
  }
  const envelope = JSON.parse(structured.resultJson);
  if (envelope?.isError === true || envelope?.ok === false) {
    throw new Error(`device_call ${toolName} returned an error: ${JSON.stringify(envelope).slice(0, 1200)}`);
  }
  const payload = envelope?.structuredContent && typeof envelope.structuredContent === "object"
    ? envelope.structuredContent
    : envelope;
  record("semantic-call", { toolName, ok: true, screen: payload?.screen, generation: payload?.generation });
  return payload;
}

const accessToken = await authorizeMcp();
const transport = new StreamableHTTPClientTransport(new URL(mcpUrl), {
  requestInit: { headers: { Authorization: `Bearer ${accessToken}` } },
});
const client = new Client({ name: "fabushi-android-global-dharma-ci-e2e", version: "1.0.0" });

async function waitForDevice() {
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const listed = await client.callTool({ name: "list_devices", arguments: {} });
    const devices = listed?.structuredContent?.devices || [];
    if (devices.some((candidate) => candidate?.id === expectedDeviceId)) {
      record("device-discovered");
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  throw new Error(`expected same-account Android device ${expectedDeviceId} was not returned by list_devices`);
}

async function callDevice(toolName, args = {}) {
  const result = await client.callTool({
    name: "device_call",
    arguments: { deviceId: expectedDeviceId, toolName, argumentsJson: JSON.stringify(args) },
  });
  return parseRelay(result, toolName);
}

async function snapshot() {
  return callDevice("fabushi.app.snapshot", { maxElements: 500, includeText: true });
}

async function action(agentId, actionName, value) {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const current = await snapshot();
    const element = (current.elements || []).find((item) => item?.agentId === agentId);
    if (!element) throw new Error(`semantic element not found: ${agentId} on ${current.screen}`);
    try {
      return await callDevice("fabushi.app.action", {
        generation: current.generation,
        agentId,
        action: actionName,
        ...(value === undefined ? {} : { value }),
      });
    } catch (error) {
      if (!String(error?.message || error).includes("stale_app_surface_generation") || attempt === 2) throw error;
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
  }
  throw new Error(`semantic action failed: ${agentId}`);
}

async function waitElement(agentId, state = "present", timeoutMs = 30_000) {
  const result = await callDevice("fabushi.app.wait", { agentId, state, timeoutMs });
  if (result.passed !== true) throw new Error(`wait failed for ${agentId}: ${JSON.stringify(result.failures || [])}`);
  return result;
}

async function assertElement(agentId, state = "present") {
  const result = await callDevice("fabushi.app.assert", { agentId, state });
  if (result.passed !== true) throw new Error(`assert failed for ${agentId}: ${JSON.stringify(result.failures || [])}`);
  return result;
}

async function waitSnapshot(predicate, description, timeoutMs = 30_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const current = await snapshot();
    if (predicate(current)) return current;
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`semantic snapshot condition timed out: ${description}`);
}

try {
  await client.connect(transport);
  await waitForDevice();
  await callDevice("fabushi.app.status", {});
  await callDevice("fabushi.app.find", { role: "application", limit: 20 });
  screenshot("100-ci-driver-start");

  let current = await snapshot();
  if (current.screen === "grok-home") {
    await action("grok-mobile-legacy", "invoke");
    await new Promise((resolve) => setTimeout(resolve, 700));
  }
  current = await waitSnapshot((value) => value.screen === "home", "legacy Fabushi home");
  await action("profile-avatar", "invoke");
  await waitElement("marketplace-entry", "present");
  await action("marketplace-entry", "invoke");
  await waitSnapshot((value) => value.screen === "marketplace", "Marketplace screen");
  screenshot("110-marketplace-open");

  await action("marketplace-search", "setValue", "全球法布施");
  await action("marketplace-search-submit", "invoke");
  await waitElement("plugin-global-dharma", "present", 30_000);
  screenshot("120-global-dharma-search");

  current = await snapshot();
  const install = (current.elements || []).find((item) => item?.agentId === "install-global-dharma");
  if (install?.enabled === true) {
    await action("install-global-dharma", "invoke");
  }
  await waitSnapshot(
    (value) => (value.elements || []).some((item) => item?.agentId === "host-status" && String(item?.name || "").includes("global-dharma 已安装")),
    "canonical Global Dharma installed state",
    45_000,
  );
  screenshot("130-global-dharma-installed");

  await action("app-shell", "pressKey", "BACK");
  await waitSnapshot((value) => value.screen === "grok-home", "Grok Messenger home");
  await waitElement("grok-bot-global-dharma-bot", "present", 30_000);
  screenshot("140-global-dharma-bot-projected");
  await action("grok-bot-global-dharma-bot", "invoke");
  await waitSnapshot((value) => value.screen === "bot-chat", "Global Dharma Bot chat");
  await waitElement("mobile-bot-open-miniapp", "enabled", 30_000);
  screenshot("150-global-dharma-bot-open");

  await action("mobile-bot-draft", "setValue", "please show status now");
  await action("mobile-bot-send", "invoke");
  await waitSnapshot(
    (value) => value.screen === "bot-chat" && (value.elements || []).some((item) => item?.agentId === "mobile-bot-send" && item?.enabled === false),
    "Bot natural-language command completes",
    60_000,
  ).catch(async () => waitSnapshot(
    (value) => value.screen === "bot-chat" && (value.elements || []).some((item) => item?.agentId === "mobile-bot-send"),
    "Bot natural-language command returns to idle",
    60_000,
  ));
  await assertElement("mobile-bot-error", "absent");
  screenshot("160-bot-webmcp-command-complete");

  await action("mobile-bot-open-miniapp", "invoke");
  await waitForUiText("本地 WebMCP 已连接", 45_000);
  await waitForUiText("Fabushi 已登录", 45_000);
  screenshot("170-miniapp-web-ui-synced");
  record("miniapp-opened", { webMcp: true, autoLogin: true });

  const beforePurchaseXml = uiXml();
  const alreadyAllowed = beforePurchaseXml.includes("本地转经轮：已解锁");
  if (!alreadyAllowed) {
    await tapUiText("¥1080 买断（测试）", "180-purchase-requested");
    await waitForUiText("本地转经轮：已解锁", 45_000);
    await waitForUiText("¥1080 买断权益已由服务端确认", 45_000);
    screenshot("181-purchase-entitlement-confirmed");
    record("purchase-verified", { amountMinor: 108000, currency: "CNY", sku: "prod.global-dharma.local-prayer-wheel.lifetime" });
  } else {
    record("purchase-already-entitled", { allowed: true });
  }

  await tapUiText("恢复购买", "190-restore-requested");
  await waitForUiText("权益恢复完成", 45_000);
  await waitForUiText("本地转经轮：已解锁", 45_000);
  screenshot("191-restore-entitlement-confirmed");
  record("restore-verified", { allowed: true });

  adb("shell", "input", "keyevent", "4");
  await new Promise((resolve) => setTimeout(resolve, 700));
  current = await waitSnapshot((value) => value.screen === "bot-chat", "return from Mini App to Bot", 30_000);
  await action("mobile-bot-close", "invoke");
  await waitSnapshot((value) => value.screen === "grok-home", "return to Grok home", 30_000);
  await action("grok-mobile-legacy", "invoke");
  await waitSnapshot((value) => value.screen === "home", "legacy home before logout", 30_000);
  await action("profile-avatar", "invoke");
  await waitElement("mobile-logout", "present", 20_000);
  screenshot("198-before-logout");
  await action("mobile-logout", "invoke");
  record("journey-complete", { status: "passed-logged-out" });
} finally {
  await client.close().catch(() => {});
}
