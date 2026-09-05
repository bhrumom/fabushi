import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const workflowPath = new URL('../../.github/workflows/macos-interactive-app-e2e.yml', import.meta.url);

async function workflow() {
  return readFile(workflowPath, 'utf8');
}

test('macOS interactive E2E keeps the installed app as the only device-registration owner', async () => {
  const source = await workflow();
  assert.match(source, /runs-on:\s*macos-15/u);
  assert.match(source, /Start whole-session macOS recording/u);
  assert.match(source, /Resolve newest published macOS test release/u);
  assert.match(source, /Install exact published macOS test app/u);
  assert.match(source, /login-ci-test-account\.mjs/u);
  assert.match(source, /export-ci-app-account-session\.mjs/u);
  assert.match(source, /FABUSHI_CI_ACCOUNT_SESSION_FILE/u);
  assert.match(source, /Launch installed Fabushi app and wait for App-owned registration/u);
  assert.match(source, /controllable device online/u);
  assert.match(source, /Hold for @fabushi test complete macOS journey/u);
  assert.match(source, /ci_session_finish/u);
  assert.match(source, /if:\s*always\(\)/u);
  assert.match(source, /Upload complete macOS interactive evidence even on failure/u);

  assert.doesNotMatch(source, /node\s+[^\n]*fabushi-device-agent\.js/u);
  assert.doesNotMatch(source, /interactive-runner-mcp/u);
  assert.doesNotMatch(source, /KRIS/u);
});

test('whole-session recording is ordered before release resolution and installation', async () => {
  const source = await workflow();
  const record = source.indexOf('Start whole-session macOS recording');
  const resolve = source.indexOf('Resolve newest published macOS test release');
  const install = source.indexOf('Install exact published macOS test app');
  assert.ok(record >= 0 && resolve > record && install > resolve);
});

test('evidence allowlist excludes account session files and includes required classes', async () => {
  const source = await workflow();
  const upload = source.slice(source.indexOf('Upload complete macOS interactive evidence even on failure'));
  assert.match(upload, /macos-session\.mov/u);
  assert.match(upload, /steps\//u);
  assert.match(upload, /device-calls\.jsonl/u);
  assert.match(upload, /playwright-report/u);
  assert.match(upload, /test-results/u);
  assert.match(upload, /fabushi-app\.log/u);
  assert.match(upload, /release\.json/u);
  assert.match(upload, /report\.json/u);
  assert.doesNotMatch(upload, /FABUSHI_ACCOUNT_SESSION_FILE/u);
  assert.doesNotMatch(upload, /FABUSHI_CI_ACCOUNT_SESSION_FILE/u);
});
