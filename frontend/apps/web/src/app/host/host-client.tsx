import {
  mahayanaHostFeatures,
  type MahayanaHostFeatureId,
  type MahayanaHostFeatureState,
} from "@fabushi/shared";
import React, {
  useEffect,
  useMemo,
  useRef,
  useState,
  type FormEvent,
} from "react";
import styles from "./host.module.css";
import type {
  AgentMode,
  ApprovalRequestedEvent,
  AttachmentContext,
  AutomationSummary,
  AuthProvider,
  AuthProviderId,
  AuthState,
  BotSummary,
  CapabilitySummary,
  ConnectorSummary,
  ConversationSummary,
  ListenerIntegrationSummary,
  ListenerPlatform,
  MessageDraft,
  RuntimeCommand,
  SkillSummary,
  SkillTeamSummary,
  UpdateState,
} from "../../lib/mahayana-host/contracts";
import { MockMahayanaHostTransport } from "../../lib/mahayana-host/mock-transport";
import { isTauriMahayanaHostAvailable } from "../../lib/mahayana-host/tauri-transport";
import type { MahayanaHostTransport } from "../../lib/mahayana-host/transport";
import { estimateStringTokenCount } from "../../lib/grok-agent/token-estimate";
import { buildCurrentModeStatement } from "../../lib/grok-agent/agent-mode-guidance";
import { addLineNumbers } from "../../lib/grok-agent/formatting";
import { normalizeSchedule } from "../../lib/grok-agent/automation-schedule";
import {
  ExtensionStudio,
  MarketplaceTabs,
  type MarketplaceSection,
} from "./extension-studio";
import {
  RichMessage,
  TranscriptCardView,
  type TranscriptCardEntry,
} from "./rich-transcript";

const defaultMiniAppId = "global-dharma";

const marketplaceApps = [
  {
    id: "global-dharma",
    title: "全球法布施",
    description: "管理法布施任务、日志与部署状态",
    glyph: "法",
    tone: "violet",
  },
  {
    id: "faliu-flashcards",
    title: "法流记忆卡",
    description: "创建经文牌组并安排复习",
    glyph: "记",
    tone: "blue",
  },
  {
    id: "platform-publish",
    title: "平台发布",
    description: "创建草稿并发布到内容平台",
    glyph: "发",
    tone: "orange",
  },
  {
    id: "hermes-installer",
    title: "Hermes 安装器",
    description: "安装、启动并检查本地服务",
    glyph: "H",
    tone: "green",
  },
  {
    id: "bot-father",
    title: "Bot Father",
    description: "创建和管理自动化机器人",
    glyph: "B",
    tone: "pink",
  },
  {
    id: "mahayana-assistant",
    title: "大乘助手",
    description: "使用 Mahayana Runtime 完成复杂任务",
    glyph: "乘",
    tone: "cyan",
  },
  {
    id: "chatgpt-auto-confirm",
    title: "自动确认",
    description: "管理长任务授权与执行队列",
    glyph: "✓",
    tone: "yellow",
  },
] as const;

type FeatureStates = Record<
  MahayanaHostFeatureId,
  MahayanaHostFeatureState
>;

type AgentActivity = {
  id: string;
  operationId?: string;
  kind: string;
  title: string;
  detail?: string;
  status: "running" | "completed" | "failed";
};

type SettingsSection = "general" | "usage" | "updates";
type ThemePreference = "system" | "light" | "dark";

type HostPreferences = {
  theme: ThemePreference;
  notifyOnUpdates: boolean;
  autoUpdateWhenIdle: boolean;
  localExecution: boolean;
  routeEgressLocally: boolean;
  securityKeys: boolean;
  autoReviewRules: Array<{ id: string; behavior: "allow" | "ask"; text: string }>;
};

const defaultPreferences: HostPreferences = {
  theme: "system",
  notifyOnUpdates: true,
  autoUpdateWhenIdle: true,
  localExecution: true,
  routeEgressLocally: false,
  securityKeys: false,
  autoReviewRules: [],
};

const modelOptions = [
  { value: "auto", label: "自动选择" },
  { value: "deepseek-chat", label: "DeepSeek Chat" },
  { value: "deepseek-reasoner", label: "DeepSeek Reasoner" },
] as const;

const listenerOptions: Array<{
  value: ListenerPlatform;
  label: string;
  defaultEvent: string;
}> = [
  { value: "github", label: "GitHub", defaultEvent: "pull_request.opened" },
  { value: "git", label: "Git", defaultEvent: "commit.created" },
  { value: "slack", label: "Slack", defaultEvent: "mention.created" },
  { value: "teams", label: "Microsoft Teams", defaultEvent: "mention.created" },
  { value: "linear", label: "Linear", defaultEvent: "issue.updated" },
  { value: "sentry", label: "Sentry", defaultEvent: "issue.regressed" },
  { value: "pagerduty", label: "PagerDuty", defaultEvent: "incident.triggered" },
];

function automationTriggerLabel(automation: AutomationSummary): string {
  const trigger = automation.trigger;
  if (trigger?.kind === "event") {
    const source = listenerOptions.find(
      (option) => option.value === trigger.source,
    )?.label ?? trigger.source;
    return `${source} · ${trigger.event}`;
  }
  return automation.trigger?.kind === "schedule"
    ? automation.trigger.schedule
    : automation.schedule;
}

function automationRunLabel(automation: AutomationSummary): string {
  if (!automation.enabled) return "已暂停";
  if (automation.trigger?.kind === "event") return "等待事件";
  return automation.nextRunAtMs
    ? `下次 ${new Date(automation.nextRunAtMs).toLocaleString()}`
    : "等待调度";
}

function updateStateCopy(state: UpdateState): {
  title: string;
  detail: string;
  action: "check" | "install" | null;
} {
  switch (state.type) {
    case "loading":
      return { title: "正在读取更新状态", detail: "请稍候…", action: null };
    case "disabled":
      return { title: "当前构建不支持自动更新", detail: state.reason, action: null };
    case "checking":
      return { title: "正在检查更新", detail: "正在联系更新服务…", action: null };
    case "available":
      return { title: `发现版本 ${state.version}`, detail: state.notes || "可以下载并安装更新。", action: "install" };
    case "downloading":
      return { title: `正在下载 ${state.version}`, detail: state.progress === undefined ? "下载中…" : `${state.progress}%`, action: null };
    case "staging":
      return { title: `正在准备 ${state.version}`, detail: "安装包正在验证。", action: null };
    case "ready":
      return { title: `${state.version} 已可安装`, detail: "重新启动客户端以完成更新。", action: "install" };
    case "upToDate":
      return { title: "当前已是最新版本", detail: `Fabushi ${state.version} · Mahayana Runtime`, action: "check" };
    case "error":
      return { title: "检查更新失败", detail: state.message, action: "check" };
  }
}

function createInitialFeatureStates(): FeatureStates {
  return Object.fromEntries(
    mahayanaHostFeatures.map((feature) => [feature.id, "pending"]),
  ) as FeatureStates;
}

function Icon({
  name,
  size = 18,
}: {
  name:
    | "plus"
    | "search"
    | "plugins"
    | "settings"
    | "send"
    | "close"
    | "stop"
    | "shield"
    | "attach"
    | "network"
    | "automation"
    | "computer";
  size?: number;
}) {
  const paths = {
    plus: <path d="M12 5v14M5 12h14" />,
    search: <><circle cx="11" cy="11" r="7" /><path d="m20 20-4-4" /></>,
    plugins: <path d="M8 3v4H4v4h4v4H4v4h4v2h4v-4h4v4h4v-4h-4v-4h4V9h-4V5h-4v4h-2V3H8Zm2 8h4v4h-4v-4Z" />,
    settings: <><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .34 1.88l.06.06-2.83 2.83-.06-.06A1.7 1.7 0 0 0 15 19.4a1.7 1.7 0 0 0-1 .6 1.7 1.7 0 0 0-.4 1.1V21h-4v-.1A1.7 1.7 0 0 0 8.6 19.4a1.7 1.7 0 0 0-1.88.34l-.06.06-2.83-2.83.06-.06A1.7 1.7 0 0 0 4.6 15a1.7 1.7 0 0 0-1.5-1H3v-4h.1A1.7 1.7 0 0 0 4.6 9a1.7 1.7 0 0 0-.34-1.88l-.06-.06 2.83-2.83.06.06A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-1.5V3h4v.1A1.7 1.7 0 0 0 15 4.6a1.7 1.7 0 0 0 1.88-.34l.06-.06 2.83 2.83-.06.06A1.7 1.7 0 0 0 19.4 9a1.7 1.7 0 0 0 1.5 1h.1v4h-.1a1.7 1.7 0 0 0-1.5 1Z" /></>,
    send: <path d="m4 4 17 8-17 8 3-8-3-8Zm3 8h14" />,
    close: <path d="m6 6 12 12M18 6 6 18" />,
    stop: <rect x="6" y="6" width="12" height="12" rx="2" />,
    shield: <path d="M12 3 5 6v5c0 4.5 2.8 8.3 7 10 4.2-1.7 7-5.5 7-10V6l-7-3Z" />,
    attach: <path d="m20.5 11.5-8.9 8.9a5 5 0 0 1-7.1-7.1l9.6-9.6a3.5 3.5 0 0 1 5 5l-9.7 9.7a2 2 0 0 1-2.8-2.8l8.9-8.9" />,
    network: <><circle cx="12" cy="5" r="2.5" /><circle cx="5" cy="18" r="2.5" /><circle cx="19" cy="18" r="2.5" /><path d="m10.8 7.2-4.5 8.4m6.9-8.4 4.5 8.4M7.5 18h9" /></>,
    automation: <><circle cx="12" cy="12" r="8" /><path d="M12 8v4l3 2M5.5 5.5 3 3m15.5 2.5L21 3" /></>,
    computer: <><rect x="3" y="4" width="18" height="13" rx="2" /><path d="M8 21h8m-4-4v4" /></>,
  };
  return (
    <svg
      aria-hidden="true"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill={name === "plugins" ? "currentColor" : "none"}
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {paths[name]}
    </svg>
  );
}

