#!/usr/bin/env node
import { createHash } from "node:crypto";
import { writeFile } from "node:fs/promises";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

const origin = String(process.env.FABUSHI_MCP_ORIGIN || "https://fabushi-mcp.ombhrum.com").replace(/\/$/u, "");
const mcpUrl = `${origin}/mcp`;
const username = String(process.env.FABUSHI_CI_TEST_USERNAME || "").trim();
const password = String(process.env.FABUSHI_CI_TEST_PASSWORD || "");
const expectedDeviceId = String(process.env.EXPECTED_DEVICE_ID || "").trim();
const outputPath = String(process.env.OUTPUT_JSON || "public-mcp-app-inspect.json");

if (!username || !password) throw new Error("managed Fabushi test account credentials are required");
if (!/^gha-[0-9]+-[0-9]+-(?:macos-app|windows-app)$/u.test(expectedDeviceId)) {
  throw new Error("EXPECTED_DEVICE_ID must be a protected App-owned desktop Actions id");
}

const redirectUri = "http://127.0.0.1/callback";
const verifier = "v".repeat(64);
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
  state: "ci-public-mcp-app-inspect",
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
  throw new Error("authorization did not redirect to canonical Fabushi login portal");
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
if (!completionMatch) throw new Error("Fabushi browser login did not return to MCP completion endpoint");
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

function parseRelay(result) {
  const structured = result?.structuredContent && typeof result.structuredContent === "object" ? result.structuredContent : {};
  if (String(structured.status || "") !== "completed") {
    throw new Error(`device_call did not complete: ${String(structured.error || structured.message || structured.status || "unknown")}`);
  }
  if (typeof structured.resultJson !== "string") throw new Error("device_call returned no resultJson");
  return JSON.parse(structured.resultJson);
}

const transport = new StreamableHTTPClientTransport(new URL(mcpUrl), {
  requestInit: { headers: { Authorization: `Bearer ${tokens.access_token}` } },
});
const client = new Client({ name: "fabushi-public-mcp-app-inspect", version: "1.0.0" });
const evidence = { schema: "fabushi.public-mcp.app-inspect.v1", expectedDeviceId, inspectedAt: new Date().toISOString() };
try {
  await client.connect(transport);
  const devicesResult = await client.callTool({ name: "list_devices", arguments: {} });
  const devices = devicesResult?.structuredContent?.devices || [];
  const device = devices.find((candidate) => candidate?.id === expectedDeviceId);
  if (!device) throw new Error(`expected same-account device ${expectedDeviceId} was not returned by list_devices`);
  evidence.device = device;

  const requiredTools = [
    "ci_session_status", "ci_session_note", "ci_session_finish",
    "fabushi.app.status", "fabushi.app.snapshot", "fabushi.app.find",
    "fabushi.app.action", "fabushi.app.wait", "fabushi.app.assert",
  ];
  evidence.tools = {};
  for (const toolName of requiredTools) {
    const described = await client.callTool({
      name: "describe_device_tool",
      arguments: { deviceId: expectedDeviceId, toolName },
    });
    evidence.tools[toolName] = described?.structuredContent || null;
    if (described?.structuredContent?.available !== true) throw new Error(`target App does not advertise required tool ${toolName}`);
  }

  const remote = async (toolName, args = {}) => parseRelay(await client.callTool({
    name: "device_call",
    arguments: { deviceId: expectedDeviceId, toolName, argumentsJson: JSON.stringify(args) },
  }));

  evidence.ciSessionStatus = await remote("ci_session_status");
  evidence.appStatus = await remote("fabushi.app.status");
  evidence.snapshot = await remote("fabushi.app.snapshot", { maxElements: 500, includeText: true });
  evidence.settingsLogoutFind = await remote("fabushi.app.find", { agentId: "settings-logout", limit: 2 });
  evidence.semanticAssert = await remote("fabushi.app.assert", { state: "present" });
  await writeFile(outputPath, `${JSON.stringify(evidence, null, 2)}\n`, { mode: 0o600 });
  process.stdout.write(`Inspected App-owned device ${expectedDeviceId}; generation=${evidence.appStatus?.generation ?? evidence.snapshot?.generation ?? "unknown"}.\n`);
} finally {
  await client.close().catch(() => {});
}
