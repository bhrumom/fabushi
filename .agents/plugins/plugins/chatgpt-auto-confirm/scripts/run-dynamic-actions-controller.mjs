import { spawn, spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const runtime = process.env.CHATGPT_AUTO_CONFIRM_NATIVE ||
  fileURLToPath(new URL('../runtime/macos/chatgpt-auto-confirm', import.meta.url));
const controller = fileURLToPath(new URL('./run-actions-controller.mjs', import.meta.url));
const resultPath = process.env.ACTION_RESULT_PATH || 'action-result.json';
const repository = process.env.GITHUB_REPOSITORY || 'bhrumom/fabushi';
const controlPath = process.env.CHATGPT_AUTO_CONFIRM_TASK_CONTROL_PATH ||
  '.agents/plugins/plugins/chatgpt-auto-confirm/tasks/actions-inbox.json';
const controlRef = process.env.CHATGPT_AUTO_CONFIRM_TASK_CONTROL_REF || 'main';
const pollSeconds = Math.max(15, Number(
  process.env.CHATGPT_AUTO_CONFIRM_TASK_CONTROL_POLL_SECONDS || 30,
));
const boundaryRetrySeconds = Math.max(2, Number(
  process.env.CHATGPT_AUTO_CONFIRM_TASK_BOUNDARY_RETRY_SECONDS || 5,
));
const sessionSeconds = Math.min(
  20_700,
  Math.max(300, Number(process.env.ACTION_SESSION_SECONDS || 20_100)),
);
const deadline = Date.now() + sessionSeconds * 1_000;

const native = (command, params = undefined) => {
  const args = [command];
  if (params !== undefined) args.push(JSON.stringify(params));
  const result = spawnSync(runtime, args, {
    encoding: 'utf8',
    env: process.env,
    timeout: 120_000,
    maxBuffer: 10 * 1024 * 1024,
  });
  const line = result.stdout.trim().split(/\r?\n/).at(-1);
  if (!line) throw new Error(`${command} returned no JSON: ${result.stderr}`);
  const payload = JSON.parse(line);
  if (result.status !== 0 || payload.ok === false) {
    throw new Error(`${command} failed: ${payload.errorCode || payload.message || result.stderr}`);
  }
  return payload;
};

const fetchControl = () => {
  const result = spawnSync('gh', [
    'api', '--method', 'GET',
    `repos/${repository}/contents/${controlPath}`,
    '-f', `ref=${controlRef}`,
  ], {
    encoding: 'utf8',
    env: process.env,
    timeout: 60_000,
    maxBuffer: 10 * 1024 * 1024,
  });
  if (result.status !== 0) {
    throw new Error(`task control fetch failed: ${result.stderr || result.stdout}`);
  }
  const envelope = JSON.parse(result.stdout);
  const raw = Buffer.from(String(envelope.content || '').replace(/\s+/g, ''), 'base64')
    .toString('utf8');
  const control = JSON.parse(raw);
  control._blobSha = envelope.sha;
  control._source = envelope.html_url ||
    `https://github.com/${repository}/blob/${controlRef}/${controlPath}`;
  return control;
};

const reportContract = `
\n最终回复协议（必须执行，优先于任何旧版“完成时正常回复”的说明）：
无论任务完成、未完成还是阻塞，最终回复末尾都必须输出且只输出一个完整机器报告。不要把 JSON 放进 Markdown 代码块。
MAHAYANA_TASK_REPORT_V1_BEGIN
{"protocol":"mahayana.task-report.v1","status":"complete|incomplete|blocked","summary":"本轮实际结果","completed":["已完成项"],"remaining":["未完成项；complete 时必须为空数组"],"blockers":["真实卡点；complete 时必须为空数组"],"verification":["可复核验证证据"],"next_connector":"下一新 Chat 的 connector；无需切换则为空字符串","next_task":"下一轮完整续作指令；complete 时必须为空字符串"}
MAHAYANA_TASK_REPORT_V1_END
任务全部完成时 status 必须为 complete，remaining、blockers 必须为空数组，next_task 必须为空字符串。不得仅用自然语言声称完成。
`;

const normalizedDirectory = value => String(value || '')
  .trim()
  .replace(/^\/+|\/+$/g, '');

const taskDocumentBlock = task => {
  const directory = normalizedDirectory(task.documentDirectory);
  if (!directory) return '';
  const directoryURL = `https://github.com/${repository}/tree/${controlRef}/${directory}`;
  const additionalURLs = Array.isArray(task.documentURLs)
    ? task.documentURLs.map(value => String(value || '').trim()).filter(Boolean)
    : [];
  const links = [directoryURL, ...additionalURLs];
  return [
    '任务文档目录（开始工作前必须打开并阅读目录中的全部相关文档）：',
    `- 仓库目录：${directory}`,
    ...links.map(value => `- 文件夹链接：${value}`),
    '只在消息中提供目录路径和文件夹链接，不在提示词中复制文档正文。',
    '目录中可以包含 PRD、技术设计、架构说明、UI/UX、接口契约、验收标准和其他任务资料。',
    '当前 goalVersion 对应的目录资料优先于旧 Chat 中的任务描述。',
  ].join('\n');
};

const runtimeId = task => `${task.id}--v${Math.max(1, Number(task.goalVersion || 1))}`;
const logicalPrefix = task => `${task.id}--v`;
const managedBy = (current, task) =>
  current.id === task.id || current.id.startsWith(logicalPrefix(task));
const isRunning = task => task.status === 'running';
const isTerminal = task => ['completed', 'cancelled'].includes(task.status);

const taskPrompt = (control, task) => [
  `动态任务控制版本：${control.revision || control._blobSha}。`,
  `逻辑任务：${task.id}；目标版本：${Math.max(1, Number(task.goalVersion || 1))}。`,
  task.prompt,
  taskDocumentBlock(task),
  reportContract,
].filter(Boolean).join('\n\n');

let activeControl = null;
let lastBlobSha = '';

const reconcileControl = control => {
  activeControl = control;
  const queue = native('queue_status');
  const existing = Array.isArray(queue.tasks) ? queue.tasks : [];
  const desiredTasks = Array.isArray(control.tasks) ? control.tasks : [];
  const runtimeIdsByLogicalId = new Map(
    desiredTasks.filter(task => task?.id).map(task => [task.id, runtimeId(task)]),
  );
  const cancelled = [];
  const enqueued = [];
  const deferred = [];

  for (const task of desiredTasks) {
    if (!task?.id || !task?.title || !task?.prompt ||
        !normalizedDirectory(task.documentDirectory)) {
      process.stderr.write(
        `TASK_CONTROL_INVALID_TASK ${JSON.stringify({
          id: task?.id || null,
          reason: 'id_title_prompt_and_documentDirectory_are_required',
        })}\n`,
      );
      continue;
    }

    const desiredId = runtimeId(task);
    const managed = existing.filter(current => managedBy(current, task));
    const running = managed.filter(isRunning);

    // A task update is never allowed to stop the Chat that is currently
    // working. The new goal is held until that Chat reaches a round boundary.
    if (running.length > 0) {
      deferred.push({
        logicalTaskId: task.id,
        desiredId,
        runningIds: running.map(current => current.id),
      });
      continue;
    }

    for (const current of managed) {
      const staleVersion = current.id !== desiredId;
      if (staleVersion && !isTerminal(current)) {
        try {
          native('queue_cancel', { taskId: current.id });
          cancelled.push(current.id);
        } catch (error) {
          process.stderr.write(`TASK_CONTROL_CANCEL_WARNING ${current.id} ${error.message}\n`);
        }
      }
    }

    if (managed.some(current => current.id === desiredId)) continue;

    native('queue_enqueue', {
      tasks: [{
        ...task,
        id: desiredId,
        dependsOn: (Array.isArray(task.dependsOn) ? task.dependsOn : [])
          .map(dependency => runtimeIdsByLogicalId.get(dependency) || dependency),
        prompt: taskPrompt(control, task),
      }],
      // Dispatch is opened explicitly only after the latest control file has
      // been read at the next Chat boundary.
      start: false,
      maxConcurrent: Math.min(4, Math.max(1, Number(control.maxConcurrent || 2))),
      reviewGate: control.reviewGate ?? false,
    });
    enqueued.push(desiredId);
  }

  if (control.authoritative === true) {
    for (const current of existing) {
      const managed = desiredTasks.some(task => managedBy(current, task));
      if (managed || isTerminal(current)) continue;
      if (isRunning(current)) {
        deferred.push({
          logicalTaskId: null,
          desiredId: null,
          runningIds: [current.id],
          removal: true,
        });
        continue;
      }
      try {
        native('queue_cancel', { taskId: current.id });
        cancelled.push(current.id);
      } catch (error) {
        process.stderr.write(`TASK_CONTROL_CANCEL_WARNING ${current.id} ${error.message}\n`);
      }
    }
  }

  const changed = control._blobSha !== lastBlobSha;
  lastBlobSha = control._blobSha;
  const result = {
    changed,
    revision: control.revision || control._blobSha,
    source: control._source,
    enqueued,
    cancelled,
    deferred,
    keepAlive: control.keepAlive === true,
  };
  process.stdout.write(`TASK_CONTROL_SYNC ${JSON.stringify(result)}\n`);
  return result;
};

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

const dispatchFreshRound = async reason => {
  // queue_pause does not interrupt running Chats. It only closes the gate that
  // creates another Chat, which gives us a deterministic update boundary.
  native('queue_pause');
  const control = fetchControl();
  const sync = reconcileControl(control);
  const queue = native('queue_status');
  const tasks = Array.isArray(queue.tasks) ? queue.tasks : [];
  const queued = tasks.filter(task => task.status === 'queued');
  const runningCount = tasks.filter(isRunning).length;
  const maxConcurrent = Math.min(4, Math.max(1, Number(
    control.maxConcurrent || queue.maxConcurrent || 2,
  )));

  if (queued.length > 0 && runningCount < maxConcurrent) {
    process.stdout.write(`TASK_CHAT_BOUNDARY ${JSON.stringify({
      reason,
      revision: sync.revision,
      queuedIds: queued.map(task => task.id),
      runningCount,
      maxConcurrent,
      action: 'resume_after_fresh_control_read',
    })}\n`);
    native('queue_resume', {
      maxConcurrent,
      reviewGate: control.reviewGate ?? false,
    });
    // Let the watcher select eligible queued work. If it is already inside
    // startAutomationTask, queue_pause waits for that locked send to finish and
    // then closes the gate before any later Chat can be selected.
    await sleep(1_000);
    native('queue_pause');
  }
  return sync;
};

const writeIncomplete = reason => {
  let queue = {};
  try { queue = native('queue_status'); } catch {}
  const result = {
    status: 'incomplete',
    reason,
    finishedAt: new Date().toISOString(),
    counts: queue.counts || {},
    tasks: queue.tasks || [],
    taskControl: activeControl ? {
      revision: activeControl.revision || activeControl._blobSha,
      source: activeControl._source,
      keepAlive: activeControl.keepAlive === true,
    } : null,
  };
  writeFileSync(resultPath, `${JSON.stringify(result)}\n`);
  process.stdout.write(`ACTION_RESULT ${JSON.stringify(result)}\n`);
};

let child = null;
let stopping = false;
const stopChild = () => {
  if (child && child.exitCode === null) child.kill('SIGTERM');
};
const handleFinishedChild = async () => {
  if (!child || child.exitCode === null) return false;
  const exitCode = child.exitCode;
  let status = '';
  try { status = JSON.parse(readFileSync(resultPath, 'utf8')).status || ''; } catch {}
  if (status === 'failed') process.exit(exitCode || 1);
  if (activeControl?.keepAlive !== true) {
    process.exit(exitCode || (status === 'complete' ? 0 : 1));
  }
  child = null;
  await sleep(Math.min(5_000, pollSeconds * 1_000));
  return true;
};
process.on('SIGTERM', () => { stopping = true; stopChild(); });
process.on('SIGINT', () => { stopping = true; stopChild(); });

try {
  await dispatchFreshRound('startup');
} catch (error) {
  process.stderr.write(`TASK_CONTROL_INITIAL_WARNING ${error.message}\n`);
}

let nextControlPollAt = Date.now() + pollSeconds * 1_000;
let nextBoundaryRetryAt = Date.now();
let previousRunningIds = new Set();
while (!stopping && Date.now() < deadline) {
  // Consume the terminal result before considering a replacement child. The
  // previous order could overwrite a just-finished failed child at the top of
  // the loop, causing a deterministic failure to restart until the six-hour
  // hosted deadline.
  if (await handleFinishedChild()) continue;
  if (!child) {
    const remainingSeconds = Math.max(300, Math.ceil((deadline - Date.now()) / 1_000));
    child = spawn(process.execPath, [controller], {
      env: {
        ...process.env,
        ACTION_SESSION_SECONDS: String(Math.min(remainingSeconds, 20_100)),
      },
      stdio: ['ignore', 'inherit', 'inherit'],
    });
  }

  let queue = null;
  try { queue = native('queue_status'); }
  catch (error) { process.stderr.write(`TASK_QUEUE_STATUS_WARNING ${error.message}\n`); }
  const tasks = Array.isArray(queue?.tasks) ? queue.tasks : [];
  const runningIds = new Set(tasks.filter(isRunning).map(task => task.id));
  const runningEnded = [...previousRunningIds].some(id => !runningIds.has(id));
  const hasQueued = tasks.some(task => task.status === 'queued');
  const controlPollDue = Date.now() >= nextControlPollAt;
  const boundaryRetryDue = hasQueued && Date.now() >= nextBoundaryRetryAt;

  if (runningEnded || controlPollDue || boundaryRetryDue) {
    const reason = runningEnded
      ? 'previous_chat_finished'
      : controlPollDue
        ? 'periodic_control_refresh'
        : 'queued_chat_boundary';
    try { await dispatchFreshRound(reason); }
    catch (error) { process.stderr.write(`TASK_CONTROL_SYNC_WARNING ${error.message}\n`); }
    if (controlPollDue) nextControlPollAt = Date.now() + pollSeconds * 1_000;
    nextBoundaryRetryAt = Date.now() + boundaryRetrySeconds * 1_000;
    try {
      queue = native('queue_status');
      previousRunningIds = new Set(
        (Array.isArray(queue.tasks) ? queue.tasks : [])
          .filter(isRunning)
          .map(task => task.id),
      );
    } catch {
      previousRunningIds = runningIds;
    }
  } else {
    previousRunningIds = runningIds;
  }

  if (await handleFinishedChild()) continue;
  await sleep(1_000);
}

stopChild();
writeIncomplete(stopping ? 'dynamic_controller_interrupted' : 'hosted_runner_session_deadline');
