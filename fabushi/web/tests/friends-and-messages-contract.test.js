import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const handler = readFileSync(join(root, 'src/handlers/friends.js'), 'utf8');
const router = readFileSync(join(root, 'src/router.js'), 'utf8');
const communityRouter = readFileSync(join(root, 'src/routes/community-routes.js'), 'utf8');
const webRuntimeBootstrap = readFileSync(
  join(root, 'mahayana-wasm/bootstrap.js'),
  'utf8',
);
const migration = readFileSync(
  join(root, 'migrations/20260713_friends_and_direct_messages.sql'),
  'utf8',
);
const messageSemanticsMigration = readFileSync(
  join(root, 'migrations/20261005_direct_message_semantics.sql'),
  'utf8',
);
const attachmentHandler = readFileSync(
  join(root, 'src/handlers/message-attachments.js'),
  'utf8',
);

test('friend and direct-message storage has durable identities and indexes', () => {
  assert.match(migration, /CREATE TABLE IF NOT EXISTS friend_requests/i);
  assert.match(migration, /sender_user_id INTEGER NOT NULL/i);
  assert.match(migration, /recipient_user_id INTEGER NOT NULL/i);
  assert.match(migration, /CHECK \(status IN \('pending', 'accepted', 'rejected', 'cancelled'\)\)/i);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS direct_messages/i);
  assert.match(migration, /idx_direct_messages_client_request/i);
  assert.match(messageSemanticsMigration, /reply_to_message_id/i);
  assert.match(messageSemanticsMigration, /direct_message_attachments/i);
  assert.match(messageSemanticsMigration, /direct_message_reactions/i);
});

test('friend handlers require stable authenticated account identities', () => {
  assert.match(handler, /requireAuthIdentity\(request, env, db\)/);
  assert.match(handler, /Number\.isFinite\(auth\.userId\)/);
  assert.match(handler, /只能给已添加的好友发送消息/);
  assert.match(handler, /MAX_MESSAGE_LENGTH = 4000/);
  assert.match(handler, /clientRequestId\.length > 200/);
  assert.match(handler, /directMessageSelectColumns/);
  assert.match(handler, /deduplicated \? 200 : 201/);
  assert.match(handler, /resolveMessageAttachments/);
  assert.match(handler, /requireConversationMessage/);
  assert.match(handler, /replyToMessageId/);
  assert.match(handler, /handleSetDirectMessageReaction/);
  assert.match(handler, /消息请求编号已绑定到不同内容/);
  assert.match(attachmentHandler, /MAX_MESSAGE_ATTACHMENT_BYTES = 25 \* 1024 \* 1024/);
  assert.match(attachmentHandler, /message-attachments\//);
  assert.match(attachmentHandler, /JOIN direct_messages m ON m.id = a.message_id/);
});

test('router exposes the endpoints consumed by canonical apps and the CLI', () => {
  for (const path of [
    '/api/social/users/search',
    '/api/social/friends',
    '/api/social/friend-requests',
    '/api/social/friend-requests/incoming',
    '/api/social/messages',
    '/api/social/message-attachments',
  ]) {
    assert.ok(communityRouter.includes(path), `missing ${path}`);
  }
  assert.match(communityRouter, /friend-requests\\\/\(\\d\+\)\\\/accept/);
  assert.match(communityRouter, /messages\\\/\(\\d\+\)\\\/reactions/);
  assert.match(communityRouter, /messageAttachmentMatch/);
});

test('browser embeds the WASM runtime without a cloud Agent gateway', () => {
  assert.ok(!router.includes('/api/mahayana/execute'));
  assert.match(webRuntimeBootstrap, /new Worker/);
  assert.match(webRuntimeBootstrap, /createRuntime/);
  assert.match(webRuntimeBootstrap, /receive/);
  assert.match(
    readFileSync(join(root, 'mahayana-wasm/worker.js'), 'utf8'),
    /getDirectoryHandle/,
  );
});
