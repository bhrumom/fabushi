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

test('persistent Actions runner polls the main-branch task control file', () => {
  assert.match(workflow, /run-dynamic-actions-controller\.mjs/);
  assert.match(workflow, /CHATGPT_AUTO_CONFIRM_TASK_CONTROL_REF: main/);
  assert.match(workflow, /CHATGPT_AUTO_CONFIRM_TASK_CONTROL_POLL_SECONDS: "30"/);
  assert.match(
    workflow,
    /inputs\.parallel_queue_smoke && format\('chatgpt-auto-confirm-parallel-smoke-\{0\}-\{1\}'/,
  );
  assert.doesNotMatch(workflow, /Import dynamic parallel task inbox/);
  assert.match(workflow, /Verify dynamic parallel task queue/);
  assert.match(controller, /spawnSync\('gh'/);
  assert.match(controller, /repos\/\$\{repository\}\/contents\/\$\{repositoryPath\}/);
  assert.match(controller, /fetchRepositoryContent\(controlPath\)/);
  assert.match(controller, /task\._specDigest/);
  assert.match(controller, /entry\.sha/);
  assert.match(controller, /createHash\('sha256'\)/);
  assert.match(controller, /pollSeconds \* 1_000/);
  assert.match(controller, /ACTION_DISABLE_TASK_REFRESH: 'true'/);
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
  assert.ok(inbox.tasks.every(task => task.specSources === undefined || Array.isArray(task.specSources)));
  assert.ok(inbox.tasks.every(task => task.repository === 'bhrumom/fabushi'));
  assert.ok(inbox.tasks.every(task => typeof task.codeDirectory === 'string'));
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
  assert.match(controller, /resume_until_task_claimed/);
  assert.match(controller, /claimDeadline[\s\S]*native\('queue_pause'\)/);
  assert.match(controller, /wait_for_child_controller/);
  assert.match(controller, /runningEnded[\s\S]*previous_chat_finished/);
  assert.match(controller, /queued_chat_boundary/);
});

test('unchanged tasks continue while changed tasks replace only at the boundary', () => {
  assert.match(controller, /if \(exact\) \{/);
  assert.match(controller, /staleVersion && !isTerminal\(current\)/);
  assert.match(controller, /action: 'resume_until_task_claimed'/);
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

test('every dispatched work Chat receives one machine report contract', () => {
  assert.match(controller, /MAHAYANA_TASK_REPORT_CONTRACT_V4/);
  assert.match(controller, /"status":"incomplete"/);
  assert.match(controller, /"all_tasks_complete":false/);
  assert.doesNotMatch(controller, /MAHAYANA_TASK_WAIT_V1/);
  assert.match(controller, /"task_id":\$\{taskId\}/);
  assert.match(controller, /\.mahayana-project-email\.json/);
  assert.match(controller, /第一轮、续作轮和验收轮开始时使用 Gmail 按任务 id/);
  assert.match(controller, /禁止发送立项、进展或完成邮件/);
  assert.match(controller, /只有确实需要人工提供信息、权限、凭证或决策时/);
});

test('every round names the model, repository, task path, code path, and code-change gate', () => {
  assert.match(controller, /GPT-5\.6 Sol/);
  assert.match(controller, /Extra High/);
  assert.match(controller, /task\.repository \|\| repository/);
  assert.match(controller, /task\.documentDirectory/);
  assert.match(controller, /task\.codeDirectory/);
  assert.match(controller, /必须产生可核验的代码变更/);
});

test('task documents are optional and document bodies stay out of prompts', () => {
  assert.match(controller, /task\.documentDirectory/);
  assert.match(controller, /\/tree\/\$\{controlRef\}\/\$\{directory\}/);
  assert.match(controller, /只在消息中提供目录路径和文件夹链接/);
  assert.match(controller, /本任务没有配置任务文档/);
  assert.match(controller, /documentDirectory[\s\S]*\? directoryEntries\(documentDirectory\)[\s\S]*: \[\]/);
  assert.doesNotMatch(controller, /specificationFiles|specificationURLs/);
  assert.doesNotMatch(controller, /documentDirectory_and_codeDirectory_are_required/);
});

test('no standard task document names are required', () => {
  assert.doesNotMatch(controller, /README\.md|PRD\.md|TECHNICAL_DESIGN\.md|UI_UX\.md/);
});
