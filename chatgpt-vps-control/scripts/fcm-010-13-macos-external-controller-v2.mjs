#!/usr/bin/env node
import { createHash, randomBytes } from "node:crypto";
import { appendFileSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { serializeDeviceCallArguments } from "./fcm-010-13-find-contract.mjs";
import { runLiveJourney } from "./fcm-010-13-macos-live-journey.mjs";
import { retryTransientNetwork } from "./fcm-010-13-transient-retry.mjs";

const FROZEN_SOURCE = String(process.env.FROZEN_SOURCE_SHA || "").trim();
const IMMUTABLE_TAG = String(process.env.IMMUTABLE_RELEASE_TAG || "").trim();
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
if (!/^[0-9a-f]{40}$/u.test(FROZEN_SOURCE)) throw new Error("FROZEN_SOURCE_SHA must be an exact commit SHA");
if (!/^desktop-[0-9]+\.[0-9]+\.[0-9]+-[0-9a-f]{12}$/u.test(IMMUTABLE_TAG)) throw new Error("IMMUTABLE_RELEASE_TAG must be an immutable desktop source tag");
if (!runId || !runAttempt || !/^\d+$/u.test(runId) || !/^\d+$/u.test(runAttempt)) throw new Error("target run id/attempt are required");
if (headSha !== FROZEN_SOURCE) throw new Error(`controller refuses non-frozen source ${headSha}`);
if (headBranch !== IMMUTABLE_TAG) throw new Error(`controller refuses non-immutable tag ${headBranch}`);
if (expectedDeviceId !== `gha-${runId}-${runAttempt}-macos-app`) throw new Error("expected device id must be derived from the exact target run attempt");
if (!/^gha-[0-9]+-[0-9]+-macos-app$/u.test(expectedDeviceId)) throw new Error("expected device must be a run-owned macOS App device");
if (!evidenceDir) throw new Error("EVIDENCE_DIR is required");
mkdirSync(evidenceDir, { recursive: true });
const tracePath = join(evidenceDir, "external-controller-trace.jsonl");
const summaryPath = join(evidenceDir, "external-controller-summary.json");
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function record(phase, data = {}) {
  const row = { at: new Date().toISOString(), phase, runId, runAttempt, deviceId: expectedDeviceId, ...data };
  appendFileSync(tracePath, `${JSON.stringify(row)}\n`, "utf8");
  process.stdout.write(`[fcm-010.13.11] ${phase} ${JSON.stringify(data)}\n`);
}
function sanitizeError(error) {
  return String(error?.message || error || "unknown error").replaceAll(password, "[REDACTED]").slice(0, 1600);
}

async function authorizeMcpOnce() {
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
  authorizeUrl.search = new URLSearchParams({ client_id: registration.client_id, redirect_uri: redirectUri, response_type: "code", state: `fcm-010-13-11-${runId}-${runAttempt}`, scope: "devices.read devices.control", resource: mcpUrl, code_challenge: challenge, code_challenge_method: "S256" }).toString();
  const authorizeResponse = await fetch(authorizeUrl, { redirect: "manual" });
  if (authorizeResponse.status !== 302) throw new Error(`authorization start failed: HTTP ${authorizeResponse.status}`);
  const loginLocation = authorizeResponse.headers.get("location");
  if (!loginLocation) throw new Error("authorization start returned no Fabushi login URL");
  const loginUrl = new URL(loginLocation);
  if (loginUrl.hostname !== "api.ombhrum.com" || loginUrl.pathname !== "/api/auth/browser/portal") throw new Error("authorization did not redirect to the canonical Fabushi login portal");
  const attemptId = loginUrl.searchParams.get("attemptId") || "";
  const ticket = loginUrl.searchParams.get("ticket") || "";
  if (!attemptId || !ticket) throw new Error("Fabushi login portal URL is missing attempt binding");

  const passwordResponse = await fetch(new URL("/api/auth/browser/password", loginUrl.origin), {
    method: "POST",
    redirect: "manual",
    headers: { "content-type": "application/x-www-form-urlencoded;charset=UTF-8" },
    body: new URLSearchParams({ attemptId, ticket, username, password }),
  });
  if (![200, 302, 303].includes(passwordResponse.status)) throw new Error(`Fabushi browser password login failed: HTTP ${passwordResponse.status}`);
  const passwordBody = await passwordResponse.text();
  const passwordRedirect = passwordResponse.headers.get("location") || "";
  const completionMatch = `${passwordRedirect}\n${passwordBody}`.match(/https:\/\/fabushi-mcp\.ombhrum\.com\/oauth\/fabushi\/complete\?request_id=([A-Za-z0-9_-]{32,128})/u);
  if (!completionMatch) throw new Error("Fabushi browser login did not return to the MCP completion endpoint");
  const requestId = completionMatch[1];

  let authorization = null;
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const response = await fetch(`${origin}/oauth/fabushi/status?request_id=${encodeURIComponent(requestId)}`, { headers: { accept: "application/json" }, cache: "no-store" });
    if (!response.ok) throw new Error(`MCP authorization status failed: HTTP ${response.status}`);
    authorization = await response.json();
    if (authorization.status === "completed") break;
    if (["failed", "expired", "cancelled"].includes(authorization.status)) throw new Error(`MCP authorization ended as ${authorization.status}`);
    await sleep(500);
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
  record("oauth-complete", { account: `${username.slice(0, 2)}***` });
  return tokens.access_token;
}

async function authorizeMcp() {
  return retryTransientNetwork(
    ({ attempt, maxAttempts }) => {
      record("oauth-attempt", { attempt, maxAttempts });
      return authorizeMcpOnce();
    },
    {
      maxAttempts: 3,
      baseDelayMs: 250,
      sleepFn: sleep,
      onRetry: ({ attempt, nextAttempt, maxAttempts, code, delayMs }) => {
        record("oauth-transient-retry", { attempt, nextAttempt, maxAttempts, code, delayMs });
      },
    },
  );
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
const client = new Client({ name: "fabushi-fcm-010-13-11-macos-external-controller", version: "2.0.0" });
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
    await sleep(1000);
  }
  throw new Error(`exact run-owned App device ${expectedDeviceId} was not returned by production list_devices`);
}
async function callDevice(toolName, args = {}) {
  const result = await client.callTool({ name: "device_call", arguments: { deviceId: expectedDeviceId, toolName, argumentsJson: serializeDeviceCallArguments(toolName, args) } });
  return parseRelay(result, toolName);
}

