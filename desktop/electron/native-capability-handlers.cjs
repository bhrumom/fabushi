'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');

const MAX_TEXT_BYTES = 5 * 1024 * 1024;
const MAX_BINARY_BYTES = 32 * 1024 * 1024;
const MAX_DOWNLOAD_BYTES = 64 * 1024 * 1024;
const MAX_DIAGNOSTIC_BYTES = 256 * 1024;
const SENSITIVE_KEY = /(secret|token|password|authorization|cookie|credential|private.?key)/i;
const LOCAL_TOOL_PERMISSIONS = new Set(['never', 'ask', 'always']);
const UPDATE_TRACKS = new Set(['stable', 'beta', 'alpha']);

function cleanString(value, limit = 4096) {
  return String(value ?? '').replace(/\0/g, '').trim().slice(0, limit);
}

function safeFileName(value, fallback = 'attachment.bin') {
  const base = path.basename(cleanString(value, 220) || fallback);
  const sanitized = base.replace(/[<>:"/\\|?*\x00-\x1f]/g, '_').replace(/^\.+/, '').trim();
  return sanitized || fallback;
}

function mimeForPath(filePath) {
  switch (path.extname(filePath).toLowerCase()) {
    case '.png': return 'image/png';
    case '.jpg': case '.jpeg': return 'image/jpeg';
    case '.webp': return 'image/webp';
    case '.gif': return 'image/gif';
    case '.svg': return 'image/svg+xml';
    case '.pdf': return 'application/pdf';
    case '.json': return 'application/json';
    case '.md': case '.markdown': return 'text/markdown';
    case '.txt': case '.log': case '.csv': case '.tsv': return 'text/plain';
    case '.mp3': return 'audio/mpeg';
    case '.wav': return 'audio/wav';
    case '.m4a': return 'audio/mp4';
    case '.mp4': return 'video/mp4';
    default: return 'application/octet-stream';
  }
}

function redact(value, depth = 0) {
  if (depth > 6) return '[truncated]';
  if (value == null || typeof value === 'number' || typeof value === 'boolean') return value;
  if (typeof value === 'string') return value.length > 4000 ? `${value.slice(0, 4000)}…` : value;
  if (Array.isArray(value)) return value.slice(0, 100).map((item) => redact(item, depth + 1));
  if (typeof value !== 'object') return String(value);
  const out = {};
  for (const [key, item] of Object.entries(value).slice(0, 100)) {
    out[key] = SENSITIVE_KEY.test(key) ? '[redacted]' : redact(item, depth + 1);
  }
  return out;
}

function xmlEscape(value) {
  return String(value).replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;',
  })[character]);
}

function dataUrl(mimeType, bytes) {
  return `data:${mimeType};base64,${bytes.toString('base64')}`;
}

