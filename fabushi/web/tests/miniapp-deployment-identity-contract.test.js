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

test('keeps local, official, managed GitHub, and user GitHub identities orthogonal to hosting', () => {
  const local = normalizeMiniAppIdentity({
    ...base,
    deploymentTarget: 'local-only',
  }, CONFIG);

  const managed = normalizeMiniAppIdentity({
    ...base,
    deploymentTarget: 'official-managed-github',
    sourceProvider: 'github',
    sourceHost: 'github',
    repositoryOwner: 'mahayana-user-apps',
    repositoryName: 'miniapp-demo',
    repositoryId: 1001,
    hostingProvider: 'github-pages',
    runtimeProfile: 'web-static',
  }, CONFIG);

  const user = normalizeMiniAppIdentity({
    ...base,
    deploymentTarget: 'user-github',
    sourceProvider: 'github',
    sourceHost: 'github',
    repositoryOwner: 'alice',
    repositoryName: 'miniapp-demo',
    repositoryId: 1002,
    hostingProvider: 'cloudflare-workers',
    runtimeProfile: 'remote-edge',
  }, CONFIG);

  const official = normalizeMiniAppIdentity({
    author: 'fabushi',
    publisher: 'fabushi',
    officialStatus: 'official',
    deploymentTarget: 'official-source-github',
    sourceProvider: 'github',
    sourceHost: 'github',
    repositoryOwner: 'bhrumom',
    repositoryName: 'official-miniapp',
    repositoryId: 1003,
    hostingProvider: 'none',
    runtimeProfile: 'local-native',
  }, CONFIG);

  assert.deepEqual(
    {
      sourceHost: local.sourceHost,
      sourceCustody: local.sourceCustody,
      sourceProvider: local.sourceProvider,
      sourceActor: local.sourceActor,
      sourceTransport: local.sourceTransport,
      hostingProvider: local.hostingProvider,
    },
    {
      sourceHost: 'local',
      sourceCustody: 'device',
      sourceProvider: 'local',
      sourceActor: 'user',
      sourceTransport: 'local-fs',
      hostingProvider: 'none',
    },
  );
  assert.equal(managed.sourceCustody, 'platform-managed');
  assert.equal(managed.sourceTransport, 'github-app-api');
  assert.equal(managed.hostingProvider, 'github-pages');
  assert.equal(managed.runtimeProfile, 'web-static');
  assert.equal(user.sourceCustody, 'user-owned');
  assert.equal(user.sourceTransport, 'github-mcp');
  assert.equal(user.hostingProvider, 'cloudflare-workers');
  assert.equal(user.runtimeProfile, 'remote-edge');
  assert.equal(official.officialStatus, 'official');
  assert.equal(official.repositoryOwner, 'bhrumom');
  assert.equal(official.hostingProvider, 'none');
  assert.notEqual(managed.repositoryId, user.repositoryId);
});

test('identity serialization round trips without losing source custody or hosting boundaries', () => {
  const value = {
    ...base,
    deploymentTarget: 'user-github',
    sourceProvider: 'github',
    sourceActor: 'user',
    sourceTransport: 'github-mcp',
    sourceHost: 'github',
    sourceCustody: 'user-owned',
    repositoryOwner: 'alice',
    repositoryName: 'miniapp-demo',
    repositoryId: 1002,
    hostingProvider: 'none',
    runtimeProfile: 'local-web-wasm',
  };

  const restored = deserializeMiniAppIdentity(serializeMiniAppIdentity(value, CONFIG), CONFIG);
  assert.equal(restored.repositoryId, 1002);
  assert.equal(restored.sourceProvider, 'github');
  assert.equal(restored.sourceActor, 'user');
  assert.equal(restored.sourceTransport, 'github-mcp');
  assert.equal(restored.sourceCustody, 'user-owned');
  assert.equal(restored.hostingProvider, 'none');
  assert.equal(restored.runtimeProfile, 'local-web-wasm');
});

test('source hosting does not imply a web deployment', () => {
  const managedSourceOnly = normalizeMiniAppIdentity({
    ...base,
    deploymentTarget: 'official-managed-github',
    repositoryOwner: 'mahayana-user-apps',
    repositoryName: 'source-only',
    repositoryId: 1010,
    hostingProvider: 'none',
    runtimeProfile: 'local-web-wasm',
  }, CONFIG);

  assert.equal(managedSourceOnly.sourceHost, 'github');
  assert.equal(managedSourceOnly.sourceCustody, 'platform-managed');
  assert.equal(managedSourceOnly.hostingProvider, 'none');
  assert.notEqual(managedSourceOnly.runtimeProfile, 'web-static');
});

test('managed repositories cannot impersonate official source', () => {
  assert.throws(() => marketplaceSourceLabels({
    ...base,
    deploymentTarget: 'official-managed-github',
    sourceProvider: 'github',
    sourceHost: 'github',
    repositoryOwner: 'bhrumom',
    repositoryName: 'fake-user-app',
    repositoryId: 1004,
  }, CONFIG), (error) => error.code === 'managed_owner_mismatch');
});
