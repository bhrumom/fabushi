#!/usr/bin/env node
import { createHash } from "node:crypto";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

const origin = String(process.env.FABUSHI_MCP_ORIGIN || "https://fabushi-mcp.ombhrum.com").replace(/\/$/u, "");
const mcpUrl = `${origin}/mcp`;
const username = String(process.env.FABUSHI_CI_TEST_USERNAME || "").trim();
const password = String(process.env.FABUSHI_CI_TEST_PASSWORD || "");
const expectedDeviceId = String(process.env.EXPECTED_DEVICE_ID || "").trim();
if (!username || !password) throw new Error("managed Fabushi test account credentials are required");
if (!/^gha-[0-9]+-[0-9]+-macos-app$/u.test(expectedDeviceId)) throw new Error("EXPECTED_DEVICE_ID must be a protected macOS App-owned id");

const redirectUri = "http://127.0.0.1/callback";
const verifier = "v".repeat(64);
const challenge = createHash("sha256").update(verifier).digest("base64url");

async function registerClient() {
  let lastStatus = 0;
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    const response = await fetch(`${origin}/oauth/register`, {
      method: "POST", headers: { "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({ redirect_uris: [redirectUri] }),
    });
    if (response.ok) return response.json();
    lastStatus = response.status;
    if (response.status < 500 || response.status > 599 || attempt === 4) break;
    await new Promise((resolve) => setTimeout(resolve, attempt * 1000));
  }
  throw new Error(`dynamic client registration failed: HTTP ${lastStatus}`);
}

async function authorize() {
  const registration = await registerClient();
  if (!registration?.client_id) throw new Error("dynamic client registration returned no client_id");
  const authorizeUrl = new URL(`${origin}/oauth/authorize`);
  authorizeUrl.search = new URLSearchParams({
    client_id: registration.client_id, redirect_uri: redirectUri, response_type: "code",
    state: "ci-macos-live-probe", scope: "devices.read devices.control", resource: mcpUrl,
    code_challenge: challenge, code_challenge_method: "S256",
  }).toString();
  const authorizeResponse = await fetch(authorizeUrl, { redirect: "manual" });
  if (authorizeResponse.status !== 302) throw new Error(`authorization start failed: HTTP ${authorizeResponse.status}`);
  const loginUrl = new URL(authorizeResponse.headers.get("location"));
  const attemptId = loginUrl.searchParams.get("attemptId") || "";
  const ticket = loginUrl.searchParams.get("ticket") || "";
  const passwordResponse = await fetch(new URL("/api/auth/browser/password", loginUrl.origin), {
    method: "POST", redirect: "manual", headers: { "content-type": "application/x-www-form-urlencoded;charset=UTF-8" },
    body: new URLSearchParams({ attemptId, ticket, username, password }),
  });
  const combined = `${passwordResponse.headers.get("location") || ""}\n${await passwordResponse.text()}`;
  const match = combined.match(/https:\/\/fabushi-mcp\.ombhrum\.com\/oauth\/fabushi\/complete\?request_id=([A-Za-z0-9_-]{32,128})/u);
  if (!match) throw new Error("Fabushi browser login did not return to MCP completion");
  let authorization = null;
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const response = await fetch(`${origin}/oauth/fabushi/status?request_id=${encodeURIComponent(match[1])}`, { headers: { accept: "application/json" }, cache: "no-store" });
    authorization = await response.json();
    if (authorization.status === "completed") break;
    if (["failed", "expired", "cancelled"].includes(authorization.status)) throw new Error(`MCP authorization ${authorization.status}`);
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  if (authorization?.status !== "completed" || !authorization.redirectUrl) throw new Error("MCP authorization timed out");
  const code = new URL(authorization.redirectUrl).searchParams.get("code") || "";
  const tokenResponse = await fetch(`${origin}/oauth/token`, {
    method: "POST", headers: { "content-type": "application/x-www-form-urlencoded", accept: "application/json" },
    body: new URLSearchParams({ grant_type: "authorization_code", client_id: registration.client_id, redirect_uri: redirectUri, resource: mcpUrl, code, code_verifier: verifier }),
  });
  const tokens = await tokenResponse.json();
  if (!tokens?.access_token) throw new Error("MCP token exchange returned no access token");
  return tokens.access_token;
}

function relayPayload(result, toolName) {
  const structured = result?.structuredContent || {};
  if (structured.status !== "completed" || typeof structured.resultJson !== "string") throw new Error(`relay ${toolName} failed: ${JSON.stringify(structured).slice(0, 1200)}`);
  const envelope = JSON.parse(structured.resultJson);
  if (envelope?.ok === false || envelope?.isError === true) throw new Error(`device ${toolName} failed: ${JSON.stringify(envelope).slice(0, 1200)}`);
  const inner = envelope?.result && typeof envelope.result === "object" ? envelope.result : envelope;
  return inner?.structuredContent && typeof inner.structuredContent === "object" ? inner.structuredContent : inner;
}

const accessToken = await authorize();
const transport = new StreamableHTTPClientTransport(new URL(mcpUrl), { requestInit: { headers: { Authorization: `Bearer ${accessToken}` } } });
const client = new Client({ name: "fabushi-macos-live-public-mcp-probe", version: "1.0.0" });
async function callDevice(toolName, args = {}) {
  const result = await client.callTool({ name: "device_call", arguments: { deviceId: expectedDeviceId, toolName, argumentsJson: JSON.stringify(args) } });
  return relayPayload(result, toolName);
}
try {
  await client.connect(transport);
  const listed = await client.callTool({ name: "list_devices", arguments: {} });
  if (!(listed?.structuredContent?.devices || []).some((device) => device?.id === expectedDeviceId)) throw new Error(`device not found: ${expectedDeviceId}`);
  for (const toolName of ["fabushi.app.status","fabushi.app.snapshot","fabushi.app.find","fabushi.app.action","fabushi.app.wait","fabushi.app.assert","ci_session_status","ci_session_note","ci_session_finish"]) {
    const described = await client.callTool({ name: "describe_device_tool", arguments: { deviceId: expectedDeviceId, toolName } });
    if (described?.structuredContent?.available !== true) throw new Error(`missing advertised tool ${toolName}`);
  }
  const status = await callDevice("fabushi.app.status", {});
  const snapshot = await callDevice("fabushi.app.snapshot", { maxElements: 500, includeText: true });
  const found = await callDevice("fabushi.app.find", { agentId: "test:profile-navigation-trigger", limit: 1 });
  const waited = await callDevice("fabushi.app.wait", { agentId: "test:profile-navigation-trigger", state: "visible", timeoutMs: 10_000 });
  const asserted = await callDevice("fabushi.app.assert", { agentId: "test:profile-navigation-trigger", state: "visible" });
  const session = await callDevice("ci_session_status", {});
  if (waited?.passed !== true || asserted?.passed !== true) throw new Error("semantic probe did not satisfy trigger visibility");
  const elements = (snapshot?.elements || []).filter((item) => item?.agentId).map((item) => ({ agentId: item.agentId, role: item.role, name: item.name, enabled: item.enabled, visible: item.visible }));
  process.stdout.write(`${JSON.stringify({ expectedDeviceId, status, session, found, generation: snapshot?.generation, screen: snapshot?.screen, route: snapshot?.route, elements }, null, 2)}\n`);
} finally {
  await client.close().catch(() => {});
}
