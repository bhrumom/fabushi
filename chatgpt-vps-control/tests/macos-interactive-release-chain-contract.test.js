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

test('macOS release handoff is pinned to an immutable exact-source release tag', async () => {
  const source = await workflow();
  assert.match(source, /\.immutable == true/u);
  assert.match(source, /\.target_commitish == \$sha/u);
  assert.match(source, /fabushi-\[0-9\]\+\[\.\]\[0-9\]\+\[\.\]\[0-9\]\+-macos-arm64/u);
  assert.match(source, /commits\/\$release_tag/u);
  assert.match(source, /test "\$tag_sha" = "\$source_sha"/u);
  assert.match(source, /short_source="\$\{source_sha:0:12\}"/u);
  assert.match(source, /\[\[ "\$release_tag" == desktop-\*"-\$short_source" \]\]/u);
});

test('release chain delegates target creation and control exclusively to FCM external controller', async () => {
  const source = await workflow();
  assert.match(source, /gh workflow run fcm-010-13-11-macos-external-controller\.yml[^\n]*--ref "\$RELEASE_TAG"/u);
  assert.doesNotMatch(source, /gh workflow run macos-interactive-app-e2e\.yml/u);
  assert.match(source, /never dispatches the target workflow directly/u);
});

test('macOS release chain suppresses duplicate active or successful exact-source controller runs', async () => {
  const source = await workflow();
  assert.match(source, /actions\/workflows\/fcm-010-13-11-macos-external-controller\.yml\/runs\?head_sha=\$source_sha/u);
  assert.match(source, /select\(\.event == "workflow_dispatch"\)/u);
  assert.match(source, /select\(\.head_branch == \$tag\)/u);
  assert.match(source, /select\(\.status != "completed" or \.conclusion == "success"\)/u);
  assert.match(source, /steps\.release\.outputs\.skip != 'true'/u);
});
