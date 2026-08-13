export type HostStatus = "idle" | "initializing" | "ready" | "closed";

export interface HostConfig {
  profileId: string;
  mode: "test" | "production";
}

export interface HostInfo {
  runtimeVersion: string;
  protocolVersion: "1";
  platform: "mock" | "tauri" | "wasm" | "flutter";
}

interface CommandBase {
  requestId: string;
}

export interface AccountSummary {
  loggedIn: boolean;
  provider: string;
  displayName?: string;
  membership?: string;
}

export interface ContactSummary {
  id: string;
  displayName: string;
  unreadCount: number;
}

export type RuntimeCommand =
  | (CommandBase & { type: "account.status" })
  | (CommandBase & {
      type: "account.password.login";
      username: string;
      password: string;
    })
  | (CommandBase & { type: "account.provider.start"; provider: string })
  | (CommandBase & { type: "account.provider.poll"; provider: string; state: string })
  | (CommandBase & { type: "account.logout" })
  | (CommandBase & { type: "contacts.list" })
  | (CommandBase & { type: "contacts.search"; query: string })
  | (CommandBase & {
      type: "contacts.request";
      contact: string;
      message?: string;
    })
  | (CommandBase & {
      type: "contacts.message.send";
      contact: string;
      text: string;
    })
  | (CommandBase & { type: "chat.send"; text: string })
  | (CommandBase & { type: "marketplace.install"; miniAppId: string })
  | (CommandBase & { type: "miniapp.open"; miniAppId: string })
  | (CommandBase & {
      type: "capability.request";
      miniAppId: string;
      capability: string;
      reason: string;
    })
  | (CommandBase & { type: "runtime.longTask"; label: string })
  | (CommandBase & { type: "session.clear" });

export interface CommandAccepted {
  requestId: string;
  operationId?: string;
}

interface EventBase {
  timestamp: string;
}

export type RuntimeEvent =
  | (EventBase & { type: "host.ready"; info: HostInfo })
  | (EventBase & { type: "account.updated"; account: AccountSummary })
  | (EventBase & { type: "account.provider.authorization"; provider: string; loginUrl: string; state: string })
  | (EventBase & { type: "account.provider.pending"; provider: string; state: string })
  | (EventBase & { type: "contacts.loaded"; contacts: ContactSummary[] })
  | (EventBase & {
      type: "contacts.search.results";
      contacts: ContactSummary[];
    })
  | (EventBase & { type: "contacts.request.sent"; contact: string })
  | (EventBase & {
      type: "contacts.message.sent";
      contact: string;
      text: string;
    })
  | (EventBase & {
      type: "chat.message";
      role: "user" | "assistant";
      text: string;
      operationId?: string;
    })
  | (EventBase & {
      type: "chat.delta";
      operationId: string;
      delta: string;
    })
  | (EventBase & {
      type: "marketplace.installed";
      miniAppId: string;
      version: string;
    })
  | (EventBase & { type: "miniapp.opened"; miniAppId: string })
  | (EventBase & {
      type: "approval.requested";
      approvalId: string;
      miniAppId: string;
      capability: string;
      reason: string;
    })
  | (EventBase & {
      type: "approval.resolved";
      approvalId: string;
      decision: "allow-once" | "deny";
    })
  | (EventBase & {
      type: "operation.started";
      operationId: string;
      label: string;
      interruptible: boolean;
    })
  | (EventBase & { type: "operation.interrupted"; operationId: string })
  | (EventBase & { type: "operation.completed"; operationId: string })
  | (EventBase & {
      type: "operation.failed";
      operationId: string;
      code: string;
      message: string;
    })
  | (EventBase & { type: "session.cleared" })
  | (EventBase & { type: "host.closed" });

export type ApprovalRequestedEvent = Extract<
  RuntimeEvent,
  { type: "approval.requested" }
>;

export interface ApprovalResolution {
  approvalId: string;
  decision: "allow-once" | "deny";
}
