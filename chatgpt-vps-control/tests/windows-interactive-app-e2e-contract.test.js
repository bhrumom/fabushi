import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const contractPath = fileURLToPath(import.meta.url);
const here = path.dirname(contractPath);
const root = path.resolve(here, '..', '..');
const workflowPath = path.join(root, '.github', 'workflows', 'windows-interactive-app-e2e.yml');

function workflow() {
  return fs.readFileSync(workflowPath, 'utf8');
}

test('Windows workflow contract itself remains native ESM', () => {
  const source = fs.readFileSync(contractPath, 'utf8');
  assert.equal(/\brequire\s*\(/.test(source), false, 'contract must not regress to CommonJS require inside the type=module package');
});

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
    'No standalone Runner/KRIS/interactive-runner device agent is started.',
  ];
  for (const marker of required) {
    assert.ok(text.includes(marker), `workflow is missing contract marker: ${marker}`);
  }

  assert.ok(text.includes('fabushi-') && text.includes('-setup\\.exe'), 'workflow must resolve a published versioned Windows installer');
  assert.ok(text.includes('FABUSHI_CI_TEST_USERNAME'), 'workflow must use the protected CI test account');
  assert.ok(text.includes('FABUSHI_CI_TEST_PASSWORD'), 'workflow must use the protected CI test account password secret');
  assert.ok(text.includes('controllable device online'), 'workflow must prove App-owned registration from the installed App log');
  assert.ok(text.includes('if: always()'), 'evidence upload/collection must survive failures');
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
