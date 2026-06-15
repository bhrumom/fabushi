const DEFAULT_BRIDGE_URL = "http://127.0.0.1:18790";
const CONNECTOR_ID_KEY = "connectorId";

async function getSettings() {
  const settings = await chrome.storage.local.get([
    "bridgeUrl",
    "token",
    CONNECTOR_ID_KEY,
  ]);
  let connectorId = settings[CONNECTOR_ID_KEY];
  if (!connectorId) {
    connectorId = `chrome_${crypto.randomUUID()}`;
    await chrome.storage.local.set({ [CONNECTOR_ID_KEY]: connectorId });
  }
  return {
    bridgeUrl: (settings.bridgeUrl || DEFAULT_BRIDGE_URL).replace(/\/$/, ""),
    token: settings.token || "",
    connectorId,
  };
}

async function bridgeFetch(path, options = {}) {
  const settings = await getSettings();
  if (!settings.token) {
    throw new Error("Missing Dacheng bridge token. Open extension options.");
  }
  return fetch(`${settings.bridgeUrl}${path}`, {
    ...options,
    headers: {
      "Authorization": `Bearer ${settings.token}`,
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });
}

async function heartbeat() {
  const settings = await getSettings();
  if (!settings.token) return;
  await bridgeFetch("/chrome/heartbeat", {
    method: "POST",
    body: JSON.stringify({
      connectorId: settings.connectorId,
      version: chrome.runtime.getManifest().version,
    }),
  });
}

async function pollCommands() {
  const settings = await getSettings();
  if (!settings.token) return;
  const response = await bridgeFetch(
    `/chrome/commands?connectorId=${encodeURIComponent(settings.connectorId)}`,
  );
  if (!response.ok) return;
  const payload = await response.json();
  for (const command of payload.commands || []) {
    await runCommand(command);
  }
}

async function runCommand(command) {
  try {
    const data = await handleCommand(command.tool, command.arguments || {});
    await postResult(command.id, { ok: true, data });
  } catch (error) {
    await postResult(command.id, {
      ok: false,
      errorCode: "chrome_command_failed",
      message: error && error.message ? error.message : String(error),
    });
  }
}

async function postResult(id, result) {
  await bridgeFetch("/chrome/results", {
    method: "POST",
    body: JSON.stringify({ id, ...result }),
  });
}

async function handleCommand(tool, args) {
  switch (tool) {
    case "chrome.tabs":
      return { tabs: (await chrome.tabs.query({})).map(sanitizeTab) };
    case "chrome.navigate": {
      const tab = await resolveTab(args);
      const url = String(args.url || "");
      if (!/^https?:\/\//i.test(url)) {
        throw new Error("Only http and https navigation is allowed.");
      }
      return { tab: sanitizeTab(await chrome.tabs.update(tab.id, { url })) };
    }
    case "chrome.screenshot": {
      const tab = await resolveTab(args);
      const dataUrl = await chrome.tabs.captureVisibleTab(tab.windowId, {
        format: args.format === "jpeg" ? "jpeg" : "png",
      });
      return { tab: sanitizeTab(tab), dataUrl };
    }
    case "chrome.dom_snapshot": {
      const tab = await resolveTab(args);
      const [result] = await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        func: collectDomSnapshot,
        args: [args],
      });
      return { tab: sanitizeTab(tab), snapshot: result.result };
    }
    case "chrome.click": {
      const tab = await resolveTab(args);
      const [result] = await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        func: clickElement,
        args: [args],
      });
      return { tab: sanitizeTab(tab), result: result.result };
    }
    case "chrome.type": {
      const tab = await resolveTab(args);
      const [result] = await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        func: typeIntoElement,
        args: [args],
      });
      return { tab: sanitizeTab(tab), result: result.result };
    }
    default:
      throw new Error(`Unknown command: ${tool}`);
  }
}

async function resolveTab(args) {
  if (Number.isInteger(args.tabId)) {
    return chrome.tabs.get(args.tabId);
  }
  const [active] = await chrome.tabs.query({
    active: true,
    currentWindow: true,
  });
  if (!active || !active.id) throw new Error("No active Chrome tab.");
  return active;
}

function sanitizeTab(tab) {
  return {
    id: tab.id,
    windowId: tab.windowId,
    active: tab.active,
    title: tab.title || "",
    url: tab.url || "",
    status: tab.status || "",
    audible: Boolean(tab.audible),
    pinned: Boolean(tab.pinned),
  };
}

