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

const MCP_PROTOCOL_VERSION = "2026-07-28";
const MCP_APPS_SPECIFICATION = "2026-01-26";
const MCP_APP_MIME = "text/html;profile=mcp-app";

const TITLES: Record<string, string> = {
  "global-dharma": "全球法布施",
  "faliu-flashcards": "法流记忆卡",
  "platform-publish": "平台发布",
  "hermes-installer": "Hermes 安装器",
  "bot-father": "Bot Father",
  "mahayana-assistant": "大乘助手",
  "chatgpt-auto-confirm": "ChatGPT 自动确认",
  "computer-cleaner": "Computer Cleaner",
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
  "chatgpt-auto-confirm": "chatgpt-auto-confirm@7f5362512a619801e88b30e76e383f03",
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

class StatelessMcpHttpClient {
  private nextId = 1;

  constructor(private readonly endpoint: string) {}

  async request(method: string, params: Record<string, unknown> = {}): Promise<any> {
    const existingMeta = (params._meta && typeof params._meta === "object")
      ? params._meta as Record<string, unknown>
      : {};
    const requestParams = {
      ...params,
      _meta: {
        ...existingMeta,
        "io.modelcontextprotocol/protocolVersion": MCP_PROTOCOL_VERSION,
        "io.modelcontextprotocol/clientInfo": { name: "fabushi-web-mcp-host", version: "2.0.0" },
        "io.modelcontextprotocol/clientCapabilities": {
          extensions: {
            "io.modelcontextprotocol/ui": { mimeTypes: [MCP_APP_MIME] },
          },
        },
      },
    };
    const response = await fetch(this.endpoint, {
      method: "POST",
      credentials: "include",
      headers: {
        "content-type": "application/json",
        accept: "application/json, text/event-stream",
        "mcp-protocol-version": MCP_PROTOCOL_VERSION,
      },
      body: JSON.stringify({ jsonrpc: "2.0", id: this.nextId++, method, params: requestParams }),
    });
    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      const code = payload?.error?.code ?? payload?.error ?? `http_${response.status}`;
      const message = payload?.error?.message ?? payload?.message ?? `MCP ${method} failed`;
      throw new Error(`${code}: ${message}`);
    }
    if (payload?.error) throw new Error(payload.error.message || `MCP ${method} failed`);
    return payload?.result;
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
  const client = useMemo(() => new StatelessMcpHttpClient(endpoint), [endpoint]);
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const appInitializedRef = useRef(false);
  const viewRequestIdRef = useRef(1);
  const [tools, setTools] = useState<McpTool[]>([]);
  const [uiHtml, setUiHtml] = useState("");
  const [uiMeta, setUiMeta] = useState<Record<string, unknown>>({});
  const [command, setCommand] = useState("");
  const [output, setOutput] = useState("正在初始化 MCP…");
  const [busy, setBusy] = useState(true);
  const [formTool, setFormTool] = useState<McpTool | null>(null);
  const [formValue, setFormValue] = useState<Record<string, unknown>>({});
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
    (async () => {
      try {
        const availableTools = await refreshTools();
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
            if (selected?.mimeType === MCP_APP_MIME && selected.text) {
              setUiMeta((selected._meta?.ui ?? {}) as Record<string, unknown>);
              setUiHtml(String(selected.text));
            }
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
      appInitializedRef.current = false;
      const view = iframeRef.current?.contentWindow;
      if (view) {
        view.postMessage({
          jsonrpc: "2.0",
          id: viewRequestIdRef.current++,
          method: "ui/resource-teardown",
          params: { reason: "host_unmounted" },
        }, "*");
      }
    };
  }, [client, contentStateEndpoint, messagesEndpoint, pluginInstanceId, refreshTools, title]);

  useEffect(() => {
    const view = iframeRef.current?.contentWindow;
    if (!view) return;

    const postToView = (message: Record<string, unknown>) => {
      view.postMessage(message, "*");
    };
    const respond = (id: number | string | undefined, result?: unknown, error?: { code: number; message: string }) => {
      if (id === undefined) return;
      postToView({ jsonrpc: "2.0", id, ...(error ? { error } : { result: result ?? {} }) });
    };
    const receive = async (event: MessageEvent) => {
      if (event.source !== view || event.origin !== "null") return;
      const request = event.data as JsonRpcRequest & { id?: number | string };
      if (!request || request.jsonrpc !== "2.0" || typeof request.method !== "string") return;

      if (request.method === "ui/notifications/sandbox-proxy-ready") {
        postToView({
          jsonrpc: "2.0",
          method: "ui/notifications/sandbox-resource-ready",
          params: { html: applyMcpAppCsp(uiHtml, uiMeta) },
        });
        return;
      }
      if (request.method === "ui/notifications/initialized") {
        appInitializedRef.current = true;
        return;
      }
      if (request.method === "ui/notifications/size-changed") {
        const height = Number(request.params?.height ?? 0);
        if (Number.isFinite(height) && height > 0 && iframeRef.current) {
          iframeRef.current.style.height = `${Math.min(Math.max(height, 160), 1200)}px`;
        }
        return;
      }
      if (request.method === "notifications/message") {
        console.info("MCP App View", request.params ?? {});
        return;
      }

      try {
        if (request.method === "ui/initialize") {
          appInitializedRef.current = false;
          respond(request.id, {
            protocolVersion: MCP_APPS_SPECIFICATION,
            hostInfo: { name: "fabushi-web-mcp-apps-host", version: "2.0.0" },
            hostCapabilities: {
              openLinks: {},
              serverTools: { listChanged: false },
              serverResources: { listChanged: false },
              logging: {},
              sandbox: { permissions: {} },
            },
            hostContext: {
              theme: window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light",
              locale: navigator.language,
              timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
              platform: "web",
              displayMode: "inline",
              availableDisplayModes: ["inline", "fullscreen"],
              containerDimensions: { maxWidth: iframeRef.current?.clientWidth || 960, maxHeight: 1200 },
            },
          });
          return;
        }
        if (!appInitializedRef.current) {
          throw Object.assign(new Error("MCP App View must initialize before requesting host capabilities"), { code: -32002 });
        }
        if (request.method === "tools/call") {
          const params = request.params ?? {};
          const name = String(params.name ?? "");
          const tool = tools.find((candidate) => candidate.name === name);
          if (!tool || !isAppVisibleTool(tool)) {
            throw Object.assign(new Error(`Tool ${name || "<missing>"} is not app-visible`), { code: -32601 });
          }
          const args = (params.arguments ?? {}) as Record<string, unknown>;
          postToView({ jsonrpc: "2.0", method: "ui/notifications/tool-input", params: { arguments: args } });
          const result = await callTool(name, args);
          respond(request.id, result);
          return;
        }
        if (request.method === "resources/read") {
          respond(request.id, await client.request("resources/read", request.params ?? {}));
          return;
        }
        if (request.method === "ping") {
          respond(request.id, {});
          return;
        }
        if (request.method === "ui/open-link") {
          const url = new URL(String(request.params?.url ?? ""));
          if (!['http:', 'https:'].includes(url.protocol)) throw new Error("Only HTTP(S) links are allowed");
          if (!window.confirm(`Open external link?\n\n${url.origin}`)) throw new Error("User denied external link");
          window.open(url.toString(), "_blank", "noopener,noreferrer");
          respond(request.id, {});
          return;
        }
        if (request.method === "ui/request-display-mode") {
          const requested = String(request.params?.mode ?? "inline");
          respond(request.id, { mode: requested === "fullscreen" ? "fullscreen" : "inline" });
          return;
        }
        throw Object.assign(new Error(`Unsupported MCP Apps method: ${request.method}`), { code: -32601 });
      } catch (error) {
        const code = typeof (error as { code?: unknown })?.code === "number" ? Number((error as { code: number }).code) : -32000;
        respond(request.id, undefined, { code, message: error instanceof Error ? error.message : "MCP Apps request failed" });
      }
    };
    window.addEventListener("message", receive);
    return () => window.removeEventListener("message", receive);
  }, [callTool, client, tools, uiHtml, uiMeta]);


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
    {uiHtml ? <iframe ref={iframeRef} className="mcp-ui-frame" sandbox="allow-scripts" src={sandboxProxyDataUrl()} title={`${title} MCP App`} /> : <section className="ma-card">MCP App UI unavailable; use the Tool command surface above.</section>}
  </main>;
}

function isAppVisibleTool(tool: McpTool): boolean {
  const visibility = tool._meta?.["ui/visibility"];
  return visibility === undefined || (Array.isArray(visibility) && visibility.includes("app"));
}

function applyMcpAppCsp(html: string, meta: Record<string, unknown>): string {
  const uiCsp = (meta.csp ?? {}) as Record<string, unknown>;
  const origins = (key: string) => Array.isArray(uiCsp[key])
    ? (uiCsp[key] as unknown[]).map(String).filter((value) => /^https:\/\//.test(value))
    : [];
  const connect = origins("connectDomains");
  const resources = origins("resourceDomains");
  const frames = origins("frameDomains");
  const bases = origins("baseUriDomains");
  const csp = [
    "default-src 'none'",
    `script-src 'self' 'unsafe-inline' ${resources.join(" ")}`.trim(),
    `style-src 'self' 'unsafe-inline' ${resources.join(" ")}`.trim(),
    `img-src 'self' data: ${resources.join(" ")}`.trim(),
    `font-src 'self' data: ${resources.join(" ")}`.trim(),
    `media-src 'self' data: ${resources.join(" ")}`.trim(),
    connect.length ? `connect-src ${connect.join(" ")}` : "connect-src 'none'",
    frames.length ? `frame-src ${frames.join(" ")}` : "frame-src 'none'",
    bases.length ? `base-uri ${bases.join(" ")}` : "base-uri 'self'",
    "object-src 'none'",
    "form-action 'none'",
  ].join("; ");
  const stripped = html.replace(/<meta[^>]+http-equiv=["']Content-Security-Policy["'][^>]*>/gi, "");
  const tag = `<meta http-equiv="Content-Security-Policy" content="${csp.replace(/&/g, "&amp;").replace(/"/g, "&quot;")}">`;
  return /<head(?:\s[^>]*)?>/i.test(stripped)
    ? stripped.replace(/<head(?:\s[^>]*)?>/i, (head) => `${head}${tag}`)
    : `<!doctype html><html><head>${tag}</head><body>${stripped}</body></html>`;
}

let cachedSandboxProxyUrl = "";
function sandboxProxyDataUrl(): string {
  if (cachedSandboxProxyUrl) return cachedSandboxProxyUrl;
  const proxy = `<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; frame-src 'self' data:; style-src 'unsafe-inline'; object-src 'none'; base-uri 'none'"></head><body style="margin:0"><script>(()=>{let view=null;const send=m=>parent.postMessage(m,'*');addEventListener('message',event=>{if(event.source===parent){const m=event.data;if(m?.method==='ui/notifications/sandbox-resource-ready'){view=document.createElement('iframe');view.setAttribute('sandbox','allow-scripts');view.style.cssText='border:0;width:100%;min-height:160px';view.srcdoc=String(m.params?.html||'');document.body.replaceChildren(view);return}if(view?.contentWindow)view.contentWindow.postMessage(m,'*');return}if(view&&event.source===view.contentWindow&&event.origin==='null')send(event.data)});send({jsonrpc:'2.0',method:'ui/notifications/sandbox-proxy-ready',params:{}})})()<\/script></body></html>`;
  cachedSandboxProxyUrl = `data:text/html;charset=utf-8,${encodeURIComponent(proxy)}`;
  return cachedSandboxProxyUrl;
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
