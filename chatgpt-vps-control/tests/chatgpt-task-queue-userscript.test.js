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
  const app = await source("app.js");
  for (const message of ["fabushi.userscript.list", "fabushi.userscript.install", "fabushi.userscript.setEnabled", "fabushi.userscript.uninstall", "fabushi.userscript.pageReady", "fabushi.userscript.request"]) assert.match(runner, new RegExp(message.replaceAll(".", "\\.")));
  assert.match(runner, /chrome\.runtime\.onStartup/);
  assert.match(runner, /chrome\.runtime\.onInstalled/);
  assert.match(runner, /chrome\.tabs\.onUpdated/);
  assert.match(runner, /__fabushiDesktopRequest/);
  assert.match(core, /forbiddenDirectives/);
  assert.match(core, /dynamic WebAssembly/);
  assert.match(content, /fabushi\.userscript\.pageReady/);
  assert.match(app, /userscript-chatgpt-task-queue/);
  assert.match(app, /fabushi\.userscript\.install/);
});
