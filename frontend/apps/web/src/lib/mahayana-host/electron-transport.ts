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

type MahayanaElectronBridge = {
  contractVersion: number;
  invoke<T>(method: string, params?: Record<string, unknown>): Promise<T>;
  subscribe?(listener: RuntimeEventListener): () => void;
};

type ElectronShellBridge = {
  contractVersion: number;
  notify(title: string, body: string): Promise<boolean | void>;
  openExternal(url: string): Promise<boolean | void>;
  openSystemSettings(pane: "screen-recording" | "accessibility"): Promise<boolean | void>;
  windowFocused(): Promise<boolean>;
};

declare global {
  interface Window {
    fabushi: ElectronShellBridge;
    mahayana?: MahayanaElectronBridge;
  }
}

const ELECTRON_EDGE_CONTRACT_VERSION = 1;

const idle = (milliseconds = 10) =>
  new Promise<void>((resolve) => setTimeout(resolve, milliseconds));

function isMiniAppConversation(kind: string): boolean {
  return kind.trim().toLocaleLowerCase() === "miniapp";
}

function miniAppIdForConversation(conversation: { id: string; title: string }): string {
  const exactTitle = conversation.title.trim().toLocaleLowerCase();
  const knownByTitle: Record<string, string> = {
    "bot father": "bot-father",
    "chatgpt 自动确认": "chatgpt-auto-confirm",
    "全球法布施": "global-dharma",
    "法流记忆卡": "faliu-flashcards",
    "平台发布": "platform-publish",
    "hermes 安装器": "hermes-installer",
    "大乘助手": "mahayana-assistant",
  };
  const known = knownByTitle[exactTitle];
  if (known) return known;

  const cleanId = conversation.id.trim();
  const namespaced = cleanId.match(/(?:^|:)([a-z0-9][a-z0-9-]*)$/i)?.[1];
  return namespaced || cleanId;
}

export function isElectronMahayanaHostAvailable(): boolean {
  return (
    typeof window !== "undefined" &&
    window.mahayana?.contractVersion === ELECTRON_EDGE_CONTRACT_VERSION &&
    typeof window.mahayana.invoke === "function"
  );
}

function mahayanaBridge(): MahayanaElectronBridge {
  if (!isElectronMahayanaHostAvailable() || !window.mahayana) {
    throw new Error("Electron Mahayana Host is not available or uses an unsupported bridge contract");
  }
  return window.mahayana;
}

function shellBridge(): ElectronShellBridge {
  if (typeof window === "undefined" || window.fabushi?.contractVersion !== ELECTRON_EDGE_CONTRACT_VERSION) {
    throw new Error("Electron shell bridge is not available or uses an unsupported contract");
  }
  return window.fabushi;
}

export class ElectronMahayanaHostTransport implements MahayanaHostTransport {
  private readonly listeners = new Set<RuntimeEventListener>();
  private readonly miniAppConversations = new Map<string, string>();
  private closed = false;
  private pumping = false;
  private unsubscribeBridge: (() => void) | null = null;

