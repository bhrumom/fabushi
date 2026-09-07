const views = ["chats", "miniapps", "marketplace", "browser", "settings"];
const labels = { chats: "聊天", miniapps: "小程序", marketplace: "Marketplace", browser: "浏览器", settings: "设置" };
const state = {
  view: "chats",
  desktopConnected: false,
  auth: { loggedIn: false },
  conversations: [],
  activeConversationId: "",
  messages: new Map(),
  installed: [],
  marketplace: [],
  browser: { connected: false, tabs: [] },
};

const $ = (selector) => document.querySelector(selector);
const navButtons = [...document.querySelectorAll("[data-view]")];
const loading = $("#loading");
const banner = $("#banner");
const desktopState = $("#desktop-state");
const accountName = $("#account-name");
const accountDetail = $("#account-detail");
const accountAvatar = $("#account-avatar");
const search = $("#search");

function runtimeMessage(message) {
  return new Promise((resolve, reject) => {
    chrome.runtime.sendMessage(message, (response) => {
      const runtimeError = chrome.runtime.lastError;
      if (runtimeError) reject(new Error(runtimeError.message));
      else resolve(response);
    });
  });
}

async function desktopRequest(method, params = {}, timeoutMs) {
  const response = await runtimeMessage({ type: "fabushi.platform.request", method, params, timeoutMs });
  if (!response?.ok) throw new Error(response?.error || `Desktop request failed: ${method}`);
  return response.result;
}

function requestId(prefix) {
  return `${prefix}-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
}

function showBanner(message, kind = "warning") {
  banner.textContent = message;
  banner.className = `banner${kind === "error" ? " error" : ""}`;
  banner.hidden = false;
}

function hideBanner() {
  banner.hidden = true;
  banner.textContent = "";
}

function setDesktopConnection(connected, error = "") {
  state.desktopConnected = connected;
  desktopState.classList.toggle("connected", connected);
  desktopState.classList.toggle("error", !connected && Boolean(error));
  desktopState.querySelector("strong").textContent = connected ? "桌面端已连接" : "桌面端未连接";
  desktopState.querySelector("span:last-child").textContent = connected ? "共享 Fabushi 账户和 Host" : (error || "请先启动 Fabushi 桌面端");
}

function setAuth(auth) {
  state.auth = auth && typeof auth === "object" ? auth : { loggedIn: false };
  const user = state.auth.user || {};
  const label = user.nickname || user.username || user.email || "Fabushi";
  accountName.textContent = label;
  accountDetail.textContent = state.auth.loggedIn ? `${state.auth.provider || "Fabushi"} · 桌面会话` : "请先在桌面端登录";
  accountAvatar.textContent = String(label).trim().slice(0, 1).toUpperCase() || "F";
  $("#settings-auth").textContent = state.auth.loggedIn ? "已登录" : "未登录";
}

function activateView(name) {
  if (!views.includes(name)) return;
  state.view = name;
  $("#view-title").textContent = labels[name];
  for (const button of navButtons) button.toggleAttribute("aria-current", button.dataset.view === name);
  for (const view of views) $(`#${view}-view`).hidden = view !== name;
  search.placeholder = name === "marketplace" ? "搜索 Marketplace" : name === "chats" ? "搜索聊天" : "搜索 Fabushi";
  if (name === "marketplace") void refreshMarketplace(search.value);
  if (name === "miniapps") void refreshInstalled();
  if (name === "browser") void refreshBrowser();
}

function conversationSubtitle(item) {
  const unread = Number(item.unreadCount || 0);
  const kind = item.kind || "conversation";
  return unread > 0 ? `${kind} · ${unread} 条未读` : kind;
}

function renderConversations(query = "") {
  const needle = query.trim().toLowerCase();
  const list = $("#chat-list");
  list.replaceChildren();
  const filtered = state.conversations.filter((item) => !needle || `${item.title} ${item.kind || ""}`.toLowerCase().includes(needle));
  $("#chat-count").textContent = String(filtered.length);
  for (const item of filtered) {
    const button = document.createElement("button");
    button.type = "button";
    button.classList.toggle("active", item.id === state.activeConversationId);
    const title = document.createElement("strong");
    title.textContent = item.title || "未命名对话";
    const subtitle = document.createElement("span");
    subtitle.textContent = conversationSubtitle(item);
    button.append(title, subtitle);
    button.addEventListener("click", () => void openConversation(item));
    list.append(button);
  }
  if (!filtered.length) {
    const empty = document.createElement("div");
    empty.className = "empty compact";
    empty.innerHTML = "<p>没有匹配的聊天。</p>";
    list.append(empty);
  }
}

