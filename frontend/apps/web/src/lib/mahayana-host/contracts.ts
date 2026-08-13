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

export type AgentMode = "agent" | "ask" | "plan";

export interface AttachmentContext {
  id: string;
  name: string;
  mimeType?: string;
  text?: string;
}

export type ListenerPlatform =
  | "slack"
  | "github"
  | "git"
  | "teams"
  | "linear"
  | "sentry"
  | "pagerduty";

export interface ScheduleAutomationTrigger {
  kind: "schedule";
  schedule: string;
}

export interface EventAutomationTrigger {
  kind: "event";
  source: ListenerPlatform;
  event: string;
  filter?: string;
}

export type AutomationTrigger = ScheduleAutomationTrigger | EventAutomationTrigger;

export type ConnectorStatus =
  | "connected"
  | "disconnected"
  | "connecting"
  | "authRequired"
  | "error"
  | "disabledByTeamAdminPolicy";

export interface ConnectorToolSummary {
  id: string;
  name: string;
  description: string;
  enabled: boolean;
  requiresApproval?: boolean;
}

export interface ConnectorAccountSummary {
  id: string;
  label: string;
  status: ConnectorStatus;
  email?: string;
  teamManaged?: boolean;
  error?: string;
}

export interface ConnectorSummary {
  id: string;
  displayName: string;
  description: string;
  status: ConnectorStatus;
  isTeam: boolean;
  canAddAccount: boolean;
  transport: "http" | "sse" | "command";
  source?: string;
  teammateCount?: number;
  accounts: ConnectorAccountSummary[];
  tools: ConnectorToolSummary[];
}

export type SkillSource = "private" | "team" | "public";
export type SkillPublishState = "local" | "published" | "synced" | "managed";

export interface SkillSummary {
  id: string;
  name: string;
  description: string;
  useWhen: string;
  instructions: string;
  source: SkillSource;
  publishState: SkillPublishState;
  ownerAgentId?: string;
  teamId?: string;
  teamName?: string;
  readOnly?: boolean;
  updatedAtMs: number;
}

export interface SkillTeamSummary {
  id: string;
  name: string;
}

export interface BotSummary {
  id: string;
  name: string;
  description: string;
  hidden: boolean;
  avatar?: string;
  conversationId?: string;
}

export interface ListenerIntegrationSummary {
  platform: ListenerPlatform;
  displayName: string;
  blurb: string;
  isConnected: boolean;
  accountLabel?: string;
  error?: string;
}

export type DraftSendState =
  | "editable"
  | "sending"
  | "sent"
  | "discarded"
  | "failed";

export interface EmailDraft {
  kind: "email";
  id: string;
  from?: string;
  to: string[];
  cc?: string[];
  subject: string;
  body: string;
  status: DraftSendState;
  error?: string;
}

export interface SlackDraft {
  kind: "slack";
  id: string;
  workspace?: string;
  target: string;
  thread?: string;
  body: string;
  status: DraftSendState;
  error?: string;
}

export type MessageDraft = EmailDraft | SlackDraft;

export interface SpreadsheetSheet {
  name: string;
  rows: string[][];
}

export interface EventCard {
  source: ListenerPlatform;
  event: string;
  title: string;
  summary: string;
  url?: string;
  actor?: string;
  fields?: Array<{ label: string; value: string }>;
  occurredAtMs?: number;
}

export type TranscriptCard =
  | { kind: "emailDraft"; draft: EmailDraft }
  | { kind: "slackDraft"; draft: SlackDraft }
  | {
      kind: "secretRequest";
      requestId: string;
      label: string;
      description?: string;
      provided: boolean;
    }
  | {
      kind: "listenerConnect";
      platform: ListenerPlatform;
      reason?: string;
      connected: boolean;
      pending?: boolean;
    }
  | { kind: "event"; event: EventCard }
  | {
      kind: "pdf";
      name: string;
      url?: string;
      dataBase64?: string;
      pageCount?: number;
    }
  | {
      kind: "spreadsheet";
      name: string;
      sheets: SpreadsheetSheet[];
    };