function collectDomSnapshot(args) {
  const limit = Math.max(1, Math.min(Number(args.limit || 120), 500));
  const nodes = [];
  const walker = document.createTreeWalker(
    document.body || document.documentElement,
    NodeFilter.SHOW_ELEMENT,
  );
  while (walker.nextNode() && nodes.length < limit) {
    const element = walker.currentNode;
    const rect = element.getBoundingClientRect();
    const style = window.getComputedStyle(element);
    if (
      rect.width <= 0 ||
      rect.height <= 0 ||
      style.visibility === "hidden" ||
      style.display === "none"
    ) {
      continue;
    }
    const tag = element.tagName.toLowerCase();
    const type = (element.getAttribute("type") || "").toLowerCase();
    const text = type === "password" ? "" : visibleText(element);
    nodes.push({
      tag,
      role: element.getAttribute("role") || "",
      ariaLabel: element.getAttribute("aria-label") || "",
      placeholder: element.getAttribute("placeholder") || "",
      type,
      text,
      href: tag === "a" ? element.getAttribute("href") || "" : "",
      selector: cssPath(element),
      rect: {
        x: Math.round(rect.x),
        y: Math.round(rect.y),
        width: Math.round(rect.width),
        height: Math.round(rect.height),
      },
    });
  }
  return {
    title: document.title,
    url: location.href,
    nodes,
  };
}

function clickElement(args) {
  const element = findTarget(args);
  element.scrollIntoView({ block: "center", inline: "center" });
  element.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));
  return { clicked: true, selector: cssPath(element) };
}

function typeIntoElement(args) {
  const element = findTarget(args);
  const type = (element.getAttribute("type") || "").toLowerCase();
  if (type === "password") {
    throw new Error("Typing into password fields is not exposed.");
  }
  const text = String(args.text || "");
  element.focus();
  if ("value" in element) {
    element.value = text;
    element.dispatchEvent(new Event("input", { bubbles: true }));
    element.dispatchEvent(new Event("change", { bubbles: true }));
    return { typed: true, selector: cssPath(element), length: text.length };
  }
  document.execCommand("insertText", false, text);
  return { typed: true, selector: cssPath(element), length: text.length };
}

function findTarget(args) {
  if (args.selector) {
    const element = document.querySelector(String(args.selector));
    if (!element) throw new Error(`Selector not found: ${args.selector}`);
    return element;
  }
  if (Number.isFinite(args.x) && Number.isFinite(args.y)) {
    const element = document.elementFromPoint(Number(args.x), Number(args.y));
    if (!element) throw new Error("No element at requested point.");
    return element;
  }
  throw new Error("A selector or x/y point is required.");
}

function visibleText(element) {
  const raw = element.innerText || element.textContent || "";
  return raw.replace(/\s+/g, " ").trim().slice(0, 240);
}

function cssPath(element) {
  const parts = [];
  let current = element;
  while (current && current.nodeType === Node.ELEMENT_NODE && parts.length < 5) {
    let selector = current.tagName.toLowerCase();
    if (current.id) {
      selector += `#${CSS.escape(current.id)}`;
      parts.unshift(selector);
      break;
    }
    const cls = [...current.classList].slice(0, 2).map((name) => `.${CSS.escape(name)}`).join("");
    selector += cls;
    const parent = current.parentElement;
    if (parent) {
      const siblings = [...parent.children].filter((node) => node.tagName === current.tagName);
      if (siblings.length > 1) {
        selector += `:nth-of-type(${siblings.indexOf(current) + 1})`;
      }
    }
    parts.unshift(selector);
    current = parent;
  }
  return parts.join(" > ");
}

async function tick() {
  try {
    await heartbeat();
    await pollCommands();
  } catch (_) {
    // The desktop app may be closed; keep the connector quiet and retry later.
  }
}

chrome.runtime.onInstalled.addListener(() => {
  chrome.alarms.create("dacheng_tick", { periodInMinutes: 0.1 });
  tick();
});

chrome.runtime.onStartup.addListener(() => {
  chrome.alarms.create("dacheng_tick", { periodInMinutes: 0.1 });
  tick();
});

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "dacheng_tick") tick();
});

setInterval(tick, 3000);
tick();
