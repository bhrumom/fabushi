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
    // Keep both the active state and Chat identity across hosted runner
    // rotation. monitorAutomationTask recreates only the hidden renderer,
    // navigates back to this durable conversation, confirms pending
    // authorization, and observes its real terminal state. Re-queuing here
    // would skip that recovery and create a new Chat before the prior one had
    // actually finished.
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
