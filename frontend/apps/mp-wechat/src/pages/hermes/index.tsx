import { useEffect, useRef, useState } from "react";
import { Button, Input, ScrollView, Text, View } from "@tarojs/components";
import Taro from "@tarojs/taro";
import "./index.scss";

const LOCAL_HOST = "http://127.0.0.1:17393";

type Phase = "setup" | "installing" | "ready" | "chatting" | "failed";
type PendingQuestion = "mode" | "apiBase" | "model" | "apiKey" | "installDir" | "review" | null;
type Role = "assistant" | "user" | "terminal" | "hermes";

type ChatMessage = {
  id: string;
  role: Role;
  text: string;
};

type HermesConfig = {
  setupMode: "portal" | "manual" | "existing";
  installDir: string;
  apiBase: string;
  model: string;
  apiKey: string;
};

type HostLog = {
  id?: string;
  seq?: number;
  role?: Role;
  text?: string;
};

const initialConfig: HermesConfig = {
  setupMode: "portal",
  installDir: "",
  apiBase: "",
  model: "",
  apiKey: "",
};

const welcome =
  "我是 Hermes 安装机器人。回复数字即可完成配置：\n1. 一键安装 + Nous Portal 登录\n2. 一键安装 + OpenAI 兼容配置\n3. 已安装 Hermes，直接聊天";

