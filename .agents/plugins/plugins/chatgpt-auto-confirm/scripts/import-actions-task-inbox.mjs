import { readFileSync, writeFileSync } from 'node:fs';

const statePath = process.env.CHATGPT_AUTO_CONFIRM_QUEUE_STATE;
const inboxPath = process.env.CHATGPT_AUTO_CONFIRM_TASK_INBOX_FILE?.trim();
if (!statePath) throw new Error('CHATGPT_AUTO_CONFIRM_QUEUE_STATE is required');
if (!inboxPath) throw new Error('CHATGPT_AUTO_CONFIRM_TASK_INBOX_FILE is required');

const inbox = JSON.parse(readFileSync(inboxPath, 'utf8'));
const incoming = Array.isArray(inbox.tasks) ? inbox.tasks : [];
const state = JSON.parse(readFileSync(statePath, 'utf8'));
const tasks = Array.isArray(state.automationTasks) ? state.automationTasks : [];
const knownTasks = new Map(tasks.map(task => [task.id, task]));
const now = new Date().toISOString();
const appended = [];
const requeued = [];

const resetExecution = (task) => {
  task.attempts = 0;
  task.status = 'queued';
  task.startedAt = null;
  task.finishedAt = null;
  task.workerPid = null;
  task.workerPort = null;
  task.workerTargetId = null;
  task.workerStatePath = null;
  task.workerProfilePath = null;
  task.resultPath = null;
  task.conversationId = null;
  task.chatURL = null;
  task.lastActivitySignature = null;
  task.lastProgressAt = null;
  task.hiddenWorkerLastHeartbeatAt = null;
  task.hiddenWorkerLastError = null;
  task.waitingUntil = null;
  task.waitReason = null;
  task.lastError = null;
  task.updatedAt = now;
};

for (const task of incoming) {
  if (!task?.id) continue;
  const existing = knownTasks.get(task.id);
  if (existing) {
    for (const field of [
      'title', 'prompt', 'promptTemplate', 'connector', 'dependsOn',
      'resourceLocks', 'priority', 'timeout', 'maxTaskContinuations',
      'maxRuntimeRetries',
    ]) {
      if (task[field] !== undefined) existing[field] = task[field];
    }
    if (['failed', 'blocked'].includes(existing.status)) {
      resetExecution(existing);
      requeued.push(existing.id);
    }
    continue;
  }
  tasks.push({
    id: task.id,
    title: task.title,
    prompt: task.prompt,
    promptTemplate: task.promptTemplate || 'continue-to-complete',
    connector: task.connector || 'GitHub',
    dependsOn: task.dependsOn || [],
    resourceLocks: task.resourceLocks || [],
    priority: task.priority || 0,
    timeout: task.timeout || 7200,
    maxTaskContinuations: task.maxTaskContinuations || 20,
    maxRuntimeRetries: task.maxRuntimeRetries ?? 2,
    attempts: 0,
    reviewRound: 0,
    status: 'queued',
    createdAt: now,
    updatedAt: now,
    startedAt: null,
    finishedAt: null,
    workerPid: null,
    workerPort: null,
    workerTargetId: null,
    workerStatePath: null,
    workerProfilePath: null,
    resultPath: null,
    conversationId: null,
    reviewConversationId: null,
    reviewStatus: null,
    reviewReport: null,
    chatURL: null,
    report: null,
    lastResultJSON: null,
    lastError: null,
    reviewFeedback: null,
    reviewedAt: null,
    continuationDepth: 0,
    reportFingerprints: [],
    lastActivitySignature: null,
    lastProgressAt: null,
    hiddenWorkerLastHeartbeatAt: null,
    hiddenWorkerRecoveryCount: 0,
    hiddenWorkerLastError: null,
    watchdogLastRecoveryAt: null,
    watchdogRecoveryCount: 0,
    waitingUntil: null,
    waitReason: null,
  });
  knownTasks.set(task.id, tasks.at(-1));
  appended.push(task.id);
}

state.automationTasks = tasks;
state.queueEnabled = true;
state.queuePaused = false;
state.queueMaxConcurrent = Math.min(4, Math.max(2,
  Number(inbox.maxConcurrent || state.queueMaxConcurrent || 2)));
state.queueReviewGate = inbox.reviewGate ?? false;
writeFileSync(statePath, `${JSON.stringify(state)}\n`, { mode: 0o600 });
process.stdout.write(
  `Imported ${appended.length} new queued task(s); requeued ${requeued.length} failed task(s).` +
  `${requeued.length ? ` Requeued: ${requeued.join(', ')}.` : ''}\n`,
);