export type UpdateState =
  | { type: "loading" }
  | {
      type: "disabled";
      reason:
        | "not-packaged"
        | "lab-build"
        | "unsupported-platform"
        | "disabled-by-env";
    }
  | { type: "checking" }
  | { type: "available"; version: string; notes?: string }
  | { type: "downloading"; version: string; progress?: number }
  | { type: "staging"; version: string }
  | { type: "ready"; version: string }
  | { type: "upToDate"; version: string }
  | { type: "error"; message: string };

export type RuntimeCommand =
  | (CommandBase & {
      type: "chat.send";
      text: string;
      agentId?: string;
      conversationId?: string;
      mode?: AgentMode;
      modeStatement?: string;
      model?: string;
      attachments?: AttachmentContext[];
    })
  | (CommandBase & { type: "conversation.list"; query?: string })
  | (CommandBase & { type: "conversation.open"; conversationId: string })
  | (CommandBase & { type: "capability.list"; query?: string })
  | (CommandBase & { type: "automation.list" })
  | (CommandBase & {
      type: "automation.upsert";
      id?: string;
      name: string;
      prompt: string;
      schedule: string;
      trigger?: AutomationTrigger;
      enabled?: boolean;
    })
  | (CommandBase & { type: "automation.setEnabled"; id: string; enabled: boolean })
  | (CommandBase & { type: "automation.delete"; id: string })
  | (CommandBase & { type: "automation.run"; id: string })
  | (CommandBase & { type: "marketplace.install"; miniAppId: string })
  | (CommandBase & { type: "miniapp.open"; miniAppId: string })
  | (CommandBase & {
      type: "capability.request";
      miniAppId: string;
      capability: string;
      reason: string;
    })
  | (CommandBase & { type: "connector.list" })
  | (CommandBase & {
      type: "connector.connect";
      connectorId: string;
      accountLabel?: string;
    })
  | (CommandBase & {
      type: "connector.renameAccount";
      connectorId: string;
      accountId: string;
      label: string;
    })
  | (CommandBase & {
      type: "connector.removeAccount";
      connectorId: string;
      accountId: string;
    })
  | (CommandBase & {
      type: "connector.setToolEnabled";
      connectorId: string;
      toolId: string;
      enabled: boolean;
    })
  | (CommandBase & { type: "skill.list"; agentId?: string })
  | (CommandBase & {
      type: "skill.upsert";
      id?: string;
      name: string;
      description: string;
      useWhen: string;
      instructions: string;
      ownerAgentId?: string;
    })
  | (CommandBase & { type: "skill.delete"; id: string })
  | (CommandBase & { type: "skill.publish"; id: string; teamId: string })
  | (CommandBase & { type: "skill.unpublish"; id: string })
  | (CommandBase & { type: "skill.sync"; id: string })
  | (CommandBase & { type: "bot.list" })
  | (CommandBase & { type: "bot.setHidden"; id: string; hidden: boolean })
  | (CommandBase & {
      type: "draft.resolve";
      draft: MessageDraft;
      action: "send" | "discard";
    })
  | (CommandBase & {
      type: "secret.provide";
      secretRequestId: string;
      value: string;
    })
  | (CommandBase & { type: "listener.list" })
  | (CommandBase & { type: "listener.connect"; platform: ListenerPlatform })
  | (CommandBase & { type: "update.status" })
  | (CommandBase & { type: "update.check" })
  | (CommandBase & { type: "update.install" })
  | (CommandBase & { type: "runtime.longTask"; label: string })
  | (CommandBase & { type: "session.clear" });

export interface CommandAccepted {
  requestId: string;
  operationId?: string;
}

