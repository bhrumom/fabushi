import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

import {
  createMcpAppIdentity,
  deserializeMcpAppIdentity,
  fromMcpAppIdentityRow,
  serializeMcpAppIdentity,
  toMcpAppIdentityRow,
  upgradeLegacyMcpAppIdentity,
  assertMcpAppIdentityRoundTrip,
} from '../src/domain/mcp-app-identity.js';

const here = dirname(fileURLToPath(import.meta.url));
const migration = fs.readFileSync(resolve(here, '../migrations/20260810_mcp_app_identity_schema.sql'), 'utf8');

function remote(overrides = {}) {
  return {
    appId: 'app.demo',
    pluginId: 'io.mahayana.alice.demo',
    author: 'alice',
    publisher: 'alice',
    deploymentTarget: 'user-github',
    repositoryId: 4242,
    repositoryOwner: 'alice',
    repositoryName: 'demo',
    sourceCommit: 'a'.repeat(40),
    ...overrides,
  };
}

test('creates a local-first identity with orthogonal source and hosting fields', () => {
  const identity = createMcpAppIdentity({ appId: 'app.test' });
  assert.equal(identity.pluginId, 'app.test');
  assert.equal(identity.author, 'unknown');
  assert.equal(identity.sourceHost, 'local');
  assert.equal(identity.sourceCustody, 'device');
  assert.equal(identity.sourceProvider, 'local');
  assert.equal(identity.sourceActor, 'user');
  assert.equal(identity.sourceTransport, 'local-fs');
  assert.equal(identity.hostingProvider, 'none');
  assert.equal(identity.runtimeProfile, 'local-web-wasm');
  assert.equal(identity.deploymentTarget, 'local-only');
  assert.equal(identity.sourceState, 'local-only');
  assert.equal(identity.webDeploymentState, 'none');
  assert.equal(Object.hasOwn(identity, 'deployed'), false);
});

test('represents official, managed-user, and user GitHub sources independently from web hosting', () => {
  const managed = createMcpAppIdentity(remote({
    deploymentTarget: 'official-managed-github',
    repositoryId: 5001,
    repositoryOwner: 'mahayana-hosted-01',
    hostingProvider: 'github-pages',
    runtimeProfile: 'web-static',
  }));
  const user = createMcpAppIdentity(remote({
    repositoryId: 5002,
    hostingProvider: 'cloudflare-workers',
    runtimeProfile: 'remote-edge',
  }));
  const official = createMcpAppIdentity(remote({
    appId: 'app.official',
    pluginId: 'io.mahayana.official.demo',
    author: 'fabushi',
    publisher: 'fabushi',
    officialStatus: 'official',
    deploymentTarget: 'official-source-github',
    repositoryId: 5003,
    repositoryOwner: 'bhrumom',
    hostingProvider: 'none',
  }));

  assert.deepEqual(
    [managed.sourceCustody, managed.sourceActor, managed.sourceTransport, managed.hostingProvider],
    ['platform-managed', 'platform', 'github-app-api', 'github-pages'],
  );
  assert.deepEqual(
    [user.sourceCustody, user.sourceActor, user.sourceTransport, user.hostingProvider],
    ['user-owned', 'user', 'github-mcp', 'cloudflare-workers'],
  );
  assert.equal(official.officialStatus, 'official');
  assert.equal(official.repositoryOwner, 'bhrumom');
  assert.equal(official.hostingProvider, 'none');
  assert.notEqual(managed.repositoryId, user.repositoryId);
});

test('serialization round-trips every source identity field without inventing deployment', () => {
  const sourceHosted = createMcpAppIdentity(remote({
    hostingProvider: 'none',
    webDeploymentState: 'none',
  }));
  const restored = deserializeMcpAppIdentity(serializeMcpAppIdentity(sourceHosted));
  assert.deepEqual(restored, sourceHosted);
  assert.equal(restored.sourceState, 'source-hosted');
  assert.equal(restored.hostingProvider, 'none');
  assert.equal(restored.webDeploymentState, 'none');
  assert.equal(Object.hasOwn(restored, 'deployed'), false);

  const row = toMcpAppIdentityRow(restored);
  assert.equal(row.source_provider, 'github');
  assert.equal(row.source_transport, 'github-mcp');
  assert.equal(row.hosting_provider, 'none');
  assert.equal(row.web_deployment_state, 'none');
});



test('database row round-trip preserves every canonical identity dimension', () => {
  const identity = createMcpAppIdentity(remote({
    deploymentTarget: 'official-managed-github',
    repositoryId: 8123,
    repositoryOwner: 'mahayana-hosted-01',
    repositoryName: 'miniapp-demo-8123',
    publisher: 'user-42',
    officialStatus: 'community',
    hostingProvider: 'github-pages',
    runtimeProfile: 'web-static',
    webDeploymentState: 'deployed',
  }));
  const restored = fromMcpAppIdentityRow(toMcpAppIdentityRow(identity));
  assert.deepEqual(restored, identity);
  assert.equal(restored.sourceState, 'source-hosted');
  assert.equal(restored.webDeploymentState, 'deployed');
});

