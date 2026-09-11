import { createAppAgentSurfaceClient } from "./app-agent-surface-client.js";

const DEFAULT_READY_TIMEOUT_MS = 30_000;
const DEFAULT_POLL_MS = 250;
const DEFAULT_TRIGGER_AGENT_ID = "test:profile-navigation-trigger";
const DEFAULT_MENU_AGENT_ID = "test:profile-navigation-menu";

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function positiveInteger(value, fallback, max) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(Math.trunc(parsed), max);
}

function requireGeneration(value, label) {
  const generation = Number(value);
  if (!Number.isSafeInteger(generation) || generation < 1) {
    throw new Error(`${label} did not return a valid App Agent generation.`);
  }
  return generation;
}

function requirePassed(result, label) {
  if (result?.passed !== true) {
    const failures = Array.isArray(result?.failures) ? result.failures.join("; ") : "condition did not pass";
    throw new Error(`${label} failed: ${failures}`);
  }
}

export async function runAppAgentCiSmoke(options = {}) {
  const client = options.client ?? createAppAgentSurfaceClient(options.clientOptions);
  const readyTimeoutMs = positiveInteger(options.readyTimeoutMs, DEFAULT_READY_TIMEOUT_MS, 120_000);
  const pollMs = positiveInteger(options.pollMs, DEFAULT_POLL_MS, 5_000);
  const triggerAgentId = String(options.triggerAgentId || DEFAULT_TRIGGER_AGENT_ID);
  const menuAgentId = String(options.menuAgentId || DEFAULT_MENU_AGENT_ID);
  const startedAt = new Date().toISOString();
  const deadline = Date.now() + readyTimeoutMs;

  let status = await client.status();
  while (status?.available !== true && Date.now() < deadline) {
    await sleep(pollMs);
    status = await client.status();
  }
  if (status?.available !== true) {
    throw new Error(`Fabushi App Agent Surface did not become available within ${readyTimeoutMs}ms: ${status?.reason || "unknown reason"}`);
  }

  const snapshot = await client.call("snapshot", { maxElements: 500, includeText: true });
  const initialGeneration = requireGeneration(snapshot?.generation, "snapshot");
  if (!Array.isArray(snapshot?.elements)) throw new Error("snapshot did not return semantic elements.");
  if (snapshot.elements.some((element) => element?.sensitive === true && Object.hasOwn(element, "value"))) {
    throw new Error("snapshot exposed a sensitive semantic value.");
  }

  requirePassed(await client.call("wait", {
    agentId: triggerAgentId,
    state: "visible",
    timeoutMs: 10_000,
  }), "profile trigger visibility wait");

  const trigger = await client.call("find", { agentId: triggerAgentId, limit: 1 });
  if (trigger?.count !== 1) throw new Error(`Expected exactly one ${triggerAgentId}; found ${trigger?.count ?? "unknown"}.`);
  const openGeneration = requireGeneration(trigger?.generation ?? initialGeneration, "trigger find");
  await client.call("action", {
    generation: openGeneration,
    agentId: triggerAgentId,
    action: "invoke",
  });

  requirePassed(await client.call("assert", {
    agentId: menuAgentId,
    state: "visible",
  }), "profile menu visible assertion");

  const closeTrigger = await client.call("find", { agentId: triggerAgentId, limit: 1 });
  if (closeTrigger?.count !== 1) throw new Error(`Expected exactly one ${triggerAgentId} while closing the smoke menu.`);
  await client.call("action", {
    generation: requireGeneration(closeTrigger?.generation, "fresh trigger find"),
    agentId: triggerAgentId,
    action: "invoke",
  });

  requirePassed(await client.call("wait", {
    agentId: menuAgentId,
    state: "hidden",
    timeoutMs: 10_000,
  }), "profile menu hidden wait");

  const finalStatus = await client.status();
  if (finalStatus?.available !== true) throw new Error("Fabushi App Agent Surface became unavailable during the smoke journey.");

  return Object.freeze({
    schema: "fabushi.app-agent-ci-smoke.v1",
    ok: true,
    appId: String(finalStatus.appId || status.appId || "fabushi.desktop"),
    platform: String(finalStatus.platform || status.platform || "unknown"),
    route: finalStatus.route ?? null,
    screen: finalStatus.screen ?? null,
    initialGeneration,
    finalGeneration: Number.isSafeInteger(Number(finalStatus.generation)) ? Number(finalStatus.generation) : null,
    triggerAgentId,
    menuAgentId,
    operations: ["status", "snapshot", "wait", "find", "action", "assert", "find", "action", "wait", "status"],
    startedAt,
    completedAt: new Date().toISOString(),
  });
}
