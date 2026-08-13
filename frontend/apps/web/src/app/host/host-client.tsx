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
  ApprovalRequestedEvent,
  AuthProvider,
  AuthProviderId,
  AuthState,
  RuntimeCommand,
} from "../../lib/mahayana-host/contracts";
import { MockMahayanaHostTransport } from "../../lib/mahayana-host/mock-transport";
import { isTauriMahayanaHostAvailable } from "../../lib/mahayana-host/tauri-transport";
import type { MahayanaHostTransport } from "../../lib/mahayana-host/transport";

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

function createInitialFeatureStates(): FeatureStates {
  return Object.fromEntries(
    mahayanaHostFeatures.map((feature) => [feature.id, "pending"]),
  ) as FeatureStates;
}

function Icon({
  name,
  size = 18,
}: {
  name: "plus" | "search" | "plugins" | "settings" | "send" | "close" | "stop" | "shield";
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
  const transport = useMemo<MahayanaHostTransport>(
    () => new MockMahayanaHostTransport(),
    [],
  );
  const requestSequence = useRef(0);
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
    () => new Set(),
  );
  const [openedMiniApp, setOpenedMiniApp] = useState<string | null>(null);
  const [openedMiniAppHtml, setOpenedMiniAppHtml] = useState<string | null>(null);
  const [approval, setApproval] = useState<ApprovalRequestedEvent | null>(null);
  const [approvalState, setApprovalState] = useState("not-requested");
  const [activeOperationId, setActiveOperationId] = useState<string | null>(null);
  const [operationState, setOperationState] = useState("idle");
  const [sessionState, setSessionState] = useState("active");
  const [featureStates, setFeatureStates] = useState<FeatureStates>(
    createInitialFeatureStates,
  );
  const [error, setError] = useState<string | null>(null);
  const [marketplaceOpen, setMarketplaceOpen] = useState(false);
  const [marketplaceSearch, setMarketplaceSearch] = useState("");
  const [busyMiniApp, setBusyMiniApp] = useState<string | null>(null);
  const [auth, setAuth] = useState<AuthState | null>(null);
  const [loginUsername, setLoginUsername] = useState("");
  const [loginPassword, setLoginPassword] = useState("");
  const [loginBusy, setLoginBusy] = useState(false);
  const [loginProvider, setLoginProvider] = useState<AuthProviderId | null>(null);
  const [loginError, setLoginError] = useState<string | null>(null);
  const [authProviders, setAuthProviders] = useState<AuthProvider[]>([]);
  const [passwordLoginOpen, setPasswordLoginOpen] = useState(false);
  const [accountOpen, setAccountOpen] = useState(false);
  const [activeAgentId, setActiveAgentId] = useState("mahayana-assistant");

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
          pass("marketplace.install");
          break;
        case "miniapp.opened":
          setOpenedMiniApp(event.miniAppId);
          setOpenedMiniAppHtml(event.html ?? null);
          setActiveAgentId(event.miniAppId);
          setMarketplaceOpen(false);
          setBusyMiniApp(null);
          pass("miniapp.open");
          break;
        case "approval.requested":
          setApproval(event);
          setApprovalState("pending");
          break;
        case "approval.resolved":
          setApproval(null);
          setApprovalState(event.decision === "allow-once" ? "allowed" : "denied");
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
    await run(() =>
      execute({
        type: "chat.send",
        requestId: nextRequestId("chat"),
        text,
        agentId: activeAgentId,
      }),
    );
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

  const visibleMarketplaceApps = marketplaceApps.filter((app) =>
    `${app.title} ${app.id} ${app.description}`
      .toLowerCase()
      .includes(marketplaceSearch.toLowerCase()),
  );
  const activeMiniApp = marketplaceApps.find((app) => app.id === openedMiniApp);
  const activeAgent =
    activeAgentId === "mahayana-assistant"
      ? undefined
      : marketplaceApps.find((app) => app.id === activeAgentId);
  const displayName =
    auth?.user?.nickname || auth?.user?.username || "大乘用户";

  return (
    <main className={styles.shell} data-testid="mahayana-host">
      <aside className={styles.sidebar}>
        <div className={styles.titlebar}>
          <div className={styles.trafficLights} aria-hidden="true">
            <span />
            <span />
            <span />
          </div>
          <strong>Fabushi</strong>
          <button className={styles.iconButton} type="button" aria-label="新建会话">
            <Icon name="plus" />
          </button>
        </div>

        <label className={styles.searchBox}>
          <Icon name="search" size={16} />
          <input aria-label="搜索会话" placeholder="搜索" />
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
            onClick={() => setAccountOpen(true)}
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
                  <p>{message.text}</p>
                </div>
              </article>
            ))}
          </div>

          <form className={styles.composer} onSubmit={(event) => void sendMessage(event)}>
            <input
              data-testid="chat-input"
              aria-label="消息内容"
              value={input}
              onChange={(event) => setInput(event.target.value)}
              placeholder={activeAgent ? `给${activeAgent.title}机器人发消息…` : "给大乘助手发消息…"}
              disabled={hostStatus !== "ready"}
            />
            <button
              data-testid="send-message"
              type="submit"
              disabled={hostStatus !== "ready" || !input.trim()}
              aria-label="发送消息"
            >
              <Icon name="send" />
            </button>
          </form>
        </div>
      </section>

      <aside className={styles.activityPanel}>
        <div className={styles.activityHeader}>
          <div>
            <span className={styles.activityKicker}>WORKSPACE</span>
            <h2>运行与能力</h2>
          </div>
          <span className={styles.secureBadge}><Icon name="shield" size={14} /> 本地</span>
        </div>

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
      </aside>

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

            <label className={styles.marketSearch}>
              <Icon name="search" size={16} />
              <input
                value={marketplaceSearch}
                onChange={(event) => setMarketplaceSearch(event.target.value)}
                placeholder="搜索插件"
              />
            </label>

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
          </section>
        </div>
      ) : null}

      {approval ? (
        <div className={styles.backdrop}>
          <section className={styles.approvalDialog} role="dialog" aria-modal="true" aria-labelledby="approval-title">
            <span className={styles.approvalIcon}><Icon name="shield" size={24} /></span>
            <h2 id="approval-title">能力审批</h2>
            <p><strong>{approval.miniAppId}</strong> 请求 {approval.capability}</p>
            <small>{approval.reason}</small>
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
            </div>
          </section>
        </div>
      ) : null}

      {auth?.loggedIn === false ? (
        <div className={styles.backdrop} data-testid="login-gate">
          <section className={styles.loginDialog} role="dialog" aria-modal="true" aria-labelledby="login-title">
            <div className={styles.loginBrand}>
              <span className={styles.loginMark}>乘</span>
              <p>FABUSHI</p>
            </div>
            <h2 id="login-title">欢迎回来</h2>
            <small>登录后继续使用智能体、插件市场与安全会话。</small>
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
