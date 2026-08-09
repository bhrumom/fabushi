import assert from 'node:assert/strict';
import test from 'node:test';
import {
  assistantDeltaText,
  buildContinuationPrompt,
  parseTaskReport,
  taskRuntimeId,
} from '../runtime/task-protocol.ts';

test('assistantDeltaText ignores sent prompt and keeps new assistant output', () => {
  const result = assistantDeltaText(
    ['hello user prompt', 'MAHAYANA_TASK_REPORT_V1_BEGIN', 'finished work'],
    ['old reply'],
    'hello user prompt',
  );
  assert.equal(result.includes('hello user prompt'), false);
  assert.equal(result.includes('finished work'), true);
});

test('task report parser reads continuation protocol', () => {
  const report = parseTaskReport('x\nMAHAYANA_TASK_REPORT_V1_BEGIN\n{"protocol":"mahayana.task-report.v1","status":"incomplete","remaining":["a"],"blockers":[],"next_task":"continue a"}\nMAHAYANA_TASK_REPORT_V1_END');
  assert.equal(report?.status, 'incomplete');
  assert.equal(report?.next_task, 'continue a');
});

test('runtime id changes when revision changes', () => {
  assert.notEqual(
    taskRuntimeId({ id: 'x', prompt: 'a', revision: 1 }),
    taskRuntimeId({ id: 'x', prompt: 'a', revision: 2 }),
  );
});

test('continuation prompt contains next work item', () => {
  const prompt = buildContinuationPrompt(
    { id: 'x', prompt: 'do it' },
    { protocol: 'mahayana.task-report.v1', status: 'incomplete', remaining: ['b'], blockers: [], next_task: 'do b' },
    2,
  );
  assert.equal(prompt.includes('do b'), true);
});
