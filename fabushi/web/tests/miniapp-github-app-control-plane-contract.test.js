import test from 'node:test';
import assert from 'node:assert/strict';
import { assertGithubAppControlPlane } from '../src/miniapps/deployment-contract.js';

test('managed GitHub uses short-lived installation tokens only', () => {
  assert.equal(assertGithubAppControlPlane({ credentialType: 'installation-token' }).credentialType, 'installation-token');
});

test('managed GitHub rejects PAT and client credential exposure', () => {
  assert.throws(() => assertGithubAppControlPlane({ credentialType: 'organization-pat' }), /requires short-lived/);
  assert.throws(() => assertGithubAppControlPlane({ credentialType: 'installation-token', clientReceivesCredential: true }), /cannot be sent/);
});
