import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../../", import.meta.url);
const read = (path) => readFile(new URL(path, root), "utf8");

test("iOS interactive workflow installs a logged-in app that owns device registration", async () => {
  const workflow = await read(".github/workflows/ios-interactive-app-e2e.yml");
  for (const required of [
    "branches: [main]",
    "Initialize runner-owned paths after runner allocation",
    "FABUSHI_ACCOUNT_SESSION_FILE=$RUNNER_TEMP/fabushi-account/session.json",
    "FABUSHI_CI_ACCOUNT_SESSION_FILE=$RUNNER_TEMP/fabushi-ci-app/session.json",
    "DERIVED_DATA=$RUNNER_TEMP/fabushi-ios-derived",
    "EVIDENCE_DIR=$GITHUB_WORKSPACE/ios-interactive-evidence",
    '>> "$GITHUB_ENV"',
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
    "Start end-to-end Simulator recording before app installation",
    "Install exact Simulator test build before account login",
    "Login protected Fabushi test account and export bounded app session",
    "Launch authenticated exact test build and let the app own device registration",
    "Upload complete evidence even on failure",
    "if: always()",
    "fabushi.app.status",
    "fabushi.app.snapshot",
    "fabushi.app.find",
    "fabushi.app.action",
    "fabushi.app.wait",
    "fabushi.app.assert",
  ]) assert.ok(workflow.includes(required), `missing iOS interactive invariant: ${required}`);

  const recording = workflow.indexOf("Start end-to-end Simulator recording before app installation");
  const install = workflow.indexOf("Install exact Simulator test build before account login");
  const login = workflow.indexOf("Login protected Fabushi test account and export bounded app session");
  const launch = workflow.indexOf("Launch authenticated exact test build and let the app own device registration");
  const control = workflow.indexOf("Hold live app for @fabushi test semantic control");
  assert.ok(recording < install, "recording must start before app installation");
  assert.ok(install < login, "exact app must be installed before protected test-account login");
  assert.ok(login < launch, "test-account session must exist before authenticated app launch");
  assert.ok(launch < control, "app-owned registration must precede external semantic control");

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