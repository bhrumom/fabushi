#!/usr/bin/env node
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { resolve, sep } from "node:path";

function required(name) {
  const value = String(process.env[name] || "").trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

function privateSessionPath(name) {
  const runnerTemp = resolve(required("RUNNER_TEMP"));
  const value = resolve(required(name));
  if (!value.startsWith(`${runnerTemp}${sep}`)) throw new Error(`${name} must live under RUNNER_TEMP.`);
  return value;
}

function accountRef(value) {
  return createHash("sha256").update(String(value)).digest("hex").slice(0, 16);
}

async function readBoundedSession(name) {
  const session = JSON.parse(await readFile(privateSessionPath(name), "utf8"));
  const accessToken = String(session?.accessToken || "").trim();
  const deviceId = String(session?.deviceId || "").trim();
  const userId = String(session?.userId || session?.user?.id || "").trim();
  const username = String(session?.username || session?.user?.username || "").trim();
  if (session?.provider !== "github-actions" || session?.ciRunner !== true || "refreshToken" in session) {
    throw new Error(`${name} is not a bounded refresh-token-free GitHub Actions session.`);
  }
  if (!accessToken || !deviceId || !userId || !username) throw new Error(`${name} is incomplete.`);
  return { accessToken, deviceId, userId, username };
}

const baseUrl = new URL(required("FABUSHI_API_BASE_URL"));
if (baseUrl.protocol !== "https:" || baseUrl.username || baseUrl.password || baseUrl.search || baseUrl.hash) {
  throw new Error("FABUSHI_API_BASE_URL must be a clean HTTPS origin/base URL.");
}
if (process.env.GITHUB_ACTIONS !== "true") throw new Error("Human peer preparation is GitHub Actions only.");

const first = await readBoundedSession("FABUSHI_CI_ACCOUNT_SESSION_FILE");
const second = await readBoundedSession("FABUSHI_CI_PEER_ACCOUNT_SESSION_FILE");
if (first.userId === second.userId || first.username.toLowerCase() === second.username.toLowerCase()) {
  throw new Error("Phase 1 production acceptance requires two distinct Fabushi accounts.");
}
if (first.deviceId === second.deviceId) throw new Error("Phase 1 production acceptance requires two distinct app device ids.");

async function api(session, pathname, init = {}) {
  const url = new URL(pathname.replace(/^\//u, ""), baseUrl.toString().replace(/\/?$/u, "/"));
  const headers = new Headers(init.headers || {});
  headers.set("authorization", `Bearer ${session.accessToken}`);
  headers.set("x-fabushi-device-id", session.deviceId);
  headers.set("accept", "application/json");
  if (init.body != null) headers.set("content-type", "application/json");
  const response = await fetch(url, { ...init, headers });
  let payload = null;
  try { payload = await response.json(); } catch {}
  return { response, payload };
}

function friendIds(payload) {
  const friends = Array.isArray(payload?.data?.friends) ? payload.data.friends : [];
  return new Set(friends.map((friend) => String(friend?.userId ?? friend?.id ?? "")).filter(Boolean));
}

async function alreadyFriends(session, peer) {
  const { response, payload } = await api(session, "/api/social/friends");
  if (!response.ok || payload?.success !== true) throw new Error(`Friend list failed with HTTP ${response.status}.`);
  return friendIds(payload).has(peer.userId);
}

async function acceptIncoming(session, peer) {
  const { response, payload } = await api(session, "/api/social/friend-requests/incoming");
  if (!response.ok || payload?.success !== true) throw new Error(`Incoming friend requests failed with HTTP ${response.status}.`);
  const requests = Array.isArray(payload?.data?.requests) ? payload.data.requests : [];
  const request = requests.find((candidate) =>
    String(candidate?.fromUser?.userId ?? candidate?.fromUser?.id ?? "") === peer.userId);
  if (!request) return false;
  const requestId = String(request?.requestId ?? request?.id ?? "").trim();
  if (!/^\d+$/u.test(requestId)) throw new Error("Incoming friend request id is invalid.");
  const accepted = await api(session, `/api/social/friend-requests/${requestId}/accept`, { method: "POST" });
  if (!accepted.response.ok || accepted.payload?.success !== true) {
    throw new Error(`Friend request acceptance failed with HTTP ${accepted.response.status}.`);
  }
  return true;
}

if (!(await alreadyFriends(first, second))) {
  const created = await api(first, "/api/social/friend-requests", {
    method: "POST",
    body: JSON.stringify({ targetUserId: second.userId, message: "GitHub Actions Phase 1 packaged acceptance" }),
  });
  if (!(created.response.ok || created.response.status === 409)) {
    throw new Error(`Friend request creation failed with HTTP ${created.response.status}.`);
  }
  await acceptIncoming(second, first);
  await acceptIncoming(first, second);
}

if (!(await alreadyFriends(first, second)) || !(await alreadyFriends(second, first))) {
  throw new Error("Two bounded production accounts did not converge to an accepted friendship.");
}

async function assertTurn(session) {
  const { response, payload } = await api(session, "/api/social/calls/ice");
  if (!response.ok || payload?.success !== true) throw new Error(`Production call ICE preflight failed with HTTP ${response.status}.`);
  const servers = Array.isArray(payload?.iceServers) ? payload.iceServers : [];
  const hasAuthenticatedTurn = servers.some((server) => {
    const urls = Array.isArray(server?.urls) ? server.urls : [server?.urls];
    return urls.some((url) => /^turns?:/iu.test(String(url || "")))
      && String(server?.username || "").length > 0
      && String(server?.credential || "").length > 0;
  });
  if (!hasAuthenticatedTurn) throw new Error("Production call ICE preflight did not return authenticated TURN.");
}

await assertTurn(first);
await assertTurn(second);
process.stdout.write(
  `Prepared distinct bounded production Human peers ${accountRef(first.userId)} and ${accountRef(second.userId)} with authenticated TURN.\n`,
);
