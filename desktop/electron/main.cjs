const { app, autoUpdater, BrowserWindow, dialog, ipcMain, net, nativeTheme, Notification, protocol, safeStorage, shell, session } = require('electron');
const fs = require('node:fs/promises');
const fsSync = require('node:fs');
const path = require('node:path');
const { pathToFileURL, URL } = require('node:url');
const { MahayanaHostProcess } = require('./host-process.cjs');
const { serveMainEdge } = require('./edge-ipc.cjs');
const { MAHAYANA_EDGE } = require('./mahayana-edge.cjs');
const { NATIVE_EDGE } = require('./native-edge.cjs');
const { createNativeCapabilityHandlers } = require('./native-capability-handlers.cjs');

const appDataOverride = process.env.FABUSHI_APP_DATA?.trim();
if (appDataOverride) app.setPath('userData', path.resolve(appDataOverride));

protocol.registerSchemesAsPrivileged([
  {
    scheme: 'app',
    privileges: { standard: true, secure: true, supportFetchAPI: true },
  },
]);

const host = new MahayanaHostProcess();
const allowedHostMethods = new Set(Object.keys(MAHAYANA_EDGE.methods));
let mahayanaEdgeServer = null;
let nativeEdgeServer = null;
let hostEventPumpStopped = false;
let hostEventPump = null;

function isTrustedRendererUrl(value) {
  try {
    const parsed = new URL(value);
    if (parsed.protocol === 'app:' && parsed.hostname === 'bundle') return true;
    if (process.env.VITE_DEV_SERVER_URL) {
      const dev = new URL(process.env.VITE_DEV_SERVER_URL);
      return parsed.origin === dev.origin;
    }
  } catch {}
  return false;
}

function assertTrustedSender(event) {
  const url = event.senderFrame?.url || event.sender.getURL();
  if (isTrustedRendererUrl(url)) return;
  throw new Error(`Rejected IPC sender: ${url}`);
}

function isTrustedSender(event) {
  try {
    assertTrustedSender(event);
    return true;
  } catch {
    return false;
  }
}

