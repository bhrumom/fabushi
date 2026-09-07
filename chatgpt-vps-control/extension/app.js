const sections = {
  Chats: "Open conversations and continue your Fabushi work.",
  "Mini Apps": "Run focused Fabushi mini apps from one consistent application shell.",
  Marketplace: "Discover mini apps and integrations for Fabushi.",
};

const MARKETPLACE_SECTION = "Marketplace";
const USER_SCRIPT_PORT = "fabushi-userscripts";
const marketplaceCatalog = [
  {
    id: "userscript-chatgpt-task-queue",
    name: "ChatGPT Task Queue",
    description: "Queue ChatGPT tasks, send them sequentially, safely confirm explicit low-risk @ChatGPT prompts, retry failures, and display status.",
    kind: "userscript",
    surfaces: [MARKETPLACE_SECTION],
    platforms: ["chrome-extension"],
    tags: ["ChatGPT", "task queue", "automation", "userscript", "safe confirmation"],
    version: "1.0.0",
    matches: ["https://chatgpt.com/*", "https://chat.openai.com/*"],
    sourcePath: "marketplace/chatgpt-task-queue.user.js",
  },
  {
    id: "desktop-device-control",
    name: "Device Control",
    description: "Manage Fabushi devices from desktop application builds.",
    kind: "mini-app",
    surfaces: [MARKETPLACE_SECTION],
    platforms: ["desktop"],
    tags: ["device", "desktop"],
  },
  {
    id: "mobile-companion",
    name: "Mobile Companion",
    description: "Mobile-only companion mini app.",
    kind: "mini-app",
    surfaces: [MARKETPLACE_SECTION],
    platforms: ["ios", "android"],
    tags: ["mobile"],
  },
];

const title = document.querySelector("#section-title");
const description = document.querySelector("#section-description");
const status = document.querySelector("#section-status");
const content = document.querySelector(".content");
const buttons = [...document.querySelectorAll("[data-section]")];
const search = document.querySelector("#app-search");
const loadingState = document.querySelector("#loading-state");
const errorState = document.querySelector("#error-state");
const errorMessage = document.querySelector("#error-message");
const retryButton = document.querySelector("#retry-button");
const views = {
  Chats: document.querySelector("#chats-view"),
  "Mini Apps": document.querySelector("#mini-apps-view"),
  Marketplace: document.querySelector("#marketplace-view"),
};
const marketplaceList = document.querySelector("#marketplace-list");
const marketplaceCount = document.querySelector("#marketplace-count");
const marketplacePlatform = document.querySelector("#marketplace-platform");
const currentPlatform = document.body.dataset.platform || "unknown";
let currentSection = "Chats";
let userscriptStatus = { available: false, consent: false, scripts: [] };
const userscriptSourceCache = new Map();

marketplacePlatform.textContent = currentPlatform;

function normalizedSearchText(item) {
  return [item.name, item.description, item.kind, ...item.platforms, ...item.tags].join(" ").toLowerCase();
}

function isVisibleInMarketplace(item) {
  if (!item.surfaces.includes(MARKETPLACE_SECTION)) return false;
  if (!item.platforms.includes(currentPlatform)) return false;
  if (item.kind === "userscript") return currentPlatform === "chrome-extension" && item.surfaces.length === 1;
  return true;
}

function getVisibleMarketplaceItems(query = "") {
  const normalizedQuery = query.trim().toLowerCase();
  return marketplaceCatalog.filter((item) => isVisibleInMarketplace(item) && (!normalizedQuery || normalizedSearchText(item).includes(normalizedQuery)));
}

function userscriptRequest(action, payload = {}) {
  return new Promise((resolve, reject) => {
    const port = chrome.runtime.connect({ name: USER_SCRIPT_PORT });
    const requestId = crypto.randomUUID();
    let settled = false;
    const cleanup = () => { try { port.disconnect(); } catch {} };
    port.onMessage.addListener((message) => {
      if (message?.requestId !== requestId) return;
      settled = true;
      cleanup();
      if (message.ok) resolve(message.result);
      else reject(new Error(message.error || "Userscript request failed."));
    });
    port.onDisconnect.addListener(() => {
      if (!settled && chrome.runtime.lastError) reject(new Error(chrome.runtime.lastError.message));
    });
    port.postMessage({ requestId, action, ...payload });
  });
}

async function sha256(value) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function loadUserscriptSource(item) {
  if (item.kind !== "userscript" || !item.sourcePath) throw new Error("Marketplace userscript release is missing its packaged source path.");
  if (userscriptSourceCache.has(item.id)) return userscriptSourceCache.get(item.id);
  const response = await fetch(chrome.runtime.getURL(item.sourcePath), { cache: "no-store", credentials: "same-origin" });
  if (!response.ok) throw new Error(`Could not load packaged userscript source (${response.status}).`);
  const code = await response.text();
  if (!code.includes("// ==UserScript==") || !code.includes("// ==/UserScript==")) throw new Error("Packaged userscript source has invalid metadata.");
  for (const match of item.matches) {
    if (!code.includes(`// @match        ${match}`) && !code.includes(`// @match ${match}`)) throw new Error(`Packaged userscript metadata is missing approved match ${match}.`);
  }
  userscriptSourceCache.set(item.id, code);
  return code;
}

