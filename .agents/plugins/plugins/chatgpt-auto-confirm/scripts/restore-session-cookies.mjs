const port = Number(process.env.CHATGPT_CDP_PORT || 9324);
const encoded = process.env.CHATGPT_SESSION_COOKIES_B64;
if (!encoded) throw new Error('CHATGPT_SESSION_COOKIES_B64 is required');
const payload = JSON.parse(Buffer.from(encoded, 'base64').toString('utf8'));
if (!Array.isArray(payload.cookies) || payload.cookies.length === 0) {
  throw new Error('The ChatGPT cookie secret is empty');
}

const deadline = Date.now() + 120_000;
let target;
while (Date.now() < deadline) {
  try {
    const targets = await fetch(`http://127.0.0.1:${port}/json/list`).then(response => response.json());
    target = targets.find(item =>
      item.type === 'page' &&
      item.url === 'app://-/index.html' &&
      item.webSocketDebuggerUrl
    );
    if (target) break;
  } catch {}
  await new Promise(resolve => setTimeout(resolve, 1_000));
}
if (!target) throw new Error('ChatGPT did not expose a page target within 120 seconds');

const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve, { once: true });
  socket.addEventListener('error', reject, { once: true });
});
let sequence = 0;
const call = (method, params = {}) => new Promise((resolve, reject) => {
  const id = ++sequence;
  const onMessage = event => {
    const message = JSON.parse(String(event.data));
    if (message.id !== id) return;
    socket.removeEventListener('message', onMessage);
    if (message.error) reject(new Error(`${method} failed`));
    else resolve(message.result || {});
  };
  socket.addEventListener('message', onMessage);
  socket.send(JSON.stringify({ id, method, params }));
});

await call('Network.setCookies', { cookies: payload.cookies });
await call('Page.reload', { ignoreCache: true });
await new Promise(resolve => setTimeout(resolve, 5_000));
const authentication = await call('Runtime.evaluate', {
  expression: `(
    async () => {
      try {
        const response = await fetch('https://chatgpt.com/api/auth/session', {
          credentials: 'include',
          cache: 'no-store'
        });
        const data = await response.json().catch(() => ({}));
        return {
          status: response.status,
          authenticated: Boolean(data && (data.user || data.accessToken))
        };
      } catch {
        return { status: 0, authenticated: false };
      }
    }
  )()`,
  awaitPromise: true,
  returnByValue: true,
});
socket.close();
const authValue = authentication.result?.value;
if (!authValue?.authenticated) {
  throw new Error(`ChatGPT session verification failed (HTTP ${authValue?.status || 0})`);
}
process.stdout.write(`Restored ${payload.cookies.length} ChatGPT session cookies\n`);
