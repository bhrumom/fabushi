import type { RemoteComputerCapability, RemoteComputerPlatform, RemoteComputerProvider } from "../mahayana-host/contracts";

const DEFAULT_API_BASE = "https://api.ombhrum.com";
const SESSION_KEY = "fabushi-remote-auth-v1";
const MOBILE_DEVICE_KEY = "fabushi-remote-mobile-device-v1";
const LEGACY_PAIRED_CLIENTS_KEY = "fabushi-remote-paired-clients-v1";
const PAIRED_CLIENTS_KEY_PREFIX = "fabushi-remote-paired-clients-v2";

export interface RemoteAuthSession {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresAt: number;
  refreshTokenExpiresAt: number;
  sessionId: string;
  deviceId: string;
  username: string;
  userId: string | number;
}

export interface RemoteComputerInfo {
  deviceId: string;
  label: string;
  lastSeenAt: number;
  createdAt: number;
  online: boolean;
  provider: RemoteComputerProvider;
  platform: RemoteComputerPlatform;
  appVersion: string;
  capabilities: RemoteComputerCapability[];
  activeSessionCount: number;
}

export interface PairingResult {
  deviceId: string;
  computerLabel: string;
  clientId: string;
  clientToken: string;
  clientLabel: string;
  pairedAt: number;
}

export interface RemoteControlPermissions {
  display: boolean;
  input: boolean;
  clipboard: boolean;
  fileTransfer: boolean;
  audio: boolean;
}

export interface MobileControlSession {
  sessionId: string;
  deviceId: string;
  clientId: string;
  mobileToken: string;
  createdAt: number;
  expiresAt: number;
  state: "pending" | "active" | "closed";
  iceServers: RTCIceServer[];
  permissions: RemoteControlPermissions;
}

export interface RemoteSignal {
  signalId: number;
  senderRole: "desktop" | "mobile";
  kind: "offer" | "answer" | "ice" | "ready" | "close";
  payload: unknown;
  createdAt: number;
}

export interface SignalDrain {
  sessionId: string;
  signals: RemoteSignal[];
  lastSignalId: number;
}

export interface PairedClientRecord {
  accountId: string;
  deviceId: string;
  clientId: string;
  clientToken: string;
  computerLabel: string;
  clientLabel: string;
  pairedAt: number;
}

const MAX_RESPONSE_CHARS = 2 * 1024 * 1024;
const MAX_AUTH_TOKEN_CHARS = 16 * 1024;
const ALLOWED_ICE_SCHEMES = new Set(["stun:", "turn:", "turns:"]);
const MOBILE_SIGNAL_KINDS = new Set<RemoteSignal["kind"]>(["offer", "ice", "ready", "close"]);
const DESKTOP_SIGNAL_KINDS = new Set<RemoteSignal["kind"]>(["answer", "ice", "ready", "close"]);
const REMOTE_COMPUTER_PROVIDERS = new Set<RemoteComputerProvider>(["fabushi-webrtc", "rustdesk-sidecar"]);
const REMOTE_COMPUTER_PLATFORMS = new Set<RemoteComputerPlatform>([
  "windows", "macos", "linux", "android", "ios", "web", "unknown",
]);
const REMOTE_COMPUTER_CAPABILITIES = new Set<RemoteComputerCapability>([
  "remote-desktop", "input", "clipboard", "file-transfer", "display", "audio", "session-management",
]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function browserStorage(): Storage | null {
  if (typeof window === "undefined") return null;
  try { return window.sessionStorage; } catch { return null; }
}

function persistentStorage(): Storage | null {
  if (typeof window === "undefined") return null;
  try { return window.localStorage; } catch { return null; }
}

function newId(prefix: string): string {
  const suffix = typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  return `${prefix}-${suffix}`;
}

function mobileDeviceId(): string {
  const storage = persistentStorage();
  let existing: string | null = null;
  try { existing = storage?.getItem(MOBILE_DEVICE_KEY)?.trim() ?? null; } catch { /* storage may be blocked */ }
  if (validStoredIdentifier(existing, 160)) return existing;
  const value = newId("fabushi-mobile");
  try { storage?.setItem(MOBILE_DEVICE_KEY, value); } catch { /* private browsing may deny persistence */ }
  return value;
}

function validOpaqueCredential(value: unknown): value is string {
  return typeof value === "string" && value.length >= 48 && value.length <= 256 && /^[A-Za-z0-9_-]+$/.test(value);
}

function validStoredIdentifier(value: unknown, maxLength = 160): value is string {
  return typeof value === "string" && value.length > 0 && value.length <= maxLength && /^[A-Za-z0-9._:-]+$/.test(value);
}

function validDisplayText(value: unknown, maxLength = 320): value is string {
  return typeof value === "string" && value.trim().length > 0 && value.length <= maxLength && !/[\u0000-\u001F\u007F]/.test(value);
}

function validAuthToken(value: unknown): value is string {
  return typeof value === "string"
    && value.length >= 16
    && value.length <= MAX_AUTH_TOKEN_CHARS
    && !/[\u0000-\u0020\u007F]/.test(value);
}

function validTimestamp(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value >= 0;
}

function remoteComputerProvider(value: unknown): RemoteComputerProvider {
  return typeof value === "string" && REMOTE_COMPUTER_PROVIDERS.has(value as RemoteComputerProvider)
    ? value as RemoteComputerProvider
    : "fabushi-webrtc";
}

function remoteComputerPlatform(value: unknown): RemoteComputerPlatform {
  return typeof value === "string" && REMOTE_COMPUTER_PLATFORMS.has(value as RemoteComputerPlatform)
    ? value as RemoteComputerPlatform
    : "unknown";
}

function remoteComputerVersion(value: unknown): string {
  return typeof value === "string" && /^[A-Za-z0-9.+_-]{1,64}$/.test(value) ? value : "unknown";
}

function remoteComputerCapabilities(value: unknown): RemoteComputerCapability[] {
  if (!Array.isArray(value)) return [];
  const normalized: RemoteComputerCapability[] = [];
  for (const candidate of value.slice(0, 32)) {
    if (typeof candidate !== "string"
      || !REMOTE_COMPUTER_CAPABILITIES.has(candidate as RemoteComputerCapability)
      || normalized.includes(candidate as RemoteComputerCapability)) continue;
    normalized.push(candidate as RemoteComputerCapability);
  }
  return normalized;
}

function activeSessionCount(value: unknown): number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 32 ? value : 0;
}