test('upgrades the v0 source type and web target without losing source identity', () => {
  const upgraded = upgradeLegacyMcpAppIdentity({
    appId: 'app.legacy',
    repositoryId: '7001',
    sourceCommit: 'b'.repeat(40),
    sourceType: 'user-github',
    deploymentTarget: 'cloudflare',
  });
  assert.equal(upgraded.repositoryId, 7001);
  assert.equal(upgraded.sourceCommit, 'b'.repeat(40));
  assert.equal(upgraded.sourceHost, 'github');
  assert.equal(upgraded.sourceCustody, 'user-owned');
  assert.equal(upgraded.sourceProvider, 'github');
  assert.equal(upgraded.sourceActor, 'user');
  assert.equal(upgraded.sourceTransport, 'github-mcp');
  assert.equal(upgraded.deploymentTarget, 'user-github');
  assert.equal(upgraded.hostingProvider, 'cloudflare-workers');
  assert.equal(upgraded.runtimeProfile, 'remote-edge');
  assert.equal(upgraded.webDeploymentState, 'none');
});

test('migration upgrades legacy rows and does not conflate source-hosted with deployed', () => {
  const db = new DatabaseSync(':memory:');
  db.exec(`
    CREATE TABLE mcp_app_identity (
      app_id TEXT PRIMARY KEY,
      repository_id TEXT,
      source_commit TEXT,
      source_type TEXT NOT NULL DEFAULT 'local-workspace',
      deployment_target TEXT NOT NULL DEFAULT 'local-only',
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  `);
  db.prepare(`
    INSERT INTO mcp_app_identity(app_id, repository_id, source_commit, source_type, deployment_target)
    VALUES (?, ?, ?, ?, ?)
  `).run('app.legacy.user', '9001', 'c'.repeat(40), 'user-github', 'github-pages');
  db.prepare(`
    INSERT INTO mcp_app_identity(app_id, repository_id, source_commit, source_type, deployment_target)
    VALUES (?, ?, ?, ?, ?)
  `).run('app.legacy.local', null, null, 'local-workspace', 'local-only');

  db.exec(migration);

  const columns = db.prepare('PRAGMA table_info(mcp_app_identity)').all().map((row) => row.name);
  for (const field of [
    'author', 'source_host', 'source_custody', 'source_provider', 'source_actor', 'source_transport',
    'repository_id', 'publisher', 'official_status', 'hosting_provider', 'runtime_profile',
    'deployment_target', 'source_state', 'web_deployment_state', 'source_identity_json',
  ]) assert.ok(columns.includes(field), `missing migrated column ${field}`);
  assert.equal(columns.includes('deployed'), false);

  const user = db.prepare('SELECT * FROM mcp_app_identity WHERE app_id = ?').get('app.legacy.user');
  assert.equal(user.repository_id, 9001);
  assert.equal(user.source_commit, 'c'.repeat(40));
  assert.equal(user.source_host, 'github');
  assert.equal(user.source_custody, 'user-owned');
  assert.equal(user.source_provider, 'github');
  assert.equal(user.source_actor, 'user');
  assert.equal(user.source_transport, 'github-mcp');
  assert.equal(user.deployment_target, 'user-github');
  assert.equal(user.hosting_provider, 'github-pages');
  assert.equal(user.runtime_profile, 'web-static');
  assert.equal(user.source_state, 'source-hosted');
  assert.equal(user.web_deployment_state, 'none');
  assert.equal(JSON.parse(user.source_identity_json).repositoryId, 9001);

  const local = db.prepare('SELECT * FROM mcp_app_identity WHERE app_id = ?').get('app.legacy.local');
  assert.equal(local.source_host, 'local');
  assert.equal(local.source_custody, 'device');
  assert.equal(local.hosting_provider, 'none');
  assert.equal(local.source_state, 'local-only');
  assert.equal(local.web_deployment_state, 'none');
});

test('rejects spoofed source identity fields and official status', () => {
  assert.throws(
    () => createMcpAppIdentity(remote({ sourceTransport: 'github-app-api' })),
    (error) => error.code === 'source_identity_conflict',
  );
  assert.throws(
    () => createMcpAppIdentity(remote({ officialStatus: 'official' })),
    (error) => error.code === 'official_status_forbidden',
  );
});


test('round trip helper preserves source custody and transport boundary', () => {
  const identity = assertMcpAppIdentityRoundTrip(remote({
    hostingProvider: 'cloudflare-pages',
    runtimeProfile: 'web-static',
  }));
  assert.equal(identity.sourceCustody, 'user-owned');
  assert.equal(identity.sourceTransport, 'github-mcp');
  assert.equal(identity.hostingProvider, 'cloudflare-pages');
});
