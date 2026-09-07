import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const scriptPath = resolve("extension/marketplace/chatgpt-task-queue.user.js");
const appPath = resolve("extension/app.js");

async function source(path) {
  return readFile(path, "utf8");
}

test("ChatGPT task queue userscript is packaged with narrow host metadata", async () => {
  const code = await source(scriptPath);
  assert.match(code, /\/\/ ==UserScript==/);
  assert.match(code, /@name\s+Fabushi ChatGPT Task Queue/);
  assert.match(code, /@version\s+1\.0\.0/);
  assert.match(code, /@match\s+https:\/\/chatgpt\.com\/\*/);
  assert.match(code, /@match\s+https:\/\/chat\.openai\.com\/\*/);
  assert.match(code, /@grant\s+none/);
  assert.doesNotMatch(code, /@match\s+<all_urls>/);
  assert.doesNotMatch(code, /@require|@resource|@connect|@updateURL|@downloadURL/i);
  assert.doesNotMatch(code, /\beval\s*\(|\bnew\s+Function\b|\bimport\s*\(/);
});

test("ChatGPT task queue userscript implements queue, retry, completion and human safety gates", async () => {
  const code = await source(scriptPath);
  assert.match(code, /MAX_RETRIES\s*=\s*2/);
  assert.match(code, /processQueue/);
  assert.match(code, /waitForCompletion/);
  assert.match(code, /stopGeneratingVisible/);
  assert.match(code, /item\.status = "retrying"/);
  assert.match(code, /LOGIN_OR_CHALLENGE/);
  assert.match(code, /SENSITIVE/);
  assert.match(code, /EXPLICIT_CHATGPT/);
  assert.match(code, /manual action required/i);
  assert.match(code, /sensitive operation/);
  assert.match(code, /confirmation is not explicitly addressed to @ChatGPT/);
  assert.match(code, /Auto-confirmed/);
});

test("Marketplace catalog exposes task queue only as chrome-extension userscript and installs packaged source", async () => {
  const app = await source(appPath);
  assert.match(app, /id: "userscript-chatgpt-task-queue"/);
  assert.match(app, /kind: "userscript"/);
  assert.match(app, /platforms: \["chrome-extension"\]/);
  assert.match(app, /sourcePath: "marketplace\/chatgpt-task-queue\.user\.js"/);
  assert.match(app, /loadUserscriptSource/);
  assert.match(app, /chrome\.runtime\.getURL\(item\.sourcePath\)/);
  assert.match(app, /source: \{ kind: "marketplace", pluginId: item\.id, version: item\.version, sha256: digest \}/);
  assert.match(app, /item\.kind === "userscript"/);
  assert.match(app, /currentPlatform === "chrome-extension"/);
});
