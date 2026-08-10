import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createManagedRepositoryName,
  createManagedRepositoryProvisioner,
  selectManagedRepositoryShard,
} from '../src/miniapps/deployment-contract.js';

function createClaimsStore() {
  const entries = new Map();
  return {
    async get(key) { return entries.get(key) ?? null; },
    async claim(key, value) {
      if (entries.has(key)) return { created: false, claim: entries.get(key) };
      entries.set(key, { ...value });
      return { created: true, claim: entries.get(key) };
    },
    async update(key, patch) {
      const next = { ...(entries.get(key) ?? {}), ...patch };
      entries.set(key, next);
      return next;
    },
  };
}

const shards = [
  { owner: 'mahayana-hosted-02', repositoryCount: 120, hardStopRepositoryCount: 40000 },
  { owner: 'mahayana-hosted-01', repositoryCount: 12, hardStopRepositoryCount: 40000 },
];

const request = {
  subjectId: 'user-42',
  idempotencyKey: 'deploy-key-42',
  deploymentId: 'deployment-42',
  snapshotSha256: 'a'.repeat(64),
  slug: 'lotus-notes',
  publicId: '7f31ab',
  piiValues: ['alice@example.com', '+1 415 555 0100', 'Alice Example'],
  shards,
};

test('managed repository shard routing fails closed at capacity and excludes official source org', () => {
  assert.equal(selectManagedRepositoryShard(shards).owner, 'mahayana-hosted-01');
  assert.throws(() => selectManagedRepositoryShard([
    { owner: 'bhrumom', repositoryCount: 0, hardStopRepositoryCount: 40000 },
  ]), (error) => error.code === 'managed_owner_trust_boundary');
  assert.throws(() => selectManagedRepositoryShard([
    { owner: 'mahayana-hosted-01', repositoryCount: 40000, hardStopRepositoryCount: 40000 },
    { owner: 'mahayana-hosted-02', repositoryCount: 25, hardStopRepositoryCount: 40000, acceptingNewRepositories: false },
  ]), (error) => error.code === 'managed_shard_capacity_exhausted');
  assert.throws(() => selectManagedRepositoryShard([
    { owner: 'mahayana-hosted-03', repositoryCount: 10 },
  ]), (error) => error.code === 'managed_shard_capacity_invalid');
});

test('managed repository names reject direct and configured PII', () => {
  assert.equal(createManagedRepositoryName({ slug: 'Lotus Notes', publicId: '7F31AB' }), 'miniapp-lotus-notes-7f31ab');
  assert.throws(() => createManagedRepositoryName({ slug: 'alice@example.com', publicId: '7f31ab' }), (error) => error.code === 'repository_name_pii');
  assert.throws(() => createManagedRepositoryName({ slug: 'alice-example-project', publicId: '7f31ab', piiValues: ['Alice Example'] }), (error) => error.code === 'repository_name_pii');
});

test('concurrent and repeated provisioning returns one stable GitHub repository id', async () => {
  const claims = createClaimsStore();
  let createCalls = 0;
  let repository = null;
  const github = {
    async createRepository({ owner, name }) {
      createCalls += 1;
      await new Promise((resolve) => setTimeout(resolve, 15));
      repository = { repositoryId: 99001, owner, name };
      return repository;
    },
    async reconcileRepository() { return repository; },
  };
  const provision = createManagedRepositoryProvisioner({ claims, github });
  const [first, second] = await Promise.all([provision(request), provision(request)]);
  const retried = await provision(request);
  assert.equal(createCalls, 1);
  assert.equal(first.repositoryId, 99001);
  assert.equal(second.repositoryId, 99001);
  assert.equal(retried.repositoryId, 99001);
  assert.equal(first.repositoryOwner, 'mahayana-hosted-01');
  assert.equal(first.repositoryName, 'miniapp-lotus-notes-7f31ab');
});

test('unknown GitHub create outcomes reconcile before any retry', async () => {
  const claims = createClaimsStore();
  let createCalls = 0;
  let repository = null;
  const github = {
    async createRepository({ owner, name }) {
      createCalls += 1;
      repository = { repositoryId: 99002, owner, name };
      const error = new Error('connection reset after create');
      error.outcomeUnknown = true;
      throw error;
    },
    async reconcileRepository() { return repository; },
  };
  const provision = createManagedRepositoryProvisioner({ claims, github });
  const first = await provision({ ...request, idempotencyKey: 'unknown-42', deploymentId: 'deployment-unknown-42' });
  const second = await provision({ ...request, idempotencyKey: 'unknown-42', deploymentId: 'deployment-unknown-42' });
  assert.equal(createCalls, 1);
  assert.equal(first.repositoryId, 99002);
  assert.equal(second.repositoryId, 99002);
});

test('reusing an idempotency key for a different source snapshot is rejected', async () => {
  const claims = createClaimsStore();
  const github = {
    async createRepository() { return { repositoryId: 99003 }; },
    async reconcileRepository() { return null; },
  };
  const provision = createManagedRepositoryProvisioner({ claims, github });
  await provision({ ...request, idempotencyKey: 'conflict-key', deploymentId: 'conflict-deployment' });
  await assert.rejects(
    provision({ ...request, idempotencyKey: 'conflict-key', deploymentId: 'conflict-deployment', snapshotSha256: 'b'.repeat(64) }),
    (error) => error.code === 'idempotency_conflict',
  );
});
