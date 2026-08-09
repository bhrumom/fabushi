import assert from 'node:assert/strict';
import test from 'node:test';

import { transitionDeploymentState } from '../src/miniapps/deployment-contract.js';

test('deployment state machine rejects source-as-hosting and market skips', () => {
  assert.equal(transitionDeploymentState('local-only', 'source-hosted'), 'source-hosted');
  assert.equal(transitionDeploymentState('source-hosted', 'build-passed'), 'build-passed');
  assert.equal(transitionDeploymentState('build-passed', 'deployed'), 'deployed');
  assert.throws(() => transitionDeploymentState('local-only', 'deployed'));
  assert.throws(() => transitionDeploymentState('source-hosted', 'marketplace-listed'));
});
