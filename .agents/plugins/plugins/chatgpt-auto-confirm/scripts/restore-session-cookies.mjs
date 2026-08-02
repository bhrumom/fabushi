const port = Number(process.env.CHATGPT_CDP_PORT || 9324);
const mode = process.env.CHATGPT_SESSION_MODE || 'restore-and-verify';
const encoded = process.env.CHATGPT_SESSION_COOKIES_B64;

if (!['seed', 'restore', 'verify', 'restore-and-verify'].includes(mode)) {
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

const authenticatedControllerIsReady = state =>
  !state.asksForLogin
  && state.bridge
  && state.readyState === 'complete'
  && state.bodyLength > 50;

const appRootURL = 'app://-/index.html?initialRoute=%2F';

const listTargets = async () =>
  fetch(`http://127.0.0.1:${port}/json/list`, {
    signal: AbortSignal.timeout(5_000),
  }).then(response => response.json());

const findTarget = async (timeoutMs, label) => {
  const deadline = Date.now() + timeoutMs;
  const avatarOverlayFallbackDeadline = Date.now() + Math.min(10_000, timeoutMs);
  let lastTargets = [];
  let avatarOverlayTarget;
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
      avatarOverlayTarget = lastTargets.find(item =>
        item.type === 'page'
        && item.webSocketDebuggerUrl
        && String(item.url || '').startsWith('app://-/index.html')
        && String(item.url || '').includes('/avatar-overlay')
      ) || avatarOverlayTarget;
      // The desktop app can expose only its startup avatar overlay while the
      // normal renderer is being bootstrapped. It is still a valid CDP page;
      // recover it to the app root after connecting instead of waiting for a
      // renderer that the app will not create on its own.
      if (avatarOverlayTarget && Date.now() >= avatarOverlayFallbackDeadline) {
        return avatarOverlayTarget;
      }
    } catch {}
    await sleep(1_000);
  }
  if (avatarOverlayTarget) return avatarOverlayTarget;
  const safeTargets = lastTargets.map(item => ({
    type: item.type,
    url: String(item.url || '').slice(0, 160),
  }));
  throw new Error(`${label} was not exposed; targets=${JSON.stringify(safeTargets)}`);
};

const connect = async target => {
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    const cleanup = () => {
      clearTimeout(timer);
      socket.removeEventListener('open', onOpen);
      socket.removeEventListener('error', onError);
    };
    const onOpen = () => {
      cleanup();
      resolve();
    };
    const onError = event => {
      cleanup();
      reject(event);
    };
    const timer = setTimeout(() => {
      cleanup();
      try {
        socket.close();
      } catch {}
      reject(new Error('ChatGPT CDP socket connection timed out'));
    }, 15_000);
    socket.addEventListener('open', onOpen, { once: true });
    socket.addEventListener('error', onError, { once: true });
  });
  let sequence = 0;
  const call = (method, params = {}, timeoutMs = 30_000) => new Promise((resolve, reject) => {
    const id = ++sequence;
    let settled = false;
    const cleanup = () => {
      clearTimeout(timer);
      socket.removeEventListener('message', onMessage);
      socket.removeEventListener('close', onClose);
      socket.removeEventListener('error', onError);
    };
    const finish = (handler, value) => {
      if (settled) return;
      settled = true;
      cleanup();
      handler(value);
    };
    const onMessage = event => {
      let message;
      try {
        message = JSON.parse(String(event.data));
      } catch {
        return;
      }
      if (message.id !== id) return;
      if (message.error) {
        finish(reject, new Error(`${method} failed: ${JSON.stringify(message.error)}`));
      } else {
        finish(resolve, message.result || {});
      }
    };
    const onClose = () => finish(reject, new Error(`${method} failed because the CDP socket closed`));
    const onError = () => finish(reject, new Error(`${method} failed because the CDP socket errored`));
    const timer = setTimeout(() => {
      finish(reject, new Error(`${method} timed out`));
    }, timeoutMs);
    socket.addEventListener('message', onMessage);
    socket.addEventListener('close', onClose, { once: true });
    socket.addEventListener('error', onError, { once: true });
    try {
      socket.send(JSON.stringify({ id, method, params }));
    } catch (error) {
      finish(reject, error instanceof Error ? error : new Error(String(error)));
    }
  });
  return { socket, call };
};