function accountIdentity(userId: string | number): string {
  return `${typeof userId}:${String(userId)}`;
}

function accountStorageScope(userId: string | number): string {
  const value = accountIdentity(userId);
  let left = 0x811c9dc5;
  let right = 0x9e3779b9;
  for (const character of value) {
    const code = character.codePointAt(0) ?? 0;
    left = Math.imul(left ^ code, 0x01000193);
    right = Math.imul(right ^ (code + 0x9e3779b9), 0x85ebca6b);
  }
  return `${(left >>> 0).toString(16).padStart(8, "0")}${(right >>> 0).toString(16).padStart(8, "0")}`;
}

function pairedClientsStorageKey(userId: string | number): string {
  return `${PAIRED_CLIENTS_KEY_PREFIX}:${accountStorageScope(userId)}`;
}

function normalizeAuthSession(value: unknown): RemoteAuthSession | null {
  if (!isRecord(value)
    || !validAuthToken(value.accessToken)
    || !validAuthToken(value.refreshToken)
    || !validTimestamp(value.accessTokenExpiresAt)
    || !validTimestamp(value.refreshTokenExpiresAt)
    || !validStoredIdentifier(value.sessionId, 200)
    || !validStoredIdentifier(value.deviceId, 200)
    || !validDisplayText(value.username, 320)
    || !((typeof value.userId === "string" && value.userId.length > 0 && value.userId.length <= 200)
      || (typeof value.userId === "number" && Number.isFinite(value.userId)))) return null;
  return {
    accessToken: value.accessToken,
    refreshToken: value.refreshToken,
    accessTokenExpiresAt: value.accessTokenExpiresAt,
    refreshTokenExpiresAt: value.refreshTokenExpiresAt,
    sessionId: value.sessionId,
    deviceId: value.deviceId,
    username: value.username,
    userId: value.userId,
  };
}

function normalizeApiBase(value: string): string {
  const candidate = value.trim().replace(/\/+$/, "");
  let url: URL;
  try { url = new URL(candidate); } catch { throw new Error("远程控制 API 地址无效"); }
  const loopback = ["localhost", "127.0.0.1", "::1", "[::1]"].includes(url.hostname);
  if (url.protocol !== "https:" && !(loopback && url.protocol === "http:")) {
    throw new Error("远程控制 API 必须使用 HTTPS");
  }
  if (url.username || url.password || url.search || url.hash) throw new Error("远程控制 API 地址不能包含凭据、查询参数或片段");
  return url.toString().replace(/\/+$/, "");
}

