import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const read = (relativePath) => fs.readFileSync(path.join(repositoryRoot, relativePath), 'utf8');

const hostPath = 'frontend/apps/web/src/app/miniapps/[id]/McpPluginApp.tsx';
const backendPath = 'ai-backend/src/official_mcp_apps.js';
const globalDharmaPath = 'native/global-dharma/crates/global-dharma-mcp/src/main.rs';

test('web host uses MCP Apps 2026-01-26 over stateless POST only', () => {
  const source = read(hostPath);
  assert.match(source, /MCP_APPS_SPECIFICATION = "2026-01-26"/);
  assert.match(source, /MCP_PROTOCOL_VERSION = "2026-07-28"/);
  assert.match(source, /class StatelessMcpHttpClient/);
  assert.match(source, /method: "POST"/);
  assert.match(source, /method === "ui\/initialize"/);
  assert.match(source, /ui\/notifications\/initialized/);
  assert.match(source, /ui\/resource-teardown/);
  assert.match(source, /event\.source !== view \|\| event\.origin !== "null"/);
  assert.match(source, /sandbox="allow-scripts"/);
  assert.doesNotMatch(source, /class McpHttpClient|mcp-session-id|last-event-id/);
  assert.doesNotMatch(source, /client\.(listen|terminate|respond)\(/);
});

test('official HTTP transport rejects legacy session and event replay paths', () => {
  const source = read(backendPath);
  assert.match(source, /createMcpHandler/);
  assert.match(source, /legacy: 'reject'/);
  assert.match(source, /responseMode: 'json'/);
  assert.match(source, /Official MCP Apps use stateless POST only/);
  assert.match(source, /Legacy MCP sessions and event replay are not supported/);
  assert.doesNotMatch(source, /httpSessions|MemoryEventStore|onsessioninitialized|sessionReaper/);
});

test('custom v1 iframe bridge is removed from the shared SDK', () => {
  assert.equal(
    fs.existsSync(path.join(repositoryRoot, 'frontend/packages/mcp-app-sdk/src/bridge.ts')),
    false,
  );
  assert.doesNotMatch(read('frontend/packages/mcp-app-sdk/src/index.ts'), /bridge/);
  assert.doesNotMatch(read('frontend/packages/mcp-app-sdk/package.json'), /bridge/i);
});

test('Global Dharma exposes a stable MCP App resource and performs the View handshake', () => {
  const source = read(globalDharmaPath);
  assert.match(source, /PROTOCOL_VERSION: &str = "2025-11-25"/);
  assert.match(source, /text\/html;profile=mcp-app/);
  assert.match(source, /ui:\/\/fabushi\/global-dharma\/home-v1\.html/);
  assert.match(source, /'2026-01-26'/);
  assert.match(source, /request\('ui\/initialize'/);
  assert.match(source, /ui\/notifications\/initialized/);
  assert.match(source, /ui\/notifications\/size-changed/);
  assert.match(source, /"ui\/visibility": \["app", "model"\]/);
});

test('mobile registry advertises only the MCP Apps host contract', () => {
  const source = read('fabushi/lib/services/mini_app_registry_service.dart');
  assert.match(source, /hostApiVersion: 'mcp-apps-2026-01-26'/);
  assert.doesNotMatch(source, /mcp-2025-06-18/);
});
