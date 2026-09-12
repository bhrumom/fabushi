import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const extensionRoot = resolve("chrome-platform/extension");

test("Chrome extension action opens the unified Fabushi application shell", async () => {
  const manifest = JSON.parse(await readFile(resolve(extensionRoot, "manifest.json"), "utf8"));
  const appHtml = await readFile(resolve(extensionRoot, "app.html"), "utf8");
  const appJs = await readFile(resolve(extensionRoot, "app.js"), "utf8");

  assert.equal(manifest.action.default_popup, "app.html");
  assert.equal(manifest.background.service_worker, "service-worker.js");
  assert.deepEqual(manifest.host_permissions, ["<all_urls>"]);
  assert.equal(manifest.content_scripts?.[0]?.js?.[0], "userscript-content.js");
  for (const label of ["Fabushi", "聊天", "小程序", "Marketplace", "浏览器", "设置"]) assert.match(appHtml, new RegExp(label));
  assert.match(appHtml, /id="search"/);
  assert.match(appHtml, /src="app\.js"/);
  assert.match(appJs, /feature\.marketplace\.browse/);
  assert.match(appJs, /fabushi\.browser\.status/);
  assert.match(appJs, /fabushi\.platform\.request/);
  assert.match(appJs, /import-userscript/);
  assert.match(appJs, /chatgpt-auto-confirm/);
});
