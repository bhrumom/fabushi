import type { JsonSchema, McpTool, McpToolResult } from "./types";

export type WebMcpTool = {
  name: string;
  title?: string;
  description?: string;
  inputSchema?: JsonSchema;
  annotations?: McpTool["annotations"];
  execute: (input: Record<string, unknown>) => Promise<unknown> | unknown;
};

type WebMcpModelContext = {
  registerTool(tool: WebMcpTool & { signal?: AbortSignal }): unknown;
  unregisterTool?(name: string): unknown;
  getTools?(): unknown;
  executeTool?(name: string, input?: Record<string, unknown>): unknown;
};

type FabushiWebMcpRegistry = {
  readonly version: 1;
  list(): Array<Omit<WebMcpTool, "execute">>;
  call(name: string, input?: Record<string, unknown>): Promise<unknown>;
};

declare global {
  interface Document {
    modelContext?: WebMcpModelContext;
  }
  interface Window {
    __fabushiWebMcp?: FabushiWebMcpRegistry;
  }
}

const localTools = new Map<string, WebMcpTool>();

function publicTool(tool: WebMcpTool): Omit<WebMcpTool, "execute"> {
  const { execute: _execute, ...metadata } = tool;
  return metadata;
}

function installFallbackRegistry(): void {
  if (typeof window === "undefined" || window.__fabushiWebMcp) return;
  Object.defineProperty(window, "__fabushiWebMcp", {
    configurable: true,
    enumerable: false,
    value: {
      version: 1 as const,
      list: () => [...localTools.values()].map(publicTool),
      call: async (name: string, input: Record<string, unknown> = {}) => {
        const tool = localTools.get(name);
        if (!tool) throw new Error(`Unknown WebMCP tool: ${name}`);
        return tool.execute(input);
      },
    },
  });
}

export function supportsNativeWebMcp(): boolean {
  return typeof document !== "undefined" && typeof document.modelContext?.registerTool === "function";
}

export function listRegisteredWebMcpTools(): Array<Omit<WebMcpTool, "execute">> {
  return [...localTools.values()].map(publicTool);
}

export async function callRegisteredWebMcpTool(
  name: string,
  input: Record<string, unknown> = {},
): Promise<unknown> {
  const nativeExecute = typeof document !== "undefined" ? document.modelContext?.executeTool : undefined;
  if (typeof nativeExecute === "function") {
    return nativeExecute.call(document.modelContext, name, input);
  }
  const tool = localTools.get(name);
  if (!tool) throw new Error(`Unknown WebMCP tool: ${name}`);
  return tool.execute(input);
}

export function registerWebMcpTool(tool: WebMcpTool): () => void {
  if (!tool.name.trim()) throw new Error("WebMCP tool name is required");
  localTools.set(tool.name, tool);
  installFallbackRegistry();

  const context = typeof document !== "undefined" ? document.modelContext : undefined;
  const controller = typeof AbortController !== "undefined" ? new AbortController() : undefined;
  if (context?.registerTool) {
    context.registerTool({ ...tool, ...(controller ? { signal: controller.signal } : {}) });
  }

  return () => {
    if (localTools.get(tool.name) !== tool) return;
    localTools.delete(tool.name);
    controller?.abort();
    try { context?.unregisterTool?.(tool.name); } catch { /* native host may already have torn down the document */ }
  };
}

export function exposeMcpToolsAsWebMcp(
  tools: readonly McpTool[],
  callTool: (name: string, args: Record<string, unknown>) => Promise<McpToolResult>,
): () => void {
  const disposers = tools.map((tool) => registerWebMcpTool({
    name: tool.name,
    title: tool.title,
    description: tool.description,
    inputSchema: tool.inputSchema,
    annotations: tool.annotations,
    execute: (input) => callTool(tool.name, input),
  }));
  return () => {
    for (const dispose of disposers.reverse()) dispose();
  };
}
