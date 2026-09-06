"use client";

import { useEffect, useMemo } from "react";
import { exposeMcpToolsAsWebMcp, type McpTool, type McpToolResult } from "@fabushi/mcp-app-sdk";

class MiniAppWebMcpClient {
  private nextId = 1;
  private sessionId = "";

  constructor(private readonly endpoint: string) {}

  async request(method: string, params: Record<string, unknown> = {}): Promise<any> {
    const response = await fetch(this.endpoint, {
      method: "POST",
      credentials: "include",
      headers: {
        "content-type": "application/json",
        accept: "application/json, text/event-stream",
        ...(this.sessionId ? { "mcp-session-id": this.sessionId, "mcp-protocol-version": "2025-06-18" } : {}),
      },
      body: JSON.stringify({ jsonrpc: "2.0", id: this.nextId++, method, params }),
    });
    const sessionId = response.headers.get("mcp-session-id");
    if (sessionId) this.sessionId = sessionId;
    if (!response.ok) throw new Error(`MCP ${method} failed (${response.status})`);
    const payload = await response.json();
    if (payload.error) throw new Error(payload.error.message || `MCP ${method} failed`);
    return payload.result;
  }

  async notify(method: string): Promise<void> {
    const response = await fetch(this.endpoint, {
      method: "POST",
      credentials: "include",
      headers: {
        "content-type": "application/json",
        accept: "application/json, text/event-stream",
        ...(this.sessionId ? { "mcp-session-id": this.sessionId, "mcp-protocol-version": "2025-06-18" } : {}),
      },
      body: JSON.stringify({ jsonrpc: "2.0", method }),
    });
    if (!response.ok) throw new Error(`MCP ${method} failed (${response.status})`);
  }

  async close(): Promise<void> {
    if (!this.sessionId) return;
    await fetch(this.endpoint, {
      method: "DELETE",
      credentials: "include",
      headers: { "mcp-session-id": this.sessionId, "mcp-protocol-version": "2025-06-18" },
    }).catch(() => undefined);
    this.sessionId = "";
  }
}

export default function WebMcpMiniAppAdapter({ pluginId }: { pluginId: string }) {
  const normalizedId = pluginId.replace(/^official\./, "");
  const backendBase = (process.env.NEXT_PUBLIC_AI_BACKEND_URL || "https://api.ombhrum.com").replace(/\/$/, "");
  const endpoint = `${backendBase}/api/mcp/apps/${encodeURIComponent(normalizedId)}`;
  const client = useMemo(() => new MiniAppWebMcpClient(endpoint), [endpoint]);

  useEffect(() => {
    let active = true;
    let dispose = () => undefined;

    void (async () => {
      try {
        await client.request("initialize", {
          protocolVersion: "2025-06-18",
          capabilities: {},
          clientInfo: { name: "fabushi-webmcp-adapter", version: "1.0.0" },
        });
        await client.notify("notifications/initialized");
        const listed = await client.request("tools/list");
        if (!active) return;
        const tools = Array.isArray(listed?.tools) ? listed.tools as McpTool[] : [];
        dispose = exposeMcpToolsAsWebMcp(tools, async (name, args) => {
          const tool = tools.find((candidate) => candidate.name === name);
          if (!tool) throw new Error(`Unknown MiniApp tool: ${name}`);
          if (tool.annotations?.readOnlyHint !== true) {
            const risk = tool.annotations?.destructiveHint === true
              ? "该操作可能产生破坏性修改。"
              : tool.annotations?.openWorldHint === true
                ? "该操作会影响小程序外部系统。"
                : "该操作会修改小程序或后台状态。";
            if (!window.confirm(`允许 WebMCP 调用 ${name}？\n\n${risk}`)) {
              throw new Error("用户取消了 WebMCP Tool 调用");
            }
          }
          const callArgs = tool.annotations?.readOnlyHint === true
            ? args
            : { ...args, operationId: typeof (args as Record<string, unknown>).operationId === "string" ? (args as Record<string, unknown>).operationId : crypto.randomUUID() };
          return await client.request("tools/call", { name, arguments: callArgs }) as McpToolResult;
        });
        window.dispatchEvent(new CustomEvent("fabushi:webmcp-ready", {
          detail: { pluginId: normalizedId, tools: tools.map((tool) => tool.name) },
        }));
      } catch (error) {
        window.dispatchEvent(new CustomEvent("fabushi:webmcp-error", {
          detail: { pluginId: normalizedId, error: error instanceof Error ? error.message : String(error) },
        }));
      }
    })();

    return () => {
      active = false;
      dispose();
      void client.close();
    };
  }, [client, normalizedId]);

  return null;
}
