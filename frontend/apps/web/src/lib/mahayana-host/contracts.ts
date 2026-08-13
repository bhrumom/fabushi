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

export interface AuthUser {
  id?: string | number;
  username?: string;
  nickname?: string;
  email?: string;
  avatar?: string;
}

export interface AuthState {
  loggedIn: boolean;
  provider?: string;
  user?: AuthUser;
}

export type AuthProviderId = "google" | "apple" | "microsoft" | "github";

export interface AuthProvider {
  id: AuthProviderId;
  displayName: string;
  enabled: boolean;
}

export interface OAuthAttempt {
  attemptId: string;
  provider: AuthProviderId;
  authorizationUrl: string;
  expiresAt?: number;
}

export interface OAuthPollResult {
  status: "pending" | "completed" | "expired" | "cancelled";
  auth?: AuthState;
}

interface CommandBase {
  requestId: string;
}

export type RuntimeCommand =
  | (CommandBase & { type: "chat.send"; text: string; agentId?: string })
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
  | (EventBase & { type: "miniapp.opened"; miniAppId: string; html?: string })
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
