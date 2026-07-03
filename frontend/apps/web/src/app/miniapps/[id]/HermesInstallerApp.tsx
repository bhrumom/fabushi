"use client";

import React, { useCallback, useEffect, useRef, useState } from "react";
import {
  Bot,
  CheckCircle2,
  CircleStop,
  PlugZap,
  Send,
  Settings2,
  TerminalSquare,
} from "lucide-react";
import { bootMiniApp, fbApp, hostErrorMessage } from "./miniapp-runtime";
import "./miniapps.css";

const MINIAPP_ID = "official.hermes-installer";
const LOCAL_HOST = "http://127.0.0.1:17393";

type MessageRole = "assistant" | "user" | "terminal" | "hermes";
type Phase = "setup" | "installing" | "ready" | "chatting" | "failed";
type PendingQuestion =
  | "mode"
  | "apiBase"
  | "model"
  | "apiKey"
  | "installDir"
  | "review"
  | null;

type HermesConfig = {
  setupMode: "portal" | "manual" | "existing";
  installDir: string;
  apiBase: string;
  model: string;
  apiKey: string;
  chatCommand: string;
};

type ChatMessage = {
  id: string;
  role: MessageRole;
  text: string;
  level?: string;
};

type HostLog = {
  id?: string;
  seq?: number;
  role?: MessageRole;
  text?: string;
  level?: string;
};

const initialConfig: HermesConfig = {
  setupMode: "portal",
  installDir: "",
  apiBase: "",
  model: "",
  apiKey: "",
  chatCommand: "hermes",
};

const welcomeText =
  "我是 Hermes 安装机器人。你不用复制终端命令，只要回复数字完成配置：\n1. 一键安装 + Nous Portal 登录\n2. 一键安装 + 我提供 OpenAI 兼容配置\n3. 我已安装 Hermes，直接开始对话";

