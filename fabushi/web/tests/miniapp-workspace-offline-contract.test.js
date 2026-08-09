import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createDeterministicSourceSnapshot,
  normalizeSourceSnapshot,
  transitionDeploymentState,
} from '../src/miniapps/deployment-contract.js';

test('local source snapshot remains deterministic and remote independent', async () => {
  const first = await createDeterministicSourceSnapshot([
    { path: 'ui/index.html', content: '<div>hello</div>' },
    { path: 'runtime/worker.js', content: 'export function run() {}' },
  ]);
  const second = await createDeterministicSourceSnapshot([
    { path: 'runtime/worker.js', content: 'export function run() {}' },
    { path: 'ui/index.html', content: '<div>hello</div>' },
  ]);
  assert.equal(first.sourceArchiveSha256, second.sourceArchiveSha256);
  assert.equal(first.sourceTreeHash, second.sourceTreeHash);
  assert.equal(normalizeSourceSnapshot(first.files).length, 2);
});

test('workspace deployment state does not skip source/build stages', () => {
  assert.equal(transitionDeploymentState('local-only', 'source-hosted'), 'source-hosted');
  assert.throws(() => transitionDeploymentState('local-only', 'installable'));
});
