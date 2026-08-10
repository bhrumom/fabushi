import test from 'node:test';
import assert from 'node:assert/strict';
import { createMcpAppIdentity } from '../src/domain/mcp-app-identity.js';

test('creates local first mcp app identity', () => {
  assert.deepEqual(createMcpAppIdentity({ appId: 'app.test' }), {
    appId: 'app.test',
    repositoryId: null,
    sourceCommit: null,
    sourceType: 'local-workspace',
    deploymentTarget: 'local-only',
  });
});

test('requires stable app id', () => {
  assert.throws(() => createMcpAppIdentity({}), /appId is required/);
});
