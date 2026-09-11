import assert from "node:assert/strict";
import test from "node:test";

import { runAppAgentCiSmoke } from "../lib/app-agent-ci-smoke.js";

function fakeClient(options = {}) {
  const calls = [];
  let generation = 7;
  let menuVisible = false;
  const client = {
    async status() {
      calls.push(["status", {}]);
      return {
        version: 1,
        appId: "fabushi.desktop",
        platform: "electron",
        available: true,
        route: "/messages",
        screen: "messenger",
        generation,
      };
    },
    async call(operation, input) {
      calls.push([operation, structuredClone(input)]);
      if (operation === "snapshot") {
        return {
          generation,
          elements: [
            { agentId: "test:profile-navigation-trigger", sensitive: false },
            { agentId: "redacted-sensitive-probe", sensitive: true },
          ],
        };
      }
      if (operation === "wait") {
        if (input.agentId === "test:profile-navigation-trigger") return { passed: true };
        if (input.agentId === "test:profile-navigation-menu") return { passed: !menuVisible };
      }
      if (operation === "find") return { generation, count: 1, matches: [{ agentId: input.agentId }] };
      if (operation === "action") {
        assert.equal(input.generation, generation);
        generation += 1;
        menuVisible = !menuVisible;
        return { status: "completed", after: { generation } };
      }
      if (operation === "assert") {
        return { passed: options.failVisibleAssertion ? false : menuVisible, failures: options.failVisibleAssertion ? ["menu hidden"] : [] };
      }
      throw new Error(`unexpected operation ${operation}`);
    },
  };
  return { client, calls };
}

test("Action-owned App Agent smoke drives the existing semantic bridge without coordinates", async () => {
  const { client, calls } = fakeClient();
  const result = await runAppAgentCiSmoke({ client, readyTimeoutMs: 1_000, pollMs: 1 });

  assert.equal(result.ok, true);
  assert.equal(result.appId, "fabushi.desktop");
  assert.equal(result.platform, "electron");
  assert.deepEqual(result.operations, ["status", "snapshot", "wait", "find", "action", "assert", "find", "action", "wait", "status"]);
  assert.deepEqual(calls.map(([operation]) => operation), result.operations);
  assert.equal(calls.some(([operation, input]) => operation === "action" && Object.hasOwn(input, "x")), false);
  assert.equal(calls.some(([operation, input]) => operation === "action" && Object.hasOwn(input, "y")), false);
});

test("Action-owned App Agent smoke fails closed when a semantic assertion fails", async () => {
  const { client } = fakeClient({ failVisibleAssertion: true });
  await assert.rejects(
    runAppAgentCiSmoke({ client, readyTimeoutMs: 1_000, pollMs: 1 }),
    /profile menu visible assertion failed: menu hidden/u,
  );
});

test("Action-owned App Agent smoke rejects sensitive values in snapshots", async () => {
  const { client } = fakeClient();
  const originalCall = client.call;
  client.call = async (operation, input) => {
    const result = await originalCall(operation, input);
    if (operation === "snapshot") result.elements[1].value = "must-not-escape";
    return result;
  };
  await assert.rejects(
    runAppAgentCiSmoke({ client, readyTimeoutMs: 1_000, pollMs: 1 }),
    /snapshot exposed a sensitive semantic value/u,
  );
});
