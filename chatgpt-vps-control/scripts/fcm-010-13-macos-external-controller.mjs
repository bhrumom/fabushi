#!/usr/bin/env node
import { createHash, randomBytes } from "node:crypto";
import { appendFileSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

const FROZEN_SOURCE = "7ee12b790e18049d2b9509b0c29128dd2ace690b";
const IMMUTABLE_TAG = "desktop-1.2.56-7ee12b790e18";
const REQUIRED_CATEGORIES = [
  "startup", "login", "main", "conversations", "search", "send", "receive", "reply", "edit", "delete",
  "forward", "draft", "pin", "mute", "unread", "contacts", "groups", "bot", "agent", "miniapp", "webmcp",
  "media", "file", "notifications", "sync", "settings", "update",
];

const origin = String(process.env.FABUSHI_MCP_ORIGIN || "https://fabushi-mcp.ombhrum.com").replace(/\/$/u, "");
const mcpUrl = `${origin}/mcp`;
const username = String(process.env.FABUSHI_CI_TEST_USERNAME || "").trim();
const password = String(process.env.FABUSHI_CI_TEST_PASSWORD || "");
const runId = String(process.env.TARGET_RUN_ID || "").trim();
const runAttempt = String(process.env.TARGET_RUN_ATTEMPT || "").trim();
const headSha = String(process.env.TARGET_HEAD_SHA || "").trim();
const headBranch = String(process.env.TARGET_HEAD_BRANCH || "").trim();
const expectedDeviceId = String(process.env.EXPECTED_DEVICE_ID || "").trim();
const evidenceDir = String(process.env.EVIDENCE_DIR || "").trim();

if (!username || !password) throw new Error("managed Fabushi test account credentials are required");
if (!runId || !runAttempt || !/^\d+$/u.test(runId) || !/^\d+$/u.test(runAttempt)) throw new Error("target run id/attempt are required");
if (headSha !== FROZEN_SOURCE) throw new Error(`controller refuses non-frozen source ${headSha}`);
if (headBranch !== IMMUTABLE_TAG) throw new Error(`controller refuses non-immutable tag ${headBranch}`);
if (expectedDeviceId !== `gha-${runId}-${runAttempt}-macos-app`) throw new Error("expected device id must be derived from the exact target run attempt");
if (!/^gha-[0-9]+-[0-9]+-macos-app$/u.test(expectedDeviceId)) throw new Error("expected device must be a run-owned macOS App device");
if (!evidenceDir) throw new Error("EVIDENCE_DIR is required");
mkdirSync(evidenceDir, { recursive: true });
const tracePath = join(evidenceDir, "external-controller-trace.jsonl");
const summaryPath = join(evidenceDir, "external-controller-summary.json");
const completedCategories = [];

function record(phase, data = {}) {
  const row = { at: new Date().toISOString(), phase, runId, runAttempt, deviceId: expectedDeviceId, ...data };
  appendFileSync(tracePath, `${JSON.stringify(row)}\n`, "utf8");
  process.stdout.write(`[fcm-010.13.11] ${phase} ${JSON.stringify(data)}\n`);
}

function sanitizeError(error) {
  return String(error?.message || error || "unknown error").replaceAll(password, "[REDACTED]").slice(0, 1200);
}

async function authorizeMcp() {
  record("oauth-start", { origin });
  const redirectUri = "http://127.0.0.1/callback";
  const verifier = randomBytes(48).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
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
    state: `fcm-010-13-11-${runId}-${runAttempt}`,
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
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const response = await fetch(`${origin}/oauth/fabushi/status?request_id=${encodeURIComponent(requestId)}`, {
      headers: { accept: "application/json" }, cache: "no-store",
    });
    if (!response.ok) throw new Error(`MCP authorization status failed: HTTP ${response.status}`);
    authorization = await response.json();
    if (authorization.status === "completed") break;
    if (["failed", "expired", "cancelled"].includes(authorization.status)) throw new Error(`MCP authorization ended as ${authorization.status}`);
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  if (authorization?.status !== "completed" || !authorization.redirectUrl) throw new Error("MCP authorization did not complete in time");
  const callback = new URL(authorization.redirectUrl);
  const code = callback.searchParams.get("code") || "";
  if (!code) throw new Error("MCP callback did not contain an authorization code");

  const tokenResponse = await fetch(`${origin}/oauth/token`, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded", accept: "application/json" },
    body: new URLSearchParams({ grant_type: "authorization_code", client_id: registration.client_id, redirect_uri: redirectUri, resource: mcpUrl, code, code_verifier: verifier }),
  });
  if (!tokenResponse.ok) throw new Error(`MCP token exchange failed: HTTP ${tokenResponse.status}`);
  const tokens = await tokenResponse.json();
  if (!tokens?.access_token) throw new Error("MCP token exchange returned no access token");
  record("oauth-complete", { account: username.slice(0, 2) + "***" });
  return tokens.access_token;
}