function createMessage(role: Role, text: string): ChatMessage {
  return {
    id: `${role}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    role,
    text,
  };
}

function normalize(value: string) {
  return value.trim().replace(/\s+/g, " ").toLowerCase();
}

function isSkip(value: string) {
  return ["", "skip", "跳过", "默认", "无", "none"].includes(normalize(value));
}

function isYes(value: string) {
  return ["1", "继续", "确认", "yes", "y", "ok", "start"].includes(normalize(value));
}

function maskSecret(value: string) {
  const text = value.trim();
  if (!text) return "未填写";
  if (text.length <= 8) return "已填写";
  return `${text.slice(0, 4)}...${text.slice(-4)}`;
}

function reviewText(config: HermesConfig) {
  return [
    "请确认 Hermes 安装配置：",
    `安装方式：${config.setupMode === "portal" ? "Nous Portal" : "自定义 API"}`,
    `安装目录：${config.installDir || "默认 ~/.hermes"}`,
    `模型：${config.model || "由 Hermes 向导选择"}`,
    `API Base：${config.apiBase || "由 Hermes 向导选择"}`,
    `API Key：${maskSecret(config.apiKey)}`,
    "回复 1 开始；回复 2 重新配置；回复 3 跳过安装直接聊天。",
  ].join("\n");
}

async function requestHost<T>(path: string, method: "GET" | "POST", data?: unknown): Promise<T> {
  const response = await Taro.request<T & { message?: string }>({
    url: `${LOCAL_HOST}${path}`,
    method,
    data,
    header: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    timeout: 120000,
  });
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw new Error(response.data?.message || `Hermes Host HTTP ${response.statusCode}`);
  }
  return response.data as T;
}

export default function HermesPage() {
  const [phase, setPhase] = useState<Phase>("setup");
  const [pending, setPending] = useState<PendingQuestion>("mode");
  const [config, setConfig] = useState<HermesConfig>(initialConfig);
  const [messages, setMessages] = useState<ChatMessage[]>([createMessage("assistant", welcome)]);
  const [draft, setDraft] = useState("");
  const [loading, setLoading] = useState(false);
  const [sessionId, setSessionId] = useState("");
  const [lastSeq, setLastSeq] = useState(0);
  const lastSeqRef = useRef(0);

  function addMessage(role: Role, text: string) {
    setMessages((current) => [...current.slice(-160), createMessage(role, text)]);
  }

  function appendLogs(logs: HostLog[] = []) {
    if (!logs.length) return;
    let nextSeq = lastSeqRef.current;
    logs.forEach((item) => {
      if (typeof item.seq === "number") nextSeq = Math.max(nextSeq, item.seq);
      if (item.text) addMessage(item.role || "terminal", item.text);
    });
    lastSeqRef.current = nextSeq;
    setLastSeq(nextSeq);
  }

  function resetWizard() {
    setPhase("setup");
    setPending("mode");
    setConfig(initialConfig);
    setSessionId("");
    lastSeqRef.current = 0;
    setLastSeq(0);
    setMessages([createMessage("assistant", welcome)]);
  }

  async function pollInstallStatus(id: string) {
    const data = await requestHost<{
      status: string;
      logs?: HostLog[];
      lastSeq?: number;
    }>(
      `/api/hermes/install/status?id=${encodeURIComponent(id)}&after=${lastSeqRef.current}`,
      "GET",
    );
    appendLogs(data.logs || []);
    if (data.status === "installed") {
      setPhase("ready");
      setPending(null);
      addMessage("assistant", "Hermes 已安装完成。现在直接输入消息，就是和 Hermes 对话。");
    } else if (data.status === "failed") {
      setPhase("failed");
      addMessage("assistant", "Hermes 安装失败。回复 2 重新配置，或修复后回复 1 重试。");
    }
  }

  useEffect(() => {
    if (phase !== "installing" || !sessionId) return undefined;
    const timer = setInterval(() => {
      void pollInstallStatus(sessionId).catch((error) => {
        addMessage("assistant", error instanceof Error ? error.message : "读取安装状态失败");
      });
    }, 1400);
    return () => clearInterval(timer);
  }, [phase, sessionId]);

  async function startInstall(nextConfig: HermesConfig) {
    setLoading(true);
    setPhase("installing");
    setPending(null);
    addMessage("assistant", "开始连接本机 Hermes Host。请先在电脑运行：node scripts/hermes-chat-host.mjs");
    try {
      const data = await requestHost<{
        sessionId?: string;
        logs?: HostLog[];
      }>("/api/hermes/install/start", "POST", { config: nextConfig });
      const id = String(data.sessionId || "");
      if (!id) throw new Error("Hermes Host 没有返回安装会话");
      setSessionId(id);
      appendLogs(data.logs || []);
    } catch (error) {
      setPhase("failed");
      addMessage(
        "assistant",
        `${error instanceof Error ? error.message : "连接 Hermes Host 失败"}\n请确认本机 Host 正在运行，且小程序开发环境允许访问 127.0.0.1。`,
      );
    } finally {
      setLoading(false);
    }
  }

  async function sendInstallReply(text: string) {
    if (!sessionId) {
      addMessage("assistant", "还没有安装会话。回复 /install 重新开始。");
      return;
    }
    const data = await requestHost<{ logs?: HostLog[] }>("/api/hermes/install/reply", "POST", {
      sessionId,
      message: text,
      after: lastSeqRef.current,
    });
    appendLogs(data.logs || []);
  }

  async function sendHermesChat(text: string) {
    setLoading(true);
    setPhase("chatting");
    try {
      const data = await requestHost<{ reply?: string; logs?: HostLog[] }>("/api/hermes/chat", "POST", {
        message: text,
        config,
      });
      if (data.logs?.length) {
        data.logs.forEach((item) => {
          if (item.role !== "user" && item.text) addMessage(item.role || "hermes", item.text);
        });
      } else {
        addMessage("hermes", data.reply || "Hermes 暂未返回内容。");
      }
      setPhase("ready");
    } catch (error) {
      setPhase("ready");
      addMessage("assistant", error instanceof Error ? error.message : "Hermes 对话失败");
    } finally {
      setLoading(false);
    }
  }

  async function handleIncoming(raw: string) {
    const text = raw.trim();
    if (!text || loading) return;
    addMessage("user", text);
    const lower = normalize(text);

    if (lower === "/install" || lower === "/reset") {
      resetWizard();
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
      if (lower === "1" || lower === "portal") {
        const next = { ...config, setupMode: "portal" as const };
        setConfig(next);
        setPending("installDir");
        addMessage("assistant", "选择 Nous Portal 快速安装。请输入安装目录，或回复“默认”。");
        return;
      }
      if (lower === "2" || lower === "api" || lower === "manual") {
        const next = { ...config, setupMode: "manual" as const };
        setConfig(next);
        setPending("apiBase");
        addMessage("assistant", "请输入 OpenAI 兼容 API Base URL，或回复“跳过”。");
        return;
      }
      if (lower === "3" || lower === "existing") {
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
      const next = { ...config, apiBase: isSkip(text) ? "" : text };
      setConfig(next);
      setPending("model");
      addMessage("assistant", "请输入模型名，或回复“跳过”。");
      return;
    }

    if (pending === "model") {
      const next = { ...config, model: isSkip(text) ? "" : text };
      setConfig(next);
      setPending("apiKey");
      addMessage("assistant", "请输入 API Key，或回复“跳过”。");
      return;
    }

    if (pending === "apiKey") {
      const next = { ...config, apiKey: isSkip(text) ? "" : text };
      setConfig(next);
      setPending("installDir");
      addMessage("assistant", "请输入安装目录，或回复“默认”。");
      return;
    }

    if (pending === "installDir") {
      const next = { ...config, installDir: isSkip(text) ? "" : text };
      setConfig(next);
      setPending("review");
      addMessage("assistant", reviewText(next));
      return;
    }

    if (pending === "review") {
      if (isYes(text)) {
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
  }

  function submitDraft() {
    const text = draft.trim();
    if (!text) return;
    setDraft("");
    void handleIncoming(text);
  }

  return (
    <View className="hermes-page">
      <View className="hermes-topbar">
        <Text className="hermes-title">Hermes 安装机器人</Text>
        <Text className="hermes-subtitle">终端交互转成聊天，安装后继续对话 Hermes。</Text>
      </View>

      <View className="hermes-status">
        <View>
          <Text>状态</Text>
          <Text>{phase}</Text>
        </View>
        <View>
          <Text>Host</Text>
          <Text>{sessionId ? "已连接" : "待连接"}</Text>
        </View>
        <View>
          <Text>日志</Text>
          <Text>{lastSeq}</Text>
        </View>
      </View>

      <View className="hermes-actions">
        <Button onClick={() => void handleIncoming("1")}>Portal 安装</Button>
        <Button onClick={() => void handleIncoming("2")}>API 配置</Button>
        <Button onClick={() => void handleIncoming("3")}>已安装</Button>
      </View>

      <ScrollView className="hermes-chat" scrollY scrollIntoView="bottom-anchor">
        {messages.map((message) => (
          <View className={`hermes-bubble ${message.role}`} key={message.id}>
            <Text className="hermes-role">
              {message.role === "user"
                ? "你"
                : message.role === "terminal"
                  ? "终端"
                  : message.role === "hermes"
                    ? "Hermes"
                    : "机器人"}
            </Text>
            <Text className="hermes-text">{message.text}</Text>
          </View>
        ))}
        {loading && (
          <View className="hermes-bubble assistant">
            <Text className="hermes-role">机器人</Text>
            <Text className="hermes-text">处理中...</Text>
          </View>
        )}
        <View id="bottom-anchor" />
      </ScrollView>

      <View className="hermes-composer">
        <Input
          className="hermes-input"
          value={draft}
          placeholder={phase === "ready" ? "对 Hermes 说点什么" : "回复数字或输入配置"}
          confirmType="send"
          onInput={(event) => setDraft(event.detail.value)}
          onConfirm={submitDraft}
        />
        <Button className="hermes-send" loading={loading} onClick={submitDraft}>
          ↑
        </Button>
      </View>
    </View>
  );
}
