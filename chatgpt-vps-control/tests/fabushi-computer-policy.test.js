import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { computerControlPolicyDecision } from "../lib/fabushi-computer-policy.js";

async function withPolicy(value, callback) {
  const root = await mkdtemp(join(tmpdir(), "fabushi-computer-policy-"));
  const path = join(root, "settings.json");
  try {
    if (value !== undefined) {
      await writeFile(path, typeof value === "string" ? value : JSON.stringify(value));
    }
    await callback(path);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}

test("Computer Use policy fails closed when configuration is absent or unreadable", async () => {
  assert.equal(computerControlPolicyDecision({ env: {} }).allowed, false);
  await withPolicy(undefined, async (path) => {
    const decision = computerControlPolicyDecision({ env: { FABUSHI_COMPUTER_POLICY_FILE: path } });
    assert.equal(decision.allowed, false);
    assert.match(decision.reason, /尚未准备好/);
  });
  await withPolicy("{not-json", async (path) => {
    assert.equal(computerControlPolicyDecision({ env: { FABUSHI_COMPUTER_POLICY_FILE: path } }).allowed, false);
  });
});

test("Computer Use policy requires explicit local execution, AI control, and a valid permission", async () => {
  const baseline = { localExecution: true, aiComputerControlEnabled: true, localToolPermission: "ask" };
  await withPolicy(baseline, async (path) => {
    assert.equal(computerControlPolicyDecision({ env: { FABUSHI_COMPUTER_POLICY_FILE: path } }).allowed, true);
  });
  for (const settings of [
    { ...baseline, localExecution: false },
    { ...baseline, aiComputerControlEnabled: false },
    { ...baseline, localToolPermission: "never" },
    { localExecution: true, aiComputerControlEnabled: true },
    { ...baseline, localToolPermission: "unexpected" },
  ]) {
    await withPolicy(settings, async (path) => {
      assert.equal(computerControlPolicyDecision({ env: { FABUSHI_COMPUTER_POLICY_FILE: path } }).allowed, false);
    });
  }
});
