import test from 'node:test';
import assert from 'node:assert/strict';

import {
  createDeterministicSourceSnapshot,
  verifyManagedInitialSourcePush,
} from '../src/miniapps/deployment-contract.js';

async function gitBlobSha1(content) {
  const contentBytes = new TextEncoder().encode(content);
  const headerBytes = new TextEncoder().encode(`blob ${contentBytes.byteLength}\0`);
  const payload = new Uint8Array(headerBytes.byteLength + contentBytes.byteLength);
  payload.set(headerBytes);
  payload.set(contentBytes, headerBytes.byteLength);
  const digest = await crypto.subtle.digest('SHA-1', payload);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

const files = [
  { path: 'README.md', content: '# Lotus\n' },
  { path: 'src/app.js', content: "export const lotus = 'bloom';\n" },
];

async function fixtures(overrides = {}) {
  const snapshot = await createDeterministicSourceSnapshot(files);
  const remoteFiles = await Promise.all(snapshot.files.map(async (file) => ({
    path: file.path,
    type: 'blob',
    sha: await gitBlobSha1(file.content),
  })));
  const provisioning = {
    state: 'created',
    repositoryId: 99011,
    repositoryOwner: 'mahayana-hosted-01',
    repositoryName: 'miniapp-lotus-7f31ab',
    snapshotSha256: snapshot.sourceArchiveSha256,
  };
  const pushReceipt = {
    managedOrgId: 'managed-org-01',
    repositoryId: 99011,
    repositoryOwner: 'mahayana-hosted-01',
    repositoryName: 'miniapp-lotus-7f31ab',
    defaultBranch: 'main',
    commit: '1'.repeat(40),
    treeHash: '2'.repeat(40),
    snapshotSha256: snapshot.sourceArchiveSha256,
  };
  const remoteTree = {
    treeHash: '2'.repeat(40),
    files: remoteFiles,
  };
  return {
    provisioning: { ...provisioning, ...overrides.provisioning },
    snapshotEntries: overrides.snapshotEntries ?? files,
    pushReceipt: { ...pushReceipt, ...overrides.pushReceipt },
    remoteTree: { ...remoteTree, ...overrides.remoteTree },
  };
}

test('initial managed source push binds the exact snapshot to repository id, commit and tree without marking web deployed', async () => {
  const binding = await verifyManagedInitialSourcePush(await fixtures());
  assert.deepEqual(
    {
      repositoryId: binding.repositoryId,
      repositoryOwner: binding.repositoryOwner,
      defaultBranch: binding.defaultBranch,
      sourceState: binding.sourceState,
      sourceTransport: binding.sourceTransport,
      sourceCustody: binding.sourceCustody,
      hostingProvider: binding.hostingProvider,
      hostingState: binding.hostingState,
      officialStatus: binding.officialStatus,
    },
    {
      repositoryId: 99011,
      repositoryOwner: 'mahayana-hosted-01',
      defaultBranch: 'main',
      sourceState: 'hosted',
      sourceTransport: 'github-app-api',
      sourceCustody: 'platform-managed',
      hostingProvider: 'none',
      hostingState: 'none',
      officialStatus: 'community',
    },
  );
});

test('initial source push rejects any changed or extra GitHub bytes', async () => {
  const changed = await fixtures();
  changed.remoteTree.files[0] = { ...changed.remoteTree.files[0], sha: '3'.repeat(40) };
  await assert.rejects(
    verifyManagedInitialSourcePush(changed),
    (error) => error.code === 'managed_source_tree_mismatch',
  );

  const extra = await fixtures();
  extra.remoteTree.files.push({ path: 'unexpected.txt', type: 'blob', sha: '4'.repeat(40) });
  await assert.rejects(
    verifyManagedInitialSourcePush(extra),
    (error) => error.code === 'managed_source_tree_mismatch',
  );
});

test('initial source push rejects repository identity and snapshot drift', async () => {
  await assert.rejects(
    verifyManagedInitialSourcePush(await fixtures({ pushReceipt: { repositoryId: 99012 } })),
    (error) => error.code === 'managed_source_repository_mismatch',
  );
  await assert.rejects(
    verifyManagedInitialSourcePush(await fixtures({ pushReceipt: { snapshotSha256: 'f'.repeat(64) } })),
    (error) => error.code === 'managed_source_snapshot_mismatch',
  );
  await assert.rejects(
    verifyManagedInitialSourcePush(await fixtures({
      provisioning: { repositoryOwner: 'bhrumom' },
      pushReceipt: { repositoryOwner: 'bhrumom' },
    })),
    (error) => error.code === 'managed_owner_trust_boundary',
  );
});
