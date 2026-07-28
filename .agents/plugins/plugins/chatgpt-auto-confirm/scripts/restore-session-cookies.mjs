const port = Number(process.env.CHATGPT_CDP_PORT || 9324);
const mode = process.env.CHATGPT_SESSION_MODE || 'restore-and-verify';
const encoded = process.env.CHATGPT_SESSION_COOKIES_B64;

if (!['seed', 'verify', 'restore-and-verify'].includes(mode)) {
  throw new Error(`Unsupported CHATGPT_SESSION_MODE: ${mode}`);
}

let payload = { cookies: [] };
if (mode !== 'verify') {
  if (!encoded) {
    throw new Error(
      'CHATGPT_SESSION_COOKIES_B64 is required because Codex auth alone only restores Work access'
    );
  }
  payload = JSON.parse(Buffer.from(encoded, 'base64').toString('utf8'));
  if (!Array.isArray(payload.cookies) || payload.cookies.length === 0) {
    throw new Error('The ChatGPT session cookie secret is empty');
  }
}

const sleep = milliseconds =>
  new Promise(resolve => setTimeout(resolve, milliseconds));

const listTargets = async () =>
  fetch(`http://127.0.0.1:${port}/json/list`).then(response => response.json());

const findTarget = async (timeoutMs, label) => {
  const deadline = Date.now() + timeoutMs;
  let lastTargets = [];
  while (Date.now() < deadline) {
    try {
      lastTargets = await listTargets();
      const target = lastTargets.find(item =>
        item.type === 'page'
        && item.webSocketDebuggerUrl
        && String(item.url || '').startsWith('app://-/index.html')
        && !String(item.url || '').includes('/avatar-overlay')
      );
      if (target) return target;
    } catch {}
    await sleep(1_000);
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

const activate = async call => {
  await call('Page.setWebLifecycleState', { state: 'active' });
  await call('Emulation.setFocusEmulationEnabled', { enabled: true });
  await call('Emulation.setIdleOverride', {
    isUserActive: true,
    isScreenUnlocked: true,
  });
};

const target = await findTarget(120_000, 'ChatGPT app shell');
const { socket, call } = await connect(target);
await activate(call);

if (mode !== 'verify') {
  await call('Network.setCookies', { cookies: payload.cookies });
  const result = await call('Network.getAllCookies');
  const restored = (result.cookies || []).filter(cookie =>
    /(^|\.)((chatgpt|openai)\.com)$/i.test(cookie.domain || '')
  ).length;
  if (restored === 0) {
    socket.close();
    throw new Error('ChatGPT session cookies were not persisted');
  }
  if (mode === 'seed') {
    socket.close();
    process.stdout.write(`Seeded ${restored} ChatGPT session cookies\n`);
    process.exit(0);
  }
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
  await sleep(2_000);
  await activate(call);
  const evaluation = await call('Runtime.evaluate', {
    expression: `(() => {
      const normalize = value => (value || '').replace(/\\s+/g, ' ').trim();
      const visible = element => !!(element && (
        element.offsetWidth || element.offsetHeight || element.getClientRects().length
      ));
      const bodyText = normalize(document.body?.innerText).slice(0, 12000);
      const controls = [...document.querySelectorAll(
        'button, [role="button"], [role="tab"], [aria-label]'
      )].filter(visible);
      const labels = controls.map(element => normalize([
        element.innerText,
        element.textContent,
        element.getAttribute('aria-label'),
        element.getAttribute('title')
      ].filter(Boolean).join(' ')));
      const exact = label => labels.some(value => value.toLowerCase() === label);
      const hasChat = exact('chat') || exact('聊天');
      const hasWork = exact('work') || exact('工作');
      const currentMode = labels.find(value =>
        /current mode|当前模式|目前模式/i.test(value)
      ) || '';
      const asksForLogin = /(^|\\n)(log in|sign up|登录|登入|註冊|注册)(\\n|$)/i.test(bodyText);
      const workComposer = !!document.querySelector('[data-codex-composer="true"]');
      return {
        hasChat,
        hasWork,
        currentMode: currentMode.slice(0, 160),
        asksForLogin,
        workComposer,
        bodyLength: bodyText.length,
        url: location.href,
        bridge: !!window.electronBridge,
        visibility: document.visibilityState,
        readyState: document.readyState
      };
    })()`,
    returnByValue: true,
  });
  lastState = evaluation.result?.value || {};
  if (
    lastState.hasChat
    && lastState.hasWork
    && !lastState.asksForLogin
    && lastState.bridge
  ) {
    verified = true;
    break;
  }
}

socket.close();
if (!verified) {
  throw new Error(
    `Authenticated Chat surface was not verified (${JSON.stringify(lastState)})`
  );
}
process.stdout.write(
  `Verified authenticated Chat surface (${JSON.stringify(lastState)})\n`
);
