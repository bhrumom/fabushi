"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  parseToolCommand,
  schemaDefaults,
  validateSchemaValue,
  type JsonRpcRequest,
  type JsonSchema,
  type McpTool,
  type McpToolResult,
} from "@fabushi/mcp-app-sdk";

const TITLES: Record<string, string> = {
  "global-dharma": "全球法布施",
  "faliu-flashcards": "法流记忆卡",
  "platform-publish": "平台发布",
  "hermes-installer": "Hermes 安装器",
  "bot-father": "Bot Father",
  "mahayana-assistant": "大乘助手",
};

// Official installs use the same canonical repository + manifest-name SHA-256
// identity as CLI and Flutter. Keeping these stable also migrates old session
// aliases without making reinstalling a plugin replay its welcome content.
const OFFICIAL_INSTANCE_IDS: Record<string, string> = {
  "global-dharma": "global-dharma@184d7e8c5a737b9e1f62590f834fda9d",
  "faliu-flashcards": "faliu-flashcards@6fb6a56e06ff63a02dc7842ace74b8fc",
  "platform-publish": "platform-publish@752ce2a905fb13b859972dde16fdf9e2",
  "hermes-installer": "hermes-installer@25dcb916e9c4ce5e508c5df2644c8e47",
  "bot-father": "bot-father@d738f95aa3b19cd3a73332bc9b910bda",
  "mahayana-assistant": "mahayana-assistant@a9d77fcedbb35078e1b7c882f8c18224",
};

type QuickAction =
  | { type: "message"; value: string }
  | { type: "tool"; name: string; arguments?: Record<string, unknown> }
  | { type: "resource"; uri: string }
  | { type: "url"; url: string };
type QuickReply = { id: string; label: string; aliases?: string[]; action: QuickAction };
type FeedItem = {
  id: string;
  revision: string;
  kind: "announcement" | "article";
  title: string;
  publishedAt: string;
  summary?: string;
  coverImage?: string;
  resourceUri: string;
};
type HomeDocument = {
  schema: "mahayana.miniapp.home.v1";
  revision: string;
  app: { id: string; title: string; version: string; source?: string };
  welcome?: { id: string; markdown: string };
  tips?: Array<{ id: string; markdown: string }>;
  quickReplies?: QuickReply[];
  feed?: { items: FeedItem[]; nextCursor?: string | null };
};
type TimelineItem = {
  id: string;
  role: "user" | "miniapp" | "tool" | "error";
  text: string;
  feedItem?: FeedItem;
};
type ContentState = {
  welcomeShown: boolean;
  welcomeShownAt: string | null;
  receipts: Array<{ itemId: string; revision: string; readAt: string }>;
};

class McpHttpClient {
  private nextId = 1;
  private sessionId = "";

  constructor(private readonly endpoint: string) {}

  async request(method: string, params: Record<string, unknown> = {}): Promise<any> {
    const response = await fetch(this.endpoint, {
      method: "POST",
      credentials: "include",
      headers: this.headers(),
      body: JSON.stringify({ jsonrpc: "2.0", id: this.nextId++, method, params }),
    });
    this.captureSession(response);
    if (!response.ok) throw new Error(`MCP ${method} 失败（${response.status}）`);
    const payload = await response.json();
    if (payload.error) throw new Error(payload.error.message || `MCP ${method} 失败`);
    return payload.result;
  }

  async notify(method: string, params: Record<string, unknown> = {}): Promise<void> {
    const response = await fetch(this.endpoint, {
      method: "POST",
      credentials: "include",
      headers: this.headers(),
      body: JSON.stringify({ jsonrpc: "2.0", method, params }),
    });
    this.captureSession(response);
    if (!response.ok) throw new Error(`MCP ${method} 通知失败（${response.status}）`);
  }

  async respond(id: number | string, result: unknown): Promise<void> {
    const response = await fetch(this.endpoint, {
      method: "POST",
      credentials: "include",
      headers: this.headers(),
      body: JSON.stringify({ jsonrpc: "2.0", id, result }),
    });
    if (!response.ok) throw new Error(`MCP 客户端响应失败（${response.status}）`);
  }

