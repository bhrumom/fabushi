import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
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

test('persistent Actions runner polls the main-branch task control file', () => {
  assert.match(workflow, /run-dynamic-actions-controller\.mjs/);
  assert.match(workflow, /CHATGPT_AUTO_CONFIRM_TASK_CONTROL_REF: main/);
  assert.match(workflow, /CHATGPT_AUTO_CONFIRM_TASK_CONTROL_POLL_SECONDS: "30"/);
  assert.match(
    workflow,
    /Import dynamic parallel task inbox\r?\n\s+if: \$\{\{ inputs\.cancel_task_id == '' && inputs\.parallel_queue_smoke \}\}/,
  );
  assert.match(controller, /spawnSync\('gh'/);
  assert.match(controller, /repos\/\$\{repository\}\/contents\/\$\{repositoryPath\}/);
  assert.match(controller, /fetchRepositoryContent\(controlPath\)/);
  assert.match(controller, /task\._specDigest/);
  assert.match(controller, /entry\.sha/);
  assert.match(controller, /createHash\('sha256'\)/);
  assert.match(controller, /pollSeconds \* 1_000/);
});

test('goal versions are idempotent and dependencies use desired runtime ids', () => {
  assert.match(controller, /\$\{task\.id\}--v\$\{/);
  assert.match(controller, /native\('queue_cancel'/);
  assert.match(controller, /native\('queue_enqueue'/);
  assert.match(controller, /runtimeIdsByLogicalId/);
  assert.match(controller, /specDigest: task\._specDigest/);
  assert.match(controller, /specSources: task\._specFiles/);
  assert.match(controller, /dependsOn:[\s\S]*runtimeIdsByLogicalId\.get/);
  assert.equal(inbox.schemaVersion, 3);
  assert.equal(inbox.keepAlive, true);
  assert.ok(inbox.maxConcurrent >= 2);
  assert.ok(inbox.tasks.every(task => Number.isInteger(task.goalVersion)));
  assert.ok(inbox.tasks.every(task => Number.isInteger(task.revision)));
  assert.ok(inbox.tasks.every(task => Array.isArray(task.specSources) && task.specSources.length > 0));
});

test('task updates never cancel the currently running Chat', () => {
  assert.match(controller, /const running = managed\.filter\(isRunning\)/);
  assert.match(controller, /if \(running\.length > 0\) \{[\s\S]*deferred\.push/);
  assert.match(controller, /A task update is never allowed to stop the Chat/);
  assert.doesNotMatch(
    controller,
    /if \(staleVersion && !\['cancelled', 'completed'\]\.includes\(current\.status\)\)/,
  );
});

test('every new Chat is dispatched only after a fresh control read', () => {
  assert.match(controller, /const dispatchFreshRound = async reason =>/);
  assert.match(controller, /native\('queue_pause'\);[\s\S]*const control = fetchControl\(\)/);
  assert.match(controller, /start: false/);
  assert.match(controller, /native\('queue_resume'/);
  assert.match(controller, /await sleep\(1_000\);\r?\n\s+native\('queue_pause'\)/);
  assert.match(controller, /runningEnded[\s\S]*previous_chat_finished/);
  assert.match(controller, /queued_chat_boundary/);
});

test('unchanged tasks continue while changed tasks replace only at the boundary', () => {
  assert.match(controller, /if \(exact\) \{/);
  assert.match(controller, /staleVersion && !isTerminal\(current\)/);
  assert.match(controller, /action: 'resume_after_fresh_control_read'/);
  assert.match(controller, /queue_pause does not interrupt running Chats/);
});

test('unchanged terminal tasks preserve the child controller recovery budget', () => {
  assert.match(controller, /action: 'preserve_child_recovery_budget'/);
  assert.match(controller, /bypassed maxRuntimeRetries and ACTION_MAX_SAME_FAILURE_RECOVERIES/);
  assert.doesNotMatch(
    controller,
    /if \(exact && \['failed', 'blocked', 'cancelled'\]\.includes\(exact\.status\)\)[\s\S]*?native\('queue_retry'/,
  );
});

test('every dispatched work Chat receives a complete machine report contract', () => {
  assert.match(controller, /MAHAYANA_TASK_REPORT_CONTRACT_V2/);
  assert.match(controller, /"status":"complete"/);
  assert.match(controller, /"status":"incomplete\|blocked"/);
  assert.match(controller, /"task_id":\$\{taskId\}/);
  assert.match(controller, /完成报告会停止该任务的重复派发/);
});

test('each task sends one document folder path and link without document bodies', () => {
  assert.match(controller, /task\.documentDirectory/);
  assert.match(controller, /\/tree\/\$\{controlRef\}\/\$\{directory\}/);
  assert.match(controller, /只在消息中提供目录路径和文件夹链接/);
  assert.doesNotMatch(controller, /specificationFiles|specificationURLs/);
  assert.ok(inbox.tasks.every(task => typeof task.documentDirectory === 'string'));

  for (const task of inbox.tasks) {
    const relative = task.documentDirectory.replace(
      '.agents/plugins/plugins/chatgpt-auto-confirm/',
      '../',
    );
    const directoryURL = new URL(relative.endsWith('/') ? relative : `${relative}/`, import.meta.url);
    const files = readdirSync(directoryURL).sort();
    assert.ok(files.length >= 2, `${task.id} should have multiple documents`);
    assert.ok(files.includes('README.md'));
    assert.ok(files.includes('PRD.md'));
  }
});

test('document folders can contain PRD, technical, UI and acceptance files', () => {
  const task = inbox.tasks[0];
  const relative = task.documentDirectory.replace(
    '.agents/plugins/plugins/chatgpt-auto-confirm/',
    '../',
  );
  const directoryURL = new URL(`${relative}/`, import.meta.url);
  const files = readdirSync(directoryURL).sort();
  for (const required of [
    'ACCEPTANCE.md',
    'PRD.md',
    'README.md',
    'TECHNICAL_DESIGN.md',
    'UI_UX.md',
  ]) {
    assert.ok(files.includes(required), `missing required task document: ${required}`);
  }
});
