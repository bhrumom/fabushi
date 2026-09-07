const PORT_NAME = "fabushi-userscripts";
const STORAGE_KEYS = {
  consent: "fabushiUserscriptConsentV1",
  scripts: "fabushiUserscriptsV1",
};
const MAX_SCRIPT_BYTES = 256 * 1024;
const MAX_MATCHES = 32;
const ALLOWED_DECLARED_PERMISSIONS = new Set(["page-dom"]);
const ALLOWED_MATCH_PATTERNS = new Set(["https://chatgpt.com/*", "https://chat.openai.com/*"]);
const SCRIPT_ID_PATTERN = /^[a-z0-9][a-z0-9._-]{1,63}$/;
const SHA256_PATTERN = /^[a-f0-9]{64}$/;
let runtimeError = "";

function text(value, max = 200) {
  const normalized = String(value ?? "").trim();
  if (!normalized || normalized.length > max) throw new Error(`Invalid text value (max ${max}).`);
  return normalized;
}

function normalizeMatchPattern(value) {
  const pattern = text(value, 512);
  if (pattern === "<all_urls>" || pattern.startsWith("http://") || pattern.startsWith("file://")) {
    throw new Error("User scripts may run only on explicit HTTPS match patterns.");
  }
  const match = pattern.match(/^https:\/\/(\*\.)?([a-z0-9.-]+)(?::\d+)?\/(.*)$/i);
  if (!match || !match[2] || match[2] === "*" || match[2].includes("..")) {
    throw new Error(`Unsupported user-script match pattern: ${pattern}`);
  }
  if (!ALLOWED_MATCH_PATTERNS.has(pattern)) {
    throw new Error(`User-script match is outside this extension's approved host permissions: ${pattern}`);
  }
  return pattern;
}

function metadataDirectives(code) {
  const header = String(code).match(/\/\/\s*==UserScript==([\s\S]*?)\/\/\s*==\/UserScript==/i)?.[1] ?? "";
  const directives = new Map();
  for (const line of header.split(/\r?\n/)) {
    const match = line.match(/^\s*\/\/\s*@([a-zA-Z][\w-]*)\s*(.*?)\s*$/);
    if (!match) continue;
    const key = match[1].toLocaleLowerCase();
    const values = directives.get(key) ?? [];
    values.push(match[2]);
    directives.set(key, values);
  }
  return directives;
}