function normalizeRemoteControlPermissions(value: unknown): RemoteControlPermissions | null {
  if (!isRecord(value)) return null;
  const names = ["display", "input", "clipboard", "fileTransfer", "audio"] as const;
  if (names.some((name) => typeof value[name] !== "boolean")) return null;
  return {
    display: value.display as boolean,
    input: value.input as boolean,
    clipboard: value.clipboard as boolean,
    fileTransfer: value.fileTransfer as boolean,
    audio: value.audio as boolean,
  };
}

function normalizeIceServers(value: unknown): RTCIceServer[] {
  if (!Array.isArray(value)) return [];
  const result: RTCIceServer[] = [];
  for (const candidate of value.slice(0, 16)) {
    if (!isRecord(candidate)) continue;
    const rawUrls = Array.isArray(candidate.urls) ? candidate.urls : [candidate.urls];
    const urls = rawUrls.filter((item): item is string => {
      if (typeof item !== "string" || item.length < 6 || item.length > 2048) return false;
      try { return ALLOWED_ICE_SCHEMES.has(new URL(item).protocol); } catch { return false; }
    });
    if (!urls.length) continue;
    const server: RTCIceServer = { urls: urls.length === 1 ? urls[0] : urls };
    if (typeof candidate.username === "string" && candidate.username.length <= 1024) server.username = candidate.username;
    if (typeof candidate.credential === "string" && candidate.credential.length <= 4096) server.credential = candidate.credential;
    result.push(server);
  }
  return result;
}

function loadPairedClients(userId: string | number): Record<string, PairedClientRecord> {
  const expectedAccountId = accountIdentity(userId);
  try {
    const raw = persistentStorage()?.getItem(pairedClientsStorageKey(userId));
    if (!raw) return {};
    const parsed: unknown = JSON.parse(raw);
    if (!isRecord(parsed)) return {};
    const records: Record<string, PairedClientRecord> = Object.create(null) as Record<string, PairedClientRecord>;
    for (const [deviceId, candidate] of Object.entries(parsed)) {
      if (!isRecord(candidate)) continue;
      if (!validStoredIdentifier(deviceId, 128)
        || candidate.accountId !== expectedAccountId
        || candidate.deviceId !== deviceId
        || !validStoredIdentifier(candidate.clientId)
        || !validOpaqueCredential(candidate.clientToken)
        || !validDisplayText(candidate.computerLabel, 80)
        || !validDisplayText(candidate.clientLabel, 80)
        || !validTimestamp(candidate.pairedAt)) continue;
      records[deviceId] = {
        accountId: expectedAccountId,
        deviceId,
        clientId: candidate.clientId,
        clientToken: candidate.clientToken,
        computerLabel: candidate.computerLabel,
        clientLabel: candidate.clientLabel,
        pairedAt: candidate.pairedAt,
      };
    }
    return records;
  } catch {
    return {};
  }
}

function assertPairedClientStorageAvailable(userId: string | number): void {
  const storage = persistentStorage();
  if (!storage) throw new Error("当前浏览器无法保存配对凭据");
  const probe = `${pairedClientsStorageKey(userId)}:probe`;
  try {
    storage.setItem(probe, "1");
    storage.removeItem(probe);
  } catch {
    throw new Error("无法安全保存配对凭据，请检查浏览器存储权限");
  }
}

function savePairedClients(userId: string | number, records: Record<string, PairedClientRecord>): void {
  const storage = persistentStorage();
  if (!storage) throw new Error("当前浏览器无法保存配对凭据");
  const expectedAccountId = accountIdentity(userId);
  if (Object.values(records).some((record) => record.accountId !== expectedAccountId)) {
    throw new Error("配对凭据与当前登录账号不匹配");
  }
  try { storage.setItem(pairedClientsStorageKey(userId), JSON.stringify(records)); }
  catch { throw new Error("无法安全保存配对凭据，请检查浏览器存储权限"); }
}

async function parseResponse<T>(response: Response): Promise<T> {
  const advertisedLength = Number(response.headers.get("content-length") || 0);
  if (Number.isFinite(advertisedLength) && advertisedLength > MAX_RESPONSE_CHARS) {
    throw new Error("远程控制服务响应过大");
  }
  const text = await response.text();
  if (text.length > MAX_RESPONSE_CHARS) throw new Error("远程控制服务响应过大");
  let value: unknown = {};
  if (text) {
    try { value = JSON.parse(text); } catch { value = { message: text }; }
  }
  if (!response.ok) {
    const object = value && typeof value === "object" ? value as Record<string, unknown> : {};
    throw new Error(String(object.message ?? object.error ?? `HTTP ${response.status}`));
  }
  return value as T;
}

