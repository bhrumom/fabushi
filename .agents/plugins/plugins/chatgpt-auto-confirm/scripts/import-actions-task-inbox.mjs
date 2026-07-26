import { readFileSync, writeFileSync } from 'node:fs';

const statePath = process.env.CHATGPT_AUTO_CONFIRM_QUEUE_STATE;
const inboxPath = process.env.CHATGPT_AUTO_CONFIRM_TASK_INBOX_FILE?.trim();
if (!statePath) throw new Error('CHATGPT_AUTO_CONFIRM_QUEUE_STATE is required');
if (!inboxPath) throw new Error('CHATGPT_AUTO_CONFIRM_TASK_INBOX_FILE is required');

const inbox = JSON.parse(readFileSync(inboxPath, 'utf8'));
const incoming = Array.isArray(inbox.tasks) ? inbox.tasks : [];
const state = JSON.parse(readFileSync(statePath, 'utf8'));
const tasks = Array.isArray(state.automationTasks) ? state.automationTasks : [];
const knownIds = new Set(tasks.map(task => task.id));
const now = new Date().toISOString();
const appended = [];

for (const task of incoming) {
  if (!task?.id || knownIds.has(task.id)) continue;
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
  knownIds.add(task.id);
  appended.push(task.id);
}

state.automationTasks = tasks;
state.queueEnabled = true;
state.queuePaused = false;
state.queueMaxConcurrent = Math.min(4, Math.max(2,
  Number(inbox.maxConcurrent || state.queueMaxConcurrent || 2)));
state.queueReviewGate = inbox.reviewGate ?? false;
writeFileSync(statePath, `${JSON.stringify(state)}\n`, { mode: 0o600 });
process.stdout.write(`Imported ${appended.length} new queued task(s).\n`);
