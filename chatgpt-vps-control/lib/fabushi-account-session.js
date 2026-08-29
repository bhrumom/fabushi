import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { normalizeFabushiApiBaseUrl, FabushiAccountAuthError } from "./fabushi-account-auth.js";

const REFRESH_EARLY_MS = 60_000;
const REQUEST_TIMEOUT_MS = 15_000;

function cleanSession(payload) {
  const accessToken = String(payload?.accessToken || "").trim();
  const refreshToken = String(payload?.refreshToken || "").trim();
  const deviceId = String(payload?.deviceId || "").trim();
  if (accessToken.length < 24 || refreshToken.length < 24 || !deviceId) {
    throw new FabushiAccountAuthError("invalid_account_session", "Fabushi account session is incomplete.");
  }
  return {
    accessToken,
    refreshToken,
    tokenType: String(payload?.tokenType || "Bearer"),
    accessTokenExpiresAt: Number(payload?.accessTokenExpiresAt || 0),
    refreshTokenExpiresAt: Number(payload?.refreshTokenExpiresAt || 0),
    sessionId: String(payload?.sessionId || ""),
    deviceId,
    username: String(payload?.username || payload?.user?.username || ""),
    userId: String(payload?.userId || payload?.user?.id || ""),
    user: payload?.user && typeof payload.user === "object" ? payload.user : null,
  };
}

async function decodeJson(response) {
  const text = await response.text();
  let payload = {};
  try { payload = text ? JSON.parse(text) : {}; } catch {}
  if (!response.ok) {
    const code = String(payload?.error?.code || payload?.code || `http_${response.status}`);
    const message = String(payload?.error?.message || payload?.message || "Fabushi account request failed.");
    throw new FabushiAccountAuthError(code, message, response.status);
  }
  return payload;
}

export function createFabushiAccountSessionStore(options = {}) {
  const sessionPath = resolve(String(options.sessionPath || process.env.FABUSHI_ACCOUNT_SESSION_FILE || ""));
  if (!sessionPath || sessionPath === resolve(".")) throw new Error("FABUSHI_ACCOUNT_SESSION_FILE is required.");
  const baseUrl = normalizeFabushiApiBaseUrl(options.baseUrl ?? process.env.FABUSHI_API_BASE_URL);
  const fetchImpl = options.fetchImpl ?? globalThis.fetch;
  const now = options.now ?? Date.now;
  const timeoutMs = Math.max(1_000, Math.min(Number(options.timeoutMs ?? REQUEST_TIMEOUT_MS), 60_000));

  async function request(path, body) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    timer.unref?.();
    try {
      const response = await fetchImpl(`${baseUrl}${path}`, {
        method: "POST",
        headers: { Accept: "application/json", "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
      return decodeJson(response);
    } catch (error) {
      if (error?.name === "AbortError") throw new FabushiAccountAuthError("account_request_timeout", "Fabushi account request timed out.");
      throw error;
    } finally {
      clearTimeout(timer);
    }
  }

  async function save(session) {
    const normalized = cleanSession(session);
    await mkdir(dirname(sessionPath), { recursive: true, mode: 0o700 });
    const temporary = `${sessionPath}.${process.pid}.${now()}.tmp`;
    await writeFile(temporary, `${JSON.stringify(normalized, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
    await rename(temporary, sessionPath);
    return normalized;
  }

  async function read() {
    let payload;
    try { payload = JSON.parse(await readFile(sessionPath, "utf8")); }
    catch { throw new FabushiAccountAuthError("account_session_missing", "Fabushi account session file is missing or invalid."); }
    return cleanSession(payload);
  }

  async function login({ username, password, deviceId }) {
    const normalizedUsername = String(username || "").trim();
    const normalizedPassword = String(password || "");
    const normalizedDeviceId = String(deviceId || "").trim();
    if (!normalizedUsername || !normalizedPassword || !normalizedDeviceId) {
      throw new FabushiAccountAuthError("invalid_login", "Fabushi CI login requires username, password, and device id.");
    }
    const response = await request("/api/auth/login", {
      username: normalizedUsername,
      password: normalizedPassword,
      deviceId: normalizedDeviceId,
    });
    return save(response);
  }

  async function refresh(session) {
    const current = cleanSession(session);
    if (current.refreshTokenExpiresAt && current.refreshTokenExpiresAt * 1000 <= now()) {
      throw new FabushiAccountAuthError("account_refresh_expired", "Fabushi account refresh session has expired.", 401);
    }
    const response = await request("/api/auth/refresh", {
      refreshToken: current.refreshToken,
      deviceId: current.deviceId,
    });
    return save({ ...current, ...response, deviceId: response.deviceId || current.deviceId });
  }

  async function accessToken() {
    let session = await read();
    const expiresAtMs = session.accessTokenExpiresAt ? session.accessTokenExpiresAt * 1000 : 0;
    if (!expiresAtMs || expiresAtMs <= now() + REFRESH_EARLY_MS) session = await refresh(session);
    return session.accessToken;
  }

  return { sessionPath, baseUrl, save, read, login, refresh, accessToken };
}