const restoreAppRootIfNeeded = async call => {
  let currentURL = '';
  try {
    const evaluation = await call('Runtime.evaluate', {
      expression: 'location.href',
      returnByValue: true,
    }, 5_000);
    currentURL = String(evaluation.result?.value || '');
  } catch {}
  if (!currentURL.includes('/avatar-overlay')) return false;
  const navigated = await optionalCall(call, 'Page.navigate', { url: appRootURL }, 10_000);
  if (navigated) await sleep(1_000);
  return navigated;
};

const optionalCall = async (call, method, params = {}, timeoutMs = 5_000) => {
  try {
    await call(method, params, timeoutMs);
    return true;
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    process.stderr.write(`Optional CDP command ${method} failed: ${detail}\n`);
    return false;
  }
};

const activate = async call => {
  // New ChatGPT desktop builds can leave Page.setWebLifecycleState unanswered.
  // Focus hints improve hosted rendering but must never abort cookie bootstrap.
  await optionalCall(call, 'Emulation.setFocusEmulationEnabled', { enabled: true });
  await optionalCall(call, 'Emulation.setIdleOverride', {
    isUserActive: true,
    isScreenUnlocked: true,
  });
};

const target = await findTarget(120_000, 'ChatGPT app shell');
const { socket, call } = await connect(target);

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

// A fresh hosted desktop launch can land on the internal avatar overlay
// instead of the normal app shell. The overlay is blank but remains a live
// renderer, so navigate that same target back to the authenticated app root.
await restoreAppRootIfNeeded(call);

if (mode === 'restore' || mode === 'restore-and-verify') {
  // Page.reload is a bounded request and is more reliable than evaluating
  // location.reload() inside a renderer that may still be suspended.
  await optionalCall(call, 'Page.reload', { ignoreCache: true }, 10_000);
  await restoreAppRootIfNeeded(call);
}
await activate(call);

// Hosted macOS can leave the visible controller blank after reload. The
// native queue must be allowed to create and verify the real Chat renderer.
if (mode === 'restore') {
  socket.close();
  process.stdout.write(`Restored ${payload.cookies.length} ChatGPT session cookies and requested renderer reload\n`);
  process.exit(0);
}

// Cookie restoration authenticates the visible controller window. A fresh
// hosted runner commonly opens that controller on Work, while the native queue
// runtime creates and validates its own show:false Chat window immediately
// afterwards. Requiring the controller itself to finish rendering Chat here
// prevented the real hidden-Chat path from ever running.
const verificationDeadline = Date.now() + 120_000;
let verified = false;
let lastState = {};
while (Date.now() < verificationDeadline) {
  await sleep(2_000);
  await restoreAppRootIfNeeded(call);
  let evaluation;
  try {
    evaluation = await call('Runtime.evaluate', {
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
    }, 15_000);
  } catch (error) {
    lastState = {
      cdpError: error instanceof Error ? error.message : String(error),
    };
    continue;
  }
  lastState = evaluation.result?.value || {};
  if (authenticatedControllerIsReady(lastState)) {
    verified = true;
    break;
  }
}

socket.close();
if (!verified) {
  throw new Error(
    `Authenticated desktop shell was not verified (${JSON.stringify(lastState)})`
  );
}
process.stdout.write(
  `Verified authenticated desktop shell (${JSON.stringify(lastState)})\n`
);
// This is a one-shot bootstrap command. Electron does not always complete the
// DevTools WebSocket close handshake on hosted macOS, which can otherwise keep
// Node alive after verification has already succeeded.
process.exit(0);
