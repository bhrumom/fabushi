#!/usr/bin/env node
import { createHash, randomBytes } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

const origin = String(process.env.FABUSHI_MCP_ORIGIN || "https://fabushi-mcp.ombhrum.com").replace(/\/$/u, "");
const mcpUrl = `${origin}/mcp`;
const username = String(process.env.FABUSHI_CI_TEST_USERNAME || "").trim();
const password = String(process.env.FABUSHI_CI_TEST_PASSWORD || "");
const evidenceDir = String(process.env.EVIDENCE_DIR || "").trim();
if (!username || !password) throw new Error("managed Fabushi test account credentials are required");
if (!evidenceDir) throw new Error("EVIDENCE_DIR is required");
mkdirSync(evidenceDir, { recursive: true });

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
  state: "fcm-010-13-11-protected-account-preflight",
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
if (![200, 302, 303].includes(passwordResponse.status)) throw new Error(`Fabushi browser password login failed: HTTP ${passwordResponse.status}`);
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

const transport = new StreamableHTTPClientTransport(new URL(mcpUrl), { requestInit: { headers: { Authorization: `Bearer ${tokens.access_token}` } } });
const client = new Client({ name: "fabushi-fcm-010-13-11-account-preflight", version: "1.0.0" });
try {
  await client.connect(transport);
  const listed = await client.callTool({ name: "list_devices", arguments: {} });
  if (listed?.isError === true) throw new Error("production list_devices returned an MCP error");
  const devices = listed?.structuredContent?.devices || [];
  const evidence = {
    schema: "fcm-010.13.11.protected-account-preflight.v1",
    ok: true,
    origin,
    accountHint: `${username.slice(0, 2)}***`,
    scopes: ["devices.read", "devices.control"],
    visibleDeviceCount: devices.length,
    visibleDeviceIds: devices.map((device) => String(device?.id || "")).filter(Boolean),
    verifiedAt: new Date().toISOString(),
  };
  writeFileSync(join(evidenceDir, "protected-account-preflight.json"), `${JSON.stringify(evidence, null, 2)}\n`, "utf8");
  process.stdout.write(`Protected Fabushi account connected to production MCP; list_devices returned ${devices.length} same-account device(s).\n`);
} finally {
  await client.close().catch(() => {});
}
