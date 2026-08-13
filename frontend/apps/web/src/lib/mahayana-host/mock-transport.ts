import type {
  ApprovalResolution,
  CommandAccepted,
  HostConfig,
  HostInfo,
  HostStatus,
  RuntimeCommand,
  RuntimeEvent,
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
  private readonly contacts = [
    { id: "contact-1", displayName: "善友", unreadCount: 1 },
    { id: "contact-2", displayName: "法喜", unreadCount: 0 },
  ];
  private account = {
    loggedIn: false,
    provider: "password",
    displayName: undefined as string | undefined,
    membership: undefined as string | undefined,
  };
  private status: HostStatus = "idle";
  private sequence = 0;
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
      case "account.status":
        this.emit({
          type: "account.updated",
          timestamp: now(),
          account: { ...this.account },
        });
        return { requestId: command.requestId };
      case "account.password.login":
        if (!command.username.trim() || !command.password.trim()) {
          throw new Error("Username and password are required");
        }
        this.account = {
          loggedIn: true,
          provider: "password",
          displayName: command.username.trim(),
          membership: "free",
        };
        this.emit({
          type: "account.updated",
          timestamp: now(),
          account: { ...this.account },
        });
        return { requestId: command.requestId };
      case "account.provider.start":
        if (command.provider !== "alipay") {
          throw new Error(`Unsupported account provider: ${command.provider}`);
        }
        this.emit({
          type: "account.provider.authorization",
          timestamp: now(),
          provider: command.provider,
          loginUrl: "https://example.invalid/alipay-login",
          state: "test-provider-state",
        });
        return { requestId: command.requestId };
      case "account.provider.poll":
        this.account = {
          loggedIn: true,
          provider: command.provider,
          displayName: "测试用户",
          membership: "free",
        };
        this.emit({
          type: "account.updated",
          timestamp: now(),
          account: { ...this.account },
        });
        return { requestId: command.requestId };
      case "account.logout":
        this.account = {
          loggedIn: false,
          provider: "official",
          displayName: undefined,
          membership: undefined,
        };
        this.emit({
          type: "account.updated",
          timestamp: now(),
          account: { ...this.account },
        });
        return { requestId: command.requestId };
      case "contacts.list":
        this.assertAuthenticated();
        this.emit({
          type: "contacts.loaded",
          timestamp: now(),
          contacts: this.contacts.map((contact) => ({ ...contact })),
        });
        return { requestId: command.requestId };
      case "contacts.search": {
        this.assertAuthenticated();
        const query = command.query.trim().toLocaleLowerCase();
        this.emit({
          type: "contacts.search.results",
          timestamp: now(),
          contacts: this.contacts.filter(
            (contact) =>
              contact.id.toLocaleLowerCase().includes(query) ||
              contact.displayName.toLocaleLowerCase().includes(query),
          ),
        });
        return { requestId: command.requestId };
      }
      case "contacts.request":
        this.assertAuthenticated();
        this.emit({
          type: "contacts.request.sent",
          timestamp: now(),
          contact: command.contact,
        });
        return { requestId: command.requestId };
      case "contacts.message.send":
        this.assertAuthenticated();
        if (!this.contacts.some((contact) => contact.id === command.contact)) {
          throw new Error(`Unknown contact: ${command.contact}`);
        }
        this.emit({
          type: "contacts.message.sent",
          timestamp: now(),
          contact: command.contact,
          text: command.text,
        });
        return { requestId: command.requestId };
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
        this.account = {
          loggedIn: false,
          provider: this.account.provider,
          displayName: undefined,
          membership: undefined,
        };
        this.emit({
          type: "account.updated",
          timestamp: now(),
          account: { ...this.account },
        });
        this.emit({ type: "session.cleared", timestamp: now() });
        return { requestId: command.requestId };
    }
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

  private assertAuthenticated(): void {
    if (!this.account.loggedIn) {
      throw new Error("Account must be logged in");
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