function requestId(prefix) {
  return `${prefix}-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;
}

function ensureWithin(root, candidate) {
  const normalizedRoot = path.resolve(root);
  const normalized = path.resolve(candidate);
  if (normalized !== normalizedRoot && !normalized.startsWith(`${normalizedRoot}${path.sep}`)) {
    throw new Error('Path escaped the managed desktop storage root.');
  }
  return normalized;
}

async function readLimitedFile(filePath, maxBytes) {
  const stat = await fs.stat(filePath);
  if (!stat.isFile()) throw new Error('Requested path is not a file.');
  if (stat.size > maxBytes) throw new Error(`File exceeds ${maxBytes} byte limit.`);
  return { stat, bytes: await fs.readFile(filePath) };
}

function createNativeCapabilityHandlers(deps) {
  const {
    app,
    autoUpdater,
    dialog,
    net,
    safeStorage,
    shell,
    host,
    readNativeState,
    mutateNativeState,
    windowForEvent,
    broadcastNativeEvent,
  } = deps;

  const telemetryPath = () => path.join(app.getPath('userData'), 'diagnostics', 'native-events.ndjson');
  const feedbackPath = () => path.join(app.getPath('userData'), 'feedback', 'feedback.ndjson');
  const secretPath = () => path.join(app.getPath('userData'), 'secure', 'secrets.json');
  const stagedRoot = () => path.join(app.getPath('userData'), 'attachments', 'staged');
  const committedRoot = () => path.join(app.getPath('userData'), 'attachments', 'committed');

  async function appendJsonLine(target, record) {
    await fs.mkdir(path.dirname(target), { recursive: true });
    let line = JSON.stringify(record);
    if (Buffer.byteLength(line) > MAX_DIAGNOSTIC_BYTES) {
      line = JSON.stringify({
        type: record.type ?? 'oversized',
        timestamp: record.timestamp ?? new Date().toISOString(),
        truncated: true,
      });
    }
    await fs.appendFile(target, `${line}\n`, { mode: 0o600 });
  }

  async function report(type, params) {
    const record = {
      type,
      timestamp: new Date().toISOString(),
      payload: redact(params),
    };
    await appendJsonLine(telemetryPath(), record);
    return { recorded: true, type, timestamp: record.timestamp };
  }

  async function getPreference(key, fallback = null) {
    const state = await readNativeState();
    return state.preferences?.[key] ?? fallback;
  }

  async function setPreference(key, value) {
    await mutateNativeState((state) => ({
      ...state,
      preferences: { ...(state.preferences ?? {}), [key]: value },
    }));
    return value;
  }

  async function featureExecute(command) {
    return host.request('feature.execute', { command });
  }

  async function loadSecretVault() {
    try {
      const parsed = JSON.parse(await fs.readFile(secretPath(), 'utf8'));
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
    } catch (error) {
      if (error?.code === 'ENOENT') return {};
      throw error;
    }
  }

  async function saveSecretVault(vault) {
    await fs.mkdir(path.dirname(secretPath()), { recursive: true });
    const temp = `${secretPath()}.tmp`;
    await fs.writeFile(temp, `${JSON.stringify(vault, null, 2)}\n`, { mode: 0o600 });
    await fs.rename(temp, secretPath());
  }

  function requireSecretEncryption() {
    if (!safeStorage?.isEncryptionAvailable?.()) {
      throw new Error('OS-backed secret encryption is not available on this device.');
    }
  }

  async function installedPluginPointers() {
    const catalog = await host.request('marketplace.browse', { query: '', platform: process.platform }).catch(() => []);
    const entries = Array.isArray(catalog) ? catalog : Array.isArray(catalog?.plugins) ? catalog.plugins : [];
    const pointers = [];
    for (const entry of entries.slice(0, 200)) {
      const pluginId = cleanString(entry?.id ?? entry?.pluginId, 200);
      if (!pluginId) continue;
      const pointer = await host.request('plugin.active', { pluginId }).catch(() => null);
      if (pointer) pointers.push({ pluginId, ...pointer });
    }
    return pointers;
  }

  async function currentUpdateStatus() {
    const state = await readNativeState();
    return state.updateStatus ?? {
      type: 'upToDate',
      version: app.getVersion(),
      track: state.preferences?.updateTrack ?? 'stable',
    };
  }

  async function writeUpdateStatus(status) {
    await mutateNativeState((state) => ({ ...state, updateStatus: status }));
    broadcastNativeEvent('update-status', status);
    return status;
  }

  const handlers = {
    async submitFeedback(params) {
      const id = crypto.randomUUID();
      const record = {
        id,
        createdAtMs: Date.now(),
        category: cleanString(params.category ?? 'general', 80),
        message: cleanString(params.message ?? params.text, 12000),
        context: redact(params.context ?? {}),
      };
      if (!record.message) throw new Error('Feedback message is required.');
      await appendJsonLine(feedbackPath(), record);
      return { id, stored: true, createdAtMs: record.createdAtMs };
    },

    setTitleBarOverlayTone(params, event) {
      const win = windowForEvent(event);
      if (typeof win.setTitleBarOverlay !== 'function') return { supported: false };
      const tone = cleanString(params.tone ?? params.preference ?? 'system', 20);
      const dark = tone === 'dark' || (tone === 'system' && deps.nativeTheme?.shouldUseDarkColors);
      const overlay = {
        color: cleanString(params.color, 32) || (dark ? '#111111' : '#ffffff'),
        symbolColor: cleanString(params.symbolColor, 32) || (dark ? '#ffffff' : '#111111'),
        height: Number.isFinite(Number(params.height)) ? Math.max(20, Math.min(80, Number(params.height))) : 32,
      };
      win.setTitleBarOverlay(overlay);
      return { supported: true, ...overlay };
    },

    async getHardwareAcceleration() {
      const enabled = await getPreference('hardwareAccelerationEnabled', true);
      return { enabled: enabled !== false, requiresRelaunch: false };
    },

    async setHardwareAccelerationEnabled(params) {
      const enabled = params.enabled !== false;
      await setPreference('hardwareAccelerationEnabled', enabled);
      return { enabled, requiresRelaunch: true };
    },

    async getEgressTunnelEnabled() {
      const providerAvailable = Boolean(process.env.FABUSHI_EGRESS_TUNNEL_URL?.trim());
      const requested = await getPreference('egressTunnelEnabled', false);
      return providerAvailable && requested === true;
    },

    async setEgressTunnelEnabled(params) {
      const providerAvailable = Boolean(process.env.FABUSHI_EGRESS_TUNNEL_URL?.trim());
      const enabled = params.enabled === true && providerAvailable;
      await setPreference('egressTunnelEnabled', enabled);
      broadcastNativeEvent('egress-tunnel-changed', enabled);
      broadcastNativeEvent('egress-tunnel-status-changed', await this.getEgressTunnelStatus());
      return enabled;
    },

    async getEgressTunnelStatus() {
      const provider = process.env.FABUSHI_EGRESS_TUNNEL_URL?.trim() || null;
      const enabled = provider ? await getPreference('egressTunnelEnabled', false) === true : false;
      return {
        available: Boolean(provider),
        enabled,
        state: !provider ? 'unavailable' : enabled ? 'connected' : 'disabled',
        reason: provider ? null : 'No managed egress tunnel provider is configured.',
      };
    },

    async getWebauthnProxyEnabled() {
      const available = process.env.FABUSHI_WEBAUTHN_PROXY_AVAILABLE === '1';
      return available && await getPreference('webauthnProxyEnabled', false) === true;
    },

    async setWebauthnProxyEnabled(params) {
      const available = process.env.FABUSHI_WEBAUTHN_PROXY_AVAILABLE === '1';
      const enabled = params.enabled === true && available;
      await setPreference('webauthnProxyEnabled', enabled);
      broadcastNativeEvent('webauthn-proxy-changed', enabled);
      return enabled;
    },

    getUpdateStatus() {
      return currentUpdateStatus();
    },

    async checkForUpdates() {
      if (!app.isPackaged || !autoUpdater?.checkForUpdates) {
        return writeUpdateStatus({ type: 'upToDate', version: app.getVersion(), source: 'local-build' });
      }
      await writeUpdateStatus({ type: 'checking', version: app.getVersion() });
      try {
        await autoUpdater.checkForUpdates();
        return currentUpdateStatus();
      } catch (error) {
        return writeUpdateStatus({ type: 'error', message: error instanceof Error ? error.message : String(error) });
      }
    },

    async setUpdateTrack(params) {
      const track = cleanString(params.track ?? 'stable', 20);
      if (!UPDATE_TRACKS.has(track)) throw new Error('Unsupported update track.');
      await setPreference('updateTrack', track);
      return { ...(await currentUpdateStatus()), track };
    },

    async quitAndInstallUpdate(params) {
      const status = await currentUpdateStatus();
      const expected = cleanString(params.expectedVersion, 80);
      if (expected && status.version && expected !== status.version) throw new Error('Update version changed before install.');
      if (!autoUpdater?.quitAndInstall || status.type !== 'ready') {
        return { installed: false, reason: 'No downloaded desktop update is ready.' };
      }
      setImmediate(() => autoUpdater.quitAndInstall());
      return { installed: true, version: status.version ?? null };
    },

    async setAutoUpdateWhenIdleOptIn(params) {
      return setPreference('autoUpdateWhenIdle', params.enabled === true);
    },

    async getComputeMigrationStatus() {
      const value = await getPreference('computeMigrationStatus', null);
      return value ?? { required: false, status: 'complete', provider: 'mahayana' };
    },

    async markDeepLinksReady() {
      await setPreference('deepLinksReady', true);
      return { ready: true, pending: [] };
    },

    getAutoReviewInstructions() {
      return getPreference('autoReviewInstructions', '');
    },

    async setAutoReviewInstructions(params) {
      return setPreference('autoReviewInstructions', cleanString(params.instructions, 20000));
    },

    getLocalToolPermission() {
      return getPreference('localToolPermission', 'ask');
    },

    async getLocalToolPermissionCeiling() {
      const ceiling = cleanString(process.env.FABUSHI_LOCAL_TOOL_PERMISSION_CEILING ?? 'always', 20);
      return LOCAL_TOOL_PERMISSIONS.has(ceiling) ? ceiling : 'always';
    },

    async setLocalToolPermission(params) {
      const permission = cleanString(params.permission ?? 'ask', 20);
      if (!LOCAL_TOOL_PERMISSIONS.has(permission)) throw new Error('Unsupported local tool permission.');
      const ceiling = await this.getLocalToolPermissionCeiling();
      const order = ['never', 'ask', 'always'];
      if (order.indexOf(permission) > order.indexOf(ceiling)) throw new Error('Permission exceeds administrator ceiling.');
      await setPreference('localToolPermission', permission);
      return permission;
    },

    async recordLocalToolApproval(params) {
      const approvalId = cleanString(params.approvalId, 160);
      if (!approvalId) throw new Error('Approval ID is required.');
      const entry = {
        approvalId,
        action: cleanString(params.action, 120),
        target: cleanString(params.target, 1000),
        recordedAtMs: Date.now(),
      };
      await mutateNativeState((state) => ({
        ...state,
        localToolApprovals: { ...(state.localToolApprovals ?? {}), [approvalId]: entry },
      }));
      return entry;
    },

    async clearLocalToolApprovals() {
      await mutateNativeState((state) => ({ ...state, localToolApprovals: {} }));
      return true;
    },

    async pickAvatarSource() {
      const result = await dialog.showOpenDialog({
        title: 'Choose avatar source',
        properties: ['openFile'],
        filters: [{ name: 'Images', extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'svg'] }],
      });
      return result.canceled || !result.filePaths[0] ? null : { path: result.filePaths[0] };
    },

    async pickAvatarFile() {
      const result = await this.pickAvatarSource();
      if (!result) return null;
      const { bytes, stat } = await readLimitedFile(result.path, 8 * 1024 * 1024);
      const mimeType = mimeForPath(result.path);
      return { path: result.path, name: path.basename(result.path), sizeBytes: stat.size, mimeType, bytesBase64: bytes.toString('base64'), dataUrl: dataUrl(mimeType, bytes) };
    },

    async generateAgentAvatarImage(params) {
      const label = cleanString(params.prompt ?? params.name ?? params.agentId ?? 'Fabushi', 80) || 'Fabushi';
      const digest = crypto.createHash('sha256').update(label).digest();
      const hueA = digest.readUInt16BE(0) % 360;
      const hueB = (hueA + 40 + (digest[2] % 120)) % 360;
      const initials = label.split(/\s+/u).filter(Boolean).slice(0, 2).map((part) => [...part][0]).join('').toUpperCase().slice(0, 2) || 'F';
      const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="hsl(${hueA} 72% 54%)"/><stop offset="1" stop-color="hsl(${hueB} 68% 38%)"/></linearGradient></defs><rect width="512" height="512" rx="144" fill="url(#g)"/><circle cx="256" cy="226" r="112" fill="rgba(255,255,255,.14)"/><text x="256" y="286" text-anchor="middle" font-family="system-ui,sans-serif" font-size="148" font-weight="700" fill="white">${xmlEscape(initials)}</text></svg>`;
      const bytes = Buffer.from(svg);
      return { mimeType: 'image/svg+xml', width: 512, height: 512, bytesBase64: bytes.toString('base64'), dataUrl: dataUrl('image/svg+xml', bytes), source: 'fabushi-local-generator' };
    },

    async resolveAttachmentMedia(params) {
      const filePath = path.resolve(cleanString(params.path ?? params.filePath, 4096));
      const { stat } = await readLimitedFile(filePath, MAX_BINARY_BYTES);
      return { path: filePath, name: path.basename(filePath), mimeType: mimeForPath(filePath), sizeBytes: stat.size, modifiedAtMs: stat.mtimeMs };
    },

    async readAttachmentText(params) {
      const filePath = path.resolve(cleanString(params.path ?? params.filePath, 4096));
      const { bytes, stat } = await readLimitedFile(filePath, MAX_TEXT_BYTES);
      return { path: filePath, text: bytes.toString(params.encoding === 'latin1' ? 'latin1' : 'utf8'), sizeBytes: stat.size, mimeType: mimeForPath(filePath) };
    },

    async readAttachmentBytes(params) {
      const filePath = path.resolve(cleanString(params.path ?? params.filePath, 4096));
      const { bytes, stat } = await readLimitedFile(filePath, MAX_BINARY_BYTES);
      return { path: filePath, bytesBase64: bytes.toString('base64'), sizeBytes: stat.size, mimeType: mimeForPath(filePath) };
    },

    async stageAttachmentBytes(params) {
      const raw = cleanString(params.bytesBase64, MAX_BINARY_BYTES * 2);
      const bytes = Buffer.from(raw, 'base64');
      if (!bytes.length || bytes.length > MAX_BINARY_BYTES) throw new Error('Attachment bytes are empty or exceed the limit.');
      const id = crypto.randomUUID();
      const name = safeFileName(params.filename ?? params.name);
      const dir = path.join(stagedRoot(), id);
      await fs.mkdir(dir, { recursive: true });
      const filePath = ensureWithin(dir, path.join(dir, name));
      await fs.writeFile(filePath, bytes, { mode: 0o600 });
      return { id, path: filePath, name, mimeType: cleanString(params.mimeType, 120) || mimeForPath(name), sizeBytes: bytes.length };
    },

    async downloadAttachment(params) {
      const url = new URL(cleanString(params.url, 4096));
      if (url.protocol !== 'https:') throw new Error('Only HTTPS attachments may be downloaded.');
      const response = await net.fetch(url.toString());
      if (!response.ok) throw new Error(`Attachment download failed with HTTP ${response.status}.`);
      const declared = Number(response.headers.get('content-length') ?? 0);
      if (declared > MAX_DOWNLOAD_BYTES) throw new Error('Attachment download exceeds the size limit.');
      const bytes = Buffer.from(await response.arrayBuffer());
      if (bytes.length > MAX_DOWNLOAD_BYTES) throw new Error('Attachment download exceeds the size limit.');
      const name = safeFileName(params.filename ?? path.basename(url.pathname), 'download.bin');
      const target = path.join(app.getPath('downloads'), name);
      await fs.writeFile(target, bytes);
      return { path: target, name, sizeBytes: bytes.length, mimeType: response.headers.get('content-type') || mimeForPath(name) };
    },

    async commitStagedAttachments(params) {
      const items = Array.isArray(params.items) ? params.items : Array.isArray(params.paths) ? params.paths.map((item) => ({ path: item })) : [];
      await fs.mkdir(committedRoot(), { recursive: true });
      const committed = [];
      for (const item of items.slice(0, 100)) {
        const source = ensureWithin(stagedRoot(), cleanString(item.path ?? item.filePath, 4096));
        const name = safeFileName(item.name ?? path.basename(source));
        const destination = ensureWithin(committedRoot(), path.join(committedRoot(), `${crypto.randomUUID()}-${name}`));
        await fs.rename(source, destination);
        const stat = await fs.stat(destination);
        committed.push({ path: destination, name, sizeBytes: stat.size, mimeType: mimeForPath(destination) });
      }
      return committed;
    },

    async discardStagedAttachment(params) {
      const target = ensureWithin(stagedRoot(), cleanString(params.path ?? params.filePath, 4096));
      await fs.rm(target, { recursive: true, force: true });
      return true;
    },

    async forceRecreateComputer() {
      const generation = Number(await getPreference('computerGeneration', 0)) + 1;
      await setPreference('computerGeneration', generation);
      const accepted = await featureExecute({ type: 'computer.status', requestId: requestId('computer-recreate') });
      const result = { dispatched: true, generation, accepted };
      broadcastNativeEvent('update-computer-dispatched', result);
      return result;
    },

    async updateComputer(params) {
      const command = params.command && typeof params.command === 'object'
        ? params.command
        : { type: 'computer.status', requestId: requestId('computer-update') };
      if (!command.requestId) command.requestId = requestId('computer-update');
      const accepted = await featureExecute(command);
      const result = { dispatched: true, accepted };
      broadcastNativeEvent('update-computer-dispatched', result);
      return result;
    },

    async forceReconnectGateway() {
      const info = await host.request('feature.info', {});
      return { connected: true, checkedAtMs: Date.now(), info };
    },

    async getExperimentsSnapshot() {
      const state = await readNativeState();
      return { overrides: state.featureFlags ?? {}, refreshedAtMs: state.featureFlagsRefreshedAtMs ?? null };
    },

    async applyFeatureFlagOverride(params) {
      const key = cleanString(params.key ?? params.flag, 160);
      if (!key) throw new Error('Feature flag key is required.');
      await mutateNativeState((state) => ({ ...state, featureFlags: { ...(state.featureFlags ?? {}), [key]: params.value } }));
      const snapshot = await this.getExperimentsSnapshot();
      broadcastNativeEvent('experiments-changed', snapshot);
      return snapshot;
    },

    async refreshFeatureFlags() {
      await mutateNativeState((state) => ({ ...state, featureFlagsRefreshedAtMs: Date.now() }));
      const snapshot = await this.getExperimentsSnapshot();
      broadcastNativeEvent('experiments-changed', snapshot);
      return snapshot;
    },

    async startRpcTraceWindow() {
      const trace = { traceId: crypto.randomUUID(), startedAtMs: Date.now(), expiresAtMs: Date.now() + 60_000 };
      await setPreference('rpcTraceWindow', trace);
      return trace;
    },

    getAgentDefaultModel() {
      return getPreference('agentDefaultModel', 'auto');
    },

    async setAgentDefaultModel(params) {
      return setPreference('agentDefaultModel', cleanString(params.model ?? 'auto', 160) || 'auto');
    },

    getComputerUseModel() {
      return getPreference('computerUseModel', 'auto');
    },

    async setComputerUseModel(params) {
      return setPreference('computerUseModel', cleanString(params.model ?? 'auto', 160) || 'auto');
    },

    getHostPinnedAgents() {
      return getPreference('hostPinnedAgents', []);
    },

    async setHostPinnedAgents(params) {
      const ids = Array.isArray(params.agentIds ?? params.ids) ? (params.agentIds ?? params.ids).map((value) => cleanString(value, 160)).filter(Boolean) : [];
      return setPreference('hostPinnedAgents', [...new Set(ids)].slice(0, 100));
    },

    getHostSidebarSections() {
      return getPreference('hostSidebarSections', ['agents', 'groups', 'automations', 'skills']);
    },

    async setHostSidebarSections(params) {
      const sections = Array.isArray(params.sections) ? params.sections.map((value) => cleanString(value, 80)).filter(Boolean) : [];
      return setPreference('hostSidebarSections', [...new Set(sections)].slice(0, 30));
    },

    async getAvailableModels() {
      const configured = cleanString(process.env.FABUSHI_AVAILABLE_MODELS, 4096)
        .split(',').map((value) => value.trim()).filter(Boolean);
      const defaults = [await this.getAgentDefaultModel(), await this.getComputerUseModel(), 'auto'];
      return [...new Set([...configured, ...defaults])];
    },

    async transcribeAudio(params) {
      const tools = await host.request('runtime.tools', {}).catch(() => []);
      const tool = (Array.isArray(tools) ? tools : []).find((item) => /transcrib|speech.*text|audio.*text/i.test(String(item?.name ?? item)));
      if (!tool) return { available: false, reason: 'No local transcription runtime tool is installed.' };
      const name = typeof tool === 'string' ? tool : tool.name;
      const result = await host.request('runtime.callTool', { name, arguments: params });
      return { available: true, tool: name, result };
    },

    async getAccountAuthStatus() {
      const auth = await host.request('feature.auth.status', {});
      const state = await readNativeState();
      return { ...auth, displayName: state.accountDisplayName ?? null, avatar: state.accountAvatar ?? null };
    },

    async loginAccount(params) {
      if (params.username != null || params.password != null) {
        return host.request('feature.auth.passwordLogin', { username: String(params.username ?? ''), password: String(params.password ?? '') });
      }
      const providers = await host.request('feature.auth.providers', {});
      const provider = cleanString(params.provider, 80) || (Array.isArray(providers) ? cleanString(providers[0]?.id ?? providers[0], 80) : '');
      if (!provider) throw new Error('No account login provider is available.');
      const attempt = await host.request('feature.auth.oauthStart', { provider });
      await setPreference('activeLoginAttempt', attempt?.attemptId ?? null);
      return attempt;
    },

    async cancelAccountLogin() {
      await setPreference('activeLoginAttempt', null);
      return { cancelled: true };
    },

    async logoutAccount() {
      const auth = await host.request('feature.auth.logout', {});
      broadcastNativeEvent('account-auth-changed', auth);
      return auth;
    },

    async updateAccountName(params) {
      const name = cleanString(params.name ?? params.displayName, 160);
      await mutateNativeState((state) => ({ ...state, accountDisplayName: name || null }));
      return name || null;
    },

    async getAccountAvatar() {
      const state = await readNativeState();
      return state.accountAvatar ?? null;
    },

    async getWeeklyUsage() {
      const state = await readNativeState();
      const entries = Array.isArray(state.usageEvents) ? state.usageEvents : [];
      const cutoff = Date.now() - 7 * 24 * 60 * 60 * 1000;
      const recent = entries.filter((item) => Number(item.timestampMs) >= cutoff);
      const totalTokens = recent.reduce((sum, item) => sum + Number(item.totalTokens ?? 0), 0);
      return { windowDays: 7, totalTokens, events: recent.length, source: 'local-runtime-telemetry' };
    },

    async getUsageSummary() {
      const weekly = await this.getWeeklyUsage();
      const state = await readNativeState();
      return { ...weekly, lifetimeTokens: Number(state.usageLifetimeTokens ?? weekly.totalTokens), updatedAtMs: state.usageUpdatedAtMs ?? null };
    },

    async getReviewPreferences() {
      return {
        autoReviewInstructions: await this.getAutoReviewInstructions(),
        localToolPermission: await this.getLocalToolPermission(),
      };
    },

    getPrivacyModeEnabled() {
      return getPreference('privacyModeEnabled', false);
    },

    async getRuntimeAccess() {
      try {
        const info = await host.request('feature.info', {});
        return { available: true, status: 'ready', info };
      } catch (error) {
        return { available: false, status: 'unavailable', reason: error instanceof Error ? error.message : String(error) };
      }
    },

    refreshRuntimeAccess() {
      return this.getRuntimeAccess();
    },

    async invokeAccountDashboardAction(params) {
      const action = cleanString(params.action, 120);
      if (action === 'logout') return this.logoutAccount();
      if (action === 'relaunch') return { relaunching: true };
      if (action === 'open-url' && params.url) {
        const url = new URL(String(params.url));
        if (url.protocol !== 'https:' || !url.hostname) throw new Error('Only HTTPS dashboard URLs may be opened.');
        await shell.openExternal(url.toString());
        return { opened: true };
      }
      return { handled: false, action, reason: 'No local dashboard adapter is registered for this action.' };
    },

    async cancelRuntimeTrial() {
      return { cancelled: false, available: false, reason: 'No billing/trial provider is configured in the desktop runtime.' };
    },

    reportAgentLoad(params) { return report('agent-load', params); },
    reportAccessBlocked(params) { return report('access-blocked', params); },
    reportAgentsUnreachable(params) { return report('agents-unreachable', params); },
    reportRecoveryAction(params) { return report('recovery-action', params); },
    reportRebuildLifecycle(params) { return report('rebuild-lifecycle', params); },
    reportReconciliation(params) { return report('reconciliation', params); },
    reportComputeVisibility(params) { return report('compute-visibility', params); },
    reportSendLatency(params) { return report('send-latency', params); },
    reportSendAck(params) { return report('send-ack', params); },
    reportReactionAck(params) { return report('reaction-ack', params); },
    reportRenderTtfr(params) { return report('render-ttfr', params); },
    reportRenderStream(params) { return report('render-stream', params); },
    reportRemoteDesktopSession(params) { return report('remote-desktop-session', params); },
    reportRemoteDesktopLiveness(params) { return report('remote-desktop-liveness', params); },
    reportOpenComputer(params) { return report('open-computer', params); },
    reportUpdatePrompt(params) { return report('update-prompt', params); },
    reportSigninGate(params) { return report('signin-gate', params); },
    reportOnboardingStep(params) { return report('onboarding-step', params); },
    reportClientFailure(params) { return report('client-failure', params); },
    reportHeapMetrics(params) { return report('heap-metrics', params); },
    noteConversationForDiagnostics(params) { return report('conversation-diagnostics', params); },

    async openCloudAgent(params) {
      const url = cleanString(params.url, 4096);
      if (url) {
        const parsed = new URL(url);
        if (parsed.protocol !== 'https:') throw new Error('Only HTTPS cloud-agent URLs may be opened.');
        await shell.openExternal(parsed.toString());
        return { opened: true, provider: 'external-url' };
      }
      return { opened: false, available: false, reason: 'No cloud-agent provider URL was supplied.' };
    },

    async getLinkMetadata(params) {
      const parsed = new URL(cleanString(params.url, 4096));
      if (parsed.protocol !== 'https:') throw new Error('Only HTTPS link metadata is supported.');
      const response = await net.fetch(parsed.toString(), { headers: { accept: 'text/html,application/xhtml+xml' } });
      if (!response.ok) throw new Error(`Link metadata request failed with HTTP ${response.status}.`);
      const bytes = Buffer.from(await response.arrayBuffer());
      const html = bytes.subarray(0, 512 * 1024).toString('utf8');
      const title = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1]?.replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim() ?? null;
      const description = html.match(/<meta[^>]+(?:name|property)=["'](?:description|og:description)["'][^>]+content=["']([^"']*)["']/i)?.[1] ?? null;
      const image = html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']*)["']/i)?.[1] ?? null;
      return { url: response.url || parsed.toString(), title, description, image, contentType: response.headers.get('content-type') };
    },

    async listSecrets() {
      const vault = await loadSecretVault();
      return Object.entries(vault).map(([name, item]) => ({ name, updatedAtMs: item.updatedAtMs ?? null })).sort((a, b) => a.name.localeCompare(b.name));
    },

    async revealSecret(params) {
      requireSecretEncryption();
      const name = cleanString(params.name ?? params.key, 200);
      const item = (await loadSecretVault())[name];
      if (!item?.ciphertext) return null;
      return safeStorage.decryptString(Buffer.from(item.ciphertext, 'base64'));
    },

    async upsertSecrets(params) {
      requireSecretEncryption();
      const candidates = [];
      if (Array.isArray(params.secrets)) candidates.push(...params.secrets);
      else if (params.secrets && typeof params.secrets === 'object') candidates.push(...Object.entries(params.secrets).map(([name, value]) => ({ name, value })));
      else if (params.name != null) candidates.push({ name: params.name, value: params.value });
      const vault = await loadSecretVault();
      const now = Date.now();
      for (const candidate of candidates.slice(0, 100)) {
        const name = cleanString(candidate.name ?? candidate.key, 200);
        if (!name || !/^[a-zA-Z0-9._:/-]+$/.test(name)) throw new Error('Invalid secret name.');
        const value = String(candidate.value ?? '');
        const ciphertext = safeStorage.encryptString(value).toString('base64');
        vault[name] = { ciphertext, updatedAtMs: now };
      }
      await saveSecretVault(vault);
      return this.listSecrets();
    },

    async removeSecrets(params) {
      const names = Array.isArray(params.names) ? params.names : [params.name ?? params.key].filter(Boolean);
      const vault = await loadSecretVault();
      for (const raw of names) delete vault[cleanString(raw, 200)];
      await saveSecretVault(vault);
      return this.listSecrets();
    },

    async migrateClientPersistence(params) {
      const fromPrefix = cleanString(params.fromPrefix ?? params.from, 160);
      const toPrefix = cleanString(params.toPrefix ?? params.to, 160);
      if (!fromPrefix || !toPrefix) throw new Error('Persistence migration requires fromPrefix and toPrefix.');
      const state = await readNativeState();
      const store = { ...(state.clientPersistence ?? {}) };
      let migrated = 0;
      for (const [key, value] of Object.entries({ ...store })) {
        if (!key.startsWith(fromPrefix)) continue;
        const nextKey = `${toPrefix}${key.slice(fromPrefix.length)}`;
        if (store[nextKey] === undefined || params.overwrite === true) store[nextKey] = value;
        if (params.copy !== true) delete store[key];
        migrated += 1;
      }
      await mutateNativeState((current) => ({ ...current, clientPersistence: store }));
      return { migrated, fromPrefix, toPrefix, copied: params.copy === true };
    },

    async getMcpState() {
      const [tools, plugins] = await Promise.all([
        host.request('runtime.tools', {}).catch(() => []),
        installedPluginPointers(),
      ]);
      return { available: true, tools: Array.isArray(tools) ? tools : [], plugins };
    },

    getEffectivePlugins() {
      return installedPluginPointers();
    },

    async getMcpCatalog() {
      const catalog = await host.request('marketplace.browse', { query: 'mcp', platform: process.platform });
      return Array.isArray(catalog) ? catalog : catalog?.plugins ?? catalog;
    },

    async getMcpTeamPopularity() {
      return { available: false, items: [], reason: 'No team marketplace analytics provider is configured.' };
    },

    async getMcpPluginLogo(params) {
      const pluginId = cleanString(params.pluginId ?? params.id, 200);
      const catalog = await host.request('marketplace.browse', { query: pluginId, platform: process.platform }).catch(() => []);
      const entries = Array.isArray(catalog) ? catalog : catalog?.plugins ?? [];
      const match = entries.find((item) => cleanString(item?.id ?? item?.pluginId, 200) === pluginId) ?? entries[0];
      return match?.logo ?? match?.icon ?? null;
    },

    async installEntry(params) {
      const pluginId = cleanString(params.pluginId ?? params.id ?? params.entry?.id, 200);
      const version = cleanString(params.version ?? params.entry?.version, 100);
      if (!pluginId || !version) throw new Error('Plugin ID and version are required.');
      const release = params.release ?? await host.request('marketplace.release', { pluginId, version });
      return host.request('plugin.install', { release, platform: process.platform });
    },

    updatePluginInstall(params) {
      return this.installEntry(params);
    },

    async removeMcpServer(params) {
      const server = cleanString(params.server ?? params.name, 200);
      if (!server) throw new Error('MCP server name is required.');
      const accepted = await featureExecute({ type: 'mcp.oauthLogout', requestId: requestId('mcp-remove'), server });
      return { removed: true, server, accepted };
    },

    async uninstallPlugin(params) {
      const pluginId = cleanString(params.pluginId ?? params.id, 200);
      if (!pluginId) throw new Error('Plugin ID is required.');
      return host.request('plugin.uninstall', { pluginId });
    },

    async authenticateMcpServer(params) {
      const server = cleanString(params.server ?? params.name, 200);
      const accepted = await featureExecute({ type: 'mcp.oauthLogin', requestId: requestId('mcp-login'), server });
      return { server, accepted };
    },

    async renameMcpAccount(params) {
      const connectorId = cleanString(params.connectorId ?? params.server, 200);
      const accountId = cleanString(params.accountId, 200);
      const label = cleanString(params.label ?? params.name, 200);
      const accepted = await featureExecute({ type: 'connector.renameAccount', requestId: requestId('mcp-rename'), connectorId, accountId, label });
      return { connectorId, accountId, label, accepted };
    },

    async removeMcpAccount(params) {
      const connectorId = cleanString(params.connectorId ?? params.server, 200);
      const accountId = cleanString(params.accountId, 200);
      const accepted = await featureExecute({ type: 'connector.removeAccount', requestId: requestId('mcp-account-remove'), connectorId, accountId });
      return { connectorId, accountId, accepted };
    },

    async setMcpCustomInstructions(params) {
      const server = cleanString(params.server ?? params.name, 200);
      const instructions = cleanString(params.instructions, 20000);
      const state = await readNativeState();
      const all = { ...(state.mcpCustomInstructions ?? {}), [server]: instructions };
      await mutateNativeState((current) => ({ ...current, mcpCustomInstructions: all }));
      return { server, instructions };
    },

    async listMcpServerTools(params) {
      const server = cleanString(params.server ?? params.name, 200);
      const tools = await host.request('runtime.tools', {}).catch(() => []);
      return (Array.isArray(tools) ? tools : []).filter((tool) => !server || cleanString(tool?.server ?? tool?.pluginId, 200) === server);
    },

    async toggleMcpToolDisabled(params) {
      const server = cleanString(params.server ?? params.pluginId, 200);
      const tool = cleanString(params.tool ?? params.toolId, 200);
      const disabled = params.disabled === true;
      const key = `${server}:${tool}`;
      await mutateNativeState((state) => ({
        ...state,
        mcpDisabledTools: { ...(state.mcpDisabledTools ?? {}), [key]: disabled },
      }));
      return { server, tool, disabled };
    },

    devRestart() {
      setImmediate(() => { app.relaunch(); app.exit(0); });
      return true;
    },

    async getProductionComputeAttachmentStatus() {
      const enabled = await getPreference('productionComputeAttachmentEnabled', false);
      return { enabled: enabled === true, available: true, provider: 'mahayana' };
    },

    async setProductionComputeAttachmentEnabled(params) {
      const enabled = params.enabled === true;
      await setPreference('productionComputeAttachmentEnabled', enabled);
      return { enabled, available: true, provider: 'mahayana' };
    },
  };

  for (const [name, handler] of Object.entries(handlers)) {
    if (typeof handler === 'function') handlers[name] = handler.bind(handlers);
  }
  return handlers;
}

module.exports = { createNativeCapabilityHandlers };
