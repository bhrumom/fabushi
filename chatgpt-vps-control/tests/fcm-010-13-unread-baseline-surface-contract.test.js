import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const journey = await readFile(new URL("../scripts/fcm-010-13-macos-live-journey.mjs", import.meta.url), "utf8");

test("send verifies exact unread-none on the chat-list surface before opening the assistant", () => {
  const sendStart = journey.indexOf('await category("send", async () => {');
  const listIndex = journey.indexOf('await navigateSection("聊天");', sendStart);
  const baselineIndex = journey.indexOf("const unreadBaseline = await waitForAssistantUnread(false, 30_000);", sendStart);
  const openIndex = journey.indexOf("await openAssistantConversation();", sendStart);
  const sendIndex = journey.indexOf("const tracking = await messageReceiveTracker.captureBeforeSend(async () => {", sendStart);

  assert.ok(sendStart >= 0, "send category must exist");
  assert.ok(listIndex > sendStart, "send must first return to the chat-list surface");
  assert.ok(baselineIndex > listIndex, "unread-none baseline must be verified on the chat-list surface");
  assert.ok(openIndex > baselineIndex, "assistant conversation must open only after unread-none is verified");
  assert.ok(sendIndex > openIndex, "probe send must happen only after the assistant conversation is open");

  assert.match(journey, /find\(\{ agentId: ASSISTANT_UNREAD_AGENT_ID, name: marker, limit: 1 \}\)/u);
  assert.match(journey, /record\("unread-baseline-cleared", unreadBaseline\)/u);
  assert.match(journey, /record\("unread-transition-observed", unread\)/u);
});
