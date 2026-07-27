import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  chmodSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const controller = fileURLToPath(
  new URL('../scripts/run-actions-controller.mjs', import.meta.url));

test('Actions controller reports repeated terminal failures without chaining for six hours', () => {
  const directory = mkdtempSync(path.join(os.tmpdir(), 'chatgpt-actions-controller-'));
  const runtimePath = path.join(directory, 'fake-runtime.mjs');
  const resultPath = path.join(directory, 'action-result.json');
  try {
    writeFileSync(runtimePath, `#!/usr/bin/env node
const command = process.argv[2];
if (command === 'queue_watchdog') {
  console.log(JSON.stringify({ ok: true, recovered: true }));
} else if (command === 'queue_status') {
  console.log(JSON.stringify({
    ok: true,
    counts: { failed: 1 },
    tasks: [{
      id: 'broken-task',
      status: 'failed',
      attempts: 3,
      lastError: 'new_chat_prepare_failed',
      hiddenWorkerLastError: 'queue_monitor_hidden_target_rebuild_failed:missing',
    }],
  }));
} else {
  console.log(JSON.stringify({ ok: false, message: 'unexpected command' }));
  process.exitCode = 1;
}
`);
    chmodSync(runtimePath, 0o755);
    const result = spawnSync(process.execPath, [controller], {
      encoding: 'utf8',
      timeout: 5_000,
      env: {
        ...process.env,
        NODE_ENV: 'test',
        CHATGPT_AUTO_CONFIRM_NATIVE: runtimePath,
        ACTION_RESULT_PATH: resultPath,
        ACTION_SESSION_SECONDS: '2',
        ACTION_POLL_INTERVAL_MS: '10',
        ACTION_RECOVERY_INTERVAL_MS: '10',
        ACTION_MAX_SAME_FAILURE_RECOVERIES: '1',
      },
    });
    assert.equal(result.status, 1);
    assert.match(result.stdout, /WATCHDOG_RECOVERY/);
    assert.match(result.stdout, /ACTION_RESULT/);
    const report = JSON.parse(readFileSync(resultPath, 'utf8'));
    assert.equal(report.status, 'failed');
    assert.equal(report.reason, 'repeated_terminal_task_failure');
    assert.deepEqual(report.counts, { failed: 1 });
    assert.equal(report.tasks[0].id, 'broken-task');
    assert.equal(report.tasks[0].lastError, 'new_chat_prepare_failed');
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
