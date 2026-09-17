import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const workflowPath = new URL('../../.github/workflows/mahayana-fast-checks.yml', import.meta.url);

async function workflow() {
  return readFile(workflowPath, 'utf8');
}

test('Mahayana pull requests keep a cache-backed CLI-first fast gate', async () => {
  const source = await workflow();

  assert.match(source, /pull_request:\s*\n\s*paths:/u);
  assert.match(source, /sparse-checkout:/u);
  assert.match(source, /Swatinem\/rust-cache@v2/u);
  assert.match(source, /cancel-in-progress:\s*true/u);
  assert.match(source, /CARGO_INCREMENTAL:\s*"1"/u);

  assert.match(
    source,
    /Test Mahayana CLI as the product logic entry point[\s\S]*?cargo test\s+-p mahayana-cli\s+--profile ci\s+--no-default-features/u,
  );
  assert.match(
    source,
    /Test deterministic CLI test-driver protocol[\s\S]*?cargo test\s+-p mahayana-test-driver-protocol\s+--profile ci/u,
  );

  const cli = source.indexOf('Test Mahayana CLI as the product logic entry point');
  const compatibility = source.indexOf('Test Mahayana-owned CLI compatibility surfaces');
  assert.ok(cli >= 0 && compatibility > cli, 'the product CLI must fail before broader compatibility suites');
  assert.doesNotMatch(source, /cargo test\s+--workspace/u);
});
