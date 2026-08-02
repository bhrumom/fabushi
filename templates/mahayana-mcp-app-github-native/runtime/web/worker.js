let ready;
self.addEventListener('message', async (event) => {
  const message = event.data;
  if (message?.type === 'load-wasm') {
    const go = new Go();
    const instance = await WebAssembly.instantiateStreaming(fetch(message.url), go.importObject);
    ready = go.run(instance.instance);
    return;
  }
  if (message?.jsonrpc === '2.0') {
    if (!globalThis.mahayanaMcpCall) {
      postMessage({ jsonrpc: '2.0', id: message.id, error: { code: -32000, message: 'runtime_not_ready' } });
      return;
    }
    postMessage(JSON.parse(globalThis.mahayanaMcpCall(JSON.stringify(message))));
  }
});
