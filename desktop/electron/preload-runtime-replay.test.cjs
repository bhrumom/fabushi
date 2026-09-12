const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const ASSISTANT_CONVERSATION_ID = 'mahayana-ai:agent:assistant';

function loadPreload() {
  const channels = new Map();
  const exposed = {};
  const ipcRenderer = {
    on(channel, listener) {
      const listeners = channels.get(channel) ?? new Set();
      listeners.add(listener);
      channels.set(channel, listeners);
    },
    off(channel, listener) { channels.get(channel)?.delete(listener); },
    invoke: async () => ({ ok: true, value: null }),
  };
  const contextBridge = { exposeInMainWorld(name, value) { exposed[name] = value; } };
  const source = fs.readFileSync(path.join(__dirname, 'preload.cjs'), 'utf8');
  vm.runInNewContext(source, {
    require(id) {
      if (id === 'electron') return { contextBridge, ipcRenderer };
      throw new Error(`unexpected require: ${id}`);
    },
    console,
    Object,
    Set,
    Map,
    Array,
  }, { filename: 'preload.cjs' });
  return {
    exposed,
    emit(channel, payload) {
      for (const listener of channels.get(channel) ?? []) listener({}, payload);
    },
  };
}

test('Mahayana preload replays bootstrap projections to every renderer subscriber in the account session', () => {
  const bridge = loadPreload();
  const channel = 'fabushi-edge:mahayana-host:event:runtime-event';
  bridge.emit(channel, { type: 'conversation.listed', conversations: [{ id: 'c1' }] });
  bridge.emit(channel, { type: 'bot.listed', bots: [{ id: 'b1' }] });
  bridge.emit(channel, { type: 'group.listed', groups: [{ id: 'g1' }] });

  const received = [];
  const unsubscribe = bridge.exposed.mahayana.subscribe((event) => received.push(event.type));
  assert.deepEqual(received, ['conversation.listed', 'bot.listed', 'group.listed']);

  bridge.emit(channel, { type: 'chat.delta', operationId: 'op', delta: 'x' });
  assert.equal(received.at(-1), 'chat.delta');
  unsubscribe();

  const next = [];
  bridge.exposed.mahayana.subscribe((event) => next.push(event.type));
  assert.deepEqual(next, ['conversation.listed', 'bot.listed', 'group.listed']);
  assert.equal(next.includes('chat.delta'), false);
});

test('Mahayana preload preserves the newest bootstrap projection across multiple active-subscriber handoffs', () => {
  const bridge = loadPreload();
  const channel = 'fabushi-edge:mahayana-host:event:runtime-event';
  const first = [];
  const unsubscribeFirst = bridge.exposed.mahayana.subscribe((event) => first.push(event.type));
  bridge.emit(channel, { type: 'conversation.listed', conversations: [{ id: 'c1' }] });
  assert.deepEqual(first, ['conversation.listed']);

  const second = [];
  bridge.exposed.mahayana.subscribe((event) => second.push(event.type));
  assert.deepEqual(second, ['conversation.listed']);
  unsubscribeFirst();

  const third = [];
  bridge.exposed.mahayana.subscribe((event) => third.push(event.type));
  assert.deepEqual(third, ['conversation.listed']);
});

test('Mahayana preload clears replay at authentication account boundaries', async () => {
  const bridge = loadPreload();
  const channel = 'fabushi-edge:mahayana-host:event:runtime-event';
  bridge.emit(channel, { type: 'conversation.listed', conversations: [{ id: 'old-account' }] });
  await bridge.exposed.mahayana.invoke('feature.auth.browserStart');

  const afterLoginStart = [];
  bridge.exposed.mahayana.subscribe((event) => afterLoginStart.push(event));
  assert.deepEqual(afterLoginStart, []);

  bridge.emit(channel, { type: 'conversation.listed', conversations: [{ id: 'new-account' }] });
  await bridge.exposed.mahayana.invoke('feature.auth.logout');
  const afterLogout = [];
  bridge.exposed.mahayana.subscribe((event) => afterLogout.push(event));
  assert.deepEqual(afterLogout, []);
});

