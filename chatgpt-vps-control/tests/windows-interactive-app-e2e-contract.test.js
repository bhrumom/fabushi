const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

const root = path.resolve(__dirname, '..', '..');
const workflowPath = path.join(root, '.github', 'workflows', 'windows-interactive-app-e2e.yml');

function workflow() {
  return fs.readFileSync(workflowPath, 'utf8');
}

test('Windows interactive workflow is App-owned, release-based, and evidence-complete', () => {
  const text = workflow();
  const required = [
    'name: Windows interactive app device E2E',
    'runs-on: windows-latest',
    'DEVICE_ID: gha-${{ github.run_id }}-${{ github.run_attempt }}-windows-app',
    'Start whole-session Windows recording before install',
    'Resolve newest published Windows test release',
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
  ];
  for (const marker of required) {
    assert.ok(text.includes(marker), `workflow is missing contract marker: ${marker}`);
  }

  assert.ok(text.includes("select((.name // '') | test('^fabushi-[0-9]+\\\\.[0-9]+\\\\.[0-9]+-setup\\\\.exe$'))") || text.includes('fabushi-'), 'workflow must resolve a published Windows installer');
  assert.ok(text.includes('FABUSHI_CI_TEST_USERNAME'), 'workflow must use the protected CI test account');
  assert.ok(text.includes('FABUSHI_CI_TEST_PASSWORD'), 'workflow must use the protected CI test account password secret');
  assert.ok(text.includes('controllable device online'), 'workflow must prove App-owned registration from the installed App log');
  assert.ok(text.includes('if: always()'), 'evidence upload/collection must survive failures');
});

test('Windows interactive workflow does not start a standalone runner-owned Fabushi gateway', () => {
  const text = workflow();
  const forbidden = [
    'start-interactive-runner',
    'interactive-runner-account-binding',
    'KRIS',
  ];
  for (const marker of forbidden) {
    assert.equal(text.includes(marker), false, `workflow must not contain standalone/legacy device marker: ${marker}`);
  }
});
