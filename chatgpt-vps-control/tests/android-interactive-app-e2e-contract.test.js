import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../../", import.meta.url);
const read = (path) => readFile(new URL(path, root), "utf8");

test("Android interactive workflow tests an immutable published APK and always uploads evidence", async () => {
  const workflow = await read(".github/workflows/android-interactive-app-e2e.yml");
  assert.match(workflow, /workflow_dispatch:/u);
  assert.doesNotMatch(workflow, /\n  push:/u);
  assert.match(workflow, /release_tag:/u);
  assert.match(workflow, /release_sha:/u);
  assert.match(workflow, /gha-\$\{\{ github\.run_id \}\}-\$\{\{ github\.run_attempt \}\}-interactive/u);
  assert.match(workflow, /reactivecircus\/android-emulator-runner@v2/u);
  assert.match(workflow, /FABUSHI_CI_TEST_USERNAME/u);
  assert.match(workflow, /FABUSHI_CI_TEST_PASSWORD/u);
  assert.match(workflow, /if: always\(\)/u);
  assert.match(workflow, /android-session\.mp4/u);
  assert.match(workflow, /device-gateway-trace\.jsonl/u);
  assert.match(workflow, /logcat-final\.txt/u);
  assert.doesNotMatch(workflow, /fabushi-device-agent\.js/u);
  assert.doesNotMatch(workflow, /runner-owned gateway/u);
});

test("Android interactive runner records before install, then authenticates and launches the App-owned gateway", async () => {
  const script = await read("chatgpt-vps-control/scripts/run-android-interactive-app-e2e.sh");
  const recordAt = script.indexOf("screenrecord");
  const installAt = script.indexOf("adb install -r");
  const loginAt = script.indexOf("login-ci-test-account.mjs");
  const launchAt = script.indexOf("adb shell am start -W");
  assert.ok(recordAt >= 0 && recordAt < installAt, "recording must start before APK install");
  assert.ok(installAt < loginAt, "protected test account login must happen after APK install");
  assert.ok(loginAt < launchAt, "bounded session must exist before authenticated App launch");
  assert.match(script, /git\/ref\/tags\/\$RELEASE_TAG/u);
  assert.match(script, /test "\$ref_sha" = "\$RELEASE_SHA"/u);
  assert.match(script, /sha256sum -c SHA256SUMS\.txt/u);
  const updateMetadataAt = script.indexOf("--pattern 'fabushi-android-update.json'");
  const checksumAt = script.indexOf("sha256sum -c SHA256SUMS.txt");
  assert.ok(updateMetadataAt >= 0 && updateMetadataAt < checksumAt, "release metadata covered by SHA256SUMS must be downloaded before verification");
  assert.match(script, /fabushi\.ci\.device-name/u);
  assert.match(script, /phase == "registered"/u);
  assert.match(script, /phase == "call-completed" and \.ok == true/u);
  assert.match(script, /reason == "logged-out"/u);
  for (const tool of ["status", "snapshot", "find", "action", "wait", "assert"]) {
    assert.match(script, new RegExp(`fabushi\\.app\\.${tool}`, "u"));
  }
});

test("Android App owns the remote gateway while CI account import stays GitHub-release-only", async () => {
  const activity = await read("mobile/android/app/src/main/java/com/ombhrum/fabushi/MainActivity.kt");
  const bootstrap = await read("mobile/android/app/src/main/java/com/ombhrum/fabushi/FabushiCiBootstrap.kt");
  const gateway = await read("mobile/android/app/src/main/java/com/ombhrum/fabushi/FabushiRemoteDeviceGateway.kt");
  const gradle = await read("mobile/android/app/build.gradle");
  assert.match(activity, /FabushiCiBootstrap\.prepare\(this\)/u);
  assert.match(activity, /FabushiRemoteDeviceGateway/u);
  assert.match(activity, /remoteDeviceGateway\.setLoggedIn\(state\.loggedIn\)/u);
  assert.match(bootstrap, /github-actions-android-app/u);
  assert.match(bootstrap, /FABUSHI_CI_ACCOUNT_SESSION_FILE/u);
  assert.match(bootstrap, /\^gha-\(\[0-9\]\+\)-\(\[0-9\]\+\)-interactive\$/u);
  assert.match(gateway, /wss:\/\/fabushi-mcp\.ombhrum\.com\/agent/u);
  assert.match(gateway, /feature\.auth\.deviceAgentSession/u);
  assert.match(gateway, /"platform", "android"/u);
  assert.match(gateway, /FabushiAppAgentSurface\.ToolNames/u);
  assert.match(gradle, /CI_ACCOUNT_SESSION_IMPORT_ENABLED', 'false'/u);
  assert.match(gradle, /githubRelease[\s\S]*CI_ACCOUNT_SESSION_IMPORT_ENABLED', 'true'/u);
});

test("Native Android GitHub release is explicitly a test-tier release gate", async () => {
  const release = await read(".github/workflows/native-android-release.yml");
  assert.match(release, /RELEASE_TARGET: android/u);
  assert.match(release, /RELEASE_TIER: test/u);
  assert.match(release, /bash \.github\/scripts\/require-release-source-gates\.sh/u);
  assert.match(release, /Required gates: CI result \(Android GitHub test tier\)/u);
  assert.doesNotMatch(release, /Required gates: CI result \+ Native mobile result/u);
});

test("Native Android release self-starts the exact published App-owned interactive lane", async () => {
  const release = await read(".github/workflows/native-android-release.yml");
  assert.ok(release.includes("actions: write"));
  assert.ok(release.includes("gh workflow run android-interactive-app-e2e.yml"));
  assert.ok(release.includes("--ref main"));
  assert.ok(release.includes("-f release_tag='${{ steps.release.outputs.release_tag }}'"));
  assert.ok(release.includes("-f release_sha='${{ steps.source.outputs.sha }}'"));
});

test("authenticated Android Grok shell owns the App semantic surface", async () => {
  const activity = await read("mobile/android/app/src/main/java/com/ombhrum/fabushi/MainActivity.kt");
  const grok = await read("mobile/android/app/src/main/java/com/ombhrum/fabushi/GrokMobileShellAndroid.kt");
  assert.match(activity, /GrokMobileShellAndroid[\s\S]*appAgentSurface = appAgentSurface/u);
  for (const required of [
    "appAgentSurface: FabushiAppAgentSurface",
    "appAgentSurface.publish(screen = screen",
    'appAgentSurface.publish(screen = "bot-chat"',
    '"grok-home"',
    '"grok-compose"',
    '"grok-create-bot"',
    '"grok-mobile-legacy"',
    '"grok-mobile-search-field"',
    '"grok-mobile-add"',
    '"grok-bot-mahayana-assistant"',
    '"mobile-bot-draft"',
    '"mobile-bot-send"',
    'setOf("setValue")',
    'setOf("invoke")',
  ]) assert.ok(grok.includes(required), `missing authenticated Android Grok semantic invariant: ${required}`);
});