function normalizeParams(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function safeHttpsUrl(value) {
  const parsed = new URL(String(value));
  if (parsed.protocol !== 'https:' || !parsed.hostname) throw new Error('Only HTTPS URLs may be opened externally.');
  return parsed.toString();
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function nativeStatePath() {
  return path.join(app.getPath('userData'), 'fabushi-native-state.json');
}

let nativeStateWrite = Promise.resolve();

function applyStartupNativePreferences() {
  try {
    const raw = fsSync.readFileSync(nativeStatePath(), 'utf8');
    const state = JSON.parse(raw);
    if (state?.preferences?.hardwareAccelerationEnabled === false) app.disableHardwareAcceleration();
  } catch (error) {
    if (error?.code !== 'ENOENT') console.warn('[native-edge] unable to apply startup preferences', error);
  }
}

async function readNativeState() {
  try {
    const raw = await fs.readFile(nativeStatePath(), 'utf8');
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch (error) {
    if (error?.code === 'ENOENT') return {};
    throw error;
  }
}

async function mutateNativeState(mutator) {
  nativeStateWrite = nativeStateWrite.then(async () => {
    const state = await readNativeState();
    const next = mutator({ ...state }) ?? state;
    const file = nativeStatePath();
    await fs.mkdir(path.dirname(file), { recursive: true });
    const temp = `${file}.tmp`;
    await fs.writeFile(temp, `${JSON.stringify(next, null, 2)}\n`, { mode: 0o600 });
    await fs.rename(temp, file);
  });
  return nativeStateWrite;
}

function persistenceKey(value) {
  const key = String(value ?? '').trim();
  if (!key || key.length > 160 || !/^[a-zA-Z0-9._:/-]+$/.test(key)) {
    throw new Error('Invalid persistence key.');
  }
  return key;
}

const DISK_AUDIT_MAX_NODES = 50_000;
const DISK_AUDIT_MAX_DEPTH = 12;
const RECLAIMABLE_TOP_LEVEL_NAMES = new Set([
  'cache',
  'code cache',
  'gpucache',
  'logs',
  'temp',
  'tmp',
]);

async function measureDiskEntry(target, state, depth = 0) {
  if (state.scannedNodes >= DISK_AUDIT_MAX_NODES || depth > DISK_AUDIT_MAX_DEPTH) {
    state.truncated = true;
    return 0;
  }
  state.scannedNodes += 1;
  let stat;
  try {
    stat = await fs.lstat(target);
  } catch {
    return 0;
  }
  if (stat.isSymbolicLink()) return 0;
  if (stat.isFile()) return Math.max(0, Number(stat.size) || 0);
  if (!stat.isDirectory()) return 0;
  let children;
  try {
    children = await fs.readdir(target, { withFileTypes: true });
  } catch {
    return 0;
  }
  let bytes = 0;
  for (const child of children) {
    if (state.scannedNodes >= DISK_AUDIT_MAX_NODES) {
      state.truncated = true;
      break;
    }
    bytes += await measureDiskEntry(path.join(target, child.name), state, depth + 1);
  }
  return bytes;
}

async function auditUserDataStorage() {
  const root = app.getPath('userData');
  const state = { scannedNodes: 0, truncated: false };
  let topLevel = [];
  try {
    topLevel = await fs.readdir(root, { withFileTypes: true });
  } catch (error) {
    throw new Error(`Unable to inspect desktop storage: ${error instanceof Error ? error.message : String(error)}`);
  }
  const entries = [];
  for (const item of topLevel) {
    const bytes = await measureDiskEntry(path.join(root, item.name), state, 0);
    entries.push({
      name: item.name,
      bytes,
      reclaimable: RECLAIMABLE_TOP_LEVEL_NAMES.has(item.name.trim().toLowerCase()),
    });
  }
  entries.sort((left, right) => right.bytes - left.bytes || left.name.localeCompare(right.name));
  const totalBytes = entries.reduce((total, entry) => total + entry.bytes, 0);
  const reclaimableBytes = entries.reduce(
    (total, entry) => total + (entry.reclaimable ? entry.bytes : 0),
    0,
  );
  return {
    root,
    totalBytes,
    reclaimableBytes,
    scannedNodes: state.scannedNodes,
    truncated: state.truncated,
    scannedAtMs: Date.now(),
    entries: entries.slice(0, 50),
  };
}

function windowForEvent(event) {
  const win = BrowserWindow.fromWebContents(event.sender);
  if (!win || win.isDestroyed()) throw new Error('Renderer window is unavailable.');
  return win;
}

function describeWindow(win) {
  const bounds = win.getBounds();
  return {
    focused: win.isFocused(),
    minimized: win.isMinimized(),
    maximized: win.isMaximized(),
    fullScreen: win.isFullScreen(),
    bounds,
  };
}

function describeTheme() {
  return {
    preference: nativeTheme.themeSource,
    dark: nativeTheme.shouldUseDarkColors,
    highContrast: nativeTheme.shouldUseHighContrastColors,
  };
}

function broadcastNativeEvent(eventName, payload) {
  if (!nativeEdgeServer) return;
  for (const win of BrowserWindow.getAllWindows()) {
    if (win.isDestroyed() || win.webContents.isDestroyed()) continue;
    nativeEdgeServer.emit(win.webContents, eventName, payload);
  }
}

function installNativeEdge() {
  const handlers = {
    async openExternal(params) {
      await shell.openExternal(safeHttpsUrl(params.url));
      return true;
    },
    getDesktopEnvironment() {
      return {
        platform: process.platform,
        arch: process.arch,
        appVersion: app.getVersion(),
        electronVersion: process.versions.electron,
        packaged: app.isPackaged,
      };
    },
    getWindowState(_params, event) {
      return describeWindow(windowForEvent(event));
    },
    minimizeWindow(_params, event) {
      windowForEvent(event).minimize();
      return true;
    },
    toggleMaximizeWindow(_params, event) {
      const win = windowForEvent(event);
      if (win.isMaximized()) win.unmaximize();
      else win.maximize();
      return describeWindow(win);
    },
    closeWindow(_params, event) {
      windowForEvent(event).close();
      return true;
    },
    resizeWindowWidth(params, event) {
      const win = windowForEvent(event);
      const width = Math.max(880, Math.min(2400, Math.round(Number(params.width) || 1180)));
      const [currentWidth, height] = win.getSize();
      if (currentWidth !== width) win.setSize(width, height, true);
      return describeWindow(win);
    },
    getThemeState() {
      return describeTheme();
    },
    setThemePreference(params) {
      const preference = String(params.preference ?? 'system');
      if (!['system', 'light', 'dark'].includes(preference)) throw new Error('Unsupported theme preference.');
      nativeTheme.themeSource = preference;
      const state = describeTheme();
      broadcastNativeEvent('theme-changed', state);
      return state;
    },
    relaunchDesktop() {
      setImmediate(() => {
        app.relaunch();
        app.exit(0);
      });
      return true;
    },
    async getOnboardingSeen() {
      const state = await readNativeState();
      return state.onboardingSeen === true;
    },
    async setOnboardingSeen(params) {
      const value = params.seen !== false;
      await mutateNativeState((state) => ({ ...state, onboardingSeen: value }));
      return value;
    },
    async getTimeZone() {
      const state = await readNativeState();
      return typeof state.timeZoneOverride === 'string' && state.timeZoneOverride
        ? state.timeZoneOverride
        : Intl.DateTimeFormat().resolvedOptions().timeZone;
    },
    async setTimeZoneOverride(params) {
      const value = params.timeZone == null ? '' : String(params.timeZone).trim();
      if (value) new Intl.DateTimeFormat('en-US', { timeZone: value }).format(new Date());
      await mutateNativeState((state) => {
        if (value) state.timeZoneOverride = value;
        else delete state.timeZoneOverride;
        return state;
      });
      return value || null;
    },
    async getSidebarCollapsed() {
      const state = await readNativeState();
      return state.sidebarCollapsed === true;
    },
    async setSidebarCollapsed(params) {
      const value = params.collapsed === true;
      await mutateNativeState((state) => ({ ...state, sidebarCollapsed: value }));
      return value;
    },
    async readClientPersistence(params) {
      const key = persistenceKey(params.key);
      const state = await readNativeState();
      return state.clientPersistence?.[key] ?? null;
    },
    async writeClientPersistence(params) {
      const key = persistenceKey(params.key);
      const value = params.value;
      await mutateNativeState((state) => ({
        ...state,
        clientPersistence: { ...(state.clientPersistence ?? {}), [key]: value },
      }));
      return true;
    },
    async removeClientPersistence(params) {
      const key = persistenceKey(params.key);
      await mutateNativeState((state) => {
        const next = { ...(state.clientPersistence ?? {}) };
        delete next[key];
        return { ...state, clientPersistence: next };
      });
      return true;
    },
    async listClientPersistenceKeys(params) {
      const prefix = params.prefix == null ? '' : String(params.prefix);
      const state = await readNativeState();
      return Object.keys(state.clientPersistence ?? {}).filter((key) => key.startsWith(prefix)).sort();
    },
    requestDiskSaverAudit() {
      return auditUserDataStorage();
    },
  };

  Object.assign(handlers, createNativeCapabilityHandlers({
    app,
    autoUpdater,
    dialog,
    net,
    nativeTheme,
    safeStorage,
    shell,
    host,
    readNativeState,
    mutateNativeState,
    windowForEvent,
    broadcastNativeEvent,
  }));

  nativeEdgeServer = serveMainEdge(ipcMain, NATIVE_EDGE, handlers, {
    isTrustedSender,
    onHandlerError(method, error) {
      console.error(`[native-edge] ${method} failed`, error);
    },
  });
}

function installMahayanaEdge() {
  const handlers = Object.fromEntries(
    Object.keys(MAHAYANA_EDGE.methods).map((method) => [
      method,
      async (params) => host.request(method, normalizeParams(params)),
    ]),
  );

  mahayanaEdgeServer = serveMainEdge(ipcMain, MAHAYANA_EDGE, handlers, {
    isTrustedSender,
    onHandlerError(method, error) {
      console.error(`[mahayana-edge] ${method} failed`, error);
    },
  });
}

function noteRuntimeUsage(event) {
  if (!event || event.type !== 'usage.updated') return;
  const totalTokens = Math.max(0, Number(event.totalTokens ?? 0));
  const item = { timestampMs: Date.now(), totalTokens };
  void mutateNativeState((state) => {
    const previous = Array.isArray(state.usageEvents) ? state.usageEvents : [];
    const cutoff = Date.now() - 35 * 24 * 60 * 60 * 1000;
    const usageEvents = [...previous.filter((entry) => Number(entry.timestampMs) >= cutoff), item].slice(-5000);
    return {
      ...state,
      usageEvents,
      usageLifetimeTokens: Number(state.usageLifetimeTokens ?? 0) + totalTokens,
      usageUpdatedAtMs: item.timestampMs,
    };
  }).catch((error) => console.error('[native-edge] failed to persist usage telemetry', error));
}

function broadcastMahayanaEvent(event) {
  noteRuntimeUsage(event);
  if (!mahayanaEdgeServer) return;
  for (const win of BrowserWindow.getAllWindows()) {
    if (win.isDestroyed() || win.webContents.isDestroyed()) continue;
    mahayanaEdgeServer.emit(win.webContents, 'runtime-event', event);
  }
}

function startHostEventPump() {
  if (hostEventPump) return;
  hostEventPumpStopped = false;
  hostEventPump = (async () => {
    while (!hostEventPumpStopped) {
      try {
        const event = await host.request('feature.receive', {});
        if (event) broadcastMahayanaEvent(event);
        else await sleep(10);
      } catch (error) {
        if (hostEventPumpStopped) break;
        console.error('[mahayana-edge] runtime event pump failed', error);
        await sleep(100);
      }
    }
  })().finally(() => {
    hostEventPump = null;
  });
}

function installIpcHandlers() {
  installMahayanaEdge();
  installNativeEdge();

  // Temporary compatibility channel for older renderer builds. Current preload
  // routes window.fabushi.invoke through MAHAYANA_EDGE instead.
  ipcMain.handle('fabushi:host', async (event, request) => {
    assertTrustedSender(event);
    const method = String(request?.method || '');
    if (!allowedHostMethods.has(method)) throw new Error(`Host method is not allowed: ${method}`);
    return host.request(method, normalizeParams(request?.params));
  });

  ipcMain.handle('fabushi:pick-file', async (event) => {
    assertTrustedSender(event);
    const result = await dialog.showOpenDialog({ properties: ['openFile'] });
    return result.canceled ? null : result.filePaths[0] || null;
  });

  ipcMain.handle('fabushi:notify', async (event, payload) => {
    assertTrustedSender(event);
    const title = String(payload?.title || '').trim();
    const body = String(payload?.body || '');
    if (!title || title.length > 160 || body.length > 4000) throw new Error('Invalid notification content.');
    new Notification({ title, body }).show();
    return true;
  });

  ipcMain.handle('fabushi:open-external', async (event, payload) => {
    assertTrustedSender(event);
    await shell.openExternal(safeHttpsUrl(payload?.url));
    return true;
  });

  ipcMain.handle('fabushi:window-focused', async (event) => {
    assertTrustedSender(event);
    return BrowserWindow.fromWebContents(event.sender)?.isFocused() ?? false;
  });

  ipcMain.handle('fabushi:open-system-settings', async (event, payload) => {
    assertTrustedSender(event);
    const pane = String(payload?.pane || '');
    if (!['screen-recording', 'accessibility'].includes(pane)) {
      throw new Error(`Unsupported system settings pane: ${pane}`);
    }
    if (process.platform === 'darwin') {
      const url = pane === 'screen-recording'
        ? 'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture'
        : 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility';
      await shell.openExternal(url);
      return true;
    }
    if (process.platform === 'win32') {
      await shell.openExternal('ms-settings:privacy');
      return true;
    }
    throw new Error('System privacy settings must be opened manually on this platform.');
  });
}

function createWindow() {
  const win = new BrowserWindow({
    title: '全球法布施',
    width: 1180,
    height: 840,
    minWidth: 880,
    minHeight: 640,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true,
      allowRunningInsecureContent: false,
    },
  });

  win.webContents.setWindowOpenHandler(({ url }) => {
    try { void shell.openExternal(safeHttpsUrl(url)); } catch {}
    return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (event, url) => {
    if (!isTrustedRendererUrl(url)) event.preventDefault();
  });
  const publishWindowState = () => broadcastNativeEvent('window-state', describeWindow(win));
  for (const eventName of ['focus', 'blur', 'minimize', 'restore', 'maximize', 'unmaximize', 'enter-full-screen', 'leave-full-screen']) {
    win.on(eventName, publishWindowState);
  }
  win.once('ready-to-show', () => { win.show(); publishWindowState(); });

  if (process.env.VITE_DEV_SERVER_URL) {
    void win.loadURL(process.env.VITE_DEV_SERVER_URL);
  } else {
    void win.loadURL('app://bundle/index.html');
  }
}

function installAutoUpdaterEvents() {
  if (!autoUpdater?.on) return;
  autoUpdater.on('checking-for-update', () => {
    void mutateNativeState((state) => ({ ...state, updateStatus: { type: 'checking', version: app.getVersion() } }));
    broadcastNativeEvent('update-status', { type: 'checking', version: app.getVersion() });
  });
  autoUpdater.on('update-not-available', (info) => {
    const status = { type: 'upToDate', version: info?.version ?? app.getVersion() };
    void mutateNativeState((state) => ({ ...state, updateStatus: status }));
    broadcastNativeEvent('update-status', status);
  });
  autoUpdater.on('update-available', (info) => {
    const status = { type: 'downloading', version: info?.version ?? null };
    void mutateNativeState((state) => ({ ...state, updateStatus: status }));
    broadcastNativeEvent('update-status', status);
  });
  autoUpdater.on('update-downloaded', (_event, _notes, version) => {
    const status = { type: 'ready', version: version ?? null };
    void mutateNativeState((state) => ({ ...state, updateStatus: status }));
    broadcastNativeEvent('update-status', status);
  });
  autoUpdater.on('error', (error) => {
    const status = { type: 'error', message: error instanceof Error ? error.message : String(error) };
    void mutateNativeState((state) => ({ ...state, updateStatus: status }));
    broadcastNativeEvent('update-status', status);
  });
}

function installAppProtocol() {
  const distRoot = path.resolve(__dirname, '..', 'dist');
  protocol.handle('app', (request) => {
    const requested = new URL(request.url);
    if (requested.hostname !== 'bundle') return new Response('Not found', { status: 404 });
    const pathname = decodeURIComponent(requested.pathname === '/' ? '/index.html' : requested.pathname);
    const resolved = path.resolve(distRoot, `.${pathname}`);
    const withinRoot = resolved === distRoot || resolved.startsWith(`${distRoot}${path.sep}`);
    if (!withinRoot) return new Response('Forbidden', { status: 403 });
    return net.fetch(pathToFileURL(resolved).toString());
  });
}

applyStartupNativePreferences();

app.whenReady().then(() => {
  installAppProtocol();
  installAutoUpdaterEvents();
  session.defaultSession.setPermissionRequestHandler((_webContents, _permission, callback) => callback(false));
  installIpcHandlers();
  host.start();
  createWindow();
  startHostEventPump();
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});

app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
app.on('before-quit', () => {
  hostEventPumpStopped = true;
  mahayanaEdgeServer?.dispose();
  mahayanaEdgeServer = null;
  nativeEdgeServer?.dispose();
  nativeEdgeServer = null;
  host.close();
});
