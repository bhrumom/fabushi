import test from 'node:test';
import assert from 'node:assert/strict';
import { createMcpAppIdentity, createSourceBinding, createWebDeployment, isDeployed, assertMcpAppIdentityRoundTrip } from '../src/domain/mcp-app-identity.js';

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

test('keeps github app transport separate from hosting', () => {
  const binding = createSourceBinding({
    provider: 'github',
    actor: 'platform',
    transport: 'github-app-api',
    repositoryId: 99,
  });
  assert.equal(binding.transport, 'github-app-api');
  assert.equal(createWebDeployment({ hostingProvider: 'cloudflare-workers', state: 'deployed' }).hostingProvider, 'cloudflare-workers');
});

test('rejects invalid hosting provider', () => {
  assert.throws(() => createWebDeployment({ hostingProvider: 'github', state: 'deployed' }));
});

test('rejects github binding without repository identity', () => {
  assert.throws(() => createSourceBinding({ provider: 'github', actor: 'user', transport: 'github-mcp' }));
});

test('identity serialization preserves app identity and source/deployment separation', () => {
  const identity = createMcpAppIdentity({
    appId: 'app-roundtrip',
    pluginId: 'plugin-roundtrip',
    sourceHost: 'github',
    sourceCustody: 'user-owned',
    repositoryId: 100,
  });
  const result = assertMcpAppIdentityRoundTrip(identity);
  assert.equal(result.appId, 'app-roundtrip');
  assert.equal(result.pluginId, 'plugin-roundtrip');
});
