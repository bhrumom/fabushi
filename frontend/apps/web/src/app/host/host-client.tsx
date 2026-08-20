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
  AgentPeerMessage,
  AsyncTaskSummary,
  ApprovalRequestedEvent,
  AttachmentContext,
  AutomationSummary,
  AuthState,
  BrowserLoginAttempt,
  BotSummary,
  CapabilitySummary,
  ComputerSnapshot,
  ComputerStatus,
  GroupSummary,
  ConnectorSummary,
  ConversationSummary,
  ErrorTray,
  ListenerIntegrationSummary,
  ListenerPlatform,
  MemoryKind,
  MemoryRecord,
  MessageDraft,
  ProductHostSettings,
  RuntimeCommand,
  SearchMediaMatch,
  SearchMessageMatch,
  SkillSummary,
  SkillTeamSummary,
  SubagentSummary,
  TeachRecordingResult,
  TeachRecordingStatus,
  UpdateState,
  WorkflowSummary,
  WorkflowTrigger,
} from "../../lib/mahayana-host/contracts";
import { isElectronMahayanaHostAvailable } from "../../lib/mahayana-host/electron-transport";
import { MockMahayanaHostTransport } from "../../lib/mahayana-host/mock-transport";
import { isTauriMahayanaHostAvailable } from "../../lib/mahayana-host/tauri-transport";
import type { MahayanaHostTransport } from "../../lib/mahayana-host/transport";
import {
  RemoteComputerDesktopController,
  type RemoteComputerDesktopState,
} from "../../lib/remote-computer/desktop-peer";
import { estimateStringTokenCount } from "../../lib/grok-agent/token-estimate";
import { buildCurrentModeStatement } from "../../lib/grok-agent/agent-mode-guidance";
import { addLineNumbers } from "../../lib/grok-agent/formatting";
import { normalizeSchedule } from "../../lib/grok-agent/automation-schedule";
import { clampAgentMessage } from "../../lib/grok-bot/agent-messaging";
import {
  SandOsNotificationDecider,
  buildNotificationContent,
  type SandAgentNotificationSnapshot,
} from "../../lib/grok-bot/os-notification";
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
import {
  BotMark,
  botMarkStateFromActivity,
  type BotMarkColor,
  type BotMarkShape,
  type BotMarkState,
} from "./bot-mark";
import { GroupAvatarStack, GroupChatPanel, GroupEditor } from "./group-chat-panel";
import { AgentWorkflowPanel } from "./agent-workflow-panel";

const defaultMiniAppId = "global-dharma";
const ONBOARDING_COMPLETE_KEY = "fabushi.host.onboarding-complete.v1";
const ATTACHMENT_BYTE_LIMIT = 25 * 1024 * 1024;
const VIDEO_ATTACHMENT_BYTE_LIMIT = 200 * 1024 * 1024;
const ATTACHMENT_TEXT_PREVIEW_BYTES = 64 * 1024;

function attachmentLooksLikeVideo(name: string): boolean {
  return /\.(?:mp4|mov|m4v|webm|mkv|avi|mpg|mpeg)$/i.test(name);
}

function attachmentLooksTextPreviewable(file: File): boolean {
  if (file.type.startsWith("text/")) return true;
  return /\.(?:txt|md|markdown|mdc|csv|tsv|json|jsonl|ya?ml|toml|xml|html?|css|jsx?|tsx?|py|rs|go|java|kt|swift|c|h|cpp|hpp|sh|bash|zsh|fish|log|sql|ini|conf)$/i.test(file.name);
}

function fileToBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(reader.error ?? new Error(`无法读取 ${file.name}`));
    reader.onload = () => {
      const result = typeof reader.result === "string" ? reader.result : "";
      const comma = result.indexOf(",");
      if (comma < 0) reject(new Error(`无法编码 ${file.name}`));
      else resolve(result.slice(comma + 1));
    };
    reader.readAsDataURL(file);
  });
}

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

type SettingsSection = "general" | "mcp" | "usage" | "updates";
type ThemePreference = "system" | "light" | "dark";

type HostPreferences = {
  theme: ThemePreference;
  notifyOnUpdates: boolean;
  autoUpdateWhenIdle: boolean;
  localExecution: boolean;
  routeEgressLocally: boolean;
  securityKeys: boolean;
  webauthnProxyEnabled: boolean;
  localToolPermission: "never" | "ask" | "always";
  remoteControlEnabled: boolean;
  aiComputerControlEnabled: boolean;
  autoReviewRules: Array<{ id: string; behavior: "allow" | "ask"; text: string }>;
};

