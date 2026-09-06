import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const workflowPath = new URL('../../.github/workflows/macos-interactive-app-e2e.yml', import.meta.url);
const exportPath = new URL('../scripts/export-ci-app-account-session.mjs', import.meta.url);
const renewPath = new URL('../scripts/renew-ci-app-account-session.mjs', import.meta.url);

async function workflow() {
  return readFile(workflowPath, 'utf8');
}

test('workflow owns the whole-session recording and App-owned account gateway contract', async () => {
  const [source, exporter] = await Promise.all([workflow(), readFile(exportPath, 'utf8')]);
  assert.match(source, /Start whole-session macOS recording/u);
  assert.match(source, /Install exact release DMG after recording has started/u);
  assert.match(source, /Login protected CI account and export App-owned session/u);
  assert.match(source, /DEVICE_ID: gha-\$\{\{ github\.run_id \}\}-\$\{\{ github\.run_attempt \}\}-macos-app/u);
  assert.match(source, /FABUSHI_CI_ACCOUNT_SESSION_FILE/u);
  assert.match(source, /export-ci-app-account-session\.mjs/u);
  assert.match(source, /renew-ci-app-account-session\.mjs/u);
  assert.match(source, /session-renewal\.log/u);
  assert.match(exporter, /ciRunner: true/u);
  assert.match(exporter, /provider: 'github-actions'/u);
  assert.doesNotMatch(exporter, /refreshToken:/u);
});

test('workflow forces the external semantic matrix and truthful final logout gate', async () => {
  const source = await workflow();
  for (const tool of [
    'fabushi.app.status',
    'fabushi.app.snapshot',
    'fabushi.app.find',
    'fabushi.app.action',
    'fabushi.app.wait',
    'fabushi.app.assert',
    'ci_session_status',
    'ci_session_note',
    'ci_session_finish',
  ]) {
    assert.match(source, new RegExp(tool.replaceAll('.', '\\.')));
  }
  assert.match(source, /TFI_MACOS_FULL_JOURNEY READY_FOR_LOGOUT PASS/u);
  assert.match(source, /settings-logout/u);
  assert.match(source, /finish-requested\.json/u);
});

test('macOS hold renews the private ordinary session while keeping the App projection refresh-token-free', async () => {
  const [source, renewSource] = await Promise.all([workflow(), readFile(renewPath, 'utf8')]);
  assert.match(source, /next_session_renewal=\$\(\(SECONDS \+ 240\)\)/u);
  assert.match(source, /renew-ci-app-account-session\.mjs/u);
  assert.match(source, /jq -e '\.refreshToken \| not'/u);
  assert.match(renewSource, /createFabushiAccountSessionStore/u);
  assert.match(renewSource, /store\.refresh\(current\)/u);
  assert.match(renewSource, /export-ci-app-account-session\.mjs/u);
  assert.doesNotMatch(renewSource, /FABUSHI_CI_TEST_PASSWORD/u);
});

test('truthful pass requires READY note, ci_session_finish, and the exact settings logout action', async () => {
  const source = await workflow();
  assert.match(source, /finish_requested=true/u);
  assert.match(source, /ready_note.*finish_requested.*logout_complete/su);
  assert.match(source, /ci_session_note ci_session_finish; do/u);
  assert.match(source, /finish-requested\.json/u);
  assert.match(source, /agentId == "settings-logout"/u);
});

test('whole-session recording is ordered before release resolution and installation', async () => {
  const source = await workflow();
  const record = source.indexOf('Start whole-session macOS recording');
  const resolve = source.indexOf('Resolve newest immutable macOS test release');
  const install = source.indexOf('Install exact release DMG after recording has started');
  assert.ok(record >= 0, 'recording step is missing');
  assert.ok(resolve > record, 'release resolution must happen after recording starts');
  assert.ok(install > resolve, 'installation must happen after release resolution');
});

test('workflow refuses non-App-owned devices in the operator contract', async () => {
  const source = await workflow();
  assert.match(source, /Do not use KRIS, old devices, pre-existing devices, or runner-owned gateways/u);
  assert.match(source, /Only the packaged App may register the macOS gateway\/device/u);
});

test('evidence is always uploaded and includes the external semantic trace', async () => {
  const source = await workflow();
  assert.match(source, /if: always\(\)/u);
  assert.match(source, /device-calls\.jsonl/u);
  assert.match(source, /remote-notes\.jsonl/u);
  assert.match(source, /macos-session\.mov/u);
  assert.match(source, /playwright-report/u);
  assert.match(source, /session-renewal\.log/u);
});
