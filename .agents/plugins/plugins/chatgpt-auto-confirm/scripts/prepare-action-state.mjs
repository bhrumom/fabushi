import { readFileSync, writeFileSync } from 'node:fs';

const statePath = process.env.CHATGPT_AUTO_CONFIRM_QUEUE_STATE;
if (!statePath) throw new Error('CHATGPT_AUTO_CONFIRM_QUEUE_STATE is required');
const state = JSON.parse(readFileSync(statePath, 'utf8'));
state.enabled = true;
state.approveAll = true;
state.watcherPid = null;
state.backgroundTargets = {};
state.backgroundAppPort = null;
state.backgroundChatTargetId = null;
state.backgroundConversationId = null;
state.queueEnabled = true;
state.queuePaused = false;
state.queueWatcherPid = null;
state.queueWorkerPort = null;
state.queueWorkerTargetId = null;
state.queueWorkerProfilePath = null;
state.queueWorkerMode = null;
for (const task of state.automationTasks || []) {
  task.workerPid = null;
  task.workerPort = null;
  task.workerTargetId = null;
  task.workerStatePath = null;
  task.workerProfilePath = null;
  task.resultPath = null;
  if (task.status === 'running') {
    task.status = 'queued';
    task.startedAt = null;
    task.finishedAt = null;
    // Keep the finished/active Chat identity across hosted runner rotation.
    // startAutomationTask will reopen this conversation and click
    // "Continue in new task" when continuationDepth is non-zero. Clearing it
    // here silently turns a serial continuation into an unrelated fresh Chat.
    task.lastProgressAt = null;
    task.lastError = 'github_actions_runner_continuation';
    const note = 'GitHub Actions 已在新托管 Runner 中接管。请从同一 checkout 的最新落盘进度继续。';
    task.reviewFeedback = [task.reviewFeedback, note].filter(Boolean).join('\n\n');
  }
  if (['failed', 'blocked'].includes(task.status)) {
    task.status = 'queued';
    task.startedAt = null;
    task.finishedAt = null;
    task.attempts = 0;
    task.lastError = 'github_actions_runner_retry';
  }
}
writeFileSync(statePath, `${JSON.stringify(state)}\n`, { mode: 0o600 });