try {
  await client.connect(transport);
  await waitForDevice();
  const result = await runLiveJourney({ callDevice, expectedDeviceId, runId, runAttempt, record });
  writeFileSync(summaryPath, `${JSON.stringify({ schema: "fcm-010.13.11.external-controller.v2", status: "passed", source: FROZEN_SOURCE, tag: IMMUTABLE_TAG, runId, runAttempt, deviceId: expectedDeviceId, ...result }, null, 2)}\n`);
  record("journey-pass", { categories: result.categories.length, finalAction: "settings-logout" });
} catch (error) {
  const failure = sanitizeError(error);
  record("journey-fail", { error: failure });
  try { await callDevice("ci_session_note", { note: `TFI_MACOS_FULL_JOURNEY FAIL ${failure}` }); } catch (noteError) { record("failure-note-error", { error: sanitizeError(noteError) }); }
  try { await callDevice("ci_session_finish", { reason: `FCM-010.13.11 external journey failed: ${failure}` }); } catch (finishError) { record("failure-finish-error", { error: sanitizeError(finishError) }); }
  writeFileSync(summaryPath, `${JSON.stringify({ schema: "fcm-010.13.11.external-controller.v2", status: "failed", source: FROZEN_SOURCE, tag: IMMUTABLE_TAG, runId, runAttempt, deviceId: expectedDeviceId, error: failure }, null, 2)}\n`);
  throw error;
} finally {
  await client.close().catch(() => {});
}
