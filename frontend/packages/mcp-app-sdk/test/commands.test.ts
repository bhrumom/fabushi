import assert from "node:assert/strict";
import test from "node:test";

import { parseToolCommand, schemaDefaults, validateSchemaValue } from "../src/commands.ts";
import type { McpTool } from "../src/types.ts";

const tools: McpTool[] = [
  { name: "home", inputSchema: { type: "object", properties: {} } },
  {
    name: "send",
    inputSchema: {
      type: "object",
      properties: { content: { type: "string" } },
      required: ["content"],
    },
  },
  {
    name: "deploy_latest",
    inputSchema: {
      type: "object",
      properties: {
        environment: { type: "string", enum: ["staging", "production"], default: "staging" },
        options: {
          type: "object",
          properties: { replicas: { type: "integer", default: 1 } },
          required: ["replicas"],
        },
        regions: { type: "array", items: { type: "string" } },
      },
      required: ["environment", "options"],
    },
  },
];

test("command names map exactly to MCP Tool names", () => {
  const home = parseToolCommand("/home", tools);
  assert.equal(home.kind, "call");
  if (home.kind === "call") assert.deepEqual(home.arguments, {});

  const deploy = parseToolCommand("/deploy_latest", tools);
  assert.equal(deploy.kind, "form");
  assert.throws(() => parseToolCommand("/deploy-latest", tools), /没有 \/deploy-latest Tool/);
});

test("one string field receives all text after the first separator unchanged", () => {
  const parsed = parseToolCommand("/send   保留  内部空格", tools);
  assert.equal(parsed.kind, "call");
  if (parsed.kind === "call") {
    assert.deepEqual(parsed.arguments, { content: "  保留  内部空格" });
  }
});

test("ordinary text stays ordinary and host commands are not reserved", () => {
  assert.deepEqual(parseToolCommand("请查看状态", tools), { kind: "text", text: "请查看状态" });
  assert.throws(() => parseToolCommand("/quit", tools), /没有 \/quit Tool/);
  assert.throws(() => parseToolCommand("/history", tools), /没有 \/history Tool/);
});

test("nested defaults and schema validation cover shared form types", () => {
  const schema = tools[2].inputSchema;
  assert.deepEqual(schemaDefaults(schema), {
    environment: "staging",
    options: { replicas: 1 },
    regions: [],
  });
  assert.deepEqual(validateSchemaValue(schema, {
    environment: "production",
    options: { replicas: 2 },
    regions: ["ap-east-1"],
  }), []);
  assert.deepEqual(validateSchemaValue(schema, {
    environment: "invalid",
    options: { replicas: 1.5 },
    regions: [3],
  }), [
    "$.environment 必须是枚举中的一个值",
    "$.options.replicas 必须是整数",
    "$.regions[0] 必须是字符串",
  ]);
  assert.deepEqual(validateSchemaValue(schema, {}), [
    "$.environment 是必填项",
    "$.options 是必填项",
  ]);
});
