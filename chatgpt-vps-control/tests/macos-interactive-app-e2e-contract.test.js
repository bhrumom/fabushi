import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const workflowPath = new URL('../../.github/workflows/macos-interactive-app-e2e.yml', import.meta.url);
const loginPath = new URL('../scripts/login-ci-test-account.mjs', import.meta.url);
const exportPath = new URL('../scripts/export-ci-app-account-session.mjs', import.meta.url);
const renewPath = new URL('../scripts/renew-ci-app-account-session.mjs', import.meta.url);
const sessionStorePath = new URL('../lib/fabushi-account-session.js', import.meta.url);

async function workflow() {
  return readFile(workflowPath, 'utf8');
}

function stepBlock(source, stepName, nextStepName) {
  const start = source.indexOf(`- name: ${stepName}`);
  assert.ok(start >= 0, `missing step: ${stepName}`);
  const end = nextStepName ? source.indexOf(`- name: ${nextStepName}`, start + 1) : source.length;
  assert.ok(end > start, `missing next step after: ${stepName}`);
  return source.slice(start, end);
}

test('macOS interactive E2E keeps the installed app as the only device-registration owner', async () => {
  const source = await workflow();
  assert.match(source, /runs-on:\s*macos-15/u);
  assert.match(source, /Start whole-session macOS recording/u);
  assert.match(source, /Resolve newest published macOS test release/u);
  assert.match(source, /Install exact published macOS test app/u);
  assert.match(source, /login-ci-test-account\.mjs/u);
  assert.match(source, /export-ci-app-account-session\.mjs/u);
  assert.match(source, /renew-ci-app-account-session\.mjs/u);
  assert.match(source, /session-renewal\.log/u);
  assert.match(source, /FABUSHI_CI_ACCOUNT_SESSION_FILE/u);
  assert.match(source, /Launch installed Fabushi app and wait for App-owned registration/u);
  assert.match(source, /controllable device online/u);
  assert.match(source, /Hold for @fabushi test complete macOS journey/u);
  assert.match(source, /ci_session_finish/u);
  assert.match(source, /if:\s*always\(\)/u);
  assert.match(source, /Upload complete macOS interactive evidence even on failure/u);
  assert.match(source, /No standalone Runner\/KRIS\/interactive-runner device agent is started/u);

  assert.doesNotMatch(source, /node\s+[^\n]*fabushi-device-agent\.js/u);
  assert.doesNotMatch(source, /uses:\s*[^\n]*interactive-runner/iu);
  assert.doesNotMatch(source, /run:\s*[^\n]*(?:KRIS|interactive-runner)/iu);
});

test('protected account helpers accept the App-owned macOS Actions id without assigning gateway ownership', async () => {
  const [loginSource, exportSource, sessionStoreSource] = await Promise.all([
    readFile(loginPath, 'utf8'),
    readFile(exportPath, 'utf8'),
    readFile(sessionStorePath, 'utf8'),
  ]);
  for (const source of [loginSource, exportSource, sessionStoreSource]) {
    assert.match(source, /macos-app/u);
  }
  assert.match(loginSource, /protected GitHub Actions test device id/u);
  assert.match(exportSource, /do not grant device-gateway ownership/u);
  assert.match(sessionStoreSource, /does not mean the Actions runner owns device registration/u);
  assert.doesNotMatch(loginSource, /must be the protected interactive Runner id/u);
  assert.doesNotMatch(exportSource, /must be the protected interactive Runner id/u);
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
  const resolve = source.indexOf('Resolve newest published macOS test release');
  const install = source.indexOf('Install exact published macOS test app');
  assert.ok(record >= 0 && resolve > record && install > resolve);
});

test('evidence upload allowlist excludes private account sessions and includes required classes', async () => {
  const source = await workflow();
  const upload = stepBlock(
    source,
    'Upload complete macOS interactive evidence even on failure',
    'Remove private account material and temporary app data',
  );
  assert.match(upload, /macos-interactive-evidence\//u);
  assert.match(upload, /playwright-report\//u);
  assert.match(upload, /test-results\//u);
  assert.doesNotMatch(upload, /FABUSHI_ACCOUNT_SESSION_FILE/u);
  assert.doesNotMatch(upload, /FABUSHI_CI_ACCOUNT_SESSION_FILE/u);

  assert.match(source, /macos-session\.mov/u);
  const collection = stepBlock(
    source,
    'Collect macOS App, device-call, Playwright, and release evidence',
    'Upload complete macOS interactive evidence even on failure',
  );
  assert.match(collection, /steps\/999-final\.png/u);
  assert.match(collection, /device-calls\.jsonl/u);
  assert.match(collection, /fabushi-system\.log/u);
  assert.match(collection, /releaseTag/u);
  assert.match(collection, /report\.json/u);
});
