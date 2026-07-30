import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const scriptPath = new URL('../scripts/prepare-action-state.mjs', import.meta.url);

test('hosted runner rotation preserves the conversation needed for serial continuation', () => {
  const directory = mkdtempSync(join(tmpdir(), 'chatgpt-action-state-'));
  const statePath = join(directory, 'queue-state.json');
  writeFileSync(statePath, JSON.stringify({
    enabled: true,
    automationTasks: [{
      id: 'continuation-task',
      status: 'running',
      attempts: 7,
      continuationDepth: 2,
      conversationId: 'conversation-to-continue',
      chatURL: 'https://chatgpt.com/c/conversation-to-continue',
      workerPid: 123,
      workerPort: 9324,
      workerTargetId: 'old-target',
    }],
  }));

  const result = spawnSync(process.execPath, [scriptPath], {
    env: {
      ...process.env,
      CHATGPT_AUTO_CONFIRM_QUEUE_STATE: statePath,
    },
    encoding: 'utf8',
  });
  assert.equal(result.status, 0, result.stderr);

  const prepared = JSON.parse(readFileSync(statePath, 'utf8'));
  const [task] = prepared.automationTasks;
  assert.equal(task.status, 'queued');
  assert.equal(task.conversationId, 'conversation-to-continue');
  assert.equal(task.chatURL, 'https://chatgpt.com/c/conversation-to-continue');
  assert.equal(task.workerPid, null);
  assert.equal(task.workerPort, null);
  assert.equal(task.workerTargetId, null);
  assert.equal(task.lastError, 'github_actions_runner_continuation');
});
