import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../../", import.meta.url);
const read = (path) => readFile(new URL(path, root), "utf8");

test("latest iOS Grok search button owns one visible and semantic search state", async () => {
  const source = await read("mobile/ios/Fabushi/GrokMobileShell.swift");

  for (const required of [
    '@State private var searchOpen = false',
    'String(searchOpen)',
    'add("grok-mobile-search", role: "button"',
    'name: searchOpen ? "关闭搜索" : "打开搜索"',
    'searchOpen.toggle()',
    'if !searchOpen { query = "" }',
    'searchOpen = true',
    'if searchOpen {',
    '.accessibilityIdentifier("grok-mobile-search")',
    '.accessibilityIdentifier("grok-mobile-search-field")',
  ]) {
    assert.ok(source.includes(required), `missing Grok search invariant: ${required}`);
  }

  assert.doesNotMatch(
    source,
    /Button \{ \} label: \{ Image\(systemName: "magnifyingglass"\) \}/u,
    "the visible latest-UI search control must not remain an empty action",
  );
});