export default function HostClient() {
  const screenshotMode = new URLSearchParams(window.location.search).get("screenshot");
  const screenshotHasMiniApp = screenshotMode === "miniapp";
  const screenshotComputerOpen = ["computer", "running", "miniapp"].includes(screenshotMode ?? "");
  const transport = useMemo<MahayanaHostTransport>(
    () => new MockMahayanaHostTransport({ authenticated: screenshotMode !== null }),
    [screenshotMode],
  );
  const requestSequence = useRef(0);
  const attachmentInput = useRef<HTMLInputElement>(null);
  const [hostStatus, setHostStatus] = useState("initializing");
  const [input, setInput] = useState("");
  const [messages, setMessages] = useState<
    Array<{
      role: "user" | "assistant";
      text: string;
      operationId?: string;
    }>
  >([]);
  const [installedMiniApps, setInstalledMiniApps] = useState<Set<string>>(
    () => new Set(screenshotHasMiniApp ? [defaultMiniAppId] : []),
  );
  const [openedMiniApp, setOpenedMiniApp] = useState<string | null>(
    screenshotHasMiniApp ? defaultMiniAppId : null,
  );
  const [openedMiniAppHtml, setOpenedMiniAppHtml] = useState<string | null>(
    screenshotHasMiniApp
      ? '<!doctype html><html lang="zh-CN"><body style="font:15px system-ui;background:#101722;color:#edf3ff;padding:20px"><h1>全球法流</h1><p>MiniApp 已在隔离容器中打开，可通过受控能力与宿主通信。</p></body></html>'
      : null,
  );
  const [approval, setApproval] = useState<ApprovalRequestedEvent | null>(null);
  const [approvalState, setApprovalState] = useState("not-requested");
  const [activeOperationId, setActiveOperationId] = useState<string | null>(
    screenshotMode === "running" ? "operation-screenshot" : null,
  );
  const [operationState, setOperationState] = useState(screenshotMode === "running" ? "running" : "idle");
  const [sessionState, setSessionState] = useState("active");
  const [featureStates, setFeatureStates] = useState<FeatureStates>(
    createInitialFeatureStates,
  );
  const [error, setError] = useState<string | null>(null);
  const [marketplaceOpen, setMarketplaceOpen] = useState(screenshotMode === "marketplace");
  const [marketplaceSection, setMarketplaceSection] = useState<MarketplaceSection>("apps");
  const [networkOpen, setNetworkOpen] = useState(false);
  const [automationOpen, setAutomationOpen] = useState(screenshotMode === "automation");
  const [computerOpen, setComputerOpen] = useState(screenshotComputerOpen);
  const [agentSettingsOpen, setAgentSettingsOpen] = useState(false);
  const [agentTitle, setAgentTitle] = useState("");
  const [agentDescription, setAgentDescription] = useState("");
  const [agentNotifications, setAgentNotifications] = useState(true);
  const [marketplaceSearch, setMarketplaceSearch] = useState("");
  const [busyMiniApp, setBusyMiniApp] = useState<string | null>(null);
  const [auth, setAuth] = useState<AuthState | null>(null);
  const [loginUsername, setLoginUsername] = useState("");
  const [loginPassword, setLoginPassword] = useState("");
  const [loginBusy, setLoginBusy] = useState(false);
  const [loginProvider, setLoginProvider] = useState<AuthProviderId | null>(null);
  const [loginError, setLoginError] = useState<string | null>(null);
  const [authProviders, setAuthProviders] = useState<AuthProvider[]>([]);
  const [loginOptionsOpen, setLoginOptionsOpen] = useState(false);
  const [onboardingStep, setOnboardingStep] = useState(0);
  const [passwordLoginOpen, setPasswordLoginOpen] = useState(false);
  const [accountOpen, setAccountOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(screenshotMode === "settings");
  const [settingsSection, setSettingsSection] = useState<SettingsSection>("general");
  const [preferences, setPreferences] = useState<HostPreferences>(defaultPreferences);
  const [ruleDraft, setRuleDraft] = useState("");
  const [ruleBehavior, setRuleBehavior] = useState<"allow" | "ask">("allow");
  const [activeAgentId, setActiveAgentId] = useState("mahayana-assistant");
  const [activeConversationId, setActiveConversationId] = useState<string | null>(null);
  const [conversations, setConversations] = useState<ConversationSummary[]>([]);
  const [capabilities, setCapabilities] = useState<CapabilitySummary[]>([]);
  const [automations, setAutomations] = useState<AutomationSummary[]>([]);
  const [connectors, setConnectors] = useState<ConnectorSummary[]>([]);
  const [skills, setSkills] = useState<SkillSummary[]>([]);
  const [skillTeams, setSkillTeams] = useState<SkillTeamSummary[]>([]);
  const [bots, setBots] = useState<BotSummary[]>([]);
  const [listenerIntegrations, setListenerIntegrations] = useState<ListenerIntegrationSummary[]>([]);
  const [connectingListeners, setConnectingListeners] = useState<Set<ListenerPlatform>>(
    () => new Set(),
  );
  const [updateState, setUpdateState] = useState<UpdateState>({ type: "loading" });
  const [transcriptCards, setTranscriptCards] = useState<TranscriptCardEntry[]>([]);
  const [automationName, setAutomationName] = useState("");
  const [automationPrompt, setAutomationPrompt] = useState("");
  const [automationSchedule, setAutomationSchedule] = useState("@daily");
  const [automationTriggerKind, setAutomationTriggerKind] = useState<"schedule" | "event">("schedule");
  const [automationEventSource, setAutomationEventSource] = useState<ListenerPlatform>("github");
  const [automationEventName, setAutomationEventName] = useState("pull_request.opened");
  const [automationEventFilter, setAutomationEventFilter] = useState("");
  const [editingAutomationId, setEditingAutomationId] = useState<string | null>(null);
  const [conversationSearch, setConversationSearch] = useState("");
  const [agentMode, setAgentMode] = useState<AgentMode>("agent");
  const [selectedModel, setSelectedModel] = useState("auto");
  const [attachments, setAttachments] = useState<AttachmentContext[]>([]);
  const [activity, setActivity] = useState<AgentActivity[]>([]);
  const [usage, setUsage] = useState<{
    totalTokens: number;
    contextWindow?: number;
    model: string;
  } | null>(null);

  useEffect(() => {
    try {
      const stored = window.localStorage.getItem("fabushi.host.preferences.v1");
      if (stored) {
        setPreferences({ ...defaultPreferences, ...JSON.parse(stored) });
      }
    } catch {
      // A damaged preference should never prevent the host from starting.
    }
  }, []);

  useEffect(() => {
    window.localStorage.setItem(
      "fabushi.host.preferences.v1",
      JSON.stringify(preferences),
    );
  }, [preferences]);

  useEffect(() => {
    const pass = (featureId: MahayanaHostFeatureId) => {
      setFeatureStates((current) => ({
        ...current,
        [featureId]: "passed",
      }));
    };

    const unsubscribe = transport.subscribe((event) => {
      switch (event.type) {
        case "host.ready":
          setHostStatus("ready");
          pass("runtime.boot");
          break;
        case "chat.message":
          setMessages((current) => {
            if (event.role === "assistant" && event.operationId) {
              const index = current.findIndex(
                (message) => message.operationId === event.operationId,
              );
              if (index >= 0) {
                return current.map((message, messageIndex) =>
                  messageIndex === index
                    ? { ...message, text: event.text }
                    : message,
                );
              }
            }
            return [
              ...current,
              {
                role: event.role,
                text: event.text,
                operationId: event.operationId,
              },
            ];
          });
          if (event.role === "assistant") pass("chat.send");
          break;
        case "chat.delta":
          setMessages((current) => {
            const index = current.findIndex(
              (message) => message.operationId === event.operationId,
            );
            if (index < 0) {
              return [
                ...current,
                {
                  role: "assistant",
                  text: event.delta,
                  operationId: event.operationId,
                },
              ];
            }
            return current.map((message, messageIndex) =>
              messageIndex === index
                ? { ...message, text: `${message.text}${event.delta}` }
                : message,
            );
          });
          break;
        case "transcript.card":
          setTranscriptCards((current) => {
            const entry = {
              entryId: event.entryId,
              operationId: event.operationId,
              card: event.card,
            };
            const index = current.findIndex((item) => item.entryId === event.entryId);
            return index < 0
              ? [...current, entry]
              : current.map((item, itemIndex) => itemIndex === index ? entry : item);
          });
          break;
        case "draft.changed":
          setTranscriptCards((current) => current.map((entry) => {
            if (
              (entry.card.kind === "emailDraft" || entry.card.kind === "slackDraft") &&
              entry.card.draft.id === event.draftId
            ) {
              return {
                ...entry,
                card: {
                  ...entry.card,
                  draft: {
                    ...entry.card.draft,
                    status: event.status,
                    error: event.error,
                  },
                },
              } as TranscriptCardEntry;
            }
            return entry;
          }));
          break;
        case "secret.provided":
          setTranscriptCards((current) => current.map((entry) =>
            entry.card.kind === "secretRequest" &&
            entry.card.requestId === event.secretRequestId
              ? { ...entry, card: { ...entry.card, provided: true } }
              : entry,
          ));
          break;
        case "conversation.listed":
          setConversations(event.conversations);
          break;
        case "capability.listed":
          setCapabilities(event.capabilities);
          break;
        case "automation.listed":
          setAutomations(event.automations);
          break;
        case "automation.changed":
          setAutomations((current) => {
            if (event.action === "deleted") {
              return current.filter((item) => item.id !== event.automation.id);
            }
            const index = current.findIndex((item) => item.id === event.automation.id);
            return index < 0
              ? [...current, event.automation]
              : current.map((item, itemIndex) => itemIndex === index ? event.automation : item);
          });
          break;
        case "connector.listed":
          setConnectors(event.connectors);
          break;
        case "connector.changed":
          setConnectors((current) => {
            const index = current.findIndex((item) => item.id === event.connector.id);
            return index < 0
              ? [...current, event.connector]
              : current.map((item, itemIndex) => itemIndex === index ? event.connector : item);
          });
          break;
        case "connector.oauthRequested":
          void transport.openExternal(event.authorizationUrl).catch((cause: unknown) => {
            setError(cause instanceof Error ? cause.message : String(cause));
          });
          break;
        case "skill.listed":
          setSkills(event.skills);
          setSkillTeams(event.teams);
          break;
        case "skill.changed":
          setSkills((current) => {
            if (event.action === "deleted") {
              return current.filter((item) => item.id !== event.skill.id);
            }
            const index = current.findIndex((item) => item.id === event.skill.id);
            return index < 0
              ? [...current, event.skill]
              : current.map((item, itemIndex) => itemIndex === index ? event.skill : item);
          });
          break;
        case "bot.listed":
          setBots(event.bots);
          break;
        case "bot.changed":
          setBots((current) => {
            const index = current.findIndex((item) => item.id === event.bot.id);
            return index < 0
              ? [...current, event.bot]
              : current.map((item, itemIndex) => itemIndex === index ? event.bot : item);
          });
          break;
        case "listener.listed":
          setListenerIntegrations(event.integrations);
          break;
        case "listener.changed":
          setListenerIntegrations((current) => {
            const index = current.findIndex((item) => item.platform === event.integration.platform);
            return index < 0
              ? [...current, event.integration]
              : current.map((item, itemIndex) => itemIndex === index ? event.integration : item);
          });
          setConnectingListeners((current) => {
            if (!current.has(event.integration.platform)) return current;
            const next = new Set(current);
            next.delete(event.integration.platform);
            return next;
          });
          setTranscriptCards((current) => current.map((entry) =>
            entry.card.kind === "listenerConnect" &&
            entry.card.platform === event.integration.platform
              ? {
                  ...entry,
                  card: {
                    ...entry.card,
                    connected: event.integration.isConnected,
                    pending: false,
                  },
                }
              : entry,
          ));
          break;
        case "update.changed":
          setUpdateState(event.state);
          break;
        case "conversation.opened":
          setActiveConversationId(event.conversationId);
          setActiveAgentId("mahayana-assistant");
          setTranscriptCards([]);
          setMessages(
            event.messages.map((message) => ({
              role: message.role,
              text: message.text,
            })),
          );
          break;
        case "agent.step":
          setActivity((current) => {
            const next: AgentActivity = {
              id: event.stepId,
              operationId: event.operationId,
              kind: event.kind,
              title: event.title,
              detail: event.detail,
              status: event.status,
            };
            const index = current.findIndex(
              (item) =>
                item.id === event.stepId &&
                item.operationId === event.operationId,
            );
            return index < 0
              ? [...current.slice(-11), next]
              : current.map((item, itemIndex) =>
                  itemIndex === index ? next : item,
                );
          });
          break;
        case "model.routed":
          setUsage((current) => ({
            totalTokens: current?.totalTokens ?? 0,
            contextWindow: current?.contextWindow,
            model: event.model,
          }));
          setActivity((current) => [
            ...current.slice(-11),
            {
              id: `${event.operationId}:model`,
              operationId: event.operationId,
              kind: "model",
              title: event.model === "auto" ? "自动选择模型" : event.model,
              detail: `${event.provider} · ${event.mode}`,
              status: "completed",
            },
          ]);
          break;
        case "usage.updated":
          setUsage((current) => ({
            totalTokens: event.totalTokens,
            contextWindow: event.contextWindow,
            model: current?.model ?? "auto",
          }));
          break;
        case "marketplace.installed":
          setInstalledMiniApps((current) => {
            const next = new Set(current);
            next.add(event.miniAppId);
            window.localStorage.setItem(
              "fabushi.installed-miniapps",
              JSON.stringify([...next]),
            );
            return next;
          });
          setBusyMiniApp(null);
          void transport.execute({
            type: "capability.list",
            requestId: `capability-refresh-${Date.now()}`,
          });
          pass("marketplace.install");
          break;
        case "miniapp.opened":
          setOpenedMiniApp(event.miniAppId);
          setOpenedMiniAppHtml(event.html ?? null);
          setActiveAgentId(event.miniAppId);
          setMarketplaceOpen(false);
          setComputerOpen(true);
          setBusyMiniApp(null);
          pass("miniapp.open");
          break;
        case "approval.requested":
          setApproval(event);
          setApprovalState("pending");
          break;
        case "approval.resolved":
          setApproval(null);
          setApprovalState(
            event.decision === "allow-once"
              ? "allowed-once"
              : event.decision === "allow-session"
                ? "allowed-for-session"
                : "denied",
          );
          pass("capability.approval");
          break;
        case "operation.started":
          if (event.interruptible) {
            setActiveOperationId(event.operationId);
            setOperationState("running");
          }
          break;
        case "operation.interrupted":
          setActiveOperationId(null);
          setOperationState("interrupted");
          pass("operation.interrupt");
          break;
        case "operation.completed":
          setActiveOperationId((current) =>
            current === event.operationId ? null : current,
          );
          setOperationState((current) =>
            current === "running" ? "completed" : current,
          );
          break;
        case "operation.failed":
          setActiveOperationId((current) =>
            current === event.operationId ? null : current,
          );
          setOperationState("failed");
          setError(`${event.code}: ${event.message}`);
          break;
        case "session.cleared":
          setSessionState("cleared");
          setAuth({ loggedIn: false });
          pass("session.clear");
          break;
        case "host.closed":
          setHostStatus("closed");
          break;
      }
    });

    const configuredMode =
      typeof process !== "undefined"
        ? process.env.NEXT_PUBLIC_MAHAYANA_HOST_MODE
        : undefined;
    const mode =
      configuredMode === "production" || configuredMode === "test"
        ? configuredMode
        : isTauriMahayanaHostAvailable()
          ? "production"
          : "test";

    void transport
      .initialize({ profileId: "default", mode })
      .then(async () => {
        await transport.execute({
          type: "conversation.list",
          requestId: "conversation-list-initial",
        });
        await transport.execute({
          type: "capability.list",
          requestId: "capability-list-initial",
        });
        await transport.execute({
          type: "automation.list",
          requestId: "automation-list-initial",
        });
        await Promise.all([
          transport.execute({
            type: "connector.list",
            requestId: "connector-list-initial",
          }),
          transport.execute({
            type: "skill.list",
            requestId: "skill-list-initial",
          }),
          transport.execute({
            type: "bot.list",
            requestId: "bot-list-initial",
          }),
          transport.execute({
            type: "listener.list",
            requestId: "listener-list-initial",
          }),
          transport.execute({
            type: "update.status",
            requestId: "update-status-initial",
          }),
        ]);
        try {
          setAuthProviders(
            (
              await Promise.race([
                transport.authProviders(),
                new Promise<AuthProvider[]>((_, reject) =>
                  window.setTimeout(
                    () => reject(new Error("登录方式发现超时")),
                    4_000,
                  ),
                ),
              ])
            ).filter((provider) => provider.enabled),
          );
        } catch {
          // Provider discovery is server-owned. Password login remains the
          // safe fallback when an older deployment has not enabled OAuth yet.
          setAuthProviders([]);
        }
        try {
          const authState = await Promise.race([
            transport.authStatus(),
            new Promise<never>((_, reject) =>
              window.setTimeout(
                () => reject(new Error("账号服务响应超时，请重新登录")),
                8_000,
              ),
            ),
          ]);
          setAuth(authState);
          if (authState.loggedIn) {
            setFeatureStates((current) => ({ ...current, "auth.login": "passed" }));
          }
        } catch (cause: unknown) {
          setAuth({ loggedIn: false });
          setLoginError(
            `无法恢复账号会话：${cause instanceof Error ? cause.message : String(cause)}`,
          );
        }
        const stored = JSON.parse(
          window.localStorage.getItem("fabushi.installed-miniapps") ?? "[]",
        ) as unknown;
        if (Array.isArray(stored)) {
          for (const miniAppId of stored.filter(
            (value): value is string => typeof value === "string",
          )) {
            try {
              await transport.execute({
                type: "marketplace.install",
                requestId: `restore-${miniAppId}`,
                miniAppId,
              });
            } catch {
              // A removed or unavailable plugin should not prevent the Host
              // from starting; its stale local entry is replaced by events.
            }
          }
        }
      })
      .catch((cause: unknown) => {
        setHostStatus("failed");
        setError(cause instanceof Error ? cause.message : String(cause));
      });

    return () => {
      unsubscribe();
      void transport.close();
    };
  }, [transport]);

  const nextRequestId = (prefix: string) => {
    requestSequence.current += 1;
    return `${prefix}-${requestSequence.current}`;
  };

  const run = async (action: () => Promise<unknown>) => {
    setError(null);
    try {
      await action();
    } catch (cause: unknown) {
      setBusyMiniApp(null);
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  };

  const execute = (command: RuntimeCommand) => transport.execute(command);

  const sendMessage = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const text = input.trim();
    if (!text) return;
    setInput("");
    const outgoingAttachments = attachments;
    setAttachments([]);
    await run(() =>
      execute({
        type: "chat.send",
        requestId: nextRequestId("chat"),
        text,
        agentId: activeAgentId,
        conversationId: activeConversationId ?? undefined,
        mode: agentMode,
        modeStatement: buildCurrentModeStatement(
          agentMode === "ask" ? "chat" : agentMode,
        ),
        model: selectedModel === "auto" ? undefined : selectedModel,
        attachments: outgoingAttachments,
      }),
    );
  };

  const attachFiles = async (files: FileList | null) => {
    if (!files?.length) return;
    const next: AttachmentContext[] = [];
    for (const file of [...files].slice(0, 6)) {
      if (file.size > 1_500_000) {
        setError(`${file.name} 超过 1.5 MB，暂未添加`);
        continue;
      }
      next.push({
        id: `${file.name}-${file.lastModified}-${file.size}`,
        name: file.name,
        mimeType: file.type || undefined,
        text: await file.text(),
      });
    }
    setAttachments((current) => [...current, ...next].slice(0, 6));
    if (attachmentInput.current) attachmentInput.current.value = "";
  };

  const login = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!loginUsername.trim() || !loginPassword) {
      setLoginError("请输入账号和密码");
      return;
    }
    setLoginBusy(true);
    setLoginError(null);
    try {
      const state = await transport.passwordLogin(
        loginUsername.trim(),
        loginPassword,
      );
      setAuth({ ...state, loggedIn: true });
      setFeatureStates((current) => ({ ...current, "auth.login": "passed" }));
      setLoginPassword("");
    } catch (cause: unknown) {
      setLoginError(cause instanceof Error ? cause.message : String(cause));
    } finally {
      setLoginBusy(false);
    }
  };

  const logout = async () => {
    await run(async () => {
      const state = await transport.logout();
      setAuth({ ...state, loggedIn: false });
      setAccountOpen(false);
    });
  };

  const oauthLogin = async (provider: AuthProviderId) => {
    setLoginBusy(true);
    setLoginProvider(provider);
    setLoginError(null);
    try {
      const attempt = await transport.oauthStart(provider);
      await transport.openExternal(attempt.authorizationUrl);
      for (let poll = 0; poll < 160; poll += 1) {
        const result = await transport.oauthPoll(attempt.attemptId);
        if (result.status === "completed" && result.auth) {
          setAuth({ ...result.auth, loggedIn: true });
          setFeatureStates((current) => ({ ...current, "auth.login": "passed" }));
          return;
        }
        if (result.status !== "pending") throw new Error("登录链接已失效，请重新登录");
        await new Promise((resolve) => window.setTimeout(resolve, 750));
      }
      throw new Error("等待登录超时，请重试");
    } catch (cause: unknown) {
      setLoginError(cause instanceof Error ? cause.message : String(cause));
    } finally {
      setLoginBusy(false);
      setLoginProvider(null);
    }
  };

  const providerIcon = (provider: AuthProviderId) => {
    const labels: Record<AuthProviderId, string> = {
      google: "G",
      apple: "●",
      microsoft: "⊞",
      github: "⌘",
    };
    return <span className={`${styles.providerIcon} ${styles[provider]}`}>{labels[provider]}</span>;
  };

  const installMiniApp = (miniAppId: string) => {
    setBusyMiniApp(miniAppId);
    void run(() =>
      execute({
        type: "marketplace.install",
        requestId: nextRequestId("install"),
        miniAppId,
      }),
    );
  };

  const openMiniApp = (miniAppId: string) => {
    setBusyMiniApp(miniAppId);
    void run(() =>
      execute({
        type: "miniapp.open",
        requestId: nextRequestId("open"),
        miniAppId,
      }),
    );
  };

  const resolveDraft = (draft: MessageDraft, action: "send" | "discard") => {
    void run(() =>
      execute({
        type: "draft.resolve",
        requestId: nextRequestId("draft"),
        draft,
        action,
      }),
    );
  };

  const provideSecret = (secretRequestId: string, value: string) => {
    void run(() =>
      execute({
        type: "secret.provide",
        requestId: nextRequestId("secret"),
        secretRequestId,
        value,
      }),
    );
  };

  const connectListener = (platform: ListenerPlatform) => {
    setConnectingListeners((current) => new Set(current).add(platform));
    setTranscriptCards((current) => current.map((entry) =>
      entry.card.kind === "listenerConnect" && entry.card.platform === platform
        ? { ...entry, card: { ...entry.card, pending: true } }
        : entry,
    ));
    void run(async () => {
      try {
        await execute({
          type: "listener.connect",
          requestId: nextRequestId("listener-connect"),
          platform,
        });
      } finally {
        setConnectingListeners((current) => {
          if (!current.has(platform)) return current;
          const next = new Set(current);
          next.delete(platform);
          return next;
        });
        setTranscriptCards((current) => current.map((entry) =>
          entry.card.kind === "listenerConnect" && entry.card.platform === platform
            ? { ...entry, card: { ...entry.card, pending: false } }
            : entry,
        ));
      }
    });
  };

  const visibleMarketplaceApps = marketplaceApps.filter((app) =>
    `${app.title} ${app.id} ${app.description}`
      .toLowerCase()
      .includes(marketplaceSearch.toLowerCase()),
  );
  const visibleConversations = conversations.filter((conversation) =>
    `${conversation.title} ${conversation.id}`
      .toLowerCase()
      .includes(conversationSearch.toLowerCase()),
  );
  const activeMiniApp = marketplaceApps.find((app) => app.id === openedMiniApp);
  const activeAgent =
    activeAgentId === "mahayana-assistant"
      ? undefined
      : marketplaceApps.find((app) => app.id === activeAgentId);
  const displayName =
    auth?.user?.nickname || auth?.user?.username || "大乘用户";
  const attachmentTokens = attachments.reduce(
    (total, attachment) => total + estimateStringTokenCount(attachment.text ?? ""),
    0,
  );
  const mentionMatch = input.match(/(?:^|\s)@([^\s@]*)$/);
  const mentionQuery = mentionMatch?.[1]?.toLowerCase() ?? null;
  const mentionSuggestions = mentionQuery === null
    ? []
    : capabilities
        .filter((capability) => capability.availability !== "unavailable")
        .filter((capability) =>
          `${capability.id} ${capability.title} ${capability.description}`
            .toLowerCase()
            .includes(mentionQuery),
        )
        .slice(0, 6);
  const effectiveTheme =
    preferences.theme === "system" ? "dark" : preferences.theme;
  const updateCopy = updateStateCopy(updateState);
  const selectedListenerIntegration = listenerIntegrations.find(
    (integration) => integration.platform === automationEventSource,
  );
  const selectedListenerNeededByCount = automations.filter(
    (automation) =>
      automation.enabled &&
      automation.trigger?.kind === "event" &&
      automation.trigger.source === automationEventSource,
  ).length;
  const selectedListenerState = connectingListeners.has(automationEventSource)
    ? "connecting"
    : selectedListenerIntegration?.error
      ? "error"
      : selectedListenerIntegration?.isConnected
        ? "listening"
        : "idle";
  const selectedListenerStateCopy = {
    idle: "尚未连接",
    connecting: "正在连接",
    listening: "正在监听",
    error: "连接异常",
  }[selectedListenerState];
  const visibleSidebarBots = bots.filter(
    (bot) => !bot.hidden && bot.id !== "mahayana-assistant",
  );

  const setPreference = <Key extends keyof HostPreferences>(
    key: Key,
    value: HostPreferences[Key],
  ) => setPreferences((current) => ({ ...current, [key]: value }));

  const addAutoReviewRule = () => {
    const text = ruleDraft.trim();
    if (!text) return;
    setPreferences((current) => ({
      ...current,
      autoReviewRules: [
        ...current.autoReviewRules,
        { id: `rule-${Date.now()}`, behavior: ruleBehavior, text },
      ],
    }));
    setRuleDraft("");
  };

  const resetAutomationDraft = () => {
    setEditingAutomationId(null);
    setAutomationName("");
    setAutomationPrompt("");
    setAutomationSchedule("@daily");
    setAutomationTriggerKind("schedule");
    setAutomationEventSource("github");
    setAutomationEventName("pull_request.opened");
    setAutomationEventFilter("");
  };

  const editAutomation = (automation: AutomationSummary) => {
    setEditingAutomationId(automation.id);
    setAutomationName(automation.name);
    setAutomationPrompt(automation.prompt);
    if (automation.trigger?.kind === "event") {
      setAutomationTriggerKind("event");
      setAutomationEventSource(automation.trigger.source);
      setAutomationEventName(automation.trigger.event);
      setAutomationEventFilter(automation.trigger.filter ?? "");
      setAutomationSchedule("@daily");
    } else {
      setAutomationTriggerKind("schedule");
      setAutomationSchedule(
        automation.trigger?.kind === "schedule"
          ? automation.trigger.schedule
          : automation.schedule,
      );
    }
  };

  const saveAutomation = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const trigger = automationTriggerKind === "event"
      ? {
          kind: "event" as const,
          source: automationEventSource,
          event: automationEventName.trim(),
          filter: automationEventFilter.trim() || undefined,
        }
      : {
          kind: "schedule" as const,
          schedule: normalizeSchedule(automationSchedule),
        };
    await run(() => execute({
      type: "automation.upsert",
      requestId: nextRequestId("automation"),
      id: editingAutomationId ?? undefined,
      name: automationName.trim(),
      prompt: automationPrompt.trim(),
      schedule:
        trigger.kind === "schedule"
          ? trigger.schedule
          : `event:${trigger.source}:${trigger.event}`,
      trigger,
      enabled: true,
    }));
    resetAutomationDraft();
  };

  return (
    <main className={styles.shell} data-theme={effectiveTheme} data-testid="mahayana-host">
      <aside className={styles.sidebar}>
        <div className={styles.titlebar}>
          <div className={styles.trafficLights} aria-hidden="true">
            <span />
            <span />
            <span />
          </div>
          <strong>Fabushi</strong>
          <div className={styles.titleActions}>
            <button className={styles.iconButton} type="button" aria-label="智能体网络" onClick={() => setNetworkOpen(true)}>
              <Icon name="network" />
            </button>
            <button
              className={styles.iconButton}
              type="button"
              aria-label="新建会话"
              onClick={() => {
                setMessages([]);
                setTranscriptCards([]);
                setActivity([]);
                setUsage(null);
                setActiveConversationId(null);
                setActiveAgentId("mahayana-assistant");
              }}
            >
              <Icon name="plus" />
            </button>
          </div>
        </div>

        <label className={styles.searchBox}>
          <Icon name="search" size={16} />
          <input
            aria-label="搜索会话"
            placeholder="搜索"
            value={conversationSearch}
            onChange={(event) => setConversationSearch(event.target.value)}
          />
        </label>

        <nav className={styles.agentList} aria-label="智能体会话">
          <button
            className={activeAgentId === "mahayana-assistant" ? styles.agentActive : styles.agentItem}
            type="button"
            onClick={() => setActiveAgentId("mahayana-assistant")}
          >
            <span className={styles.avatar}>乘</span>
            <span className={styles.agentCopy}>
              <span><strong>大乘助手</strong><time>现在</time></span>
              <small>{operationState === "running" ? "正在工作…" : "Mahayana Runtime 已连接"}</small>
            </span>
          </button>
          {visibleConversations
            .filter((conversation) => conversation.id !== "codex:agent:assistant")
            .map((conversation) => (
              <button
                key={conversation.id}
                className={activeConversationId === conversation.id ? styles.agentActive : styles.agentItem}
                type="button"
                onClick={() =>
                  void run(() =>
                    execute({
                      type: "conversation.open",
                      requestId: nextRequestId("conversation"),
                      conversationId: conversation.id,
                    }),
                  )
                }
              >
                <span className={styles.avatarAlt}>聊</span>
                <span className={styles.agentCopy}>
                  <span><strong>{conversation.title}</strong></span>
                  <small>{conversation.kind} · {conversation.unreadCount ? `${conversation.unreadCount} 条未读` : "历史会话"}</small>
                </span>
              </button>
            ))}
          {visibleSidebarBots.map((bot) => (
            <button
              key={bot.id}
              className={activeConversationId === bot.conversationId ? styles.agentActive : styles.agentItem}
              type="button"
              onClick={() => {
                setActiveAgentId(bot.id);
                const existingConversation = bot.conversationId
                  ? conversations.find((conversation) => conversation.id === bot.conversationId)
                  : undefined;
                if (existingConversation) {
                  void run(() =>
                    execute({
                      type: "conversation.open",
                      requestId: nextRequestId("bot-conversation"),
                      conversationId: existingConversation.id,
                    }),
                  );
                } else {
                  setActiveConversationId(null);
                  setMessages([]);
                  setTranscriptCards([]);
                  setActivity([]);
                  setUsage(null);
                }
              }}
            >
              <span className={styles.avatarAlt}>{bot.name.slice(0, 1)}</span>
              <span className={styles.agentCopy}>
                <span><strong>{bot.name}</strong></span>
                <small>{bot.description}</small>
              </span>
            </button>
          ))}
          {[...installedMiniApps].map((miniAppId) => {
            const app = marketplaceApps.find((item) => item.id === miniAppId);
            if (!app || app.id === "mahayana-assistant") return null;
            return (
              <button
                key={app.id}
                data-testid={`agent-${app.id}`}
                className={activeAgentId === app.id ? styles.agentActive : styles.agentItem}
                type="button"
                onClick={() => {
                  setActiveAgentId(app.id);
                  if (openedMiniApp !== app.id) openMiniApp(app.id);
                }}
              >
                <span className={styles.avatarAlt}>{app.glyph}</span>
                <span className={styles.agentCopy}>
                  <span><strong>{app.title}机器人</strong></span>
                  <small>{openedMiniApp === app.id ? "应用已打开" : app.description}</small>
                </span>
              </button>
            );
          })}
        </nav>

        <div className={styles.sidebarFooter}>
          <button className={styles.footerButton} type="button" onClick={() => setAutomationOpen(true)}>
            <Icon name="automation" />
            <span>自动化例程</span>
            <em>{automations.length}</em>
          </button>
          <button
            data-testid="open-marketplace"
            className={styles.footerButton}
            type="button"
            onClick={() => setMarketplaceOpen(true)}
          >
            <Icon name="plugins" />
            <span>插件市场</span>
            <em>{installedMiniApps.size}</em>
          </button>
          <button
            className={styles.profileButton}
            data-testid="account-menu"
            type="button"
            onClick={() => setSettingsOpen(true)}
          >
            <span className={styles.profileAvatar}>{displayName.slice(0, 1)}</span>
            <span>{displayName}</span>
            <Icon name="settings" size={17} />
          </button>
        </div>
      </aside>

      <section className={styles.workspace}>
        <header className={styles.chatHeader}>
          <div className={styles.headerIdentity}>
            <span className={styles.headerAvatar}>{activeAgent?.glyph ?? "乘"}</span>
            <div>
              <h1>{activeAgent ? `${activeAgent.title}机器人` : "大乘助手"}</h1>
              <p>{activeAgent ? `${activeAgent.description} · Mahayana MiniApp` : "Mahayana Rust Core · 本地优先"}</p>
            </div>
          </div>
          <output
            className={styles.runtimeStatus}
            data-state={hostStatus}
            data-testid="host-status"
            aria-live="polite"
          >
            <span />
            {hostStatus}
          </output>
          <button
            className={styles.computerButton}
            type="button"
            aria-label="大乘助手的电脑"
            aria-expanded={computerOpen}
            onClick={() => setComputerOpen((current) => !current)}
          >
            <Icon name="computer" size={16} />
          </button>
        </header>

        {error ? <p role="alert" className={styles.error}>{error}</p> : null}

        <div className={styles.conversation}>
          <div className={styles.welcome}>
            <span className={styles.welcomeAvatar}>{activeAgent?.glyph ?? "乘"}</span>
            <h2>{activeAgent ? `${activeAgent.title}已连接` : "有什么可以帮你？"}</h2>
            <p>{activeAgent ? "可以在右侧打开应用，也可以通过大乘助手调用它的能力。" : "发送消息、运行任务，或从插件市场为助手添加能力。"}</p>
          </div>
          <div className={styles.messages} data-testid="messages" aria-live="polite">
            {messages.map((message, index) => (
              <article
                key={`${message.role}-${index}`}
                data-testid={`message-${message.role}`}
                className={message.role === "user" ? styles.userMessage : styles.assistantMessage}
              >
                {message.role === "assistant" ? <span className={styles.messageAvatar}>乘</span> : null}
                <div>
                  <strong>{message.role === "user" ? "你" : activeAgent ? `${activeAgent.title}机器人` : "大乘助手"}</strong>
                  {message.role === "assistant"
                    ? <RichMessage text={message.text} />
                    : <p>{message.text}</p>}
                </div>
              </article>
            ))}
            {transcriptCards.length ? (
              <div className={styles.transcriptCards}>
                {transcriptCards.map((entry) => (
                  <TranscriptCardView
                    key={entry.entryId}
                    entry={entry}
                    onResolveDraft={resolveDraft}
                    onProvideSecret={provideSecret}
                    onConnectListener={connectListener}
                  />
                ))}
              </div>
            ) : null}
          </div>

          <form className={styles.composer} onSubmit={(event) => void sendMessage(event)}>
            {mentionSuggestions.length ? (
              <div className={styles.mentionMenu} role="listbox" aria-label="能力引用建议">
                {mentionSuggestions.map((capability) => (
                  <button
                    key={capability.id}
                    type="button"
                    role="option"
                    onClick={() => {
                      setInput((current) =>
                        current.replace(/@[^\s@]*$/, `${capability.mention} `),
                      );
                    }}
                  >
                    <span>{capability.title.slice(0, 1)}</span>
                    <div><strong>{capability.title}</strong><small>{capability.mention} · {capability.kind}</small></div>
                    {capability.requiredPermissions.length ? <em>需权限</em> : null}
                  </button>
                ))}
              </div>
            ) : null}
            {attachments.length ? (
              <div className={styles.attachmentList}>
                {attachments.map((attachment) => (
                  <span key={attachment.id}>
                    <Icon name="attach" size={13} /> {attachment.name}
                    <button
                      type="button"
                      aria-label={`移除 ${attachment.name}`}
                      onClick={() =>
                        setAttachments((current) =>
                          current.filter((item) => item.id !== attachment.id),
                        )
                      }
                    >
                      ×
                    </button>
                  </span>
                ))}
                <small>约 {attachmentTokens.toLocaleString()} tokens</small>
              </div>
            ) : null}
            <textarea
              data-testid="chat-input"
              aria-label="消息内容"
              value={input}
              rows={1}
              onChange={(event) => setInput(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter" && !event.shiftKey) {
                  event.preventDefault();
                  event.currentTarget.form?.requestSubmit();
                }
              }}
              placeholder={activeAgent ? `给${activeAgent.title}机器人发消息…` : "描述任务，@ 引用文件，或让大乘助手执行操作…"}
              disabled={hostStatus !== "ready"}
            />
            <div className={styles.composerToolbar}>
              <input
                ref={attachmentInput}
                className={styles.fileInput}
                type="file"
                multiple
                onChange={(event) => void attachFiles(event.target.files)}
              />
              <button
                className={styles.toolButton}
                type="button"
                aria-label="添加附件"
                onClick={() => attachmentInput.current?.click()}
              >
                <Icon name="attach" size={17} />
              </button>
              <select
                data-testid="agent-mode"
                aria-label="Agent 模式"
                value={agentMode}
                onChange={(event) => setAgentMode(event.target.value as AgentMode)}
              >
                <option value="agent">Agent</option>
                <option value="ask">问答</option>
                <option value="plan">计划</option>
              </select>
              <select
                data-testid="agent-model"
                aria-label="模型"
                value={selectedModel}
                onChange={(event) => setSelectedModel(event.target.value)}
              >
                {modelOptions.map((model) => (
                  <option key={model.value} value={model.value}>{model.label}</option>
                ))}
              </select>
              <span className={styles.toolbarSpacer} />
              {activeOperationId ? (
                <button
                  className={styles.sendButton}
                  type="button"
                  aria-label="停止任务"
                  onClick={() => void run(() => transport.interrupt(activeOperationId))}
                >
                  <Icon name="stop" />
                </button>
              ) : (
                <button
                  className={styles.sendButton}
                  data-testid="send-message"
                  type="submit"
                  disabled={hostStatus !== "ready" || !input.trim()}
                  aria-label="发送消息"
                >
                  <Icon name="send" />
                </button>
              )}
            </div>
          </form>
        </div>
      </section>

      {computerOpen ? <aside className={styles.activityPanel}>
        <div className={styles.computerPanelHeader}>
          {agentSettingsOpen ? <strong>设置</strong> : <button type="button" aria-label="智能体设置" onClick={() => setAgentSettingsOpen(true)}><Icon name="settings" size={15} /></button>}
          <button type="button" aria-label="关闭电脑面板" onClick={() => setComputerOpen(false)}><Icon name="close" size={16} /></button>
        </div>
        {agentSettingsOpen ? (
          <section className={styles.agentSettingsPanel}>
            <button type="button" onClick={() => setAgentSettingsOpen(false)}>← 返回电脑与例程</button>
            <span className={styles.agentSettingsAvatar}>乘</span>
            <label><span>名称</span><input value="大乘助手" readOnly /></label>
            <label><span>职衔</span><input value={agentTitle} onChange={(event) => setAgentTitle(event.target.value)} placeholder="描述这个智能体的工作" /></label>
            <label><span>描述</span><textarea value={agentDescription} onChange={(event) => setAgentDescription(event.target.value)} placeholder="这个智能体用于什么" rows={4} /></label>
            <label className={styles.agentNotification}><span><strong>通知</strong><small>智能体完成工作或需要输入时通知我</small></span><input type="checkbox" checked={agentNotifications} onChange={(event) => setAgentNotifications(event.target.checked)} /></label>
          </section>
        ) : (
          <>
            <section className={styles.computerPreview}>
              <div><span className={operationState === "running" ? styles.computerPulse : undefined} /></div>
              <small>大乘助手的屏幕</small>
            </section>
            <section className={styles.routineShortcut}>
              <p>例程是这个智能体按计划反复执行的任务。</p>
              <button type="button" onClick={() => setAutomationOpen(true)}>创建例程</button>
            </section>
          </>
        )}
        <div className={styles.activityHeader}>
          <div>
            <span className={styles.activityKicker}>WORKSPACE</span>
            <h2>运行与能力</h2>
          </div>
          <span className={styles.secureBadge}><Icon name="shield" size={14} /> 本地</span>
        </div>

        <section className={styles.agentRunCard}>
          <div className={styles.cardHeading}>
            <div>
              <strong>Agent 活动</strong>
              <small>{activity.length ? `${activity.length} 个步骤` : "等待任务"}</small>
            </div>
            {usage ? <span className={styles.tokenBadge}>{usage.totalTokens.toLocaleString()} tokens</span> : null}
          </div>
          {activity.length ? (
            <ol className={styles.activityTimeline} data-testid="agent-activity">
              {activity.map((item, index) => (
                <li key={`${item.operationId ?? "runtime"}-${item.id}-${index}`} data-state={item.status}>
                  <i />
                  <div>
                    <strong>{item.title}</strong>
                    {item.detail ? (
                      <details>
                        <summary>{item.kind === "shell" ? "查看终端输出" : "查看详情"}</summary>
                        <pre>{item.kind === "shell" ? addLineNumbers({ gpt5CodexCatN: true }, item.detail, 1) : item.detail}</pre>
                      </details>
                    ) : null}
                  </div>
                </li>
              ))}
            </ol>
          ) : (
            <p className={styles.emptyActivity}>模型选择、工具调用和执行进度会显示在这里。</p>
          )}
          {usage?.contextWindow ? (
            <div className={styles.contextUsage}>
              <span style={{ width: `${Math.min(100, usage.totalTokens / usage.contextWindow * 100)}%` }} />
              <small>{usage.model} · 上下文 {Math.round(usage.totalTokens / usage.contextWindow * 100)}%</small>
            </div>
          ) : null}
        </section>

        <section className={styles.controlCard}>
          <div className={styles.cardHeading}>
            <div>
              <strong>Runtime 任务</strong>
              <small data-testid="operation-state">{operationState}</small>
            </div>
            <span data-state={operationState} className={styles.stateDot} />
          </div>
          <div className={styles.controlActions}>
            <button
              data-testid="start-long-operation"
              type="button"
              onClick={() =>
                void run(() =>
                  execute({
                    type: "runtime.longTask",
                    requestId: nextRequestId("long-task"),
                    label: "长任务测试",
                  }),
                )
              }
            >
              启动长任务
            </button>
            <button
              data-testid="interrupt-operation"
              type="button"
              disabled={!activeOperationId}
              onClick={() =>
                activeOperationId
                  ? void run(() => transport.interrupt(activeOperationId))
                  : undefined
              }
            >
              <Icon name="stop" size={15} /> 中断
            </button>
          </div>
        </section>

        <section className={styles.controlCard}>
          <div className={styles.cardHeading}>
            <div>
              <strong>安全会话</strong>
              <small data-testid="session-state">{sessionState}</small>
            </div>
          </div>
          <button
            className={styles.fullButton}
            data-testid="clear-session"
            type="button"
            onClick={() =>
              void run(() =>
                execute({
                  type: "session.clear",
                  requestId: nextRequestId("session"),
                }),
              )
            }
          >
            清除本地会话
          </button>
        </section>

        {activeMiniApp ? (
          <section className={styles.miniAppPanel} data-testid="miniapp-panel">
            <div className={`${styles.marketIcon} ${styles[activeMiniApp.tone]}`}>
              {activeMiniApp.glyph}
            </div>
            <div>
              <strong>{activeMiniApp.title}</strong>
              <small>{activeMiniApp.id}</small>
            </div>
            <p>隔离 MiniApp 容器已打开。</p>
            {openedMiniAppHtml ? (
              <iframe
                className={styles.miniAppFrame}
                data-testid="miniapp-frame"
                title={`${activeMiniApp.title}应用`}
                sandbox="allow-scripts"
                srcDoc={openedMiniAppHtml}
              />
            ) : null}
            <button
              data-testid="request-capability"
              type="button"
              onClick={() =>
                void run(() =>
                  execute({
                    type: "capability.request",
                    requestId: nextRequestId("capability"),
                    miniAppId: activeMiniApp.id,
                    capability: "microphone.request",
                    reason: "为语音布施功能录制音频",
                  }),
                )
              }
            >
              请求麦克风权限
            </button>
            <output data-testid="approval-state">{approvalState}</output>
          </section>
        ) : (
          <button
            className={styles.emptyMiniApp}
            type="button"
            onClick={() => setMarketplaceOpen(true)}
          >
            <Icon name="plugins" />
            <span><strong>添加插件</strong><small>扩展助手能力</small></span>
          </button>
        )}

        <section className={styles.coverageCard}>
          <div className={styles.coverageTitle}>
            <strong>自动化覆盖</strong>
            <span>{Object.values(featureStates).filter((state) => state === "passed").length}/{mahayanaHostFeatures.length}</span>
          </div>
          <ul data-testid="feature-coverage">
            {mahayanaHostFeatures.map((feature) => (
              <li
                key={feature.id}
                data-testid={`feature-result-${feature.id}`}
                data-state={featureStates[feature.id]}
              >
                <span>{feature.label}</span>
                <i />
              </li>
            ))}
          </ul>
        </section>
      </aside> : null}

      {marketplaceOpen ? (
        <div className={styles.backdrop} onMouseDown={() => setMarketplaceOpen(false)}>
          <section
            className={styles.marketplace}
            role="dialog"
            aria-modal="true"
            aria-labelledby="marketplace-title"
            onMouseDown={(event) => event.stopPropagation()}
          >
            <header>
              <div>
                <p>FABUSHI EXTENSIONS</p>
                <h2 id="marketplace-title">插件市场</h2>
                <span>为所有智能体安装官方 Mahayana 插件。</span>
              </div>
              <button
                className={styles.iconButton}
                type="button"
                aria-label="关闭插件市场"
                onClick={() => setMarketplaceOpen(false)}
              >
                <Icon name="close" />
              </button>
            </header>

            <MarketplaceTabs
              section={marketplaceSection}
              onChange={setMarketplaceSection}
              counts={{
                apps: marketplaceApps.length,
                connectors: connectors.length,
                skills: skills.length,
                bots: bots.length,
              }}
            />

            <label className={styles.marketSearch}>
              <Icon name="search" size={16} />
              <input
                value={marketplaceSearch}
                onChange={(event) => setMarketplaceSearch(event.target.value)}
                placeholder={marketplaceSection === "apps" ? "搜索插件" : `搜索 ${marketplaceSection}`}
              />
            </label>

            {marketplaceSection === "apps" ? (
              <div className={styles.marketList}>
              {visibleMarketplaceApps.map((app) => {
                const installed = installedMiniApps.has(app.id);
                const busy = busyMiniApp === app.id;
                return (
                  <article key={app.id} className={styles.marketRow}>
                    <div className={`${styles.marketIcon} ${styles[app.tone]}`}>
                      {app.glyph}
                    </div>
                    <div className={styles.marketCopy}>
                      <div>
                        <strong>{app.title}</strong>
                        {installed ? <span className={styles.connectedDot} /> : null}
                      </div>
                      <p>{app.description}</p>
                    </div>
                    <button
                      data-testid={app.id === defaultMiniAppId ? "install-miniapp" : `install-${app.id}`}
                      type="button"
                      disabled={installed || busy}
                      onClick={() => installMiniApp(app.id)}
                    >
                      {busy ? "安装中…" : installed ? "已安装" : "安装"}
                    </button>
                    <button
                      data-testid={app.id === defaultMiniAppId ? "open-miniapp" : `open-${app.id}`}
                      type="button"
                      disabled={!installed || busy}
                      onClick={() => openMiniApp(app.id)}
                    >
                      打开
                    </button>
                    {app.id === defaultMiniAppId ? (
                      <output className={styles.srOnly} data-testid="marketplace-state">
                        {installed ? "installed" : "not-installed"}
                      </output>
                    ) : null}
                  </article>
                );
              })}
              {visibleMarketplaceApps.length === 0 ? (
                <p className={styles.noResults}>没有匹配的插件。</p>
              ) : null}
              </div>
            ) : (
              <ExtensionStudio
                section={marketplaceSection}
                connectors={connectors}
                skills={skills}
                skillTeams={skillTeams}
                bots={bots}
                search={marketplaceSearch}
                execute={execute}
                nextRequestId={nextRequestId}
                run={run}
              />
            )}
          </section>
        </div>
      ) : null}

      {networkOpen ? (
        <div className={styles.backdrop} onMouseDown={() => setNetworkOpen(false)}>
          <section className={styles.networkDialog} role="dialog" aria-modal="true" aria-labelledby="network-title" onMouseDown={(event) => event.stopPropagation()}>
            <header>
              <div><p>AGENT NETWORK</p><h2 id="network-title">智能体网络</h2><span>查看 Agents、Bots、插件和联系人之间的能力关系。</span></div>
              <button className={styles.iconButton} type="button" aria-label="关闭智能体网络" onClick={() => setNetworkOpen(false)}><Icon name="close" /></button>
            </header>
            <div className={styles.networkCanvas}>
              <span className={styles.networkLine} />
              <article className={styles.networkHub}>
                <span>乘</span><strong>大乘助手</strong><small>Agent · Codex</small>
              </article>
              <div className={styles.networkNodes}>
                {capabilities.filter((capability) => capability.id !== "agent.mahayana").map((capability) => (
                  <button key={capability.id} type="button" disabled={capability.availability === "unavailable"} onClick={() => {
                    if (capability.pluginId) {
                      setNetworkOpen(false);
                      setMarketplaceOpen(true);
                      setMarketplaceSearch(capability.pluginId);
                    }
                  }}>
                    <span>{capability.title.slice(0, 1)}</span>
                    <strong>{capability.title}</strong>
                    <small>{capability.kind} · {capability.availability}</small>
                  </button>
                ))}
              </div>
              {capabilities.length <= 1 ? (
                <div className={styles.networkEmpty}><Icon name="network" size={26} /><strong>还没有其他智能体</strong><p>安装几个 Bot 或插件后，网络关系会显示在这里。</p><button type="button" onClick={() => { setNetworkOpen(false); setMarketplaceOpen(true); }}>打开插件市场</button></div>
              ) : null}
            </div>
          </section>
        </div>
      ) : null}

      {automationOpen ? (
        <div className={styles.backdrop} onMouseDown={() => setAutomationOpen(false)}>
          <section className={styles.automationDialog} role="dialog" aria-modal="true" aria-labelledby="automation-title" onMouseDown={(event) => event.stopPropagation()}>
            <header>
              <div><p>ALWAYS-ON ROUTINES</p><h2 id="automation-title">自动化例程</h2><span>按计划或外部事件唤醒大乘助手，执行保存的 standing instruction。</span></div>
              <button className={styles.iconButton} type="button" aria-label="关闭自动化" onClick={() => setAutomationOpen(false)}><Icon name="close" /></button>
            </header>
            <div className={styles.automationBody}>
              <div className={styles.automationList}>
                {automations.map((automation) => (
                  <article key={automation.id}>
                    <span data-enabled={automation.enabled}><Icon name="automation" size={15} /></span>
                    <div><strong>{automation.name}</strong><p>{automation.prompt}</p><small>{automationTriggerLabel(automation)} · {automationRunLabel(automation)}</small></div>
                    <div className={styles.automationActions}>
                      <button type="button" onClick={() => void run(() => execute({ type: "automation.run", requestId: nextRequestId("automation-run"), id: automation.id }))}>运行</button>
                      <button type="button" onClick={() => void run(() => execute({ type: "automation.setEnabled", requestId: nextRequestId("automation-toggle"), id: automation.id, enabled: !automation.enabled }))}>{automation.enabled ? "暂停" : "恢复"}</button>
                      <button type="button" onClick={() => editAutomation(automation)}>编辑</button>
                      <button type="button" onClick={() => void run(() => execute({ type: "automation.delete", requestId: nextRequestId("automation-delete"), id: automation.id }))}>删除</button>
                    </div>
                  </article>
                ))}
                {!automations.length ? <div className={styles.automationEmpty}><Icon name="automation" size={25} /><strong>还没有例程</strong><p>创建一个日报、周期检查或提醒。</p></div> : null}
              </div>
              <form className={styles.automationForm} onSubmit={(event) => void saveAutomation(event)}>
                <h3>{editingAutomationId ? "编辑例程" : "新建例程"}</h3>
                <label><span>名称</span><input value={automationName} onChange={(event) => setAutomationName(event.target.value)} placeholder="例如：早间摘要" required /></label>
                <label><span>执行指令</span><textarea value={automationPrompt} onChange={(event) => setAutomationPrompt(event.target.value)} placeholder="告诉智能体每次唤醒后要完成什么" rows={6} required /></label>
                <fieldset className={styles.triggerPicker}>
                  <legend>触发方式</legend>
                  <label><input type="radio" name="automation-trigger" checked={automationTriggerKind === "schedule"} onChange={() => setAutomationTriggerKind("schedule")} /><span>计划</span></label>
                  <label><input type="radio" name="automation-trigger" checked={automationTriggerKind === "event"} onChange={() => setAutomationTriggerKind("event")} /><span>事件</span></label>
                </fieldset>
                {automationTriggerKind === "schedule" ? (
                  <label><span>计划</span><input value={automationSchedule} onChange={(event) => setAutomationSchedule(event.target.value)} placeholder="@daily 或 0 9 * * 1-5" required /><small>支持 5 段 cron、@hourly、@daily、@weekly 与 @every 5m。</small></label>
                ) : (
                  <div className={styles.eventTriggerFields}>
                    <label><span>事件来源</span><select value={automationEventSource} onChange={(event) => {
                      const source = event.target.value as ListenerPlatform;
                      setAutomationEventSource(source);
                      const option = listenerOptions.find((item) => item.value === source);
                      if (option) setAutomationEventName(option.defaultEvent);
                    }}>{listenerOptions.map((option) => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>
                    <label><span>事件</span><input value={automationEventName} onChange={(event) => setAutomationEventName(event.target.value)} placeholder="pull_request.opened" required /></label>
                    <label><span>过滤条件（可选）</span><input value={automationEventFilter} onChange={(event) => setAutomationEventFilter(event.target.value)} placeholder="例如：repository == org/repo" /></label>
                    <div className={styles.listenerStatus} data-state={selectedListenerState}>
                      <span aria-hidden="true" />
                      <div>
                        <strong>{selectedListenerIntegration?.displayName ?? automationEventSource}</strong>
                        <small>{selectedListenerIntegration?.isConnected ? selectedListenerIntegration.accountLabel || "监听器已连接" : selectedListenerIntegration?.blurb || "需要连接事件来源"}</small>
                        <em>{selectedListenerStateCopy} · {selectedListenerNeededByCount ? `${selectedListenerNeededByCount} 个启用例程依赖此来源` : "暂无启用例程依赖此来源"}</em>
                        {selectedListenerIntegration?.error ? <b>{selectedListenerIntegration.error}</b> : null}
                      </div>
                      {!selectedListenerIntegration?.isConnected ? <button type="button" disabled={selectedListenerState === "connecting"} onClick={() => connectListener(automationEventSource)}>{selectedListenerState === "connecting" ? "连接中…" : "连接"}</button> : null}
                    </div>
                  </div>
                )}
                <div><button type="button" onClick={resetAutomationDraft}>清空</button><button type="submit">{editingAutomationId ? "保存修改" : "创建例程"}</button></div>
              </form>
            </div>
          </section>
        </div>
      ) : null}

      {settingsOpen ? (
        <div className={styles.backdrop} onMouseDown={() => setSettingsOpen(false)}>
          <section
            className={styles.settingsDialog}
            role="dialog"
            aria-modal="true"
            aria-labelledby="settings-title"
            onMouseDown={(event) => event.stopPropagation()}
          >
            <aside className={styles.settingsNav}>
              <div className={styles.settingsBrand}>
                <span className={styles.profileAvatar}>{displayName.slice(0, 1)}</span>
                <div><strong>{displayName}</strong><small>{auth?.user?.email || auth?.provider || "本地账户"}</small></div>
              </div>
              <p>设置分区</p>
              {([
                ["general", "通用", "General"],
                ["usage", "用量与计费", "Usage & Billing"],
                ["updates", "更新", "Updates"],
              ] as const).map(([id, label, english]) => (
                <button
                  key={id}
                  type="button"
                  className={settingsSection === id ? styles.settingsNavActive : undefined}
                  onClick={() => setSettingsSection(id)}
                >
                  <span>{label}</span><small>{english}</small>
                </button>
              ))}
              <span className={styles.settingsNavSpacer} />
              <button type="button" onClick={() => { setSettingsOpen(false); setAccountOpen(true); }}>
                <span>账户</span><small>Account</small>
              </button>
            </aside>

            <div className={styles.settingsContent}>
              <header>
                <div>
                  <p>GROK BOT SETTINGS</p>
                  <h2 id="settings-title">
                    {settingsSection === "general" ? "通用设置" : settingsSection === "usage" ? "用量与计费" : "Grok Bot 更新"}
                  </h2>
                </div>
                <button className={styles.iconButton} type="button" aria-label="关闭设置" onClick={() => setSettingsOpen(false)}>
                  <Icon name="close" />
                </button>
              </header>

              {settingsSection === "general" ? (
                <div className={styles.settingsSections}>
                  <SettingsGroup title="外观" description="Appearance">
                    <label className={styles.settingsRow}>
                      <span><strong>主题</strong><small>跟随系统，或固定使用浅色/深色主题。</small></span>
                      <select value={preferences.theme} onChange={(event) => setPreference("theme", event.target.value as ThemePreference)}>
                        <option value="system">跟随系统</option><option value="light">浅色</option><option value="dark">深色</option>
                      </select>
                    </label>
                  </SettingsGroup>

                  <SettingsGroup title="通知" description="Notifications">
                    <ToggleRow
                      checked={preferences.notifyOnUpdates}
                      label="任务状态通知"
                      description="智能体完成任务或需要输入时通知我。"
                      onChange={(value) => setPreference("notifyOnUpdates", value)}
                    />
                  </SettingsGroup>

                  <SettingsGroup title="本机能力" description="Execution on Local Computer">
                    <ToggleRow
                      checked={preferences.localExecution}
                      label="允许在本机执行"
                      description="允许助手打开文件并在这台电脑上运行任务；自动审批仍会检查每个操作。"
                      onChange={(value) => setPreference("localExecution", value)}
                    />
                    <ToggleRow
                      checked={preferences.routeEgressLocally}
                      label="通过此桌面路由网络出口"
                      description="让智能体的新网络连接通过这台电脑，而不是云端出口。"
                      onChange={(value) => setPreference("routeEgressLocally", value)}
                    />
                    <ToggleRow
                      checked={preferences.securityKeys}
                      label="使用硬件安全密钥"
                      description="允许智能体请求使用连接到电脑的安全密钥，每次使用仍需确认。"
                      onChange={(value) => setPreference("securityKeys", value)}
                    />
                  </SettingsGroup>

                  <SettingsGroup title="自动审批" description="Auto-review Rules">
                    <p className={styles.settingsHelp}>内置安全检查始终生效；“先询问”规则在冲突时优先。</p>
                    <div className={styles.ruleComposer}>
                      <input value={ruleDraft} onChange={(event) => setRuleDraft(event.target.value)} placeholder="例如：允许为我运行只读测试" />
                      <select value={ruleBehavior} onChange={(event) => setRuleBehavior(event.target.value as "allow" | "ask")}>
                        <option value="allow">自动允许</option><option value="ask">先询问</option>
                      </select>
                      <button type="button" disabled={!ruleDraft.trim()} onClick={addAutoReviewRule}>添加规则</button>
                    </div>
                    {preferences.autoReviewRules.length ? (
                      <ul className={styles.ruleList}>
                        {preferences.autoReviewRules.map((rule) => (
                          <li key={rule.id}>
                            <span data-behavior={rule.behavior}>{rule.behavior === "allow" ? "允许" : "询问"}</span>
                            <p>{rule.text}</p>
                            <button type="button" aria-label={`删除规则 ${rule.text}`} onClick={() => setPreference("autoReviewRules", preferences.autoReviewRules.filter((item) => item.id !== rule.id))}>×</button>
                          </li>
                        ))}
                      </ul>
                    ) : <p className={styles.settingsEmpty}>尚未添加自定义规则。</p>}
                  </SettingsGroup>
                </div>
              ) : settingsSection === "usage" ? (
                <div className={styles.settingsSections}>
                  <SettingsGroup title="当前用量" description="Usage & Billing">
                    <div className={styles.usageSummary}>
                      <strong>{usage ? usage.totalTokens.toLocaleString() : "0"}</strong>
                      <span>本次会话 tokens</span>
                      <i><b style={{ width: usage?.contextWindow ? `${Math.min(100, usage.totalTokens / usage.contextWindow * 100)}%` : "0%" }} /></i>
                      <small>{usage?.model || selectedModel} · {usage?.contextWindow ? `${usage.contextWindow.toLocaleString()} 上下文窗口` : "等待首次模型调用"}</small>
                    </div>
                  </SettingsGroup>
                  <SettingsGroup title="按需用量" description="On-demand usage">
                    <p className={styles.settingsHelp}>当前运行时由本地大乘 CLI 管理模型账户与配额；这里显示实际运行事件返回的用量。</p>
                  </SettingsGroup>
                </div>
              ) : (
                <div className={styles.settingsSections}>
                  <SettingsGroup title="Grok Bot 更新" description="Updates">
                    <div className={styles.updateCard} data-state={updateState.type}>
                      <span className={styles.updateIcon}>{updateState.type === "error" ? "!" : updateState.type === "checking" || updateState.type === "downloading" || updateState.type === "staging" ? "↻" : "✓"}</span>
                      <div><strong>{updateCopy.title}</strong><small>{updateCopy.detail}</small></div>
                      {updateCopy.action ? (
                        <button
                          type="button"
                          onClick={() => void run(() => execute({
                            type: updateCopy.action === "check" ? "update.check" : "update.install",
                            requestId: nextRequestId(`update-${updateCopy.action}`),
                          }))}
                        >
                          {updateCopy.action === "check" ? "检查更新" : updateState.type === "ready" ? "重新安装" : "下载并安装"}
                        </button>
                      ) : null}
                    </div>
                    <ToggleRow
                      checked={preferences.autoUpdateWhenIdle}
                      label="空闲时自动更新"
                      description="在不影响进行中任务时自动安装客户端更新。"
                      onChange={(value) => setPreference("autoUpdateWhenIdle", value)}
                    />
                  </SettingsGroup>
                </div>
              )}
            </div>
          </section>
        </div>
      ) : null}

      {approval ? (
        <div className={styles.backdrop}>
          <section className={styles.approvalDialog} role="dialog" aria-modal="true" aria-labelledby="approval-title">
            <span className={styles.approvalIcon}><Icon name="shield" size={24} /></span>
            <h2 id="approval-title">
              {approval.kind === "command"
                ? "运行命令？"
                : approval.kind === "connectedService"
                  ? "连接外部服务？"
                  : approval.kind === "automation"
                    ? "允许自动化操作？"
                    : "能力审批"}
            </h2>
            <p><strong>{approval.miniAppId}</strong> 请求 {approval.capability}</p>
            {approval.subject ? <pre className={styles.approvalSubject}>{approval.subject}</pre> : null}
            <small>{approval.detail || approval.reason}</small>
            {approval.location ? <span className={styles.approvalLocation}>执行位置：{approval.location}</span> : null}
            {approval.proposedRule ? <div className={styles.approvalRule}><strong>以后自动允许</strong><code>{approval.proposedRule}</code></div> : null}
            <div>
              <button
                data-testid="deny-capability"
                type="button"
                onClick={() =>
                  void run(() =>
                    transport.resolveApproval({
                      approvalId: approval.approvalId,
                      decision: "deny",
                    }),
                  )
                }
              >
                拒绝
              </button>
              <button
                data-testid="approve-capability"
                type="button"
                onClick={() =>
                  void run(() =>
                    transport.resolveApproval({
                      approvalId: approval.approvalId,
                      decision: "allow-once",
                    }),
                  )
                }
              >
                本次允许
              </button>
              <button
                data-testid="approve-capability-session"
                type="button"
                onClick={() =>
                  void run(() =>
                    transport.resolveApproval({
                      approvalId: approval.approvalId,
                      decision: "allow-session",
                    }),
                  )
                }
              >
                本会话始终允许
              </button>
            </div>
          </section>
        </div>
      ) : null}

      {auth?.loggedIn === false ? (
        <div className={styles.loginBackdrop} data-testid="login-gate">
          {!loginOptionsOpen && onboardingStep < 3 ? (
            <section className={styles.onboarding} role="dialog" aria-modal="true" aria-labelledby="onboarding-title">
              {onboardingStep === 0 ? (
                <>
                  <h2 id="onboarding-title">认识 Fabushi</h2>
                  <div className={styles.onboardingBot}><span /><span /></div>
                  <div className={styles.onboardingPrompt}><span>把任何任务交给你的智能体团队</span><i>＋</i><b>↑</b></div>
                </>
              ) : null}
              {onboardingStep === 1 ? (
                <>
                  <h2 id="onboarding-title">给每个 Bot 一份工作</h2>
                  <div className={styles.onboardingBots}>
                    <div><i data-tone="red"><span /><span /></i><b>账单跟进</b></div>
                    <div><i data-tone="cyan"><span /><span /></i><b>每周站会</b></div>
                    <div><i data-tone="blue"><span /><span /></i><b>销售预测</b></div>
                  </div>
                </>
              ) : null}
              {onboardingStep === 2 ? (
                <>
                  <h2 id="onboarding-title">你每天使用哪些工具？</h2>
                  <label className={styles.onboardingSearch}><Icon name="search" size={15} /><input placeholder="搜索" /></label>
                  <div className={styles.onboardingTools}>
                    {["Workspace", "Slack", "Notion", "Salesforce", "Microsoft 365", "LinkedIn", "Zoom", "GitHub", "Jira", "Figma", "HubSpot", "Canva"].map((tool) => <button type="button" key={tool}><span>{tool.slice(0, 1)}</span>{tool}</button>)}
                  </div>
                </>
              ) : null}
              <div className={styles.onboardingNav}>
                <button type="button" onClick={() => setOnboardingStep((step) => Math.min(3, step + 1))}>下一步</button>
                {onboardingStep ? <button type="button" onClick={() => setOnboardingStep((step) => Math.max(0, step - 1))}>返回</button> : null}
              </div>
            </section>
          ) : !loginOptionsOpen ? (
            <section className={styles.grokWelcome} role="dialog" aria-modal="true" aria-labelledby="login-title">
              <div className={styles.grokTitle}>
                <div className={styles.grokLogo}><span>••</span></div>
                <h2 id="login-title">Fabushi</h2>
              </div>
              <p>一支始终在线、可以真正完成工作的智能体团队。</p>
              <button type="button" data-testid="show-login-options" onClick={() => setLoginOptionsOpen(true)}>登录 <span>→</span></button>
            </section>
          ) : (
            <section className={styles.loginDialog} role="dialog" aria-modal="true" aria-labelledby="login-options-title">
              <button className={styles.loginBack} type="button" onClick={() => setLoginOptionsOpen(false)}>← 返回</button>
              <div className={styles.loginBrand}>
                <span className={styles.loginMark}>乘</span>
                <p>FABUSHI</p>
              </div>
              <h2 id="login-options-title">在浏览器中继续</h2>
              <small>选择登录方式；完成授权后会自动回到 Fabushi。</small>
              <div className={styles.providerList}>
                {authProviders.map((provider) => (
                  <button
                    key={provider.id}
                    data-testid={`oauth-${provider.id}`}
                    type="button"
                    disabled={loginBusy}
                    onClick={() => void oauthLogin(provider.id)}
                  >
                    {providerIcon(provider.id)}
                    <span>使用 {provider.displayName} 登录</span>
                    {loginProvider === provider.id ? <i aria-label="登录中" /> : null}
                  </button>
                ))}
              </div>
              {authProviders.length ? <div className={styles.loginDivider}><span>或使用账号密码</span></div> : null}
              <button
                className={styles.passwordToggle}
                data-testid="password-login-toggle"
                type="button"
                aria-expanded={passwordLoginOpen || authProviders.length === 0}
                onClick={() => setPasswordLoginOpen((open) => !open)}
              >
                账号密码登录
              </button>
              {passwordLoginOpen || authProviders.length === 0 ? (
                <form className={styles.passwordForm} onSubmit={(event) => void login(event)}>
                  <label>
                    <span>账号或邮箱</span>
                    <input data-testid="login-username" autoComplete="username" value={loginUsername} onChange={(event) => setLoginUsername(event.target.value)} placeholder="请输入账号或邮箱" />
                  </label>
                  <label>
                    <span>密码</span>
                    <input data-testid="login-password" autoComplete="current-password" type="password" value={loginPassword} onChange={(event) => setLoginPassword(event.target.value)} placeholder="请输入密码" />
                  </label>
                  <button data-testid="login-submit" type="submit" disabled={loginBusy}>
                    {loginBusy ? "登录中…" : "登录"}
                  </button>
                </form>
              ) : null}
              {loginError ? <output role="alert">{loginError}</output> : null}
              <p className={styles.loginTerms}>继续即表示你同意《服务条款》和《隐私政策》</p>
            </section>
          )}
        </div>
      ) : null}

      {accountOpen && auth?.loggedIn ? (
        <div className={styles.backdrop} onMouseDown={() => setAccountOpen(false)}>
          <section className={styles.accountDialog} onMouseDown={(event) => event.stopPropagation()}>
            <span className={styles.profileAvatar}>{displayName.slice(0, 1)}</span>
            <h2>{displayName}</h2>
            <p>{auth.user?.email || auth.user?.username || auth.provider}</p>
            <button data-testid="logout" type="button" onClick={() => void logout()}>
              退出登录
            </button>
          </section>
        </div>
      ) : null}
    </main>
  );
}

function SettingsGroup({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: React.ReactNode;
}) {
  return (
    <section className={styles.settingsGroup}>
      <header><div><h3>{title}</h3><small>{description}</small></div></header>
      <div>{children}</div>
    </section>
  );
}

function ToggleRow({
  checked,
  label,
  description,
  onChange,
}: {
  checked: boolean;
  label: string;
  description: string;
  onChange: (value: boolean) => void;
}) {
  return (
    <label className={styles.settingsRow}>
      <span><strong>{label}</strong><small>{description}</small></span>
      <input className={styles.switchInput} type="checkbox" checked={checked} onChange={(event) => onChange(event.target.checked)} />
    </label>
  );
}
