import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

function source(relativePath) {
  return readFileSync(resolve(repositoryRoot, relativePath), "utf8");
}

test("Fabushi embeds the complete Computer Use tool registrar behind stdio", () => {
  const entry = source("chatgpt-vps-control/bin/fabushi-computer-mcp.js");
  const computerUse = source("chatgpt-vps-control/computer-use.js");
  const policy = source("chatgpt-vps-control/lib/fabushi-computer-policy.js");

  assert.match(entry, /StdioServerTransport/);
  assert.match(entry, /registerComputerUseTools\(server/);
  assert.doesNotMatch(entry, /HTTP|WebSocketServer|listen\s*\(/);
  assert.match(entry, /fabushi\.computer\.audit/);
  assert.match(entry, /computerControlPolicyDecision/);
  assert.match(policy, /if \(!policyFile\)[\s\S]*allowed: false/);
  assert.match(policy, /error\?\.code === "ENOENT"[\s\S]*allowed: false/);
  assert.match(policy, /settings\.localExecution !== true/);
  assert.match(policy, /settings\.aiComputerControlEnabled !== true/);

  for (const operation of [
    "list_apps",
    "get_app_state",
    "click",
    "drag",
    "perform_secondary_action",
    "press_key",
    "scroll",
    "select_text",
    "set_value",
    "type_text",
  ]) {
    assert.ok(computerUse.includes(`"${operation}"`), `missing Computer Use operation ${operation}`);
  }
});

test("the disposable packaging command stages runtime dependencies and native helpers", () => {
  const prepare = source("chatgpt-vps-control/bin/prepare-fabushi-bundle.js");
  const runtimeInstall = source("chatgpt-vps-control/lib/runtime-install.js");
  assert.match(prepare, /CHATGPT_COMPUTER_HOME must name the disposable Fabushi packaging directory/);
  assert.match(prepare, /expectedBundleHome = join\(repositoryRoot, "desktop", "resources", "computer-control"\)/);
  assert.match(prepare, /relative\(expectedBundleHome, bundleHome\) !== ""/);
  assert.match(prepare, /refusing destructive cleanup/);
  assert.match(prepare, /await rm\(bundleHome, \{ recursive: true, force: true \}\)/);
  assert.match(prepare, /await installLocalRuntime\(\)/);
  assert.match(prepare, /active-runtime\.json/);
  assert.match(prepare, /await stageFabushiNativeHelper\(/);
  assert.match(runtimeInstall, /REQUIRED_RUNTIME_PATHS[\s\S]*bin\/fabushi-computer-mcp\.js/);
  assert.match(runtimeInstall, /REQUIRED_RUNTIME_PATHS[\s\S]*lib\/fabushi-computer-policy\.js/);
  for (const required of [
    "extension/manifest.json",
    "native/linux/accessibility-helper.py",
    "native/macos/ComputerHelper.swift",
    "native/macos/ComputerHelper-Info.plist",
    "native/macos/RequestService-Info.plist",
    "native/windows/computer-helper.ps1",
  ]) assert.ok(runtimeInstall.includes(`"${required}"`), `private runtime does not require ${required}`);
  assert.match(runtimeInstall, /chmod\(join\(staging, "bin", "fabushi-computer-mcp\.js"\), 0o700\)/);

  const desktopPackage = JSON.parse(source("desktop/package.json"));
  assert.ok(desktopPackage.build.extraResources.some((resource) =>
    resource.from === "resources/computer-control" && resource.to === "computer-control"
  ));
});

test("Electron and Mahayana discover the private packaged stdio runtime", () => {
  const host = source("desktop/electron/host-process.cjs");
  const agent = source("third_party/mahayana/mahayana-rs/mahayana-agent-codex/src/implementation.rs");

  assert.match(host, /feature-host', 'runtime', 'settings\.json/);
  assert.match(host, /active-runtime\.json/);
  assert.match(host, /PACKAGED_COMPUTER_RUNTIME_ID = \/\^v1-\[a-f0-9\]\{20\}\$\//);
  assert.match(host, /manifest\?\.runtimeId !== expectedRuntimeId/);
  assert.match(host, /expectedRuntimeId !== `v1-\$\{manifest\.sourceHash\.slice\(0, 20\)\}`/);
  assert.match(host, /A present pointer is authoritative/);
  assert.match(host, /A production package always uses its signed resources/);
  assert.match(host, /MAHAYANA_COMPUTER_MCP_COMMAND: appImpl\.isPackaged \? execPath : developmentCommand/);
  assert.match(host, /!appImpl\.isPackaged && explicitHelper/);
  assert.match(host, /node_modules', 'ws', 'package\.json/);
  assert.match(host, /lib', 'fabushi-computer-policy\.js/);

  for (const marker of [
    "bin', 'fabushi-computer-mcp.js",
    "MAHAYANA_COMPUTER_MCP_COMMAND",
    "MAHAYANA_COMPUTER_MCP_ENTRY",
    "MAHAYANA_COMPUTER_MCP_CWD",
    "MAHAYANA_COMPUTER_MCP_HOME",
    "MAHAYANA_COMPUTER_MCP_NATIVE_HELPER",
  ]) assert.ok(host.includes(marker), `Electron Host is missing ${marker}`);

  for (const marker of [
    "MAHAYANA_COMPUTER_MCP_COMMAND",
    "MAHAYANA_COMPUTER_MCP_ENTRY",
    "ELECTRON_RUN_AS_NODE",
    "CHATGPT_COMPUTER_HOME",
    "CHATGPT_COMPUTER_NATIVE_HELPER",
  ]) assert.ok(agent.includes(marker), `Mahayana Agent is missing ${marker}`);
  assert.match(agent, /if !command\.is_file\(\)/);
  assert.match(agent, /if !cwd\.is_dir\(\)/);
});

test("every full Electron packager installs and stages Computer Use before sealing", () => {
  const workflows = [
    ".github/workflows/electron-desktop.yml",
    ".github/workflows/native-electron-release.yml",
    ".github/workflows/apple-store-delivery.yml",
  ];

  for (const workflow of workflows) {
    const yaml = source(workflow);
    const install = yaml.indexOf("working-directory: chatgpt-vps-control");
    const installCommand = yaml.indexOf("npm ci --ignore-scripts", install);
    const prepare = yaml.indexOf("node chatgpt-vps-control/bin/prepare-fabushi-bundle.js");
    const packageApplication = yaml.indexOf("electron-builder", prepare);
    assert.ok(install >= 0, `${workflow} does not install Computer Use dependencies`);
    assert.ok(installCommand > install && installCommand < prepare, `${workflow} does not npm ci Computer Use before staging it`);
    assert.ok(prepare > install, `${workflow} does not stage Computer Use after installing it`);
    assert.ok(packageApplication > prepare, `${workflow} does not stage Computer Use before electron-builder`);
    assert.match(yaml, /CHATGPT_COMPUTER_HOME: \$\{\{ github\.workspace \}\}\/desktop\/resources\/computer-control/);
    assert.ok(
      yaml.indexOf("export CHATGPT_COMPUTER_CODESIGN_IDENTITY=") > installCommand
        && yaml.indexOf("export CHATGPT_COMPUTER_CODESIGN_IDENTITY=") < prepare,
      `${workflow} does not pass the runtime-discovered signing identity to Computer Use staging`,
    );
    assert.ok(
      yaml.indexOf("export CHATGPT_COMPUTER_TEAM_ID=") > installCommand
        && yaml.indexOf("export CHATGPT_COMPUTER_TEAM_ID=") < prepare,
      `${workflow} does not pass the runtime-discovered signing team to Computer Use staging`,
    );
    if (workflow.endsWith("apple-store-delivery.yml")) {
      const identity = yaml.indexOf("MACOS_APP_STORE_APP_IDENTITY=$identity");
      assert.ok(identity > installCommand && identity < prepare, `${workflow} does not establish the MAS helper signing identity before staging`);
    }
  }

  const verifier = source(".github/scripts/verify-packaged-computer-control.mjs");
  for (const marker of [
    "active-runtime.json",
    "runtime-manifest.json",
    "ELECTRON_RUN_AS_NODE",
    "tools/list",
    "computer_use_bridge",
    "MAX_DISCOVERY_ENTRIES",
    "MAX_STDOUT_BYTES",
    "MCP_TIMEOUT_MS",
  ]) assert.ok(verifier.includes(marker), `packaged Computer Use verifier is missing ${marker}`);

  for (const workflow of workflows) {
    const yaml = source(workflow);
    const packageApplication = yaml.indexOf("electron-builder");
    const verifierStep = yaml.indexOf("node .github/scripts/verify-packaged-computer-control.mjs", packageApplication);
    assert.ok(packageApplication >= 0 && verifierStep > packageApplication, `${workflow} does not verify Computer Use after packaging`);
    assert.match(yaml, /--release-root desktop\/release/);
  }

  const hotPackage = source(".github/workflows/electron-macos-hot-package.yml");
  assert.match(hotPackage, /workflow_dispatch:/);
  assert.match(hotPackage, /jobs:\s*\n\s*paused:/);
  assert.ok(hotPackage.includes("Superseded by the single Native Electron macOS test release workflow."));
  assert.doesNotMatch(hotPackage, /electron-builder/);
  assert.doesNotMatch(hotPackage, /prepare-fabushi-bundle/);

  const ci = source(".github/workflows/ci.yml");
  for (const marker of [
    "name: CI",
    "pull_request:",
    "merge_group:",
    "name: CI result",
    "Release-control integrity",
    'test "$(jq -r .version app-version.json)" = "$(jq -r .version desktop/package.json)"',
    "release=.github/workflows/native-electron-release.yml",
    "RELEASE_TARGET=macos",
    "RELEASE_TIER=test",
    "bash .github/scripts/require-release-source-gates.sh",
    "already exists; refusing to mutate an existing release",
    "node desktop/scripts/check-app-agent-stable-rebase-contract.mjs",
    "node --test desktop/electron/remote-device-agent-supervisor-packaged-helper.test.cjs",
    "node --test chatgpt-vps-control/tests/ios-interactive-app-e2e-contract.test.js",
  ]) assert.ok(ci.includes(marker), `canonical CI result is missing ${marker}`);
  assert.match(ci, /test "\$\(jq -r \.version app-version\.json\)" = "1\.2\.\d+"/);

  const electron = source(".github/workflows/electron-desktop.yml");
  for (const trigger of [
    "'chatgpt-vps-control/**'",
    "'frontend/apps/web/src/app/remote-computer/**'",
    "'frontend/apps/web/src/lib/remote-computer/**'",
    "'third_party/mahayana/mahayana-rs/mahayana-agent-codex/**'",
  ]) assert.ok(electron.includes(trigger), `Electron PR path trigger is missing ${trigger}`);
});


test("remote computer peers serialize signaling and bound untrusted channel data", () => {
  const desktop = source("frontend/apps/web/src/lib/remote-computer/desktop-peer.ts");
  const mobile = source("frontend/apps/web/src/lib/remote-computer/mobile-peer.ts");
  const page = source("frontend/apps/web/src/app/remote-computer/page.tsx");

  for (const marker of [
    "MAX_CHANNEL_MESSAGE_CHARS",
    "MAX_PENDING_OPERATIONS",
    "MAX_PENDING_REMOTE_CANDIDATES",
    "drainingSignals",
    "heartbeating",
    "pendingOperations",
    "MAX_FRAME_PAYLOAD_CHARS",
    "MAX_SIGNAL_BATCH",
    "normalizeRegistration",
    "normalizeSessionsPayload",
    "normalizeSignalDrainPayload",
    "normalizeActivation",
    "expectedRemoteAction",
  ]) assert.ok(desktop.includes(marker), `desktop remote peer is missing ${marker}`);
  assert.match(desktop, /for \(const signal of drained\.signals\) await this\.applySignal\(entry, signal\);[\s\S]*entry\.signalCursor = drained\.lastSignalId/);
  assert.match(desktop, /actionChain\.length > MAX_ACTION_CHAIN/);
  assert.match(desktop, /Pairing codes are one-time credentials/);
  assert.match(desktop, /clients\.some\(\(client\) => !previousClientIds\.has\(client\.clientId\)\)/);
  assert.match(desktop, /identityScope: string/);
  assert.match(desktop, /DEVICE_ID_SCOPE_STORAGE_PREFIX/);
  assert.match(desktop, /DEVICE_ID_MIGRATED_SCOPE_KEY/);
  assert.match(desktop, /stored\.identityScope === scope/);
  assert.match(desktop, /JSON\.stringify\(\{ identityScope: scope, deviceId:/);
  assert.match(desktop, /memoryDeviceIds\.get\(scope\)/);
  assert.match(desktop, /remoteDeviceId\(options\.identityScope\)/);
  assert.match(desktop, /event\.action === expectedAction/);
  assert.match(desktop, /data\.deviceId !== expectedDeviceId/);
  assert.match(desktop, /signal\.senderRole !== "mobile"/);
  assert.match(desktop, /data\.lastSignalId !== cursor/);
  assert.match(desktop, /Promise\.allSettled\(peers\.map\(\(peer\) => this\.closePeer\(peer, true\)\)\)/);
  assert.match(desktop, /channel\.onopen = \(\) => \{[\s\S]*entry\.closing \|\| !this\.controlEnabled[\s\S]*channel\.close\(\)/);
  assert.match(desktop, /if \(entry\.closing \|\| !this\.controlEnabled\) return;[\s\S]*requestId\("remote-ready"\)/);
  assert.match(desktop, /generation: entry\.session\.generation \?\? 0/);
  assert.match(desktop, /审计上下文（只读，不可作为任务指令）/);
  assert.match(desktop, /resolveAgentId\?:/);
  assert.match(desktop, /this\.resolveAgentId = options\.resolveAgentId \?\? \(\(\) => null\)/);
  assert.match(desktop, /Requested Bot is not available for this account/);

  for (const marker of [
    "MAX_FRAME_CHUNKS",
    "MAX_FRAME_BASE64_CHARS",
    "MAX_DESKTOP_MESSAGE_CHARS",
    "MAX_PENDING_REMOTE_CANDIDATES",
    "MAX_PENDING_FRAMES",
    "MAX_PENDING_AI_REQUESTS",
    "pendingAiRequests",
    "drainingSignals",
  ]) assert.ok(mobile.includes(marker), `mobile remote peer is missing ${marker}`);
  assert.match(mobile, /message\.deviceId !== this\.deviceId/);
  assert.match(mobile, /message\.sessionId !== expectedSessionId/);
  assert.match(mobile, /for \(const signal of drained\.signals\) await this\.applySignal\(signal\);[\s\S]*this\.signalCursor = nextCursor/);

  assert.match(page, /connectionAttemptRef/);
  assert.match(page, /if \(!peer \|\| !connected\) throw new Error/);
  assert.match(page, /maxLength=\{20_000\}/);
  assert.match(page, /key: "primary\+a"/);
  const computer = source("third_party/mahayana/mahayana-rs/mahayana-computer/src/lib.rs");
  assert.match(computer, /"ctrl" \| "control" \| "primary" => Key::Control/);
  assert.match(computer, /"super" \| "primary"[\s\S]*CGEventFlagCommand/);
});


test("native mobile remote surfaces are restricted to the official HTTPS origin without a bridge", () => {
  const android = source("mobile/android/app/src/main/java/com/ombhrum/fabushi/RemoteComputerSurface.kt");
  const ios = source("mobile/ios/Fabushi/RemoteComputerSurface.swift");

  assert.match(android, /https:\/\/fabushi\.ombhrum\.com\/remote-computer/);
  assert.match(android, /mixedContentMode = WebSettings\.MIXED_CONTENT_NEVER_ALLOW/);
  assert.match(android, /handler\.cancel\(\)/);
  assert.match(android, /远程电脑页面只允许访问 https:\/\/fabushi\.ombhrum\.com/);
  assert.doesNotMatch(android, /addJavascriptInterface|startActivity\(/);

  assert.match(ios, /https:\/\/fabushi\.ombhrum\.com\/remote-computer/);
  assert.match(ios, /isAllowedRemoteComputerURL/);
  assert.match(ios, /远程电脑页面只允许访问 https:\/\/fabushi\.ombhrum\.com/);
  assert.doesNotMatch(ios, /WKScriptMessageHandler|userContentController\.add|UIApplication\.shared\.open/);
});


test("device presence stays available while every remote-control path remains opt-in", () => {
  const featureHost = source("third_party/mahayana/mahayana-rs/mahayana-feature-host/src/implementation.rs");
  const remoteStart = featureHost.indexOf("fn execute_remote_computer(");
  const remoteEnd = featureHost.indexOf("fn ensure_computer_origin_allowed(", remoteStart);
  assert.ok(remoteStart >= 0 && remoteEnd > remoteStart, "remote computer executor is missing");
  const remoteExecutor = featureHost.slice(remoteStart, remoteEnd);

  const registerStart = remoteExecutor.indexOf("FeatureCommand::RemoteComputerRegister");
  const heartbeatStart = remoteExecutor.indexOf("FeatureCommand::RemoteComputerHeartbeat");
  const sessionsStart = remoteExecutor.indexOf("FeatureCommand::RemoteComputerSessions");
  const activateStart = remoteExecutor.indexOf("FeatureCommand::RemoteComputerSessionActivate");
  const signalStart = remoteExecutor.indexOf("FeatureCommand::RemoteComputerSignal {");
  const drainStart = remoteExecutor.indexOf("FeatureCommand::RemoteComputerSignalDrain");
  assert.ok(registerStart >= 0 && heartbeatStart > registerStart && sessionsStart > heartbeatStart);
  assert.doesNotMatch(remoteExecutor.slice(registerStart, heartbeatStart), /if !remote_enabled/);
  assert.doesNotMatch(remoteExecutor.slice(heartbeatStart, sessionsStart), /if !remote_enabled/);
  for (const gated of [
    remoteExecutor.slice(sessionsStart, activateStart),
    remoteExecutor.slice(activateStart, signalStart),
    remoteExecutor.slice(signalStart, drainStart),
    remoteExecutor.slice(drainStart),
  ]) assert.match(gated, /if !remote_enabled/);

  const originStart = featureHost.indexOf("fn ensure_computer_origin_allowed(");
  const originEnd = featureHost.indexOf("fn execute_memory(", originStart);
  const originGuard = featureHost.slice(originStart, originEnd);
  assert.match(originGuard, /ComputerControlOrigin::RemoteMobile[\s\S]*!settings\.remote_control_enabled/);
  assert.match(originGuard, /active paired session id/);
  assert.match(originGuard, /target\.device_id[\s\S]*session\.device_id/);
  assert.match(originGuard, /target\.generation != session\.generation/);
});

test("desktop background presence survives tray-unavailable environments", () => {
  const main = source("desktop/electron/main.cjs");
  assert.match(main, /win\.on\('close',[\s\S]*event\.preventDefault\(\)[\s\S]*win\.hide\(\)/);
  assert.match(main, /try \{[\s\S]*const tray = new Tray\(image\)[\s\S]*backgroundTray = tray/);
  assert.match(main, /catch \(cause\)[\s\S]*continuing in background mode/);
  assert.match(main, /second-instance[\s\S]*focusMainWindow\(\)/);
});


test("remote desktop device secrets are private, bounded, and fail closed", () => {
  const featureHost = source("third_party/mahayana/mahayana-rs/mahayana-feature-host/src/implementation.rs");
  assert.match(featureHost, /std::fs::Permissions::from_mode\(0o600\)/);
  assert.match(featureHost, /REMOTE_DEVICE_SECRET_MAX_ENTRIES/);
  assert.match(featureHost, /REMOTE_DEVICE_SECRET_MAX_BYTES/);
  assert.match(featureHost, /metadata\.len\(\) > REMOTE_DEVICE_SECRET_MAX_BYTES/);
  assert.match(featureHost, /secrets\.len\(\) > REMOTE_DEVICE_SECRET_MAX_ENTRIES/);
  assert.match(featureHost, /remote_device_secret_state_limits_fail_closed/);
});


test("paired clients require a possession-bound token before a control session can be created", () => {
  const worker = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/worker_api/remote_computer.rs");
  const migration = source("third_party/mahayana/mahayana-rs/mahayana-platform-worker/migrations/0014_remote_computer_client_tokens.sql");
  const api = source("frontend/apps/web/src/lib/remote-computer/remote-api.ts");
  const mobile = source("frontend/apps/web/src/lib/remote-computer/mobile-peer.ts");

  assert.match(migration, /ADD COLUMN client_token_hash TEXT/);
  assert.match(migration, /SET state = 'closed'/);
  assert.match(migration, /SET revoked_at = COALESCE/);
  assert.doesNotMatch(migration, /client_token TEXT/);
  assert.match(worker, /struct RemoteComputerSessionCreateRequest[\s\S]*client_token: String/);
  assert.match(worker, /client_token_hash IS NOT NULL/);
  assert.match(worker, /constant_time_eq\([\s\S]*client\.client_token_hash/);
  assert.match(worker, /"clientToken": client_token/);
  assert.match(worker, /REMOTE_SESSION_MAX_PER_CLIENT/);
  assert.match(worker, /REMOTE_CLIENT_MAX_PER_DEVICE/);
  assert.match(worker, /REMOTE_COMPUTER_MAX_PER_ACCOUNT/);
  assert.match(worker, /existing\.device_id <> \?1/);
  assert.match(worker, /"computer_limit"/);
  assert.match(worker, /pairing_claim_hash/);
  assert.match(worker, /d1_changes\(results\.first\(\)\)/);
  assert.match(worker, /claim_changes == 0/);
  assert.match(worker, /insert_changes == 0/);
  assert.match(worker, /THEN NULL ELSE \?5 END/);
  assert.match(worker, /pairing_expires_at = CASE/);
  assert.match(worker, /"paired_client_limit"/);
  assert.match(worker, /REMOTE_SIGNAL_MAX_ROWS_PER_SESSION/);
  assert.match(worker, /remote_signal_kind_allowed/);
  assert.match(worker, /raw\[\.\.12\]\.to_ascii_uppercase\(\)/);
  assert.match(worker, /code\.len\(\) != 12/);
  assert.match(api, /clientToken: string/);
  assert.match(api, /PAIRED_CLIENTS_KEY_PREFIX/);
  assert.match(api, /pairedClientsStorageKey\(userId\)/);
  assert.match(api, /accountId: string/);
  assert.match(api, /candidate\.accountId !== expectedAccountId/);
  assert.match(api, /accountIdentity\(refreshed\.userId\) !== accountIdentity\(current\.userId\)/);
  assert.match(api, /clients\/\$\{encodeURIComponent\(result\.clientId\)\}\/revoke/);
  assert.match(api, /assertPairedClientStorageAvailable/);
  assert.match(api, /LEGACY_PAIRED_CLIENTS_KEY/);
  assert.match(api, /JSON\.stringify\(\{ clientId, clientToken \}\)/);
  assert.match(api, /validOpaqueCredential\(raw\.clientToken\)/);
  assert.match(api, /private refreshPromise: Promise<void> \| null/);
  assert.match(api, /normalizeApiBase/);
  assert.match(api, /MOBILE_SIGNAL_KINDS/);
  assert.match(api, /DESKTOP_SIGNAL_KINDS/);
  assert.match(worker, /c\.client_token_hash IS NOT NULL/);
  assert.match(worker, /active_client\.client_token_hash IS NOT NULL/);
  assert.match(worker, /c\.client_token_hash = \?10 AND c\.revoked_at IS NULL/);
  assert.match(worker, /s\.state <> 'closed' AND s\.expires_at > \?6/);
  assert.match(worker, /FROM remote_computer_signals signal[\s\S]*s\.device_id = \?6[\s\S]*c\.revoked_at IS NULL/);
  assert.match(worker, /"control_session_unavailable"/);
  assert.match(mobile, /clientToken: string/);
  assert.match(mobile, /createControlSession\(this\.deviceId, this\.clientId, this\.clientToken\)/);
});


test("the exact-main platform deployment is recoverable and smokes remote-control fail-closed behavior", () => {
  const release = source(".github/workflows/native-electron-release.yml");
  const releaseGate = source(".github/scripts/require-release-source-gates.sh");
  for (const marker of [
    "bash .github/scripts/require-release-source-gates.sh",
    "export RELEASE_TARGET=macos",
    "export RELEASE_TIER=test",
    "already exists; refusing to mutate an existing release",
    'gh release create "$RELEASE_TAG"',
    '--target "$HEAD_SHA"',
    "SHA256SUMS.txt",
  ]) assert.ok(release.includes(marker), `macOS test release is missing ${marker}`);
  assert.match(release, /test "\$\(git rev-parse HEAD\)" = "\$\(git rev-parse refs\/remotes\/origin\/main\)"/);
  for (const marker of [
    "compare/main...$SOURCE_SHA",
    "ahead_by",
    "Required release gate '$required'",
    "'CI result'",
    "'Electron desktop result'",
    "'Native mobile result'",
  ]) assert.ok(releaseGate.includes(marker), `canonical release-source gate is missing ${marker}`);

  const security = source(".github/workflows/computer-control-security.yml");
  assert.match(security, /name: Computer control security result/);
  assert.match(security, /packaged-computer-control-verifier\.test\.js/);
  assert.match(security, /cargo test --locked -p mahayana-host-protocol -p mahayana-computer -p mahayana-feature-host/);

  const workflow = source(".github/workflows/platform-control-plane.yml");
  assert.match(workflow, /cancel-in-progress: \$\{\{ github\.event_name == 'pull_request' \}\}/);
  assert.match(workflow, /deploy --dry-run --outdir/);
  assert.match(workflow, /d1 time-travel info PLATFORM_DB --json/);
  assert.match(workflow, /d1 migrations apply PLATFORM_DB --remote/);
  assert.match(workflow, /mahayana-platform\.bhrumom\.workers\.dev/);
  assert.match(workflow, /api\.ombhrum\.com/);
  assert.match(workflow, /\[ "\$status" = 401 \]/);
  assert.match(workflow, /platform-production-\$\{\{ github\.sha \}\}/);
});


test("browser login cannot leave stale HostClient hydration competing with Messenger", () => {
  const hostClient = source("frontend/apps/web/src/app/host/host-client.tsx");

  assert.match(hostClient, /let disposed = false;[\s\S]*let restoredLoggedIn = false;/);
  assert.match(hostClient, /if \(disposed\) return;[\s\S]*restoredLoggedIn = authState\.loggedIn/);
  assert.match(hostClient, /if \(disposed \|\| !restoredLoggedIn\) return/);
  assert.match(hostClient, /return \(\) => \{\s*disposed = true;\s*unsubscribe\(\);/);
});


test("logged-in desktops stay discoverable while remote control is disabled", () => {
  const hostClient = source("frontend/apps/web/src/app/host/host-client.tsx");
  const shell = source("desktop/src/messaging-shell-v2.tsx");
  const controller = source("frontend/apps/web/src/lib/remote-computer/desktop-peer.ts");

  assert.doesNotMatch(hostClient, /!auth\?\.loggedIn\s*\|\|\s*!preferences\.remoteControlEnabled/);
  assert.match(hostClient, /identityScope: String\(auth\.user\?\.id \?\? auth\.user\?\.username \?\? auth\.user\?\.email\)/);
  assert.match(hostClient, /controlEnabled: preferences\.remoteControlEnabled/);
  assert.match(hostClient, /resolveAgentId:[\s\S]*botsRef\.current\.some/);
  assert.match(hostClient, /remoteControlEnabled: preferences\.remoteControlEnabled/);
  assert.match(shell, /const \[remoteAccountScope, setRemoteAccountScope\]/);
  assert.match(shell, /if \(!hostReady \|\| !remoteAccountScope\) return/);
  assert.match(shell, /identityScope: remoteAccountScope/);
  assert.match(shell, /resolveAgentId:[\s\S]*peersRef\.current\.some/);
  assert.match(controller, /Presence and control are deliberately separate/);
  assert.match(controller, /this\.heartbeatTimer = window\.setInterval/);
  assert.match(controller, /if \(!this\.stopped && this\.controlEnabled\)/);
});
