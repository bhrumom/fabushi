'use strict';

// Electron sandboxed preloads may only require Electron and a small set of
// built-ins. Keep this file self-contained; the main process remains the
// authority that validates the registered edge/method allowlists.
const { contextBridge, ipcRenderer } = require('electron');

const MAHAYANA_EDGE = 'mahayana-host';
const NATIVE_EDGE = 'native-desktop';
const MAHAYANA_RUNTIME_EVENT = 'runtime-event';
const EDGE_CONTRACT_VERSION = 1;
const DESIGN_SKILL_MARKER = '[Fabushi Design Skill activated]';
const NATIVE_EVENTS = new Set([
  'mcp-auth-completed',
  'focus-agent',
  'cloud-agent-open',
  'shared-room-changed',
  'deep-link',
  'compute-migration',
  'dev-compute-rebuild',
  'open-feedback',
  'open-about',
  'widget-gallery',
  'force-onboarding',
  'account-auth-changed',
  'experiments-changed',
  'window-state',
  'zoom-factor-changed',
  'update-computer-dispatched',
  'offline-asr-progress',
  'open-offline-asr',
  'remote-desktop-user-presence',
  'dev-compute-pull-progress',
  'egress-tunnel-changed',
  'egress-tunnel-status-changed',
  'webauthn-proxy-changed',
  'skip-onboarding',
  'theme-changed',
  'update-status',
  'messaging-call-signal',
  'messaging-call-status',
]);

function callChannel(edge, method) {
  return `fabushi-edge:${edge}:call:${method}`;
}

function eventChannel(edge, eventName) {
  return `fabushi-edge:${edge}:event:${eventName}`;
}

function failureMessage(failure) {
  if (!failure || typeof failure !== 'object') return 'Native edge call failed.';
  const code = typeof failure.code === 'string' ? failure.code : 'bridge/invoke-failed';
  const detail = typeof failure.detail === 'string' ? failure.detail : 'Native edge call failed.';
  return `${code}: ${detail}`;
}

async function invokeEdge(edge, method, params = {}) {
  const reply = await ipcRenderer.invoke(callChannel(edge, method), params ?? {});
  if (!reply || typeof reply !== 'object' || typeof reply.ok !== 'boolean') {
    throw new Error('bridge/invoke-failed: Native edge returned an invalid reply.');
  }
  if (reply.ok) return reply.value;
  throw new Error(failureMessage(reply.failure));
}

function subscribeEdge(edge, eventName, listener) {
  if (typeof listener !== 'function') return () => {};
  const channel = eventChannel(edge, eventName);
  const forward = (_event, payload) => listener(payload);
  ipcRenderer.on(channel, forward);
  return () => ipcRenderer.off(channel, forward);
}

function isRecord(value) {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
}

function isFabushiDesignIntent(text) {
  const normalized = String(text || '').trim().toLocaleLowerCase();
  if (!normalized || normalized.includes(DESIGN_SKILL_MARKER.toLocaleLowerCase())) return false;
  return /(?:设计|界面|ui\b|ux\b|小程序|mini\s*app|网页|网站|landing\s*page|dashboard|仪表盘|原型|prototype|artifact|pptx?|幻灯片|演示文稿|deck\b|海报|封面|视觉|design\s*system|design\b)/i.test(normalized);
}

function designWorkspaceId(command) {
  const source = String(command.agentId || command.conversationId || 'mahayana-assistant');
  const slug = source.replace(/[^a-zA-Z0-9._-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 96);
  return slug || 'mahayana-assistant';
}

function renderDesignModeStatement(context, existing) {
  const craft = Array.isArray(context.craft)
    ? context.craft.map((entry) => `[Craft: ${entry.slug}]\n${entry.content}`).join('\n\n')
    : '';
  const previous = typeof existing === 'string' && existing.trim()
    ? `[Existing mode statement]\n${existing.trim()}\n\n`
    : '';
  return `${previous}${DESIGN_SKILL_MARKER}
This context augments the current turn inside the single Mahayana Runtime. It is not a second agent loop and must not override Mahayana permissions, sandboxing, approvals, MiniApp policy, or tool authority.

[Portable Fabushi SKILL.md]
${context.skill}

${craft}

[Canonical Fabushi DESIGN.md]
${context.designSystem.design}

[Canonical Fabushi tokens.css]
${context.designSystem.tokens}

[Artifact delivery]
Create real project files in the active Mahayana workspace. When the output is a web page, dashboard, MiniApp, deck, document, image, video, audio, or data artifact, emit a 'mahayana-artifact/v1' manifest in the run result with a safe relative entrypoint and designSystemId 'fabushi'. Only expose export formats confirmed by the trusted Host. MiniApps must use the existing Fabushi MiniApp/WebMCP/marketplace pipeline; never bypass capability review.`;
}

async function enrichMahayanaParams(method, params) {
  if (method !== 'feature.execute' || !isRecord(params) || !isRecord(params.command)) return params;
  const command = params.command;
  if (command.type !== 'chat.send' || typeof command.text !== 'string' || !isFabushiDesignIntent(command.text)) return params;
  try {
    const context = await invokeEdge(NATIVE_EDGE, 'getDesignSkillContext', {
      skillId: 'fabushi-design',
      workspaceId: designWorkspaceId(command),
    });
    if (!isRecord(context) || context.schemaVersion !== 'fabushi-design-skill-context/v1') {
      throw new Error('bridge/invoke-failed: Invalid design Skill context.');
    }
    return {
      ...params,
      command: {
        ...command,
        modeStatement: renderDesignModeStatement(context, command.modeStatement),
      },
    };
  } catch (error) {
    // Design enrichment is additive. If the trusted Host refuses it, preserve
    // the ordinary Mahayana turn and never fall back to arbitrary filesystem
    // reads or a renderer-owned permission path.
    console.warn('Fabushi design Skill context unavailable', error);
    return params;
  }
}

const mahayana = Object.freeze({
  contractVersion: EDGE_CONTRACT_VERSION,
  async invoke(method, params = {}) {
    return invokeEdge(MAHAYANA_EDGE, method, await enrichMahayanaParams(method, params));
  },
  subscribe(listener) {
    return subscribeEdge(MAHAYANA_EDGE, MAHAYANA_RUNTIME_EVENT, listener);
  },
});

contextBridge.exposeInMainWorld('mahayana', mahayana);

contextBridge.exposeInMainWorld('fabushiNative', Object.freeze({
  contractVersion: EDGE_CONTRACT_VERSION,
  invoke(method, params = {}) {
    return invokeEdge(NATIVE_EDGE, method, params);
  },
  subscribe(listeners = {}) {
    if (!listeners || typeof listeners !== 'object') return () => {};
    const cleanup = [];
    for (const eventName of NATIVE_EVENTS) {
      const listener = listeners[eventName];
      if (typeof listener === 'function') cleanup.push(subscribeEdge(NATIVE_EDGE, eventName, listener));
    }
    return () => cleanup.splice(0).forEach((dispose) => dispose());
  },
}));

contextBridge.exposeInMainWorld('fabushi', Object.freeze({
  contractVersion: EDGE_CONTRACT_VERSION,
  pickFile() {
    return ipcRenderer.invoke('fabushi:pick-file');
  },
  notify(title, body) {
    return ipcRenderer.invoke('fabushi:notify', { title, body });
  },
  openExternal(url) {
    return ipcRenderer.invoke('fabushi:open-external', { url });
  },
  openSystemSettings(pane) {
    return ipcRenderer.invoke('fabushi:open-system-settings', { pane });
  },
  windowFocused() {
    return ipcRenderer.invoke('fabushi:window-focused');
  },
}));
