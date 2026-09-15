'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const test = require('node:test');
const ts = require('typescript');

function loadTypeScriptModule(filePath) {
  const source = fs.readFileSync(filePath, 'utf8');
  const compiled = ts.transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2022,
      esModuleInterop: true,
    },
    fileName: filePath,
  }).outputText;
  const loaded = new Module(filePath, module);
  loaded.filename = filePath;
  loaded.paths = Module._nodeModulePaths(path.dirname(filePath));
  loaded._compile(compiled, filePath);
  return loaded.exports;
}

const transcriptPath = path.resolve(__dirname, '../../frontend/apps/web/src/lib/mahayana-host/turn-transcript.ts');
const {
  MAHAYANA_TURN_PROTOCOL_VERSION,
  legacyRuntimeEventToTurnEvent,
  reduceAssistantTurn,
} = loadTypeScriptModule(transcriptPath);

function turnEvent(seq, type, payload) {
  return {
    protocolVersion: MAHAYANA_TURN_PROTOCOL_VERSION,
    sessionId: 'session-1',
    conversationId: 'conversation-1',
    turnId: 'turn-1',
    operationId: 'operation-1',
    seq,
    replayEpoch: 0,
    timestampMs: 1_000 + seq,
    type,
    payload,
  };
}

test('one Mahayana operation stays one assistant turn across reasoning, text and tool lifecycle', () => {
  const events = [
    turnEvent(1, 'message.start', { model: 'gpt-5.6-sol', provider: 'fabushi' }),
    turnEvent(2, 'reasoning.delta', { text: '正在检查仓库…' }),
    turnEvent(3, 'message.delta', { text: '我先检查消息模型。' }),
    turnEvent(4, 'tool.start', { toolId: 'tool-1', name: 'github.search', title: 'Search repository', arguments: { q: 'chat.delta' } }),
    turnEvent(5, 'tool.complete', { toolId: 'tool-1', result: { matches: 3 } }),
    turnEvent(6, 'message.delta', { text: '根因是 transcript 被拆成两套状态。' }),
    turnEvent(7, 'message.complete', { text: '根因是 transcript 被拆成两套状态。', status: 'completed' }),
  ];

  const turn = events.reduce((current, event) => reduceAssistantTurn(current, event), undefined);
  assert.equal(turn.id, 'turn:session-1:turn-1');
  assert.equal(turn.operationId, 'operation-1');
  assert.equal(turn.status, 'completed');
  assert.deepEqual(turn.parts.map((part) => part.kind), ['reasoning', 'text', 'tool', 'text']);

  const toolParts = turn.parts.filter((part) => part.kind === 'tool');
  assert.equal(toolParts.length, 1, 'tool.start/tool.complete must update one stable part');
  assert.equal(toolParts[0].toolId, 'tool-1');
  assert.equal(toolParts[0].status, 'completed');
  assert.deepEqual(toolParts[0].result, { matches: 3 });

  const textParts = turn.parts.filter((part) => part.kind === 'text');
  assert.deepEqual(textParts.map((part) => part.text), [
    '我先检查消息模型。',
    '根因是 transcript 被拆成两套状态。',
  ]);
  assert.ok(textParts.every((part) => part.sealed));
});

test('replayed or out-of-order events cannot duplicate transcript parts', () => {
  const first = reduceAssistantTurn(undefined, turnEvent(1, 'message.delta', { text: 'A' }));
  const second = reduceAssistantTurn(first, turnEvent(2, 'message.delta', { text: 'B' }));
  const replayed = reduceAssistantTurn(second, turnEvent(2, 'message.delta', { text: 'B' }));
  assert.equal(replayed.parts.length, 1);
  assert.equal(replayed.parts[0].text, 'AB');
  assert.equal(replayed.lastSeq, 2);
});

test('legacy RuntimeEvent compatibility maps chat and agent steps but drops model routing from transcript', () => {
  const coordinates = { sessionId: 'legacy-session', conversationId: 'conversation-1', seq: 10, timestampMs: 2_000 };
  const modelRoute = legacyRuntimeEventToTurnEvent({
    type: 'model.routed', timestamp: new Date(2_000).toISOString(), operationId: 'operation-1', provider: 'fabushi', model: 'auto', mode: 'agent',
  }, coordinates);
  assert.equal(modelRoute, null, 'model routing is inspector metadata, not a chat card');

  const delta = legacyRuntimeEventToTurnEvent({
    type: 'chat.delta', timestamp: new Date(2_001).toISOString(), operationId: 'operation-1', delta: 'hello',
  }, { ...coordinates, seq: 11 });
  assert.equal(delta.type, 'message.delta');
  assert.equal(delta.payload.text, 'hello');

  const start = legacyRuntimeEventToTurnEvent({
    type: 'agent.step', timestamp: new Date(2_002).toISOString(), operationId: 'operation-1', stepId: 'step-1', kind: 'tool', title: 'Read file', status: 'running',
  }, { ...coordinates, seq: 12 });
  const complete = legacyRuntimeEventToTurnEvent({
    type: 'agent.step', timestamp: new Date(2_003).toISOString(), operationId: 'operation-1', stepId: 'step-1', kind: 'tool', title: 'Read file', detail: 'done', status: 'completed',
  }, { ...coordinates, seq: 13 });
  assert.equal(start.type, 'tool.start');
  assert.equal(complete.type, 'tool.complete');
  assert.equal(start.payload.toolId, complete.payload.toolId);
});
