const NATIVE_HOST = "com.fabushi.chatgpt_computer_control";
const HEARTBEAT_ALARM = "fabushi-browser-heartbeat";
const RECONNECT_ALARM = "fabushi-browser-reconnect";
const STORAGE = {
  instanceId: "fabushiBrowserInstanceId",
  generation: "fabushiBrowserGeneration",
  claimed: "fabushiClaimedTabs",
};

let nativePort = null;
let nativeConnected = false;
let nativeError = "";
let reconnectTimer = null;
let reconnectDelayMs = 500;
const attachedTabs = new Set();
const queues = new Map();

function randomId() {
  return crypto.randomUUID().replaceAll("-", "");
}

function isOrdinaryWebUrl(value) {
  try { return ["http:", "https:"].includes(new URL(String(value || "")).protocol); }
  catch { return false; }
}

async function state() {
  const local = await chrome.storage.local.get([STORAGE.instanceId]);
  const session = await chrome.storage.session.get([STORAGE.generation, STORAGE.claimed]);
  if (!local[STORAGE.instanceId]) {
    local[STORAGE.instanceId] = randomId();
    await chrome.storage.local.set({ [STORAGE.instanceId]: local[STORAGE.instanceId] });
  }
  if (!session[STORAGE.generation]) {
    session[STORAGE.generation] = randomId();
    await chrome.storage.session.set({ [STORAGE.generation]: session[STORAGE.generation] });
  }
  return {
    instanceId: local[STORAGE.instanceId],
    generation: session[STORAGE.generation],
    claimed: new Set((session[STORAGE.claimed] || []).map(Number)),
  };
}

async function saveClaimed(claimed) {
  await chrome.storage.session.set({ [STORAGE.claimed]: [...claimed] });
  await chrome.action.setBadgeBackgroundColor({ color: claimed.size ? "#111827" : "#9ca3af" });
  await chrome.action.setBadgeText({ text: claimed.size ? String(Math.min(claimed.size, 99)) : "" });
}

async function visibleTabs() {
  const current = await state();
  const tabs = await chrome.tabs.query({});
  const present = new Set(tabs.map((tab) => tab.id));
  let changed = false;
  for (const id of current.claimed) {
    if (!present.has(id)) { current.claimed.delete(id); changed = true; }
  }
  if (changed) await saveClaimed(current.claimed);
  return tabs.filter((tab) => isOrdinaryWebUrl(tab.url || tab.pendingUrl)).map((tab) => ({
    id: String(tab.id),
    title: String(tab.title || ""),
    url: String(tab.url || tab.pendingUrl || ""),
    active: tab.active === true,
    windowId: tab.windowId,
    owner: "user",
    retained: true,
    claimed: current.claimed.has(tab.id),
  }));
}

function post(message) {
  try { nativePort?.postMessage(message); return Boolean(nativePort); }
  catch (error) { nativeError = error?.message || String(error); return false; }
}

async function announce(type = "tabs") {
  const current = await state();
  post({ type, instanceId: current.instanceId, generation: current.generation, browser: navigator.userAgent, tabs: await visibleTabs() });
}

function scheduleReconnect() {
  if (reconnectTimer) return;
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    connectNative();
  }, reconnectDelayMs);
  reconnectDelayMs = Math.min(reconnectDelayMs * 2, 30_000);
  chrome.alarms.create(RECONNECT_ALARM, { delayInMinutes: 0.5 });
}

function connectNative() {
  clearTimeout(reconnectTimer);
  reconnectTimer = null;
  nativeConnected = false;
  try { nativePort = chrome.runtime.connectNative(NATIVE_HOST); }
  catch (error) {
    nativePort = null;
    nativeError = error?.message || String(error);
    scheduleReconnect();
    return;
  }
  nativePort.onMessage.addListener((message) => {
    if (message?.type === "hello_ack") {
      nativeConnected = true;
      nativeError = "";
      reconnectDelayMs = 500;
      chrome.alarms.clear(RECONNECT_ALARM).catch(() => {});
      return;
    }
    if (message?.type === "request") void handleRequest(message);
  });
  nativePort.onDisconnect.addListener(() => {
    nativeError = chrome.runtime.lastError?.message || "Fabushi browser-control bridge disconnected.";
    nativeConnected = false;
    nativePort = null;
    scheduleReconnect();
  });
  void announce("hello");
}

async function locked(tabId, operation) {
  const previous = queues.get(tabId) || Promise.resolve();
  const current = previous.catch(() => {}).then(operation);
  queues.set(tabId, current);
  try { return await current; }
  finally { if (queues.get(tabId) === current) queues.delete(tabId); }
}

