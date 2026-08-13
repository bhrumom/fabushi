import type {
  ApprovalResolution,
  AuthState,
  AuthProvider,
  AuthProviderId,
  CommandAccepted,
  HostConfig,
  HostInfo,
  HostStatus,
  RuntimeCommand,
  RuntimeEvent,
  OAuthAttempt,
  OAuthPollResult,
} from "./contracts";
import {
  isTauriMahayanaHostAvailable,
  TauriMahayanaHostTransport,
} from "./tauri-transport";
import type {
  MahayanaHostTransport,
  RuntimeEventListener,
} from "./transport";

const now = () => new Date().toISOString();

/**
 * Deterministic browser transport used by fast UI tests.
 *
 * The historical class name is retained so existing pages need no migration
 * churn. Inside a native Tauri window it automatically delegates every method
 * to the real Rust feature Host; only an ordinary browser uses the in-memory
 * implementation below.
 */
export class MockMahayanaHostTransport implements MahayanaHostTransport {
  private readonly native: MahayanaHostTransport | null;
  private readonly listeners = new Set<RuntimeEventListener>();
  private readonly approvals = new Set<string>();
  private status: HostStatus = "idle";
  private sequence = 0;
  private auth: AuthState = { loggedIn: false, provider: "test" };
  private oauthAttempt: OAuthAttempt | null = null;
  private info: HostInfo = {
    runtimeVersion: "mahayana-mock-1.0.0",
    protocolVersion: "1",
    platform: "mock",
  };

  constructor() {
    this.native = isTauriMahayanaHostAvailable()
      ? new TauriMahayanaHostTransport()
      : null;
  }

