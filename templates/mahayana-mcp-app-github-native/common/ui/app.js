const pending = new Map();
let nextId = 1;

function request(method, params) {
  const id = nextId++;
  window.parent.postMessage({ jsonrpc: '2.0', id, method, params }, '*');
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}

window.addEventListener('message', (event) => {
  if (event.source !== window.parent || event.origin !== 'null') return;
  const message = event.data;
  if (!message || message.jsonrpc !== '2.0' || !pending.has(message.id)) return;
  const waiter = pending.get(message.id);
  pending.delete(message.id);
  if (message.error) waiter.reject(new Error(message.error.message));
  else waiter.resolve(message.result);
});

await request('ui/initialize', {
  appInfo: { name: 'io.mahayana.example.github-native-app', version: '0.1.0' },
  appCapabilities: {},
});
window.parent.postMessage({ jsonrpc: '2.0', method: 'ui/notifications/initialized' }, '*');

document.querySelector('#send-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const text = document.querySelector('#message').value;
  const result = await request('tools/call', { name: 'send', arguments: { text } });
  document.querySelector('#result').textContent = JSON.stringify(result.structuredContent, null, 2);
});

window.addEventListener('pagehide', () => {
  window.parent.postMessage({ jsonrpc: '2.0', method: 'ui/resource-teardown' }, '*');
});
