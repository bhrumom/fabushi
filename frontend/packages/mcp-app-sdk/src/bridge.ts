import type { JsonRpcRequest, JsonRpcResponse, McpToolResult } from "./types";

type Listener = (params: unknown) => void;

export class McpAppBridge {
  private nextId = 1;
  private pending = new Map<number | string, (response: JsonRpcResponse) => void>();
  private listeners = new Map<string, Set<Listener>>();

  constructor(private readonly target: Window = window.parent) {
    window.addEventListener("message", this.handleMessage);
  }

  dispose(): void {
    window.removeEventListener("message", this.handleMessage);
    this.pending.clear();
    this.listeners.clear();
  }

  async callTool(name: string, args: Record<string, unknown> = {}): Promise<McpToolResult> {
    return this.request("tools/call", { name, arguments: args }) as Promise<McpToolResult>;
  }

  async sendMessage(content: string): Promise<unknown> {
    return this.request("ui/message", { content });
  }

  async updateModelContext(context: Record<string, unknown>): Promise<unknown> {
    return this.request("ui/update-model-context", context);
  }

  on(method: "ui/notifications/tool-input" | "ui/notifications/tool-result", listener: Listener): () => void {
    const listeners = this.listeners.get(method) ?? new Set<Listener>();
    listeners.add(listener);
    this.listeners.set(method, listeners);
    return () => listeners.delete(listener);
  }

  private request(method: string, params: Record<string, unknown>): Promise<unknown> {
    const id = this.nextId++;
    const request: JsonRpcRequest = { jsonrpc: "2.0", id, method, params };
    return new Promise((resolve, reject) => {
      this.pending.set(id, (response) => {
        if (response.error) reject(new Error(response.error.message));
        else resolve(response.result);
      });
      this.target.postMessage(request, "*");
    });
  }

  private handleMessage = (event: MessageEvent): void => {
    const message = event.data as JsonRpcResponse & { method?: string; params?: unknown };
    if (!message || message.jsonrpc !== "2.0") return;
    if (message.id !== undefined && this.pending.has(message.id)) {
      const done = this.pending.get(message.id)!;
      this.pending.delete(message.id);
      done(message);
      return;
    }
    if (message.method) {
      for (const listener of this.listeners.get(message.method) ?? []) listener(message.params);
    }
  };
}