function renderMessages() {
  const container = $("#messages");
  container.replaceChildren();
  const messages = state.messages.get(state.activeConversationId) || [];
  for (const message of messages) {
    const node = document.createElement("div");
    node.className = `message${message.role === "user" ? " me" : ""}`;
    node.textContent = message.text || "";
    container.append(node);
  }
  container.scrollTop = container.scrollHeight;
}

async function openConversation(item) {
  state.activeConversationId = item.id;
  renderConversations(search.value);
  $("#conversation-empty").hidden = true;
  $("#conversation").hidden = false;
  $("#conversation-title").textContent = item.title || "聊天";
  renderMessages();
  await desktopRequest("feature.execute", { command: { type: "conversation.open", requestId: requestId("conversation-open"), conversationId: item.id } });
}

function appendMessage(conversationId, message) {
  const id = conversationId || state.activeConversationId || "new";
  const current = state.messages.get(id) || [];
  current.push(message);
  state.messages.set(id, current.slice(-240));
  if (id === state.activeConversationId || (!state.activeConversationId && id === "new")) renderMessages();
}

function handlePlatformEvent(event) {
  if (!event || typeof event !== "object") return;
  if (event.type === "conversation.listed" && Array.isArray(event.conversations)) {
    state.conversations = event.conversations;
    renderConversations(state.view === "chats" ? search.value : "");
    return;
  }
  if (event.type === "conversation.opened") {
    if (event.conversationId) state.activeConversationId = event.conversationId;
    if (Array.isArray(event.messages) && event.conversationId) state.messages.set(event.conversationId, event.messages.map((message) => ({ role: message.role, text: message.text || message.content || "" })));
    renderMessages();
    return;
  }
  if (event.type === "chat.message") {
    appendMessage(state.activeConversationId, { role: event.role, text: event.text || "" });
    return;
  }
  if (event.type === "chat.delta") {
    const id = state.activeConversationId || "new";
    const current = state.messages.get(id) || [];
    const last = current.at(-1);
    if (last?.role === "assistant" && last.streaming) last.text += event.delta || "";
    else current.push({ role: "assistant", text: event.delta || "", streaming: true });
    state.messages.set(id, current);
    renderMessages();
    return;
  }
  if (["operation.completed", "operation.failed", "operation.interrupted"].includes(event.type)) {
    const id = state.activeConversationId || "new";
    const current = state.messages.get(id) || [];
    if (current.at(-1)?.streaming) current.at(-1).streaming = false;
    renderMessages();
  }
}

function marketplaceItems(result) {
  if (Array.isArray(result)) return result;
  for (const key of ["items", "plugins", "results", "entries"]) if (Array.isArray(result?.[key])) return result[key];
  return [];
}

function renderCards(container, items, emptyText) {
  container.replaceChildren();
  for (const item of items) {
    const card = document.createElement("article");
    card.className = "card";
    const heading = document.createElement("h3");
    heading.textContent = item.name || item.displayName || item.title || item.id || "Fabushi App";
    const body = document.createElement("p");
    body.textContent = item.description || item.summary || item.blurb || "Fabushi 小程序";
    const meta = document.createElement("div");
    meta.className = "meta";
    for (const value of [item.version, item.kind, item.category, item.publisher].filter(Boolean).slice(0, 4)) {
      const tag = document.createElement("span");
      tag.className = "tag";
      tag.textContent = String(value);
      meta.append(tag);
    }
    card.append(heading, body, meta);
    container.append(card);
  }
  if (!items.length) {
    const empty = document.createElement("div");
    empty.className = "empty compact";
    empty.innerHTML = `<h3>${emptyText}</h3>`;
    container.append(empty);
  }
}

async function refreshMarketplace(query = "") {
  if (!state.desktopConnected || !state.auth.loggedIn) {
    renderCards($("#marketplace-list"), [], "连接并登录桌面 Fabushi 后即可浏览 Marketplace");
    return;
  }
  try {
    const result = await desktopRequest("feature.marketplace.browse", { query: query.trim() || undefined, platform: "chrome-extension" });
    state.marketplace = marketplaceItems(result);
    renderCards($("#marketplace-list"), state.marketplace, "没有找到兼容 Chrome 的项目");
  } catch (error) {
    showBanner(error.message, "error");
  }
}

async function refreshInstalled() {
  if (!state.desktopConnected || !state.auth.loggedIn) return;
  try {
    const result = await desktopRequest("feature.plugin.listInstalled");
    state.installed = Array.isArray(result) ? result : Array.isArray(result?.plugins) ? result.plugins : Array.isArray(result?.items) ? result.items : [];
    renderCards($("#miniapp-list"), state.installed, "还没有已安装的小程序");
    $("#miniapp-empty").hidden = state.installed.length > 0;
  } catch (error) {
    showBanner(error.message, "error");
  }
}

