import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const workflowPath = new URL('../../.github/workflows/macos-interactive-app-e2e.yml', import.meta.url);
const loginPath = new URL('../scripts/login-ci-test-account.mjs', import.meta.url);
const exportPath = new URL('../scripts/export-ci-app-account-session.mjs', import.meta.url);
const renewPath = new URL('../scripts/renew-ci-app-account-session.mjs', import.meta.url);
const sessionStorePath = new URL('../lib/fabushi-account-session.js', import.meta.url);
const recorderPath = new URL('../scripts/fcm-010-13-macos-session-recorder.sh', import.meta.url);
const recorderVideoPath = new URL('../scripts/fcm-010-13-macos-session-video.swift', import.meta.url);

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
  assert.match(source, /release:\s*\n\s*types: \[published\]/u);
  assert.match(source, /startsWith\(github\.event\.release\.tag_name, 'desktop-'\)/u);
  assert.match(source, /workflow_dispatch:/u);
  assert.doesNotMatch(source, /\n  push:/u);
  assert.match(source, /Start whole-session macOS recording/u);
  assert.match(source, /Wait for exact-main published macOS test release/u);
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

test('Action-owned semantic smoke runs after App registration and before the external full journey', async () => {
  const source = await workflow();
  const launch = source.indexOf('Launch installed Fabushi app and wait for App-owned registration');
  const smoke = source.indexOf('Run Action-owned packaged App Agent semantic smoke');
  const hold = source.indexOf('Hold for @fabushi test complete macOS journey');
  assert.ok(launch >= 0 && smoke > launch && hold > smoke);
  assert.match(source, /run-app-agent-ci-smoke\.mjs/u);
  assert.match(source, /action-owned-app-agent-smoke\.json/u);
  assert.match(source, /fabushi\.app-agent-ci-smoke\.v1/u);
  assert.match(source, /ACTION_SMOKE_OUTCOME/u);
  assert.match(source, /test "\$ACTION_SMOKE_OUTCOME" = success/u);
  assert.match(source, /index\("action"\)/u);
  assert.match(source, /index\("assert"\)/u);
});

test('macOS release resolver waits for and accepts only the exact workflow source SHA', async () => {
  const source = await workflow();
  assert.match(source, /deadline=\$\(\(SECONDS \+ 1200\)\)/u);
  assert.match(source, /resolved_target.*GITHUB_SHA/su);
  assert.match(source, /test "\$resolved_target" = "\$GITHUB_SHA"/u);
  assert.match(source, /Waiting for published macOS release bound to \$GITHUB_SHA/u);
  assert.match(source, /No published macOS release bound to exact workflow source \$GITHUB_SHA appeared within 20 minutes/u);
  assert.match(source, /sleep 15/u);
  assert.match(source, /select\(\.draft == false\)/u);
  assert.doesNotMatch(source, /select\(\.draft == false and \.prerelease == true\)/u);
  assert.doesNotMatch(source, /Resolve newest published macOS test release/u);
  assert.doesNotMatch(source, /sort_by\(\.published_at \/\/ \.created_at\) \| last/u);
});

test('macOS recovery release validates bundle SemVer from the strict asset name, not the tag', async () => {
  const source = await workflow();
  assert.match(source, /ASSET_NAME:\s*\$\{\{ steps\.release\.outputs\.asset_name \}\}/u);
  assert.match(source, /expected="\$\{ASSET_NAME#fabushi-\}"/u);
  assert.match(source, /expected="\$\{expected%-macos-arm64\.zip\}"/u);
  assert.match(source, /\[\[ "\$expected" =~ \^\[0-9\]\+\\\.\[0-9\]\+\\\.\[0-9\]\+\$ \]\]/u);
  assert.doesNotMatch(source, /expected="\$\{RELEASE_TAG#v\}"/u);
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

test('truthful pass requires READY note, ci_session_finish, exact settings logout, and non-zero real remote App actions', async () => {
  const source = await workflow();
  assert.match(source, /finish_requested=true/u);
  assert.match(source, /ready_note.*finish_requested.*logout_complete/su);
  assert.match(source, /ci_session_note ci_session_finish; do/u);
  assert.match(source, /finish-requested\.json/u);
  assert.match(source, /agentId == "settings-logout"/u);
  assert.match(source, /remote_action_count/u);
  assert.match(source, /test "\$remote_action_count" -gt 0/u);
  assert.match(source, /remoteActionCount/u);
});

test('whole-session recording is ordered before exact-main release resolution and installation', async () => {
  const source = await workflow();
  const record = source.indexOf('Start whole-session macOS recording');
  const resolve = source.indexOf('Wait for exact-main published macOS test release');
  const install = source.indexOf('Install exact published macOS test app');
  assert.ok(record >= 0 && resolve > record && install > resolve);
});

test('whole-session recorder detects the GitHub-hosted paravirtual display, rejects PID-only success, and requires decoded playable MOV evidence', async () => {
  const [source, recorderSource, videoSource] = await Promise.all([
    workflow(),
    readFile(recorderPath, 'utf8'),
    readFile(recorderVideoPath, 'utf8'),
  ]);
  assert.match(source, /fcm-010-13-macos-session-recorder\.sh start/u);
  assert.match(source, /fcm-010-13-macos-session-recorder\.sh assert-live/u);
  assert.match(source, /fcm-010-13-macos-session-recorder\.sh stop/u);
  assert.match(source, /fcm-010-13-macos-session-recorder\.sh verify/u);
  assert.doesNotMatch(source, /screencapture -v -V 3300/u);
  assert.match(source, /recorder-stop-exit\.txt/u);
  assert.match(source, /recorderPlayable/u);
  assert.match(recorderSource, /AppleM2ScalerParavirtDriver/u);
  assert.match(recorderSource, /native_probe/u);
  assert.match(recorderSource, /fallback_probe/u);
  assert.match(recorderSource, /frame-avassetwriter/u);
  assert.match(recorderSource, /first_sample=decoded/u);
  assert.match(recorderSource, /fallbackRecorderPlayable/u);
  assert.match(recorderSource, /recorder-preflight\.json/u);
  assert.match(videoSource, /AVAssetWriter/u);
  assert.match(videoSource, /AVAssetReader/u);
  assert.match(videoSource, /copyNextSampleBuffer/u);
  assert.match(videoSource, /duration_seconds=/u);
});

test('packaged secondary evidence includes the exact assistant semantic projection journey regression', async () => {
  const source = await workflow();
  assert.match(source, /e2e\/app-agent-surface\.spec\.ts e2e\/fcm-010-13-assistant-projection\.spec\.ts/u);
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
  assert.match(source, /recorder-final\.json/u);
  assert.match(source, /action-owned-app-agent-smoke\.json/u);
  const collection = stepBlock(
    source,
    'Collect macOS App, device-call, Playwright, and release evidence',
    'Upload complete macOS interactive evidence even on failure',
  );
  assert.match(collection, /steps\/999-final\.png/u);
  assert.match(collection, /device-calls\.jsonl/u);
  assert.match(collection, /fabushi-system\.log/u);
  assert.match(collection, /releaseTag/u);
  assert.match(collection, /actionSmokeStatus/u);
  assert.match(collection, /report\.json/u);
});
