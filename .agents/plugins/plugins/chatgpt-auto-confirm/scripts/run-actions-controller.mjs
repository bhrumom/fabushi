import { spawnSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const runtime = process.env.CHATGPT_AUTO_CONFIRM_NATIVE ||
  fileURLToPath(new URL('../runtime/macos/chatgpt-auto-confirm', import.meta.url));
const testMode = process.env.NODE_ENV === 'test';
const deadlineSeconds = Math.min(
  20_700,
  Math.max(testMode ? 1 : 300, Number(process.env.ACTION_SESSION_SECONDS || 20_400)),
);
const deadline = Date.now() + deadlineSeconds * 1_000;
const resultPath = process.env.ACTION_RESULT_PATH || 'action-result.json';
const pollIntervalMs = Math.max(
  testMode ? 10 : 1_000,
  Number(process.env.ACTION_POLL_INTERVAL_MS || 15_000),
);
const recoveryIntervalMs = Math.max(
  testMode ? 10 : 60_000,
  Number(process.env.ACTION_RECOVERY_INTERVAL_MS || 300_000),
);
const maxSameFailureRecoveries = Math.max(
  1,
  Number(process.env.ACTION_MAX_SAME_FAILURE_RECOVERIES || 3),
);

const run = (command, params = undefined) => {
  const args = [command];
  if (params !== undefined) args.push(JSON.stringify(params));
  const result = spawnSync(runtime, args, {
    encoding: 'utf8',
    env: process.env,
    timeout: 120_000,
    maxBuffer: 10 * 1024 * 1024,
  });
  const line = result.stdout.trim().split(/\r?\n/).at(-1);
  if (!line) throw new Error(`${command} returned no JSON`);
  const payload = JSON.parse(line);
  if (result.status !== 0 || payload.ok === false) {
    throw new Error(`${command} failed: ${payload.errorCode || payload.message || result.stderr}`);
  }
  return payload;
};

const recognitionDiagnostics = task => {
  if (!task.replyDiagnostics) return null;
  const { pageSnapshot: _pageSnapshot, ...recognition } = task.replyDiagnostics;
  return recognition;
};

const taskDiagnostics = (queue) => (Array.isArray(queue?.tasks) ? queue.tasks : [])
  .map(task => ({
    id: task.id,
    status: task.status,
    attempts: task.attempts,
    continuationDepth: task.continuationDepth ?? null,
    maxTaskContinuations: task.maxTaskContinuations ?? null,
    conversationId: task.conversationId || null,
    lastError: task.lastError || null,
    hiddenWorkerLastError: task.hiddenWorkerLastError || null,
    lastProgressAt: task.lastProgressAt || null,
    replyDiagnostics: recognitionDiagnostics(task),
  }));

const pageDiagnostics = queue => (Array.isArray(queue?.tasks) ? queue.tasks : [])
  .filter(task => task.replyDiagnostics?.pageSnapshot)
  .map(task => ({
    id: task.id,
    conversationId: task.conversationId || null,
    page: task.replyDiagnostics.pageSnapshot,
  }));

const writeResult = (status, queue, reason) => {
  const result = {
    status,
    reason,
    finishedAt: new Date().toISOString(),
    counts: queue?.counts || {},
    tasks: taskDiagnostics(queue),
  };
  writeFileSync(resultPath, `${JSON.stringify(result)}\n`);
  process.stdout.write(`ACTION_RESULT ${JSON.stringify(result)}\n`);
};

const queueFingerprint = queue => JSON.stringify(taskDiagnostics(queue));
const failureFingerprint = tasks => JSON.stringify(tasks
  .filter(task => ['failed', 'blocked'].includes(task.status))
  .map(task => ({
    id: task.id,
    status: task.status,
    lastError: task.lastError || null,
    hiddenWorkerLastError: task.hiddenWorkerLastError || null,
  })));
const isNonRecoverableFailure = task => {
  const detail = [task.lastError, task.hiddenWorkerLastError]
    .filter(Boolean)
    .join(' ');
  return /model_selection\s*:|model_picker_not_found|quick_chat_thinking_not_selected|reasoning_high_not_selected|target_model_not_selected|connector_selection_not_confirmed|task_continuation_limit_reached|dependency_not_completed/.test(detail.replace(/\s+/g, ' '));
};
const watchdogDiagnostics = result => ({
  ok: result?.ok !== false,
  recovered: result?.recovered === true,
  eligibleTaskIds: result?.eligibleTaskIds || [],
  watcherPid: result?.watcherPid || null,
  queue: {
    counts: result?.queue?.counts || {},
    tasks: taskDiagnostics(result?.queue),
  },
});

const initialRecovery = run('queue_watchdog', { staleAfterSeconds: 300, force: true });
process.stdout.write(`WATCHDOG_INITIAL ${JSON.stringify(watchdogDiagnostics(initialRecovery))}\n`);
let lastRecovery = 0;
let lastQueueFingerprint = '';
let lastPageFingerprint = '';
let lastTraceFingerprint = '';
let lastFailureFingerprint = '';
let sameFailureRecoveries = 0;
while (Date.now() < deadline) {
  const queue = run('queue_status');
  const tasks = Array.isArray(queue.tasks) ? queue.tasks : [];
  const fingerprint = queueFingerprint(queue);
  if (fingerprint !== lastQueueFingerprint) {
    process.stdout.write(`QUEUE_RECOGNITION ${fingerprint}\n`);
    lastQueueFingerprint = fingerprint;
  }
  const pageFingerprint = JSON.stringify(pageDiagnostics(queue));
  if (pageFingerprint !== lastPageFingerprint) {
    process.stdout.write(`QUEUE_PAGE ${pageFingerprint}\n`);
    lastPageFingerprint = pageFingerprint;
  }
  const trace = Array.isArray(queue.watcherTrace) ? queue.watcherTrace : [];
  const traceFingerprint = JSON.stringify(trace);
  if (traceFingerprint !== lastTraceFingerprint) {
    process.stdout.write(`QUEUE_TRACE ${traceFingerprint}\n`);
    lastTraceFingerprint = traceFingerprint;
  }
  if (tasks.length === 0) {
    writeResult('failed', queue, 'no_tasks_configured');
    process.exit(1);
  }
  const complete = tasks.length > 0 &&
    tasks.every(task => ['completed', 'cancelled'].includes(task.status));
  if (complete) {
    writeResult('complete', queue, 'all_tasks_terminal');
    process.exit(0);
  }
  const allTerminal = tasks.length > 0 && tasks.every(task =>
    ['completed', 'cancelled', 'failed', 'blocked'].includes(task.status));
  const hasRecoverableTerminalFailure = tasks.some(task =>
    ['failed', 'blocked'].includes(task.status) && !isNonRecoverableFailure(task));
  if (allTerminal && !hasRecoverableTerminalFailure) {
    writeResult('failed', queue, 'terminal_task_failure');
    process.exit(1);
  }

  const needsRecovery = tasks.some(task =>
    (['failed', 'blocked'].includes(task.status) && !isNonRecoverableFailure(task)) ||
    (task.lastError && String(task.lastError).includes('not_chat_surface')));
  if (needsRecovery && Date.now() - lastRecovery >= recoveryIntervalMs) {
    const currentFailureFingerprint = failureFingerprint(tasks);
    if (currentFailureFingerprint === lastFailureFingerprint) {
      sameFailureRecoveries += 1;
    } else {
      lastFailureFingerprint = currentFailureFingerprint;
      sameFailureRecoveries = 1;
    }
    if (sameFailureRecoveries > maxSameFailureRecoveries) {
      writeResult('failed', queue, 'repeated_terminal_task_failure');
      process.exit(1);
    }
    const recovery = run('queue_watchdog', { staleAfterSeconds: 300, force: true });
    process.stdout.write(
      `WATCHDOG_RECOVERY attempt=${sameFailureRecoveries} ` +
      `${JSON.stringify(watchdogDiagnostics(recovery))}\n`,
    );
    lastRecovery = Date.now();
  }
  await new Promise(resolve => setTimeout(resolve, pollIntervalMs));
}

const finalQueue = run('queue_status');
const finalRecovery = run('queue_watchdog', { staleAfterSeconds: 300, force: true });
process.stdout.write(`WATCHDOG_DEADLINE ${JSON.stringify(watchdogDiagnostics(finalRecovery))}\n`);
writeResult('incomplete', finalQueue, 'hosted_runner_session_deadline');
