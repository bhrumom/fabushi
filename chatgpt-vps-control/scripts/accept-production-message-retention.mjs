#!/usr/bin/env node
import { createHash, randomUUID } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve, sep } from "node:path";

function required(name) {
  const value = String(process.env[name] || "").trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

function privateRunnerPath(name) {
  const root = resolve(required("RUNNER_TEMP"));
  const value = resolve(required(name));
  if (!value.startsWith(`${root}${sep}`)) {
    throw new Error(`${name} must live under RUNNER_TEMP.`);
  }
  return value;
}

async function readBoundedSession(name) {
  const raw = JSON.parse(await readFile(privateRunnerPath(name), "utf8"));
  const accessToken = String(raw?.accessToken || "").trim();
  const deviceId = String(raw?.deviceId || "").trim();
  const userId = String(raw?.userId || raw?.user?.id || "").trim();
  if (raw?.provider !== "github-actions" || raw?.ciRunner !== true || "refreshToken" in raw) {
    throw new Error(`${name} is not a bounded refresh-token-free GitHub Actions session.`);
  }
  if (!accessToken || !deviceId || !userId) throw new Error(`${name} is incomplete.`);
  return { accessToken, deviceId, userId };
}

function opaqueRef(value) {
  return createHash("sha256").update(String(value)).digest("hex").slice(0, 16);
}

const baseUrl = new URL(required("FABUSHI_API_BASE_URL"));
if (baseUrl.protocol !== "https:" || baseUrl.username || baseUrl.password || baseUrl.search || baseUrl.hash) {
  throw new Error("FABUSHI_API_BASE_URL must be a clean HTTPS origin/base URL.");
}
if (process.env.GITHUB_ACTIONS !== "true") {
  throw new Error("Production retention acceptance is GitHub Actions only.");
}

const first = await readBoundedSession("FABUSHI_RETENTION_SESSION_A");
const second = await readBoundedSession("FABUSHI_RETENTION_SESSION_B");
if (first.userId !== second.userId) throw new Error("Retention device sessions must belong to the same CI account.");
if (first.deviceId === second.deviceId) throw new Error("Retention acceptance requires two distinct device sessions.");

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

async function requireRetention(session, contactId) {
  const { response, payload } = await api(
    session,
    `/api/social/message-retention?contactId=${encodeURIComponent(contactId)}`,
  );
  if (!response.ok || payload?.success !== true || !payload?.retention) {
    throw new Error(`Retention read failed with HTTP ${response.status}.`);
  }
  const revision = Number(payload.retention.revision);
  const retentionSeconds = payload.retention.retentionSeconds == null
    ? null
    : Number(payload.retention.retentionSeconds);
  if (!Number.isSafeInteger(revision) || revision < 0) throw new Error("Retention revision is invalid.");
  if (retentionSeconds != null && (!Number.isSafeInteger(retentionSeconds) || retentionSeconds <= 0)) {
    throw new Error("Retention seconds are invalid.");
  }
  return {
    conversationId: String(payload.retention.conversationId || ""),
    retentionSeconds,
    revision,
  };
}

async function setRetention(session, contactId, retentionSeconds, expectedRevision) {
  return api(session, "/api/social/message-retention", {
    method: "PUT",
    body: JSON.stringify({ contactId, retentionSeconds, expectedRevision }),
  });
}

const friendsResult = await api(first, "/api/social/friends");
if (!friendsResult.response.ok || friendsResult.payload?.success !== true) {
  throw new Error(`Friend list failed with HTTP ${friendsResult.response.status}.`);
}
const friends = Array.isArray(friendsResult.payload?.data?.friends)
  ? friendsResult.payload.data.friends
  : [];
const peer = friends.find((friend) => String(friend?.userId ?? friend?.id ?? "").trim());
if (!peer) {
  throw new Error("Production CI account has no accepted Human friend for retention acceptance.");
}
const contactId = String(peer.userId ?? peer.id).trim();

const baselineA = await requireRetention(first, contactId);
const baselineB = await requireRetention(second, contactId);
if (baselineA.conversationId !== baselineB.conversationId
    || baselineA.revision !== baselineB.revision
    || baselineA.retentionSeconds !== baselineB.retentionSeconds) {
  throw new Error("Two production devices did not begin from the same retention authority.");
}

const probeSeconds = baselineA.retentionSeconds === 2 ? 3 : 2;
let mutatedRevision = null;
let restored = false;
let acceptanceError = null;
const clientRequestId = `gha-retention-${process.env.GITHUB_RUN_ID || "run"}-${process.env.GITHUB_RUN_ATTEMPT || "attempt"}-${randomUUID()}`;
const messageText = "Fabushi GitHub Actions retention acceptance";

try {
  const changed = await setRetention(first, contactId, probeSeconds, baselineA.revision);
  if (!changed.response.ok || changed.payload?.success !== true || !changed.payload?.retention) {
    throw new Error(`Retention mutation failed with HTTP ${changed.response.status}.`);
  }
  mutatedRevision = Number(changed.payload.retention.revision);
  if (mutatedRevision !== baselineA.revision + 1
      || Number(changed.payload.retention.retentionSeconds) !== probeSeconds) {
    throw new Error("Retention mutation did not advance the authoritative revision.");
  }

  const converged = await requireRetention(second, contactId);
  if (converged.revision !== mutatedRevision || converged.retentionSeconds !== probeSeconds) {
    throw new Error("Second production device did not observe the authoritative retention mutation.");
  }

  const stale = await setRetention(second, contactId, probeSeconds, baselineA.revision);
  if (stale.response.status !== 409
      || stale.payload?.success !== false
      || Number(stale.payload?.retention?.revision) !== mutatedRevision) {
    throw new Error(`Stale retention mutation did not fail closed with current authority (HTTP ${stale.response.status}).`);
  }

  const sent = await api(first, "/api/social/messages", {
    method: "POST",
    body: JSON.stringify({
      targetUserId: contactId,
      text: messageText,
      clientRequestId,
      silent: true,
    }),
  });
  if (sent.response.status !== 201 || sent.payload?.success !== true || !sent.payload?.message) {
    throw new Error(`Retention probe message send failed with HTTP ${sent.response.status}.`);
  }
  const expiresAtMs = Number(sent.payload.message.expiresAtMs);
  if (!Number.isSafeInteger(expiresAtMs) || expiresAtMs <= Date.now()) {
    throw new Error("Retention probe message did not receive a future server-authoritative expiry.");
  }

  const settleDelay = Math.max(0, expiresAtMs - Date.now()) + 1500;
  await new Promise((resolveDelay) => setTimeout(resolveDelay, settleDelay));

  const list = await api(
    second,
    `/api/social/messages?contactId=${encodeURIComponent(contactId)}&limit=200`,
  );
  if (!list.response.ok || list.payload?.success !== true) {
    throw new Error(`Post-expiry message sync failed with HTTP ${list.response.status}.`);
  }
  const messages = Array.isArray(list.payload?.data?.messages) ? list.payload.data.messages : [];
  if (messages.some((message) => String(message?.clientRequestId || "") === clientRequestId)) {
    throw new Error("Expired message resurrected in the second production device sync.");
  }

  const replay = await api(first, "/api/social/messages", {
    method: "POST",
    body: JSON.stringify({
      targetUserId: contactId,
      text: messageText,
      clientRequestId,
      silent: true,
    }),
  });
  if (replay.response.status !== 410
      || replay.payload?.success !== false
      || String(replay.payload?.tombstone?.clientRequestId || "") !== clientRequestId) {
    throw new Error(`Expired client-message-id replay did not return the durable tombstone (HTTP ${replay.response.status}).`);
  }
} catch (error) {
  acceptanceError = error;
} finally {
  try {
    const current = await requireRetention(first, contactId);
    const restore = await setRetention(
      first,
      contactId,
      baselineA.retentionSeconds,
      current.revision,
    );
    if (!restore.response.ok || restore.payload?.success !== true || !restore.payload?.retention) {
      throw new Error(`Retention restoration failed with HTTP ${restore.response.status}.`);
    }
    const restoredRevision = Number(restore.payload.retention.revision);
    const observed = await requireRetention(second, contactId);
    if (observed.revision !== restoredRevision
        || observed.retentionSeconds !== baselineA.retentionSeconds) {
      throw new Error("Second production device did not observe the restored retention policy.");
    }
    restored = true;
  } catch (restoreError) {
    if (acceptanceError) {
      acceptanceError = new Error(`${acceptanceError.message}; additionally failed to restore production retention policy: ${restoreError.message}`);
    } else {
      acceptanceError = restoreError;
    }
  }
}

const evidencePath = privateRunnerPath("FABUSHI_RETENTION_ACCEPTANCE_EVIDENCE_FILE");
await mkdir(dirname(evidencePath), { recursive: true, mode: 0o700 });
const evidence = {
  schema: "fabushi.message-retention-production-acceptance.v1",
  sourceSha: String(process.env.EXPECTED_SOURCE_SHA || ""),
  runId: String(process.env.GITHUB_RUN_ID || ""),
  runAttempt: String(process.env.GITHUB_RUN_ATTEMPT || ""),
  accountRef: opaqueRef(first.userId),
  peerRef: opaqueRef(contactId),
  deviceCount: 2,
  baselineRevision: baselineA.revision,
  mutatedRevision,
  restored,
  staleRevisionRejected: acceptanceError == null,
  expiredReplayRejected: acceptanceError == null,
  completedAt: new Date().toISOString(),
};
await writeFile(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`, { mode: 0o600 });

if (acceptanceError) throw acceptanceError;
process.stdout.write(
  `Authenticated production retention acceptance passed for account ${evidence.accountRef} across two device sessions; original policy restored.\n`,
);
