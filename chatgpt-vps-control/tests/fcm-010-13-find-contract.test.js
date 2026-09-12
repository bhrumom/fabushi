import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import {
  MAX_FABUSHI_APP_FIND_LIMIT,
  normalizeDeviceCallArguments,
  serializeDeviceCallArguments,
} from "../scripts/fcm-010-13-find-contract.mjs";
import {
  createMessageReceiveTracker,
  newestMessageRowsFromSnapshot,
} from "../scripts/fcm-010-13-macos-live-journey.mjs";

const controller = await readFile(new URL("../scripts/fcm-010-13-macos-external-controller-v2.mjs", import.meta.url), "utf8");
const journey = await readFile(new URL("../scripts/fcm-010-13-macos-live-journey.mjs", import.meta.url), "utf8");

function serializedFind(args) {
  return JSON.parse(serializeDeviceCallArguments("fabushi.app.find", args));
}

function messageRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    role: "article",
    agentId: `message-actions:test:${index}`,
    text: `message ${index}`,
  }));
}

function messageSnapshot(rows, { includeComposer = true } = {}) {
  const elements = [...rows];
  if (includeComposer) elements.push({ role: "textbox", agentId: "test:messenger-input", name: "Message" });
  return { elements };
}

test("production controller serializes every fabushi.app.find through the shared <=100 boundary", () => {
  assert.equal(MAX_FABUSHI_APP_FIND_LIMIT, 100);
  assert.match(controller, /serializeDeviceCallArguments\(toolName, args\)/u);
  assert.equal(controller.includes("argumentsJson: JSON.stringify(args)"), false);

  for (const requestedLimit of [undefined, 1, 5, 100, 101, 200, 10_000]) {
    const input = requestedLimit === undefined ? { role: "article" } : { role: "article", limit: requestedLimit };
    const emitted = serializedFind(input);
    assert.equal(emitted.role, "article");
    assert.ok(emitted.limit >= 1 && emitted.limit <= 100, `illegal emitted find limit ${emitted.limit}`);
    assert.equal(emitted.limit, requestedLimit === undefined ? 100 : Math.min(requestedLimit, 100));
  }

  for (const invalid of [0, -1, 1.5, "100", Number.NaN]) {
    assert.throws(
      () => normalizeDeviceCallArguments("fabushi.app.find", { limit: invalid }),
      /fabushi\.app\.find limit must be a positive integer/u,
    );
  }

  const unrelated = { timeoutMs: 30_000, limit: 200 };
  assert.equal(normalizeDeviceCallArguments("fabushi.app.wait", unrelated), unrelated);
});

test("production message receive tracker detects an echoed assistant reply past 100 rendered messages by sent-row identity", async () => {
  let rows = messageRows(130);
  const calls = [];
  const fakeDeviceTransport = async (toolName, args) => {
    calls.push({ toolName, args });
    if (toolName !== "fabushi.app.snapshot") throw new Error(`unexpected fake device call: ${toolName}`);
    return messageSnapshot(rows);
  };
  const tracker = createMessageReceiveTracker({
    callDevice: fakeDeviceTransport,
    intervalMs: 0,
    timeoutMs: 1_000,
    maxAttempts: 1,
  });

  const tracking = await tracker.captureBeforeSend(async () => {
    calls.push({ toolName: "send" });
    rows = [
      ...rows,
      { role: "article", agentId: "message-actions:test:130", text: "own probe" },
      { role: "article", agentId: "message-actions:test:131", text: "收到：own probe" },
    ];
    return "message-actions:test:130";
  });
  const { beforeIds, sentMessageRowId } = tracking;

  assert.equal(beforeIds.size, 100);
  assert.equal(beforeIds.has("message-actions:test:29"), false);
  assert.equal(beforeIds.has("message-actions:test:30"), true);
  assert.equal(beforeIds.has("message-actions:test:129"), true);
  assert.equal(sentMessageRowId, "message-actions:test:130");

  const received = await tracker.waitForIncoming(beforeIds, sentMessageRowId);
  assert.deepEqual(received, {
    agentId: "message-actions:test:131",
    text: "收到：own probe",
  });
  assert.deepEqual(calls.map((call) => call.toolName), ["fabushi.app.snapshot", "send", "fabushi.app.snapshot"]);
  assert.deepEqual(calls[0].args, { maxElements: 500, includeText: true });
  assert.deepEqual(calls[2].args, { maxElements: 500, includeText: true });

  await assert.rejects(
    () => tracker.captureBeforeSend(async () => "message-actions:test:129"),
    /sent_message_identity_not_new/u,
  );
  await assert.rejects(
    () => tracker.captureBeforeSend(async () => ""),
    /sent_message_identity_missing/u,
  );

  assert.throws(
    () => newestMessageRowsFromSnapshot(messageSnapshot(messageRows(130), { includeComposer: false })),
    /message_snapshot_incomplete: exact messenger input sentinel missing/u,
  );
  assert.throws(() => newestMessageRowsFromSnapshot(messageSnapshot(messageRows(10)), 101), /1\.\.100/u);

  assert.match(journey, /const messageReceiveTracker = createMessageReceiveTracker\(\{ callDevice \}\)/u);
  assert.match(journey, /const tracking = await messageReceiveTracker\.captureBeforeSend\(async \(\) => \{/u);
  assert.match(journey, /String\(item\?\.text \|\| item\?\.name \|\| ""\)\.trim\(\) === sendProbe/u);
  assert.match(journey, /messageReceiveTracker\.waitForIncoming\(beforeIds, sentMessageRowId\)/u);
  assert.equal(journey.includes("text.includes(ownText)"), false, "assistant replies that echo the prompt must not be filtered by text");
  assert.equal(journey.includes('find({ role: "article"'), false, "production journey must not use the oldest-first capped article query");
});

test("all literal production journey find limits are <=100 before serialization and remain <=100 after it", () => {
  assert.equal(journey.includes("limit: 200"), false, "production journey must not retain an over-limit find request");

  const literalFindLimits = [...journey.matchAll(/find\(\{[\s\S]*?limit:\s*([0-9_]+)[\s\S]*?\}\)/gu)]
    .map((match) => Number(match[1].replaceAll("_", "")))
    .filter(Number.isFinite);
  assert.ok(literalFindLimits.length > 0, "expected literal find limits in production journey");

  for (const requestedLimit of literalFindLimits) {
    assert.ok(requestedLimit <= 100, `journey contains illegal literal find limit ${requestedLimit}`);
    const emitted = serializedFind({ role: "article", limit: requestedLimit });
    assert.ok(emitted.limit <= 100, `journey requested ${requestedLimit}, controller emitted ${emitted.limit}`);
  }
});
