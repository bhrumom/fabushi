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
  const inboxPath = path.join(directory, 'actions-inbox.json');
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
      maxTaskContinuations: 0,
    }],
  };
  const env = {
    ...process.env,
    CHATGPT_AUTO_CONFIRM_QUEUE_STATE: statePath,
    CHATGPT_AUTO_CONFIRM_TASK_INBOX_FILE: inboxPath,
  };
  try {
    writeFileSync(statePath, JSON.stringify({ automationTasks: [] }));
    writeFileSync(inboxPath, JSON.stringify(inbox));
    execFileSync(process.execPath, [script], { env });
    execFileSync(process.execPath, [script], { env });
    const state = JSON.parse(readFileSync(statePath, 'utf8'));
    assert.equal(state.automationTasks.length, 1);
    assert.equal(state.automationTasks[0].id, 'marketplace-parallel');
    assert.equal(state.automationTasks[0].maxTaskContinuations, 0);
    assert.equal(state.queueMaxConcurrent, 2);
    assert.equal(state.queueReviewGate, false);
    assert.equal(state.queueEnabled, true);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('Actions inbox refreshes and requeues an existing failed task', () => {
  const directory = mkdtempSync(path.join(os.tmpdir(), 'chatgpt-actions-inbox-retry-'));
  const statePath = path.join(directory, 'state.json');
  const inboxPath = path.join(directory, 'actions-inbox.json');
  const script = fileURLToPath(
    new URL('../scripts/import-actions-task-inbox.mjs', import.meta.url));
  const env = {
    ...process.env,
    CHATGPT_AUTO_CONFIRM_QUEUE_STATE: statePath,
    CHATGPT_AUTO_CONFIRM_TASK_INBOX_FILE: inboxPath,
  };
  try {
    writeFileSync(statePath, JSON.stringify({
      automationTasks: [{
        id: 'marketplace-parallel',
        title: 'Old title',
        prompt: 'Old prompt',
        status: 'failed',
        attempts: 3,
        workerPid: 123,
        workerTargetId: 'stale-target',
        conversationId: 'stale-conversation',
        lastError: 'new_chat_prepare_failed',
      }],
    }));
    writeFileSync(inboxPath, JSON.stringify({
      maxConcurrent: 2,
      tasks: [{
        id: 'marketplace-parallel',
        title: 'Updated title',
        prompt: 'Updated prompt',
        maxRuntimeRetries: 4,
      }],
    }));
    const output = execFileSync(process.execPath, [script], { env, encoding: 'utf8' });
    const state = JSON.parse(readFileSync(statePath, 'utf8'));
    const task = state.automationTasks[0];
    assert.match(output, /requeued 1 failed task/);
    assert.equal(state.automationTasks.length, 1);
    assert.equal(task.title, 'Updated title');
    assert.equal(task.prompt, 'Updated prompt');
    assert.equal(task.maxRuntimeRetries, 4);
    assert.equal(task.status, 'queued');
    assert.equal(task.attempts, 0);
    assert.equal(task.workerPid, null);
    assert.equal(task.workerTargetId, null);
    assert.equal(task.conversationId, null);
    assert.equal(task.lastError, null);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('authoritative Actions inbox removes stale tasks from restored initial state', () => {
  const directory = mkdtempSync(path.join(os.tmpdir(), 'chatgpt-actions-inbox-authoritative-'));
  const statePath = path.join(directory, 'state.json');
  const inboxPath = path.join(directory, 'actions-inbox.json');
  const script = fileURLToPath(
    new URL('../scripts/import-actions-task-inbox.mjs', import.meta.url));
  const env = {
    ...process.env,
    CHATGPT_AUTO_CONFIRM_QUEUE_STATE: statePath,
    CHATGPT_AUTO_CONFIRM_TASK_INBOX_FILE: inboxPath,
  };
  try {
    writeFileSync(statePath, JSON.stringify({
      automationTasks: [
        { id: 'autonomous-pr-manager-001', status: 'queued', attempts: 1519 },
        { id: 'marketplace-current', status: 'failed', attempts: 4 },
      ],
    }));
    writeFileSync(inboxPath, JSON.stringify({
      authoritative: true,
      tasks: [{
        id: 'marketplace-current',
        title: 'Current marketplace task',
        prompt: 'Continue current work',
      }],
    }));
    const output = execFileSync(process.execPath, [script], { env, encoding: 'utf8' });
    const state = JSON.parse(readFileSync(statePath, 'utf8'));
    assert.match(output, /Removed stale tasks: autonomous-pr-manager-001/);
    assert.deepEqual(state.automationTasks.map(task => task.id), ['marketplace-current']);
    assert.equal(state.automationTasks[0].status, 'queued');
    assert.equal(state.automationTasks[0].attempts, 0);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
