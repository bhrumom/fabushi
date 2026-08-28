import assert from 'node:assert/strict';
import test from 'node:test';
import worker from './marketplace-e2e-artifact-worker.mjs';

function envWith(value) {
  return {
    ARTIFACTS: {
      async get(key) {
        if (key !== 'e2e/marketplace/123-1/plugin.tar.gz' || value === null) return null;
        return {
          body: value,
          size: value.length,
          httpEtag: '"fixture"',
          writeHttpMetadata(headers) { headers.set('content-type', 'application/gzip'); },
        };
      },
    },
  };
}

test('serves only immutable marketplace test artifacts over GET and HEAD', async () => {
  const get = await worker.fetch(new Request('https://artifacts.example/e2e/marketplace/123-1/plugin.tar.gz'), envWith('archive'));
  assert.equal(get.status, 200);
  assert.equal(await get.text(), 'archive');
  assert.equal(get.headers.get('cache-control'), 'public, max-age=31536000, immutable');
  assert.equal(get.headers.get('access-control-allow-origin'), '*');

  const head = await worker.fetch(new Request('https://artifacts.example/e2e/marketplace/123-1/plugin.tar.gz', { method: 'HEAD' }), envWith('archive'));
  assert.equal(head.status, 200);
  assert.equal(await head.text(), '');
});

test('denies writes, traversal, arbitrary bucket keys, and missing objects', async () => {
  const method = await worker.fetch(new Request('https://artifacts.example/e2e/marketplace/123-1/plugin.tar.gz', { method: 'POST' }), envWith('archive'));
  assert.equal(method.status, 405);
  assert.equal(method.headers.get('allow'), 'GET, HEAD');

  for (const path of [
    '/e2e/marketplace/../../secret',
    '/private/plugin.tar.gz',
    '/e2e/marketplace/abc-1/plugin.tar.gz',
  ]) {
    const denied = await worker.fetch(new Request(`https://artifacts.example${path}`), envWith('archive'));
    assert.equal(denied.status, 404);
  }

  const missing = await worker.fetch(new Request('https://artifacts.example/e2e/marketplace/123-1/plugin.tar.gz'), envWith(null));
  assert.equal(missing.status, 404);
});
