import assert from 'node:assert/strict';
import test from 'node:test';

import { createDeterministicSourceSnapshot } from '../src/miniapps/deployment-contract.js';

test('safe source snapshot rejects secrets and unsafe paths', async () => {
  await assert.rejects(
    () => createDeterministicSourceSnapshot([
      { path: '.env', content: 'TOKEN=secret' },
    ]),
  );
  await assert.rejects(
    () => createDeterministicSourceSnapshot([
      { path: 'src/app.js', content: 'Authorization: Bearer abc' },
    ]),
  );
  await assert.rejects(
    () => createDeterministicSourceSnapshot([
      { path: '../outside.txt', content: 'x' },
    ]),
  );
});
