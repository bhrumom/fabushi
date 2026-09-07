import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../../", import.meta.url);
const read = (path) => readFile(new URL(path, root), "utf8");

test("Android interactive runner self-drives over public MCP without a ChatGPT plugin prerequisite", async () => {
  const workflow = await read(".github/workflows/android-interactive-app-e2e.yml");
  const runner = await read("chatgpt-vps-control/scripts/run-android-interactive-app-e2e.sh");
  const driver = await read("chatgpt-vps-control/scripts/android-global-dharma-public-mcp-e2e.mjs");

  assert.match(runner, /android-global-dharma-public-mcp-e2e\.mjs/u);
  assert.match(runner, /export EXPECTED_DEVICE_ID="\$DEVICE_ID"/u);
  assert.doesNotMatch(runner, /external @fabushi test/u);
  assert.match(driver, /https:\/\/fabushi-mcp\.ombhrum\.com/u);
  assert.match(driver, /oauth\/register/u);
  assert.match(driver, /name: "list_devices"/u);
  assert.match(driver, /name: "device_call"/u);
  for (const tool of ["status", "snapshot", "find", "action", "wait", "assert"]) {
    assert.match(driver, new RegExp(`fabushi\\.app\\.${tool}`, "u"));
  }

  assert.match(workflow, /ci-public-mcp-driver\.jsonl/u);
  assert.match(workflow, /bot-natural-language-verified/u);
  assert.match(workflow, /sharedRuntimeRestored == true/u);
  assert.match(workflow, /restore-verified/u);
  assert.match(workflow, /journey-complete/u);
});

test("Android Global Dharma journey requires terminal Bot WebMCP evidence before opening synchronized Web UI", async () => {
  const driver = await read("chatgpt-vps-control/scripts/android-global-dharma-public-mcp-e2e.mjs");
  const shell = await read("mobile/android/app/src/main/java/com/ombhrum/fabushi/GlobalDharmaHostShell.kt");

  const marketplaceBackAt = driver.indexOf('action("marketplace-back", "invoke")');
  const shellBackAt = driver.indexOf('action("app-shell", "pressKey", "BACK")');
  const botAt = driver.indexOf('action("grok-bot-global-dharma-bot", "invoke")');
  const naturalAt = driver.indexOf('现在运行到哪里？请查看状态');
  const busyAt = driver.indexOf('waitElement("mobile-bot-stop", "enabled"', naturalAt);
  const terminalAt = driver.indexOf('logCount >= beforeCommandLogCount + 2', busyAt);
  const verifiedAt = driver.indexOf('record("bot-natural-language-verified"', terminalAt);
  const openAt = driver.indexOf('action("mobile-bot-open-miniapp", "invoke")', verifiedAt);
  const sharedAt = driver.indexOf('waitForUiText("Bot / Web UI 同一共享状态"', openAt);
  const purchaseAt = driver.indexOf('¥1080 买断（测试）', sharedAt);
  const restoreAt = driver.indexOf('恢复购买', purchaseAt);

  assert.ok(marketplaceBackAt >= 0 && marketplaceBackAt < shellBackAt);
  assert.ok(shellBackAt < botAt && botAt < naturalAt && naturalAt < busyAt);
  assert.ok(busyAt < terminalAt && terminalAt < verifiedAt && verifiedAt < openAt && openAt < sharedAt);
  assert.ok(sharedAt < purchaseAt && purchaseAt < restoreAt);
  assert.match(driver, /const beforeCommandLogCount = .*role === "log"/u);
  assert.match(driver, /!elements\.some\(\(item\) => item\?\.agentId === "mobile-bot-stop"\)/u);
  assert.match(driver, /assertElement\("mobile-bot-error", "absent"\)/u);
  assert.match(driver, /observedBusy: true/u);
  assert.match(driver, /afterCommandLogCount/u);
  assert.match(driver, /tapUiText\("退出登录"/u);

  assert.match(shell, /restoreSharedRuntime/u);
  assert.match(shell, /__fabushiWebMcp\.call\('status'/u);
  assert.match(shell, /fabushi:shared-runtime-restored/u);
  assert.match(shell, /Bot \/ Web UI 同一共享状态/u);
});

test("Android official WebMCP validates tools/list before tools/call and uses canonical lifetime SKU", async () => {
  const bridge = await read("mobile/android/app/src/main/java/com/ombhrum/fabushi/MiniAppPlatformBridge.kt");
  const listAt = bridge.indexOf('.put("method", "tools/list")');
  const callAt = bridge.indexOf('.put("method", "tools/call")');
  assert.ok(listAt >= 0 && callAt > listAt, "tools/list must be validated before tools/call");
  assert.match(bridge, /Mini App MCP tool \$name is not advertised by tools\/list/u);
  assert.match(bridge, /PRAYER_WHEEL_LIFETIME_SKU = "local-prayer-wheel\.lifetime"/u);
  assert.match(bridge, /PRAYER_WHEEL_LIFETIME_PRODUCT_ID = "prod\.global-dharma\.local-prayer-wheel\.lifetime"/u);
  assert.match(bridge, /PRAYER_WHEEL_LIFETIME_CNY_MINOR = 108_000L/u);
  assert.match(bridge, /fun restorePurchases\(\)/u);
  assert.match(bridge, /fun entitlement\(pluginId: String, capability: String\)/u);
});
