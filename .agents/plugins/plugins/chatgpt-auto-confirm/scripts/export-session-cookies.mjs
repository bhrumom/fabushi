const port = Number(process.env.CHATGPT_CDP_PORT || 9324);
const targets = await fetch(`http://127.0.0.1:${port}/json/list`).then(response => response.json());
const target = targets.find(item =>
  item.type === 'page' &&
  item.url === 'app://-/index.html' &&
  item.webSocketDebuggerUrl
);
if (!target) throw new Error('No authenticated ChatGPT page target is available');

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

const { cookies = [] } = await call('Network.getAllCookies');
socket.close();
const allowedSuffixes = ['chatgpt.com', 'openai.com'];
const selected = cookies
  .filter(cookie => allowedSuffixes.some(suffix =>
    cookie.domain === suffix || cookie.domain.endsWith(`.${suffix}`)))
  .map(cookie => Object.fromEntries(Object.entries({
    name: cookie.name,
    value: cookie.value,
    domain: cookie.domain,
    path: cookie.path,
    expires: cookie.expires,
    httpOnly: cookie.httpOnly,
    secure: cookie.secure,
    sameSite: cookie.sameSite,
    priority: cookie.priority,
    sameParty: cookie.sameParty,
    sourceScheme: cookie.sourceScheme,
    sourcePort: cookie.sourcePort,
    partitionKey: cookie.partitionKey,
  }).filter(([, value]) => value !== undefined)));

if (!selected.length) throw new Error('No ChatGPT session cookies were found');
const encoded = Buffer.from(JSON.stringify({ version: 1, cookies: selected })).toString('base64');
if (Buffer.byteLength(encoded) > 47_000) {
  throw new Error(`Cookie secret exceeds the GitHub secret budget (${Buffer.byteLength(encoded)} bytes)`);
}
process.stdout.write(encoded);
