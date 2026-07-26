const port = Number(process.env.CHATGPT_CDP_PORT || 9324);
const mode = process.env.CHATGPT_SESSION_MODE || 'restore-and-verify';
const encoded = process.env.CHATGPT_SESSION_COOKIES_B64;
if (!['seed', 'verify', 'restore-and-verify'].includes(mode)) {
  throw new Error(`Unsupported CHATGPT_SESSION_MODE: ${mode}`);
}
let payload = { cookies: [] };
if (mode !== 'verify') {
  if (!encoded) throw new Error('CHATGPT_SESSION_COOKIES_B64 is required');
  payload = JSON.parse(Buffer.from(encoded, 'base64').toString('utf8'));
  if (!Array.isArray(payload.cookies) || payload.cookies.length === 0) {
    throw new Error('The ChatGPT cookie secret is empty');
  }
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
const { socket, call } = await connect(shellTarget);
await call('Page.setWebLifecycleState', { state: 'active' });
await call('Emulation.setFocusEmulationEnabled', { enabled: true });
await call('Emulation.setIdleOverride', {
  isUserActive: true,
  isScreenUnlocked: true,
});
if (mode !== 'verify') {
  await call('Network.setCookies', { cookies: payload.cookies });
}
if (mode === 'seed') {
  const result = await call('Network.getAllCookies');
  const restored = (result.cookies || []).filter(cookie =>
    /(^|\.)((chatgpt|openai)\.com)$/i.test(cookie.domain || '')
  ).length;
  socket.close();
  if (restored === 0) {
    throw new Error('ChatGPT session cookies were not persisted');
  }
  process.stdout.write(`Seeded ${restored} ChatGPT session cookies\n`);
  process.exit(0);
}
if (mode === 'restore-and-verify') {
  await call('Runtime.evaluate', {
    expression: `(() => {
      document.dispatchEvent(new Event('visibilitychange'));
      window.dispatchEvent(new Event('focus'));
      setTimeout(() => location.reload(), 0);
      return true;
    })()`,
    returnByValue: true,
  });
}
const verificationDeadline = Date.now() + 120_000;
let verified = false;
let lastState = {};
while (Date.now() < verificationDeadline) {
  await new Promise(resolve => setTimeout(resolve, 2_000));
  await call('Page.setWebLifecycleState', { state: 'active' });
  await call('Emulation.setFocusEmulationEnabled', { enabled: true });
  await call('Emulation.setIdleOverride', {
    isUserActive: true,
    isScreenUnlocked: true,
  });
  const evaluation = await call('Runtime.evaluate', {
    expression: `(() => {
      document.dispatchEvent(new Event('visibilitychange'));
      window.dispatchEvent(new Event('focus'));
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
        url: location.href,
        bridge: Boolean(window.electronBridge),
        visibility: document.visibilityState,
        readyState: document.readyState,
        rootChildren: document.querySelector('#root')?.childElementCount || 0
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
    `ChatGPT desktop login UI was not verified (${JSON.stringify(lastState)})`
  );
}
process.stdout.write('Verified restored ChatGPT desktop login\n');
