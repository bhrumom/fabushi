import assert from "node:assert/strict";
import test from "node:test";

import {
  callRegisteredWebMcpTool,
  exposeMcpToolsAsWebMcp,
  listRegisteredWebMcpTools,
  registerWebMcpTool,
  supportsNativeWebMcp,
} from "../src/webmcp.ts";

function installGlobals(modelContext?: Record<string, unknown>) {
  (globalThis as any).window = {};
  (globalThis as any).document = modelContext ? { modelContext } : {};
}

function clearGlobals() {
  delete (globalThis as any).window;
  delete (globalThis as any).document;
}

test("fallback registry exposes registered tools and executes them", async () => {
  installGlobals();
  const dispose = registerWebMcpTool({
    name: "status",
    description: "Read current status",
    inputSchema: { type: "object", properties: {} },
    annotations: { readOnlyHint: true },
    execute: async () => ({ running: true }),
  });

  assert.equal(supportsNativeWebMcp(), false);
  assert.deepEqual(listRegisteredWebMcpTools().map((tool) => tool.name), ["status"]);
  assert.deepEqual(await (globalThis as any).window.__fabushiWebMcp.call("status", {}), { running: true });

  dispose();
  assert.deepEqual(listRegisteredWebMcpTools(), []);
  clearGlobals();
});

test("native modelContext registration receives lifecycle signal as register options", async () => {
  const registered: any[] = [];
  installGlobals({
    async registerTool(tool: unknown, options: unknown) { registered.push({ tool, options }); },
  });

  const dispose = registerWebMcpTool({
    name: "set_speed",
    description: "Set prayer wheel speed",
    inputSchema: {
      type: "object",
      properties: { speed: { type: "number" } },
      required: ["speed"],
    },
    execute: () => ({ ok: true }),
  });

  await Promise.resolve();
  assert.equal(supportsNativeWebMcp(), true);
  assert.equal(registered.length, 1);
  assert.equal(registered[0].tool.name, "set_speed");
  assert.ok(registered[0].options.signal instanceof AbortSignal);
  assert.equal(registered[0].options.signal.aborted, false);

  dispose();
  assert.equal(registered[0].options.signal.aborted, true);
  clearGlobals();
});

test("native discovery executes a RegisteredTool and parses its stringified result", async () => {
  const registeredTool = {
    name: "status",
    description: "Read status",
    inputSchema: "{}",
  };
  installGlobals({
    registerTool() {},
    async getTools() { return [registeredTool]; },
    async executeTool(tool: unknown, input: unknown) {
      assert.equal(tool, registeredTool);
      assert.deepEqual(input, { detail: true });
      return JSON.stringify({ running: true });
    },
  });

  assert.deepEqual(
    await callRegisteredWebMcpTool("status", { detail: true }),
    { running: true },
  );
  clearGlobals();
});

test("MCP tools are projected to WebMCP without a second command mapping", async () => {
  installGlobals();
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  const dispose = exposeMcpToolsAsWebMcp([
    {
      name: "start_prayer_wheel",
      description: "Start the selected prayer wheel",
      inputSchema: { type: "object", properties: {} },
      annotations: { readOnlyHint: false },
    },
  ], async (name, args) => {
    calls.push({ name, args });
    return { structuredContent: { started: true } };
  });

  const result = await (globalThis as any).window.__fabushiWebMcp.call("start_prayer_wheel", {});
  assert.deepEqual(calls, [{ name: "start_prayer_wheel", args: {} }]);
  assert.deepEqual(result, { structuredContent: { started: true } });

  dispose();
  clearGlobals();
});
