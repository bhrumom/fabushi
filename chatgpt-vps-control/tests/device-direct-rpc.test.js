import assert from "node:assert/strict";
import test from "node:test";
import { randomBytes } from "node:crypto";
import {
  buildDirectRpcSessionContext,
  createDirectRpcSession,
  createInvocationDeduper,
  createReplayWindow,
} from "../lib/device-direct-rpc.js";

function sessions() {
  const key = randomBytes(32);
  const context = buildDirectRpcSessionContext({
    accountId: "account-1",
    leftDeviceId: "desktop-a",
    leftGeneration: "generation-a-123456",
    rightDeviceId: "desktop-b",
    rightGeneration: "generation-b-123456",
  });
  return {
    a: createDirectRpcSession({ key, context, localDeviceId: "desktop-a", peerDeviceId: "desktop-b" }),
    b: createDirectRpcSession({ key, context, localDeviceId: "desktop-b", peerDeviceId: "desktop-a" }),
  };
}

test("direct RPC seals authenticated call/result envelopes and rejects replay", () => {
  const { a, b } = sessions();
  const call = a.seal({ kind: "call", invocationId: "invocation-1234567890", toolName: "computer_environment", arguments: {} });
  const opened = b.open(call);
  assert.equal(opened.kind, "call");
  assert.equal(opened.toolName, "computer_environment");
  assert.throws(() => b.open(call), /replay rejected/);

  const result = b.seal({ kind: "result", invocationId: opened.invocationId, ok: true, result: { value: 42 } });
  assert.deepEqual(a.open(result).result, { value: 42 });
});

test("forged packets do not consume the replay sequence", () => {
  const { a, b } = sessions();
  const envelope = a.seal({ kind: "call", invocationId: "invocation-abcdef1234", toolName: "x", arguments: {} });
  const forged = { ...envelope, tag: Buffer.from(randomBytes(16)).toString("base64url") };
  assert.throws(() => b.open(forged));
  assert.equal(b.replaySnapshot().highest, -1);
  assert.equal(b.open(envelope).invocationId, "invocation-abcdef1234");
});

test("replay window tolerates bounded UDP reordering", () => {
  const replay = createReplayWindow({ width: 8 });
  assert.equal(replay.accept(4), true);
  assert.equal(replay.accept(2), true);
  assert.equal(replay.accept(4), false);
  assert.equal(replay.accept(20), true);
  assert.equal(replay.accept(2), false);
});

test("invocation deduper executes a side effect once across direct timeout and relay fallback", async () => {
  let calls = 0;
  let now = 1_000;
  const dedupe = createInvocationDeduper({ now: () => now, ttlMs: 10_000 });
  const execute = async () => {
    calls += 1;
    await new Promise((resolve) => setTimeout(resolve, 5));
    return { calls };
  };
  const invocationId = "invocation-exactly-once-1";
  const [directResult, relayResult] = await Promise.all([
    dedupe.run(invocationId, execute),
    dedupe.run(invocationId, execute),
  ]);
  assert.equal(calls, 1);
  assert.deepEqual(directResult, { calls: 1 });
  assert.deepEqual(relayResult, { calls: 1 });

  // A later relay retry with the same invocation id reuses the completed result.
  assert.deepEqual(await dedupe.run(invocationId, execute), { calls: 1 });
  assert.equal(calls, 1);
  now += 11_000;
  dedupe.cleanup();
  assert.equal(dedupe.size(), 0);
});

test("execution errors are deduplicated and do not repeat a side effect", async () => {
  let calls = 0;
  const dedupe = createInvocationDeduper();
  const execute = async () => {
    calls += 1;
    throw new Error("tool failed after executing");
  };
  const invocationId = "invocation-error-123456";
  await assert.rejects(dedupe.run(invocationId, execute), /tool failed/);
  await assert.rejects(dedupe.run(invocationId, execute), /tool failed/);
  assert.equal(calls, 1);
});
