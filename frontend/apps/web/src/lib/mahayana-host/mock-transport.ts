import type {
  ApprovalResolution,
  AuthState,
  AuthProvider,
  AuthProviderId,
  AutomationSummary,
  BotSummary,
  CommandAccepted,
  ConnectorSummary,
  HostConfig,
  HostInfo,
  HostStatus,
  ListenerIntegrationSummary,
  ListenerPlatform,
  MessageDraft,
  RuntimeCommand,
  RuntimeEvent,
  OAuthAttempt,
  OAuthPollResult,
  SkillSummary,
  SkillTeamSummary,
  TranscriptCard,
  UpdateState,
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

const connectorTool = (id: string, name: string, description: string) => ({
  id,
  name,
  description,
  enabled: true,
  requiresApproval: true,
});

const defaultConnectors = (): ConnectorSummary[] => [
  {
    id: "github",
    displayName: "GitHub",
    description: "Repositories, pull requests, issues, comments and CI.",
    status: "disconnected",
    isTeam: false,
    canAddAccount: true,
    transport: "http",
    source: "Built in",
    accounts: [],
    tools: [
      connectorTool("read_repository", "Read repository", "Read repository files and metadata."),
      connectorTool("create_issue", "Create issue", "Create and update GitHub issues."),
      connectorTool("comment_pull_request", "Comment on pull request", "Post review comments on pull requests."),
    ],
  },
  {
    id: "slack",
    displayName: "Slack",
    description: "Messages, mentions, reactions and approved drafts.",
    status: "disconnected",
    isTeam: false,
    canAddAccount: true,
    transport: "http",
    source: "Built in",
    accounts: [],
    tools: [
      connectorTool("search_messages", "Search messages", "Search workspace messages and threads."),
      connectorTool("post_message", "Post message", "Send an approved message or thread reply."),
      connectorTool("add_reaction", "Add reaction", "Add a reaction to a message."),
    ],
  },
  {
    id: "teams",
    displayName: "Microsoft Teams",
    description: "Teams messages, mentions, channels and approved drafts.",
    status: "disconnected",
    isTeam: false,
    canAddAccount: true,
    transport: "http",
    source: "Built in",
    accounts: [],
    tools: [
      connectorTool("search_messages", "Search messages", "Search Teams channels and chats."),
      connectorTool("post_message", "Post message", "Send an approved Teams message."),
    ],
  },
  {
    id: "linear",
    displayName: "Linear",
    description: "Issues, comments, status changes and projects.",
    status: "disconnected",
    isTeam: false,
    canAddAccount: true,
    transport: "http",
    source: "Built in",
    accounts: [],
    tools: [
      connectorTool("read_issues", "Read issues", "Read Linear issues and projects."),
      connectorTool("update_issue", "Update issue", "Update issue state, assignee and fields."),
    ],
  },
  {
    id: "sentry",
    displayName: "Sentry",
    description: "Errors, regressions, releases and issue ownership.",
    status: "disconnected",
    isTeam: false,
    canAddAccount: true,
    transport: "http",
    source: "Built in",
    accounts: [],
    tools: [
      connectorTool("read_issues", "Read issues", "Read Sentry issues and events."),
      connectorTool("resolve_issue", "Resolve issue", "Resolve or assign a Sentry issue."),
    ],
  },
  {
    id: "pagerduty",
    displayName: "PagerDuty",
    description: "Incidents, acknowledgements, responders and escalation.",
    status: "disconnected",
    isTeam: false,
    canAddAccount: true,
    transport: "http",
    source: "Built in",
    accounts: [],
    tools: [
      connectorTool("read_incidents", "Read incidents", "Read incident details and timelines."),
      connectorTool("acknowledge_incident", "Acknowledge incident", "Acknowledge an incident after approval."),
    ],
  },
  {
    id: "git",
    displayName: "Git",
    description: "Local commits, branches and repository state.",
    status: "disconnected",
    isTeam: false,
    canAddAccount: true,
    transport: "command",
    source: "Built in",
    accounts: [],
    tools: [
      connectorTool("read_status", "Read status", "Read local repository status."),
      connectorTool("read_history", "Read history", "Read commit and branch history."),
    ],
  },
];

const defaultTeams = (): SkillTeamSummary[] => [
  { id: "team-mahayana", name: "Mahayana Team" },
];

const defaultSkills = (): SkillSummary[] => [
  {
    id: "skill-research-brief",
    name: "Research brief",
    description: "Turn verified sources into a concise research brief.",
    useWhen: "Use when a task needs sourced research and a decision-ready summary.",
    instructions: "Verify sources, distinguish facts from inference, and end with actionable conclusions.",
    source: "private",
    publishState: "local",
    ownerAgentId: "mahayana-assistant",
    readOnly: false,
    updatedAtMs: 0,
  },
  {
    id: "skill-incident-response",
    name: "Incident response",
    description: "Coordinate incident triage across monitoring and communication tools.",
    useWhen: "Use when an alert or incident needs coordinated triage.",
    instructions: "Establish severity, collect evidence, propose actions, and request approval before external changes.",
    source: "team",
    publishState: "managed",
    teamId: "team-mahayana",
    teamName: "Mahayana Team",
    readOnly: true,
    updatedAtMs: 0,
  },
];

const defaultBots = (): BotSummary[] => [
  { id: "mahayana-assistant", name: "大乘助手", description: "General-purpose Mahayana assistant.", hidden: false, conversationId: "codex:agent:assistant" },
  { id: "research-bot", name: "Research Bot", description: "Source verification and research synthesis.", hidden: false, conversationId: "codex:agent:research" },
  { id: "incident-bot", name: "Incident Bot", description: "Incident triage and operational coordination.", hidden: true, conversationId: "codex:agent:incident" },
];

const listenerCopy: Record<ListenerPlatform, [string, string]> = {
  github: ["GitHub", "Let automations watch a repo's PRs, comments, issues, and CI."],
  git: ["Git", "Wake automations on local commits, branches, tags, and repository changes."],
  slack: ["Slack", "Wake automations on Slack messages, mentions, and reactions."],
  teams: ["Microsoft Teams", "Wake automations on Teams messages, mentions, and reactions."],
  linear: ["Linear", "Wake automations on issues, comments, status changes, and assignments."],
  sentry: ["Sentry", "Wake automations on new, regressed, assigned, and resolved issues."],
  pagerduty: ["PagerDuty", "Wake automations when incidents are triggered, acknowledged, escalated, or resolved."],
};

const defaultListeners = (): ListenerIntegrationSummary[] =>
  (Object.keys(listenerCopy) as ListenerPlatform[]).map((platform) => ({
    platform,
    displayName: listenerCopy[platform][0],
    blurb: listenerCopy[platform][1],
    isConnected: false,
  }));

const connectorForPlatform = (platform: ListenerPlatform): string => platform;

const validateDraft = (draft: MessageDraft): void => {
  if (draft.kind === "email") {
    if (
      draft.to.length === 0 ||
      draft.to.some((recipient) => !recipient.trim() || !recipient.includes("@"))
    ) {
      throw new Error("Email draft requires valid recipients");
    }
    if (!draft.subject.trim()) throw new Error("Email subject must not be empty");
    if (!draft.body.trim()) throw new Error("Email body must not be empty");
    return;
  }
  if (!draft.target.trim()) throw new Error("Slack target must not be empty");
  if (!draft.body.trim()) throw new Error("Slack body must not be empty");
};

const RICH_RESULTS_CONVERSATION_ID = "mock:rich-results";

const richResultsMessages = () => {
  const createdAtMs = Date.now();
  return [
    {
      id: "rich-results-user",
      role: "user" as const,
      text: "Show the complete rich-result and approval-card gallery.",
      createdAtMs: createdAtMs - 1_000,
    },
    {
      id: "rich-results-assistant",
      role: "assistant" as const,
      createdAtMs,
      text: [
        "# Rich result gallery",
        "",
        "This browser-only conversation exercises **Markdown**, `inline code`, tables, code, diffs, and Mermaid without changing the native Tauri runtime.",
        "",
        "> The cards below use the same Host protocol consumed by production.",
        "",
        "| Surface | State |",
        "| --- | --- |",
        "| Markdown | Ready |",
        "| Approval cards | Interactive |",
        "| Documents | Previewable |",
        "",
        "- [x] Event routines",
        "- [x] Draft approvals",
        "- [ ] External OAuth (requires a real account)",
        "",
        "```typescript",
        "interface RoutineEvent {",
        "  source: \"slack\" | \"github\" | \"teams\";",
        "  event: string;",
        "}",
        "",
        "export const wake = async (event: RoutineEvent) => event;",
        "```",
        "",
        "```diff",
        "@@ listener state @@",
        "- status: disconnected",
        "+ status: listening",
        "+ neededByCount: 2",
        "```",
        "",
        "```mermaid",
        "flowchart TD",
        "  Event[External event] --> Match{Listener matches?}",
        "  Match -->|yes| Wake[Wake routine]",
        "  Match -->|no| Ignore[Ignore event]",
        "```",
        "",
        "```mermaid",
        "sequenceDiagram",
        "  participant Source",
        "  participant Host",
        "  participant Agent",
        "  Source->>Host: event payload",
        "  Host-->>Agent: structured wake context",
        "```",
      ].join("\n"),
    },
  ];
};

const demoPdfDataBase64 = (): string => {
  const stream = "BT /F1 18 Tf 72 720 Td (Mahayana rich result preview) Tj ET\n";
  const objects = [
    "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>\nendobj\n",
    `4 0 obj\n<< /Length ${stream.length} >>\nstream\n${stream}endstream\nendobj\n`,
    "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n",
  ];
  let pdf = "%PDF-1.4\n";
  const offsets = [0];
  for (const object of objects) {
    offsets.push(pdf.length);
    pdf += object;
  }
  const xrefOffset = pdf.length;
  pdf += `xref\n0 ${objects.length + 1}\n`;
  pdf += "0000000000 65535 f \n";
  for (const offset of offsets.slice(1)) {
    pdf += `${String(offset).padStart(10, "0")} 00000 n \n`;
  }
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF`;
  return btoa(pdf);
};

const richResultsCards = (): TranscriptCard[] => {
  const occurredAtMs = Date.now();
  const events: Array<Extract<TranscriptCard, { kind: "event" }>> = [
    {
      kind: "event",
      event: {
        source: "slack",
        event: "mention",
        title: "Agent mentioned in #operations",
        summary: "A production readiness question matched the routine keyword filter.",
        actor: "@dana",
        fields: [{ label: "Channel", value: "#operations" }, { label: "Keyword", value: "release" }],
        occurredAtMs,
      },
    },
    {
      kind: "event",
      event: {
        source: "github",
        event: "pullRequestReviewRequested",
        title: "Review requested on PR #482",
        summary: "The repository listener matched the review-request event.",
        actor: "octocat",
        fields: [{ label: "Repository", value: "ombhrum/fabushi" }, { label: "Branch", value: "main" }],
        occurredAtMs,
      },
    },
    {
      kind: "event",
      event: {
        source: "git",
        event: "commit",
        title: "Local branch advanced",
        summary: "A local commit woke the repository maintenance routine.",
        fields: [{ label: "Branch", value: "codex/fix-mahayana-marketplace-helper" }],
        occurredAtMs,
      },
    },
    {
      kind: "event",
      event: {
        source: "teams",
        event: "message",
        title: "Teams deployment thread updated",
        summary: "A message in the release channel matched the configured filter.",
        actor: "Avery",
        fields: [{ label: "Team", value: "Engineering" }, { label: "Channel", value: "Releases" }],
        occurredAtMs,
      },
    },
    {
      kind: "event",
      event: {
        source: "linear",
        event: "statusChanged",
        title: "FAB-321 moved to In Progress",
        summary: "The Linear issue entered a watched status.",
        actor: "Morgan",
        fields: [{ label: "Project", value: "Desktop" }, { label: "Team", value: "Runtime" }],
        occurredAtMs,
      },
    },
    {
      kind: "event",
      event: {
        source: "sentry",
        event: "issueRegressed",
        title: "Renderer crash regressed",
        summary: "Sentry reported a regression in the signed desktop build.",
        fields: [{ label: "Project", value: "fabushi-desktop" }, { label: "Issue", value: "DESKTOP-91" }],
        occurredAtMs,
      },
    },
    {
      kind: "event",
      event: {
        source: "pagerduty",
        event: "incidentTriggered",
        title: "API latency incident triggered",
        summary: "PagerDuty woke the incident response routine.",
        fields: [{ label: "Service", value: "Mahayana API" }, { label: "Urgency", value: "high" }],
        occurredAtMs,
      },
    },
  ];

  return [
    ...events,
    {
      kind: "emailDraft",
      draft: {
        kind: "email",
        id: "demo-email-draft",
        from: "agent@example.com",
        to: ["release@example.com"],
        cc: ["ops@example.com"],
        subject: "Release readiness update",
        body: "The migration checks passed. Please review the attached rollout summary before approval.",
        status: "editable",
      },
    },
    {
      kind: "slackDraft",
      draft: {
        kind: "slack",
        id: "demo-slack-draft",
        workspace: "Mahayana",
        target: "#release-room",
        thread: "Release 0.16 migration",
        body: "Host protocol, rich cards, and event routines are ready for final verification.",
        status: "editable",
      },
    },
    {
      kind: "secretRequest",
      requestId: "demo-secret-request",
      label: "Deployment API token",
      description: "Provide the token needed by the deployment connector. The value is never echoed into the transcript.",
      provided: false,
    },
    {
      kind: "listenerConnect",
      platform: "slack",
      reason: "Connect Slack before enabling routines that depend on mentions or reactions.",
      connected: false,
      pending: false,
    },
    {
      kind: "pdf",
      name: "migration-summary.pdf",
      dataBase64: demoPdfDataBase64(),
      pageCount: 1,
    },
    {
      kind: "spreadsheet",
      name: "migration-checklist.xlsx",
      sheets: [
        {
          name: "Coverage",
          rows: [
            ["Surface", "Status", "Evidence"],
            ["Event routines", "Ready", "7 listener sources"],
            ["Draft approvals", "Ready", "Email + Slack"],
            ["Updater", "Blocked", "Signed endpoint required"],
          ],
        },
        {
          name: "Responsive",
          rows: [
            ["Viewport", "Layout"],
            ["Desktop", "Three-column shell"],
            ["Tablet", "Activity panel hidden"],
            ["Mobile", "Compact sidebar and stacked cards"],
          ],
        },
      ],
    },
  ];
};

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
  private automations = new Map<string, AutomationSummary>();
  private connectors = new Map(defaultConnectors().map((connector) => [connector.id, connector]));
  private skills = new Map(defaultSkills().map((skill) => [skill.id, skill]));
  private bots = new Map(defaultBots().map((bot) => [bot.id, bot]));
  private listenerIntegrations = new Map(defaultListeners().map((integration) => [integration.platform, integration]));
  private updateState: UpdateState = { type: "upToDate", version: "0.1.0" };
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
      case "conversation.list":
        this.emit({
          type: "conversation.listed",
          timestamp: now(),
          conversations: [
            {
              id: "codex:agent:assistant",
              title: "大乘助手",
              kind: "codex",
              pinned: true,
              unreadCount: 0,
              updatedAtMs: Date.now(),
            },
            {
              id: RICH_RESULTS_CONVERSATION_ID,
              title: "富结果验收",
              kind: "mock gallery",
              pinned: false,
              unreadCount: 0,
              updatedAtMs: Date.now() - 1_000,
            },
          ].filter((conversation) =>
            command.query
              ? conversation.title.includes(command.query)
              : true,
          ),
        });
        return { requestId: command.requestId };
      case "conversation.open": {
        const isRichResultsGallery = command.conversationId === RICH_RESULTS_CONVERSATION_ID;
        this.emit({
          type: "conversation.opened",
          timestamp: now(),
          conversationId: command.conversationId,
          messages: isRichResultsGallery ? richResultsMessages() : [],
        });
        if (isRichResultsGallery) {
          richResultsCards().forEach((card, index) => {
            this.emit({
              type: "transcript.card",
              timestamp: now(),
              entryId: `rich-results-card-${index + 1}`,
              card,
            });
          });
        }
        return { requestId: command.requestId };
      }
      case "capability.list":
        this.emit({
          type: "capability.listed",
          timestamp: now(),
          capabilities: [
            {
              id: "agent.mahayana",
              title: "大乘助手",
              kind: "agent" as const,
              mention: "@agent.mahayana",
              conversationId: "codex:agent:assistant",
              provider: "codex",
              description: "大乘共享智能代理",
              requiredPermissions: [],
              availability: "ready" as const,
            },
          ].filter((capability) =>
            command.query
              ? `${capability.title} ${capability.id}`.includes(command.query)
              : true,
          ),
        });
        return { requestId: command.requestId };
      case "automation.list":
        this.emit({
          type: "automation.listed",
          timestamp: now(),
          automations: [...this.automations.values()],
        });
        return { requestId: command.requestId };
      case "automation.upsert": {
        const previous = command.id ? this.automations.get(command.id) : undefined;
        const id = command.id ?? this.nextId("routine");
        const automation = {
          id,
          name: command.name,
          prompt: command.prompt,
          schedule: command.schedule,
          trigger: command.trigger ?? { kind: "schedule" as const, schedule: command.schedule },
          enabled: command.enabled ?? true,
          createdAtMs: previous?.createdAtMs ?? Date.now(),
          lastRunAtMs: previous?.lastRunAtMs,
          nextRunAtMs: command.trigger?.kind === "event" ? undefined : Date.now() + 60_000,
        };
        this.automations.set(id, automation);
        this.emit({ type: "automation.changed", timestamp: now(), action: previous ? "updated" : "created", automation });
        return { requestId: command.requestId };
      }
      case "automation.setEnabled": {
        const automation = this.automations.get(command.id);
        if (!automation) throw new Error(`Unknown automation: ${command.id}`);
        const next = {
          ...automation,
          enabled: command.enabled,
          nextRunAtMs:
            command.enabled && automation.trigger?.kind !== "event"
              ? Date.now() + 60_000
              : undefined,
        };
        this.automations.set(command.id, next);
        this.emit({ type: "automation.changed", timestamp: now(), action: command.enabled ? "resumed" : "paused", automation: next });
        return { requestId: command.requestId };
      }
      case "automation.delete": {
        const automation = this.automations.get(command.id);
        if (!automation) throw new Error(`Unknown automation: ${command.id}`);
        this.automations.delete(command.id);
        this.emit({ type: "automation.changed", timestamp: now(), action: "deleted", automation });
        return { requestId: command.requestId };
      }
      case "automation.run": {
        const automation = this.automations.get(command.id);
        if (!automation) throw new Error(`Unknown automation: ${command.id}`);
        const next = { ...automation, lastRunAtMs: Date.now() };
        this.automations.set(command.id, next);
        this.emit({ type: "automation.changed", timestamp: now(), action: "running", automation: next });
        if (next.trigger?.kind === "event") {
          this.emit({
            type: "transcript.card",
            timestamp: now(),
            entryId: this.nextId("event"),
            card: {
              kind: "event",
              event: {
                source: next.trigger.source,
                event: next.trigger.event,
                title: `${listenerCopy[next.trigger.source][0]} event`,
                summary: `${next.trigger.event} woke routine “${next.name}”.`,
                fields: next.trigger.filter
                  ? [{ label: "Filter", value: next.trigger.filter }]
                  : undefined,
                occurredAtMs: Date.now(),
              },
            },
          });
        }
        const triggerContext =
          next.trigger?.kind === "event"
            ? `\n触发事件：${listenerCopy[next.trigger.source][0]} / ${next.trigger.event}`
            : "";
        return this.execute({
          type: "chat.send",
          requestId: command.requestId,
          text: `[自动化例程：${next.name}]${triggerContext}\n${next.prompt}`,
        });
      }
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
          interruptible: true,
        });
        this.emit({
          type: "model.routed",
          timestamp: now(),
          operationId,
          provider: "mahayana-mock",
          model: command.model ?? "auto",
          mode: command.mode ?? "agent",
        });
        this.emit({
          type: "agent.step",
          timestamp: now(),
          operationId,
          stepId: `${operationId}:context`,
          kind: "context",
          title: command.attachments?.length
            ? `读取 ${command.attachments.length} 个附件`
            : "分析请求",
          status: "completed",
          progress: 1,
          total: 1,
        });
        this.emit({
          type: "chat.message",
          timestamp: now(),
          role: "assistant",
          text: `收到：${command.text}`,
          operationId,
        });
        this.emit({
          type: "usage.updated",
          timestamp: now(),
          operationId,
          inputTokens: command.text.length,
          cachedInputTokens: 0,
          outputTokens: 8,
          reasoningTokens: 0,
          totalTokens: command.text.length + 8,
          contextWindow: 128_000,
        });
        this.emit({
          type: "operation.completed",
          timestamp: now(),
          operationId,
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
          kind: "capability",
        });
        return { requestId: command.requestId };
      }
      case "connector.list":
        this.emit({
          type: "connector.listed",
          timestamp: now(),
          connectors: [...this.connectors.values()],
        });
        return { requestId: command.requestId };
      case "connector.connect": {
        const connector = this.connectors.get(command.connectorId);
        if (!connector) throw new Error(`Unknown connector: ${command.connectorId}`);
        if (!connector.canAddAccount) throw new Error(`${connector.displayName} cannot add accounts`);
        this.emit({
          type: "connector.oauthRequested",
          timestamp: now(),
          connectorId: connector.id,
          authorizationUrl: `about:blank#fabushi-test-connector-${connector.id}`,
        });
        const accountLabel = command.accountLabel?.trim() || "Personal";
        const next: ConnectorSummary = {
          ...connector,
          status: "connected",
          accounts: [
            ...connector.accounts,
            {
              id: this.nextId("account"),
              label: accountLabel,
              status: "connected",
              teamManaged: false,
            },
          ],
        };
        this.connectors.set(next.id, next);
        this.emit({ type: "connector.changed", timestamp: now(), action: "connected", connector: next });
        const platform = next.id as ListenerPlatform;
        if (this.listenerIntegrations.has(platform)) {
          const integration = {
            ...this.listenerIntegrations.get(platform)!,
            isConnected: true,
            accountLabel,
          };
          this.listenerIntegrations.set(platform, integration);
          this.emit({ type: "listener.changed", timestamp: now(), integration });
        }
        return { requestId: command.requestId };
      }
      case "connector.renameAccount": {
        const connector = this.connectors.get(command.connectorId);
        if (!connector) throw new Error(`Unknown connector: ${command.connectorId}`);
        const account = connector.accounts.find((item) => item.id === command.accountId);
        if (!account) throw new Error(`Unknown connector account: ${command.accountId}`);
        if (account.teamManaged) throw new Error("Team-managed accounts cannot be renamed");
        if (!command.label.trim()) throw new Error("Account label must not be empty");
        const next = {
          ...connector,
          accounts: connector.accounts.map((item) =>
            item.id === command.accountId ? { ...item, label: command.label.trim() } : item,
          ),
        };
        this.connectors.set(next.id, next);
        this.emit({ type: "connector.changed", timestamp: now(), action: "updated", connector: next });
        return { requestId: command.requestId };
      }
      case "connector.removeAccount": {
        const connector = this.connectors.get(command.connectorId);
        if (!connector) throw new Error(`Unknown connector: ${command.connectorId}`);
        const account = connector.accounts.find((item) => item.id === command.accountId);
        if (!account) throw new Error(`Unknown connector account: ${command.accountId}`);
        if (account.teamManaged) throw new Error("Team-managed accounts cannot be removed");
        const accounts = connector.accounts.filter((item) => item.id !== command.accountId);
        const next: ConnectorSummary = {
          ...connector,
          accounts,
          status: accounts.length ? connector.status : "disconnected",
        };
        this.connectors.set(next.id, next);
        this.emit({ type: "connector.changed", timestamp: now(), action: "removed", connector: next });
        return { requestId: command.requestId };
      }
      case "connector.setToolEnabled": {
        const connector = this.connectors.get(command.connectorId);
        if (!connector) throw new Error(`Unknown connector: ${command.connectorId}`);
        if (!connector.tools.some((tool) => tool.id === command.toolId)) {
          throw new Error(`Unknown connector tool: ${command.toolId}`);
        }
        const next = {
          ...connector,
          tools: connector.tools.map((tool) =>
            tool.id === command.toolId ? { ...tool, enabled: command.enabled } : tool,
          ),
        };
        this.connectors.set(next.id, next);
        this.emit({ type: "connector.changed", timestamp: now(), action: "toolChanged", connector: next });
        return { requestId: command.requestId };
      }
      case "skill.list":
        this.emit({
          type: "skill.listed",
          timestamp: now(),
          skills: [...this.skills.values()].filter(
            (skill) => !command.agentId || skill.ownerAgentId === command.agentId,
          ),
          teams: defaultTeams(),
        });
        return { requestId: command.requestId };
      case "skill.upsert": {
        if (!command.name.trim()) throw new Error("Skill name must not be empty");
        if (!command.useWhen.trim()) throw new Error("Skill useWhen must not be empty");
        if (!command.instructions.trim()) throw new Error("Skill instructions must not be empty");
        const id = command.id ?? this.nextId("skill");
        const previous = this.skills.get(id);
        if (previous?.readOnly) throw new Error("Managed skills cannot be edited");
        const skill: SkillSummary = {
          id,
          name: command.name.trim(),
          description: command.description.trim(),
          useWhen: command.useWhen.trim(),
          instructions: command.instructions,
          source: previous?.source ?? "private",
          publishState: previous?.publishState ?? "local",
          ownerAgentId: command.ownerAgentId,
          teamId: previous?.teamId,
          teamName: previous?.teamName,
          readOnly: previous?.readOnly ?? false,
          updatedAtMs: Date.now(),
        };
        this.skills.set(id, skill);
        this.emit({
          type: "skill.changed",
          timestamp: now(),
          action: previous ? "updated" : "created",
          skill,
        });
        return { requestId: command.requestId };
      }
      case "skill.delete": {
        const skill = this.skills.get(command.id);
        if (!skill) throw new Error(`Unknown skill: ${command.id}`);
        if (skill.readOnly || skill.source === "team") throw new Error("Team-managed skills cannot be deleted");
        this.skills.delete(command.id);
        this.emit({ type: "skill.changed", timestamp: now(), action: "deleted", skill });
        return { requestId: command.requestId };
      }
      case "skill.publish": {
        const skill = this.skills.get(command.id);
        if (!skill) throw new Error(`Unknown skill: ${command.id}`);
        const team = defaultTeams().find((item) => item.id === command.teamId);
        if (!team) throw new Error(`Unknown skill team: ${command.teamId}`);
        if (!skill.description.trim()) throw new Error("Add a description first");
        const next: SkillSummary = {
          ...skill,
          source: "team",
          publishState: "published",
          teamId: team.id,
          teamName: team.name,
          updatedAtMs: Date.now(),
        };
        this.skills.set(next.id, next);
        this.emit({ type: "skill.changed", timestamp: now(), action: "published", skill: next });
        return { requestId: command.requestId };
      }
      case "skill.unpublish": {
        const skill = this.skills.get(command.id);
        if (!skill) throw new Error(`Unknown skill: ${command.id}`);
        if (skill.publishState === "managed") throw new Error("Managed skills cannot be unpublished");
        const next: SkillSummary = {
          ...skill,
          source: "private",
          publishState: "local",
          teamId: undefined,
          teamName: undefined,
          updatedAtMs: Date.now(),
        };
        this.skills.set(next.id, next);
        this.emit({ type: "skill.changed", timestamp: now(), action: "unpublished", skill: next });
        return { requestId: command.requestId };
      }
      case "skill.sync": {
        const skill = this.skills.get(command.id);
        if (!skill) throw new Error(`Unknown skill: ${command.id}`);
        if (!skill.teamId) throw new Error("Only published skills can be synced");
        const next: SkillSummary = { ...skill, publishState: "synced", updatedAtMs: Date.now() };
        this.skills.set(next.id, next);
        this.emit({ type: "skill.changed", timestamp: now(), action: "synced", skill: next });
        return { requestId: command.requestId };
      }
      case "bot.list":
        this.emit({ type: "bot.listed", timestamp: now(), bots: [...this.bots.values()] });
        return { requestId: command.requestId };
      case "bot.setHidden": {
        const bot = this.bots.get(command.id);
        if (!bot) throw new Error(`Unknown bot: ${command.id}`);
        const next = { ...bot, hidden: command.hidden };
        this.bots.set(next.id, next);
        this.emit({ type: "bot.changed", timestamp: now(), bot: next });
        return { requestId: command.requestId };
      }
      case "draft.resolve": {
        if (command.action === "send") validateDraft(command.draft);
        if (command.action === "send") {
          this.emit({
            type: "draft.changed",
            timestamp: now(),
            draftId: command.draft.id,
            status: "sending",
          });
        }
        this.emit({
          type: "draft.changed",
          timestamp: now(),
          draftId: command.draft.id,
          status: command.action === "send" ? "sent" : "discarded",
        });
        return { requestId: command.requestId };
      }
      case "secret.provide":
        if (!command.value) throw new Error("Secret value must not be empty");
        this.emit({
          type: "secret.provided",
          timestamp: now(),
          secretRequestId: command.secretRequestId,
        });
        return { requestId: command.requestId };
      case "listener.list":
        this.emit({
          type: "listener.listed",
          timestamp: now(),
          integrations: [...this.listenerIntegrations.values()],
        });
        return { requestId: command.requestId };
      case "listener.connect": {
        const integration = this.listenerIntegrations.get(command.platform);
        if (!integration) throw new Error(`Unsupported listener: ${command.platform}`);
        const next = { ...integration, isConnected: true, error: undefined };
        this.listenerIntegrations.set(command.platform, next);
        this.emit({ type: "listener.changed", timestamp: now(), integration: next });
        const connector = this.connectors.get(connectorForPlatform(command.platform));
        if (connector) {
          const connected: ConnectorSummary = { ...connector, status: "connected" };
          this.connectors.set(connected.id, connected);
          this.emit({ type: "connector.changed", timestamp: now(), action: "connected", connector: connected });
        }
        return { requestId: command.requestId };
      }
      case "update.status":
        this.emit({ type: "update.changed", timestamp: now(), state: this.updateState });
        return { requestId: command.requestId };
      case "update.check":
        this.updateState = { type: "checking" };
        this.emit({ type: "update.changed", timestamp: now(), state: this.updateState });
        this.updateState = { type: "upToDate", version: "0.1.0" };
        this.emit({ type: "update.changed", timestamp: now(), state: this.updateState });
        return { requestId: command.requestId };
      case "update.install": {
        const version =
          this.updateState.type === "available" ||
          this.updateState.type === "downloading" ||
          this.updateState.type === "staging" ||
          this.updateState.type === "ready"
            ? this.updateState.version
            : null;
        if (!version) throw new Error("No update is available to install");
        this.updateState = { type: "downloading", version, progress: 100 };
        this.emit({ type: "update.changed", timestamp: now(), state: this.updateState });
        this.updateState = { type: "ready", version };
        this.emit({ type: "update.changed", timestamp: now(), state: this.updateState });
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
    if (
      url.startsWith("about:blank#fabushi-test-oauth") ||
      url.startsWith("about:blank#fabushi-test-connector")
    ) return;
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
