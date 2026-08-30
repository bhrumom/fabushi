import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { promisify } from "node:util";
import test from "node:test";
const exec = promisify(execFile);

test("interactive device trace compiles successful app actions and excludes control plumbing", async () => {
  const root = await mkdtemp(join(tmpdir(), "fabushi-trace-"));
  try {
    const input = join(root, "trace.jsonl");
    const output = join(root, "regression.json");
    const records = [
      { at: "1", phase: "requested", requestId: "a", toolName: "computer_app_state", arguments: { app: "Fabushi" } },
      { at: "2", phase: "completed", requestId: "a", toolName: "computer_app_state", ok: true, structuredContent: { title: "Fabushi" } },
      { at: "3", phase: "requested", requestId: "b", toolName: "ci_session_finish", arguments: {} },
      { at: "4", phase: "completed", requestId: "b", toolName: "ci_session_finish", ok: true },
    ];
    await writeFile(input, `${records.map(JSON.stringify).join("\n")}\n`);
    await exec(process.execPath, [resolve("scripts/compile-ci-device-trace.mjs"), input, output]);
    const result = JSON.parse(await readFile(output, "utf8"));
    assert.equal(result.actions.length, 1);
    assert.equal(result.actions[0].toolName, "computer_app_state");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