  subscribe(listener: RuntimeEventListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  async initialize(_config: HostConfig): Promise<HostInfo> {
    const info = await mahayanaBridge().invoke<HostInfo>("feature.info");
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

  async execute(command: RuntimeCommand): Promise<CommandAccepted> {
    let normalizedCommand = command;
    if (command.type === "conversation.open") {
      const miniAppId = this.miniAppConversations.get(command.conversationId);
      if (miniAppId) {
        normalizedCommand = {
          type: "miniapp.open",
          requestId: command.requestId,
          miniAppId,
        };
      }
    }

    if (normalizedCommand.type === "miniapp.open") {
      // Official Mini Apps are first-party product surfaces. The legacy Host
      // client disabled its Open button until marketplace.install had run,
      // while the unified Messenger intentionally exposes them directly.
      // Preserve that one-click product behavior by making installation an
      // idempotent prerequisite at the Electron edge before opening the app.
      await mahayanaBridge().invoke<CommandAccepted>("feature.execute", {
        command: {
          type: "marketplace.install",
          requestId: `${normalizedCommand.requestId}-install`,
          miniAppId: normalizedCommand.miniAppId,
        },
      });
    }

    return mahayanaBridge().invoke<CommandAccepted>("feature.execute", { command: normalizedCommand });
  }

  authStatus(): Promise<AuthState> {
    return mahayanaBridge().invoke<AuthState>("feature.auth.status");
  }

  authProviders(): Promise<AuthProvider[]> {
    return mahayanaBridge().invoke<AuthProvider[]>("feature.auth.providers");
  }

  browserLoginStart(): Promise<BrowserLoginAttempt> {
    return mahayanaBridge().invoke<BrowserLoginAttempt>("feature.auth.browserStart");
  }

  browserLoginPoll(attemptId: string): Promise<BrowserLoginPollResult> {
    return mahayanaBridge().invoke<BrowserLoginPollResult>("feature.auth.browserPoll", { attemptId });
  }

  browserLoginCancel(attemptId: string): Promise<BrowserLoginPollResult> {
    return mahayanaBridge().invoke<BrowserLoginPollResult>("feature.auth.browserCancel", { attemptId });
  }

  browserLoginReopen(attemptId: string): Promise<BrowserLoginReopenResult> {
    return mahayanaBridge().invoke<BrowserLoginReopenResult>("feature.auth.browserReopen", { attemptId });
  }

  passwordLogin(username: string, password: string): Promise<AuthState> {
    return mahayanaBridge().invoke<AuthState>("feature.auth.passwordLogin", { username, password });
  }

  oauthStart(provider: AuthProviderId): Promise<OAuthAttempt> {
    return mahayanaBridge().invoke<OAuthAttempt>("feature.auth.oauthStart", { provider });
  }

  oauthPoll(attemptId: string): Promise<OAuthPollResult> {
    return mahayanaBridge().invoke<OAuthPollResult>("feature.auth.oauthPoll", { attemptId });
  }

  logout(): Promise<AuthState> {
    return mahayanaBridge().invoke<AuthState>("feature.auth.logout");
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
    return shellBridge().openExternal(url).then(() => undefined);
  }

  openSystemSettings(pane: "screen-recording" | "accessibility"): Promise<void> {
    return shellBridge().openSystemSettings(pane).then(() => undefined);
  }

  windowFocused(): Promise<boolean> {
    return shellBridge().windowFocused();
  }

  showNotification(title: string, body: string): Promise<void> {
    return shellBridge().notify(title, body).then(() => undefined);
  }

  interrupt(operationId: string): Promise<void> {
    return mahayanaBridge().invoke<void>("feature.interrupt", { operationId });
  }

  resolveApproval(resolution: ApprovalResolution): Promise<void> {
    return mahayanaBridge().invoke<void>("feature.approval.resolve", { resolution });
  }

  async close(): Promise<void> {
    this.closed = true;
    this.unsubscribeBridge?.();
    this.unsubscribeBridge = null;
    this.miniAppConversations.clear();
  }

  private dispatchEvent(event: RuntimeEvent): void {
    if (event.type === "conversation.listed") {
      const messengerConversations = event.conversations.filter((conversation) => {
        if (!isMiniAppConversation(conversation.kind)) return true;
        this.miniAppConversations.set(
          conversation.id,
          miniAppIdForConversation(conversation),
        );
        return false;
      });
      const normalizedEvent: RuntimeEvent = {
        ...event,
        conversations: messengerConversations,
      };
      for (const listener of this.listeners) listener(normalizedEvent);
      return;
    }
    for (const listener of this.listeners) listener(event);
  }

  private attachRuntimeEvents(): void {
    this.unsubscribeBridge?.();
    this.unsubscribeBridge = null;

    const electronBridge = mahayanaBridge();
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
          const event = await mahayanaBridge().invoke<RuntimeEvent | null>("feature.receive");
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