export interface ConversationSummary {
  id: string;
  title: string;
  kind: string;
  pinned: boolean;
  unreadCount: number;
  updatedAtMs: number;
}

export interface CapabilitySummary {
  id: string;
  title: string;
  kind: "agent" | "bot" | "plugin" | "miniApp" | "application" | "contact";
  mention: string;
  conversationId: string;
  provider: string;
  pluginId?: string;
  description: string;
  requiredPermissions: string[];
  availability: "ready" | "permissionRequired" | "unavailable";
  unavailableReason?: string;
}

export interface AutomationSummary {
  id: string;
  name: string;
  prompt: string;
  schedule: string;
  trigger?: AutomationTrigger;
  enabled: boolean;
  createdAtMs: number;
  lastRunAtMs?: number;
  nextRunAtMs?: number;
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
      type: "transcript.card";
      entryId: string;
      operationId?: string;
      card: TranscriptCard;
    })
  | (EventBase & {
      type: "draft.changed";
      draftId: string;
      status: DraftSendState;
      error?: string;
    })
  | (EventBase & { type: "secret.provided"; secretRequestId: string })
  | (EventBase & {
      type: "conversation.listed";
      conversations: ConversationSummary[];
    })
  | (EventBase & {
      type: "conversation.opened";
      conversationId: string;
      messages: Array<{
        id: string;
        role: "user" | "assistant";
        text: string;
        createdAtMs: number;
      }>;
    })
  | (EventBase & {
      type: "capability.listed";
      capabilities: CapabilitySummary[];
    })
  | (EventBase & {
      type: "automation.listed";
      automations: AutomationSummary[];
    })
  | (EventBase & {
      type: "automation.changed";
      action: "created" | "updated" | "paused" | "resumed" | "deleted" | "running";
      automation: AutomationSummary;
    })
  | (EventBase & { type: "connector.listed"; connectors: ConnectorSummary[] })
  | (EventBase & {
      type: "connector.changed";
      action: "connected" | "updated" | "removed" | "toolChanged" | "failed";
      connector: ConnectorSummary;
    })
  | (EventBase & {
      type: "connector.oauthRequested";
      connectorId: string;
      authorizationUrl: string;
    })
  | (EventBase & {
      type: "skill.listed";
      skills: SkillSummary[];
      teams: SkillTeamSummary[];
    })
  | (EventBase & {
      type: "skill.changed";
      action: "created" | "updated" | "deleted" | "published" | "unpublished" | "synced";
      skill: SkillSummary;
    })
  | (EventBase & { type: "bot.listed"; bots: BotSummary[] })
  | (EventBase & { type: "bot.changed"; bot: BotSummary })
  | (EventBase & {
      type: "listener.listed";
      integrations: ListenerIntegrationSummary[];
    })
  | (EventBase & {
      type: "listener.changed";
      integration: ListenerIntegrationSummary;
    })
  | (EventBase & { type: "update.changed"; state: UpdateState })
  | (EventBase & {
      type: "agent.step";
      operationId?: string;
      stepId: string;
      kind: string;
      title: string;
      detail?: string;
      status: "running" | "completed" | "failed";
      progress?: number;
      total?: number;
    })
  | (EventBase & {
      type: "model.routed";
      operationId: string;
      provider: string;
      model: string;
      mode: AgentMode;
    })
  | (EventBase & {
      type: "usage.updated";
      operationId: string;
      inputTokens: number;
      cachedInputTokens: number;
      outputTokens: number;
      reasoningTokens: number;
      totalTokens: number;
      contextWindow?: number;
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
      kind?: "command" | "connectedService" | "automation" | "capability";
      subject?: string;
      detail?: string;
      proposedRule?: string;
      location?: "local" | "agent" | "cloud";
    })
  | (EventBase & {
      type: "approval.resolved";
      approvalId: string;
      decision: "allow-once" | "allow-session" | "deny";
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
  decision: "allow-once" | "allow-session" | "deny";
}