test('Mahayana preload keeps only the newest replayable projection per type', () => {
  const bridge = loadPreload();
  const channel = 'fabushi-edge:mahayana-host:event:runtime-event';
  bridge.emit(channel, { type: 'conversation.listed', conversations: [{ id: 'old' }] });
  bridge.emit(channel, { type: 'conversation.listed', conversations: [{ id: 'new' }] });
  const received = [];
  bridge.exposed.mahayana.subscribe((event) => received.push(event));
  assert.equal(received.length, 1);
  assert.equal(received[0].conversations[0].id, 'new');
});

test('Mahayana preload deterministically repairs a missing canonical assistant conversation projection', () => {
  const bridge = loadPreload();
  const channel = 'fabushi-edge:mahayana-host:event:runtime-event';
  bridge.emit(channel, {
    type: 'conversation.listed',
    timestamp: '2026-09-12T04:51:52.000Z',
    conversations: [
      { id: 'selfhosted-shadow-a', title: 'FCM channel A', kind: 'channel', pinned: false, unreadCount: 0, updatedAtMs: 1 },
      { id: 'selfhosted-shadow-b', title: 'FCM channel B', kind: 'channel', pinned: false, unreadCount: 0, updatedAtMs: 2 },
    ],
  });
  const received = [];
  bridge.exposed.mahayana.subscribe((event) => received.push(event));
  assert.equal(received.length, 1);
  const assistant = received[0].conversations.filter((conversation) => conversation.id === ASSISTANT_CONVERSATION_ID);
  assert.equal(assistant.length, 1);
  assert.deepEqual(JSON.parse(JSON.stringify(assistant[0])), {
    id: ASSISTANT_CONVERSATION_ID,
    title: '大乘助手',
    kind: 'agent',
    pinned: false,
    unreadCount: 0,
    updatedAtMs: Date.parse('2026-09-12T04:51:52.000Z'),
  });
});

test('Mahayana preload normalizes a canonical assistant miniapp projection before Messenger filtering can erase it', () => {
  const bridge = loadPreload();
  const channel = 'fabushi-edge:mahayana-host:event:runtime-event';
  const authoritative = {
    id: ASSISTANT_CONVERSATION_ID,
    title: '大乘助手',
    kind: 'miniapp',
    pinned: true,
    unreadCount: 4,
    updatedAtMs: 987654,
  };
  bridge.emit(channel, { type: 'conversation.listed', conversations: [{ id: 'other' }, authoritative] });
  const received = [];
  bridge.exposed.mahayana.subscribe((event) => received.push(event));
  const assistants = received[0].conversations.filter((conversation) => conversation.id === ASSISTANT_CONVERSATION_ID);
  assert.equal(assistants.length, 1);
  assert.deepEqual(JSON.parse(JSON.stringify(assistants[0])), {
    ...authoritative,
    kind: 'agent',
  });
});

test('Mahayana preload never duplicates or rewrites an already semantic assistant projection', () => {
  const bridge = loadPreload();
  const channel = 'fabushi-edge:mahayana-host:event:runtime-event';
  const authoritative = {
    id: ASSISTANT_CONVERSATION_ID,
    title: '大乘助手',
    kind: 'agent',
    pinned: true,
    unreadCount: 4,
    updatedAtMs: 987654,
  };
  bridge.emit(channel, { type: 'conversation.listed', conversations: [{ id: 'other' }, authoritative] });
  const received = [];
  bridge.exposed.mahayana.subscribe((event) => received.push(event));
  const assistants = received[0].conversations.filter((conversation) => conversation.id === ASSISTANT_CONVERSATION_ID);
  assert.equal(assistants.length, 1);
  assert.deepEqual(JSON.parse(JSON.stringify(assistants[0])), authoritative);
});