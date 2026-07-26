import assert from 'node:assert/strict';
import test from 'node:test';
import { verifyEvidence } from '../scripts/parallel-queue-probe.mjs';

const passingEvidence = {
  status: 'passed',
  executionMode: 'single-authenticated-process-multi-hidden-window-parallel',
  requestedMaxConcurrent: 2,
  effectiveMaxConcurrent: 2,
  activeWorkers: [
    { taskId: 'a', targetId: 'target-a', visibilityVerified: true },
    { taskId: 'b', targetId: 'target-b', visibilityVerified: true },
  ],
  criteria: [
    'task B was enqueued after task A had already started',
    'both tasks were running in the same observation',
  ],
};

test('accepts real dynamic overlap with isolated hidden targets', () => {
  assert.equal(verifyEvidence(passingEvidence).ok, true);
});

test('rejects a configured concurrency value without observed overlap', () => {
  const evidence = structuredClone(passingEvidence);
  evidence.activeWorkers = [evidence.activeWorkers[0]];
  evidence.criteria = [];
  const result = verifyEvidence(evidence);
  assert.equal(result.ok, false);
  assert.ok(result.failures.includes('twoActiveWorkers'));
  assert.ok(result.failures.includes('dynamicEnqueue'));
  assert.ok(result.failures.includes('observedOverlap'));
});

test('rejects workers that share a target or become visible', () => {
  const evidence = structuredClone(passingEvidence);
  evidence.activeWorkers[1].targetId = 'target-a';
  evidence.activeWorkers[1].visibilityVerified = false;
  const result = verifyEvidence(evidence);
  assert.equal(result.ok, false);
  assert.ok(result.failures.includes('isolatedTargets'));
  assert.ok(result.failures.includes('hiddenTargets'));
});
