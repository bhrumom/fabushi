import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const workflowPath = new URL('../../.github/workflows/ci-latency-observability.yml', import.meta.url);

async function workflow() {
  return readFile(workflowPath, 'utf8');
}

test('CI latency observability measures the validation surfaces that actually carry feedback', async () => {
  const source = await workflow();

  for (const workflow of [
    'ci.yml',
    'mahayana-fast-checks.yml',
    'electron-desktop.yml',
    'native-mobile.yml',
    'macos-interactive-app-e2e.yml',
  ]) {
    assert.match(source, new RegExp(workflow.replaceAll('.', '\\.'), 'u'));
  }

  for (const surface of [
    'required-pr-ci',
    'required-merge-queue',
    'mahayana-pr-fast',
    'electron-pr-fast',
    'native-pr-fast',
    'canonical-desktop',
    'canonical-mobile',
    'macos-packaged-interactive',
  ]) {
    assert.match(source, new RegExp(surface, 'u'));
  }

  assert.match(source, /schema_version:\s*2/u);
  assert.match(source, /sample_limit_per_surface/u);
  assert.match(source, /source_workflows/u);
  assert.match(source, /slowest_samples/u);
  assert.match(source, /p95_seconds/u);
  assert.match(source, /queue_p95_seconds/u);
  assert.match(source, /slo_budget_seconds/u);
  assert.match(source, /over-budget/u);
  assert.match(source, /never bypasses or replaces correctness/u);

  assert.doesNotMatch(source, /const canonicalJobs = new Set/u);
  assert.doesNotMatch(source, /'Frontend checks'/u);
  assert.doesNotMatch(source, /'Worker checks'/u);
  assert.doesNotMatch(source, /'MCP plugin contracts'/u);
  assert.doesNotMatch(source, /selected_jobs/u);
});
