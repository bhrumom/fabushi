import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

test("Chrome extension action opens the Fabushi application shell", async () => {
  const manifest = JSON.parse(await readFile(resolve("extension/manifest.json"), "utf8"));
  const appHtml = await readFile(resolve("extension/app.html"), "utf8");
  const appJs = await readFile(resolve("extension/app.js"), "utf8");

  assert.equal(manifest.action.default_popup, "app.html");
  assert.match(appHtml, />Fabushi</);
  assert.match(appHtml, />Chats</);
  assert.match(appHtml, />Mini Apps</);
  assert.match(appHtml, />Marketplace</);
  assert.match(appHtml, /type="search"/);
  assert.match(appHtml, /src="app\.js"/);
  assert.match(appJs, /data-section/);
  assert.match(appJs, /Marketplace/);
});
