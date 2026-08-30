import assert from "node:assert/strict";
import test from "node:test";
import { APP_TOOL_NAMES, registerAppAgentTools } from "../lib/app-agent-tools.js";

function fakeServer() {
  const tools = new Map();
  return {
    tools,
    registerTool(name, specification, handler) {
      tools.set(name, { specification, handler });
    },
  };
}

test("App MCP registers additive semantic tools while preserving native fallback guidance", async () => {
  const server = fakeServer();
  const calls = [];
  const audits = [];
  const client = {
    async status() { return { available: true, appId: "fabushi.desktop", route: "/", screen: "messenger", generation: 9 }; },
    async call(operation, input) {
      calls.push({ operation, input });
      if (operation === "snapshot") return { route: "/", screen: "messenger", generation: 9, elementCount: 3, elements: [] };
      if (operation === "action") return { action: input.action, after: { generation: 10 } };
      return { passed: true, count: 0, matches: [] };
    },
  };
  registerAppAgentTools(server, {
    client,
    canRead: () => true,
    canWrite: () => true,
    audit: async (record) => audits.push(record),
    toolMeta: () => ({}),
  });
  assert.deepEqual([...server.tools.keys()], [
    ...Object.values(APP_TOOL_NAMES),
    "computer_control_route",
  ]);
  assert.equal(server.tools.get(APP_TOOL_NAMES.snapshot).specification.annotations.readOnlyHint, true);
  assert.equal(server.tools.get(APP_TOOL_NAMES.action).specification.annotations.readOnlyHint, false);

  const snapshot = await server.tools.get(APP_TOOL_NAMES.snapshot).handler({ maxElements: 3 });
  assert.equal(snapshot.structuredContent.generation, 9);
  const action = await server.tools.get(APP_TOOL_NAMES.action).handler({
    generation: 9,
    agentId: "test:create-bot",
    action: "invoke",
    value: "must-not-be-audited",
  });
  assert.equal(action.structuredContent.after.generation, 10);
  assert.equal(JSON.stringify(audits).includes("must-not-be-audited"), false);

  const route = await server.tools.get("computer_control_route").handler({ targetApp: "Fabushi", targetKind: "fabushi" });
  assert.equal(route.structuredContent.route, "app-mcp");
  assert.equal(route.structuredContent.screenshotIsFallback, true);
  assert.ok(route.structuredContent.priority.some((entry) => entry.tools.includes("computer_elements")));
  assert.ok(route.structuredContent.priority.some((entry) => entry.tools.includes("computer_browser_snapshot")));
  assert.equal(calls[0].operation, "snapshot");
});

test("App MCP write operations fail closed when local computer-control policy denies them", async () => {
  const server = fakeServer();
  registerAppAgentTools(server, {
    client: { async status() { return { available: false }; }, async call() { throw new Error("must not run"); } },
    canRead: () => true,
    canWrite: () => false,
    authError: () => ({ isError: true, content: [{ type: "text", text: "denied" }] }),
  });
  const denied = await server.tools.get(APP_TOOL_NAMES.action).handler({ generation: 1, agentId: "x", action: "invoke" });
  assert.equal(denied.isError, true);
  assert.equal(denied.content[0].text, "denied");
});
