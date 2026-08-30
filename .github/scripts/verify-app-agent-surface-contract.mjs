#!/usr/bin/env node

import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const toolNames = [
  'fabushi.app.status',
  'fabushi.app.snapshot',
  'fabushi.app.find',
  'fabushi.app.action',
  'fabushi.app.wait',
  'fabushi.app.assert',
];

async function source(relativePath) {
  return readFile(path.join(root, relativePath), 'utf8');
}

function requireIncludes(value, needle, label) {
  if (!value.includes(needle)) throw new Error(`${label} is missing ${needle}`);
}

function requireExcludes(value, pattern, label) {
  if (pattern.test(value)) throw new Error(`${label} contains forbidden ${pattern}`);
}

const files = {
  sdk: await source('frontend/packages/mcp-app-sdk/src/app-surface.ts'),
  webAdapter: await source('frontend/packages/mcp-app-sdk/src/app-surface-webmcp.ts'),
  dom: await source('frontend/apps/web/src/lib/app-agent-surface/dom-agent-surface.ts'),
  webMount: await source('frontend/apps/web/src/app/layout.tsx'),
  desktopRenderer: await source('desktop/src/app-agent-surface.ts'),
  desktopMain: await source('desktop/electron/main.cjs'),
  desktopBridge: await source('desktop/electron/app-agent-surface-server.cjs'),
  privateMcp: await source('chatgpt-vps-control/bin/fabushi-computer-mcp.js'),
  privateTools: await source('chatgpt-vps-control/lib/app-agent-tools.js'),
  privateClient: await source('chatgpt-vps-control/lib/app-agent-surface-client.js'),
  deviceAgent: await source('chatgpt-vps-control/lib/device-agent.js'),
  packageVerifier: await source('.github/scripts/verify-packaged-computer-control.mjs'),
  android: await source('mobile/android/app/src/main/java/com/ombhrum/fabushi/FabushiAppAgentSurface.kt'),
  ios: await source('mobile/ios/Fabushi/FabushiAppAgentSurface.swift'),
  miniAppDesktop: await source('desktop/src/miniapp-webmcp-host.ts'),
  miniAppAndroid: await source('mobile/android/app/src/main/java/com/ombhrum/fabushi/MiniAppWebMcpSurface.kt'),
  miniAppIos: await source('mobile/ios/Fabushi/MiniAppWebMcpSurface.swift'),
};

for (const name of toolNames) {
  for (const [label, value] of Object.entries({
    sdk: files.sdk,
    privateTools: files.privateTools,
    packageVerifier: files.packageVerifier,
    android: files.android,
    ios: files.ios,
  })) requireIncludes(value, name, label);
}

for (const value of [files.sdk, files.privateTools, files.android, files.ios]) {
  requireIncludes(value, 'generation', 'generation-safe App MCP contract');
}
for (const value of [files.privateClient, files.desktopBridge]) {
  requireIncludes(value, 'loopback', 'desktop App MCP loopback boundary');
}
requireIncludes(files.webAdapter, 'registerWebMcpTool', 'WebMCP adapter');
requireIncludes(files.webMount, 'FabushiAppAgentSurface', 'main Web application mount');
requireIncludes(files.privateMcp, 'registerComputerUseTools', 'legacy/full Computer Use registrar');
requireIncludes(files.privateMcp, 'registerAppAgentTools', 'additive App MCP registrar');
requireIncludes(files.privateTools, 'computer_control_route', 'semantic fallback router');
for (const fallback of [
  'computer_browser_snapshot',
  'computer_browser_locator',
  'computer_applications',
  'computer_app_state',
  'computer_elements',
  'computer_element_action',
  'computer_use_bridge',
]) requireIncludes(files.privateTools, fallback, 'third-party semantic fallback router');
requireIncludes(files.deviceAgent, 'client.listTools()', 'dynamic device tool publication');
requireIncludes(files.deviceAgent, 'redactDeviceCallArguments', 'device trace redaction');
requireIncludes(files.deviceAgent, 'redactDeviceCallResult', 'App MCP result trace redaction');
requireIncludes(files.desktopBridge, 'MAX_CONCURRENT_REQUESTS', 'bounded desktop bridge');
requireIncludes(files.desktopBridge, 'authorize(operation)', 'per-request local policy enforcement');
requireIncludes(files.desktopBridge, "mode: 0o600", 'private discovery file');
requireIncludes(files.desktopMain, 'appAgentControlPolicyDecision', 'desktop policy reload boundary');
requireIncludes(files.dom, 'stale_app_surface_generation', 'renderer stale reference rejection');
requireIncludes(files.dom, 'sensitive_app_surface_input_requires_secure_input', 'renderer sensitive input rejection');
requireIncludes(files.android, 'sensitive_app_surface_input_requires_secure_input', 'Android sensitive input rejection');
requireIncludes(files.ios, 'sensitiveInputRequiresSecureInput', 'iOS sensitive input rejection');

for (const [label, value] of Object.entries({
  desktopBridge: files.desktopBridge,
  desktopRenderer: files.desktopRenderer,
  privateTools: files.privateTools,
  android: files.android,
  ios: files.ios,
})) {
  requireExcludes(value, /executeJavaScript|Runtime\.getRuntime\(\)\.exec|ProcessBuilder|child_process|spawn\(|execFile\(|Runtime\.exec/iu, label);
}

// Existing MiniApp WebMCP surfaces are a separate product surface and must not
// be removed while the main App MCP is added.
for (const [label, value] of Object.entries({
  miniAppDesktop: files.miniAppDesktop,
  miniAppAndroid: files.miniAppAndroid,
  miniAppIos: files.miniAppIos,
})) requireIncludes(value, 'WebMcp', label);

console.log(JSON.stringify({
  ok: true,
  version: 1,
  toolNames,
  priority: ['app-mcp', 'browser-semantic', 'native-semantic', 'coordinate-fallback'],
  existingComputerUsePreserved: true,
  existingMiniAppWebMcpPreserved: true,
}, null, 2));