export class RemoteComputerApi {
  readonly baseUrl: string;
  private session: RemoteAuthSession | null = null;
  private refreshPromise: Promise<void> | null = null;

  constructor(baseUrl = process.env.NEXT_PUBLIC_AI_BACKEND_URL || process.env.NEXT_PUBLIC_FABUSHI_API_BASE_URL || DEFAULT_API_BASE) {
    this.baseUrl = normalizeApiBase(baseUrl);
    const storage = browserStorage();
    try {
      const raw = storage?.getItem(SESSION_KEY);
      if (raw) this.session = normalizeAuthSession(JSON.parse(raw));
      if (raw && !this.session) storage?.removeItem(SESSION_KEY);
      // v1 stored credentials without an account namespace. The server-side
      // client-token migration revoked those records, so discard rather than
      // risk exposing them to a different account in the same browser profile.
      try { persistentStorage()?.removeItem(LEGACY_PAIRED_CLIENTS_KEY); } catch { /* best effort */ }
    } catch {
      this.session = null;
    }
  }

  currentSession(): RemoteAuthSession | null {
    return this.session ? { ...this.session } : null;
  }

  pairedClients(): Record<string, PairedClientRecord> {
    const userId = this.session?.userId;
    return userId === undefined || userId === null ? {} : loadPairedClients(userId);
  }

