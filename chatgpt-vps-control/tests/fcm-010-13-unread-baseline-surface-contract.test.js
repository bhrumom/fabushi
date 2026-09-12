import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const journey = await readFile(new URL("../scripts/fcm-010-13-macos-live-journey.mjs", import.meta.url), "utf8");

test("send leaves the active assistant via a known peer before probing exact unread-none", () => {
  const conversationsStart = journey.indexOf('await category("conversations", async () => {');
  const searchStart = journey.indexOf('await category("search", async () => {', conversationsStart);
  const conversationsSlice = journey.slice(conversationsStart, searchStart);
  const sendStart = journey.indexOf('await category("send", async () => {');
  const channelsIndex = journey.indexOf('await navigateSection("频道");', sendStart);
  const nonAssistantPeerIndex = journey.indexOf("await openPeer(channelAId);", channelsIndex);
  const listIndex = journey.indexOf('await navigateSection("聊天");', nonAssistantPeerIndex);
  const listStateRecordIndex = journey.indexOf('record("unread-baseline-list-state-established", { viaAgentId: channelAId });', listIndex);
  const baselineIndex = journey.indexOf("const unreadBaseline = await waitForAssistantUnread(false, 30_000);", listStateRecordIndex);
  const openIndex = journey.indexOf("await openAssistantConversation();", baselineIndex);
  const sendIndex = journey.indexOf("const tracking = await messageReceiveTracker.captureBeforeSend(async () => {", openIndex);

  assert.ok(conversationsStart >= 0, "conversations category must exist");
  assert.match(conversationsSlice, /await openAssistantConversation\(\);\s*\n\s*\}\);$/u,
    "conversations must deliberately leave the assistant selected before search/send");
  assert.ok(sendStart >= 0, "send category must exist");
  assert.ok(channelsIndex > sendStart, "send must leave the active assistant by navigating to Channels");
  assert.ok(nonAssistantPeerIndex > channelsIndex, "send must select the known non-assistant channel peer");
  assert.ok(listIndex > nonAssistantPeerIndex, "send must return to Chats only after a non-assistant peer is active");
  assert.ok(listStateRecordIndex > listIndex, "the established list-state transition must be recorded");
  assert.ok(baselineIndex > listStateRecordIndex, "unread-none baseline must be verified only after the list state is established");
  assert.ok(openIndex > baselineIndex, "assistant conversation must reopen only after unread-none is verified");
  assert.ok(sendIndex > openIndex, "probe send must happen only after the assistant conversation is reopened");

  assert.match(journey, /find\(\{ agentId: ASSISTANT_UNREAD_AGENT_ID, name: marker, limit: 1 \}\)/u);
  assert.match(journey, /record\("unread-baseline-cleared", unreadBaseline\)/u);
  assert.match(journey, /record\("unread-transition-observed", unread\)/u);
});