  subscribe(listener: RuntimeEventListener): () => void {
    if (this.native) return this.native.subscribe(listener);
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  async initialize(config: HostConfig): Promise<HostInfo> {
    if (this.native) return this.native.initialize(config);
    if (this.status === "ready") return this.info;
    this.status = "initializing";
    this.status = "ready";
    this.emit({ type: "host.ready", timestamp: now(), info: this.info });
    return this.info;
  }

  async execute(command: RuntimeCommand): Promise<CommandAccepted> {
    if (this.native) return this.native.execute(command);
    this.assertReady();

    switch (command.type) {
      case "chat.send": {
        const operationId = this.nextId("chat");
        this.emit({
          type: "chat.message",
          timestamp: now(),
          role: "user",
          text: command.text,
        });
        this.emit({
          type: "operation.started",
          timestamp: now(),
          operationId,
          label: "chat-response",
          interruptible: false,
        });
        this.emit({
          type: "chat.message",
          timestamp: now(),
          role: "assistant",
          text: `收到：${command.text}`,
        });
        return { requestId: command.requestId, operationId };
      }
      case "marketplace.install":
        this.emit({
          type: "marketplace.installed",
          timestamp: now(),
          miniAppId: command.miniAppId,
          version: "1.0.0",
        });
        return { requestId: command.requestId };
      case "miniapp.open":
        this.emit({
          type: "miniapp.opened",
          timestamp: now(),
          miniAppId: command.miniAppId,
          html: `<!doctype html><html lang="zh-CN"><body style="font:15px system-ui;background:#101722;color:#edf3ff;padding:20px"><h1>测试 MiniApp</h1><p>${command.miniAppId} 已在隔离容器中打开。</p></body></html>`,
        });
        return { requestId: command.requestId };
      case "capability.request": {
        const approvalId = this.nextId("approval");
        this.approvals.add(approvalId);
        this.emit({
          type: "approval.requested",
          timestamp: now(),
          approvalId,
          miniAppId: command.miniAppId,
          capability: command.capability,
          reason: command.reason,
        });
        return { requestId: command.requestId };
      }
      case "runtime.longTask": {
        const operationId = this.nextId("operation");
        this.emit({
          type: "operation.started",
          timestamp: now(),
          operationId,
          label: command.label,
          interruptible: true,
        });
        return { requestId: command.requestId, operationId };
      }
      case "session.clear":
        this.emit({ type: "session.cleared", timestamp: now() });
        return { requestId: command.requestId };
    }
  }

  async authStatus(): Promise<AuthState> {
    if (this.native) return this.native.authStatus();
    return this.auth;
  }

  async authProviders(): Promise<AuthProvider[]> {
    if (this.native) return this.native.authProviders();
    return [
      { id: "google", displayName: "Google", enabled: true },
      { id: "apple", displayName: "Apple", enabled: true },
      { id: "microsoft", displayName: "Microsoft", enabled: true },
      { id: "github", displayName: "GitHub", enabled: true },
    ];
  }

  async oauthStart(provider: AuthProviderId): Promise<OAuthAttempt> {
    if (this.native) return this.native.oauthStart(provider);
    this.assertReady();
    this.oauthAttempt = {
      attemptId: `oauth-${provider}-${this.nextId("attempt")}`,
      provider,
      authorizationUrl: `about:blank#fabushi-test-oauth-${provider}`,
    };
    return this.oauthAttempt;
  }

  async oauthPoll(attemptId: string): Promise<OAuthPollResult> {
    if (this.native) return this.native.oauthPoll(attemptId);
    if (this.oauthAttempt?.attemptId !== attemptId) {
      return { status: "expired" };
    }
    const provider = this.oauthAttempt.provider;
    this.auth = {
      loggedIn: true,
      provider,
      user: {
        id: `fast-e2e-${provider}`,
        email: `test@${provider}.example`,
        nickname: `${provider} 测试用户`,
      },
    };
    this.oauthAttempt = null;
    return { status: "completed", auth: this.auth };
  }

  async openExternal(url: string): Promise<void> {
    if (this.native) return this.native.openExternal(url);
    if (url.startsWith("about:blank#fabushi-test-oauth")) return;
    const popup = window.open(url, "fabushi-oauth", "popup,width=520,height=720");
    if (!popup) throw new Error("浏览器窗口被拦截，请允许弹出窗口后重试");
  }

  async passwordLogin(username: string, password: string): Promise<AuthState> {
    if (this.native) return this.native.passwordLogin(username, password);
    this.assertReady();
    if (!username.trim() || !password) throw new Error("请输入账号和密码");
    this.auth = {
      loggedIn: true,
      provider: "test",
      user: { id: "fast-e2e-user", username, nickname: "本地测试用户" },
    };
    return this.auth;
  }

  async logout(): Promise<AuthState> {
    if (this.native) return this.native.logout();
    this.auth = { loggedIn: false, provider: "test" };
    return this.auth;
  }

  async interrupt(operationId: string): Promise<void> {
    if (this.native) return this.native.interrupt(operationId);
    this.assertReady();
    this.emit({
      type: "operation.interrupted",
      timestamp: now(),
      operationId,
    });
  }

  async resolveApproval(resolution: ApprovalResolution): Promise<void> {
    if (this.native) return this.native.resolveApproval(resolution);
    this.assertReady();
    if (!this.approvals.delete(resolution.approvalId)) {
      throw new Error(`Unknown approval: ${resolution.approvalId}`);
    }
    this.emit({
      type: "approval.resolved",
      timestamp: now(),
      approvalId: resolution.approvalId,
      decision: resolution.decision,
    });
  }

  async close(): Promise<void> {
    if (this.native) return this.native.close();
    if (this.status === "closed") return;
    this.status = "closed";
    this.emit({ type: "host.closed", timestamp: now() });
  }

  private assertReady(): void {
    if (this.status !== "ready") {
      throw new Error(`Mahayana host is not ready: ${this.status}`);
    }
  }

  private nextId(prefix: string): string {
    this.sequence += 1;
    return `${prefix}-${this.sequence}`;
  }

  private emit(event: RuntimeEvent): void {
    for (const listener of this.listeners) listener(event);
  }
}