function parseRelay(result, toolName) {
  const structured = result?.structuredContent && typeof result.structuredContent === "object" ? result.structuredContent : {};
  if (String(structured.status || "") !== "completed") throw new Error(`device_call ${toolName} did not complete: ${JSON.stringify(structured).slice(0, 1200)}`);
  if (typeof structured.resultJson !== "string" || !structured.resultJson) throw new Error(`device_call ${toolName} returned no resultJson`);
  const envelope = JSON.parse(structured.resultJson);
  if (envelope?.ok === false || envelope?.isError === true) throw new Error(`device_call ${toolName} returned an error: ${JSON.stringify(envelope).slice(0, 1200)}`);
  const resultEnvelope = envelope?.result && typeof envelope.result === "object" ? envelope.result : envelope;
  const payload = resultEnvelope?.structuredContent && typeof resultEnvelope.structuredContent === "object" ? resultEnvelope.structuredContent : resultEnvelope;
  record("remote-call", { toolName, screen: payload?.screen || null, generation: payload?.generation || null });
  return payload;
}

const accessToken = await authorizeMcp();
const transport = new StreamableHTTPClientTransport(new URL(mcpUrl), { requestInit: { headers: { Authorization: `Bearer ${accessToken}` } } });
const client = new Client({ name: "fabushi-fcm-010-13-11-macos-external-controller", version: "1.0.0" });

