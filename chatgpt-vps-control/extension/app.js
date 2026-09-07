const sections = {
  Chats: "Open conversations and continue your Fabushi work.",
  "Mini Apps": "Run focused Fabushi mini apps from one consistent application shell.",
  Marketplace: "Discover mini apps and integrations for Fabushi.",
};

const MARKETPLACE_SECTION = "Marketplace";
const USER_SCRIPT_PORT = "fabushi-userscripts";
const USERSCRIPT_CODE = `// ==UserScript==\n// @name Fabushi ChatGPT Control\n// @match https://chatgpt.com/*\n// @match https://chat.openai.com/*\n// @grant none\n// ==/UserScript==\nwindow.dispatchEvent(new CustomEvent("fabushi:userscript-ready", { detail: { source: "marketplace" } }));`;

const marketplaceCatalog = [
  {
    id: "userscript-chatgpt-control",
    name: "ChatGPT Control Userscript",
    description: "Run Fabushi browser-control automation directly in supported ChatGPT tabs.",
    kind: "userscript",
    surfaces: [MARKETPLACE_SECTION],
    platforms: ["chrome-extension"],
    tags: ["ChatGPT", "automation", "userscript"],
    version: "1.0.0",
    matches: ["https://chatgpt.com/*", "https://chat.openai.com/*"],
    code: USERSCRIPT_CODE,
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
const buttons = [...document.querySelectorAll("[data-section]")];
const search = document.querySelector("#marketplace-search");
const marketplaceView = document.querySelector("#marketplace-view");
const marketplaceList = document.querySelector("#marketplace-list");
const marketplaceCount = document.querySelector("#marketplace-count");
const marketplacePlatform = document.querySelector("#marketplace-platform");
const currentPlatform = document.body.dataset.platform || "unknown";
let userscriptStatus = { available: false, consent: false, scripts: [] };

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
  return marketplaceCatalog.filter((item) => {
    const queryMatches = !normalizedQuery || normalizedSearchText(item).includes(normalizedQuery);
    return isVisibleInMarketplace(item) && queryMatches;
  });
}

function userscriptRequest(action, payload = {}) {
  return new Promise((resolve, reject) => {
    const port = chrome.runtime.connect({ name: USER_SCRIPT_PORT });
    const requestId = crypto.randomUUID();
    const cleanup = () => {
      try { port.disconnect(); } catch {}
    };
    port.onMessage.addListener((message) => {
      if (message?.requestId !== requestId) return;
      cleanup();
      if (message.ok) resolve(message.result);
      else reject(new Error(message.error || "Userscript request failed."));
    });
    port.onDisconnect.addListener(() => {
      if (chrome.runtime.lastError) reject(new Error(chrome.runtime.lastError.message));
    });
    port.postMessage({ requestId, action, ...payload });
  });
}

async function sha256(value) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function refreshUserscriptStatus() {
  if (currentPlatform !== "chrome-extension") return;
  try {
    userscriptStatus = await userscriptRequest("status");
  } catch (error) {
    userscriptStatus = { available: false, consent: false, scripts: [], runtimeError: error.message };
  }
}

function installedScript(item) {
  return userscriptStatus.scripts?.find((script) => script.id === item.id);
}

async function installUserscript(item, statusNode) {
  statusNode.textContent = "Installing…";
  try {
    if (!userscriptStatus.consent) {
      userscriptStatus = await userscriptRequest("set-consent", { consent: true, userConfirmed: true });
    }
    const digest = await sha256(item.code);
    await userscriptRequest("install", {
      userConfirmed: true,
      script: {
        id: item.id,
        name: item.name,
        version: item.version,
        code: item.code,
        matches: item.matches,
        permissions: ["page-dom"],
        runAt: "document_idle",
        source: { kind: "marketplace", pluginId: item.id, version: item.version, sha256: digest },
      },
    });
    await refreshUserscriptStatus();
    statusNode.textContent = "Installed. Enable it to run.";
    renderMarketplace(search.value);
  } catch (error) {
    statusNode.textContent = error.message;
  }
}

async function setUserscriptEnabled(item, enabled, statusNode) {
  statusNode.textContent = enabled ? "Enabling…" : "Stopping…";
  try {
    userscriptStatus = await userscriptRequest("set-enabled", {
      id: item.id,
      enabled,
      userConfirmed: enabled,
    });
    statusNode.textContent = enabled ? "Running on matched ChatGPT pages." : "Stopped.";
    renderMarketplace(search.value);
  } catch (error) {
    statusNode.textContent = error.message;
  }
}

function renderMarketplace(query = "") {
  const visibleItems = getVisibleMarketplaceItems(query);
  marketplaceList.replaceChildren();

  for (const item of visibleItems) {
    const card = document.createElement("article");
    card.className = "marketplace-card";
    card.dataset.kind = item.kind;
    card.dataset.platforms = item.platforms.join(",");

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
      statusNode.textContent = userscriptStatus.available === false && userscriptStatus.runtimeError
        ? userscriptStatus.runtimeError
        : state?.enabled ? "Running" : state ? "Installed" : "Not installed";
      actionButton.disabled = userscriptStatus.available === false && Boolean(userscriptStatus.runtimeError);
      actionButton.addEventListener("click", () => {
        if (!state) void installUserscript(item, statusNode);
        else void setUserscriptEnabled(item, !state.enabled, statusNode);
      });
      actions.append(actionButton, statusNode);
      card.append(actions);
    }

    marketplaceList.append(card);
  }

  if (visibleItems.length === 0) {
    const empty = document.createElement("p");
    empty.className = "marketplace-empty";
    empty.textContent = "No Marketplace items match this search on this platform.";
    marketplaceList.append(empty);
  }
  marketplaceCount.textContent = `${visibleItems.length} ${visibleItems.length === 1 ? "result" : "results"}`;
}

function activateSection(section) {
  for (const item of buttons) {
    if (item.dataset.section === section) item.setAttribute("aria-current", "page");
    else item.removeAttribute("aria-current");
  }
  title.textContent = section;
  description.textContent = sections[section] ?? "";
  const isMarketplace = section === MARKETPLACE_SECTION;
  marketplaceView.hidden = !isMarketplace;
  if (isMarketplace) {
    renderMarketplace(search.value);
    search.focus();
  }
}

for (const button of buttons) button.addEventListener("click", () => activateSection(button.dataset.section));
search.addEventListener("input", () => {
  activateSection(MARKETPLACE_SECTION);
  const query = search.value.trim();
  description.textContent = query ? `Searching Marketplace for “${query}” on ${currentPlatform}.` : sections.Marketplace;
});

await refreshUserscriptStatus();
renderMarketplace();
