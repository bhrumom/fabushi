import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const workflowPath = new URL('../../.github/workflows/macos-interactive-release-chain.yml', import.meta.url);

async function workflow() {
  return readFile(workflowPath, 'utf8');
}

test('macOS interactive release chain follows both canonical release producers', async () => {
  const source = await workflow();
  assert.match(source, /Native Electron macOS test release/u);
  assert.match(source, /Post-main E2E Release delivery/u);
  assert.match(source, /inputs\.source_sha/u);
});

test('macOS interactive workflow_run identity is resolved from stable workflow path, not dynamic run-name', async () => {
  const source = await workflow();
  assert.match(source, /actions\/runs\/\$upstream_id/u);
  assert.match(source, /\.github\/workflows\/native-electron-release\.yml/u);
  assert.match(source, /\.github\/workflows\/post-main-delivery\.yml/u);
  assert.match(source, /Post-main source=\(\[0-9a-f\]\{40\}\) upstream=/u);
  assert.doesNotMatch(source, /github\.event\.workflow_run\.name/u);
});

test('macOS interactive dispatch is pinned to an exact-source release tag rather than moving main', async () => {
  const source = await workflow();
  assert.match(source, /\.target_commitish == \$sha/u);
  assert.match(source, /macos-\.\*\[\.\]zip\$/u);
  assert.match(source, /commits\/\$release_tag/u);
  assert.match(source, /test "\$tag_sha" = "\$source_sha"/u);
  assert.match(source, /gh workflow run macos-interactive-app-e2e\.yml[^\n]*--ref "\$RELEASE_TAG"/u);
  assert.doesNotMatch(source, /gh workflow run macos-interactive-app-e2e\.yml[^\n]*--ref main/u);
});

test('macOS interactive release chain suppresses duplicate active or successful exact-source runs', async () => {
  const source = await workflow();
  assert.match(source, /actions\/workflows\/macos-interactive-app-e2e\.yml\/runs\?head_sha=\$source_sha/u);
  assert.match(source, /select\(\.status != "completed" or \.conclusion == "success"\)/u);
  assert.match(source, /steps\.release\.outputs\.skip != 'true'/u);
});
