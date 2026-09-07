import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { applyDesktopWindowBranding } from './prepare-desktop-window-branding.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const realMainPath = path.resolve(here, '..', 'electron', 'main.cjs');

const expectedFrameOptions = `  const frameOptions = process.platform === 'darwin'\n    ? { titleBarStyle: 'hiddenInset' }`;
const whiteOverlay = "titleBarOverlay: { color: '#ffffff', symbolColor: '#1f2328', height: 54 }";
const darkOverlay = "titleBarOverlay: { color: '#111111', symbolColor: '#ffffff', height: 54 }";

test('brands the real guarded createWindow source with white native chrome and is idempotent', () => {
  const original = fs.readFileSync(realMainPath, 'utf8');
  const first = applyDesktopWindowBranding(original);
  assert.equal(first.changed, true);
  assert.match(first.source, /function createWindow\(\) \{\n  if \(mainWindow && !mainWindow\.isDestroyed\(\)\) return mainWindow;/u);
  assert.ok(first.source.includes(expectedFrameOptions));
  assert.ok(first.source.includes(whiteOverlay));
  assert.equal(first.source.includes(darkOverlay), false);
  assert.match(first.source, /title: 'Fabushi',\n    \.\.\.frameOptions,/u);

  const second = applyDesktopWindowBranding(first.source);
  assert.equal(second.changed, false);
  assert.equal(second.source, first.source);
});

test('migrates the previous dark branded title bar to the white palette', () => {
  const legacyDark = `function createWindow() {\n  const frameOptions = process.platform === 'darwin'\n    ? { titleBarStyle: 'hiddenInset' }\n    : process.platform === 'win32'\n      ? {\n          titleBarStyle: 'hidden',\n          titleBarOverlay: { color: '#111111', symbolColor: '#ffffff', height: 54 },\n        }\n      : {};\n  const win = new BrowserWindow({\n    title: 'Fabushi',\n    ...frameOptions,\n  });\n}\n`;
  const result = applyDesktopWindowBranding(legacyDark);
  assert.equal(result.changed, true);
  assert.ok(result.source.includes(whiteOverlay));
  assert.equal(result.source.includes(darkOverlay), false);
});

test('preserves CRLF line endings', () => {
  const source = `function createWindow() {\r\n  const win = new BrowserWindow({\r\n    title: '全球法布施',\r\n  });\r\n}\r\n`;
  const result = applyDesktopWindowBranding(source);
  assert.equal(result.changed, true);
  assert.equal(result.source.replace(/\r\n/g, '').includes('\n'), false);
  assert.ok(result.source.includes("title: 'Fabushi'"));
  assert.ok(result.source.includes(whiteOverlay));
});

test('fails closed for duplicate or out-of-scope anchors', () => {
  const duplicate = `function createWindow() {\n  const win = new BrowserWindow({\n    title: '全球法布施',\n  });\n  const win = new BrowserWindow({\n    title: '全球法布施',\n  });\n}\n`;
  assert.throws(() => applyDesktopWindowBranding(duplicate), /branding anchor changed/u);

  const wrongFunction = `function otherWindow() {\n  const win = new BrowserWindow({\n    title: '全球法布施',\n  });\n}\nfunction createWindow() {\n}\n`;
  assert.throws(() => applyDesktopWindowBranding(wrongFunction), /branding anchor changed/u);
});
