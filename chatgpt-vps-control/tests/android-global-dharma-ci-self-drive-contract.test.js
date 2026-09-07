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

test("Android Global Dharma journey follows Marketplace to Bot to synchronized Web UI to commerce", async () => {
  const driver = await read("chatgpt-vps-control/scripts/android-global-dharma-public-mcp-e2e.mjs");
  const shell = await read("mobile/android/app/src/main/java/com/ombhrum/fabushi/GlobalDharmaHostShell.kt");

  const marketplaceBackAt = driver.indexOf('action("marketplace-back", "invoke")');
  const shellBackAt = driver.indexOf('action("app-shell", "pressKey", "BACK")');
  const botAt = driver.indexOf('grok-bot-global-dharma-bot');
  const naturalAt = driver.indexOf('现在运行到哪里？请查看状态');
  const openAt = driver.indexOf('mobile-bot-open-miniapp');
  const sharedAt = driver.indexOf('Bot / Web UI 同一共享状态');
  const purchaseAt = driver.indexOf('¥1080 买断（测试）');
  const restoreAt = driver.indexOf('恢复购买');
  assert.ok(marketplaceBackAt >= 0 && marketplaceBackAt < shellBackAt);
  assert.ok(shellBackAt < botAt && botAt < naturalAt && naturalAt < openAt && openAt < sharedAt);
  assert.ok(sharedAt < purchaseAt && purchaseAt < restoreAt);
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