  async listen(onMessage: (message: any) => void, signal: AbortSignal): Promise<void> {
    let lastEventId = "";
    while (!signal.aborted && this.sessionId) {
      try {
        const headers = this.headers();
        if (lastEventId) headers["last-event-id"] = lastEventId;
        const response = await fetch(this.endpoint, { method: "GET", credentials: "include", headers, signal });
        if (!response.ok || !response.body) throw new Error(`MCP 事件流失败（${response.status}）`);
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = "";
        while (!signal.aborted) {
          const { done, value } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true }).replace(/\r\n/g, "\n");
          let boundary = buffer.indexOf("\n\n");
          while (boundary >= 0) {
            const frame = buffer.slice(0, boundary);
            buffer = buffer.slice(boundary + 2);
            const idLine = frame.split("\n").find((line) => line.startsWith("id:"));
            if (idLine) lastEventId = idLine.slice(3).trim();
            const data = frame.split("\n").filter((line) => line.startsWith("data:")).map((line) => line.slice(5).trimStart()).join("\n");
            if (data) onMessage(JSON.parse(data));
            boundary = buffer.indexOf("\n\n");
          }
        }
      } catch (error) {
        if (signal.aborted) return;
        await new Promise((resolve) => window.setTimeout(resolve, 500));
      }
    }
  }

  async terminate(): Promise<void> {
    if (!this.sessionId) return;
    const response = await fetch(this.endpoint, { method: "DELETE", credentials: "include", headers: this.headers() });
    if (response.ok) this.sessionId = "";
  }

  private headers(): Record<string, string> {
    return {
      "content-type": "application/json",
      accept: "application/json, text/event-stream",
      ...(this.sessionId ? { "mcp-session-id": this.sessionId, "mcp-protocol-version": "2025-06-18" } : {}),
    };
  }

  private captureSession(response: Response): void {
    const sessionId = response.headers.get("mcp-session-id");
    if (sessionId) this.sessionId = sessionId;
  }
}

