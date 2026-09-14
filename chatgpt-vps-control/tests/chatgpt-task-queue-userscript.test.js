import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const extensionRoot = resolve("chrome-platform/extension");

async function source(relative) {
  return readFile(resolve(extensionRoot, relative), "utf8");
}

test("Fabushi packages the existing 0.4.1 auto-confirm userscript and the Task Queue companion", async () => {
  const legacy = await source("userscript/chatgpt-auto-confirm.user.js");
  const taskQueue = await source("marketplace/chatgpt-task-queue.user.js");
  for (const code of [legacy, taskQueue]) {
    assert.match(code, /\/\/ ==UserScript==/);
    assert.match(code, /@match\s+https:\/\/chatgpt\.com\/\*/);
    assert.match(code, /@match\s+https:\/\/chat\.openai\.com\/\*/);
    assert.match(code, /@grant\s+none/);
    assert.doesNotMatch(code, /@match\s+<all_urls>/);
    assert.doesNotMatch(code, /@require|@resource|@connect|@updateURL|@downloadURL/i);
    assert.doesNotMatch(code, /\beval\s*\(|\bnew\s+Function\b|\bimport\s*\(/);
  }
  assert.match(legacy, /fabushi-auto-confirm-root/);
  assert.match(legacy, /navigator\.locks/);
  assert.match(taskQueue, /MAX_RETRIES\s*=\s*2/);
  assert.match(taskQueue, /processQueue/);
  assert.match(taskQueue, /manual action required/i);
});

test("the integrated runner keeps install, enable, lifecycle and desktop-call contracts", async () => {
  const runner = await source("userscript-runner.js");
  const core = await source("userscript-core.js");
  const content = await source("userscript-content.js");
  const recovery = await source("userscript-recovery.js");
  const app = await source("app.js");
  const packager = await readFile(resolve(extensionRoot, "../../scripts/package-chrome-extension.mjs"), "utf8");
  const validator = await readFile(resolve(extensionRoot, "../../scripts/validate-chrome-extension.mjs"), "utf8");
  for (const message of ["fabushi.userscript.list", "fabushi.userscript.install", "fabushi.userscript.setEnabled", "fabushi.userscript.uninstall", "fabushi.userscript.pageReady", "fabushi.userscript.request", "fabushi.userscript.memory.request"]) assert.match(runner, new RegExp(message.replaceAll(".", "\\.")));
  assert.match(runner, /chrome\.runtime\.onStartup/);
  assert.match(runner, /chrome\.runtime\.onInstalled/);
  assert.match(runner, /chrome\.tabs\.onUpdated/);
  assert.match(runner, /__fabushiDesktopRequest/);
  assert.match(runner, /chrome\.tabs\.discard/);
  assert.match(runner, /userscript-memory-policy/);
  assert.match(runner, /requestTabMemoryCleanup/);
  assert.match(packager, /"userscript-memory-policy\\.js"/);
  assert.match(validator, /"userscript-memory-policy\\.js"/);
  assert.match(core, /forbiddenDirectives/);
  assert.match(core, /dynamic WebAssembly/);
  assert.match(content, /fabushi\.userscript\.pageReady/);
  assert.match(content, /tab-memory\.request/);
  assert.match(content, /tab-memory\.response/);
  assert.match(content, /fabushi\.userscript\.recovery\.request/);
  assert.match(content, /recovery-capability\.granted/);
  assert.match(recovery, /chrome\.alarms\.onAlarm/);
  assert.match(recovery, /chrome\.tabs\.onUpdated/);
  assert.match(recovery, /chrome\.tabs\.onRemoved/);
  assert.match(recovery, /chrome-error/);
  assert.match(recovery, /tab-recovery/);
  assert.doesNotMatch(recovery, /goal|prompt|file\s*:/i);
  assert.match(app, /userscript-chatgpt-task-queue/);
  assert.match(app, /fabushi\.userscript\.install/);
});


test("memory host policy is fail-closed for active, unsafe and unapproved tabs", async () => {
  const { validateMemoryRequest } = await import("../chrome-platform/extension/userscript-memory-policy.js");
  const record = { sourcePluginId: "chatgpt-auto-confirm", enabled: true };
  const base = {
    pluginId: "chatgpt-auto-confirm",
    payload: {
      capability: "tab-memory-discard",
      pressure: "high",
      safeToDiscard: true,
      userInitiated: false,
    },
  };
  assert.equal(validateMemoryRequest(base, {
    record,
    tab: { id: 7, url: "https://chatgpt.com/c/test", active: true },
  }).reason, "active-tab");
  assert.equal(validateMemoryRequest({
    ...base,
    payload: { ...base.payload, hasDraft: true },
  }, {
    record,
    tab: { id: 7, url: "https://chatgpt.com/c/test", active: false },
  }).reason, "unsafe-state");
  assert.equal(validateMemoryRequest(base, {
    record,
    tab: { id: 7, url: "https://example.com/", active: false },
  }).reason, "unapproved-page");
  assert.equal(validateMemoryRequest(base, {
    record,
    tab: { id: 7, url: "https://chatgpt.com/c/test", active: false },
    cooldownRemaining: 2500,
  }).reason, "cooldown");
  assert.equal(validateMemoryRequest(base, {
    record,
    tab: { id: 7, url: "https://chatgpt.com/c/test", active: false },
  }).canDiscard, true);
});
