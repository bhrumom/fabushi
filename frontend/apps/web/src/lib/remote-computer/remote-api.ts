const DEFAULT_API_BASE = "https://api.ombhrum.com";
const SESSION_KEY = "fabushi-remote-auth-v1";
const MOBILE_DEVICE_KEY = "fabushi-remote-mobile-device-v1";
const PAIRED_CLIENTS_KEY = "fabushi-remote-paired-clients-v1";

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
}

export interface PairingResult {
  deviceId: string;
  computerLabel: string;
  clientId: string;
  clientLabel: string;
  pairedAt: number;
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
  deviceId: string;
  clientId: string;
  computerLabel: string;
  clientLabel: string;
  pairedAt: number;
}

function browserStorage(): Storage | null {
  return typeof window === "undefined" ? null : window.sessionStorage;
}

function persistentStorage(): Storage | null {
  return typeof window === "undefined" ? null : window.localStorage;
}

function newId(prefix: string): string {
  const suffix = typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  return `${prefix}-${suffix}`;
}

function mobileDeviceId(): string {
  const storage = persistentStorage();
  const existing = storage?.getItem(MOBILE_DEVICE_KEY)?.trim();
  if (existing) return existing;
  const value = newId("fabushi-mobile");
  storage?.setItem(MOBILE_DEVICE_KEY, value);
  return value;
}

function loadPairedClients(): Record<string, PairedClientRecord> {
  const raw = persistentStorage()?.getItem(PAIRED_CLIENTS_KEY);
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw) as Record<string, PairedClientRecord>;
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

function savePairedClients(records: Record<string, PairedClientRecord>): void {
  persistentStorage()?.setItem(PAIRED_CLIENTS_KEY, JSON.stringify(records));
}

async function parseResponse<T>(response: Response): Promise<T> {
  const text = await response.text();
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

  constructor(baseUrl = process.env.NEXT_PUBLIC_AI_BACKEND_URL || process.env.NEXT_PUBLIC_FABUSHI_API_BASE_URL || DEFAULT_API_BASE) {
    this.baseUrl = baseUrl.replace(/\/+$/, "");
    const raw = browserStorage()?.getItem(SESSION_KEY);
    if (raw) {
      try { this.session = JSON.parse(raw) as RemoteAuthSession; } catch { this.session = null; }
    }
  }

  currentSession(): RemoteAuthSession | null {
    return this.session ? { ...this.session } : null;
  }

  pairedClients(): Record<string, PairedClientRecord> {
    return loadPairedClients();
  }

  async login(username: string, password: string): Promise<RemoteAuthSession> {
    const response = await fetch(`${this.baseUrl}/api/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ username: username.trim(), password, deviceId: mobileDeviceId() }),
    });
    const session = await parseResponse<RemoteAuthSession>(response);
    if (!session.accessToken || !session.refreshToken) throw new Error("登录响应缺少远程控制凭据");
    this.setSession(session);
    return session;
  }

  logout(): void {
    this.session = null;
    browserStorage()?.removeItem(SESSION_KEY);
  }

  async listComputers(): Promise<RemoteComputerInfo[]> {
    const response = await this.authorizedFetch("/v1/computers");
    const payload = await parseResponse<{ computers?: RemoteComputerInfo[] }>(response);
    return Array.isArray(payload.computers) ? payload.computers : [];
  }

  async pair(pairingCode: string, label: string): Promise<PairingResult> {
    const response = await this.authorizedFetch("/v1/computers/pair", {
      method: "POST",
      body: JSON.stringify({ pairingCode: pairingCode.trim().toUpperCase(), label: label.trim() || "我的手机" }),
    });
    const result = await parseResponse<PairingResult>(response);
    const records = loadPairedClients();
    records[result.deviceId] = {
      deviceId: result.deviceId,
      clientId: result.clientId,
      computerLabel: result.computerLabel,
      clientLabel: result.clientLabel,
      pairedAt: result.pairedAt,
    };
    savePairedClients(records);
    return result;
  }

  async createControlSession(deviceId: string, clientId: string): Promise<MobileControlSession> {
    const response = await this.authorizedFetch(`/v1/computers/${encodeURIComponent(deviceId)}/sessions`, {
      method: "POST",
      body: JSON.stringify({ clientId }),
    });
    const result = await parseResponse<MobileControlSession>(response);
    result.iceServers = Array.isArray(result.iceServers) ? result.iceServers : [];
    return result;
  }

  async signal(
    session: MobileControlSession,
    kind: RemoteSignal["kind"],
    payload: unknown,
  ): Promise<void> {
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
    const result = await parseResponse<SignalDrain>(response);
    result.signals = Array.isArray(result.signals) ? result.signals : [];
    return result;
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
    this.session = session;
    browserStorage()?.setItem(SESSION_KEY, JSON.stringify(session));
  }

  private async refresh(): Promise<void> {
    const current = this.session;
    if (!current?.refreshToken) throw new Error("登录已过期，请重新登录");
    const response = await fetch(`${this.baseUrl}/api/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ refreshToken: current.refreshToken, deviceId: current.deviceId }),
    });
    const refreshed = await parseResponse<RemoteAuthSession>(response);
    this.setSession(refreshed);
  }

  private async authorizedFetch(path: string, init: RequestInit = {}, retried = false): Promise<Response> {
    if (!this.session?.accessToken) throw new Error("请先登录大乘账号");
    const headers = new Headers(init.headers);
    headers.set("Accept", "application/json");
    headers.set("Authorization", `Bearer ${this.session.accessToken}`);
    if (init.body && !headers.has("Content-Type")) headers.set("Content-Type", "application/json");
    const response = await fetch(`${this.baseUrl}${path}`, { ...init, headers });
    if (response.status !== 401 || retried) return response;
    await this.refresh();
    return await this.authorizedFetch(path, init, true);
  }
}