async function refreshBrowser() {
  try {
    const result = await runtimeMessage({ type: "fabushi.browser.status" });
    state.browser = result || { connected: false, tabs: [] };
    $("#browser-bridge-title").textContent = state.browser.connected ? "浏览器桥接已连接" : "浏览器桥接等待桌面端";
    $("#browser-bridge-detail").textContent = state.browser.connected ? `${state.browser.tabs?.length || 0} 个网页标签页可供 Fabushi 使用` : (state.browser.error || "启动桌面 Fabushi 后会自动连接");
    $("#settings-browser").textContent = state.browser.connected ? "已连接" : "未连接";
    const list = $("#tab-list");
    list.replaceChildren();
    for (const tab of state.browser.tabs || []) {
      const row = document.createElement("div");
      row.className = "tab-row";
      const copy = document.createElement("div");
      const title = document.createElement("strong");
      title.textContent = tab.title || "未命名标签页";
      const url = document.createElement("span");
      url.textContent = tab.url || "";
      copy.append(title, url);
      const claim = document.createElement("span");
      claim.className = "claim";
      claim.textContent = tab.claimed ? "Fabushi 已接管" : "可连接";
      row.append(copy, claim);
      list.append(row);
    }
  } catch (error) {
    state.browser = { connected: false, tabs: [], error: error.message };
    $("#settings-browser").textContent = "未连接";
  }
}

async function openDesktopSettings() {
  try {
    await desktopRequest("desktop.settings.open", { section: "general" }, 10_000);
    hideBanner();
  } catch (error) {
    showBanner(`无法打开桌面设置：${error.message}`, "error");
  }
}

async function initialize() {
  loading.hidden = false;
  hideBanner();
  try {
    const platformStatus = await runtimeMessage({ type: "fabushi.platform.status" });
    if (!platformStatus?.connected) {
      await runtimeMessage({ type: "fabushi.platform.reconnect" }).catch(() => {});
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
    const desktop = await desktopRequest("desktop.status", {}, 10_000);
    setDesktopConnection(true);
    setAuth(desktop?.auth || await desktopRequest("feature.auth.status"));
    if (!state.auth.loggedIn) showBanner("请先在 Fabushi 桌面端完成登录。插件会自动复用桌面会话，不会保存登录密码。", "warning");
    else {
      await desktopRequest("feature.execute", { command: { type: "conversation.list", requestId: requestId("conversation-list") } });
      await Promise.allSettled([refreshInstalled(), refreshBrowser()]);
    }
  } catch (error) {
    setDesktopConnection(false, error.message);
    setAuth({ loggedIn: false });
    showBanner(`Fabushi 桌面端尚未连接：${error.message}`, "error");
  } finally {
    loading.hidden = true;
    activateView("chats");
  }
}

for (const button of navButtons) button.addEventListener("click", () => activateView(button.dataset.view));
$("#open-desktop-settings").addEventListener("click", () => void openDesktopSettings());
$("#settings-open-desktop").addEventListener("click", () => void openDesktopSettings());
$("#account-button").addEventListener("click", () => activateView("settings"));
$("#refresh-browser").addEventListener("click", () => void refreshBrowser());
$("#new-chat").addEventListener("click", () => {
  state.activeConversationId = "new";
  $("#conversation-empty").hidden = true;
  $("#conversation").hidden = false;
  $("#conversation-title").textContent = "新对话";
  state.messages.set("new", []);
  renderMessages();
  $("#composer-input").focus();
});
$("#composer").addEventListener("submit", (event) => {
  event.preventDefault();
  const input = $("#composer-input");
  const text = input.value.trim();
  if (!text || !state.auth.loggedIn) return;
  input.value = "";
  const conversationId = state.activeConversationId === "new" ? undefined : state.activeConversationId || undefined;
  appendMessage(state.activeConversationId || "new", { role: "user", text });
  void desktopRequest("feature.execute", { command: { type: "chat.send", requestId: requestId("chat-send"), text, conversationId, agentId: conversationId ? undefined : "mahayana-assistant", mode: "agent" } })
    .catch((error) => showBanner(error.message, "error"));
});
search.addEventListener("input", () => {
  if (state.view === "chats") renderConversations(search.value);
  if (state.view === "marketplace") void refreshMarketplace(search.value);
});
document.addEventListener("keydown", (event) => {
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
    event.preventDefault();
    search.focus();
  }
});
chrome.runtime.onMessage.addListener((message) => {
  if (message?.type === "fabushi.platform.event") handlePlatformEvent(message.event);
  if (message?.type === "fabushi.platform.connection") setDesktopConnection(message.connected === true, message.error || "");
});

await initialize();
