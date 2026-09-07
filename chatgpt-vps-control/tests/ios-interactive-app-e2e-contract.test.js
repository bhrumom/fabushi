import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../../", import.meta.url);
const read = (path) => readFile(new URL(path, root), "utf8");

test("iOS Global Dharma workflow preserves exact-package autonomous journey and evidence gates", async () => {
  const workflow = await read(".github/workflows/ios-interactive-app-e2e.yml");
  for (const required of [
    "branches: [main]",
    "mobile/ios/Fabushi/**",
    "mobile/ios/FabushiTests/**",
    "mobile/ios/FabushiUITests/**",
    "mobile/ios/project.yml",
    "Initialize evidence paths",
    "FABUSHI_ACCOUNT_SESSION_FILE=$RUNNER_TEMP/fabushi-account/session.json",
    "FABUSHI_CI_ACCOUNT_SESSION_FILE=$RUNNER_TEMP/fabushi-ci-app/session.json",
    "DERIVED_DATA=$RUNNER_TEMP/fabushi-ios-derived",
    "EVIDENCE_DIR=$GITHUB_WORKSPACE/ios-interactive-evidence",
    '>> "$GITHUB_ENV"',
    "Boot isolated Simulator and start full-session video",
    "xcrun simctl list runtimes available -j",
    "xcrun simctl list devices available -j",
    "xcrun simctl erase",
    "xcrun simctl bootstatus",
    "recordVideo",
    "Build cached Mahayana Host for iOS Simulator",
    "Build app and tests once",
    "FabushiContracts.xcresult",
    "Stage exact Simulator package and portable UI-test harness",
    "Upload exact reusable Simulator test version before interaction",
    "Install exact package before protected account login",
    "Login protected Fabushi test account after install",
    "Inject bounded session and require App-owned registration",
    "SIMCTL_CHILD_FABUSHI_CI_ACCOUNT_SESSION_FILE",
    "xcrun simctl install",
    "xcrun simctl launch",
    "Run autonomous Global Dharma simulated-user journey",
    "GlobalDharmaJourney.xcresult",
    "GlobalDharmaJourneyUITests/testGlobalDharmaMarketplaceBotWebMcpCommerceJourney",
    "Verify canonical restore ledger and server entitlement",
    "/v1/purchases/restore",
    "/v1/plugins/global-dharma/entitlements/local.prayer-wheel.start",
    "local-prayer-wheel.lifetime",
    "108000",
    "canonical-ledger-status.txt",
    "Observe optional external fabushi test evidence without blocking",
    "Collect complete evidence",
    "Upload complete evidence even on failure",
    "if: always()",
    "ios-session.mp4",
    "global-dharma-ui-state.json",
    "sharedRuntimeSynced",
    "entitlementAllowed",
    "restoreTapped",
  ]) assert.ok(workflow.includes(required), `missing iOS Global Dharma invariant: ${required}`);

  const bootIndex = workflow.indexOf('xcrun simctl boot "$udid"');
  const videoIndex = workflow.indexOf("recordVideo");
  const rustBuildIndex = workflow.indexOf("Build cached Mahayana Host for iOS Simulator");
  const packageIndex = workflow.indexOf("Upload exact reusable Simulator test version before interaction");
  const installIndex = workflow.indexOf("Install exact package before protected account login");
  const loginIndex = workflow.indexOf("Login protected Fabushi test account after install");
  const launchIndex = workflow.indexOf("Inject bounded session and require App-owned registration");
  const journeyIndex = workflow.indexOf("Run autonomous Global Dharma simulated-user journey");
  const restoreIndex = workflow.indexOf("Verify canonical restore ledger and server entitlement");
  const optionalExternalIndex = workflow.indexOf("Observe optional external fabushi test evidence without blocking");
  const collectIndex = workflow.indexOf("Collect complete evidence");

  assert.ok(bootIndex >= 0 && videoIndex > bootIndex && rustBuildIndex > videoIndex,
    "full-session video must start immediately after Simulator boot and before build/test/login/install");
  assert.ok(packageIndex > rustBuildIndex && installIndex > packageIndex && loginIndex > installIndex && launchIndex > loginIndex,
    "exact package must be uploaded before install, then login must occur before app-owned registration");
  assert.ok(journeyIndex > launchIndex && restoreIndex > journeyIndex,
    "autonomous Global Dharma journey must run only after app-owned registration, then canonical restore must independently verify the ledger");
  assert.ok(optionalExternalIndex > restoreIndex && collectIndex > optionalExternalIndex,
    "optional external evidence must not gate the autonomous journey or canonical restore checks");
  assert.equal(workflow.match(/xcrun\s+simctl\s+install/g)?.length, 1,
    "the exact Simulator app should be installed once before protected account login");

  const restoreBlock = workflow.slice(restoreIndex, optionalExternalIndex);
  assert.match(restoreBlock, /curl[\s\S]*\/v1\/purchases\/restore/u,
    "the CI ledger restore gate must issue a real authenticated restore request");
  assert.match(restoreBlock, /entitlement-after-restore\.json/u,
    "restore must be followed by a fresh server-authoritative entitlement fetch");
  assert.match(restoreBlock, /\.access\.allowed == true/u,
    "restore passes only when the server entitlement is allowed");
  assert.match(restoreBlock, /\.purchase\.status == "fulfilled"/u,
    "restore evidence must bind to a fulfilled canonical purchase ledger entry");

  const optionalBlock = workflow.slice(optionalExternalIndex, collectIndex);
  assert.match(optionalBlock, /optional|Optional|supplement/u,
    "external fabushi test evidence must be explicitly optional/supplemental");
  assert.doesNotMatch(optionalBlock, /exit 1/u,
    "missing external device evidence must never fail the dedicated autonomous journey");

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

  const gatewayCode = gateway.replace(/\/\/.*$/gmu, "");
  assert.doesNotMatch(gatewayCode, /\bProcess\s*\(|\bNSTask\s*\(|\/bin\/sh|\bJavaScriptCore\b|\bJSContext\s*\(/u);
  assert.doesNotMatch(gatewayCode, /refreshToken/u);
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
