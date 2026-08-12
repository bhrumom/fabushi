import type {
  ApprovalResolution,
  CommandAccepted,
  HostConfig,
  HostInfo,
  HostStatus,
  RuntimeCommand,
  RuntimeEvent,
} from "./contracts";
import type {
  MahayanaHostTransport,
  RuntimeEventListener,
} from "./transport";

const now = () => new Date().toISOString();

export class MockMahayanaHostTransport implements MahayanaHostTransport {
  private readonly listeners = new Set<RuntimeEventListener>();
  private readonly approvals = new Set<string>();
  private status: HostStatus = "idle";
  private sequence = 0;
  private info: HostInfo = {
    runtimeVersion: "mahayana-mock-1.0.0",
    protocolVersion: "1",
    platform: "mock",
  };

  subscribe(listener: RuntimeEventListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  async initialize(_config: HostConfig): Promise<HostInfo> {
    if (this.status === "ready") return this.info;
    this.status = "initializing";
    this.status = "ready";
    this.emit({ type: "host.ready", timestamp: now(), info: this.info });
    return this.info;
  }

  async execute(command: RuntimeCommand): Promise<CommandAccepted> {
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

  async interrupt(operationId: string): Promise<void> {
    this.assertReady();
    this.emit({
      type: "operation.interrupted",
      timestamp: now(),
      operationId,
    });
  }

  async resolveApproval(resolution: ApprovalResolution): Promise<void> {
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