function rejectRemoteOrDynamicCode(code, directives) {
  for (const key of ["require", "resource", "downloadurl", "updateurl"]) {
    if (directives.has(key)) throw new Error(`@${key} is not allowed; Fabushi never loads remote script code at runtime.`);
  }
  if (directives.has("connect")) throw new Error("@connect is not supported by the minimal userscript sandbox.");
  for (const grant of directives.get("grant") ?? []) {
    if (grant && grant.toLocaleLowerCase() !== "none") throw new Error(`Unsupported @grant ${grant}; only @grant none is allowed.`);
  }
  const blocked = [
    [/(^|[^\w.])eval\s*\(/, "eval"],
    [/\bnew\s+Function\b|(^|[^\w.])Function\s*\(/, "Function constructor"],
    [/\bimport\s*\(/, "dynamic import"],
    [/\bWebAssembly\s*\.\s*(compile|instantiate)\s*\(/, "dynamic WebAssembly"],
  ];
  for (const [pattern, label] of blocked) {
    if (pattern.test(code)) throw new Error(`${label} is not allowed in Fabushi userscripts.`);
  }
}

async function sha256(code) {
  const bytes = new TextEncoder().encode(code);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((value) => value.toString(16).padStart(2, "0")).join("");
}

async function normalizeScript(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) throw new Error("User script payload must be an object.");
  const id = text(input.id, 64).toLocaleLowerCase();
  if (!SCRIPT_ID_PATTERN.test(id)) throw new Error("User script id is invalid.");
  const code = String(input.code ?? "");
  if (!code || new TextEncoder().encode(code).byteLength > MAX_SCRIPT_BYTES || code.includes("\0")) {
    throw new Error(`User script code must be between 1 and ${MAX_SCRIPT_BYTES} bytes and contain no NUL characters.`);
  }
  const directives = metadataDirectives(code);
  rejectRemoteOrDynamicCode(code, directives);
  const requestedMatches = Array.isArray(input.matches) ? input.matches : directives.get("match") ?? [];
  if (!requestedMatches.length || requestedMatches.length > MAX_MATCHES) throw new Error(`User script must declare 1-${MAX_MATCHES} HTTPS matches.`);
  const matches = [...new Set(requestedMatches.map(normalizeMatchPattern))];
  const metadataMatches = (directives.get("match") ?? []).map(normalizeMatchPattern);
  if (metadataMatches.some((pattern) => !matches.includes(pattern))) {
    throw new Error("Manifest matches must include every @match declared by the user script.");
  }
  const excludeMatches = [...new Set((Array.isArray(input.excludeMatches) ? input.excludeMatches : []).map(normalizeMatchPattern))];
  const permissions = [...new Set((Array.isArray(input.permissions) ? input.permissions : ["page-dom"])
    .map((value) => text(value, 64).toLocaleLowerCase()))];
  if (permissions.some((permission) => !ALLOWED_DECLARED_PERMISSIONS.has(permission))) {
    throw new Error(`Unsupported user-script permission. Allowed: ${[...ALLOWED_DECLARED_PERMISSIONS].join(", ")}.`);
  }
  const source = input.source && typeof input.source === "object" ? input.source : {};
  if (String(source.kind ?? "").toLocaleLowerCase() !== "marketplace") {
    throw new Error("User scripts must originate from the Fabushi Marketplace install flow.");
  }
  const sourceSha256 = text(source.sha256, 64).toLocaleLowerCase();
  if (!SHA256_PATTERN.test(sourceSha256)) throw new Error("Marketplace source sha256 is invalid.");
  const computedSha256 = await sha256(code);
  if (computedSha256 !== sourceSha256) throw new Error("User script source digest does not match the Marketplace release.");
  return {
    id,
    name: text(input.name ?? id, 120),
    version: text(input.version ?? source.version ?? "0", 64),
    code,
    matches,
    excludeMatches,
    permissions,
    runAt: ["document_start", "document_end", "document_idle"].includes(input.runAt) ? input.runAt : "document_idle",
    enabled: input.enabled === true,
    source: {
      kind: "marketplace",
      pluginId: text(source.pluginId, 64).toLocaleLowerCase(),
      version: text(source.version ?? input.version ?? "0", 64),
      sha256: sourceSha256,
    },
    installedAt: Number.isFinite(Number(input.installedAt)) ? Number(input.installedAt) : Date.now(),
    updatedAt: Number.isFinite(Number(input.updatedAt)) ? Number(input.updatedAt) : Date.now(),
  };
}

async function loadStore() {
  const stored = await chrome.storage.local.get([STORAGE_KEYS.consent, STORAGE_KEYS.scripts]);
  return {
    consent: stored[STORAGE_KEYS.consent] === true,
    scripts: Array.isArray(stored[STORAGE_KEYS.scripts]) ? stored[STORAGE_KEYS.scripts] : [],
  };
}

async function saveStore(store) {
  await chrome.storage.local.set({
    [STORAGE_KEYS.consent]: store.consent === true,
    [STORAGE_KEYS.scripts]: store.scripts,
  });
}

function registration(script) {
  return {
    id: `fabushi-${script.id}`,
    matches: script.matches,
    ...(script.excludeMatches.length ? { excludeMatches: script.excludeMatches } : {}),
    js: [{ code: script.code }],
    runAt: script.runAt,
    world: "USER_SCRIPT",
  };
}

async function ensureUserScriptsAvailable() {
  if (!chrome.userScripts?.getScripts || !chrome.userScripts?.register || !chrome.userScripts?.unregister) {
    throw new Error("Chrome userScripts API is unavailable. Enable Allow User Scripts in the extension details page.");
  }
  try {
    await chrome.userScripts.getScripts();
  } catch (error) {
    throw new Error(`Chrome userScripts API is disabled: ${error?.message || String(error)}`);
  }
}

async function clearRegistrations() {
  await ensureUserScriptsAvailable();
  await chrome.userScripts.unregister();
}

async function syncRegistrations() {
  runtimeError = "";
  try {
    const store = await loadStore();
    await ensureUserScriptsAvailable();
    await chrome.userScripts.configureWorld?.({ csp: "script-src 'self'; object-src 'none'", messaging: false });
    await chrome.userScripts.unregister();
    if (!store.consent) return { registered: 0, skipped: store.scripts.length };
    const valid = [];
    for (const raw of store.scripts) {
      const script = await normalizeScript(raw);
      if (script.enabled) valid.push(script);
    }
    if (valid.length) await chrome.userScripts.register(valid.map(registration));
    return { registered: valid.length, skipped: store.scripts.length - valid.length };
  } catch (error) {
    runtimeError = error?.message || String(error);
    try { await clearRegistrations(); } catch {}
    return { registered: 0, skipped: 0, error: runtimeError };
  }
}

function publicScript(script) {
  return {
    id: script.id,
    name: script.name,
    version: script.version,
    matches: script.matches,
    excludeMatches: script.excludeMatches,
    permissions: script.permissions,
    runAt: script.runAt,
    enabled: script.enabled === true,
    source: script.source,
    installedAt: script.installedAt,
    updatedAt: script.updatedAt,
  };
}

async function status() {
  const store = await loadStore();
  let available = true;
  try { await ensureUserScriptsAvailable(); } catch { available = false; }
  return {
    available,
    consent: store.consent,
    runtimeError,
    scripts: store.scripts.map(publicScript),
  };
}

async function handle(message) {
  const action = String(message?.action ?? "");
  if (action === "status") return status();
  if (action === "set-consent") {
    const consent = message.consent === true;
    if (consent && message.userConfirmed !== true) throw new Error("Explicit user confirmation is required before enabling user scripts.");
    const store = await loadStore();
    store.consent = consent;
    await saveStore(store);
    await syncRegistrations();
    return status();
  }
  if (action === "install") {
    const store = await loadStore();
    if (!store.consent || message.userConfirmed !== true) throw new Error("Enable user scripts and confirm this installation first.");
    const script = await normalizeScript({ ...message.script, enabled: false, installedAt: Date.now(), updatedAt: Date.now() });
    const index = store.scripts.findIndex((item) => item.id === script.id);
    if (index >= 0) store.scripts[index] = { ...script, installedAt: store.scripts[index].installedAt || script.installedAt };
    else store.scripts.push(script);
    await saveStore(store);
    await syncRegistrations();
    return { installed: publicScript(script), defaultEnabled: false };
  }
  if (action === "set-enabled") {
    const store = await loadStore();
    const id = text(message.id, 64).toLocaleLowerCase();
    const script = store.scripts.find((item) => item.id === id);
    if (!script) throw new Error(`User script ${id} is not installed.`);
    const enabled = message.enabled === true;
    if (enabled && (!store.consent || message.userConfirmed !== true)) {
      throw new Error("Explicit user confirmation is required before enabling this user script.");
    }
    script.enabled = enabled;
    script.updatedAt = Date.now();
    await saveStore(store);
    await syncRegistrations();
    return status();
  }
  if (action === "uninstall") {
    if (message.userConfirmed !== true) throw new Error("Explicit user confirmation is required before uninstalling a user script.");
    const store = await loadStore();
    const id = text(message.id, 64).toLocaleLowerCase();
    const before = store.scripts.length;
    store.scripts = store.scripts.filter((item) => item.id !== id);
    await saveStore(store);
    await syncRegistrations();
    return { removed: store.scripts.length !== before, ...(await status()) };
  }
  throw new Error(`Unsupported userscript action: ${action}`);
}

chrome.runtime.onConnect.addListener((port) => {
  if (port.name !== PORT_NAME) return;
  port.onMessage.addListener((message) => {
    Promise.resolve(handle(message))
      .then((result) => port.postMessage({ requestId: message?.requestId, ok: true, result }))
      .catch((error) => port.postMessage({ requestId: message?.requestId, ok: false, error: error?.message || String(error) }));
  });
});

void syncRegistrations();

export {
  ALLOWED_DECLARED_PERMISSIONS,
  ALLOWED_MATCH_PATTERNS,
  metadataDirectives,
  normalizeMatchPattern,
  normalizeScript,
  rejectRemoteOrDynamicCode,
};
