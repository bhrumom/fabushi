import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

test('Actions inbox appends a dynamic task once and enables parallel scheduling', () => {
  const directory = mkdtempSync(path.join(os.tmpdir(), 'chatgpt-actions-inbox-'));
  const statePath = path.join(directory, 'state.json');
  const script = fileURLToPath(
    new URL('../scripts/import-actions-task-inbox.mjs', import.meta.url));
  const inbox = {
    maxConcurrent: 2,
    reviewGate: false,
    tasks: [{
      id: 'marketplace-parallel',
      title: 'Marketplace',
      prompt: 'Finish the marketplace',
      resourceLocks: ['worktree:marketplace'],
    }],
  };
  const env = {
    ...process.env,
    CHATGPT_AUTO_CONFIRM_QUEUE_STATE: statePath,
    CHATGPT_AUTO_CONFIRM_TASK_INBOX_B64:
      Buffer.from(JSON.stringify(inbox)).toString('base64'),
  };
  try {
    writeFileSync(statePath, JSON.stringify({ automationTasks: [] }));
    execFileSync(process.execPath, [script], { env });
    execFileSync(process.execPath, [script], { env });
    const state = JSON.parse(readFileSync(statePath, 'utf8'));
    assert.equal(state.automationTasks.length, 1);
    assert.equal(state.automationTasks[0].id, 'marketplace-parallel');
    assert.equal(state.queueMaxConcurrent, 2);
    assert.equal(state.queueReviewGate, false);
    assert.equal(state.queueEnabled, true);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
