import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const controller = readFileSync(
  new URL('../scripts/run-dynamic-actions-controller.mjs', import.meta.url),
  'utf8',
);
const workflow = readFileSync(
  new URL('../../../../../.github/workflows/chatgpt-auto-confirm-runner.yml', import.meta.url),
  'utf8',
);
const inbox = JSON.parse(readFileSync(
  new URL('../tasks/actions-inbox.json', import.meta.url),
  'utf8',
));
const specification = readFileSync(
  new URL('../tasks/DYNAMIC_TASK_SPEC.md', import.meta.url),
  'utf8',
);

test('persistent Actions runner polls the main-branch task control file', () => {
  assert.match(workflow, /run-dynamic-actions-controller\.mjs/);
  assert.match(workflow, /CHATGPT_AUTO_CONFIRM_TASK_CONTROL_REF: main/);
  assert.match(workflow, /CHATGPT_AUTO_CONFIRM_TASK_CONTROL_POLL_SECONDS: "30"/);
  assert.match(workflow, /Import dynamic parallel task inbox\n\s+if: \$\{\{ inputs\.parallel_queue_smoke \}\}/);
  assert.match(controller, /spawnSync\('gh'/);
  assert.match(controller, /repos\/\$\{repository\}\/contents\/\$\{controlPath\}/);
  assert.match(controller, /setTimeout\(resolve, pollSeconds/);
});

test('goal versions are idempotent and updates replace only stale versions', () => {
  assert.match(controller, /\$\{task\.id\}--v\$\{/);
  assert.match(controller, /native\('queue_cancel'/);
  assert.match(controller, /native\('queue_enqueue'/);
  assert.match(controller, /runtimeIdsByLogicalId/);
  assert.match(controller, /dependsOn:[\s\S]*runtimeIdsByLogicalId\.get/);
  assert.equal(inbox.schemaVersion, 2);
  assert.equal(inbox.keepAlive, true);
  assert.ok(inbox.maxConcurrent >= 2);
  assert.ok(inbox.tasks.every(task => Number.isInteger(task.goalVersion)));
});

test('every dispatched work Chat receives a complete machine report contract', () => {
  assert.match(controller, /status":"complete\|incomplete\|blocked/);
  assert.match(controller, /不得仅用自然语言声称完成/);
  assert.match(controller, /remaining、blockers 必须为空数组/);
  assert.match(controller, /next_task 必须为空字符串/);
});

test('task specifications are injected as repository files and online links', () => {
  assert.match(controller, /specificationFiles/);
  assert.match(controller, /specificationURLs/);
  assert.deepEqual(inbox.specificationFiles, [
    '.agents/plugins/plugins/chatgpt-auto-confirm/tasks/DYNAMIC_TASK_SPEC.md',
  ]);
  assert.equal(inbox.specificationURLs.length, 1);
  assert.match(specification, /每 30 秒读取/);
  assert.match(specification, /goalVersion/);
  assert.match(specification, /动态新增任务/);
});
