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
  matchingTargets,
  newestMessageRowsFromSnapshot,
} from "../scripts/fcm-010-13-macos-live-journey.mjs";

const controller = await readFile(new URL("../scripts/fcm-010-13-macos-external-controller-v2.mjs", import.meta.url), "utf8");
const journey = await readFile(new URL("../scripts/fcm-010-13-macos-live-journey.mjs", import.meta.url), "utf8");
const botMark = await readFile(new URL("../../frontend/apps/web/src/app/host/bot-mark.tsx", import.meta.url), "utf8");

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

test("production find selection trusts server text/name filtering after returned labels are redacted", () => {
  const redactedTextResult = {
    matches: [
      { role: "div", agentId: "test:message-list", text: "<redacted-ui-text>" },
      { role: "article", agentId: "message-actions:legacy:optimistic:chat-send-1", text: "<redacted-ui-text>" },
    ],
  };
  const textMatches = matchingTargets(redactedTextResult, { text: "secret probe" }, (item) => (
    item?.role === "article" && String(item?.agentId || "").startsWith("message-actions:")
  ));
  assert.deepEqual(textMatches.map((item) => item.agentId), ["message-actions:legacy:optimistic:chat-send-1"]);

  const redactedNameResult = {
    matches: [
      { role: "button", agentId: "forward-message-peer:channel-b", name: "<redacted-ui-text>" },
    ],
  };
  const nameMatches = matchingTargets(redactedNameResult, { role: "button", name: "FCM channel B" }, (item) => (
    String(item?.agentId || "").startsWith("forward-message-peer:")
  ));
  assert.deepEqual(nameMatches.map((item) => item.agentId), ["forward-message-peer:channel-b"]);

  assert.equal(journey.includes("if (query.name && item?.name !== query.name)"), false);
  assert.equal(journey.includes("haystack.includes(query.text)"), false);
  assert.equal(journey.includes(".trim() === sendProbe"), false);
  assert.equal(journey.includes(".includes(text)"), false);
});

test("assistant unread contract exposes an exact semantic name and requires a post-send false-to-true transition", () => {
  assert.match(botMark, /closest<HTMLElement>\('button\[data-testid\^="peer-"\]'\)/u);
  assert.match(botMark, /const agentId = `peer-unread:\$\{testId\.slice\("peer-"\.length\)\}`/u);
  assert.match(botMark, /peerButton\.querySelector\("b"\) != null/u);
  assert.match(botMark, /new MutationObserver\(update\)/u);
  assert.match(botMark, /data-agent-id=\{peerUnreadSemantic\?\.agentId\}/u);
  assert.match(botMark, /peerUnreadSemantic\.positive \? "unread-positive" : "unread-none"/u);
  assert.match(botMark, /aria-label=\{semanticLabel\}/u);
  assert.match(botMark, /aria-description=\{semanticDescription\}/u);
  assert.equal(botMark.includes('`${label ?? botId} ${peerUnreadSemantic.positive ? "unread-positive" : "unread-none"}`'), false,
    "the semantic App Surface name must be the exact unread marker, not a human-label-prefixed string");

  assert.match(journey, /const ASSISTANT_UNREAD_AGENT_ID = "peer-unread:legacy:conversation:mahayana-ai:agent:assistant"/u);
  assert.match(journey, /find\(\{ agentId: ASSISTANT_UNREAD_AGENT_ID, name: marker, limit: 1 \}\)/u);
  assert.equal(journey.includes("peerHasUnreadBadgeFromSnapshot"), false);
  assert.equal(journey.includes("unreadMatch = text.match"), false);
  assert.equal(journey.includes("assistantPeerTextBefore"), false);

  const baselineIndex = journey.indexOf("const unreadBaseline = await waitForAssistantUnread(false, 30_000)");
  const sendIndex = journey.indexOf("const tracking = await messageReceiveTracker.captureBeforeSend(async () => {");
  const positiveIndex = journey.indexOf("const unread = await waitForAssistantUnread(true)");
  assert.ok(baselineIndex >= 0, "pre-send unread-none baseline is required");
  assert.ok(sendIndex > baselineIndex, "send must happen after a verified no-unread baseline");
  assert.ok(positiveIndex > sendIndex, "positive unread must be observed only after the probe send");
  assert.match(journey, /record\("unread-baseline-cleared", unreadBaseline\)/u);
  assert.match(journey, /record\("unread-transition-observed", unread\)/u);
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
  assert.match(journey, /item\?\.role === "article" && String\(item\?\.agentId \|\| ""\)\.startsWith\(MESSAGE_ROW_PREFIX\)/u);
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
