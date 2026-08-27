import assert from "node:assert/strict";
import test from "node:test";

import {
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

test("native modelContext registration receives tool metadata and lifecycle signal", () => {
  const registered: any[] = [];
  const unregistered: string[] = [];
  installGlobals({
    registerTool(tool: unknown) { registered.push(tool); },
    unregisterTool(name: string) { unregistered.push(name); },
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

  assert.equal(supportsNativeWebMcp(), true);
  assert.equal(registered.length, 1);
  assert.equal(registered[0].name, "set_speed");
  assert.ok(registered[0].signal instanceof AbortSignal);
  assert.equal(registered[0].signal.aborted, false);

  dispose();
  assert.equal(registered[0].signal.aborted, true);
  assert.deepEqual(unregistered, ["set_speed"]);
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
