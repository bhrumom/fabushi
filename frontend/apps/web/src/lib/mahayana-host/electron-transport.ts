import type {
  ApprovalResolution,
  AuthProvider,
  AuthProviderId,
  AuthState,
  BrowserLoginAttempt,
  BrowserLoginPollResult,
  BrowserLoginReopenResult,
  CommandAccepted,
  HostConfig,
  HostInfo,
  OAuthAttempt,
  OAuthPollResult,
  RuntimeCommand,
  RuntimeEvent,
} from "./contracts";
import type {
  MahayanaHostTransport,
  RuntimeEventListener,
} from "./transport";

type ElectronBridge = {
  invoke<T>(method: string, params?: Record<string, unknown>): Promise<T>;
  subscribe?(listener: RuntimeEventListener): () => void;
  notify(title: string, body: string): Promise<boolean | void>;
  openExternal(url: string): Promise<boolean | void>;
  openSystemSettings(pane: "screen-recording" | "accessibility"): Promise<boolean | void>;
  windowFocused(): Promise<boolean>;
};

declare global {
  interface Window {
    fabushi: ElectronBridge;
    mahayana?: Pick<ElectronBridge, "invoke" | "subscribe">;
  }
}

const idle = (milliseconds = 10) =>
  new Promise<void>((resolve) => setTimeout(resolve, milliseconds));

export function isElectronMahayanaHostAvailable(): boolean {
  return (
    typeof window !== "undefined" &&
    typeof window.fabushi?.invoke === "function"
  );
}

function bridge(): ElectronBridge {
  if (typeof window === "undefined" || typeof window.fabushi?.invoke !== "function") {
    throw new Error("Electron Mahayana Host is not available");
  }
  return window.fabushi;
}

export class ElectronMahayanaHostTransport implements MahayanaHostTransport {
  private readonly listeners = new Set<RuntimeEventListener>();
  private closed = false;
  private pumping = false;
  private unsubscribeBridge: (() => void) | null = null;

  subscribe(listener: RuntimeEventListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  async initialize(_config: HostConfig): Promise<HostInfo> {
    const info = await bridge().invoke<HostInfo>("feature.info");
    this.closed = false;
    this.attachRuntimeEvents();
    // The main process owns the long-lived event pump and may observe the
    // one-shot host.ready event before the renderer subscribes. A successful
    // feature.info handshake proves the Host is ready, so replay that state
    // locally after the push subscription is attached. A later native
    // host.ready event is harmless because readiness updates are idempotent.
    this.dispatchEvent({
      type: "host.ready",
      timestamp: new Date().toISOString(),
      info,
    });
    return info;
  }

  execute(command: RuntimeCommand): Promise<CommandAccepted> {
    return bridge().invoke<CommandAccepted>("feature.execute", { command });
  }

  authStatus(): Promise<AuthState> {
    return bridge().invoke<AuthState>("feature.auth.status");
  }

  authProviders(): Promise<AuthProvider[]> {
    return bridge().invoke<AuthProvider[]>("feature.auth.providers");
  }

  browserLoginStart(): Promise<BrowserLoginAttempt> {
    return bridge().invoke<BrowserLoginAttempt>("feature.auth.browserStart");
  }

  browserLoginPoll(attemptId: string): Promise<BrowserLoginPollResult> {
    return bridge().invoke<BrowserLoginPollResult>("feature.auth.browserPoll", { attemptId });
  }

  browserLoginCancel(attemptId: string): Promise<BrowserLoginPollResult> {
    return bridge().invoke<BrowserLoginPollResult>("feature.auth.browserCancel", { attemptId });
  }

  browserLoginReopen(attemptId: string): Promise<BrowserLoginReopenResult> {
    return bridge().invoke<BrowserLoginReopenResult>("feature.auth.browserReopen", { attemptId });
  }

  passwordLogin(username: string, password: string): Promise<AuthState> {
    return bridge().invoke<AuthState>("feature.auth.passwordLogin", { username, password });
  }

  oauthStart(provider: AuthProviderId): Promise<OAuthAttempt> {
    return bridge().invoke<OAuthAttempt>("feature.auth.oauthStart", { provider });
  }

  oauthPoll(attemptId: string): Promise<OAuthPollResult> {
    return bridge().invoke<OAuthPollResult>("feature.auth.oauthPoll", { attemptId });
  }

  logout(): Promise<AuthState> {
    return bridge().invoke<AuthState>("feature.auth.logout");
  }

  openExternal(url: string): Promise<void> {
    // The deterministic Rust FeatureHost test backend returns this inert URL
    // for OAuth. Keep the full Electron -> IPC -> Rust login path in E2E
    // without asking the runner OS to launch a browser. Production OAuth URLs
    // still pass through the hardened Electron external-navigation bridge.
    if (
      url.startsWith("about:blank#fabushi-test-oauth-") ||
      url.startsWith("about:blank#fabushi-test-browser-login")
    ) {
      return Promise.resolve();
    }
    return bridge().openExternal(url).then(() => undefined);
  }

  openSystemSettings(pane: "screen-recording" | "accessibility"): Promise<void> {
    return bridge().openSystemSettings(pane).then(() => undefined);
  }

  windowFocused(): Promise<boolean> {
    return bridge().windowFocused();
  }

  showNotification(title: string, body: string): Promise<void> {
    return bridge().notify(title, body).then(() => undefined);
  }

  interrupt(operationId: string): Promise<void> {
    return bridge().invoke<void>("feature.interrupt", { operationId });
  }

  resolveApproval(resolution: ApprovalResolution): Promise<void> {
    return bridge().invoke<void>("feature.approval.resolve", { resolution });
  }

  async close(): Promise<void> {
    this.closed = true;
    this.unsubscribeBridge?.();
    this.unsubscribeBridge = null;
  }

  private dispatchEvent(event: RuntimeEvent): void {
    for (const listener of this.listeners) listener(event);
  }

  private attachRuntimeEvents(): void {
    this.unsubscribeBridge?.();
    this.unsubscribeBridge = null;

    const electronBridge = bridge();
    if (typeof electronBridge.subscribe === "function") {
      this.unsubscribeBridge = electronBridge.subscribe((event) => this.dispatchEvent(event));
      return;
    }

    // Compatibility fallback for older Tauri/Electron bundles which have not
    // yet adopted the native edge event channel.
    this.startEventPump();
  }

  private startEventPump(): void {
    if (this.pumping) return;
    this.pumping = true;
    void this.pumpEvents();
  }

  private async pumpEvents(): Promise<void> {
    try {
      while (!this.closed) {
        try {
          const event = await bridge().invoke<RuntimeEvent | null>("feature.receive");
          if (event) this.dispatchEvent(event);
          else await idle(10);
        } catch (error) {
          if (this.closed) break;
          console.error("Electron Mahayana Host event pump failed", error);
          await idle(100);
        }
      }
    } finally {
      this.pumping = false;
    }
  }
}
