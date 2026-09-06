import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const contractPath = fileURLToPath(import.meta.url);
const here = path.dirname(contractPath);
const root = path.resolve(here, '..', '..');
const workflowPath = path.join(root, '.github', 'workflows', 'windows-interactive-app-e2e.yml');
const loginPath = path.join(root, 'chatgpt-vps-control', 'scripts', 'login-ci-test-account.mjs');
const exportPath = path.join(root, 'chatgpt-vps-control', 'scripts', 'export-ci-app-account-session.mjs');
const sessionStorePath = path.join(root, 'chatgpt-vps-control', 'lib', 'fabushi-account-session.js');

function workflow() {
  return fs.readFileSync(workflowPath, 'utf8');
}

test('Windows workflow contract itself remains native ESM', () => {
  const source = fs.readFileSync(contractPath, 'utf8');
  assert.equal(/\brequire\s*\(/.test(source), false, 'contract must not regress to CommonJS require inside the type=module package');
});

test('Windows interactive workflow is App-owned, exact-release-bound, and evidence-complete', () => {
  const text = workflow();
  const required = [
    'name: Windows interactive app device E2E',
    'runs-on: windows-latest',
    'DEVICE_ID: gha-${{ github.run_id }}-${{ github.run_attempt }}-windows-app',
    'Start whole-session Windows recording before install',
    'Wait for exact-main published Windows test release',
    '$deadline = (Get-Date).AddMinutes(20)',
    '$resolvedTarget -ne $env:GITHUB_SHA',
    '$targetSha -ne $env:GITHUB_SHA',
    'No published Windows installer release bound to exact workflow source',
    'Start-Sleep -Seconds 15',
    'Install exact published Windows test app',
    'Login protected Fabushi test account and export bounded app session',
    'Launch installed Fabushi app and wait for App-owned registration',
    'Hold for @fabushi test complete Windows journey',
    'fabushi.app.status',
    'fabushi.app.snapshot',
    'fabushi.app.find',
    'fabushi.app.action',
    'fabushi.app.wait',
    'fabushi.app.assert',
    'TFI_WINDOWS_FULL_JOURNEY READY_FOR_LOGOUT PASS categories=',
    'settings-logout',
    'Upload complete Windows interactive evidence even on failure',
    'retention-days: 90',
    'device-calls.jsonl',
    'remote-notes.jsonl',
    'windows-session.mp4',
    'report.json',
    'No standalone Runner/KRIS/interactive-runner device agent is started.',
  ];
  for (const marker of required) {
    assert.ok(text.includes(marker), `workflow is missing contract marker: ${marker}`);
  }

  assert.equal(text.includes('Resolve newest published Windows test release'), false, 'workflow must not select the globally newest release');
  assert.equal(text.includes('$release = $candidates[-1]'), false, 'workflow must not fall back to the newest candidate regardless of source SHA');
  assert.ok(text.includes('fabushi-') && text.includes('-setup\\.exe'), 'workflow must resolve a published versioned Windows installer');
  assert.ok(text.includes('FABUSHI_CI_TEST_USERNAME'), 'workflow must use the protected CI test account');
  assert.ok(text.includes('FABUSHI_CI_TEST_PASSWORD'), 'workflow must use the protected CI test account password secret');
  assert.ok(text.includes('controllable device online'), 'workflow must prove App-owned registration from the installed App log');
  assert.ok(text.includes('if: always()'), 'evidence upload/collection must survive failures');
});

test('protected account helpers accept the App-owned Windows Actions id without widening to arbitrary devices', () => {
  for (const helperPath of [loginPath, exportPath, sessionStorePath]) {
    const source = fs.readFileSync(helperPath, 'utf8');
    assert.match(source, /windows-app/u);
    assert.ok(source.includes('^gha-[0-9]+-[0-9]+-(?:interactive|ios-app|macos-app|windows-app)$'));
  }
});

test('protected login session path validation stays platform-aware for Windows RUNNER_TEMP', () => {
  const source = fs.readFileSync(loginPath, 'utf8');
  assert.ok(source.includes('import { resolve, sep } from "node:path";'));
  assert.ok(source.includes('const path = resolve(rawPath);'));
  assert.ok(source.includes('const root = resolve(rawRoot);'));
  assert.ok(source.includes('path.startsWith(`${root}${sep}`)'));
  assert.equal(source.includes('process.env.RUNNER_TEMP}/'), false, 'login helper must not hard-code a POSIX separator for RUNNER_TEMP');
});

test('Windows interactive workflow does not start a standalone runner-owned Fabushi gateway', () => {
  const text = workflow();
  const forbiddenExecutionMarkers = [
    'start-interactive-runner',
    'interactive-runner-account-binding',
    'run-interactive-device-agent',
  ];
  for (const marker of forbiddenExecutionMarkers) {
    assert.equal(text.includes(marker), false, `workflow must not contain standalone runner execution marker: ${marker}`);
  }
});