async function refreshUserscriptStatus() {
  if (currentPlatform !== "chrome-extension") return;
  try { userscriptStatus = await userscriptRequest("status"); }
  catch (error) { userscriptStatus = { available: false, consent: false, scripts: [], runtimeError: error.message }; }
}

function installedScript(item) {
  return userscriptStatus.scripts?.find((script) => script.id === item.id);
}

async function installUserscript(item, statusNode) {
  statusNode.textContent = "Installing…";
  try {
    if (!userscriptStatus.consent) userscriptStatus = await userscriptRequest("set-consent", { consent: true, userConfirmed: true });
    const code = await loadUserscriptSource(item);
    const digest = await sha256(code);
    await userscriptRequest("install", {
      userConfirmed: true,
      script: { id: item.id, name: item.name, version: item.version, code, matches: item.matches, permissions: ["page-dom"], runAt: "document_idle", source: { kind: "marketplace", pluginId: item.id, version: item.version, sha256: digest } },
    });
    await refreshUserscriptStatus();
    renderMarketplace(search.value);
  } catch (error) { statusNode.textContent = error.message; }
}

async function setUserscriptEnabled(item, enabled, statusNode) {
  statusNode.textContent = enabled ? "Enabling…" : "Stopping…";
  try {
    userscriptStatus = await userscriptRequest("set-enabled", { id: item.id, enabled, userConfirmed: enabled });
    renderMarketplace(search.value);
  } catch (error) { statusNode.textContent = error.message; }
}

function renderMarketplace(query = "") {
  const visibleItems = getVisibleMarketplaceItems(query);
  marketplaceList.replaceChildren();
  for (const item of visibleItems) {
    const card = document.createElement("article");
    card.className = "marketplace-card";
    const heading = document.createElement("h3");
    heading.textContent = item.name;
    const body = document.createElement("p");
    body.textContent = item.description;
    const badges = document.createElement("div");
    badges.className = "badges";
    for (const badgeText of [item.kind, ...item.tags]) {
      const badge = document.createElement("span");
      badge.className = "badge";
      badge.textContent = badgeText;
      badges.append(badge);
    }
    card.append(heading, body, badges);
    if (item.kind === "userscript") {
      const state = installedScript(item);
      const actions = document.createElement("div");
      actions.className = "marketplace-actions";
      const actionButton = document.createElement("button");
      actionButton.type = "button";
      actionButton.className = "marketplace-action";
      actionButton.textContent = !state ? "Install" : state.enabled ? "Stop" : "Run";
      const statusNode = document.createElement("span");
      statusNode.className = "marketplace-status";
      statusNode.textContent = userscriptStatus.runtimeError ? userscriptStatus.runtimeError : state?.enabled ? "Running" : state ? "Installed" : "Not installed";
      actionButton.disabled = Boolean(userscriptStatus.runtimeError);
      actionButton.addEventListener("click", () => { if (!state) void installUserscript(item, statusNode); else void setUserscriptEnabled(item, !state.enabled, statusNode); });
      actions.append(actionButton, statusNode);
      card.append(actions);
    }
    marketplaceList.append(card);
  }
  if (!visibleItems.length) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.innerHTML = "<div class=\"empty-icon\" aria-hidden=\"true\">⌕</div><h3>No results</h3><p>No Marketplace items match this search on this platform.</p>";
    marketplaceList.append(empty);
  }
  marketplaceCount.textContent = `${visibleItems.length} ${visibleItems.length === 1 ? "result" : "results"}`;
}

function setLoading(active) {
  loadingState.hidden = !active;
  content.setAttribute("aria-busy", String(active));
  status.textContent = active ? "Loading" : "Ready";
}

function setError(error) {
  errorState.hidden = !error;
  errorMessage.textContent = error?.message || "Reload the extension and try again.";
  status.textContent = error ? "Error" : "Ready";
  for (const view of Object.values(views)) view.hidden = Boolean(error) || view.hidden;
}

function activateSection(section) {
  currentSection = section;
  errorState.hidden = true;
  for (const button of buttons) button.toggleAttribute("aria-current", button.dataset.section === section);
  for (const [name, view] of Object.entries(views)) view.hidden = name !== section;
  title.textContent = section;
  description.textContent = sections[section] || "";
  search.placeholder = `Search ${section}`;
  status.textContent = "Ready";
  if (section === MARKETPLACE_SECTION) renderMarketplace(search.value);
}

for (const button of buttons) button.addEventListener("click", () => activateSection(button.dataset.section));
for (const button of document.querySelectorAll("[data-section-jump]")) button.addEventListener("click", () => activateSection(button.dataset.sectionJump));
search.addEventListener("input", () => {
  if (currentSection !== MARKETPLACE_SECTION) activateSection(MARKETPLACE_SECTION);
  const query = search.value.trim();
  description.textContent = query ? `Searching Marketplace for “${query}” on ${currentPlatform}.` : sections.Marketplace;
});
document.addEventListener("keydown", (event) => {
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") { event.preventDefault(); search.focus(); }
});
retryButton.addEventListener("click", () => { void initializeApp(); });

async function initializeApp() {
  setError(null);
  setLoading(true);
  try {
    await refreshUserscriptStatus();
    activateSection("Chats");
  } catch (error) {
    setError(error instanceof Error ? error : new Error(String(error)));
  } finally {
    setLoading(false);
  }
}

await initializeApp();
