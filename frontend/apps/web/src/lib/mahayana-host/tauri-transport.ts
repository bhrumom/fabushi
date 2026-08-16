import type {
  ApprovalResolution,
  AuthState,
  AuthProvider,
  BrowserLoginAttempt,
  BrowserLoginPollResult,
  AuthProviderId,
  CommandAccepted,
  HostConfig,
  HostInfo,
  RuntimeCommand,
  RuntimeEvent,
  OAuthAttempt,
  OAuthPollResult,
} from "./contracts";
import type {
  MahayanaHostTransport,
  RuntimeEventListener,
} from "./transport";

type TauriInvoke = <T>(
  command: string,
  args?: Record<string, unknown>,
) => Promise<T>;

declare global {
  interface Window {
    __TAURI__?: {
      core?: {
        invoke?: TauriInvoke;
      };
    };
  }
}

const idle = (milliseconds = 10) =>
  new Promise<void>((resolve) => setTimeout(resolve, milliseconds));

export function isTauriMahayanaHostAvailable(): boolean {
  return (
    typeof window !== "undefined" &&
    typeof window.__TAURI__?.core?.invoke === "function"
  );
}

function nativeInvoke<T>(
  command: string,
  args?: Record<string, unknown>,
): Promise<T> {
  const invoke =
    typeof window !== "undefined" ? window.__TAURI__?.core?.invoke : undefined;
  if (typeof invoke !== "function") {
    return Promise.reject(new Error("Tauri Mahayana Host is not available"));
  }
  return invoke<T>(command, args);
}

export class TauriMahayanaHostTransport implements MahayanaHostTransport {
  private readonly listeners = new Set<RuntimeEventListener>();
  private closed = false;
  private pumping = false;

  subscribe(listener: RuntimeEventListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  async initialize(config: HostConfig): Promise<HostInfo> {
    const info = await nativeInvoke<HostInfo>("feature_host_initialize", {
      config,
    });
    this.closed = false;
    this.startEventPump();
    return info;
  }

  execute(command: RuntimeCommand): Promise<CommandAccepted> {
    return nativeInvoke<CommandAccepted>("feature_host_execute", { command });
  }

  authStatus(): Promise<AuthState> {
    return nativeInvoke<AuthState>("feature_host_auth_status");
  }

  authProviders(): Promise<AuthProvider[]> {
    return nativeInvoke<AuthProvider[]>("feature_host_auth_providers");
  }

  browserLoginStart(): Promise<BrowserLoginAttempt> {
    return nativeInvoke<BrowserLoginAttempt>("feature_host_browser_login_start");
  }

  browserLoginPoll(attemptId: string): Promise<BrowserLoginPollResult> {
    return nativeInvoke<BrowserLoginPollResult>("feature_host_browser_login_poll", { attemptId });
  }

  browserLoginCancel(attemptId: string): Promise<BrowserLoginPollResult> {
    return nativeInvoke<BrowserLoginPollResult>("feature_host_browser_login_cancel", { attemptId });
  }

  oauthStart(provider: AuthProviderId): Promise<OAuthAttempt> {
    return nativeInvoke<OAuthAttempt>("feature_host_oauth_start", { provider });
  }

  oauthPoll(attemptId: string): Promise<OAuthPollResult> {
    return nativeInvoke<OAuthPollResult>("feature_host_oauth_poll", { attemptId });
  }

  openExternal(url: string): Promise<void> {
    return nativeInvoke<void>("feature_host_open_external", { url });
  }

  openSystemSettings(pane: "screen-recording" | "accessibility"): Promise<void> {
    return nativeInvoke<void>("feature_host_open_system_settings", { pane });
  }

  windowFocused(): Promise<boolean> {
    return nativeInvoke<boolean>("feature_host_window_focused");
  }

  showNotification(title: string, body: string): Promise<void> {
    return nativeInvoke<void>("feature_host_show_notification", { title, body });
  }

  passwordLogin(username: string, password: string): Promise<AuthState> {
    return nativeInvoke<AuthState>("feature_host_password_login", {
      username,
      password,
    });
  }

  logout(): Promise<AuthState> {
    return nativeInvoke<AuthState>("feature_host_logout");
  }

  interrupt(operationId: string): Promise<void> {
    return nativeInvoke<void>("feature_host_interrupt", { operationId });
  }

  resolveApproval(resolution: ApprovalResolution): Promise<void> {
    return nativeInvoke<void>("feature_host_resolve_approval", { resolution });
  }

  async close(): Promise<void> {
    if (this.closed) return;
    this.closed = true;
    await nativeInvoke<void>("feature_host_close");
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
          const event = await nativeInvoke<RuntimeEvent | null>(
            "feature_host_receive",
            { timeoutMs: 25 },
          );
          if (event) {
            for (const listener of this.listeners) listener(event);
          } else {
            await idle();
          }
        } catch (error) {
          if (this.closed) break;
          console.error("Mahayana Host event pump failed", error);
          // A transient invoke failure must not terminate the only Runtime
          // event stream. Back off briefly and retry while the Host is open.
          await idle(100);
        }
      }
    } finally {
      this.pumping = false;
    }
  }
}
