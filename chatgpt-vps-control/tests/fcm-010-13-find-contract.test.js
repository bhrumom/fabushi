import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import {
  MAX_FABUSHI_APP_FIND_LIMIT,
  normalizeDeviceCallArguments,
  serializeDeviceCallArguments,
} from "../scripts/fcm-010-13-find-contract.mjs";
import { newestMessageRowsFromSnapshot } from "../scripts/fcm-010-13-macos-live-journey.mjs";

const controller = await readFile(new URL("../scripts/fcm-010-13-macos-external-controller-v2.mjs", import.meta.url), "utf8");
const journey = await readFile(new URL("../scripts/fcm-010-13-macos-live-journey.mjs", import.meta.url), "utf8");

function serializedFind(args) {
  return JSON.parse(serializeDeviceCallArguments("fabushi.app.find", args));
}

function messageSnapshot(count, { includeComposer = true } = {}) {
  const elements = Array.from({ length: count }, (_, index) => ({
    role: "article",
    agentId: `message-actions:test:${index}`,
    text: `message ${index}`,
  }));
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

test("messageRowIds/send regression preserves the newest response past 100 rendered rows", () => {
  const baselineRows = newestMessageRowsFromSnapshot(messageSnapshot(130));
  assert.equal(baselineRows.length, 100);
  assert.equal(baselineRows[0].agentId, "message-actions:test:30");
  assert.equal(baselineRows.at(-1).agentId, "message-actions:test:129");

  const baselineIds = new Set(baselineRows.map((item) => item.agentId));
  const afterRows = newestMessageRowsFromSnapshot(messageSnapshot(131));
  const unseen = afterRows.filter((item) => !baselineIds.has(item.agentId));
  assert.deepEqual(unseen.map((item) => item.agentId), ["message-actions:test:130"]);

  assert.throws(
    () => newestMessageRowsFromSnapshot(messageSnapshot(130, { includeComposer: false })),
    /message_snapshot_incomplete: exact messenger input sentinel missing/u,
  );
  assert.throws(() => newestMessageRowsFromSnapshot(messageSnapshot(10), 101), /1\.\.100/u);

  const messageRowIdsStart = journey.indexOf("async function messageRowIds()");
  const messageRowIdsEnd = journey.indexOf("async function waitForAssistantUnread", messageRowIdsStart);
  const messageRowIds = journey.slice(messageRowIdsStart, messageRowIdsEnd);
  assert.ok(messageRowIdsStart >= 0 && messageRowIdsEnd > messageRowIdsStart, "messageRowIds helper must remain present");
  assert.match(messageRowIds, /const fresh = await snapshot\(\)/u);
  assert.match(messageRowIds, /newestMessageRowsFromSnapshot\(fresh\)/u);
  assert.equal(messageRowIds.includes('find({ role: "article"'), false, "message baseline must not use the oldest-first capped find path");

  const incomingStart = journey.indexOf("async function waitForIncomingMessage");
  const incomingEnd = journey.indexOf("async function ensureGlobalDharmaInstalled", incomingStart);
  const incoming = journey.slice(incomingStart, incomingEnd);
  assert.match(incoming, /newestMessageRowsFromSnapshot\(await snapshot\(\)\)/u);
  assert.equal(incoming.includes('find({ role: "article"'), false, "incoming polling must not use the oldest-first capped find path");

  const sendStart = journey.indexOf('await category("send"');
  const sendEnd = journey.indexOf('await category("unread"', sendStart);
  const send = journey.slice(sendStart, sendEnd);
  assert.ok(sendStart >= 0 && sendEnd > sendStart, "send category must remain present");
  const baselineIndex = send.indexOf("messageIdsBeforeSend = await messageRowIds()");
  const sendProbeIndex = send.indexOf("await sendText(sendProbe)");
  assert.ok(baselineIndex >= 0 && sendProbeIndex > baselineIndex, "message baseline must be captured before sending so a fast response cannot be absorbed into the baseline");

  const receiveStart = journey.indexOf('await category("receive"');
  const receiveEnd = journey.indexOf('await navigateSection("频道")', receiveStart);
  const receive = journey.slice(receiveStart, receiveEnd);
  assert.match(receive, /waitForIncomingMessage\(messageIdsBeforeSend, sendProbe\)/u);

  assert.deepEqual(serializedFind({ role: "article", limit: 100 }), { role: "article", limit: 100 });
  assert.deepEqual(serializedFind({ role: "article", limit: 200 }), { role: "article", limit: 100 });
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
