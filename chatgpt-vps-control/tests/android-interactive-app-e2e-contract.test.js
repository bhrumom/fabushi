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
