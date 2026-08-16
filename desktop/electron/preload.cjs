const { contextBridge, ipcRenderer } = require('electron');
const { createRendererEdge } = require('./edge-ipc.cjs');
const { MAHAYANA_EDGE } = require('./mahayana-edge.cjs');
const { NATIVE_EDGE } = require('./native-edge.cjs');

const edgeClient = createRendererEdge(ipcRenderer, MAHAYANA_EDGE);
const nativeEdgeClient = createRendererEdge(ipcRenderer, NATIVE_EDGE);
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

contextBridge.exposeInMainWorld('fabushiNative', Object.freeze({
  invoke(method, params = {}) {
    const spec = NATIVE_EDGE.methods[method];
    if (!spec) return Promise.reject(new Error(`Native method is not allowed: ${method}`));
    return spec.args === 'none' ? nativeEdgeClient[method]() : nativeEdgeClient[method](params);
  },
  subscribe(listeners) {
    return nativeEdgeClient.subscribe(listeners);
  },
}));

contextBridge.exposeInMainWorld('fabushi', Object.freeze({
  // Compatibility facade for the current HostClient while the UI migrates
  // feature-by-feature to the explicit Mahayana and native desktop edges.
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