export default function McpPluginApp({ pluginId }: { pluginId: string }) {
  const normalizedId = pluginId.replace(/^official\./, "");
  const title = TITLES[normalizedId] ?? normalizedId;
  const backendBase = (process.env.NEXT_PUBLIC_AI_BACKEND_URL || "https://api.ombhrum.com").replace(/\/$/, "");
  const endpoint = `${backendBase}/api/mcp/apps/${encodeURIComponent(normalizedId)}`;
  const agentEndpoint = `${backendBase}/api/codex/apps/${encodeURIComponent(normalizedId)}/turns`;
  const pluginInstanceId = OFFICIAL_INSTANCE_IDS[normalizedId] ?? `fabushi-official:${normalizedId}`;
  const contentStateEndpoint = `${backendBase}/api/miniapps/${encodeURIComponent(pluginInstanceId)}/content-state`;
  const messagesEndpoint = `${backendBase}/api/miniapps/${encodeURIComponent(pluginInstanceId)}/messages`;
  const client = useMemo(() => new McpHttpClient(endpoint), [endpoint]);
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const [tools, setTools] = useState<McpTool[]>([]);
  const [uiHtml, setUiHtml] = useState("");
  const [command, setCommand] = useState("");
  const [output, setOutput] = useState("正在初始化 MCP…");
  const [busy, setBusy] = useState(true);
  const [formTool, setFormTool] = useState<McpTool | null>(null);
  const [formValue, setFormValue] = useState<Record<string, unknown>>({});
  const [elicitation, setElicitation] = useState<{ id: number | string; message: string; schema: JsonSchema; value: Record<string, unknown> } | null>(null);
  const [conversationId, setConversationId] = useState("");
  const [home, setHome] = useState<HomeDocument | null>(null);
  const [timeline, setTimeline] = useState<TimelineItem[]>([]);
  const [article, setArticle] = useState<{ item: FeedItem; markdown: string } | null>(null);

  const appendTimeline = useCallback((item: Omit<TimelineItem, "id">) => {
    const message = { ...item, id: crypto.randomUUID() };
    setTimeline((current) => {
      const next = [...current, message];
      localStorage.setItem(`mahayana.miniapp.messages.${pluginInstanceId}`, JSON.stringify(next.slice(-500)));
      return next;
    });
    void fetch(messagesEndpoint, {
      method: "POST", credentials: "include", headers: { "content-type": "application/json" },
      body: JSON.stringify({ message: {
        messageId: message.id, role: message.role, text: message.text,
        payload: message.feedItem ? { feedItem: message.feedItem } : {},
        createdAt: new Date().toISOString(),
      } }),
    }).catch(() => undefined);
  }, [messagesEndpoint, pluginInstanceId]);

  const readResource = useCallback(async (uri: string) => {
    const resource = await client.request("resources/read", { uri });
    const selected = resource?.contents?.find((item: any) => item.uri === uri);
    if (!selected?.text) throw new Error(`资源 ${uri} 没有可显示正文`);
    return String(selected.text);
  }, [client]);

  useEffect(() => {
    let active = true;
    const key = `mahayana.miniapp.messages.${pluginInstanceId}`;
    try {
      const local = JSON.parse(localStorage.getItem(key) || "[]") as TimelineItem[];
      if (Array.isArray(local)) setTimeline(local.slice(-500));
    } catch { /* ignore corrupt offline timeline */ }
    void fetch(`${messagesEndpoint}?limit=500`, { credentials: "include" })
      .then(async (response) => response.ok ? response.json() : null)
      .then((payload) => {
        if (!active || !Array.isArray(payload?.data?.messages)) return;
        const remote = payload.data.messages.map((message: any): TimelineItem => ({
          id: String(message.messageId),
          role: message.role as TimelineItem["role"],
          text: String(message.text ?? ""),
          feedItem: message.payload?.feedItem,
        }));
        setTimeline((current) => mergeTimeline(current, remote));
      })
      .catch(() => undefined);
    return () => { active = false; };
  }, [messagesEndpoint, pluginInstanceId]);

  const callTool = useCallback(async (name: string, args: Record<string, unknown> = {}, skipApproval = false) => {
    const tool = tools.find((candidate) => candidate.name === name);
    if (!skipApproval && tool && tool.annotations?.readOnlyHint !== true) {
      const risk = tool.annotations?.destructiveHint === true
        ? "该操作可能产生破坏性修改。"
        : tool.annotations?.openWorldHint === true
          ? "该操作会影响插件外部系统。"
          : "该操作会写入数据。";
      if (!window.confirm(`允许 /${name}？\n\n${risk}`)) {
        throw new Error("用户取消了 MCP Tool 调用");
      }
    }
    setBusy(true);
    setOutput(`正在调用 /${name}…`);
    try {
      const result = await client.request("tools/call", { name, arguments: args }) as McpToolResult;
      setOutput(JSON.stringify(result.structuredContent ?? result.content ?? result, null, 2));
      iframeRef.current?.contentWindow?.postMessage({
        jsonrpc: "2.0",
        method: "ui/notifications/tool-result",
        params: { name, arguments: args, result },
      }, "*");
      return result;
    } catch (error) {
      const message = error instanceof Error ? error.message : `/${name} 调用失败`;
      setOutput(message);
      appendTimeline({ role: "error", text: `${message}\n\n发送 @codex 可交给已配对桌面修复；MCP 错误不会自动重试。` });
      throw error;
    } finally {
      setBusy(false);
    }
  }, [appendTimeline, client, tools]);

  const refreshTools = useCallback(async () => {
    const listed = await client.request("tools/list");
    setTools(Array.isArray(listed?.tools) ? listed.tools : []);
    return Array.isArray(listed?.tools) ? listed.tools as McpTool[] : [];
  }, [client]);

  useEffect(() => {
    let active = true;
    const eventStream = new AbortController();
    (async () => {
      try {
        await client.request("initialize", {
          protocolVersion: "2025-06-18",
          capabilities: { roots: { listChanged: false }, elicitation: {} },
          clientInfo: { name: "fabushi-web-mcp-host", version: "1.0.0" },
        });
        await client.notify("notifications/initialized");
        const availableTools = await refreshTools();
        void client.listen((message) => {
          if (!active || !message || message.jsonrpc !== "2.0") return;
          if (message.method === "notifications/tools/list_changed") {
            void refreshTools();
          } else if (message.method === "notifications/progress") {
            const params = message.params ?? {};
            setOutput(`${params.message ?? "处理中"}${params.total === undefined ? "" : ` ${params.progress ?? 0}/${params.total}`}`);
          } else if (message.method === "elicitation/create" && message.id !== undefined) {
            const params = message.params ?? {};
            if (params.mode === "url") {
              setOutput(`插件请求在浏览器完成操作：${String(params.url ?? "")}`);
              void client.respond(message.id, { action: "cancel" });
            } else {
              const schema = (params.requestedSchema ?? { type: "object" }) as JsonSchema;
              setElicitation({
                id: message.id,
                message: String(params.message ?? "插件需要补充信息"),
                schema,
                value: (schemaDefaults(schema) ?? {}) as Record<string, unknown>,
              });
            }
          }
        }, eventStream.signal);
        const hasHome = availableTools.some((tool) => tool.name === "home");
        if (hasHome) {
          const homeResult = await client.request("tools/call", {
            name: "home",
            arguments: { surface: "web", locale: navigator.language, limit: 10 },
          }) as McpToolResult;
          const structured = homeResult?.structuredContent as HomeDocument | undefined;
          if (structured?.schema === "mahayana.miniapp.home.v1") {
            if (new TextEncoder().encode(JSON.stringify(structured)).byteLength > 32 * 1024) throw new Error("home 首屏超过 32 KiB");
            if ((structured.feed?.items.length ?? 0) > 10) throw new Error("home 首屏文章摘要超过 10 条");
            setHome(structured);
            const key = `mahayana.miniapp.content-state.${pluginInstanceId}`;
            const empty: ContentState = { welcomeShown: false, welcomeShownAt: null, receipts: [] };
            let localState = empty;
            try { localState = { ...empty, ...JSON.parse(localStorage.getItem(key) || "{}") }; } catch { /* ignore corrupt local state */ }
            let state = localState;
            try {
              const response = await fetch(contentStateEndpoint, { credentials: "include" });
              const payload = await response.json();
              if (response.ok && payload?.data?.state) state = mergeContentState(localState, payload.data.state as ContentState);
            } catch { /* offline state remains authoritative until merge */ }
            const firstWelcome = !state.welcomeShown;
            const nextReceipts = [...state.receipts];
            const automatic: TimelineItem[] = [];
            if (firstWelcome && structured.welcome) {
              automatic.push({
                id: `welcome:${structured.welcome.id}`,
                role: "miniapp",
                text: [structured.welcome.markdown, ...(structured.tips ?? []).map((tip) => `Tip: ${tip.markdown}`)].join("\n\n"),
              });
            }
            for (const item of (structured.feed?.items ?? []).filter((item) => item.kind === "announcement")) {
              if (automatic.filter((entry) => entry.feedItem?.kind === "announcement").length >= 3) break;
              if (nextReceipts.some((receipt) => receipt.itemId === item.id && receipt.revision === item.revision)) continue;
              automatic.push({ id: `announcement:${item.id}:${item.revision}`, role: "miniapp", text: `${item.title}\n${item.summary ?? ""}`, feedItem: item });
              nextReceipts.push({ itemId: item.id, revision: item.revision, readAt: new Date().toISOString() });
            }
            if (firstWelcome) {
              for (const item of (structured.feed?.items ?? []).filter((item) => item.kind === "article")) {
                automatic.push({ id: `article:${item.id}:${item.revision}`, role: "miniapp", text: item.summary ?? item.title, feedItem: item });
              }
            }
            if (active) setTimeline((current) => {
              const next = mergeTimeline(current, automatic);
              localStorage.setItem(`mahayana.miniapp.messages.${pluginInstanceId}`, JSON.stringify(next.slice(-500)));
              return next;
            });
            if (automatic.length > 0) {
              void fetch(messagesEndpoint, {
                method: "POST", credentials: "include", headers: { "content-type": "application/json" },
                body: JSON.stringify({ messages: automatic.map((message) => ({
                  messageId: message.id, role: message.role, text: message.text,
                  payload: message.feedItem ? { feedItem: message.feedItem } : {},
                  createdAt: new Date().toISOString(),
                })) }),
              }).catch(() => undefined);
            }
            state = {
              welcomeShown: state.welcomeShown || Boolean(structured.welcome),
              welcomeShownAt: state.welcomeShownAt || (structured.welcome ? new Date().toISOString() : null),
              receipts: nextReceipts,
            };
            localStorage.setItem(key, JSON.stringify(state));
            void fetch(contentStateEndpoint, {
              method: "PUT",
              credentials: "include",
              headers: { "content-type": "application/json" },
              body: JSON.stringify({ state }),
            }).catch(() => undefined);
          }
          const uri = String(homeResult?._meta?.["ui/resourceUri"] ?? "");
          if (uri) {
            const resource = await client.request("resources/read", { uri });
            const selected = resource?.contents?.find((item: any) => item.uri === uri);
            if (selected?.mimeType === "text/html;profile=mcp-app" && selected.text) setUiHtml(String(selected.text));
          }
        }
        if (active) setOutput(`${title} 已就绪，共 ${availableTools.length} 个 Tools。${hasHome ? "" : " 此插件没有 home，保持普通机器人体验。"}`);
      } catch (error) {
        if (active) setOutput(error instanceof Error ? error.message : "MCP 初始化失败");
      } finally {
        if (active) setBusy(false);
      }
    })();
    return () => {
      active = false;
      eventStream.abort();
      void client.terminate();
    };
  }, [client, contentStateEndpoint, messagesEndpoint, pluginInstanceId, refreshTools, title]);

  useEffect(() => {
    const receive = async (event: MessageEvent) => {
      if (event.source !== iframeRef.current?.contentWindow) return;
      const request = event.data as JsonRpcRequest;
      if (!request || request.jsonrpc !== "2.0" || request.method !== "tools/call") return;
      try {
        const params = request.params ?? {};
        const result = await callTool(String(params.name ?? ""), (params.arguments ?? {}) as Record<string, unknown>);
        iframeRef.current?.contentWindow?.postMessage({ jsonrpc: "2.0", id: request.id, result }, "*");
      } catch (error) {
        iframeRef.current?.contentWindow?.postMessage({ jsonrpc: "2.0", id: request.id, error: { code: -32000, message: error instanceof Error ? error.message : "Tool 调用失败" } }, "*");
      }
    };
    window.addEventListener("message", receive);
    return () => window.removeEventListener("message", receive);
  }, [callTool]);

  async function sendCodexFallback(text: string) {
    setBusy(true);
    setOutput(`正在通过 ${title} 的隔离 Codex 会话处理…`);
    try {
      const sendTurn = (activeConversationId: string) => fetch(agentEndpoint, {
        method: "POST",
        credentials: "include",
        headers: { "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({ message: text, ...(activeConversationId ? { conversationId: activeConversationId } : {}) }),
      });
      let response = await sendTurn(conversationId);
      if (response.status === 404 && conversationId) {
        setConversationId("");
        response = await sendTurn("");
      }
      const payload = await response.json().catch(() => ({}));
      if (!response.ok || payload.success !== true) throw new Error(payload.message || `插件 Codex 会话失败（${response.status}）`);
      setConversationId(String(payload.conversationId || ""));
      const message = String(payload.message || "");
      setOutput(message);
      appendTimeline({ role: "miniapp", text: message });
    } finally {
      setBusy(false);
    }
  }

  async function submitText(text: string) {
    appendTimeline({ role: "user", text });
    if (text === "@codex" || text.startsWith("@codex ")) {
      const repairEndpoint = `${backendBase}/api/miniapps/${encodeURIComponent(pluginInstanceId)}/repair`;
      const body = { pluginId: normalizedId, source: home?.app.source, request: text.slice(6).trim() };
      let response = await fetch(repairEndpoint, {
        method: "POST", credentials: "include", headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
      });
      let payload = await response.json().catch(() => ({}));
      if (response.ok && payload?.data?.requiresConfirmation) {
        const confirmed = window.confirm(payload.data.message);
        if (!confirmed) {
          appendTimeline({ role: "miniapp", text: "已取消修复交接。" });
          return;
        }
        response = await fetch(repairEndpoint, {
          method: "POST", credentials: "include", headers: { "content-type": "application/json" },
          body: JSON.stringify({ ...body, confirmed: true }),
        });
        payload = await response.json().catch(() => ({}));
      }
      const message = payload?.data?.message || payload?.error?.message || `修复交接失败（${response.status}）`;
      appendTimeline({ role: response.ok ? "miniapp" : "error", text: message });
      return;
    }
    const articleMatch = /^A(\d+)$/i.exec(text);
    if (articleMatch) {
      const articles = (home?.feed?.items ?? []).filter((item) => item.kind === "article");
      const item = articles[Number(articleMatch[1]) - 1];
      if (!item) throw new Error(`没有文章 ${text.toUpperCase()}`);
      const markdown = await readResource(item.resourceUri);
      setArticle({ item, markdown });
      appendTimeline({ role: "miniapp", text: `${item.title}\n\n${markdown}`, feedItem: item });
      await markContentRead(contentStateEndpoint, pluginInstanceId, item);
      return;
    }
    let routedText = text;
    let actionId: string | undefined;
    const quick = home?.quickReplies?.find((reply) => reply.id === text || reply.label === text || reply.aliases?.includes(text));
    if (quick) {
      actionId = quick.id;
      if (quick.action.type === "message") routedText = quick.action.value;
      else if (quick.action.type === "tool") {
        const result = await callTool(quick.action.name, quick.action.arguments ?? {});
        appendTimeline({ role: result.isError ? "error" : "tool", text: mcpText(result) });
        return;
      } else if (quick.action.type === "resource") {
        appendTimeline({ role: "miniapp", text: await readResource(quick.action.uri) });
        return;
      } else {
        if (window.confirm(`允许打开外部链接？\n\n${quick.action.url}`)) window.open(quick.action.url, "_blank", "noopener,noreferrer");
        return;
      }
    }
    if (tools.some((tool) => tool.name === "chat")) {
      const result = await callTool("chat", { message: routedText, surface: "web", locale: navigator.language, actionId: actionId ?? null }, true);
      if (result.isError) {
        appendTimeline({ role: "error", text: `${mcpText(result)}\n\n不会自动降级，发送 @codex 可修复。` });
        return;
      }
      const disposition = result.structuredContent as { handled?: boolean; hostRequest?: unknown } | undefined;
      if (typeof disposition?.handled !== "boolean") {
        appendTimeline({ role: "error", text: "chat 返回缺少 structuredContent.handled；不会自动降级。" });
        return;
      }
      if (disposition.handled) {
        appendTimeline({ role: "miniapp", text: mcpText(result) });
        if (disposition.hostRequest) appendTimeline({ role: "tool", text: `待宿主审批的操作：\n${JSON.stringify(disposition.hostRequest, null, 2)}` });
        return;
      }
    }
    await sendCodexFallback(routedText);
  }

  async function submitCommand() {
    try {
      const parsed = parseToolCommand(command.trim(), tools);
      if (parsed.kind === "text") {
        await submitText(parsed.text);
        setCommand("");
      } else if (parsed.kind === "form") {
        setFormTool(parsed.tool);
        setFormValue(parsed.initial);
      } else {
        const result = await callTool(parsed.tool.name, parsed.arguments);
        appendTimeline({ role: result.isError ? "error" : "tool", text: mcpText(result) });
        setCommand("");
      }
    } catch (error) {
      setOutput(error instanceof Error ? error.message : "命令解析失败");
    }
  }

  async function resetOnboarding() {
    const key = `mahayana.miniapp.content-state.${pluginInstanceId}`;
    localStorage.setItem(key, JSON.stringify({ welcomeShown: false, welcomeShownAt: null, receipts: [] }));
    await fetch(contentStateEndpoint, {
      method: "PUT",
      credentials: "include",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ resetOnboarding: true }),
    }).catch(() => undefined);
    window.location.reload();
  }

  function chooseTool(tool: McpTool) {
    const properties = Object.keys(tool.inputSchema?.properties ?? {});
    if (properties.length === 0) void callTool(tool.name);
    else if (properties.length === 1 && tool.inputSchema?.properties?.[properties[0]]?.type === "string") setCommand(`/${tool.name} `);
    else {
      setFormTool(tool);
      setFormValue((schemaDefaults(tool.inputSchema) ?? {}) as Record<string, unknown>);
    }
  }

  return <main className="ma-container">
    <section className="ma-card">
      <h1 className="ma-header-title">{title}</h1>
      <p className="ma-header-subtitle">MCP 插件 · {home?.app.source ? safeSourceHost(home.app.source) : new URL(endpoint).host} · 命令来自当前 Server 的 tools/list</p>
      <div className="mcp-tools">{tools.map((tool) => <button key={tool.name} className="mcp-chip" disabled={busy} onClick={() => chooseTool(tool)}>/{tool.name}</button>)}</div>
      {(home?.quickReplies?.length ?? 0) > 0 && <div className="mcp-quick-replies">{home!.quickReplies!.map((reply) => <button key={reply.id} className="mcp-quick-reply" disabled={busy} onClick={() => void submitText(reply.aliases?.[0] ?? reply.label)}>{reply.label}</button>)}</div>}
    </section>
    <section className="ma-card mcp-command-row">
      <input className="ma-input mcp-command-input" value={command} placeholder="输入 /tool，或输入普通文本" onChange={(event) => setCommand(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") void submitCommand(); }} />
      <button className="ma-btn mcp-send" disabled={busy || !command.trim()} onClick={() => void submitCommand()}>发送</button>
    </section>
    {formTool && <section className="ma-card">
      <h2>/{formTool.name}</h2>
      <SchemaField schema={formTool.inputSchema ?? { type: "object" }} value={formValue} required onChange={(value) => setFormValue(value as Record<string, unknown>)} />
      <div className="mcp-form-actions"><button className="ma-btn ma-btn-secondary" onClick={() => setFormTool(null)}>取消</button><button className="ma-btn" onClick={() => {
        const errors = validateSchemaValue(formTool.inputSchema, formValue);
        if (errors.length > 0) {
          setOutput(errors.join("\n"));
          return;
        }
        const selected = formTool;
        setFormTool(null);
        void callTool(selected.name, formValue);
      }}>调用</button></div>
    </section>}
    {elicitation && <section className="ma-card">
      <h2>插件请求补充信息</h2>
      <p>{elicitation.message}</p>
      <SchemaField schema={elicitation.schema} value={elicitation.value} required onChange={(value) => setElicitation({ ...elicitation, value: value as Record<string, unknown> })} />
      <div className="mcp-form-actions">
        <button className="ma-btn ma-btn-secondary" onClick={() => {
          const selected = elicitation;
          setElicitation(null);
          void client.respond(selected.id, { action: "cancel" });
        }}>取消</button>
        <button className="ma-btn" onClick={() => {
          const errors = validateSchemaValue(elicitation.schema, elicitation.value);
          if (errors.length > 0) {
            setOutput(errors.join("\n"));
            return;
          }
          const selected = elicitation;
          setElicitation(null);
          void client.respond(selected.id, { action: "accept", content: selected.value });
        }}>提交</button>
      </div>
    </section>}
    <section className="ma-card mcp-timeline" aria-live="polite">
      {timeline.length === 0 ? <p className="ma-header-subtitle">此小程序没有设置欢迎内容，可以直接开始对话。</p> : timeline.map((item) => <article key={item.id} className={`mcp-message mcp-message-${item.role}`}>
        <span className="mcp-message-role">{item.role === "user" ? "你" : item.role === "error" ? "MCP 错误" : item.role === "tool" ? "操作" : title}</span>
        {item.feedItem?.coverImage && <img className="mcp-article-cover" src={item.feedItem.coverImage} alt="" />}
        {item.feedItem && <strong>{item.feedItem.title}</strong>}
        <p>{item.text}</p>
        {item.feedItem?.kind === "article" && <button className="mcp-link-button" onClick={() => void submitText(`A${(home?.feed?.items ?? []).filter((entry) => entry.kind === "article").findIndex((entry) => entry.id === item.feedItem?.id) + 1}`)}>阅读原文</button>}
      </article>)}
    </section>
    {article && <section className="ma-card mcp-article-view"><button className="mcp-link-button" onClick={() => setArticle(null)}>返回对话</button><h2>{article.item.title}</h2><p>{article.markdown}</p></section>}
    <details className="ma-card"><summary>MCP 运行状态</summary><pre className="ma-log-box">{output}</pre><button className="mcp-link-button" onClick={() => void resetOnboarding()}>重置新手引导</button></details>
    {uiHtml ? <iframe ref={iframeRef} className="mcp-ui-frame" sandbox="allow-scripts" srcDoc={uiHtml} title={`${title} MCP UI`} /> : <section className="ma-card">MCP UI 加载失败时仍可使用上方命令。</section>}
  </main>;
}

function mcpText(result: McpToolResult): string {
  const text = result.content
    ?.filter((item: any) => item?.type === "text" && typeof item.text === "string")
    .map((item: any) => item.text)
    .join("\n");
  return text || JSON.stringify(result.structuredContent ?? result, null, 2);
}

function mergeContentState(left: ContentState, right: ContentState): ContentState {
  const receipts = new Map<string, ContentState["receipts"][number]>();
  for (const receipt of [...(left.receipts ?? []), ...(right.receipts ?? [])]) {
    const key = `${receipt.itemId}\u0000${receipt.revision}`;
    const previous = receipts.get(key);
    if (!previous || receipt.readAt > previous.readAt) receipts.set(key, receipt);
  }
  return {
    welcomeShown: Boolean(left.welcomeShown || right.welcomeShown),
    welcomeShownAt: [left.welcomeShownAt, right.welcomeShownAt].filter(Boolean).sort()[0] ?? null,
    receipts: [...receipts.values()],
  };
}

function mergeTimeline(left: TimelineItem[], right: TimelineItem[]): TimelineItem[] {
  const messages = new Map<string, TimelineItem>();
  for (const message of [...left, ...right]) messages.set(message.id, message);
  return [...messages.values()].slice(-500);
}

async function markContentRead(endpoint: string, pluginInstanceId: string, item: FeedItem): Promise<void> {
  const key = `mahayana.miniapp.content-state.${pluginInstanceId}`;
  let current: ContentState = { welcomeShown: true, welcomeShownAt: null, receipts: [] };
  try { current = { ...current, ...JSON.parse(localStorage.getItem(key) || "{}") }; } catch { /* ignore */ }
  const receipt = { itemId: item.id, revision: item.revision, readAt: new Date().toISOString() };
  current = mergeContentState(current, { welcomeShown: false, welcomeShownAt: null, receipts: [receipt] });
  localStorage.setItem(key, JSON.stringify(current));
  await fetch(endpoint, {
    method: "PUT", credentials: "include", headers: { "content-type": "application/json" },
    body: JSON.stringify({ state: { receipts: [receipt] } }),
  }).catch(() => undefined);
}

function safeSourceHost(source: string): string {
  try { return new URL(source).host; } catch { return source; }
}

function SchemaField({ schema, value, required, onChange, label }: { schema: JsonSchema; value: unknown; required: boolean; onChange: (value: unknown) => void; label?: string }) {
  const caption = label ?? schema.title;
  if (schema.type === "object" || schema.properties) {
    const object = (value && typeof value === "object" && !Array.isArray(value) ? value : {}) as Record<string, unknown>;
    return <fieldset className="mcp-fieldset">{caption && <legend>{caption}</legend>}{Object.entries(schema.properties ?? {}).map(([key, child]) => <SchemaField key={key} label={child.title ?? key} schema={child} value={object[key] ?? child.default} required={schema.required?.includes(key) ?? false} onChange={(next) => onChange({ ...object, [key]: next })} />)}</fieldset>;
  }
  if (schema.type === "boolean") return <label className="mcp-field mcp-checkbox"><input type="checkbox" checked={Boolean(value)} onChange={(event) => onChange(event.target.checked)} /> {caption}{required ? " *" : ""}<small>{schema.description}</small></label>;
  if (schema.enum) return <label className="mcp-field">{caption}{required ? " *" : ""}<select className="ma-input" value={String(value ?? schema.default ?? "")} onChange={(event) => onChange(event.target.value)}>{!required && <option value="" />} {schema.enum.map((option) => <option key={String(option)} value={String(option)}>{String(option)}</option>)}</select><small>{schema.description}</small></label>;
  if (schema.type === "array") return <label className="mcp-field">{caption}{required ? " *" : ""}<textarea className="ma-textarea" value={JSON.stringify(value ?? schema.default ?? [], null, 2)} onChange={(event) => { try { onChange(JSON.parse(event.target.value)); } catch { /* wait for valid JSON */ } }} /><small>{schema.description}</small></label>;
  const inputType = schema.type === "number" || schema.type === "integer" ? "number" : "text";
  return <label className="mcp-field">{caption}{required ? " *" : ""}<input className="ma-input" type={inputType} value={String(value ?? schema.default ?? "")} onChange={(event) => onChange(inputType === "number" ? Number(event.target.value) : event.target.value)} /><small>{schema.description}</small></label>;
}