function createMessage(role: MessageRole, text: string, level?: string): ChatMessage {
  return {
    id: `${role}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    role,
    text,
    level,
  };
}

function maskSecret(value: string) {
  const text = value.trim();
  if (!text) return "未填写";
  if (text.length <= 8) return "已填写";
  return `${text.slice(0, 4)}...${text.slice(-4)}`;
}

function normalizeText(value: string) {
  return value.trim().replace(/\s+/g, " ");
}

function looksLikeYes(value: string) {
  return ["1", "继续", "确认", "yes", "y", "ok", "start"].includes(
    normalizeText(value).toLowerCase(),
  );
}

function looksLikeSkip(value: string) {
  return ["", "skip", "跳过", "默认", "无", "none"].includes(
    normalizeText(value).toLowerCase(),
  );
}

function commandPreview(config: HermesConfig) {
  if (config.setupMode === "existing") return "hermes";
  const install = "curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash";
  const setup =
    config.setupMode === "portal"
      ? "hermes setup --portal"
      : [
          config.model ? "hermes config set model <model>" : "",
          config.apiBase ? "hermes config set api_base <apiBase>" : "",
          config.apiKey ? "hermes config set OPENAI_API_KEY <hidden>" : "",
          "hermes setup",
        ]
          .filter(Boolean)
          .join(" && ");
  return `${install} && ${setup}`;
}

function reviewText(config: HermesConfig) {
  return [
    "请确认 Hermes 安装配置：",
    `安装方式：${config.setupMode === "portal" ? "Nous Portal" : config.setupMode === "manual" ? "自定义 API 配置" : "跳过安装"}`,
    `安装目录：${config.installDir || "默认 ~/.hermes"}`,
    `模型：${config.model || "由 Hermes 向导选择"}`,
    `API Base：${config.apiBase || "由 Hermes 向导选择"}`,
    `API Key：${maskSecret(config.apiKey)}`,
    `执行预览：${commandPreview(config)}`,
    "回复 1 开始；回复 2 重新配置；回复 3 跳过安装直接聊天。",
  ].join("\n");
}

function decodeHostBody(response: any) {
  if (typeof response?.body === "string") return response.body;
  if (typeof response?.bodyBase64 === "string" && response.bodyBase64) {
    return window.atob(response.bodyBase64);
  }
  return "";
}

async function callLocalHost<T>(
  path: string,
  options: { method?: "GET" | "POST"; body?: unknown; timeoutMs?: number } = {},
): Promise<T> {
  const method = options.method || "POST";
  const url = `${LOCAL_HOST}${path}`;
  const body = options.body === undefined ? undefined : JSON.stringify(options.body);

  if (fbApp.isHostEnv()) {
    try {
      const response = await fbApp.invoke<any>("localLoopback.fetch", {
        url,
        method,
        headers: { Accept: "application/json", "Content-Type": "application/json" },
        body,
        timeoutMs: options.timeoutMs || 120000,
      });
      const text = decodeHostBody(response);
      return (text ? JSON.parse(text) : response) as T;
    } catch {
      // Fall through to browser fetch for desktop preview and development.
    }
  }

  const response = await fetch(url, {
    method,
    headers: { Accept: "application/json", "Content-Type": "application/json" },
    body,
  });
  const data = await response.json();
  if (!response.ok) throw new Error(data?.message || `Hermes Host HTTP ${response.status}`);
  return data as T;
}

export default function HermesInstallerApp() {
  const [phase, setPhase] = useState<Phase>("setup");
  const [pending, setPending] = useState<PendingQuestion>("mode");
  const [config, setConfig] = useState<HermesConfig>(initialConfig);
  const [messages, setMessages] = useState<ChatMessage[]>([
    createMessage("assistant", welcomeText),
  ]);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);
  const [installSessionId, setInstallSessionId] = useState<string | null>(null);
  const [lastSeq, setLastSeq] = useState(0);
  const lastSeqRef = useRef(0);
  const pollTimerRef = useRef<number | null>(null);

  const postBotMessage = useCallback(async (text: string, level = "info") => {
    try {
      await fbApp.invoke("bot.postMessage", {
        level,
        message: text,
        text,
        payload: { miniAppId: MINIAPP_ID },
      });
    } catch {
      // Browser preview has no host chat to mirror into.
    }
  }, []);

  const addMessage = useCallback(
    (role: MessageRole, text: string, level?: string, mirrorToBot = role !== "user") => {
      const message = createMessage(role, text, level);
      setMessages((current) => [...current.slice(-160), message]);
      if (mirrorToBot) void postBotMessage(text.slice(0, 1800), level);
    },
    [postBotMessage],
  );

  const appendHostLogs = useCallback(
    (logs: HostLog[] = []) => {
      if (!logs.length) return;
      let nextSeq = lastSeqRef.current;
      for (const item of logs) {
        if (typeof item.seq === "number") nextSeq = Math.max(nextSeq, item.seq);
        if (item.text) addMessage(item.role || "terminal", item.text, item.level);
      }
      lastSeqRef.current = nextSeq;
      setLastSeq(nextSeq);
    },
    [addMessage],
  );

  const stopPolling = useCallback(() => {
    if (pollTimerRef.current === null) return;
    window.clearInterval(pollTimerRef.current);
    pollTimerRef.current = null;
  }, []);

  const pollInstallStatus = useCallback(
    async (sessionId: string) => {
      try {
        const data = await callLocalHost<any>(
          `/api/hermes/install/status?id=${encodeURIComponent(sessionId)}&after=${lastSeqRef.current}`,
          { method: "GET" },
        );
        appendHostLogs(data.logs || []);
        if (data.status === "installed") {
          stopPolling();
          setPhase("ready");
          setPending(null);
          addMessage("assistant", "Hermes 已安装完成。现在直接输入消息，就是和 Hermes 对话。");
        } else if (data.status === "failed") {
          stopPolling();
          setPhase("failed");
          addMessage("assistant", "Hermes 安装失败。可以回复 2 重新配置，或启动 Host 后回复 1 重试。", "error");
        }
      } catch (error) {
        addMessage("assistant", hostErrorMessage(error, "读取 Hermes Host 状态失败"), "warn");
      }
    },
    [addMessage, appendHostLogs, stopPolling],
  );

  const startPolling = useCallback(
    (sessionId: string) => {
      stopPolling();
      pollTimerRef.current = window.setInterval(() => {
        void pollInstallStatus(sessionId);
      }, 1200);
    },
    [pollInstallStatus, stopPolling],
  );

  const startInstall = useCallback(
    async (nextConfig: HermesConfig) => {
      setBusy(true);
      setPhase("installing");
      setPending(null);
      addMessage(
        "assistant",
        "开始连接本机 Hermes Host。若尚未启动，请在本机运行：node scripts/hermes-chat-host.mjs",
      );
      try {
        const data = await callLocalHost<any>("/api/hermes/install/start", {
          body: { config: nextConfig },
          timeoutMs: 120000,
        });
        const sessionId = String(data.sessionId || "");
        if (!sessionId) throw new Error("Hermes Host 没有返回 install sessionId");
        setInstallSessionId(sessionId);
        appendHostLogs(data.logs || []);
        startPolling(sessionId);
      } catch (error) {
        setPhase("failed");
        addMessage(
          "assistant",
          `${hostErrorMessage(error, "连接 Hermes Host 失败")}\n请先在电脑本机启动：node scripts/hermes-chat-host.mjs，然后回复 1 重试。`,
          "error",
        );
      } finally {
        setBusy(false);
      }
    },
    [addMessage, appendHostLogs, startPolling],
  );

  const sendInstallReply = useCallback(
    async (text: string) => {
      if (!installSessionId) {
        addMessage("assistant", "还没有安装会话。回复 /install 重新开始。", "warn");
        return;
      }
      try {
        const data = await callLocalHost<any>("/api/hermes/install/reply", {
          body: { sessionId: installSessionId, message: text, after: lastSeqRef.current },
        });
        appendHostLogs(data.logs || []);
      } catch (error) {
        addMessage("assistant", hostErrorMessage(error, "发送安装器输入失败"), "error");
      }
    },
    [addMessage, appendHostLogs, installSessionId],
  );

  const sendHermesChat = useCallback(
    async (text: string) => {
      setBusy(true);
      setPhase("chatting");
      try {
        const data = await callLocalHost<any>("/api/hermes/chat", {
          body: { message: text, config },
          timeoutMs: 120000,
        });
        if (Array.isArray(data.logs) && data.logs.length > 0) {
          for (const item of data.logs as HostLog[]) {
            if (item.role === "user") continue;
            if (item.text) addMessage(item.role || "hermes", item.text, item.level);
          }
        } else {
          addMessage("hermes", data.reply || "Hermes 暂未返回内容。");
        }
        setPhase("ready");
      } catch (error) {
        setPhase("ready");
        addMessage(
          "assistant",
          `${hostErrorMessage(error, "Hermes 对话失败")}\n请确认本机 Host 正在运行，且 hermes 命令可用。`,
          "error",
        );
      } finally {
        setBusy(false);
      }
    },
    [addMessage, config],
  );

  const resetWizard = useCallback(() => {
    stopPolling();
    setPhase("setup");
    setPending("mode");
    setConfig(initialConfig);
    setInstallSessionId(null);
    lastSeqRef.current = 0;
    setLastSeq(0);
    setMessages([createMessage("assistant", welcomeText)]);
  }, [stopPolling]);

  const processIncoming = useCallback(
    async (raw: string) => {
      const text = raw.trim();
      if (!text || busy) return;
      addMessage("user", text, undefined, false);

      const lower = normalizeText(text).toLowerCase();
      if (lower === "/reset") {
        resetWizard();
        return;
      }
      if (lower === "/install") {
        resetWizard();
        return;
      }
      if (lower === "/status") {
        addMessage(
          "assistant",
          `状态：${phase}；安装会话：${installSessionId || "无"}；最后日志序号：${lastSeq}`,
        );
        return;
      }
      if (lower === "/stop") {
        stopPolling();
        await callLocalHost("/api/hermes/chat/stop", { body: {} }).catch(() => null);
        setPhase("ready");
        addMessage("assistant", "已请求停止当前 Hermes 对话进程。");
        return;
      }

      if (phase === "installing") {
        await sendInstallReply(text);
        return;
      }

      if (phase === "ready" || phase === "chatting") {
        await sendHermesChat(text);
        return;
      }

      if (pending === "mode") {
        if (["1", "portal", "nous"].includes(lower)) {
          const next = { ...config, setupMode: "portal" as const };
          setConfig(next);
          setPending("installDir");
          addMessage("assistant", "选择 Nous Portal 快速安装。请输入安装目录，或回复“默认”。");
          return;
        }
        if (["2", "manual", "api"].includes(lower)) {
          const next = { ...config, setupMode: "manual" as const };
          setConfig(next);
          setPending("apiBase");
          addMessage("assistant", "请输入 OpenAI 兼容 API Base URL，或回复“跳过”交给 Hermes 向导。");
          return;
        }
        if (["3", "existing", "已安装"].includes(lower)) {
          setConfig({ ...config, setupMode: "existing" });
          setPhase("ready");
          setPending(null);
          addMessage("assistant", "已进入 Hermes 对话模式。现在输入任何内容都会转给本机 hermes。");
          return;
        }
        addMessage("assistant", "请回复 1、2 或 3。");
        return;
      }

      if (pending === "apiBase") {
        const next = { ...config, apiBase: looksLikeSkip(text) ? "" : text };
        setConfig(next);
        setPending("model");
        addMessage("assistant", "请输入模型名，例如 anthropic/claude-opus-4.6；或回复“跳过”。");
        return;
      }

      if (pending === "model") {
        const next = { ...config, model: looksLikeSkip(text) ? "" : text };
        setConfig(next);
        setPending("apiKey");
        addMessage("assistant", "请输入 API Key；如果走 Hermes 自己的登录/向导，回复“跳过”。");
        return;
      }

      if (pending === "apiKey") {
        const next = { ...config, apiKey: looksLikeSkip(text) ? "" : text };
        setConfig(next);
        setPending("installDir");
        addMessage("assistant", "请输入安装目录，或回复“默认”。");
        return;
      }

      if (pending === "installDir") {
        const next = { ...config, installDir: looksLikeSkip(text) ? "" : text };
        setConfig(next);
        setPending("review");
        addMessage("assistant", reviewText(next));
        return;
      }

      if (pending === "review") {
        if (looksLikeYes(text)) {
          await startInstall(config);
          return;
        }
        if (lower === "2") {
          resetWizard();
          return;
        }
        if (lower === "3") {
          setPhase("ready");
          setPending(null);
          addMessage("assistant", "已跳过安装，进入 Hermes 对话模式。");
          return;
        }
        addMessage("assistant", "请回复 1 开始、2 重配、3 跳过。");
      }
    },
    [
      addMessage,
      busy,
      config,
      installSessionId,
      lastSeq,
      pending,
      phase,
      resetWizard,
      sendHermesChat,
      sendInstallReply,
      startInstall,
      stopPolling,
    ],
  );

  const handleSubmit = async (event?: React.FormEvent) => {
    event?.preventDefault();
    const text = draft.trim();
    if (!text) return;
    setDraft("");
    await processIncoming(text);
  };

  useEffect(() => {
    void bootMiniApp(MINIAPP_ID, "Hermes 安装机器人").then(() => {
      void fbApp.invoke("bot.setInputPlaceholder", {
        placeholder: "回复数字配置 Hermes；安装后直接和 Hermes 对话",
      }).catch(() => null);
      void fbApp.invoke("bot.setCommands", {
        commands: [
          { command: "/install", description: "重新开始 Hermes 安装向导", order: 1 },
          { command: "/status", description: "查看 Hermes 安装状态", order: 2 },
          { command: "/stop", description: "停止 Hermes 对话进程", order: 3 },
          { command: "/reset", description: "清空并重置向导", order: 4 },
        ],
      }).catch(() => null);
    });
    return () => stopPolling();
  }, [stopPolling]);

  useEffect(() => {
    if (typeof window === "undefined") return undefined;
    let unsubscribeCommand: (() => void) | undefined;
    const attachCommandListener = () => {
      const hostBot = (window as any).FabushiMiniApp?.bot;
      if (!hostBot || unsubscribeCommand) return;
      if (typeof hostBot.onAnyCommand === "function") {
        unsubscribeCommand = hostBot.onAnyCommand((detail: any) => {
          const command = String(detail?.command || "").trim();
          const incoming = String(
            detail?.args || detail?.rawText || detail?.text || "",
          ).trim();
          void processIncoming(incoming || command || "/status");
        });
      }
    };
    attachCommandListener();
    window.addEventListener("fabushi-miniapp-ready", attachCommandListener);
    return () => {
      window.removeEventListener("fabushi-miniapp-ready", attachCommandListener);
      unsubscribeCommand?.();
    };
  }, [processIncoming]);

  return (
    <div
      className="ma-panel hermes-panel ma-fade-in"
      style={
        {
          "--accent-start": "#2F9E83",
          "--accent-end": "#28666E",
          "--accent-rgb": "47, 158, 131",
        } as React.CSSProperties
      }
    >
      <div className="ma-title-row">
        <div>
          <h1 className="ma-header-title">Hermes 安装机器人</h1>
          <p className="ma-header-subtitle">
            宿主只做本机终端代理；配置、安装、Hermes 对话都在聊天框里完成。
          </p>
        </div>
        <Bot size={24} className="ma-title-icon" />
      </div>

      <div className="hermes-status-grid">
        <div>
          <span>状态</span>
          <strong>{phase}</strong>
        </div>
        <div>
          <span>安装会话</span>
          <strong>{installSessionId ? "已连接" : "未连接"}</strong>
        </div>
        <div>
          <span>日志序号</span>
          <strong>{lastSeq}</strong>
        </div>
      </div>

      <div className="ma-pill-selector">
        <button className="ma-pill" type="button" onClick={() => void processIncoming("1")}>
          <PlugZap size={15} /> Portal 快速安装
        </button>
        <button className="ma-pill" type="button" onClick={() => void processIncoming("2")}>
          <Settings2 size={15} /> 自定义 API
        </button>
        <button className="ma-pill" type="button" onClick={() => void processIncoming("3")}>
          <CheckCircle2 size={15} /> 已安装
        </button>
        <button className="ma-pill" type="button" onClick={() => void processIncoming("/stop")}>
          <CircleStop size={15} /> 停止
        </button>
      </div>

      <div className="hermes-chat-log" role="log" aria-live="polite">
        {messages.map((message) => (
          <div className={`hermes-message ${message.role}`} key={message.id}>
            <span>
              {message.role === "user"
                ? "你"
                : message.role === "terminal"
                  ? "终端"
                  : message.role === "hermes"
                    ? "Hermes"
                    : "机器人"}
            </span>
            <p>{message.text}</p>
          </div>
        ))}
        {busy && (
          <div className="hermes-message assistant">
            <span>机器人</span>
            <p>处理中...</p>
          </div>
        )}
      </div>

      <form className="hermes-composer" onSubmit={(event) => void handleSubmit(event)}>
        <TerminalSquare size={18} />
        <input
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          placeholder={phase === "ready" ? "对 Hermes 说点什么" : "回复数字或输入配置"}
          disabled={busy}
        />
        <button type="submit" disabled={busy || !draft.trim()} aria-label="发送">
          <Send size={17} />
        </button>
      </form>
    </div>
  );
}
