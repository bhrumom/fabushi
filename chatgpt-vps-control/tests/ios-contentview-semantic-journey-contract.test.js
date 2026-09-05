import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../../", import.meta.url);
const read = (path) => readFile(new URL(path, root), "utf8");

test("iOS ContentView exposes the existing messaging journey through the native semantic surface", async () => {
  const source = await read("mobile/ios/Fabushi/ContentView.swift");

  for (const required of [
    'publish("home")',
    'publish("chat")',
    'publish("agent-chat")',
    'publish("profile-menu")',
    'publish("compose-menu")',
    'publish("forward-message")',
    'publish("poll-compose")',
    'publish("contact-share")',
    'publish("location-share")',
    'publish("media-viewer")',
    '"home-sync"',
    '"chat-sync"',
    '"conversation-pin-',
    '"conversation-mute-',
    '"conversation-unread-',
    '"conversation-archive-',
    '"chat-draft"',
    '"chat-send"',
    '"message-reply-',
    '"message-forward-',
    '"message-react-',
    '"message-edit-',
    '"message-pin-',
    '"message-delete-',
    '"chat-attach-file"',
    '"chat-attach-location"',
    '"chat-attach-contact"',
    '"chat-attach-poll"',
    '"mahayana-draft"',
    '"mahayana-send"',
    '"mobile-logout"',
    '"compose-participant-',
    '"compose-create"',
    '"section-unavailable"',
    'allowed: ["setValue"]',
    'allowed: ["invoke"]',
  ]) {
    assert.ok(source.includes(required), `missing native iOS messaging semantic invariant: ${required}`);
  }

  for (const existingBusinessCall of [
    "messaging.refresh()",
    "messaging.createDirect(contact: contact)",
    "messaging.setPinned(",
    "messaging.setMuted(",
    "messaging.setMarkedUnread(",
    "messaging.setArchived(",
    "messaging.sendText(",
    "messaging.editText(",
    "messaging.deleteMessage(",
    "messaging.forwardMessage(",
    "messaging.setReaction(",
    "messaging.sendContact(",
    "messaging.sendLocation(",
    "messaging.sendPoll(",
    "messaging.votePoll(",
    "model.sendChat()",
    "model.stopChat()",
    "model.logout()",
  ]) {
    assert.ok(source.includes(existingBusinessCall), `semantic action must reuse real business call: ${existingBusinessCall}`);
  }

  assert.match(source, /case \.calls, \.payments, \.settings:\s*add\("section-unavailable"/u,
    "not-yet-native settings/calls/payments must stay truthfully unavailable instead of being fabricated");
  assert.doesNotMatch(source, /fabushi-device-agent|Process\(|NSTask|\/bin\/sh/u);
  assert.doesNotMatch(source, /message\.text\s*\)\s*,\s*role:\s*"article"/u,
    "message body text must not be copied into semantic element names");
});
