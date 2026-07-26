const port = Number(process.env.CHATGPT_CDP_PORT || 9324);
const encoded = process.env.CHATGPT_SESSION_COOKIES_B64;
if (!encoded) throw new Error('CHATGPT_SESSION_COOKIES_B64 is required');
const payload = JSON.parse(Buffer.from(encoded, 'base64').toString('utf8'));
if (!Array.isArray(payload.cookies) || payload.cookies.length === 0) {
  throw new Error('The ChatGPT cookie secret is empty');
}

const listTargets = async () =>
  fetch(`http://127.0.0.1:${port}/json/list`).then(response => response.json());

const findTarget = async (predicate, timeoutMs, label) => {
  const deadline = Date.now() + timeoutMs;
  let lastTargets = [];
  while (Date.now() < deadline) {
    try {
      lastTargets = await listTargets();
      const target = lastTargets.find(item =>
        item.webSocketDebuggerUrl && predicate(item)
      );
      if (target) return target;
    } catch {}
    await new Promise(resolve => setTimeout(resolve, 1_000));
  }
  const safeTargets = lastTargets.map(item => ({
    type: item.type,
    url: String(item.url || '').slice(0, 160),
  }));
  throw new Error(`${label} was not exposed; targets=${JSON.stringify(safeTargets)}`);
};

const connect = async target => {
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  let sequence = 0;
  const call = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => {
      socket.removeEventListener('message', onMessage);
      reject(new Error(`${method} timed out`));
    }, 30_000);
    const onMessage = event => {
      const message = JSON.parse(String(event.data));
      if (message.id !== id) return;
      clearTimeout(timer);
      socket.removeEventListener('message', onMessage);
      if (message.error) reject(new Error(`${method} failed`));
      else resolve(message.result || {});
    };
    socket.addEventListener('message', onMessage);
    socket.send(JSON.stringify({ id, method, params }));
  });
  return { socket, call };
};

const shellTarget = await findTarget(
  item => item.type === 'page' && item.url === 'app://-/index.html',
  120_000,
  'ChatGPT app shell'
);
const shell = await connect(shellTarget);
await shell.call('Network.setCookies', { cookies: payload.cookies });
shell.socket.close();

const contentTarget = await findTarget(
  item =>
    item.type === 'page' &&
    /^https:\/\/(chatgpt\.com|chat\.openai\.com)(\/|$)/i.test(item.url),
  120_000,
  'ChatGPT content page'
);
const { socket, call } = await connect(contentTarget);
await call('Network.setCookies', { cookies: payload.cookies });
await call('Runtime.evaluate', {
  expression: 'setTimeout(() => location.reload(), 0); true',
  returnByValue: true,
});
const verificationDeadline = Date.now() + 90_000;
let verified = false;
let lastState = {};
while (Date.now() < verificationDeadline) {
  await new Promise(resolve => setTimeout(resolve, 2_000));
  const evaluation = await call('Runtime.evaluate', {
    expression: `(() => {
      const text = (document.body?.innerText || '').slice(0, 12000);
      const hasSidebar = Boolean(document.querySelector(
        '[data-app-action-sidebar-scroll], nav[aria-label]'
      ));
      const hasProfileMenu = Boolean([...document.querySelectorAll(
        'button[aria-label], [role="button"][aria-label]'
      )].find(element => /profile|个人资料|個人資料/i.test(
        element.getAttribute('aria-label') || ''
      )));
      const asksForLogin = /(^|\\n)(log in|sign up|登录|登入|註冊|注册)(\\n|$)/i.test(text);
      return {
        hasSidebar,
        hasProfileMenu,
        asksForLogin,
        bodyLength: text.length,
        url: location.href
      };
    })()`,
    returnByValue: true,
  });
  lastState = evaluation.result?.value || {};
  if (lastState.hasSidebar && lastState.hasProfileMenu && !lastState.asksForLogin) {
    verified = true;
    break;
  }
}
socket.close();
if (!verified) {
  throw new Error(
    `ChatGPT desktop login UI was not verified (url=${lastState.url || 'unknown'}, bodyLength=${lastState.bodyLength || 0})`
  );
}
process.stdout.write(`Restored ${payload.cookies.length} ChatGPT session cookies\n`);
