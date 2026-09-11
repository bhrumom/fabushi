import assert from 'node:assert/strict';
import { loadConfigFromFile } from 'vite';

// Synthetic canaries, never real CI credentials. This loads configuration only.
process.env.FCM_PRIVATE_CANARY = 'must-not-enter-renderer';
process.env.NEXT_PUBLIC_FCM_CANARY = 'public-config-visible';
try {
  const loaded = await loadConfigFromFile({ command: 'serve', mode: 'test' }, 'vite.config.ts');
  assert.ok(loaded, 'real Vite configuration must load');
  const environment = JSON.parse(loaded.config.define['process.env']);
  assert.equal(environment.NEXT_PUBLIC_FCM_CANARY, 'public-config-visible');
  assert.equal(environment.FCM_PRIVATE_CANARY, undefined);
  assert.ok(Object.keys(environment).every(key => key === 'NODE_ENV' || key.startsWith('NEXT_PUBLIC_')));
  assert.equal(JSON.stringify(loaded.config.define).includes('must-not-enter-renderer'), false);
  console.log('FABUSHI_PUBLIC_ENVIRONMENT_PASSED');
} finally {
  delete process.env.FCM_PRIVATE_CANARY;
  delete process.env.NEXT_PUBLIC_FCM_CANARY;
}
