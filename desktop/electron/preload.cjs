const { contextBridge, ipcRenderer } = require('electron');
const { createElectronRendererEdgeClient } = require('./grok-rpc.cjs');
const { MAHAYANA_EDGE } = require('./mahayana-edge.cjs');

const edgeClient = createElectronRendererEdgeClient(ipcRenderer, MAHAYANA_EDGE);
const allowedMethods = new Set(Object.keys(MAHAYANA_EDGE.methods));

const mahayana = Object.freeze({
  invoke(method, params = {}) {
    if (!allowedMethods.has(method)) {
      return Promise.reject(new Error(`Host method is not allowed: ${method}`));
    }
    const spec = MAHAYANA_EDGE.methods[method];
    return spec.args === 'none' ? edgeClient[method]() : edgeClient[method](params);
  },
  subscribe(listener) {
    if (typeof listener !== 'function') return () => {};
    return edgeClient.subscribe({ 'runtime-event': listener });
  },
});

contextBridge.exposeInMainWorld('mahayana', mahayana);

contextBridge.exposeInMainWorld('fabushi', Object.freeze({
  // Compatibility facade. Existing HostClient code keeps working while all
  // Mahayana calls now travel through Grok's edge/envelope IPC semantics.
  invoke(method, params = {}) {
    return mahayana.invoke(method, params);
  },
  subscribe(listener) {
    return mahayana.subscribe(listener);
  },
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
