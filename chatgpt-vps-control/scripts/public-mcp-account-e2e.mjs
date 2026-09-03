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
if (!/^gha-[0-9]+-[0-9]+-interactive$/u.test(expectedDeviceId)) {
  throw new Error("EXPECTED_DEVICE_ID must be a protected interactive Runner id");
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
  state: "ci-public-mcp-e2e",
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

const passwordUrl = new URL("/api/auth/browser/password", loginUrl.origin);
const passwordResponse = await fetch(passwordUrl, {
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
const combinedReturn = `${passwordRedirect}\n${passwordBody}`;
const completionMatch = combinedReturn.match(/https:\/\/fabushi-mcp\.ombhrum\.com\/oauth\/fabushi\/complete\?request_id=([A-Za-z0-9_-]{32,128})/u);
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

function safeRelaySummary(result) {
  const structured = result?.structuredContent && typeof result.structuredContent === "object"
    ? result.structuredContent
    : {};
  let detail = "";
  if (typeof structured.resultJson === "string" && structured.resultJson.length <= 2_000_000) {
    try {
      const parsed = JSON.parse(structured.resultJson);
      if (typeof parsed?.error === "string") detail = parsed.error;
      else if (Array.isArray(parsed?.content)) {
        detail = parsed.content
          .filter((item) => item?.type === "text" && typeof item.text === "string")
          .map((item) => item.text)
          .join(" | ");
      }
    } catch {
      detail = "resultJson was not valid JSON";
    }
  }
  return {
    status: String(structured.status || ""),
    detail: String(detail || structured.error || structured.message || "").slice(0, 500),
    hasResult: Boolean(structured.resultJson),
    isError: result?.isError === true,
  };
}

const transport = new StreamableHTTPClientTransport(new URL(mcpUrl), {
  requestInit: { headers: { Authorization: `Bearer ${tokens.access_token}` } },
});
const client = new Client({ name: "fabushi-public-mcp-production-e2e", version: "1.0.0" });
try {
  await client.connect(transport);
  const devicesResult = await client.callTool({ name: "list_devices", arguments: {} });
  const devices = devicesResult?.structuredContent?.devices || [];
  const device = devices.find((candidate) => candidate?.id === expectedDeviceId);
  if (!device) {
    throw new Error(`expected same-account device ${expectedDeviceId} was not returned by list_devices`);
  }

  for (const requiredTool of ["ci_session_status", "computer_state"]) {
    const described = await client.callTool({
      name: "describe_device_tool",
      arguments: { deviceId: expectedDeviceId, toolName: requiredTool },
    });
    if (described?.structuredContent?.available !== true) {
      throw new Error(`live Runner does not advertise required tool ${requiredTool}`);
    }
  }

  const relayResult = await client.callTool({
    name: "device_call",
    arguments: { deviceId: expectedDeviceId, toolName: "ci_session_status", argumentsJson: "{}" },
  });
  const relaySummary = safeRelaySummary(relayResult);
  if (relaySummary.status !== "completed") {
    throw new Error(`device_call relay failed for ci_session_status: ${JSON.stringify(relaySummary)}`);
  }
  process.stdout.write(`Public Fabushi MCP relay completed ci_session_status on ${expectedDeviceId}.\n`);

  const controlResult = await client.callTool({
    name: "device_call",
    arguments: { deviceId: expectedDeviceId, toolName: "computer_state", argumentsJson: "{}" },
  });
  const controlSummary = safeRelaySummary(controlResult);
  if (controlSummary.status !== "completed") {
    throw new Error(`device_call computer_state failed: ${JSON.stringify(controlSummary)}`);
  }

  process.stdout.write(`Public Fabushi MCP discovered and controlled ${expectedDeviceId}.\n`);
} finally {
  await client.close().catch(() => {});
}