const defaultPreferences: HostPreferences = {
  theme: "system",
  notifyOnUpdates: true,
  autoUpdateWhenIdle: true,
  localExecution: true,
  routeEgressLocally: false,
  securityKeys: false,
  webauthnProxyEnabled: false,
  localToolPermission: "ask",
  remoteControlEnabled: false,
  aiComputerControlEnabled: true,
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

function objectValue(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function mcpServerName(value: unknown): string {
  const server = objectValue(value);
  for (const key of ["name", "server", "id", "serverName", "identifier"]) {
    if (typeof server[key] === "string" && String(server[key]).trim()) return String(server[key]);
  }
  return "MCP Server";
}

function mcpServerStatus(value: unknown): string {
  const server = objectValue(value);
  for (const key of ["status", "state", "authStatus", "connectionStatus"]) {
    if (typeof server[key] === "string" && String(server[key]).trim()) return String(server[key]);
  }
  return "unknown";
}

function mcpServerTools(value: unknown): string[] {
  const tools = objectValue(value).tools;
  if (!Array.isArray(tools)) return [];
  return tools.map((tool) => {
    if (typeof tool === "string") return tool;
    const record = objectValue(tool);
    return typeof record.name === "string" ? record.name : "tool";
  });
}

function formatElapsedMs(value: number): string {
  const seconds = Math.max(0, Math.floor(value / 1000));
  const minutes = Math.floor(seconds / 60);
  return `${String(minutes).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
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
    | "computer"
    | "bell";
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
    bell: <><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9" /><path d="M10 21h4" /></>,
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
  const [chatDispatching, setChatDispatching] = useState(false);
  const [sessionState, setSessionState] = useState("active");
  const [featureStates, setFeatureStates] = useState<FeatureStates>(
    createInitialFeatureStates,
  );
  const [error, setError] = useState<string | null>(null);
  const [marketplaceOpen, setMarketplaceOpen] = useState(screenshotMode === "marketplace");
  const [marketplaceSection, setMarketplaceSection] = useState<MarketplaceSection>("apps");
  const [networkOpen, setNetworkOpen] = useState(false);
  const [networkTargetId, setNetworkTargetId] = useState("");
  const [networkMessage, setNetworkMessage] = useState("");
  const [networkPriority, setNetworkPriority] = useState(false);
  const [peerMessages, setPeerMessages] = useState<AgentPeerMessage[]>([]);
  const [backgroundWorkingAgents, setBackgroundWorkingAgents] = useState<Set<string>>(() => new Set());
  const [backgroundPreviews, setBackgroundPreviews] = useState<Record<string, { agentId: string; text: string }>>({});
  const [lastBroadcastResult, setLastBroadcastResult] = useState<{ total: number; scheduled: number } | null>(null);
  const [subagentAgentId, setSubagentAgentId] = useState<string | null>(null);
  const [subagents, setSubagents] = useState<SubagentSummary[]>([]);
  const [asyncTasks, setAsyncTasks] = useState<AsyncTaskSummary[]>([]);
  const [teachStatus, setTeachStatus] = useState<TeachRecordingStatus>({ state: "idle", maxDurationMs: 600_000 });
  const [teachResult, setTeachResult] = useState<TeachRecordingResult | null>(null);
  const [teachClockMs, setTeachClockMs] = useState(() => Date.now());
  const [trayOpen, setTrayOpen] = useState(false);
  const [trays, setTrays] = useState<ErrorTray[]>([]);
  const [automationOpen, setAutomationOpen] = useState(screenshotMode === "automation");
  const [computerOpen, setComputerOpen] = useState(screenshotComputerOpen);
  const [computerStatus, setComputerStatus] = useState<ComputerStatus | null>(null);
  const [computerSnapshot, setComputerSnapshot] = useState<ComputerSnapshot | null>(null);
  const [computerRefreshing, setComputerRefreshing] = useState(false);
  const [remoteDesktopState, setRemoteDesktopState] = useState<RemoteComputerDesktopState | null>(null);
  const [agentSettingsOpen, setAgentSettingsOpen] = useState(false);
  const [agentName, setAgentName] = useState("");
  const [agentTitle, setAgentTitle] = useState("");
  const [agentDescription, setAgentDescription] = useState("");
  const [agentNotifications, setAgentNotifications] = useState(true);
  const [agentMemories, setAgentMemories] = useState<MemoryRecord[]>([]);
  const [agentMemoryForId, setAgentMemoryForId] = useState<string | null>(null);
  const [agentMemoryCount, setAgentMemoryCount] = useState(0);
  const [agentMemoryLocation, setAgentMemoryLocation] = useState<string | null>(null);
  const [agentMemoryDraft, setAgentMemoryDraft] = useState("");
  const [agentMemoryKind, setAgentMemoryKind] = useState<MemoryKind>("profile");
  const [agentWorkflows, setAgentWorkflows] = useState<WorkflowSummary[]>([]);
  const [agentWorkflowForId, setAgentWorkflowForId] = useState<string | null>(null);
  const [marketplaceSearch, setMarketplaceSearch] = useState("");
  const [busyMiniApp, setBusyMiniApp] = useState<string | null>(null);
  const [auth, setAuth] = useState<AuthState | null>(null);
  const [authResolved, setAuthResolved] = useState(false);
  const [loginBusy, setLoginBusy] = useState(false);
  const [loginError, setLoginError] = useState<string | null>(null);
  const [browserLoginAttempt, setBrowserLoginAttempt] = useState<BrowserLoginAttempt | null>(null);
  const [browserLoginWakeNonce, setBrowserLoginWakeNonce] = useState(0);
  const [onboardingStep, setOnboardingStep] = useState(() =>
    screenshotMode !== null || window.localStorage.getItem(ONBOARDING_COMPLETE_KEY) === "1"
      ? 3
      : 0,
  );
  const [accountOpen, setAccountOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(screenshotMode === "settings");
  const [settingsSection, setSettingsSection] = useState<SettingsSection>("general");
  const [mcpServers, setMcpServers] = useState<unknown[]>([]);
  const [mcpApps, setMcpApps] = useState<unknown[]>([]);
  const [mcpToolServer, setMcpToolServer] = useState("");
  const [mcpToolName, setMcpToolName] = useState("");
  const [mcpToolArguments, setMcpToolArguments] = useState("{}");
  const [mcpToolResult, setMcpToolResult] = useState("");
  const [preferences, setPreferences] = useState<HostPreferences>(defaultPreferences);
  const [hostSettingsHydrated, setHostSettingsHydrated] = useState(false);
  const lastHostSettingsJsonRef = useRef("");
  const [auditRecords, setAuditRecords] = useState<unknown[]>([]);
  const [auditAgentId, setAuditAgentId] = useState<string | null>(null);
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
  const [groups, setGroups] = useState<GroupSummary[]>([]);
  const [activeGroupId, setActiveGroupId] = useState<string | null>(null);
  const [groupEditorId, setGroupEditorId] = useState<"new" | string | null>(null);
  const [groupPreviews, setGroupPreviews] = useState<Record<string, { groupId: string; memberId: string; memberName: string; text: string }>>({});
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
  const [searchMessageMatches, setSearchMessageMatches] = useState<SearchMessageMatch[]>([]);
  const [searchMediaMatches, setSearchMediaMatches] = useState<SearchMediaMatch[]>([]);
  const [searchPending, setSearchPending] = useState(false);
  const searchQueryRef = useRef("");
  const botsRef = useRef<BotSummary[]>([]);
  const preferencesRef = useRef(preferences);
  const activeAgentIdRef = useRef(activeAgentId);
  const activeGroupIdRef = useRef(activeGroupId);
  const agentWorkflowForIdRef = useRef<string | null>(null);
  const notificationDeciderRef = useRef(new SandOsNotificationDecider());
  const notificationSnapshotsRef = useRef(new Map<string, SandAgentNotificationSnapshot>());
  const notificationOperationAgentsRef = useRef(new Map<string, string>());
  const notificationQueueRef = useRef<Promise<void>>(Promise.resolve());
  const computerRefreshInFlightRef = useRef(false);
  const remoteDesktopControllerRef = useRef<RemoteComputerDesktopController | null>(null);
  const [agentMode, setAgentMode] = useState<AgentMode>("agent");
  const [selectedModel, setSelectedModel] = useState("auto");
  const [attachments, setAttachments] = useState<AttachmentContext[]>([]);
  const [activity, setActivity] = useState<AgentActivity[]>([]);
  const [usage, setUsage] = useState<{
    totalTokens: number;
    contextWindow?: number;
    model: string;
  } | null>(null);

  const notificationSnapshot = (
    agentId: string,
    patch: Partial<SandAgentNotificationSnapshot> = {},
  ): SandAgentNotificationSnapshot => {
    const bot = botsRef.current.find((candidate) => candidate.id === agentId);
    const current = notificationSnapshotsRef.current.get(agentId);
    return {
      id: agentId,
      name: bot?.name ?? current?.name ?? agentId,
      isRunning: current?.isRunning ?? false,
      awaitingReason: current?.awaitingReason ?? null,
      lastMessageId: current?.lastMessageId ?? null,
      lastMessagePreview: current?.lastMessagePreview ?? null,
      notifyEnabled: preferencesRef.current.notifyOnUpdates && (bot?.notificationsEnabled ?? current?.notifyEnabled ?? true),
      isHiddenFromSidebar: bot?.hidden ?? current?.isHiddenFromSidebar ?? false,
      ...patch,
    };
  };

  const queueNotificationSnapshot = (
    agentId: string,
    patch: Partial<SandAgentNotificationSnapshot>,
    allowNotification: boolean,
  ) => {
    const snapshot = notificationSnapshot(agentId, patch);
    notificationSnapshotsRef.current.set(agentId, snapshot);
    notificationQueueRef.current = notificationQueueRef.current
      .catch(() => {})
      .then(async () => {
        const isWindowFocused = allowNotification
          ? await transport.windowFocused().catch(() => document.hasFocus())
          : true;
        const transitions = notificationDeciderRef.current.decideAgent(snapshot, {
          isWindowFocused,
          nowMs: Date.now(),
        });
        if (!allowNotification) return;
        for (const transition of transitions) {
          const content = buildNotificationContent(transition);
          await transport.showNotification(content.title, content.body).catch(() => {});
        }
      });
  };

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
    preferencesRef.current = preferences;
    window.localStorage.setItem(
      "fabushi.host.preferences.v1",
      JSON.stringify(preferences),
    );
    if (!hostSettingsHydrated) return;
    const settings: ProductHostSettings = {
      notifications: preferences.notifyOnUpdates,
      autoUpdateWhenIdle: preferences.autoUpdateWhenIdle,
      localExecution: preferences.localExecution,
      routeEgressLocally: preferences.routeEgressLocally,
      securityKeys: preferences.securityKeys,
      webauthnProxyEnabled: preferences.webauthnProxyEnabled,
      localToolPermission: preferences.localToolPermission,
      remoteControlEnabled: preferences.remoteControlEnabled,
      aiComputerControlEnabled: preferences.aiComputerControlEnabled,
      autoReviewRules: preferences.autoReviewRules,
    };
    const serialized = JSON.stringify(settings);
    if (serialized === lastHostSettingsJsonRef.current) return;
    lastHostSettingsJsonRef.current = serialized;
    void transport.execute({
      type: "settings.update",
      requestId: `settings-update-${Date.now()}`,
      settings,
    }).catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause)));
  }, [preferences, hostSettingsHydrated, transport]);

  useEffect(() => {
    const existing = remoteDesktopControllerRef.current;
    if (
      !hostSettingsHydrated ||
      hostStatus !== "ready" ||
      !auth?.loggedIn ||
      !preferences.remoteControlEnabled
    ) {
      remoteDesktopControllerRef.current = null;
      if (existing) void existing.stop();
      setRemoteDesktopState(null);
      return;
    }

    let cancelled = false;
    const controller = new RemoteComputerDesktopController({
      transport,
      label: `${auth.user?.nickname || auth.user?.username || "Fabushi"} 的 Mac`,
      onState: (state) => {
        if (!cancelled) setRemoteDesktopState(state);
      },
    });
    remoteDesktopControllerRef.current = controller;
    const settings: ProductHostSettings = {
      notifications: preferences.notifyOnUpdates,
      autoUpdateWhenIdle: preferences.autoUpdateWhenIdle,
      localExecution: preferences.localExecution,
      routeEgressLocally: preferences.routeEgressLocally,
      securityKeys: preferences.securityKeys,
      webauthnProxyEnabled: preferences.webauthnProxyEnabled,
      localToolPermission: preferences.localToolPermission,
      remoteControlEnabled: true,
      aiComputerControlEnabled: preferences.aiComputerControlEnabled,
      autoReviewRules: preferences.autoReviewRules,
    };
    void (async () => {
      await transport.execute({
        type: "settings.update",
        requestId: `remote-settings-${Date.now()}`,
        settings,
      });
      if (!cancelled) await controller.start();
    })().catch((cause: unknown) => {
      if (!cancelled) setError(cause instanceof Error ? cause.message : String(cause));
    });
    return () => {
      cancelled = true;
      if (remoteDesktopControllerRef.current === controller) {
        remoteDesktopControllerRef.current = null;
      }
      void controller.stop();
    };
  }, [
    auth?.loggedIn,
    auth?.user?.nickname,
    auth?.user?.username,
    hostSettingsHydrated,
    hostStatus,
    preferences.remoteControlEnabled,
    transport,
  ]);

  useEffect(() => {
    botsRef.current = bots;
  }, [bots]);

  useEffect(() => {
    activeAgentIdRef.current = activeAgentId;
  }, [activeAgentId]);

  useEffect(() => {
    activeGroupIdRef.current = activeGroupId;
  }, [activeGroupId]);

  useEffect(() => {
    agentWorkflowForIdRef.current = agentWorkflowForId;
  }, [agentWorkflowForId]);

  useEffect(() => {
    if (teachStatus.state !== "recording") return;
    setTeachClockMs(Date.now());
    const timer = window.setInterval(() => setTeachClockMs(Date.now()), 500);
    return () => window.clearInterval(timer);
  }, [teachStatus.state, teachStatus.startedAtMs]);

  useEffect(() => {
    if (!computerOpen) return;
    const agentId = bots.some((bot) => bot.id === activeAgentId)
      ? activeAgentId
      : "mahayana-assistant";
    setSubagentAgentId(agentId);
    const stamp = Date.now();
    void Promise.all([
      transport.execute({ type: "subagent.list", requestId: `subagent-list-${stamp}`, agentId }),
      transport.execute({ type: "asyncTask.list", requestId: `async-task-list-${stamp}`, agentId }),
      transport.execute({ type: "teach.status", requestId: `teach-status-${stamp}` }),
      transport.execute({ type: "computer.status", requestId: `computer-status-${stamp}` }),
    ]).catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause)));
  }, [computerOpen, activeAgentId, bots, transport]);

  useEffect(() => {
    if (!computerOpen) return;
    let stopped = false;
    const refreshStatus = async () => {
      if (stopped) return;
      try {
        await transport.execute({ type: "computer.status", requestId: `computer-permission-status-${Date.now()}` });
      } catch (cause) {
        if (!stopped) setError(cause instanceof Error ? cause.message : String(cause));
      }
    };
    void refreshStatus();
    const timer = window.setInterval(() => void refreshStatus(), 2_000);
    return () => {
      stopped = true;
      window.clearInterval(timer);
    };
  }, [computerOpen, transport]);

  useEffect(() => {
    if (!computerOpen || !computerStatus?.captureSupported || !computerStatus.screenRecordingGranted) return;
    let stopped = false;
    const refresh = async () => {
      if (stopped || computerRefreshInFlightRef.current) return;
      computerRefreshInFlightRef.current = true;
      setComputerRefreshing(true);
      try {
        await transport.execute({
          type: "computer.screenshot",
          requestId: `computer-snapshot-${Date.now()}`,
          origin: "local-ui",
        });
      } catch (cause) {
        if (!stopped) setError(cause instanceof Error ? cause.message : String(cause));
      } finally {
        computerRefreshInFlightRef.current = false;
        if (!stopped) setComputerRefreshing(false);
      }
    };
    void refresh();
    const timer = window.setInterval(() => void refresh(), 900);
    return () => {
      stopped = true;
      window.clearInterval(timer);
    };
  }, [computerOpen, computerStatus?.captureSupported, computerStatus?.screenRecordingGranted, transport]);

  useEffect(() => {
    if (!settingsOpen || settingsSection !== "mcp") return;
    const stamp = Date.now();
    void Promise.all([
      transport.execute({ type: "mcp.list", requestId: `mcp-list-${stamp}` }),
      transport.execute({ type: "mcp.apps", requestId: `mcp-apps-${stamp}` }),
    ]).catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause)));
  }, [settingsOpen, settingsSection, transport]);

  useEffect(() => {
    const query = conversationSearch.trim().toLowerCase();
    searchQueryRef.current = query;
    if (!query) {
      setSearchMessageMatches([]);
      setSearchMediaMatches([]);
      setSearchPending(false);
      return;
    }
    setSearchPending(true);
    const timer = window.setTimeout(() => {
      const stamp = Date.now();
      void Promise.all([
        transport.execute({ type: "search.messages", requestId: `global-message-search-${stamp}`, query, limit: 50 }),
        transport.execute({ type: "search.media", requestId: `global-media-search-${stamp}`, query, limit: 50 }),
      ]).catch((cause: unknown) => {
        setSearchPending(false);
        setError(cause instanceof Error ? cause.message : String(cause));
      });
    }, 180);
    return () => window.clearTimeout(timer);
  }, [conversationSearch, transport]);

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
          if (event.role === "assistant") setChatDispatching(false);
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
          if (event.role === "assistant") {
            pass("chat.send");
            if (event.operationId) {
              const agentId = notificationOperationAgentsRef.current.get(event.operationId) ?? activeAgentIdRef.current;
              if (botsRef.current.some((bot) => bot.id === agentId)) {
                queueNotificationSnapshot(agentId, {
                  lastMessageId: event.operationId,
                  lastMessagePreview: event.text,
                }, false);
              }
            }
          }
          break;
        case "chat.delta":
          setChatDispatching(false);
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
        case "bot.listed": {
          botsRef.current = event.bots;
          setBots(event.bots);
          const baselines = event.bots.map((bot) => ({
            id: bot.id,
            name: bot.name,
            isRunning: false,
            awaitingReason: null,
            lastMessageId: null,
            lastMessagePreview: null,
            notifyEnabled: preferencesRef.current.notifyOnUpdates && bot.notificationsEnabled,
            isHiddenFromSidebar: bot.hidden,
          } satisfies SandAgentNotificationSnapshot));
          for (const baseline of baselines) notificationSnapshotsRef.current.set(baseline.id, baseline);
          notificationDeciderRef.current.seedBaseline(baselines);
          break;
        }
        case "bot.changed":
          setBots((current) => {
            const next = event.action === "deleted"
              ? current.filter((item) => item.id !== event.bot.id)
              : current.some((item) => item.id === event.bot.id)
                ? current.map((item) => item.id === event.bot.id ? event.bot : item)
                : [...current, event.bot];
            botsRef.current = next;
            return next;
          });
          if (event.action === "deleted") {
            notificationSnapshotsRef.current.delete(event.bot.id);
            notificationDeciderRef.current.forget(event.bot.id);
          }
          break;
        case "group.listed":
          setGroups(event.groups);
          break;
        case "group.changed":
          setGroups((current) => {
            if (event.action === "deleted") {
              return current.filter((item) => item.id !== event.group.id);
            }
            const index = current.findIndex((item) => item.id === event.group.id);
            return index < 0
              ? [...current, event.group]
              : current.map((item, itemIndex) => itemIndex === index ? event.group : item);
          });
          if (event.action === "deleted") {
            setActiveGroupId((current) => current === event.group.id ? null : current);
          }
          if (event.action === "message" || event.action.startsWith("turnFailed:")) {
            setGroupPreviews((current) => Object.fromEntries(
              Object.entries(current).filter(([, preview]) => preview.groupId !== event.group.id),
            ));
          }
          break;
        case "group.delta":
          setGroupPreviews((current) => ({
            ...current,
            [event.operationId]: {
              groupId: event.groupId,
              memberId: event.memberId,
              memberName: event.memberName,
              text: `${current[event.operationId]?.text ?? ""}${event.delta}`,
            },
          }));
          break;
        case "agent.peerMessage":
          setPeerMessages((current) => [...current.filter((message) => message.id !== event.message.id), event.message].slice(-300));
          break;
        case "agent.peerHistory":
          setPeerMessages(event.messages.slice(-300));
          break;
        case "agent.broadcasted":
          setLastBroadcastResult(event.result);
          break;
        case "agent.backgroundStarted":
          setBackgroundWorkingAgents((current) => new Set(current).add(event.agentId));
          queueNotificationSnapshot(event.agentId, {
            isRunning: true,
            awaitingReason: null,
          }, false);
          break;
        case "agent.backgroundDelta":
          setBackgroundWorkingAgents((current) => new Set(current).add(event.agentId));
          setBackgroundPreviews((current) => ({
            ...current,
            [event.operationId]: {
              agentId: event.agentId,
              text: `${current[event.operationId]?.text ?? ""}${event.delta}`,
            },
          }));
          if (activeAgentIdRef.current === event.agentId && !activeGroupIdRef.current) {
            setMessages((current) => {
              const index = current.findIndex((message) => message.operationId === event.operationId);
              if (index < 0) {
                return [...current, { role: "assistant", text: event.delta, operationId: event.operationId }];
              }
              return current.map((message, messageIndex) => messageIndex === index
                ? { ...message, text: `${message.text}${event.delta}` }
                : message);
            });
          }
          break;
        case "agent.backgroundMessage":
          setBackgroundWorkingAgents((current) => new Set(current).add(event.agentId));
          setBackgroundPreviews((current) => ({ ...current, [event.operationId]: { agentId: event.agentId, text: event.text } }));
          queueNotificationSnapshot(event.agentId, {
            isRunning: true,
            lastMessageId: event.operationId,
            lastMessagePreview: event.text,
          }, false);
          if (activeAgentIdRef.current === event.agentId && !activeGroupIdRef.current) {
            setMessages((current) => {
              const index = current.findIndex((message) => message.operationId === event.operationId);
              return index < 0
                ? [...current, { role: "assistant", text: event.text, operationId: event.operationId }]
                : current.map((message, messageIndex) => messageIndex === index ? { ...message, text: event.text } : message);
            });
          }
          break;
        case "agent.backgroundFinished":
          setBackgroundWorkingAgents((current) => {
            const next = new Set(current);
            next.delete(event.agentId);
            return next;
          });
          setBackgroundPreviews((current) => {
            const next = { ...current };
            delete next[event.operationId];
            return next;
          });
          queueNotificationSnapshot(event.agentId, {
            isRunning: false,
          }, !event.error);
          if (event.error) setError(`${event.agentName}: ${event.error}`);
          break;
        case "subagent.listed":
          setSubagentAgentId(event.agentId);
          setSubagents(event.subagents);
          break;
        case "subagent.changed":
          if (event.subagent.parentAgentId === subagentAgentId || event.subagent.parentAgentId === activeAgentIdRef.current) {
            setSubagentAgentId(event.subagent.parentAgentId);
            setSubagents((current) => {
              const index = current.findIndex((subagent) => subagent.id === event.subagent.id);
              return index < 0
                ? [...current, event.subagent]
                : current.map((subagent, subagentIndex) => subagentIndex === index ? event.subagent : subagent);
            });
          }
          break;
        case "asyncTask.listed":
        case "asyncTask.changed":
          if (event.agentId === subagentAgentId || event.agentId === activeAgentIdRef.current) {
            setSubagentAgentId(event.agentId);
            setAsyncTasks(event.tasks);
          }
          break;
        case "teach.changed":
          setTeachStatus(event.status);
          if (event.result) {
            setTeachResult(event.result);
            if (event.result.saved) {
              void transport.execute({ type: "workflow.list", requestId: `teach-workflow-refresh-${Date.now()}`, agentId: event.result.agentId }).catch(() => {});
            }
          }
          break;
        case "computer.status":
          setComputerStatus(event.status);
          break;
        case "computer.snapshot":
          setComputerSnapshot(event.snapshot);
          break;
        case "computer.result":
          setComputerSnapshot(event.result.snapshot);
          break;
        case "memory.listed":
          setAgentMemoryForId(event.agentId);
          setAgentMemories(event.memories);
          setAgentMemoryCount(event.count);
          setAgentMemoryLocation(event.location ?? null);
          break;
        case "memory.changed":
          void transport.execute({
            type: "memory.list",
            requestId: `memory-refresh-${Date.now()}`,
            agentId: event.agentId,
            limit: 1000,
          }).catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause)));
          break;
        case "workflow.listed":
          setAgentWorkflowForId(event.agentId);
          setAgentWorkflows(event.workflows);
          break;
        case "workflow.changed":
          if (event.agentId === agentWorkflowForIdRef.current) {
            setAgentWorkflows((current) => {
              if (event.action === "deleted" && event.id) {
                return current.filter((workflow) => workflow.id !== event.id);
              }
              if (event.workflow) {
                const index = current.findIndex((workflow) => workflow.id === event.workflow!.id && workflow.source === event.workflow!.source);
                return index < 0
                  ? [...current, event.workflow]
                  : current.map((workflow, workflowIndex) => workflowIndex === index ? event.workflow! : workflow);
              }
              return current;
            });
          }
          if (event.workflow?.source === "automation" || event.action === "deleted") {
            void transport.execute({
              type: "automation.list",
              requestId: `automation-refresh-${Date.now()}`,
            }).catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause)));
          }
          break;
        case "search.messages":
          if (event.query === searchQueryRef.current) {
            setSearchMessageMatches(event.matches);
            setSearchPending(false);
          }
          break;
        case "search.media":
          if (event.query === searchQueryRef.current) {
            setSearchMediaMatches(event.matches);
          }
          break;
        case "mcp.listed":
          setMcpServers(event.servers);
          if (event.servers.length) setMcpToolServer((current) => current || mcpServerName(event.servers[0]));
          break;
        case "mcp.apps":
          setMcpApps(event.apps);
          break;
        case "mcp.oauth":
          if (event.authorizationUrl) {
            void transport.openExternal(event.authorizationUrl).catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause)));
          }
          void transport.execute({ type: "mcp.list", requestId: `mcp-list-${Date.now()}` }).catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause)));
          break;
        case "mcp.refreshed":
          void Promise.all([
            transport.execute({ type: "mcp.list", requestId: `mcp-list-${Date.now()}` }),
            transport.execute({ type: "mcp.apps", requestId: `mcp-apps-${Date.now()}` }),
          ]).catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause)));
          break;
        case "mcp.toolResult":
          setMcpToolResult(JSON.stringify(event.result, null, 2));
          break;
        case "settings.changed":
          lastHostSettingsJsonRef.current = JSON.stringify(event.settings);
          setHostSettingsHydrated(true);
          setPreferences((current) => ({
            ...current,
            notifyOnUpdates: event.settings.notifications,
            autoUpdateWhenIdle: event.settings.autoUpdateWhenIdle,
            localExecution: event.settings.localExecution,
            routeEgressLocally: event.settings.routeEgressLocally,
            securityKeys: event.settings.securityKeys,
            webauthnProxyEnabled: event.settings.webauthnProxyEnabled,
            localToolPermission: event.settings.localToolPermission,
            remoteControlEnabled: event.settings.remoteControlEnabled,
            aiComputerControlEnabled: event.settings.aiComputerControlEnabled,
            autoReviewRules: event.settings.autoReviewRules,
          }));
          break;
        case "audit.listed":
          setAuditAgentId(event.agentId);
          setAuditRecords(event.records);
          break;
        case "tray.listed":
          setTrays(event.trays);
          break;
        case "tray.changed":
          setTrays((current) => {
            if (event.action === "cleared") return [];
            if (event.action === "dismissed" && event.id) return current.filter((tray) => tray.id !== event.id);
            if (event.action === "pushed" && event.tray) {
              const index = current.findIndex((tray) => tray.id === event.tray!.id);
              return index < 0
                ? [...current, event.tray]
                : current.map((tray, trayIndex) => trayIndex === index ? event.tray! : tray);
            }
            return current;
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
          setActiveAgentId(
            botsRef.current.find((bot) => bot.conversationId === event.conversationId)?.id ?? "mahayana-assistant",
          );
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
          if (botsRef.current.some((bot) => bot.id === activeAgentIdRef.current)) {
            queueNotificationSnapshot(activeAgentIdRef.current, {
              isRunning: false,
              awaitingReason: event.detail || event.reason || "Waiting for your input.",
            }, true);
          }
          break;
        case "approval.resolved":
          setApproval(null);
          for (const [agentId, snapshot] of notificationSnapshotsRef.current) {
            if (snapshot.awaitingReason) queueNotificationSnapshot(agentId, { awaitingReason: null }, false);
          }
          setApprovalState(
            event.decision === "allow-once"
              ? "allowed-once"
              : event.decision === "allow-session"
                ? "allowed-for-session"
                : "denied",
          );
          pass("capability.approval");
          break;
        case "operation.started": {
          setChatDispatching(false);
          setOperationState("running");
          if (event.interruptible) {
            setActiveOperationId(event.operationId);
          }
          const agentId = activeAgentIdRef.current;
          if (botsRef.current.some((bot) => bot.id === agentId)) {
            notificationOperationAgentsRef.current.set(event.operationId, agentId);
            queueNotificationSnapshot(agentId, { isRunning: true, awaitingReason: null }, false);
          }
          break;
        }
        case "operation.interrupted": {
          setChatDispatching(false);
          setActiveOperationId(null);
          setOperationState("interrupted");
          const agentId = notificationOperationAgentsRef.current.get(event.operationId);
          if (agentId) queueNotificationSnapshot(agentId, { isRunning: false }, false);
          notificationOperationAgentsRef.current.delete(event.operationId);
          pass("operation.interrupt");
          break;
        }
        case "operation.completed": {
          setChatDispatching(false);
          setActiveOperationId((current) =>
            current === event.operationId ? null : current,
          );
          setOperationState((current) =>
            current === "running" ? "completed" : current,
          );
          const agentId = notificationOperationAgentsRef.current.get(event.operationId);
          if (agentId) queueNotificationSnapshot(agentId, { isRunning: false }, true);
          notificationOperationAgentsRef.current.delete(event.operationId);
          break;
        }
        case "operation.failed": {
          setChatDispatching(false);
          setActiveOperationId((current) =>
            current === event.operationId ? null : current,
          );
          setOperationState("failed");
          const agentId = notificationOperationAgentsRef.current.get(event.operationId);
          if (agentId) queueNotificationSnapshot(agentId, { isRunning: false }, false);
          notificationOperationAgentsRef.current.delete(event.operationId);
          setError(`${event.code}: ${event.message}`);
          break;
        }
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
        : isElectronMahayanaHostAvailable() || isTauriMahayanaHostAvailable()
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
            type: "group.list",
            requestId: "group-list-initial",
          }),
          transport.execute({
            type: "tray.list",
            requestId: "tray-list-initial",
          }),
          transport.execute({
            type: "settings.get",
            requestId: "settings-get-initial",
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
        } finally {
          setAuthResolved(true);
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
        setAuthResolved(true);
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
    setChatDispatching(true);
    const outgoingAttachments = attachments;
    setAttachments([]);
    setError(null);
    try {
      await execute({
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
      });
    } catch (cause: unknown) {
      setChatDispatching(false);
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  };

  const attachFiles = async (files: FileList | null) => {
    if (!files?.length) return;
    const ownerId = bots.some((bot) => bot.id === activeAgentId)
      ? activeAgentId
      : "mahayana-assistant";
    const next: AttachmentContext[] = [];
    for (const file of [...files].slice(0, 6)) {
      const byteLimit = attachmentLooksLikeVideo(file.name)
        ? VIDEO_ATTACHMENT_BYTE_LIMIT
        : ATTACHMENT_BYTE_LIMIT;
      if (!file.size) {
        setError(`“${file.name}” 是空文件，未添加。`);
        continue;
      }
      if (file.size > byteLimit) {
        setError(`“${file.name}” 超过附件上限（${Math.round(byteLimit / 1024 / 1024)} MB）。`);
        continue;
      }
      try {
        let cancelStoredWait = () => {};
        const stored = new Promise<AttachmentContext>((resolve, reject) => {
          let unsubscribe = () => {};
          const timeout = window.setTimeout(() => {
            unsubscribe();
            reject(new Error(`等待 ${file.name} 写入 Host 超时`));
          }, 20_000);
          cancelStoredWait = () => {
            window.clearTimeout(timeout);
            unsubscribe();
          };
          unsubscribe = transport.subscribe((event) => {
            if (
              event.type !== "attachment.stored" ||
              event.attachment.agentId !== ownerId ||
              event.attachment.name !== file.name
            ) return;
            cancelStoredWait();
            resolve({
              id: event.attachment.id,
              name: event.attachment.name,
              mimeType: event.attachment.mimeType,
              path: event.attachment.path,
              sizeBytes: event.attachment.sizeBytes,
            });
          });
        });
        try {
          await execute({
            type: "attachment.upload",
            requestId: nextRequestId("attachment-upload"),
            agentId: ownerId,
            filename: file.name,
            mimeType: file.type || undefined,
            bytesBase64: await fileToBase64(file),
          });
        } catch (cause) {
          cancelStoredWait();
          void stored.catch(() => {});
          throw cause;
        }
        const attachment = await stored;
        if (attachmentLooksTextPreviewable(file)) {
          attachment.text = await file.slice(0, ATTACHMENT_TEXT_PREVIEW_BYTES).text();
        }
        next.push(attachment);
      } catch (cause: unknown) {
        setError(cause instanceof Error ? cause.message : String(cause));
      }
    }
    if (next.length) {
      setAttachments((current) => [...current, ...next].slice(0, 6));
    }
    if (attachmentInput.current) attachmentInput.current.value = "";
  };

  const beginBrowserLogin = async () => {
    if (loginBusy) return;
    setLoginBusy(true);
    setLoginError(null);
    try {
      const attempt = await transport.browserLoginStart();
      setBrowserLoginAttempt(attempt);
      await transport.openExternal(attempt.loginUrl);
    } catch (cause: unknown) {
      setBrowserLoginAttempt(null);
      setLoginBusy(false);
      setLoginError(cause instanceof Error ? cause.message : String(cause));
    }
  };

  const reopenBrowserLogin = async () => {
    const attempt = browserLoginAttempt;
    if (!attempt) return;
    try {
      const reopened = await transport.browserLoginReopen(attempt.attemptId);
      if (reopened.status !== "pending") {
        setBrowserLoginWakeNonce((value) => value + 1);
        return;
      }
      const loginUrl = reopened.loginUrl?.trim();
      if (!loginUrl) throw new Error("账号服务没有返回新的登录地址");
      setBrowserLoginAttempt((current) => current?.attemptId === attempt.attemptId
        ? {
            ...current,
            loginUrl,
            pollAfterMs: reopened.pollAfterMs ?? current.pollAfterMs,
          }
        : current);
      await transport.openExternal(loginUrl);
      setLoginError(null);
      setBrowserLoginWakeNonce((value) => value + 1);
    } catch (cause: unknown) {
      setLoginError(cause instanceof Error ? cause.message : String(cause));
    }
  };

  const cancelBrowserLogin = async () => {
    const attempt = browserLoginAttempt;
    if (!attempt) return;
    setLoginError(null);
    try {
      const result = await transport.browserLoginCancel(attempt.attemptId);
      if (result.status === "completed") {
        setBrowserLoginWakeNonce((value) => value + 1);
        return;
      }
      setBrowserLoginAttempt(null);
      setLoginBusy(false);
      setLoginError(result.status === "failed" ? "登录流程已失败，请重新开始" : null);
    } catch (cause: unknown) {
      setLoginError(`取消登录失败：${cause instanceof Error ? cause.message : String(cause)}`);
    }
  };

  useEffect(() => {
    const attempt = browserLoginAttempt;
    if (!attempt) return undefined;
    let cancelled = false;
    let timer: number | null = null;
    const pollDelay = Math.max(150, Math.min(2_000, attempt.pollAfterMs ?? 750));
    const schedule = (delay = pollDelay) => {
      if (!cancelled) timer = window.setTimeout(() => void poll(), delay);
    };
    const poll = async () => {
      if (cancelled) return;
      if (attempt.expiresAt && Date.now() / 1000 >= attempt.expiresAt) {
        setBrowserLoginAttempt(null);
        setLoginBusy(false);
        setLoginError("登录链接已过期，请重新开始");
        return;
      }
      try {
        const result = await transport.browserLoginPoll(attempt.attemptId);
        if (cancelled) return;
        if (result.status === "completed" && result.auth) {
          setAuth({ ...result.auth, loggedIn: true });
          setFeatureStates((current) => ({ ...current, "auth.login": "passed" }));
          setBrowserLoginAttempt(null);
          setLoginBusy(false);
          setLoginError(null);
          return;
        }
        if (result.status === "expired" || result.status === "cancelled" || result.status === "failed") {
          setBrowserLoginAttempt(null);
          setLoginBusy(false);
          setLoginError(
            result.status === "cancelled"
              ? "登录已取消"
              : result.status === "failed"
                ? "登录流程未完成，请重新开始"
                : "登录链接已过期，请重新开始",
          );
          return;
        }
        setLoginError(null);
        schedule();
      } catch (cause: unknown) {
        if (cancelled) return;
        setLoginError(`正在重新连接账号服务：${cause instanceof Error ? cause.message : String(cause)}`);
        schedule(1_500);
      }
    };
    void poll();
    return () => {
      cancelled = true;
      if (timer) window.clearTimeout(timer);
    };
  }, [browserLoginAttempt?.attemptId, browserLoginWakeNonce]);

  const logout = async () => {
    await run(async () => {
      const state = await transport.logout();
      setAuth({ ...state, loggedIn: false });
      setAccountOpen(false);
      setBrowserLoginAttempt(null);
      setLoginBusy(false);
    });
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
  const currentRunningActivity = [...activity]
    .reverse()
    .find((item) => item.status === "running");
  const activeBotState: BotMarkState = chatDispatching
    ? "thinking"
    : activeOperationId || operationState === "running"
      ? botMarkStateFromActivity(currentRunningActivity)
      : operationState === "failed" || operationState === "interrupted"
      ? "waking"
      : "idle";
  const activeBotMarkId = activeAgentId || "mahayana-assistant";
  const activeBotProfile = bots.find((bot) => bot.id === activeBotMarkId);
  const primaryBotProfile = bots.find((bot) => bot.id === "mahayana-assistant");
  const activeBotShape = activeBotProfile?.avatarShape as BotMarkShape | undefined;
  const activeBotColor = activeBotProfile?.avatarColor as BotMarkColor | undefined;
  const activeGroup = groups.find((group) => group.id === activeGroupId) ?? null;
  const editingGroup = groupEditorId && groupEditorId !== "new"
    ? groups.find((group) => group.id === groupEditorId)
    : undefined;
  const activeGroupPreviews = Object.fromEntries(
    Object.entries(groupPreviews)
      .filter(([, preview]) => preview.groupId === activeGroupId)
      .map(([operationId, preview]) => [operationId, {
        memberId: preview.memberId,
        memberName: preview.memberName,
        text: preview.text,
      }]),
  );
  const networkSender = activeBotProfile ?? primaryBotProfile;
  const networkTargets = networkSender
    ? [
        ...bots.filter((bot) => bot.id !== networkSender.id),
        ...groups
          .filter((group) => group.memberIds.includes(networkSender.id))
          .map((group) => ({
            id: group.id,
            name: group.name,
            description: group.description || `${group.memberIds.length} 个成员`,
            title: "Group",
            hidden: false,
            notificationsEnabled: false,
          } satisfies BotSummary)),
      ]
    : [];

  const openAgentNetwork = () => {
    if (networkSender) {
      setNetworkTargetId((current) => current && current !== networkSender.id ? current : networkTargets[0]?.id ?? "");
      void run(() => execute({
        type: "agent.peerHistory",
        requestId: nextRequestId("peer-history"),
        agentId: networkSender.id,
        limit: 300,
      }));
    }
    setNetworkOpen(true);
  };

  const sendNetworkMessage = async () => {
    if (!networkSender || !networkTargetId || !networkMessage.trim()) return;
    const text = clampAgentMessage(networkMessage);
    if (!text) return;
    setNetworkMessage("");
    await run(() => execute({
      type: "agent.send",
      requestId: nextRequestId("agent-send"),
      fromAgentId: networkSender.id,
      targetId: networkTargetId,
      text,
      priority: networkPriority,
    }));
  };

  const broadcastNetworkMessage = async () => {
    if (!networkMessage.trim()) return;
    const message = clampAgentMessage(networkMessage);
    if (!message) return;
    setNetworkMessage("");
    setLastBroadcastResult(null);
    await run(() => execute({
      type: "agent.broadcast",
      requestId: nextRequestId("agent-broadcast"),
      message,
    }));
  };

  const saveGroup = async (draft: { name: string; description: string; memberIds: string[] }) => {
    if (groupEditorId && groupEditorId !== "new") {
      await run(() => execute({
        type: "group.update",
        requestId: nextRequestId("group-update"),
        id: groupEditorId,
        ...draft,
      }));
    } else {
      await run(() => execute({
        type: "group.create",
        requestId: nextRequestId("group-create"),
        ...draft,
      }));
    }
    setGroupEditorId(null);
  };

  const sendGroupMessage = async (text: string) => {
    if (!activeGroup) return;
    await run(() => execute({
      type: "group.send",
      requestId: nextRequestId("group-send"),
      id: activeGroup.id,
      text,
    }));
  };

  const deleteActiveGroup = () => {
    if (!activeGroup || !window.confirm(`永久删除群聊 ${activeGroup.name}？`)) return;
    void run(() => execute({
      type: "group.delete",
      requestId: nextRequestId("group-delete"),
      id: activeGroup.id,
    }));
  };

  const openAgentSettings = () => {
    setAgentName(activeBotProfile?.name ?? (activeAgent ? `${activeAgent.title}机器人` : "大乘助手"));
    setAgentTitle(activeBotProfile?.title ?? "");
    setAgentDescription(activeBotProfile?.description ?? "");
    setAgentNotifications(activeBotProfile?.notificationsEnabled ?? true);
    setAgentSettingsOpen(true);
    if (activeBotProfile) {
      setAgentMemoryForId(activeBotProfile.id);
      void run(() => execute({
        type: "memory.list",
        requestId: nextRequestId("memory-list"),
        agentId: activeBotProfile.id,
        limit: 1000,
      }));
      setAgentWorkflowForId(activeBotProfile.id);
      void run(() => execute({
        type: "workflow.list",
        requestId: nextRequestId("workflow-list"),
        agentId: activeBotProfile.id,
      }));
      setAuditAgentId(activeBotProfile.id);
      void run(() => execute({
        type: "audit.list",
        requestId: nextRequestId("audit-list"),
        agentId: activeBotProfile.id,
        limit: 100,
      }));
    }
  };

  const updateActiveBotProfile = (patch: Partial<Pick<BotSummary, "name" | "title" | "description" | "notificationsEnabled">>) => {
    if (!activeBotProfile) return;
    void run(() => execute({
      type: "bot.update",
      requestId: nextRequestId("bot-profile"),
      id: activeBotProfile.id,
      ...patch,
    }));
  };

  const addAgentMemory = () => {
    if (!activeBotProfile || !agentMemoryDraft.trim()) return;
    const content = agentMemoryDraft;
    setAgentMemoryDraft("");
    void run(() => execute({
      type: "memory.add",
      requestId: nextRequestId("memory-add"),
      agentId: activeBotProfile.id,
      content,
      kind: agentMemoryKind,
    }));
  };

  const removeAgentMemory = (id: string) => {
    if (!activeBotProfile) return;
    void run(() => execute({
      type: "memory.remove",
      requestId: nextRequestId("memory-remove"),
      agentId: activeBotProfile.id,
      id,
    }));
  };

  const clearAgentMemory = () => {
    if (!activeBotProfile || !window.confirm(`清空 ${activeBotProfile.name} 的全部记忆？`)) return;
    void run(() => execute({
      type: "memory.clear",
      requestId: nextRequestId("memory-clear"),
      agentId: activeBotProfile.id,
    }));
  };

  const refreshAgentWorkflows = () => {
    if (!activeBotProfile) return;
    setAgentWorkflowForId(activeBotProfile.id);
    void run(() => execute({
      type: "workflow.list",
      requestId: nextRequestId("workflow-list"),
      agentId: activeBotProfile.id,
    }));
  };

  const saveAgentWorkflow = async (draft: {
    id?: string;
    name: string;
    description: string;
    body: string;
    trigger?: WorkflowTrigger;
    sourceRef?: string;
  }) => {
    if (!activeBotProfile) return;
    await run(() => execute({
      type: "workflow.upsert",
      requestId: nextRequestId("workflow-upsert"),
      agentId: activeBotProfile.id,
      ...draft,
    }));
    refreshAgentWorkflows();
  };

  const setAgentWorkflowEnabled = async (id: string, enabled: boolean) => {
    if (!activeBotProfile) return;
    await run(() => execute({
      type: "workflow.setEnabled",
      requestId: nextRequestId("workflow-toggle"),
      agentId: activeBotProfile.id,
      id,
      enabled,
    }));
    refreshAgentWorkflows();
  };

  const runAgentWorkflow = async (id: string) => {
    if (!activeBotProfile) return;
    setChatDispatching(true);
    await run(() => execute({
      type: "workflow.run",
      requestId: nextRequestId("workflow-run"),
      agentId: activeBotProfile.id,
      id,
    }));
  };

  const deleteAgentWorkflow = async (id: string) => {
    if (!activeBotProfile) return;
    await run(() => execute({
      type: "workflow.delete",
      requestId: nextRequestId("workflow-delete"),
      agentId: activeBotProfile.id,
      id,
    }));
    refreshAgentWorkflows();
  };

  const importAgentWorkflowMarkdown = async (markdown: string, fallbackName?: string) => {
    if (!activeBotProfile) return;
    await run(() => execute({
      type: "workflow.importMarkdown",
      requestId: nextRequestId("workflow-import"),
      agentId: activeBotProfile.id,
      markdown,
      fallbackName,
    }));
    refreshAgentWorkflows();
  };

  const importAgentWorkflowLiveSource = async (source: string, fallbackName?: string) => {
    if (!activeBotProfile) return;
    await run(() => execute({
      type: "workflow.importLiveSource",
      requestId: nextRequestId("workflow-live"),
      agentId: activeBotProfile.id,
      source,
      fallbackName,
    }));
    refreshAgentWorkflows();
  };

  const callMcpTool = async () => {
    if (!mcpToolServer.trim() || !mcpToolName.trim()) return;
    let argumentsValue: unknown = {};
    try {
      argumentsValue = mcpToolArguments.trim() ? JSON.parse(mcpToolArguments) : {};
    } catch {
      setError("MCP 工具参数必须是有效 JSON。");
      return;
    }
    setMcpToolResult("");
    await run(() => execute({
      type: "mcp.toolCall",
      requestId: nextRequestId("mcp-tool"),
      server: mcpToolServer.trim(),
      tool: mcpToolName.trim(),
      arguments: argumentsValue,
    }));
  };

  const setPreference = <Key extends keyof HostPreferences>(
    key: Key,
    value: HostPreferences[Key],
  ) => setPreferences((current) => ({ ...current, [key]: value }));

  const clickComputerSnapshot = (event: React.MouseEvent<HTMLImageElement>) => {
    if (!computerSnapshot || !computerStatus?.inputSupported || !computerStatus.accessibilityGranted) return;
    const bounds = event.currentTarget.getBoundingClientRect();
    if (bounds.width <= 0 || bounds.height <= 0) return;
    const sourceWidth = computerSnapshot.width ?? Math.round(bounds.width);
    const sourceHeight = computerSnapshot.height ?? Math.round(bounds.height);
    const x = Math.max(0, Math.min(sourceWidth - 1, Math.round((event.clientX - bounds.left) / bounds.width * sourceWidth)));
    const y = Math.max(0, Math.min(sourceHeight - 1, Math.round((event.clientY - bounds.top) / bounds.height * sourceHeight)));
    void run(() => execute({
      type: "computer.action",
      requestId: nextRequestId("computer-click"),
      origin: "local-ui",
      agentId: activeBotMarkId,
      action: { action: "click", x, y, button: "left", count: 1, description: "User clicked the local computer preview" },
    }));
  };

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
            <button className={styles.iconButton} type="button" aria-label="通知与错误" data-has-trays={trays.length > 0} onClick={() => setTrayOpen((open) => !open)}>
              <Icon name="bell" />
              {trays.length > 0 ? <span className={styles.trayBadge}>{Math.min(trays.length, 99)}</span> : null}
            </button>
            <button className={styles.iconButton} type="button" aria-label="智能体网络" onClick={openAgentNetwork}>
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
                setActiveGroupId(null);
                setActiveAgentId("mahayana-assistant");
              }}
            >
              <Icon name="plus" />
            </button>
          </div>
        </div>

        {trayOpen ? (
          <section className={styles.trayPopover} aria-label="通知与错误">
            <header>
              <div><strong>通知</strong><small>{trays.length ? `${trays.length} 个需要注意` : "没有需要处理的项目"}</small></div>
              {trays.length ? <button type="button" onClick={() => void run(() => execute({ type: "tray.clear", requestId: nextRequestId("tray-clear") }))}>全部清除</button> : null}
            </header>
            <div className={styles.trayList}>
              {[...trays].reverse().map((tray) => {
                const bot = bots.find((item) => item.id === tray.agentId);
                return (
                  <article key={tray.id}>
                    <BotMark
                      botId={tray.agentId}
                      state="waking"
                      size={30}
                      shape={bot?.avatarShape as BotMarkShape | undefined}
                      color={bot?.avatarColor as BotMarkColor | undefined}
                      label={bot?.name || tray.agentId}
                    />
                    <div>
                      <strong>{tray.title}{tray.count && tray.count > 1 ? ` ×${tray.count}` : ""}</strong>
                      {tray.detail ? <p>{tray.detail}</p> : null}
                      <small>{bot?.name || tray.agentId}</small>
                      {tray.actions?.length ? (
                        <div className={styles.trayActions}>
                          {tray.actions.map((action, index) => (
                            <button key={`${tray.id}-${action.kind}-${index}`} type="button" onClick={() => {
                              if (action.kind === "open-url") window.open(action.url, "_blank", "noopener,noreferrer");
                              if (action.kind === "switch-model") setSelectedModel("auto");
                            }}>
                              {action.kind === "open-url" ? action.label : action.kind === "switch-model" ? "切换模型" : action.label}
                            </button>
                          ))}
                        </div>
                      ) : null}
                    </div>
                    <button type="button" aria-label={`关闭 ${tray.title}`} onClick={() => void run(() => execute({ type: "tray.dismiss", requestId: nextRequestId("tray-dismiss"), id: tray.id }))}>×</button>
                  </article>
                );
              })}
              {!trays.length ? <p className={styles.trayEmpty}>任务失败、需要恢复的后台工作和其他错误会显示在这里。</p> : null}
            </div>
          </section>
        ) : null}

        <label className={styles.searchBox}>
          <Icon name="search" size={16} />
          <input
            aria-label="搜索会话"
            placeholder="搜索"
            value={conversationSearch}
            onChange={(event) => setConversationSearch(event.target.value)}
          />
        </label>

        {conversationSearch.trim() ? (
          <section className={styles.globalSearchResults} aria-label="全局搜索结果">
            <header>
              <strong>全局搜索</strong>
              <small>{searchPending ? "搜索中…" : `${searchMessageMatches.length} 条消息 · ${searchMediaMatches.length} 个文件`}</small>
            </header>
            {searchMessageMatches.length ? (
              <div className={styles.globalSearchSection}>
                <span>消息</span>
                {searchMessageMatches.map((match) => (
                  <button
                    type="button"
                    key={`${match.agentId}:${match.entryId}`}
                    onClick={() => {
                      setActiveGroupId(null);
                      setActiveAgentId(match.agentId);
                      void run(() => execute({
                        type: "conversation.open",
                        requestId: nextRequestId("search-open"),
                        conversationId: match.conversationId,
                      }));
                    }}
                  >
                    <BotMark botId={match.agentId} size={24} className={styles.globalSearchBotMark} label={match.agentName} />
                    <span><strong>{match.agentName}</strong><small>{match.snippet}</small></span>
                  </button>
                ))}
              </div>
            ) : null}
            {searchMediaMatches.length ? (
              <div className={styles.globalSearchSection}>
                <span>文件</span>
                {searchMediaMatches.map((match) => (
                  <article key={match.path} title={match.path}>
                    <span className={styles.globalSearchFileIcon}>⌑</span>
                    <span><strong>{match.name}</strong><small>{match.agentName} · {Math.max(1, Math.round(match.sizeBytes / 1024))} KB</small></span>
                  </article>
                ))}
              </div>
            ) : null}
            {!searchPending && !searchMessageMatches.length && !searchMediaMatches.length ? <p>没有找到匹配的消息或文件。</p> : null}
          </section>
        ) : null}

        <nav className={styles.agentList} aria-label="智能体会话">
          <button
            className={activeAgentId === "mahayana-assistant" ? styles.agentActive : styles.agentItem}
            type="button"
            onClick={() => { setActiveGroupId(null); setActiveAgentId("mahayana-assistant"); }}
          >
            <BotMark botId="mahayana-assistant" state={backgroundWorkingAgents.has("mahayana-assistant") ? "working" : activeAgentId === "mahayana-assistant" && !activeGroupId ? activeBotState : "idle"} size={38} shape={primaryBotProfile?.avatarShape as BotMarkShape | undefined} color={primaryBotProfile?.avatarColor as BotMarkColor | undefined} className={styles.sidebarBotMark} label={primaryBotProfile?.name || "大乘助手"} />
            <span className={styles.agentCopy}>
              <span><strong>大乘助手</strong><time>现在</time></span>
              <small>{chatDispatching || operationState === "running" ? "正在工作…" : "Mahayana Runtime 已连接"}</small>
            </span>
          </button>
          {visibleConversations
            .filter((conversation) => conversation.id !== "codex:agent:assistant")
            .map((conversation) => (
              <button
                key={conversation.id}
                className={activeConversationId === conversation.id ? styles.agentActive : styles.agentItem}
                type="button"
                onClick={() => {
                  setActiveGroupId(null);
                  void run(() =>
                    execute({
                      type: "conversation.open",
                      requestId: nextRequestId("conversation"),
                      conversationId: conversation.id,
                    }),
                  );
                }}
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
              className={!activeGroupId && activeConversationId === bot.conversationId ? styles.agentActive : styles.agentItem}
              type="button"
              onClick={() => {
                setActiveGroupId(null);
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
              <BotMark
                botId={bot.id}
                state={backgroundWorkingAgents.has(bot.id) ? "working" : activeAgentId === bot.id && !activeGroupId ? activeBotState : "idle"}
                size={38}
                shape={bot.avatarShape as BotMarkShape | undefined}
                color={bot.avatarColor as BotMarkColor | undefined}
                className={styles.sidebarBotMark}
                label={bot.name}
              />
              <span className={styles.agentCopy}>
                <span><strong>{bot.name}</strong></span>
                <small>{bot.title ? `${bot.title} · ` : ""}{bot.description}</small>
              </span>
            </button>
          ))}
          <div className={styles.groupListHeading}>
            <span>群聊</span>
            <button type="button" aria-label="新建群聊" onClick={() => setGroupEditorId("new")}>＋</button>
          </div>
          {groups.map((group) => (
            <button
              key={group.id}
              className={activeGroupId === group.id ? styles.agentActive : styles.agentItem}
              type="button"
              onClick={() => {
                setActiveGroupId(group.id);
                setComputerOpen(false);
                setAgentSettingsOpen(false);
              }}
            >
              <GroupAvatarStack group={group} bots={bots} size={26} />
              <span className={styles.agentCopy}>
                <span><strong>{group.name}</strong></span>
                <small>{group.memberIds.length} 个 Bot · {group.messages.length ? `${group.messages.length} 条消息` : "新群聊"}</small>
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
                  setActiveGroupId(null);
                  setActiveAgentId(app.id);
                  if (openedMiniApp !== app.id) openMiniApp(app.id);
                }}
              >
                <BotMark botId={app.id} state={activeAgentId === app.id ? activeBotState : "idle"} size={38} className={styles.sidebarBotMark} label={`${app.title}机器人`} />
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
        {activeGroup ? (
          <GroupChatPanel
            group={activeGroup}
            bots={bots}
            previews={activeGroupPreviews}
            disabled={hostStatus !== "ready"}
            onSend={sendGroupMessage}
            onEdit={() => setGroupEditorId(activeGroup.id)}
            onDelete={deleteActiveGroup}
          />
        ) : (
          <>
        <header className={styles.chatHeader}>
          <div className={styles.headerIdentity}>
            <BotMark botId={activeBotMarkId} state={activeBotState} size={22} shape={activeBotShape} color={activeBotColor} className={styles.headerBotMark} label={activeBotProfile?.name || (activeAgent ? `${activeAgent.title}机器人` : "大乘助手")} />
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
            aria-label={remoteDesktopState?.channelOpen ? "这台电脑正在被已配对手机远程控制" : "大乘助手的电脑"}
            aria-expanded={computerOpen}
            data-remote-live={remoteDesktopState?.channelOpen ? "true" : "false"}
            onClick={() => setComputerOpen((current) => !current)}
          >
            <Icon name="computer" size={16} />
            {remoteDesktopState?.channelOpen ? <span className={styles.remoteLiveDot} aria-hidden="true" /> : null}
          </button>
        </header>

        {error ? <p role="alert" className={styles.error}>{error}</p> : null}

        <div className={styles.conversation}>
          <div className={styles.welcome}>
            <BotMark botId={activeBotMarkId} state={activeBotState} size={66} shape={activeBotShape} color={activeBotColor} className={styles.welcomeBotMark} label={activeBotProfile?.name || (activeAgent ? `${activeAgent.title}机器人` : "大乘助手")} />
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
                {message.role === "assistant" ? (
                  <BotMark
                    botId={activeBotMarkId}
                    state={(chatDispatching || operationState === "running") && (!activeOperationId || !message.operationId || message.operationId === activeOperationId) ? activeBotState : "idle"}
                    size={28}
                    shape={activeBotShape}
                    color={activeBotColor}
                    className={styles.messageBotMark}
                    label={activeAgent ? `${activeAgent.title}机器人` : "大乘助手"}
                  />
                ) : null}
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
          </>
        )}
      </section>

      {groupEditorId ? (
        <GroupEditor
          group={editingGroup}
          bots={bots}
          onSave={saveGroup}
          onClose={() => setGroupEditorId(null)}
        />
      ) : null}

      {computerOpen && !activeGroup ? <aside className={styles.activityPanel}>
        <div className={styles.computerPanelHeader}>
          {agentSettingsOpen ? <strong>设置</strong> : <button type="button" aria-label="智能体设置" onClick={openAgentSettings}><Icon name="settings" size={15} /></button>}
          <button type="button" aria-label="关闭电脑面板" onClick={() => setComputerOpen(false)}><Icon name="close" size={16} /></button>
        </div>
        {agentSettingsOpen ? (
          <section className={styles.agentSettingsPanel}>
            <button type="button" onClick={() => setAgentSettingsOpen(false)}>← 返回电脑与例程</button>
            <BotMark botId={activeBotMarkId} state={activeBotState} size={66} shape={activeBotShape} color={activeBotColor} className={styles.settingsBotMark} label={activeBotProfile?.name || (activeAgent ? `${activeAgent.title}机器人` : "大乘助手")} />
            <label><span>名称</span><input value={agentName} onChange={(event) => setAgentName(event.target.value)} onBlur={() => updateActiveBotProfile({ name: agentName })} /></label>
            <label><span>职衔</span><input value={agentTitle} onChange={(event) => setAgentTitle(event.target.value)} onBlur={() => updateActiveBotProfile({ title: agentTitle })} placeholder="描述这个智能体的工作" /></label>
            <label><span>描述</span><textarea value={agentDescription} onChange={(event) => setAgentDescription(event.target.value)} onBlur={() => updateActiveBotProfile({ description: agentDescription })} placeholder="这个智能体用于什么" rows={4} /></label>
            <label className={styles.agentNotification}><span><strong>通知</strong><small>智能体完成工作或需要输入时通知我</small></span><input type="checkbox" checked={agentNotifications} onChange={(event) => { const enabled = event.target.checked; setAgentNotifications(enabled); updateActiveBotProfile({ notificationsEnabled: enabled }); }} /></label>
            {activeBotProfile ? (
              <section className={styles.agentMemoryPanel}>
                <header>
                  <div><strong>Memory</strong><small>{agentMemoryForId === activeBotProfile.id ? `${agentMemoryCount} 条持久记忆` : "正在读取…"}</small></div>
                  {agentMemoryCount > 0 ? <button type="button" onClick={clearAgentMemory}>清空</button> : null}
                </header>
                <div className={styles.agentMemoryComposer}>
                  <select value={agentMemoryKind} onChange={(event) => setAgentMemoryKind(event.target.value as MemoryKind)}>
                    <option value="profile">Profile</option>
                    <option value="log">Log</option>
                  </select>
                  <input value={agentMemoryDraft} maxLength={500} onChange={(event) => setAgentMemoryDraft(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") { event.preventDefault(); addAgentMemory(); } }} placeholder="记录一条持久事实…" />
                  <button type="button" onClick={addAgentMemory} disabled={!agentMemoryDraft.trim()}>＋</button>
                </div>
                <div className={styles.agentMemoryList}>
                  {agentMemories.map((memory) => (
                    <article key={memory.id}>
                      <span data-kind={memory.kind}>{memory.kind}</span>
                      <p>{memory.content}</p>
                      <button type="button" aria-label={`忘记 ${memory.content}`} onClick={() => removeAgentMemory(memory.id)}>×</button>
                    </article>
                  ))}
                  {agentMemoryForId === activeBotProfile.id && !agentMemories.length ? <p className={styles.agentMemoryEmpty}>还没有记忆。Profile 会每轮带入；Log 按重要性与最近时间召回。</p> : null}
                </div>
                {agentMemoryLocation ? <small className={styles.agentMemoryLocation}>{agentMemoryLocation}</small> : null}
              </section>
            ) : null}
            {activeBotProfile ? (
              <AgentWorkflowPanel
                agentId={activeBotProfile.id}
                workflows={agentWorkflowForId === activeBotProfile.id ? agentWorkflows : []}
                onRefresh={refreshAgentWorkflows}
                onSave={saveAgentWorkflow}
                onSetEnabled={setAgentWorkflowEnabled}
                onRun={runAgentWorkflow}
                onDelete={deleteAgentWorkflow}
                onImportMarkdown={importAgentWorkflowMarkdown}
                onImportLiveSource={importAgentWorkflowLiveSource}
              />
            ) : null}
            {activeBotProfile ? (
              <section className={styles.agentAuditPanel}>
                <header>
                  <div><strong>行动审计</strong><small>Shell、MCP 和自动审批的持久记录</small></div>
                  <button type="button" onClick={() => void run(() => execute({ type: "audit.list", requestId: nextRequestId("audit-refresh"), agentId: activeBotProfile.id, limit: 100 }))}>刷新</button>
                </header>
                <div className={styles.agentAuditList}>
                  {(auditAgentId === activeBotProfile.id ? auditRecords : []).slice(-30).reverse().map((record, index) => {
                    const row = objectValue(record);
                    const action = objectValue(row.action);
                    const title = String(action.kind ?? "action");
                    const detail = String(action.command ?? action.toolName ?? action.capability ?? action.status ?? "");
                    return <article key={`${String(row.eventId ?? index)}-${index}`}><span>{title.slice(0, 1).toUpperCase()}</span><div><strong>{title}</strong><p>{detail || JSON.stringify(action)}</p><small>{String(row.ts ?? "")}</small></div></article>;
                  })}
                  {auditAgentId === activeBotProfile.id && !auditRecords.length ? <p className={styles.agentAuditEmpty}>还没有可审计的操作。</p> : null}
                </div>
              </section>
            ) : null}
          </section>
        ) : (
          <>
            <section className={styles.computerPreview} data-ready={computerSnapshot ? "true" : "false"}>
              <header>
                <div>
                  <strong>这台电脑</strong>
                  <small>{computerStatus?.platform === "macos" ? "用户的 Mac" : computerStatus?.platform ?? "正在读取…"}</small>
                </div>
                <span data-active={remoteDesktopState?.channelOpen ? "true" : "false"}>{remoteDesktopState?.channelOpen ? "REMOTE ACTIVE" : preferences.remoteControlEnabled ? "REMOTE READY" : "REMOTE OFF"}</span>
              </header>
              <div className={styles.computerScreen}>
                {computerSnapshot ? (
                  <img
                    src={computerSnapshot.dataUrl}
                    alt="这台电脑的实时屏幕"
                    draggable={false}
                    onClick={clickComputerSnapshot}
                    data-controllable={computerStatus?.accessibilityGranted ? "true" : "false"}
                  />
                ) : (
                  <span className={computerRefreshing || operationState === "running" ? styles.computerPulse : undefined} />
                )}
              </div>
              <div className={styles.computerPermissionStrip}>
                {computerStatus?.screenRecordingGranted ? (
                  <span data-ok="true">屏幕录制 ✓</span>
                ) : (
                  <button type="button" onClick={() => void transport.openSystemSettings("screen-recording").catch((cause) => setError(cause instanceof Error ? cause.message : String(cause)))}>授权屏幕录制</button>
                )}
                {computerStatus?.accessibilityGranted ? (
                  <span data-ok="true">辅助功能 ✓</span>
                ) : (
                  <button type="button" onClick={() => void transport.openSystemSettings("accessibility").catch((cause) => setError(cause instanceof Error ? cause.message : String(cause)))}>授权辅助功能</button>
                )}
                <span data-ok={preferences.aiComputerControlEnabled ? "true" : "false"}>AI {preferences.aiComputerControlEnabled ? "可控制" : "已关闭"}</span>
              </div>
              <small>{computerSnapshot ? "点击画面即可控制本机；手机与 AI 使用同一套动作。" : computerStatus?.screenRecordingGranted === false ? "请在 macOS 隐私与安全中允许屏幕录制。" : "正在连接这台电脑的屏幕…"}</small>
              {preferences.remoteControlEnabled ? (
                <section className={styles.remotePairingPanel}>
                  <header>
                    <div>
                      <strong>手机远程控制</strong>
                      <small>{remoteDesktopState?.channelOpen ? "已建立端到端控制通道" : auth?.loggedIn ? "等待已配对手机连接" : "请先登录同一大乘账户"}</small>
                    </div>
                    {remoteDesktopState?.channelOpen ? <i data-live="true" /> : <i />}
                  </header>
                  {remoteDesktopState?.registration ? (
                    <div className={styles.remotePairingCode}>
                      <span>配对码</span>
                      <strong>{remoteDesktopState.registration.pairingCode}</strong>
                      <small>有效至 {new Date(remoteDesktopState.registration.pairingExpiresAt * 1000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</small>
                      <button type="button" onClick={() => void remoteDesktopControllerRef.current?.refreshPairingCode().catch((cause) => setError(cause instanceof Error ? cause.message : String(cause)))}>刷新</button>
                    </div>
                  ) : null}
                  {remoteDesktopState?.activeSessionId ? (
                    <div className={styles.remoteActiveSession}>
                      <span><strong>正在远控</strong><small>{remoteDesktopState.activeClientId ?? "已配对手机"} · {remoteDesktopState.connectionState}</small></span>
                      <button type="button" onClick={() => void remoteDesktopControllerRef.current?.disconnectActive()}>断开</button>
                    </div>
                  ) : null}
                  {remoteDesktopState?.clients.length ? (
                    <div className={styles.remoteClientList}>
                      {remoteDesktopState.clients.map((client) => (
                        <div key={client.clientId}>
                          <span><strong>{client.label}</strong><small>已配对 · {new Date(client.pairedAt * 1000).toLocaleDateString()}</small></span>
                          <button type="button" onClick={() => void remoteDesktopControllerRef.current?.revokeClient(client.clientId).catch((cause) => setError(cause instanceof Error ? cause.message : String(cause)))}>撤销</button>
                        </div>
                      ))}
                    </div>
                  ) : auth?.loggedIn ? <p>手机打开“远程电脑”，输入上面的 8 位配对码即可绑定。</p> : null}
                  {remoteDesktopState?.error ? <p className={styles.remoteError}>{remoteDesktopState.error}</p> : null}
                </section>
              ) : null}
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

        <section className={styles.teachCard}>
          <div className={styles.cardHeading}>
            <div>
              <strong>Teach</strong>
              <small>录一次操作，保存后自动学习成 Workflow</small>
            </div>
            <span className={styles.teachState} data-state={teachStatus.state}>{teachStatus.state === "recording" ? "REC" : "IDLE"}</span>
          </div>
          {teachStatus.state === "recording" ? (
            <div className={styles.teachRecordingBody}>
              <div className={styles.teachTimer}>
                <i />
                <strong>{formatElapsedMs(Math.min(teachStatus.maxDurationMs, teachClockMs - (teachStatus.startedAtMs ?? teachClockMs)))}</strong>
                <span>/ {formatElapsedMs(teachStatus.maxDurationMs)}</span>
              </div>
              <p>{teachStatus.agentId === activeBotMarkId ? "正在录制当前 Bot 的演示。" : `正在为 ${bots.find((bot) => bot.id === teachStatus.agentId)?.name ?? teachStatus.agentId} 录制。`}</p>
              <div>
                <button
                  type="button"
                  disabled={teachStatus.agentId !== activeBotMarkId}
                  onClick={() => void run(() => execute({ type: "teach.stop", requestId: nextRequestId("teach-save"), agentId: teachStatus.agentId ?? activeBotMarkId, save: true }))}
                >保存并学习</button>
                <button
                  type="button"
                  disabled={teachStatus.agentId !== activeBotMarkId}
                  onClick={() => void run(() => execute({ type: "teach.stop", requestId: nextRequestId("teach-cancel"), agentId: teachStatus.agentId ?? activeBotMarkId, save: false }))}
                >取消录制</button>
              </div>
            </div>
          ) : (
            <div className={styles.teachIdleBody}>
              <p>开始后会录制当前屏幕，最长 10 分钟。停止并保存后，该 Bot 会在后台分析演示并生成可复用的 SKILL.md。</p>
              <button
                type="button"
                onClick={() => { setTeachResult(null); void run(() => execute({ type: "teach.start", requestId: nextRequestId("teach-start"), agentId: activeBotMarkId, entryPoint: "screen_hover" })); }}
              >开始教我操作</button>
            </div>
          )}
          {teachResult ? (
            <div className={styles.teachLastResult} data-saved={teachResult.saved}>
              <strong>{teachResult.saved ? "演示已保存并开始学习" : "演示已丢弃"}</strong>
              <small>{formatElapsedMs(teachResult.durationMs)}{teachResult.saved ? ` · ${teachResult.videoPath}` : ""}</small>
            </div>
          ) : null}
        </section>

        <section className={styles.subagentCard}>
          <div className={styles.cardHeading}>
            <div>
              <strong>Subagents</strong>
              <small>{subagents.length ? `${subagents.length} 个子 Agent · ${asyncTasks.length} 个后台任务运行中` : "Codex 多 Agent"}</small>
            </div>
            <button
              type="button"
              onClick={() => {
                const agentId = subagentAgentId ?? (bots.some((bot) => bot.id === activeAgentId) ? activeAgentId : "mahayana-assistant");
                const stamp = Date.now();
                void run(() => Promise.all([
                  execute({ type: "subagent.list", requestId: `subagent-refresh-${stamp}`, agentId }),
                  execute({ type: "asyncTask.list", requestId: `async-task-refresh-${stamp}`, agentId }),
                ]).then(() => undefined));
              }}
            >刷新</button>
          </div>
          {asyncTasks.length ? (
            <div className={styles.asyncTaskStrip}>
              {asyncTasks.map((task) => (
                <article key={task.id}>
                  <span data-kind={task.kind}>↻</span>
                  <div><strong>{task.label}</strong><small>{task.kind}{task.subagentType ? ` · ${task.subagentType}` : ""}</small></div>
                </article>
              ))}
            </div>
          ) : null}
          <div className={styles.subagentList}>
            {subagents.map((subagent) => (
              <article key={subagent.id} data-status={subagent.status}>
                <span><i /></span>
                <div>
                  <strong>{subagent.title}</strong>
                  <small>{subagent.subagentType} · {subagent.status} · {subagent.id.slice(0, 10)}</small>
                  {subagent.detail ? <p>{subagent.detail}</p> : null}
                </div>
              </article>
            ))}
            {!subagents.length ? <p className={styles.subagentEmpty}>模型调用 spawn_agent 后，子 Agent 的身份、状态和后台任务会显示在这里。</p> : null}
          </div>
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
                <BotMark
                  botId={networkSender?.id ?? "mahayana-assistant"}
                  state={networkSender && backgroundWorkingAgents.has(networkSender.id) ? "working" : activeBotState}
                  size={48}
                  shape={networkSender?.avatarShape as BotMarkShape | undefined}
                  color={networkSender?.avatarColor as BotMarkColor | undefined}
                  className={styles.networkHubBotMark}
                  label={networkSender?.name ?? "大乘助手"}
                />
                <strong>{networkSender?.name ?? "大乘助手"}</strong><small>当前发送方 · Agent</small>
              </article>
              <div className={styles.networkNodes}>
                {bots.filter((bot) => bot.id !== networkSender?.id).map((bot) => (
                  <button
                    key={bot.id}
                    type="button"
                    data-selected={networkTargetId === bot.id}
                    onClick={() => setNetworkTargetId(bot.id)}
                  >
                    <BotMark botId={bot.id} state={backgroundWorkingAgents.has(bot.id) ? "working" : "idle"} size={31} shape={bot.avatarShape as BotMarkShape | undefined} color={bot.avatarColor as BotMarkColor | undefined} className={styles.networkNodeBotMark} label={bot.name} />
                    <strong>{bot.name}</strong>
                    <small>{backgroundWorkingAgents.has(bot.id) ? "正在后台工作" : bot.description || "Agent"}</small>
                  </button>
                ))}
                {networkSender ? groups.filter((group) => group.memberIds.includes(networkSender.id)).map((group) => (
                  <button key={group.id} type="button" data-selected={networkTargetId === group.id} onClick={() => setNetworkTargetId(group.id)}>
                    <GroupAvatarStack group={group} bots={bots} size={31} />
                    <strong>{group.name}</strong>
                    <small>群聊 · {group.memberIds.length} 个成员</small>
                  </button>
                )) : null}
              </div>
              {!networkTargets.length ? (
                <div className={styles.networkEmpty}><Icon name="network" size={26} /><strong>还没有其他智能体</strong><p>创建几个 Bot 后，可以让它们异步互相协作。</p><button type="button" onClick={() => { setNetworkOpen(false); setMarketplaceOpen(true); setMarketplaceSection("bots"); }}>创建 Bot</button></div>
              ) : null}
            </div>
            <section className={styles.networkMessaging}>
              <header>
                <div><strong>Agent-to-Agent</strong><small>异步发送；目标 Bot 会在自己的会话中被隐藏 turn 唤醒。</small></div>
                {lastBroadcastResult ? <em>{lastBroadcastResult.scheduled}/{lastBroadcastResult.total} 已调度</em> : null}
              </header>
              <div className={styles.networkComposer}>
                <select value={networkTargetId} onChange={(event) => setNetworkTargetId(event.target.value)}>
                  <option value="">选择目标</option>
                  {networkTargets.map((target) => <option key={target.id} value={target.id}>{target.name}</option>)}
                </select>
                <textarea value={networkMessage} onChange={(event) => setNetworkMessage(event.target.value)} rows={3} maxLength={8000} placeholder="给另一个 Agent 或群聊发送信息…" />
                <label><input type="checkbox" checked={networkPriority} onChange={(event) => setNetworkPriority(event.target.checked)} /><span>优先消息</span></label>
                <div>
                  <button type="button" disabled={!networkSender || !networkTargetId || !networkMessage.trim()} onClick={() => void sendNetworkMessage()}>发送给目标</button>
                  <button type="button" disabled={!networkMessage.trim()} onClick={() => void broadcastNetworkMessage()}>广播给全部 Bot</button>
                </div>
              </div>
              <div className={styles.peerMessageList}>
                {peerMessages
                  .filter((message) => !networkSender || message.fromAgentId === networkSender.id || message.targetId === networkSender.id)
                  .slice(-20)
                  .reverse()
                  .map((message) => (
                    <article key={message.id}>
                      <span>{message.priority ? "!" : "↗"}</span>
                      <div><strong>{message.fromAgentName} → {message.targetName}</strong><p>{message.text}</p><small>{new Date(message.createdAtMs).toLocaleString()}</small></div>
                    </article>
                  ))}
                {!peerMessages.length ? <p className={styles.networkNoMessages}>还没有 Agent 间消息。</p> : null}
              </div>
            </section>
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
                ["mcp", "MCP", "MCP Servers"],
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
                    {settingsSection === "general" ? "通用设置" : settingsSection === "mcp" ? "MCP 与 Apps" : settingsSection === "usage" ? "用量与计费" : "Grok Bot 更新"}
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
                      checked={preferences.remoteControlEnabled}
                      label="允许已配对手机远程控制此电脑"
                      description="默认关闭。开启后，只有当前账户明确配对的设备才能建立加密远控会话；桌面会持续显示远控状态。"
                      onChange={(value) => setPreference("remoteControlEnabled", value)}
                    />
                    <ToggleRow
                      checked={preferences.aiComputerControlEnabled}
                      label="允许 AI 控制此电脑"
                      description="AI 使用与手机完全相同的截图、点击、移动、拖拽、输入、按键、滚动和等待动作，并受本机工具审批规则约束。"
                      onChange={(value) => setPreference("aiComputerControlEnabled", value)}
                    />
                    <ToggleRow
                      checked={preferences.securityKeys}
                      label="使用硬件安全密钥"
                      description="允许智能体请求使用连接到电脑的安全密钥，每次使用仍需确认。"
                      onChange={(value) => setPreference("securityKeys", value)}
                    />
                    <label className={styles.settingsRow}>
                      <span><strong>本机工具权限</strong><small>Never 会拒绝本机命令；Ask 每次审批；Always 只对本机工具建立会话级授权。</small></span>
                      <select value={preferences.localToolPermission} onChange={(event) => setPreference("localToolPermission", event.target.value as HostPreferences["localToolPermission"])}>
                        <option value="never">Never</option><option value="ask">Ask</option><option value="always">Always</option>
                      </select>
                    </label>
                    <ToggleRow
                      checked={preferences.webauthnProxyEnabled}
                      label="WebAuthn 代理"
                      description="允许网页认证请求转交给桌面安全密钥代理；实际使用仍受审批和平台能力限制。"
                      onChange={(value) => setPreference("webauthnProxyEnabled", value)}
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
              ) : settingsSection === "mcp" ? (
                <div className={styles.settingsSections}>
                  <SettingsGroup title="MCP Servers" description="Model Context Protocol">
                    <div className={styles.mcpToolbar}>
                      <p className={styles.settingsHelp}>服务器状态和 OAuth 直接来自 Mahayana/Codex Runtime。</p>
                      <button type="button" onClick={() => void run(() => execute({ type: "mcp.refresh", requestId: nextRequestId("mcp-refresh") }))}>刷新服务器</button>
                    </div>
                    <div className={styles.mcpServerList}>
                      {mcpServers.map((server, index) => {
                        const name = mcpServerName(server);
                        const status = mcpServerStatus(server);
                        const tools = mcpServerTools(server);
                        const connected = /connected|ready|authenticated|ok/i.test(status);
                        return (
                          <article key={`${name}-${index}`} data-state={status}>
                            <span className={styles.mcpStatusDot} />
                            <div><strong>{name}</strong><small>{status} · {tools.length} tools</small>{tools.length ? <p>{tools.slice(0, 8).join(" · ")}</p> : null}</div>
                            <div>
                              <button type="button" onClick={() => { setMcpToolServer(name); setMcpToolName(tools[0] ?? ""); }}>使用</button>
                              <button type="button" onClick={() => void run(() => execute({ type: connected ? "mcp.oauthLogout" : "mcp.oauthLogin", requestId: nextRequestId("mcp-oauth"), server: name }))}>{connected ? "退出授权" : "OAuth 登录"}</button>
                            </div>
                          </article>
                        );
                      })}
                      {!mcpServers.length ? <p className={styles.settingsEmpty}>当前 Runtime 没有报告 MCP Server。</p> : null}
                    </div>
                  </SettingsGroup>

                  <SettingsGroup title="MCP Apps" description="Connector directory">
                    <div className={styles.mcpAppsList}>
                      {mcpApps.map((app, index) => {
                        const record = objectValue(app);
                        const name = String(record.name ?? record.title ?? record.id ?? `App ${index + 1}`);
                        const detail = String(record.description ?? record.status ?? record.id ?? "MCP App");
                        return <article key={`${name}-${index}`}><span>{name.slice(0, 1)}</span><div><strong>{name}</strong><small>{detail}</small></div></article>;
                      })}
                      {!mcpApps.length ? <p className={styles.settingsEmpty}>当前账户没有可用的 MCP Apps。</p> : null}
                    </div>
                  </SettingsGroup>

                  <SettingsGroup title="直接工具调用" description="Direct MCP tool call">
                    <div className={styles.mcpToolForm}>
                      <label><span>Server</span><input value={mcpToolServer} onChange={(event) => setMcpToolServer(event.target.value)} placeholder="github" /></label>
                      <label><span>Tool</span><input value={mcpToolName} onChange={(event) => setMcpToolName(event.target.value)} placeholder="search_repositories" /></label>
                      <label><span>Arguments (JSON)</span><textarea value={mcpToolArguments} onChange={(event) => setMcpToolArguments(event.target.value)} rows={4} /></label>
                      <button type="button" disabled={!mcpToolServer.trim() || !mcpToolName.trim()} onClick={() => void callMcpTool()}>调用工具</button>
                      {mcpToolResult ? <pre>{mcpToolResult}</pre> : null}
                    </div>
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

      {onboardingStep < 3 || !authResolved || auth?.loggedIn === false ? (
        <div
          className={styles.loginBackdrop}
          data-testid={onboardingStep < 3 ? "onboarding-gate" : "login-gate"}
        >
          {onboardingStep < 3 ? (
            <section className={styles.onboarding} role="dialog" aria-modal="true" aria-labelledby="onboarding-title">
              {onboardingStep === 0 ? (
                <>
                  <h2 id="onboarding-title">认识 Fabushi</h2>
                  <BotMark
                    botId="mahayana-assistant"
                    state="waking"
                    shape="blob"
                    color="black"
                    size={70}
                    className={styles.onboardingBotMark}
                    label="Fabushi Bot"
                  />
                  <div className={styles.onboardingPrompt}><span>把任何任务交给你的智能体团队</span><i>＋</i><b>↑</b></div>
                </>
              ) : null}
              {onboardingStep === 1 ? (
                <>
                  <h2 id="onboarding-title">给每个 Bot 一份工作</h2>
                  <div className={styles.onboardingBots}>
                    <div>
                      <BotMark botId="onboarding-billing" state="working" color="red" size={70} label="账单跟进 Bot" />
                      <b>账单跟进</b>
                    </div>
                    <div>
                      <BotMark botId="onboarding-standup" state="listening" color="cyan" size={70} label="每周站会 Bot" />
                      <b>每周站会</b>
                    </div>
                    <div>
                      <BotMark botId="onboarding-forecast" state="thinking" color="blue" size={70} label="销售预测 Bot" />
                      <b>销售预测</b>
                    </div>
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
                <button
                  type="button"
                  onClick={() => setOnboardingStep((step) => {
                    const nextStep = Math.min(3, step + 1);
                    if (nextStep === 3) {
                      window.localStorage.setItem(ONBOARDING_COMPLETE_KEY, "1");
                    }
                    return nextStep;
                  })}
                >
                  下一步
                </button>
                {onboardingStep ? <button type="button" onClick={() => setOnboardingStep((step) => Math.max(0, step - 1))}>返回</button> : null}
              </div>
            </section>
          ) : !authResolved ? (
            <section className={styles.grokWelcome} role="status" aria-live="polite">
              <div className={styles.grokTitle}>
                <div className={styles.grokLogo}><span>••</span></div>
                <h2>Fabushi</h2>
              </div>
              <p>正在恢复本地会话…</p>
            </section>
          ) : browserLoginAttempt ? (
            <section className={styles.grokWelcome} role="dialog" aria-modal="true" aria-labelledby="browser-login-title">
              <div className={styles.grokTitle}>
                <div className={styles.grokLogo}><span>••</span></div>
                <h2 id="browser-login-title">在浏览器中继续</h2>
              </div>
              <p>登录方式和密码都只在浏览器中处理。完成授权后 Fabushi 会自动领取会话。</p>
              {loginError ? <output role="status">{loginError}</output> : null}
              <button data-testid="browser-login-reopen" type="button" onClick={() => void reopenBrowserLogin()}>重新打开浏览器 <span>↗</span></button>
              <button data-testid="browser-login-cancel" type="button" onClick={() => void cancelBrowserLogin()}>取消</button>
            </section>
          ) : (
            <section className={styles.grokWelcome} role="dialog" aria-modal="true" aria-labelledby="login-title">
              <div className={styles.grokTitle}>
                <div className={styles.grokLogo}><span>••</span></div>
                <h2 id="login-title">Fabushi</h2>
              </div>
              <p>登录将在系统浏览器中完成；密码和第三方授权不会出现在桌面应用里。</p>
              <button type="button" data-testid="browser-login-start" disabled={loginBusy} onClick={() => void beginBrowserLogin()}>
                {loginBusy ? "正在打开浏览器…" : "登录"} <span>→</span>
              </button>
              {loginError ? <output role="alert">{loginError}</output> : null}
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
