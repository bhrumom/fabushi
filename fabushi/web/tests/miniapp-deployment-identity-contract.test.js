import assert from 'node:assert/strict';
import test from 'node:test';

import {
  marketplaceSourceLabels,
  normalizeMiniAppIdentity,
  serializeMiniAppIdentity,
  deserializeMiniAppIdentity,
} from '../src/miniapps/deployment-contract.js';

const CONFIG = {
  officialSourceOwner: 'bhrumom',
  managedUserAppsOwner: 'mahayana-user-apps',
};

const base = {
  author: 'alice',
  publisher: 'alice',
  officialStatus: 'user',
};

test('keeps local, managed GitHub, and user GitHub identities distinct', () => {
  const local = normalizeMiniAppIdentity({
    ...base,
    deploymentTarget: 'local-only',
  }, CONFIG);

  const managed = normalizeMiniAppIdentity({
    ...base,
    deploymentTarget: 'official-managed-github',
    provider: 'github',
    sourceHost: 'github',
    repositoryOwner: 'mahayana-user-apps',
    repositoryName: 'miniapp-demo',
    repositoryId: 1001,
  }, CONFIG);

  const user = normalizeMiniAppIdentity({
    ...base,
    deploymentTarget: 'user-github',
    provider: 'github',
    sourceHost: 'github',
    repositoryOwner: 'alice',
    repositoryName: 'miniapp-demo',
    repositoryId: 1002,
  }, CONFIG);

  assert.equal(local.provider, 'local');
  assert.equal(managed.transport, 'github-app-api');
  assert.equal(user.transport, 'github-mcp');
  assert.notEqual(managed.repositoryId, user.repositoryId);
});

test('identity serialization round trips without losing ownership boundary', () => {
  const value = {
    ...base,
    deploymentTarget: 'user-github',
    provider: 'github',
    sourceHost: 'github',
    repositoryOwner: 'alice',
    repositoryName: 'miniapp-demo',
    repositoryId: 1002,
  };

  const restored = deserializeMiniAppIdentity(serializeMiniAppIdentity(value, CONFIG), CONFIG);
  assert.equal(restored.repositoryId, 1002);
  assert.equal(restored.transport, 'github-mcp');
});

test('managed repositories cannot impersonate official source', () => {
  assert.throws(() => marketplaceSourceLabels({
    ...base,
    deploymentTarget: 'official-managed-github',
    provider: 'github',
    sourceHost: 'github',
    repositoryOwner: 'bhrumom',
    repositoryName: 'fake-user-app',
    repositoryId: 1003,
  }, CONFIG), (error) => error.code === 'managed_owner_trust_boundary');
});
