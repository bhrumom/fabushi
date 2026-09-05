import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../../", import.meta.url);
const read = (path) => readFile(new URL(path, root), "utf8");

test("iOS interactive workflow installs a logged-in app that owns device registration", async () => {
  const workflow = await read(".github/workflows/ios-interactive-app-e2e.yml");
  for (const required of [
    "branches: [main]",
    "mobile/ios/Fabushi/**",
    "mobile/ios/FabushiTests/**",
    "mobile/ios/project.yml",
    "Initialize runner-owned paths after runner allocation",
    "FABUSHI_ACCOUNT_SESSION_FILE=$RUNNER_TEMP/fabushi-account/session.json",
    "FABUSHI_CI_ACCOUNT_SESSION_FILE=$RUNNER_TEMP/fabushi-ci-app/session.json",
    "DERIVED_DATA=$RUNNER_TEMP/fabushi-ios-derived",
    "EVIDENCE_DIR=$GITHUB_WORKSPACE/ios-interactive-evidence",
    '>> "$GITHUB_ENV"',
    "Select, erase, and boot compatible iOS Simulator",
    "xcrun simctl list runtimes available -j",
    "xcrun simctl list devices available -j",
    "xcrun simctl erase",
    "xcrun simctl bootstatus",
    "simulator-runtimes.json",
    "simulator-devices.json",
    "Install exact Simulator test build before protected account login",
    "Login protected Fabushi test account and export bounded app session",
    "Launch authenticated exact test build and let the app own device registration",
    "secrets.FABUSHI_CI_TEST_USERNAME",
    "secrets.FABUSHI_CI_TEST_PASSWORD",
    "login-ci-test-account.mjs",
    "export-ci-app-account-session.mjs",
    "SIMCTL_CHILD_FABUSHI_CI_ACCOUNT_SESSION_FILE",
    "xcrun simctl install",
    "xcrun simctl launch",
    "recordVideo",
    "FabushiContracts.xcresult",
    "Upload comparable Simulator test version before interaction",
    "Upload complete evidence even on failure",
    "if: always()",
    "fabushi.app.status",
    "fabushi.app.snapshot",
    "fabushi.app.find",
    "fabushi.app.action",
    "fabushi.app.wait",
    "fabushi.app.assert",
  ]) assert.ok(workflow.includes(required), `missing iOS interactive invariant: ${required}`);

  const bootIndex = workflow.indexOf('xcrun simctl boot "$udid"');
  const videoIndex = workflow.indexOf("recordVideo");
  const rustBuildIndex = workflow.indexOf("Build Mahayana Host for iOS Simulator");
  const installIndex = workflow.indexOf("Install exact Simulator test build before protected account login");
  const loginIndex = workflow.indexOf("Login protected Fabushi test account and export bounded app session");
  const launchIndex = workflow.indexOf("Launch authenticated exact test build and let the app own device registration");
  const controlIndex = workflow.indexOf("Hold live app for @fabushi test semantic control");
  assert.ok(bootIndex >= 0 && videoIndex > bootIndex && rustBuildIndex > videoIndex,
    "full-session video must start immediately after Simulator boot and before build/test/login/install");
  assert.ok(videoIndex < installIndex && installIndex < loginIndex && loginIndex < launchIndex && launchIndex < controlIndex,
    "journey order must be recording -> exact app install -> protected account login -> app-owned registration -> external control");
  assert.equal(workflow.match(/xcrun\s+simctl\s+install/g)?.length, 1,
    "the exact Simulator app should be installed once before protected account login");

  assert.doesNotMatch(workflow, /xcrun\s+simctl\s+create/u);
  assert.doesNotMatch(workflow, /\$\{\{\s*runner\.temp\s*\}\}/u);
  assert.doesNotMatch(workflow, /fabushi-device-agent\.js/u);
  assert.doesNotMatch(workflow, /DEVICE_GATEWAY_TOKEN/u);
  assert.doesNotMatch(workflow, /FABUSHI_ACCOUNT_ACCESS_TOKEN/u);
  assert.doesNotMatch(workflow, /nohup\s+node/u);
});

test("native iOS gateway reuses the account session and semantic App Surface only", async () => {
  const gateway = await read("mobile/ios/Fabushi/FabushiRemoteDeviceGateway.swift");
  const app = await read("mobile/ios/Fabushi/FabushiApp.swift");
  const surface = await read("mobile/ios/Fabushi/FabushiAppAgentSurface.swift");

  assert.match(gateway, /wss:\/\/fabushi-mcp\.ombhrum\.com\/agent/u);
  assert.match(gateway, /feature\.auth\.deviceAgentSession/u);
  assert.match(gateway, /URLSessionWebSocketTask/u);
  assert.match(gateway, /"type": "register"/u);
  assert.match(gateway, /FabushiAppAgentSurface\.toolNames/u);
  assert.match(gateway, /"type": "result"/u);
  assert.match(gateway, /"type": "heartbeat"/u);
  assert.match(app, /FabushiRemoteDeviceGateway/u);
  assert.match(app, /setLoggedIn\(model\.loggedIn\)/u);
  assert.match(app, /onChange\(of: model\.loggedIn\)/u);
  assert.match(surface, /sensitive_app_surface_input_requires_secure_input/u);

  assert.doesNotMatch(gateway, /Process|NSTask|\/bin\/sh|JavaScript/u);
  assert.doesNotMatch(gateway, /refreshToken/u);
});

test("authenticated Grok iOS shell publishes the same native semantic surface", async () => {
  const grok = await read("mobile/ios/Fabushi/GrokMobileShell.swift");
  for (const required of [
    "let appAgentSurface: FabushiAppAgentSurface",
    ".task(id: appAgentSurfaceFingerprint) { publishAppAgentSurface() }",
    'appAgentSurface.publish(screen: "grok-home"',
    'appAgentSurface.publish(screen: "grok-compose"',
    'appAgentSurface.publish(screen: "grok-create-bot"',
    'appAgentSurface.publish(screen: "bot-chat"',
    '"grok-mobile-legacy"',
    '"grok-mobile-search-field"',
    '"grok-mobile-add"',
    '"grok-bot-mahayana-assistant"',
    '"mobile-bot-draft"',
    '"mobile-bot-send"',
    'allowed: ["setValue"]',
    'allowed: ["invoke"]',
  ]) assert.ok(grok.includes(required), `missing Grok iOS semantic invariant: ${required}`);

  assert.match(grok, /for bot in filteredBots\.prefix\(100\)/u);
  assert.match(grok, /for conversation in filteredConversations\.prefix\(100\)/u);
  assert.doesNotMatch(grok, /fabushi-device-agent|Process\(|NSTask|\/bin\/sh/u);
});