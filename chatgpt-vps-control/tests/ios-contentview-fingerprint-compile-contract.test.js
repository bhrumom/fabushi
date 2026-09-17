import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../../", import.meta.url);
const read = (path) => readFile(new URL(path, root), "utf8");

test("iOS app-agent fingerprint stays explicitly typed and order-stable", async () => {
  const source = await read("mobile/ios/Fabushi/ContentView.swift");
  const start = source.indexOf("    private var appAgentSurfaceFingerprint: String {");
  const end = source.indexOf("\n    @MainActor", start);
  assert.ok(start >= 0 && end > start, "missing appAgentSurfaceFingerprint body");
  const fingerprint = source.slice(start, end);

  const expectedValues = [
    'destinationRevision',
    'String(isSearching)',
    'homeQuery',
    'String(profileMenuPresented)',
    'String(composeMenuPresented)',
    'composeKind?.rawValue ?? ""',
    'composeName',
    'composeDescription',
    'composeParticipantIds.sorted().joined(separator: ",")',
    'activeSection?.rawValue ?? ""',
    'String(contactGroupsPresented)',
    'String(folderEditorPresented)',
    'folderTitle',
    'folderConversationIds.sorted().joined(separator: ",")',
    'String(folderIncludeGroups)',
    'String(folderIncludeChannels)',
    'String(agentChatPresented)',
    'model.chatDraft',
    'String(model.chatBusy)',
    'agentRevision',
    'selectedConversation?.id ?? ""',
    'messageDraft',
    'replyTarget?.id ?? ""',
    'editingMessage?.id ?? ""',
    'forwardMessage?.id ?? ""',
    'mediaViewerMessage?.id ?? ""',
    'String(conversationInfoPresented)',
    'String(chatSearchPresented)',
    'chatSearchQuery',
    'String(attachmentPickerPresented)',
    'String(locationSharePresented)',
    'String(contactSharePresented)',
    'String(pollComposerPresented)',
    'pollQuestion',
    'pollOption1',
    'pollOption2',
    'pollOption3',
    'String(voiceRecorder.isRecording)',
    'model.query',
    'model.message',
    'String(model.loading)',
    'model.installingPluginId ?? ""',
    'model.permissionRequest?.pluginId ?? ""',
    'openedMiniApp?.pluginId ?? ""',
    'pluginRevision',
    'conversationRevision',
    'contactRevision',
    'folderRevision',
    'selectedMessagesRevision',
    'String(messaging.loading)',
    'messaging.errorMessage ?? ""',
  ];

  const chunks = [...fingerprint.matchAll(/let fingerprintChunk\d+: \[String\] = \[\n([\s\S]*?)\n\s*\]/gu)];
  assert.equal(chunks.length, 3, "fingerprint must stay split into three explicitly typed String chunks");
  const actualValues = chunks.flatMap((match) => match[1]
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => line.endsWith(",") ? line.slice(0, -1) : line));
  assert.equal(actualValues.length, 51, "fingerprint must contain exactly 51 values");
  assert.deepEqual(actualValues, expectedValues, "all 51 fingerprint values and their order must remain identical");
  assert.match(fingerprint, /var fingerprintParts: \[String\] = \[\]/u);
  assert.match(fingerprint, /fingerprintParts\.append\(contentsOf: fingerprintChunk1\)[\s\S]*fingerprintParts\.append\(contentsOf: fingerprintChunk2\)[\s\S]*fingerprintParts\.append\(contentsOf: fingerprintChunk3\)/u);
  assert.ok(fingerprint.includes('return fingerprintParts.joined(separator: "|")'));
  assert.doesNotMatch(fingerprint, /return\s+\[\s*destinationRevision/u, "do not restore the monolithic literal");
});