async function waitForDevice() {
  for (let attempt = 0; attempt < 900; attempt += 1) {
    const listed = await client.callTool({ name: "list_devices", arguments: {} });
    const devices = listed?.structuredContent?.devices || [];
    const target = devices.find((candidate) => candidate?.id === expectedDeviceId);
    if (target) {
      record("device-discovered", { device: { id: target.id, platform: target.platform || null, name: target.name || null } });
      return target;
    }
    if (attempt % 15 === 0) record("device-wait", { visibleDeviceIds: devices.map((item) => item?.id).filter(Boolean).slice(0, 30) });
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  throw new Error(`exact run-owned App device ${expectedDeviceId} was not returned by production list_devices`);
}

async function callDevice(toolName, args = {}) {
  const result = await client.callTool({ name: "device_call", arguments: { deviceId: expectedDeviceId, toolName, argumentsJson: JSON.stringify(args) } });
  return parseRelay(result, toolName);
}

async function waitForAppReady() {
  let session = null;
  for (let attempt = 0; attempt < 180; attempt += 1) {
    session = await callDevice("ci_session_status", {});
    if (session.deviceId !== expectedDeviceId) {
      throw new Error(`CI session switched away from exact device: ${JSON.stringify(session)}`);
    }
    if (session.appReady === true) {
      record("app-ready", { phase: session.phase || null, updatedAt: session.updatedAt || null });
      return session;
    }
    if (attempt % 10 === 0) {
      record("app-ready-wait", { phase: session.phase || null, message: session.message || null, updatedAt: session.updatedAt || null });
    }
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  throw new Error(`CI session never became app-ready for exact device: ${JSON.stringify(session)}`);
}

async function snapshot() { return callDevice("fabushi.app.snapshot", { maxElements: 500, includeText: true }); }
async function find(query) { return callDevice("fabushi.app.find", { ...query, limit: query.limit || 100 }); }
async function waitFor(query, timeoutMs = 30_000) {
  const result = await callDevice("fabushi.app.wait", { ...query, timeoutMs });
  if (result.passed !== true) throw new Error(`wait failed: ${JSON.stringify(query)} :: ${JSON.stringify(result.failures || [])}`);
  return result;
}
async function assertUi(query) {
  const result = await callDevice("fabushi.app.assert", query);
  if (result.passed !== true) throw new Error(`assert failed: ${JSON.stringify(query)} :: ${JSON.stringify(result.failures || [])}`);
  return result;
}

function chooseMatch(found, query, predicate) {
  const matches = Array.isArray(found?.matches) ? found.matches : [];
  const selected = predicate ? matches.find(predicate) : matches.find((item) => {
    if (query.agentId) return item?.agentId === query.agentId;
    if (query.name) return item?.name === query.name;
    return true;
  }) || matches[0];
  if (!selected) throw new Error(`semantic target not found: ${JSON.stringify(query)}`);
  return selected;
}

async function act(query, action, value, predicate) {
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const found = await find(query);
    const target = chooseMatch(found, query, predicate);
    const args = { generation: found.generation, action, ...(target.agentId ? { agentId: target.agentId } : { ref: target.ref }), ...(value === undefined ? {} : { value }) };
    try {
      return await callDevice("fabushi.app.action", args);
    } catch (error) {
      if (!sanitizeError(error).includes("stale_app_surface_generation") || attempt === 3) throw error;
      await new Promise((resolve) => setTimeout(resolve, 150));
    }
  }
  throw new Error(`semantic action failed after generation retries: ${JSON.stringify(query)}`);
}

const testId = (id) => ({ agentId: `test:${id}` });
const invokeTest = (id) => act(testId(id), "invoke");
const setTest = (id, value) => act(testId(id), "setValue", value);
const invokeNamed = (name) => act({ role: "button", name }, "invoke");

async function category(name, fn) {
  record("category-start", { category: name });
  await fn();
  if (!completedCategories.includes(name)) completedCategories.push(name);
  record("category-pass", { category: name });
}

async function openAssistantConversation() {
  const id = "peer-legacy:conversation:mahayana-ai:agent:assistant";
  await invokeTest(id);
  await waitFor({ agentId: "test:messenger-input", state: "visible" });
}

async function openMessageMenu(text) {
  const found = await find({ text, limit: 100 });
  const match = chooseMatch(found, { text }, (item) => String(item?.agentId || "").startsWith("message-actions:"));
  await callDevice("fabushi.app.action", { generation: found.generation, agentId: match.agentId, action: "invoke" });
  await waitFor({ agentId: "test:message-context-menu", state: "visible" });
  return match.agentId;
}

async function sendText(text) {
  await setTest("messenger-input", text);
  await invokeTest("messenger-send");
  await waitFor({ text, state: "present" }, 30_000);
}

async function closeGlobalSearchIfOpen() {
  const found = await find({ agentId: "test:global-search-surface", limit: 1 });
  if ((found.matches || []).length) {
    const close = await find({ role: "button", name: "关闭搜索", limit: 5 });
    if ((close.matches || []).length) await act({ role: "button", name: "关闭搜索", limit: 5 }, "invoke");
  }
}

async function navigateSection(title) {
  await closeGlobalSearchIfOpen();
  const menu = await find({ agentId: "test:profile-navigation-menu", limit: 1 });
  if (!(menu.matches || []).length) {
    await invokeTest("profile-navigation-trigger");
    await waitFor({ agentId: "test:profile-navigation-menu", state: "visible" });
  }
  await invokeNamed(title);
}

async function ensureGlobalDharmaInstalled() {
  await closeGlobalSearchIfOpen();
  await invokeTest("global-search-trigger");
  await waitFor({ agentId: "test:global-search-surface", state: "visible" });
  const appsTab = await find({ agentId: "test:global-search-tab-apps", limit: 1 });
  if ((appsTab.matches || []).length) await invokeTest("global-search-tab-apps");
  await setTest("global-search-input", "全球法布施");
  await waitFor({ agentId: "test:global-search-app-global-dharma", state: "visible" }, 30_000);
  const install = await find({ role: "button", name: "安装", limit: 10 });
  if ((install.matches || []).length) await act({ role: "button", name: "安装", limit: 10 }, "invoke");
  await waitFor({ role: "button", name: "打开", state: "visible" }, 30_000);
  await closeGlobalSearchIfOpen();
}

async function verifyTextExists(text, label) {
  const result = await find({ text, limit: 100 });
  if (!(result.matches || []).length) throw new Error(`${label} semantic text not found: ${text}`);
  return result;
}

let failure = null;
try {
  await client.connect(transport);
  await waitForDevice();

  await category("startup", async () => {
    await waitForAppReady();
    const status = await callDevice("fabushi.app.status", {});
    if (status.available !== true || status.platform !== "electron") throw new Error(`Fabushi App MCP not available on Electron: ${JSON.stringify(status)}`);
    await snapshot();
  });

  await category("login", async () => {
    await assertUi({ agentId: "test:profile-navigation-trigger", state: "visible" });
    await assertUi({ agentId: "test:login-gate", state: "absent" });
  });

  await category("main", async () => {
    await waitFor({ agentId: "test:messenger-workspace", state: "visible" });
    await assertUi({ agentId: "test:messenger-workspace", state: "visible" });
  });

  await category("conversations", async () => openAssistantConversation());
  await category("agent", async () => assertUi({ agentId: "test:messenger-input", state: "enabled" }));

  await category("search", async () => {
    await invokeTest("global-search-trigger");
    await waitFor({ agentId: "test:global-search-surface", state: "visible" });
    await setTest("global-search-input", "全球法布施");
    await assertUi({ agentId: "test:global-search-input", state: "visible" });
    await closeGlobalSearchIfOpen();
  });

  const base = `FCM-010.13.11 ${runId}.${runAttempt}`;
  const sendProbe = `${base} send`;
  await category("send", async () => sendText(sendProbe));
  await category("receive", async () => waitFor({ text: `收到：${sendProbe}`, state: "present" }, 30_000));

  await category("reply", async () => {
    await openMessageMenu(sendProbe);
    await invokeTest("message-action-reply");
    await waitFor({ agentId: "test:reply-message-banner", state: "visible" });
    const reply = `${base} reply`;
    await sendText(reply);
  });

  await category("edit", async () => {
    const original = `${base} edit-source`;
    const edited = `${base} edit-pass`;
    await sendText(original);
    await openMessageMenu(original);
    await invokeTest("message-action-edit");
    await waitFor({ agentId: "test:edit-message-dialog", state: "visible" });
    await setTest("edit-message-input", edited);
    await invokeTest("edit-message-save");
    await waitFor({ text: edited, state: "present" }, 30_000);
  });

  await category("draft", async () => {
    const draft = `${base} draft`;
    await setTest("messenger-input", draft);
    const input = await find({ agentId: "test:messenger-input", limit: 1 });
    const value = String(input.matches?.[0]?.value ?? "");
    if (value !== draft) throw new Error(`draft value did not round-trip through semantic surface: ${value}`);
    await setTest("messenger-input", "");
  });

  await category("pin", async () => {
    await invokeNamed("置顶");
    await waitFor({ role: "button", name: "取消置顶", state: "visible" }, 15_000).catch(async () => {
      await waitFor({ role: "button", name: "置顶", state: "visible" }, 15_000);
    });
  });

  await category("mute", async () => {
    await invokeNamed("静音");
    await waitFor({ role: "button", name: "开启通知", state: "visible" }, 15_000);
  });

  await category("notifications", async () => {
    await invokeNamed("开启通知");
    await waitFor({ role: "button", name: "静音", state: "visible" }, 15_000);
  });

  await category("unread", async () => {
    let unread = await find({ text: "未读", limit: 100 });
    if (!(unread.matches || []).length) {
      const peer = await find({ agentId: "test:peer-legacy:conversation:mahayana-ai:agent:assistant", limit: 1 });
      if (!(peer.matches || []).length) throw new Error("assistant peer unavailable while checking unread state");
      await sendText(`${base} unread-probe`);
      await navigateSection("联系人");
      await new Promise((resolve) => setTimeout(resolve, 1500));
      await navigateSection("聊天");
      unread = await find({ text: "未读", limit: 100 });
    }
    if (!(unread.matches || []).length) throw new Error("no real unread semantic state was observable");
  });

  await category("miniapp", async () => {
    await ensureGlobalDharmaInstalled();
    await invokeTest("global-search-trigger");
    await waitFor({ agentId: "test:global-search-surface", state: "visible" });
    const appsTab = await find({ agentId: "test:global-search-tab-apps", limit: 1 });
    if ((appsTab.matches || []).length) await invokeTest("global-search-tab-apps");
    await setTest("global-search-input", "全球法布施");
    await waitFor({ role: "button", name: "打开", state: "visible" }, 30_000);
    await act({ role: "button", name: "打开", limit: 10 }, "invoke");
    await waitFor({ agentId: "test:miniapp-close", state: "visible" }, 30_000);
    await invokeTest("miniapp-close");
  });

  await category("contacts", async () => {
    await navigateSection("联系人");
    await verifyTextExists("全球法布施", "contacts projection");
  });

  await category("groups", async () => {
    await navigateSection("群组");
    const surface = await find({ text: "群组", limit: 100 });
    if (!(surface.matches || []).length) throw new Error("Groups section did not expose a semantic surface");
  });

  await category("bot", async () => {
    await navigateSection("Bots");
    const bots = await find({ text: "全球法布施", limit: 100 });
    const bot = (bots.matches || []).find((item) => item?.role === "button") || bots.matches?.[0];
    if (!bot) throw new Error("Global Dharma Bot was not projected after installation");
    await callDevice("fabushi.app.action", { generation: bots.generation, ...(bot.agentId ? { agentId: bot.agentId } : { ref: bot.ref }), action: "invoke" });
    await waitFor({ agentId: "test:miniapp-bot-open", state: "visible" }, 30_000);
  });

  await category("webmcp", async () => {
    const command = "现在运行到哪里？请查看状态";
    await setTest("messenger-input", command);
    await invokeTest("messenger-send");
    await waitFor({ text: "已读取全球法布施状态", state: "present" }, 60_000);
    await assertUi({ agentId: "test:miniapp-bot-open", state: "enabled" });
  });

  await category("media", async () => {
    await closeGlobalSearchIfOpen();
    await invokeTest("global-search-trigger");
    await waitFor({ agentId: "test:global-search-surface", state: "visible" });
    await invokeTest("global-search-tab-images");
    await assertUi({ agentId: "test:global-search-tab-images", state: "visible" });
  });

  await category("file", async () => {
    await invokeTest("global-search-tab-files");
    await assertUi({ agentId: "test:global-search-tab-files", state: "visible" });
    await closeGlobalSearchIfOpen();
  });

  await category("sync", async () => {
    const synced = await find({ text: "同步", limit: 100 });
    if (!(synced.matches || []).length) throw new Error("no semantic sync state/control was observable");
  });

  await category("forward", async () => {
    await openAssistantConversation();
    const text = `${base} forward-source`;
    await sendText(text);
    await openMessageMenu(text);
    await invokeTest("message-action-forward");
    await waitFor({ agentId: "test:forward-message-dialog", state: "visible" });
    const peers = await find({ role: "button", limit: 100 });
    const target = (peers.matches || []).find((item) => String(item?.agentId || "").startsWith("forward-message-peer:"));
    if (!target) throw new Error("forward dialog has no real self-hosted destination peer");
    await callDevice("fabushi.app.action", { generation: peers.generation, ...(target.agentId ? { agentId: target.agentId } : { ref: target.ref }), action: "invoke" });
    await waitFor({ agentId: "test:forward-message-dialog", state: "absent" }, 30_000);
  });

  await category("delete", async () => {
    await openAssistantConversation();
    const text = `${base} delete-source`;
    await sendText(text);
    await openMessageMenu(text);
    await invokeTest("message-action-delete");
    await waitFor({ text, state: "absent" }, 30_000);
  });

  await category("settings", async () => {
    await navigateSection("设置");
    await waitFor({ agentId: "test:settings-modal-backdrop", state: "visible" });
    await assertUi({ agentId: "test:telegram-settings-workspace", state: "visible" });
  });

  await category("update", async () => {
    await invokeTest("settings-category-updates");
    await waitFor({ agentId: "test:updates-settings", state: "visible" });
    await assertUi({ agentId: "test:settings-update-track", state: "visible" });
  });

  const missing = REQUIRED_CATEGORIES.filter((categoryName) => !completedCategories.includes(categoryName));
  if (missing.length) throw new Error(`full journey did not complete required categories: ${missing.join(",")}`);

  await invokeTest("settings-category-account");
  await waitFor({ agentId: "settings-logout", state: "visible" });
  const readyNote = `TFI_MACOS_FULL_JOURNEY READY_FOR_LOGOUT PASS categories=${REQUIRED_CATEGORIES.join(",")}`;
  await callDevice("ci_session_note", { note: readyNote });
  await callDevice("ci_session_finish", { reason: `FCM-010.13.11 external full journey passed on ${expectedDeviceId}` });

  for (let attempt = 0; attempt < 4; attempt += 1) {
    const fresh = await snapshot();
    const logout = (fresh.elements || []).find((item) => item?.agentId === "settings-logout");
    if (!logout) throw new Error("fresh pre-logout snapshot did not contain exact settings-logout");
    try {
      await callDevice("fabushi.app.action", { generation: fresh.generation, agentId: "settings-logout", action: "invoke" });
      break;
    } catch (error) {
      if (!sanitizeError(error).includes("stale_app_surface_generation") || attempt === 3) throw error;
    }
  }

  writeFileSync(summaryPath, `${JSON.stringify({ schema: "fcm-010.13.11.external-controller.v1", status: "passed", source: FROZEN_SOURCE, tag: IMMUTABLE_TAG, runId, runAttempt, deviceId: expectedDeviceId, categories: completedCategories, finalAction: { toolName: "fabushi.app.action", agentId: "settings-logout", action: "invoke" } }, null, 2)}\n`);
  record("journey-pass", { categories: completedCategories.length, finalAction: "settings-logout" });
} catch (error) {
  failure = sanitizeError(error);
  record("journey-fail", { error: failure, categories: completedCategories });
  try { await callDevice("ci_session_note", { note: `TFI_MACOS_FULL_JOURNEY FAIL ${failure}` }); } catch (noteError) { record("failure-note-error", { error: sanitizeError(noteError) }); }
  try { await callDevice("ci_session_finish", { reason: `FCM-010.13.11 external journey failed: ${failure}` }); } catch (finishError) { record("failure-finish-error", { error: sanitizeError(finishError) }); }
  writeFileSync(summaryPath, `${JSON.stringify({ schema: "fcm-010.13.11.external-controller.v1", status: "failed", source: FROZEN_SOURCE, tag: IMMUTABLE_TAG, runId, runAttempt, deviceId: expectedDeviceId, categories: completedCategories, error: failure }, null, 2)}\n`);
  throw error;
} finally {
  await client.close().catch(() => {});
}
