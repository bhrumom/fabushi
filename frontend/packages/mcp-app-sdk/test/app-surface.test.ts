import assert from "node:assert/strict";
import test from "node:test";
import {
  FABUSHI_APP_TOOL_NAMES,
  appSurfaceRegistry,
  appSurfaceToolDefinitions,
  type AppSurface,
} from "../src/app-surface.ts";

test("App Surface definitions keep WebMCP and native App MCP on one stable contract", async () => {
  const calls: Array<{ operation: string; input: Record<string, unknown> }> = [];
  const surface: AppSurface = {
    version: 1,
    appId: "fabushi.test",
    async call(operation, input = {}) {
      calls.push({ operation, input });
      return { operation, input };
    },
  };
  const registry = appSurfaceRegistry(surface);
  assert.equal(registry.version, 1);
  assert.equal(registry.appId, "fabushi.test");
  assert.deepEqual(appSurfaceToolDefinitions().map((tool) => tool.name), Object.values(FABUSHI_APP_TOOL_NAMES));
  assert.equal(appSurfaceToolDefinitions().find((tool) => tool.name === FABUSHI_APP_TOOL_NAMES.action)?.annotations.readOnlyHint, false);
  const result = await registry.call(FABUSHI_APP_TOOL_NAMES.snapshot, { maxElements: 5 });
  assert.deepEqual(result, { operation: "snapshot", input: { maxElements: 5 } });
  assert.deepEqual(calls, [{ operation: "snapshot", input: { maxElements: 5 } }]);
});
