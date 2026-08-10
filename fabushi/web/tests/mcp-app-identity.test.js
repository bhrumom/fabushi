import test from 'node:test';
import assert from 'node:assert/strict';
import { createMcpAppIdentity, createWebDeployment, isDeployed } from '../src/domain/mcp-app-identity.js';

test('source hosted does not imply web deployed', () => {
  const identity = createMcpAppIdentity({
    appId: 'app-1',
    pluginId: 'plugin-1',
    sourceHost: 'github',
    sourceCustody: 'platform-managed',
    repositoryId: 42,
  });
  const deployment = createWebDeployment({ hostingProvider: 'none', runtimeProfile: 'local-web-wasm', state: 'none' });
  assert.equal(identity.repositoryId, 42);
  assert.equal(isDeployed(deployment), false);
});

test('rejects invalid hosting provider', () => {
  assert.throws(() => createWebDeployment({ hostingProvider: 'github', state: 'deployed' }));
});
