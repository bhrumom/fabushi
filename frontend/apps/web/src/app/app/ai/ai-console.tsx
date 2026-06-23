"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import {
  type DachengAiConversationSummary,
  type DachengAiStreamEvent,
  type DachengAiUsage,
  type DharmaResourceSearchItem,
  type DharmaResourceSearchResponse,
  dachengAiEndpoints,
  getDachengAiApiBaseUrl,
  parseDachengSseChunk,
} from "@fabushi/api-client";
import {
  Bot,
  CircleUserRound,
  Download,
  History,
  Home,
  Loader2,
  MessageSquarePlus,
  RefreshCw,
  Search,
  Send,
  Sparkles,
  User,
} from "lucide-react";
import { siteHref } from "../../../lib/site-url";
import { GlobalNetworkGlobe } from "../../../components/global-network-globe";
import styles from "./ai-console.module.css";

interface ChatMessage {
  id: string;
  role: "assistant" | "user";
  content: string;
  error?: boolean;
}

interface ResourceWithPreview extends DharmaResourceSearchItem {
  preview?: string;
  downloading?: boolean;
}

function createId() {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 9)}`;
}

function formatDate(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "最近更新";
  return date.toLocaleDateString("zh-CN", { month: "2-digit", day: "2-digit" });
}

function payloadText(event: DachengAiStreamEvent) {
  return String(event.raw.message ?? event.raw.text ?? event.text ?? "");
}

export function AiConsole({ quickPrompts }: { quickPrompts: readonly string[] }) {
  const [baseUrl] = useState(() => getDachengAiApiBaseUrl());
  const [input, setInput] = useState("");
  const [contextText, setContextText] = useState("");
  const [conversationId, setConversationId] = useState<string | undefined>();
  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      id: "welcome",
      role: "assistant",
      content:
        "我是大乘 AI。你可以让我查找可分享佛法资源、整理经文摘要、生成发愿文，或把一段内容改成适合法布施的版本。",
    },
  ]);
  const [steps, setSteps] = useState<string[]>([]);
  const [usage, setUsage] = useState<DachengAiUsage | null>(null);
  const [isStreaming, setIsStreaming] = useState(false);
  const [history, setHistory] = useState<DachengAiConversationSummary[]>([]);
  const [historyStatus, setHistoryStatus] = useState("未加载");
  const [resourceQuery, setResourceQuery] = useState("心经 可公开分享 音频 经文");
  const [resources, setResources] = useState<ResourceWithPreview[]>([]);
  const [resourceStatus, setResourceStatus] = useState("输入关键词后搜索资源");
  const [abortController, setAbortController] = useState<AbortController | null>(null);
  const [dharmaShareProgress, setDharmaShareProgress] = useState<{
    isActive: boolean;
    title: string;
    logs: string[];
    completed: boolean;
  } | null>(null);
  const messagesRef = useRef<HTMLDivElement | null>(null);

  const canSubmit = input.trim().length > 0 && !isStreaming;
  const remainingLabel = useMemo(() => {
    if (!usage) return "额度待计算";
    return `剩余额度 ${usage.remainingTokens.toLocaleString("zh-CN")} token`;
  }, [usage]);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const prompt = params.get("prompt")?.trim();
    const book = params.get("book")?.trim();
    const context = params.get("context")?.trim();
    if (prompt) setInput(prompt);
    if (context || book) {
      setContextText([book ? `当前经文：${book}` : "", context ?? ""].filter(Boolean).join("\n"));
    }
  }, []);

  useEffect(() => {
    messagesRef.current?.scrollTo({
      top: messagesRef.current.scrollHeight,
      behavior: "smooth",
    });
  }, [messages, steps, isStreaming]);

  async function loadHistory() {
    setHistoryStatus("加载中");
    try {
      const response = await fetch(`${baseUrl}${dachengAiEndpoints.conversations}`, {
        headers: { Accept: "application/json" },
        cache: "no-store",
      });
      const payload = (await response.json()) as {
        success?: boolean;
        items?: DachengAiConversationSummary[];
        message?: string;
      };
      if (!response.ok || payload.success === false) {
        throw new Error(payload.message || `请求失败 ${response.status}`);
      }
      setHistory(payload.items ?? []);
      setHistoryStatus((payload.items ?? []).length ? "最近 30 条" : "暂无会话");
    } catch (error) {
      setHistoryStatus(error instanceof Error ? error.message : "加载失败");
    }
  }

  useEffect(() => {
    void loadHistory();
  }, []);

  async function openConversation(id: string) {
    setHistoryStatus("读取会话");
    try {
      const response = await fetch(`${baseUrl}${dachengAiEndpoints.conversation(id)}`, {
        headers: { Accept: "application/json" },
        cache: "no-store",
      });
      const payload = (await response.json()) as {
        success?: boolean;
        messages?: Array<{ role: "assistant" | "user"; content: string }>;
        message?: string;
      };
      if (!response.ok || payload.success === false) {
        throw new Error(payload.message || `请求失败 ${response.status}`);
      }
      setConversationId(id);
      setMessages(
        (payload.messages ?? [])
          .filter((item) => item.role === "assistant" || item.role === "user")
          .map((item) => ({ id: createId(), role: item.role, content: item.content })),
      );
      setSteps([]);
      setHistoryStatus("已打开");
    } catch (error) {
      setHistoryStatus(error instanceof Error ? error.message : "读取失败");
    }
  }

  function newConversation() {
    abortController?.abort();
    setAbortController(null);
    setConversationId(undefined);
    setMessages([
      {
        id: "welcome-new",
        role: "assistant",
        content: "新的对话已经准备好。可以直接输入问题，也可以先填右侧资源关键词。",
      },
    ]);
    setSteps([]);
    setUsage(null);
    setIsStreaming(false);
  }

  async function runGlobalDharmaShare(title: string, text: string) {
    setDharmaShareProgress({
      isActive: true,
      title,
      logs: ["正在初始化全球节点传输...", "正在读取正文：" + title],
      completed: false,
    });

    const regions = [
      "✓ 亚洲（东亚/东南亚/南亚地区节点） · 已连接",
      "✓ 北美（美国/加拿大主干网节点） · 已连接",
      "✓ 欧洲（西欧/中欧传输中继） · 已连接",
      "✓ 大洋洲（澳洲/新西兰覆盖节点） · 已连接",
      "✓ 南美与非洲（全球边缘互联节点） · 已连接",
    ];

    for (const region of regions) {
      await new Promise((resolve) => setTimeout(resolve, 800));
      setDharmaShareProgress((prev) => {
        if (!prev) return prev;
        return {
          ...prev,
          logs: [...prev.logs, region],
        };
      });
    }

    await new Promise((resolve) => setTimeout(resolve, 600));
    setDharmaShareProgress((prev) => {
      if (!prev) return prev;
      return {
        ...prev,
        logs: [
          ...prev.logs,
          "🎉 全球法布施功德圆满：已成功将该佛典资源分发至全球所有节点！",
        ],
        completed: true,
      };
    });
  }

  async function submitChat(customPrompt?: string) {
    const rawText = (customPrompt ?? input).trim();
    if (!rawText || isStreaming) return;
    setDharmaShareProgress(null);
    const finalPrompt = contextText.trim() ? `${contextText.trim()}\n\n问题：${rawText}` : rawText;
    const userMessage: ChatMessage = { id: createId(), role: "user", content: rawText };
    const assistantId = createId();
    setMessages((items) => [
      ...items,
      userMessage,
      { id: assistantId, role: "assistant", content: "" },
    ]);
    setInput("");
    setSteps([]);
    setIsStreaming(true);

    const controller = new AbortController();
    setAbortController(controller);
    let streamedText = "";
    let nextConversationId = conversationId;

    try {
      const response = await fetch(`${baseUrl}${dachengAiEndpoints.chatStream}`, {
        method: "POST",
        headers: {
          Accept: "text/event-stream",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: finalPrompt,
          conversationId,
          clientMembershipHint: false,
        }),
        signal: controller.signal,
      });

      if (!response.ok || !response.body) {
        const text = await response.text();
        throw new Error(text || `请求失败 ${response.status}`);
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const chunks = buffer.split(/\n\n+/);
        buffer = chunks.pop() ?? "";

        for (const chunk of chunks) {
          for (const event of parseDachengSseChunk(chunk)) {
            if (event.conversationId) {
              nextConversationId = event.conversationId;
              setConversationId(event.conversationId);
            }

            if (event.type === "step") {
              const line = [event.title, payloadText(event)].filter(Boolean).join("：");
              if (line.trim()) setSteps((items) => [...items, line]);
            } else if (event.type === "delta") {
              streamedText += event.text;
              setMessages((items) =>
                items.map((item) =>
                  item.id === assistantId ? { ...item, content: streamedText } : item,
                ),
              );
            } else if (event.type === "done") {
              const finalText = payloadText(event) || streamedText;
              streamedText = finalText;
              setUsage(event.usage ?? null);
              setMessages((items) =>
                items.map((item) =>
                  item.id === assistantId ? { ...item, content: finalText } : item,
                ),
              );
              if (event.raw && event.raw.clientAction) {
                const action = event.raw.clientAction as { type: string; title: string; text: string };
                if (action.type === "prepare_dharma_share_text") {
                  void runGlobalDharmaShare(action.title, action.text);
                }
              }
            } else if (event.type === "error") {
              throw new Error(payloadText(event) || "大乘 AI 生成失败");
            }
          }
        }
      }

      if (buffer.trim()) {
        for (const event of parseDachengSseChunk(buffer)) {
          if (event.type === "done") {
            const finalText = payloadText(event) || streamedText;
            setUsage(event.usage ?? null);
            setMessages((items) =>
              items.map((item) =>
                item.id === assistantId ? { ...item, content: finalText } : item,
              ),
            );
            if (event.raw && event.raw.clientAction) {
              const action = event.raw.clientAction as { type: string; title: string; text: string };
              if (action.type === "prepare_dharma_share_text") {
                void runGlobalDharmaShare(action.title, action.text);
              }
            }
          }
        }
      }

      setConversationId(nextConversationId);
      void loadHistory();
    } catch (error) {
      if (controller.signal.aborted) {
        setMessages((items) =>
          items.map((item) =>
            item.id === assistantId
              ? { ...item, content: item.content || "已停止生成。" }
              : item,
          ),
        );
      } else {
        const message = error instanceof Error ? error.message : "大乘 AI 生成失败";
        setMessages((items) =>
          items.map((item) =>
            item.id === assistantId ? { ...item, content: message, error: true } : item,
          ),
        );
      }
    } finally {
      setAbortController(null);
      setIsStreaming(false);
    }
  }

  async function searchResources() {
    const query = resourceQuery.trim();
    if (!query) return;
    setResourceStatus("搜索中");
    setResources([]);
    try {
      const response = await fetch(`${baseUrl}${dachengAiEndpoints.resourceSearch}`, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ query, limit: 8 }),
        cache: "no-store",
      });
      const payload = (await response.json()) as DharmaResourceSearchResponse & { message?: string };
      if (!response.ok || payload.success === false) {
        throw new Error(payload.message || `请求失败 ${response.status}`);
      }
      setResources(payload.items ?? []);
      setResourceStatus(payload.items?.length ? `找到 ${payload.items.length} 个候选资源` : "没有找到候选资源");
    } catch (error) {
      setResourceStatus(error instanceof Error ? error.message : "搜索失败");
    }
  }

  async function downloadResource(resource: ResourceWithPreview) {
    setResources((items) =>
      items.map((item) =>
        item.id === resource.id ? { ...item, downloading: true } : item,
      ),
    );
    try {
      const response = await fetch(`${baseUrl}${dachengAiEndpoints.resourceDownload}`, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify(resource),
        cache: "no-store",
      });
      const payload = (await response.json()) as {
        success?: boolean;
        title?: string;
        contentText?: string;
        message?: string;
      };
      if (!response.ok || payload.success === false) {
        throw new Error(payload.message || `请求失败 ${response.status}`);
      }
      setResources((items) =>
        items.map((item) =>
          item.id === resource.id
            ? {
                ...item,
                downloading: false,
                preview: payload.contentText?.slice(0, 1200) || "资源已下载。",
              }
            : item,
        ),
      );
      setContextText(
        [
          `资源：${payload.title || resource.title}`,
          payload.contentText?.slice(0, 1800) || resource.snippet,
        ]
          .filter(Boolean)
          .join("\n"),
      );
    } catch (error) {
      setResources((items) =>
        items.map((item) =>
          item.id === resource.id
            ? {
                ...item,
                downloading: false,
                preview: error instanceof Error ? error.message : "下载失败",
              }
            : item,
        ),
      );
    }
  }

  return (
    <main className={styles.shell}>
      <div className={styles.layout}>
        <aside className={styles.sidebar}>
          <a className={styles.brandLink} href={siteHref("/app")}>
            <span className={styles.brandMark}>
              <Sparkles size={18} aria-hidden="true" />
            </span>
            <span>大乘 AI</span>
          </a>
          <div className={styles.sidebarActions}>
            <button className={styles.primaryButton} type="button" onClick={newConversation}>
              <MessageSquarePlus size={17} aria-hidden="true" />
              新对话
            </button>
            <a className={styles.secondaryButton} href={siteHref("/app")}>
              <Home size={17} aria-hidden="true" />
              Web 工作台
            </a>
          </div>

          <section className={styles.sidebarSection}>
            <h2>近期会话</h2>
            <span className={styles.smallText}>{historyStatus}</span>
            <div className={styles.historyList}>
              {history.slice(0, 10).map((item) => (
                <button
                  className={styles.historyItem}
                  key={item.id}
                  type="button"
                  onClick={() => openConversation(item.id)}
                >
                  <span className={styles.historyIcon}>
                    <History size={15} aria-hidden="true" />
                  </span>
                  <span>
                    <span className={styles.historyTitle}>{item.title}</span>
                    <span className={styles.historyDate}>{formatDate(item.updatedAt)}</span>
                  </span>
                </button>
              ))}
            </div>
            <button className={styles.secondaryButton} type="button" onClick={loadHistory}>
              <RefreshCw size={16} aria-hidden="true" />
              刷新会话
            </button>
          </section>
        </aside>

        <section className={styles.chatPanel} aria-label="大乘 AI 对话">
          <header className={styles.header}>
            <div className={styles.titleBlock}>
              <span className={styles.iconBadge}>
                <Bot size={22} aria-hidden="true" />
              </span>
              <span>
                <h1>AI 资源与问经控制台</h1>
                <p>{conversationId ? `会话 ${conversationId.slice(0, 8)}` : "新会话"}</p>
              </span>
            </div>
            <span className={styles.statusPill}>
              {isStreaming ? <Loader2 size={15} aria-hidden="true" /> : <Sparkles size={15} aria-hidden="true" />}
              {isStreaming ? "生成中" : remainingLabel}
            </span>
          </header>

          <div className={styles.messages} ref={messagesRef}>
            {messages.map((message) => (
              <article
                className={[
                  styles.message,
                  message.role === "user" ? styles.user : "",
                  message.error ? styles.error : "",
                ].join(" ")}
                key={message.id}
              >
                <span className={styles.avatar}>
                  {message.role === "user" ? <User size={17} /> : <Bot size={17} />}
                </span>
                <div className={styles.bubble}>
                  {message.content || (isStreaming ? "正在整理..." : "")}
                </div>
              </article>
            ))}
            {steps.length > 0 && (
              <div className={styles.stepBox}>
                {steps.slice(-5).map((step) => (
                  <div key={step}>· {step}</div>
                ))}
              </div>
            )}
            {dharmaShareProgress && dharmaShareProgress.isActive && (
              <div className={styles.dharmaShareProgressCard}>
                <div className={styles.dharmaShareHeader}>
                  <div className={styles.dharmaShareSpinner}>
                    <div className={styles.wheel} />
                  </div>
                  <div>
                    <h3>全球法布施分发进度：{dharmaShareProgress.title}</h3>
                    <p>{dharmaShareProgress.completed ? "🎉 全球同步完成（功德无量）" : "🌐 全球边缘节点传输中..."}</p>
                  </div>
                </div>
                <div className={styles.dharmaShareGlobeWrapper}>
                  <GlobalNetworkGlobe />
                </div>
                <div className={styles.dharmaShareLogs}>
                  {dharmaShareProgress.logs.map((log, logIndex) => (
                    <div
                      key={logIndex}
                      className={[
                        styles.dharmaShareLogLine,
                        log.startsWith("🎉") ? styles.successLog : "",
                      ].join(" ")}
                    >
                      {log}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          <div>
            {usage && (
              <div className={styles.usage}>
                <span>总计 {usage.totalTokens.toLocaleString("zh-CN")} token</span>
                <span>输入 {usage.promptTokens.toLocaleString("zh-CN")}</span>
                <span>输出 {usage.completionTokens.toLocaleString("zh-CN")}</span>
              </div>
            )}
            <div className={styles.promptGrid}>
              {quickPrompts.map((prompt) => (
                <button
                  className={styles.chipButton}
                  key={prompt}
                  type="button"
                  onClick={() => setInput(prompt)}
                >
                  {prompt}
                </button>
              ))}
            </div>
            <form
              className={styles.composer}
              onSubmit={(event) => {
                event.preventDefault();
                void submitChat();
              }}
            >
              <textarea
                className={styles.input}
                value={input}
                placeholder="输入你要查找、整理、解释或生成的内容"
                rows={2}
                onChange={(event) => setInput(event.target.value)}
              />
              {isStreaming ? (
                <button
                  className={styles.sendButton}
                  type="button"
                  onClick={() => abortController?.abort()}
                  aria-label="停止生成"
                >
                  <Loader2 size={19} aria-hidden="true" />
                </button>
              ) : (
                <button className={styles.sendButton} type="submit" disabled={!canSubmit} aria-label="发送">
                  <Send size={19} aria-hidden="true" />
                </button>
              )}
            </form>
          </div>
        </section>

        <aside className={styles.resourcePanel}>
          <div className={styles.resourceHeader}>
            <h2>AI 找资源</h2>
            <Search size={19} aria-hidden="true" />
          </div>
          <div className={styles.searchBox}>
            <input
              className={styles.searchInput}
              value={resourceQuery}
              onChange={(event) => setResourceQuery(event.target.value)}
              placeholder="关键词"
            />
            <button className={styles.iconButton} type="button" onClick={searchResources} aria-label="搜索资源">
              <Search size={17} aria-hidden="true" />
            </button>
          </div>
          <textarea
            className={styles.contextInput}
            value={contextText}
            onChange={(event) => setContextText(event.target.value)}
            placeholder="可把经文、书名、资料摘要放在这里，AI 会随问题一起读取。"
          />
          <span className={styles.smallText}>{resourceStatus}</span>
          <div className={styles.resourceList}>
            {resources.map((resource) => (
              <article className={styles.resourceCard} key={resource.id}>
                <h3>{resource.title}</h3>
                <p>
                  {resource.sourceName} · {resource.resourceType}
                </p>
                {resource.snippet && <p>{resource.snippet}</p>}
                <div className={styles.resourceActions}>
                  <button
                    className={styles.secondaryButton}
                    type="button"
                    disabled={resource.downloading}
                    onClick={() => downloadResource(resource)}
                  >
                    <Download size={16} aria-hidden="true" />
                    {resource.downloading ? "下载中" : "下载预览"}
                  </button>
                  <button
                    className={styles.secondaryButton}
                    type="button"
                    onClick={() => {
                      setContextText(`资源：${resource.title}\n${resource.snippet}`);
                      setInput(`请基于右侧资源说明，整理适合法布施分享的摘要。`);
                    }}
                  >
                    <CircleUserRound size={16} aria-hidden="true" />
                    加入上下文
                  </button>
                </div>
                {resource.preview && <div className={styles.previewBox}>{resource.preview}</div>}
              </article>
            ))}
          </div>
        </aside>
      </div>
    </main>
  );
}
