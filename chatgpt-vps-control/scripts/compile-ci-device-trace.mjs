#!/usr/bin/env node
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const input = resolve(process.argv[2] || "");
const output = resolve(process.argv[3] || "");
if (!process.argv[2] || !process.argv[3]) throw new Error("Usage: compile-ci-device-trace.mjs <trace.jsonl> <regression.json>");
let lines = [];
try { lines = (await readFile(input, "utf8")).split(/\r?\n/u).filter(Boolean); } catch (error) {
  if (error?.code !== "ENOENT") throw error;
}
const requested = new Map();
const actions = [];
for (const line of lines) {
  let record;
  try { record = JSON.parse(line); } catch { continue; }
  const requestId = String(record.requestId || "");
  if (!requestId) continue;
  if (record.phase === "requested") requested.set(requestId, record);
  if (record.phase !== "completed" || record.ok !== true) continue;
  const start = requested.get(requestId);
  if (!start || ["secure_input_submit", "ci_session_status", "ci_session_note", "ci_session_finish"].includes(start.toolName)) continue;
  actions.push({
    sequence: actions.length + 1,
    toolName: start.toolName,
    arguments: start.arguments,
    expected: record.structuredContent ?? null,
    recordedAt: start.at,
  });
}
const payload = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  source: "Fabushi interactive GitHub Actions Runner MCP trace",
  replaySafety: "Review redacted values and environment-specific element identifiers before promotion to a required gate.",
  actions,
};
await writeFile(output, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
console.log(`Compiled ${actions.length} successful remote device actions into ${output}.`);