  async login(username: string, password: string): Promise<RemoteAuthSession> {
    const normalizedUsername = username.trim();
    if (!validDisplayText(normalizedUsername, 320) || password.length < 1 || password.length > 4096) {
      throw new Error("账号或密码格式无效");
    }
    const response = await fetch(`${this.baseUrl}/api/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ username: normalizedUsername, password, deviceId: mobileDeviceId() }),
      cache: "no-store",
      credentials: "omit",
      redirect: "error",
      referrerPolicy: "no-referrer",
    });
    const session = normalizeAuthSession(await parseResponse<unknown>(response));
    if (!session) throw new Error("登录响应缺少有效的远程控制凭据");
    this.setSession(session);
    return session;
  }

  logout(): void {
    this.session = null;
    try { browserStorage()?.removeItem(SESSION_KEY); } catch { /* session is cleared in memory */ }
  }

  async listComputers(): Promise<RemoteComputerInfo[]> {
    const response = await this.authorizedFetch("/v1/computers");
    const payload = await parseResponse<unknown>(response);
    if (!isRecord(payload) || !Array.isArray(payload.computers)) return [];
    return payload.computers.slice(0, 256).flatMap((candidate): RemoteComputerInfo[] => {
      if (!isRecord(candidate)
        || !validStoredIdentifier(candidate.deviceId, 128)
        || !validDisplayText(candidate.label, 80)
        || !validTimestamp(candidate.lastSeenAt)
        || !validTimestamp(candidate.createdAt)
        || typeof candidate.online !== "boolean") return [];
      return [{
        deviceId: candidate.deviceId,
        label: candidate.label,
        lastSeenAt: candidate.lastSeenAt,
        createdAt: candidate.createdAt,
        online: candidate.online,
        provider: remoteComputerProvider(candidate.provider),
        platform: remoteComputerPlatform(candidate.platform),
        appVersion: remoteComputerVersion(candidate.appVersion),
        capabilities: remoteComputerCapabilities(candidate.capabilities),
        activeSessionCount: activeSessionCount(candidate.activeSessionCount),
      }];
    });
  }

  async pair(pairingCode: string, label: string): Promise<PairingResult> {
    const normalizedCode = pairingCode.trim().toUpperCase();
    const normalizedLabel = label.trim() || "我的手机";
    if (!/^[0-9A-F]{12}$/.test(normalizedCode) || !validDisplayText(normalizedLabel, 80)) {
      throw new Error("请输入电脑资料栏显示的 12 位配对码和有效设备名称");
    }
    const userId = this.session?.userId;
    if (userId === undefined || userId === null) throw new Error("请先登录大乘账号");
    assertPairedClientStorageAvailable(userId);
    const response = await this.authorizedFetch("/v1/computers/pair", {
      method: "POST",
      body: JSON.stringify({ pairingCode: normalizedCode, label: normalizedLabel }),
    });
    const raw = await parseResponse<unknown>(response);
    if (!isRecord(raw)
      || !validStoredIdentifier(raw.deviceId, 128)
      || !validStoredIdentifier(raw.clientId)
      || !validOpaqueCredential(raw.clientToken)
      || !validDisplayText(raw.computerLabel, 80)
      || !validDisplayText(raw.clientLabel, 80)
      || !validTimestamp(raw.pairedAt)) {
      throw new Error("配对响应缺少设备绑定凭据，请更新服务端后重新配对");
    }
    const result: PairingResult = {
      deviceId: raw.deviceId,
      computerLabel: raw.computerLabel,
      clientId: raw.clientId,
      clientToken: raw.clientToken,
      clientLabel: raw.clientLabel,
      pairedAt: raw.pairedAt,
    };
    if (!this.session || accountIdentity(this.session.userId) !== accountIdentity(userId)) {
      throw new Error("登录账号已变化，请在当前账号下重新配对");
    }
    const records = loadPairedClients(userId);
    records[result.deviceId] = {
      accountId: accountIdentity(userId),
      deviceId: result.deviceId,
      clientId: result.clientId,
      clientToken: result.clientToken,
      computerLabel: result.computerLabel,
      clientLabel: result.clientLabel,
      pairedAt: result.pairedAt,
    };
    try {
      savePairedClients(userId, records);
    } catch (cause) {
      // A one-time pairing code has already been consumed. Revoke the newly
      // created client if durable storage unexpectedly fails after the probe,
      // so no inaccessible authorization is left behind on the computer.
      try {
        const revoke = await this.authorizedFetch(
          `/v1/computers/${encodeURIComponent(result.deviceId)}/clients/${encodeURIComponent(result.clientId)}/revoke`,
          { method: "POST", body: "{}" },
        );
        await parseResponse(revoke);
      } catch { /* the desktop can still revoke the orphaned client */ }
      throw cause;
    }
    return result;
  }

  async createControlSession(
    deviceId: string,
    clientId: string,
    clientToken: string,
    permissions: RemoteControlPermissions = { display: true, input: true, clipboard: false, fileTransfer: false, audio: false },
  ): Promise<MobileControlSession> {
    if (!validStoredIdentifier(deviceId, 128)
      || !validStoredIdentifier(clientId)
      || !validOpaqueCredential(clientToken)) {
      throw new Error("本手机的配对凭据无效，请重新配对");
    }
    if (!permissions || permissions.display !== true
      || [permissions.input, permissions.clipboard, permissions.fileTransfer, permissions.audio].some((value) => typeof value !== "boolean")) {
      throw new Error("远程控制权限请求无效");
    }
    const response = await this.authorizedFetch(`/v1/computers/${encodeURIComponent(deviceId)}/sessions`, {
      method: "POST",
      body: JSON.stringify({ clientId, clientToken, permissions }),
    });
    const raw = await parseResponse<unknown>(response);
    if (!isRecord(raw)
      || raw.deviceId !== deviceId
      || raw.clientId !== clientId
      || !validStoredIdentifier(raw.sessionId)
      || !validOpaqueCredential(raw.mobileToken)
      || raw.state !== "pending"
      || !validTimestamp(raw.createdAt)
      || !validTimestamp(raw.expiresAt)
      || raw.expiresAt <= raw.createdAt
      || !normalizeRemoteControlPermissions(raw.permissions)) {
      throw new Error("远程控制会话响应与已配对设备不匹配");
    }
    return {
      sessionId: raw.sessionId,
      deviceId,
      clientId,
      mobileToken: raw.mobileToken,
      createdAt: raw.createdAt,
      expiresAt: raw.expiresAt,
      state: "pending",
      permissions: normalizeRemoteControlPermissions(raw.permissions)!,
      iceServers: normalizeIceServers(raw.iceServers),
    };
  }

  async signal(
    session: MobileControlSession,
    kind: RemoteSignal["kind"],
    payload: unknown,
  ): Promise<void> {
    if (!MOBILE_SIGNAL_KINDS.has(kind)) throw new Error("手机端不能发送此类远程控制信令");
    const response = await this.authorizedFetch(`/v1/computers/${encodeURIComponent(session.deviceId)}/signals`, {
      method: "POST",
      body: JSON.stringify({
        sessionId: session.sessionId,
        senderRole: "mobile",
        clientId: session.clientId,
        mobileToken: session.mobileToken,
        kind,
        payload,
      }),
    });
    await parseResponse(response);
  }

  async drainSignals(session: MobileControlSession, afterSignalId: number): Promise<SignalDrain> {
    const response = await this.authorizedFetch(`/v1/computers/${encodeURIComponent(session.deviceId)}/signals/drain`, {
      method: "POST",
      body: JSON.stringify({
        sessionId: session.sessionId,
        receiverRole: "mobile",
        clientId: session.clientId,
        mobileToken: session.mobileToken,
        afterSignalId: Math.max(0, afterSignalId),
      }),
    });
    const raw = await parseResponse<unknown>(response);
    if (!isRecord(raw)
      || raw.sessionId !== session.sessionId
      || typeof raw.lastSignalId !== "number"
      || !Number.isSafeInteger(raw.lastSignalId)
      || raw.lastSignalId < 0) {
      throw new Error("远程控制信令响应与当前会话不匹配");
    }
    const signals = Array.isArray(raw.signals) ? raw.signals.slice(0, 128).flatMap((candidate): RemoteSignal[] => {
      if (!isRecord(candidate)
        || typeof candidate.signalId !== "number"
        || !Number.isSafeInteger(candidate.signalId)
        || candidate.signalId <= afterSignalId
        || candidate.senderRole !== "desktop"
        || typeof candidate.kind !== "string"
        || !DESKTOP_SIGNAL_KINDS.has(candidate.kind as RemoteSignal["kind"])
        || !validTimestamp(candidate.createdAt)) return [];
      return [{
        signalId: candidate.signalId,
        senderRole: "desktop",
        kind: candidate.kind as RemoteSignal["kind"],
        payload: candidate.payload,
        createdAt: candidate.createdAt,
      }];
    }) : [];
    return { sessionId: raw.sessionId, lastSignalId: raw.lastSignalId, signals };
  }

  async closeSession(session: MobileControlSession): Promise<void> {
    const response = await this.authorizedFetch(
      `/v1/computers/${encodeURIComponent(session.deviceId)}/sessions/${encodeURIComponent(session.sessionId)}/close`,
      {
        method: "POST",
        body: JSON.stringify({
          role: "mobile",
          clientId: session.clientId,
          mobileToken: session.mobileToken,
        }),
      },
    );
    await parseResponse(response);
  }

  private setSession(session: RemoteAuthSession): void {
    const normalized = normalizeAuthSession(session);
    if (!normalized) throw new Error("远程控制登录凭据无效");
    this.session = normalized;
    try { browserStorage()?.setItem(SESSION_KEY, JSON.stringify(normalized)); }
    catch { /* session remains usable for this page lifetime */ }
  }

  private async refresh(): Promise<void> {
    if (!this.refreshPromise) {
      this.refreshPromise = this.performRefresh().finally(() => { this.refreshPromise = null; });
    }
    return await this.refreshPromise;
  }

  private async performRefresh(): Promise<void> {
    const current = this.session;
    if (!current?.refreshToken) throw new Error("登录已过期，请重新登录");
    try {
      const response = await fetch(`${this.baseUrl}/api/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({ refreshToken: current.refreshToken, deviceId: current.deviceId }),
        cache: "no-store",
        credentials: "omit",
        redirect: "error",
        referrerPolicy: "no-referrer",
      });
      const refreshed = normalizeAuthSession(await parseResponse<unknown>(response));
      if (!refreshed
        || refreshed.deviceId !== current.deviceId
        || accountIdentity(refreshed.userId) !== accountIdentity(current.userId)) {
        throw new Error("刷新后的登录凭据无效或账号已变化");
      }
      this.setSession(refreshed);
    } catch (cause) {
      this.logout();
      throw cause;
    }
  }

  private async authorizedFetch(path: string, init: RequestInit = {}, retried = false): Promise<Response> {
    if (!path.startsWith("/") || path.startsWith("//")) throw new Error("远程控制 API 路径无效");
    if (!this.session?.accessToken) throw new Error("请先登录大乘账号");
    const headers = new Headers(init.headers);
    headers.set("Accept", "application/json");
    headers.set("Authorization", `Bearer ${this.session.accessToken}`);
    if (init.body && !headers.has("Content-Type")) headers.set("Content-Type", "application/json");
    const response = await fetch(`${this.baseUrl}${path}`, {
      ...init,
      headers,
      cache: "no-store",
      credentials: "omit",
      redirect: "error",
      referrerPolicy: "no-referrer",
    });
    if (response.status !== 401 || retried) return response;
    await this.refresh();
    return await this.authorizedFetch(path, init, true);
  }
}