async function ensureDebugger(tabId) {
  await locked(tabId, async () => {
    if (attachedTabs.has(tabId)) return;
    try { await chrome.debugger.attach({ tabId }, "1.3"); }
    catch (error) { if (!/already attached/i.test(String(error?.message))) throw error; }
    attachedTabs.add(tabId);
  });
}

async function requireClaimed(targetId) {
  const id = Number(targetId);
  if (!Number.isInteger(id)) throw new Error("Browser target id must be numeric.");
  const current = await state();
  if (!current.claimed.has(id)) throw new Error("Tab has not been claimed by Fabushi.");
  return { id, current };
}

async function handleCommand(command, params = {}) {
  if (command === "list_tabs") return { tabs: await visibleTabs() };
  if (command === "claim_tab") {
    const id = Number(params.targetId);
    if (!Number.isInteger(id)) throw new Error("claim_tab requires a numeric target id.");
    const tab = await chrome.tabs.get(id);
    const url = String(tab.url || tab.pendingUrl || "");
    const title = String(tab.title || "");
    if (!isOrdinaryWebUrl(url)) throw new Error("Only ordinary http/https tabs can be controlled by Fabushi.");
    if (String(params.url || "") !== url || String(params.title || "") !== title) throw new Error("The tab changed before Fabushi could claim it. Refresh browser sessions and retry.");
    const current = await state();
    current.claimed.add(id);
    await saveClaimed(current.claimed);
    return { targetId: String(id), title, url };
  }
  if (command === "cdp") {
    const { id } = await requireClaimed(params.targetId);
    await ensureDebugger(id);
    const target = { tabId: id, ...(params.sessionId ? { sessionId: String(params.sessionId) } : {}) };
    return locked(id, () => chrome.debugger.sendCommand(target, String(params.method), params.params || {}));
  }
  if (command === "detach") {
    const { id, current } = await requireClaimed(params.targetId);
    await chrome.debugger.detach({ tabId: id }).catch(() => {});
    attachedTabs.delete(id);
    current.claimed.delete(id);
    await saveClaimed(current.claimed);
    return {};
  }
  if (command === "create_tab") {
    const url = String(params.url || "about:blank");
    const tab = await chrome.tabs.create({ url, active: params.active !== false });
    return { targetId: String(tab.id) };
  }
  if (command === "tab_action") {
    const { id } = await requireClaimed(params.targetId);
    if (params.action === "activate_tab") {
      const tab = await chrome.tabs.get(id);
      await chrome.windows.update(tab.windowId, { focused: true });
      await chrome.tabs.update(id, { active: true });
    } else if (params.action === "close_tab") await chrome.tabs.remove(id);
    else if (params.action === "navigate") await chrome.tabs.update(id, { url: String(params.url) });
    else if (params.action === "reload") await chrome.tabs.reload(id);
    else if (params.action === "back") await chrome.tabs.goBack(id);
    else if (params.action === "forward") await chrome.tabs.goForward(id);
    else throw new Error(`Unsupported tab action: ${params.action}`);
    await announce();
    return {};
  }
  throw new Error(`Unsupported Fabushi browser command: ${command}`);
}

async function handleRequest(message) {
  try {
    const result = await handleCommand(String(message.command || ""), message.params || {});
    post({ type: "response", requestId: message.requestId, ok: true, result });
  } catch (error) {
    post({ type: "response", requestId: message.requestId, ok: false, error: error?.message || String(error) });
  }
}

chrome.debugger.onEvent.addListener((source, method, params) => {
  if (source.tabId == null) return;
  post({ type: "cdp_event", targetId: String(source.tabId), method, params });
});
chrome.debugger.onDetach.addListener((source) => { if (source.tabId != null) attachedTabs.delete(source.tabId); });
chrome.tabs.onUpdated.addListener(() => { void announce(); });
chrome.tabs.onRemoved.addListener((tabId) => {
  void (async () => {
    const current = await state();
    current.claimed.delete(tabId);
    attachedTabs.delete(tabId);
    await saveClaimed(current.claimed);
    await announce();
  })();
});
chrome.webNavigation.onCreatedNavigationTarget.addListener(() => { void announce(); });

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type !== "fabushi.browser.status") return false;
  visibleTabs().then((tabs) => sendResponse({ connected: nativeConnected, error: nativeError, tabs }), (error) => sendResponse({ connected: false, error: error?.message || String(error), tabs: [] }));
  return true;
});

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === RECONNECT_ALARM && !nativePort) connectNative();
  if (alarm.name === HEARTBEAT_ALARM) {
    if (nativePort) post({ type: "heartbeat", timestamp: Date.now() });
    else connectNative();
  }
});

connectNative();
chrome.alarms.create(HEARTBEAT_ALARM, { periodInMinutes: 0.5 });
void saveClaimed((await state()).claimed);
