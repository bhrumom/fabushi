import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import {
  MAX_FABUSHI_APP_FIND_LIMIT,
  normalizeDeviceCallArguments,
  serializeDeviceCallArguments,
} from "../scripts/fcm-010-13-find-contract.mjs";

const controller = await readFile(new URL("../scripts/fcm-010-13-macos-external-controller-v2.mjs", import.meta.url), "utf8");
const journey = await readFile(new URL("../scripts/fcm-010-13-macos-live-journey.mjs", import.meta.url), "utf8");

function serializedFind(args) {
  return JSON.parse(serializeDeviceCallArguments("fabushi.app.find", args));
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

test("messageRowIds/send regression stays inside the production find contract", () => {
  const messageRowIdsStart = journey.indexOf("async function messageRowIds()");
  const messageRowIdsEnd = journey.indexOf("async function waitForAssistantUnread", messageRowIdsStart);
  const messageRowIds = journey.slice(messageRowIdsStart, messageRowIdsEnd);
  assert.ok(messageRowIdsStart >= 0 && messageRowIdsEnd > messageRowIdsStart, "messageRowIds helper must remain present");
  assert.match(messageRowIds, /find\(\{ role: "article", limit: 100 \}\)/u);

  const sendStart = journey.indexOf('await category("send"');
  const sendEnd = journey.indexOf('await category("unread"', sendStart);
  const send = journey.slice(sendStart, sendEnd);
  assert.ok(sendStart >= 0 && sendEnd > sendStart, "send category must remain present");
  assert.match(send, /messageIdsAfterSend = await messageRowIds\(\)/u);

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
