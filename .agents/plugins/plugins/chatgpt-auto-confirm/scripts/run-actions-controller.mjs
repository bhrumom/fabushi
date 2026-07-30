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

const maxLogChunkChars = 2_000;
const writeChunkedEvent = (label, payload) => {
  const serialized = JSON.stringify(payload);
  const total = Math.max(1, Math.ceil(serialized.length / maxLogChunkChars));
  for (let index = 0; index < total; index += 1) {
    const chunk = serialized.slice(
      index * maxLogChunkChars,
      (index + 1) * maxLogChunkChars,
    );
    process.stdout.write(
      `${label}_CHUNK ${index + 1}/${total} ${JSON.stringify(chunk)}\n`,
    );
  }
};

const commonPrefixLength = (left, right) => {
  const limit = Math.min(left.length, right.length);
  let index = 0;
  while (index < limit && left[index] === right[index]) index += 1;
  return index;
};

const pageFieldState = new Map();
const emitPageDiagnostics = queue => {
  for (const task of pageDiagnostics(queue)) {
    for (const [field, rawValue] of Object.entries(task.page)) {
      const value = typeof rawValue === 'string'
        ? rawValue
        : JSON.stringify(rawValue);
      const key = `${task.id}:${task.conversationId}:${field}`;
      const previous = pageFieldState.get(key);
      if (previous === undefined) {
        writeChunkedEvent('QUEUE_PAGE_FULL', {
          id: task.id,
          conversationId: task.conversationId,
          field,
          value,
        });
      } else if (previous !== value) {
        const prefixLength = commonPrefixLength(previous, value);
        writeChunkedEvent('QUEUE_PAGE_DELTA', {
          id: task.id,
          conversationId: task.conversationId,
          field,
          prefixLength,
          removedLength: previous.length - prefixLength,
          append: value.slice(prefixLength),
        });
      }
      pageFieldState.set(key, value);
    }
  }
};

let previousTrace = [];
const emitTraceEvents = queue => {
  const trace = Array.isArray(queue.watcherTrace) ? queue.watcherTrace : [];
  let overlap = Math.min(previousTrace.length, trace.length);
  while (
    overlap > 0
    && previousTrace.slice(-overlap).some((entry, index) => entry !== trace[index])
  ) {
    overlap -= 1;
  }
  for (const event of trace.slice(overlap)) {
    writeChunkedEvent('QUEUE_TRACE_EVENT', { event });
  }
  previousTrace = trace;
};

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
const failureDetail = task => [task.lastError, task.hiddenWorkerLastError]
  .filter(Boolean)
  .join(' ')
  .replace(/\s+/g, ' ');
const isNonRecoverableFailure = task =>
  /model_selection\s*:|model_picker_not_found|quick_chat_thinking_not_selected|reasoning_high_not_selected|target_model_not_selected|task_continuation_limit_reached|dependency_not_completed/.test(
    failureDetail(task),
  );
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
  emitPageDiagnostics(queue);
  emitTraceEvents(queue);
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
  const recoverableTerminalTasks = tasks.filter(task =>
    ['failed', 'blocked'].includes(task.status) && !isNonRecoverableFailure(task));
  const hasRecoverableTerminalFailure = recoverableTerminalTasks.length > 0;
  if (allTerminal && !hasRecoverableTerminalFailure) {
    writeResult('failed', queue, 'terminal_task_failure');
    process.exit(1);
  }

  const needsWatchdogRecovery = tasks.some(task =>
    task.status === 'running'
    && task.lastError
    && String(task.lastError).includes('not_chat_surface'));
  const needsRecovery = hasRecoverableTerminalFailure || needsWatchdogRecovery;
  if (needsRecovery && Date.now() - lastRecovery >= recoveryIntervalMs) {
    const currentFailureFingerprint = failureFingerprint(tasks);
    if (currentFailureFingerprint === lastFailureFingerprint) {
      sameFailureRecoveries += 1;
    } else {
      lastFailureFingerprint = currentFailureFingerprint;
      sameFailureRecoveries = 1;
    }
    if (sameFailureRecoveries > maxSameFailureRecoveries) {
      // A recoverable UI/runtime failure must never cut the continuous runner
      // chain. Yield the encrypted queue state to the next Actions run instead
      // of reporting a terminal failure.
      writeResult('incomplete', queue, 'repeated_recoverable_task_failure');
      process.exit(0);
    }

    const retryResults = [];
    for (const task of recoverableTerminalTasks) {
      try {
        const retry = run('queue_retry', {
          taskId: task.id,
          feedback: 'GitHub Actions 检测到可恢复的 Chat/连接器运行时失败。请重建隐藏 Chat，并从同一 checkout 的最新落盘进度继续。',
        });
        retryResults.push({
          id: task.id,
          ok: true,
          status: retry?.retriedTask?.status || null,
        });
      } catch (error) {
        retryResults.push({
          id: task.id,
          ok: false,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
    if (retryResults.length > 0) {
      process.stdout.write(
        `QUEUE_RETRY_RECOVERY attempt=${sameFailureRecoveries} ${JSON.stringify(retryResults)}\n`,
      );
    }

    if (needsWatchdogRecovery || retryResults.some(result => !result.ok)) {
      const recovery = run('queue_watchdog', { staleAfterSeconds: 300, force: true });
      process.stdout.write(
        `WATCHDOG_RECOVERY attempt=${sameFailureRecoveries} ` +
        `${JSON.stringify(watchdogDiagnostics(recovery))}\n`,
      );
    }
    lastRecovery = Date.now();
  }
  await new Promise(resolve => setTimeout(resolve, pollIntervalMs));
}

const finalQueue = run('queue_status');
const finalRecovery = run('queue_watchdog', { staleAfterSeconds: 300, force: true });
process.stdout.write(`WATCHDOG_DEADLINE ${JSON.stringify(watchdogDiagnostics(finalRecovery))}\n`);
writeResult('incomplete', finalQueue, 'hosted_runner_session_deadline');
