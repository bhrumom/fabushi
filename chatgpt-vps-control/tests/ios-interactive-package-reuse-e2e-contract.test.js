import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../../", import.meta.url);
const read = (path) => readFile(new URL(path, root), "utf8");

test("iOS package-reuse workflow reinstalls one exact compatible artifact without rebuilding it", async () => {
  const workflow = await read(".github/workflows/ios-interactive-package-reuse-e2e.yml");

  for (const required of [
    "workflow_dispatch:",
    "origin_run_id:",
    "package_source_sha:",
    "actions: read",
    "Verify exact origin run and package compatibility",
    'actions/runs/$ORIGIN_RUN_ID',
    'compare/$PACKAGE_SOURCE_SHA...$GITHUB_SHA',
    'startswith(\"mobile/ios/\")',
    'startswith(\"third_party/mahayana/mahayana-rs/\")',
    'startswith(\"native/mahayana-messaging/\")',
    "Select, erase, boot, and start full-session recording",
    "recordVideo",
    "actions/download-artifact@v8.0.1",
    "github-token: ${{ github.token }}",
    "run-id: ${{ inputs.origin_run_id }}",
    "digest-mismatch: error",
    "checksum_line_count=",
    "expected_archive_digest=",
    "listed_archive_path=",
    "actual_archive_digest=",
    'basename "$listed_archive_path"',
    "CFBundleIdentifier",
    "com.ombhrum.fabushi",
    "Install reused Simulator package before protected account login",
    "Login protected Fabushi test account and export bounded app session",
    "Launch reused package and let the app own device registration",
    'SIMCTL_CHILD_GITHUB_SHA="$PACKAGE_SOURCE_SHA"',
    "Hold live reused app for @fabushi test simulated-user control",
    "fabushi.app.status",
    "fabushi.app.snapshot",
    "fabushi.app.find",
    "fabushi.app.action",
    "fabushi.app.wait",
    "fabushi.app.assert",
    "retention-days: 90",
    "packageSourceSha",
    "originRunId",
    "originArtifactId",
  ]) {
    assert.ok(workflow.includes(required), `missing reused-package invariant: ${required}`);
  }

  const bootIndex = workflow.indexOf('xcrun simctl boot "$udid"');
  const videoIndex = workflow.indexOf("recordVideo");
  const downloadIndex = workflow.indexOf("Download exact existing Simulator package");
  const installIndex = workflow.indexOf("Install reused Simulator package before protected account login");
  const loginIndex = workflow.indexOf("Login protected Fabushi test account and export bounded app session");
  const launchIndex = workflow.indexOf("Launch reused package and let the app own device registration");
  const controlIndex = workflow.indexOf("Hold live reused app for @fabushi test simulated-user control");
  assert.ok(bootIndex >= 0 && videoIndex > bootIndex && downloadIndex > videoIndex,
    "recording must start after boot and before reused-package download/extraction/install");
  assert.ok(downloadIndex < installIndex && installIndex < loginIndex && loginIndex < launchIndex && launchIndex < controlIndex,
    "reuse journey must remain package download -> install -> protected login -> App-owned registration -> external control");

  assert.equal(workflow.match(/xcrun\s+simctl\s+install/g)?.length, 1,
    "the reused package must be installed exactly once");
  assert.match(workflow, /deadline=\$\(\(SECONDS \+ 600\)\)/u,
    "the App-owned iOS device must stay live for a bounded ten-minute simulated-user control window");

  assert.doesNotMatch(workflow, /shasum\s+-a\s+256\s+-c\s+SHA256SUMS\.txt/u,
    "reuse mode must not trust origin-run absolute paths embedded in the checksum manifest");
  assert.doesNotMatch(workflow, /\bcargo\s+build\b/u,
    "reuse mode must not rebuild the Rust host");
  assert.doesNotMatch(workflow, /\bxcodebuild\b/u,
    "reuse mode must not rebuild or retest the iOS app");
  assert.doesNotMatch(workflow, /\bxcodegen\b/u,
    "reuse mode must not regenerate the Xcode project");
  assert.doesNotMatch(workflow, /fabushi-device-agent\.js|DEVICE_GATEWAY_TOKEN|FABUSHI_ACCOUNT_ACCESS_TOKEN|\bKRIS\b/u,
    "reuse mode must keep device registration App-owned and account-scoped");
});

test("iOS package-reuse evidence distinguishes workflow source from packaged product source", async () => {
  const workflow = await read(".github/workflows/ios-interactive-package-reuse-e2e.yml");
  assert.match(workflow, /workflow_sha=\$GITHUB_SHA/u);
  assert.match(workflow, /package_source_sha=\$PACKAGE_SOURCE_SHA/u);
  assert.match(workflow, /origin_run_id=\$ORIGIN_RUN_ID/u);
  assert.match(workflow, /origin_artifact_id=\$artifact_id/u);
  assert.match(workflow, /fabushi\.ios\.interactive-package-reuse-evidence\.v1/u);
});
