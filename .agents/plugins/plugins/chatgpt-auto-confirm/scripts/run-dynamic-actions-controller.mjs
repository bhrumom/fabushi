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

const specificationBlock = (control, task) => {
  const files = [...new Set([
    ...(Array.isArray(control.specificationFiles) ? control.specificationFiles : []),
    ...(Array.isArray(task.specificationFiles) ? task.specificationFiles : []),
  ])];
  const urls = [...new Set([
    ...(Array.isArray(control.specificationURLs) ? control.specificationURLs : []),
    ...(Array.isArray(task.specificationURLs) ? task.specificationURLs : []),
  ])];
  if (files.length === 0 && urls.length === 0) return '';
  return `\n\n任务规范（开始工作前必须读取；与旧聊天冲突时以当前 goalVersion 和这些规范为准）：\n` +
    files.map(value => `- 仓库文件：${value}`).concat(
      urls.map(value => `- 在线链接：${value}`),
    ).join('\n');
};

const runtimeId = task => `${task.id}--v${Math.max(1, Number(task.goalVersion || 1))}`;
const logicalPrefix = task => `${task.id}--v`;

let activeControl = null;
let lastBlobSha = '';

const syncControl = () => {
  const control = fetchControl();
  activeControl = control;
  if (control._blobSha === lastBlobSha) {
    return { changed: false, revision: control.revision || control._blobSha };
  }

  const queue = native('queue_status');
  const existing = Array.isArray(queue.tasks) ? queue.tasks : [];
  const desiredTasks = Array.isArray(control.tasks) ? control.tasks : [];
  const desiredIds = new Set(desiredTasks.map(runtimeId));
  const runtimeIdsByLogicalId = new Map(
    desiredTasks.filter(task => task?.id).map(task => [task.id, runtimeId(task)]),
  );
  const cancelled = [];
  const enqueued = [];

  for (const task of desiredTasks) {
    if (!task?.id || !task?.title || !task?.prompt) continue;
    const desiredId = runtimeId(task);
    for (const current of existing) {
      const staleVersion = current.id === task.id ||
        (current.id.startsWith(logicalPrefix(task)) && current.id !== desiredId);
      if (staleVersion && !['cancelled', 'completed'].includes(current.status)) {
        try {
          native('queue_cancel', { taskId: current.id });
          cancelled.push(current.id);
        } catch (error) {
          process.stderr.write(`TASK_CONTROL_CANCEL_WARNING ${current.id} ${error.message}\n`);
        }
      }
    }
    if (existing.some(current => current.id === desiredId)) continue;

    const prompt = [
      `动态任务控制版本：${control.revision || control._blobSha}。`,
      `逻辑任务：${task.id}；目标版本：${Math.max(1, Number(task.goalVersion || 1))}。`,
      task.prompt,
      specificationBlock(control, task),
      reportContract,
    ].filter(Boolean).join('\n\n');

    native('queue_enqueue', {
      tasks: [{
        ...task,
        id: desiredId,
        dependsOn: (Array.isArray(task.dependsOn) ? task.dependsOn : [])
          .map(dependency => runtimeIdsByLogicalId.get(dependency) || dependency),
        prompt,
      }],
      start: true,
      maxConcurrent: Math.min(4, Math.max(1, Number(control.maxConcurrent || 2))),
      reviewGate: control.reviewGate ?? false,
    });
    enqueued.push(desiredId);
  }

  if (control.authoritative === true) {
    for (const current of existing) {
      const managed = desiredTasks.some(task =>
        current.id === task.id || current.id.startsWith(logicalPrefix(task)));
      if (!managed && !desiredIds.has(current.id) &&
          !['cancelled', 'completed'].includes(current.status)) {
        try {
          native('queue_cancel', { taskId: current.id });
          cancelled.push(current.id);
        } catch (error) {
          process.stderr.write(`TASK_CONTROL_CANCEL_WARNING ${current.id} ${error.message}\n`);
        }
      }
    }
  }

  lastBlobSha = control._blobSha;
  const result = {
    changed: true,
    revision: control.revision || control._blobSha,
    source: control._source,
    enqueued,
    cancelled,
    keepAlive: control.keepAlive === true,
  };
  process.stdout.write(`TASK_CONTROL_SYNC ${JSON.stringify(result)}\n`);
  return result;
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

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

let child = null;
let stopping = false;
const stopChild = () => {
  if (child && child.exitCode === null) child.kill('SIGTERM');
};
process.on('SIGTERM', () => { stopping = true; stopChild(); });
process.on('SIGINT', () => { stopping = true; stopChild(); });

try {
  syncControl();
} catch (error) {
  process.stderr.write(`TASK_CONTROL_INITIAL_WARNING ${error.message}\n`);
}

let nextSyncAt = Date.now() + pollSeconds * 1_000;
while (!stopping && Date.now() < deadline) {
  if (!child || child.exitCode !== null) {
    const remainingSeconds = Math.max(300, Math.ceil((deadline - Date.now()) / 1_000));
    child = spawn(process.execPath, [controller], {
      env: {
        ...process.env,
        ACTION_SESSION_SECONDS: String(Math.min(remainingSeconds, 20_100)),
      },
      stdio: ['ignore', 'inherit', 'inherit'],
    });
  }

  if (Date.now() >= nextSyncAt) {
    try { syncControl(); }
    catch (error) { process.stderr.write(`TASK_CONTROL_SYNC_WARNING ${error.message}\n`); }
    nextSyncAt = Date.now() + pollSeconds * 1_000;
  }

  if (child.exitCode !== null) {
    let status = '';
    try { status = JSON.parse(readFileSync(resultPath, 'utf8')).status || ''; } catch {}
    if (activeControl?.keepAlive !== true) process.exit(child.exitCode || (status === 'complete' ? 0 : 1));
    await sleep(Math.min(5_000, pollSeconds * 1_000));
  } else {
    await sleep(1_000);
  }
}

stopChild();
writeIncomplete(stopping ? 'dynamic_controller_interrupted' : 'hosted_runner_session_deadline');
