import { spawnSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const runtime = process.env.CHATGPT_AUTO_CONFIRM_NATIVE ||
  fileURLToPath(new URL('../runtime/macos/chatgpt-auto-confirm', import.meta.url));
const deadlineSeconds = Math.min(
  20_700,
  Math.max(300, Number(process.env.ACTION_SESSION_SECONDS || 20_400)),
);
const deadline = Date.now() + deadlineSeconds * 1_000;
const resultPath = process.env.ACTION_RESULT_PATH || 'action-result.json';

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

const writeResult = (status, queue, reason) => {
  writeFileSync(resultPath, `${JSON.stringify({
    status,
    reason,
    finishedAt: new Date().toISOString(),
    counts: queue?.counts || {},
  })}\n`);
};

run('queue_watchdog', { staleAfterSeconds: 300, force: true });
let lastRecovery = 0;
while (Date.now() < deadline) {
  const queue = run('queue_status');
  const tasks = Array.isArray(queue.tasks) ? queue.tasks : [];
  const complete = tasks.length > 0 &&
    tasks.every(task => ['completed', 'cancelled'].includes(task.status));
  if (complete) {
    writeResult('complete', queue, 'all_tasks_terminal');
    process.exit(0);
  }

  const needsRecovery = tasks.some(task =>
    ['failed', 'blocked'].includes(task.status) ||
    (task.lastError && String(task.lastError).includes('not_chat_surface')));
  if (needsRecovery && Date.now() - lastRecovery >= 300_000) {
    run('queue_watchdog', { staleAfterSeconds: 300, force: true });
    lastRecovery = Date.now();
  }
  await new Promise(resolve => setTimeout(resolve, 15_000));
}

const finalQueue = run('queue_status');
run('queue_watchdog', { staleAfterSeconds: 300, force: true });
writeResult('incomplete', finalQueue, 'hosted_runner_session_deadline');
