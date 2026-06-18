const DEFAULT_DACHENG_AI_PROXY_PATH = "/api/dacheng-ai";
const DEFAULT_DACHENG_AI_ORIGIN = "https://fabushi.ombhrum.com";
const DEFAULT_LOCAL_DACHENG_AI_API_BASE = "https://ai.ombhrum.com";

function readConfiguredAiBaseUrl() {
  const env = globalThis as typeof globalThis & {
    process?: {
      env?: Record<string, string | undefined>;
    };
  };
  return (
    env.process?.env?.NEXT_PUBLIC_DACHENG_AI_API_BASE_URL ||
    env.process?.env?.TARO_APP_DACHENG_AI_API_BASE_URL ||
    ""
  ).trim();
}

export function getDachengAiApiBaseUrl() {
  const configured = readConfiguredAiBaseUrl();
  if (configured) {
    return configured.replace(/\/+$/, "");
  }

  if (typeof window !== "undefined" && window.location.origin) {
    if (/^(localhost|127\.0\.0\.1|\[::1\])$/.test(window.location.hostname)) {
      return DEFAULT_LOCAL_DACHENG_AI_API_BASE;
    }
    return `${window.location.origin}${DEFAULT_DACHENG_AI_PROXY_PATH}`;
  }

  return `${DEFAULT_DACHENG_AI_ORIGIN}${DEFAULT_DACHENG_AI_PROXY_PATH}`;
}

export const dachengAiEndpoints = {
  health: "/health",
  chat: "/api/ai/chat",
  chatStream: "/api/ai/chat/stream",
  conversations: "/api/ai/conversations",
  conversation: (id: string) => `/api/ai/conversations/${encodeURIComponent(id)}`,
  resourceSearch: "/api/resources/search",
  resourceDownload: "/api/resources/download",
} as const;

export interface DachengAiUsage {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
  remainingTokens: number;
  monthlyLimit: number;
}

export interface DachengAiChatResponse {
  success: boolean;
  conversationId: string;
  provider: string;
  model: string;
  message: string;
  usage: DachengAiUsage;
}

export interface DachengAiConversationSummary {
  id: string;
  title: string;
  updatedAt: string;
}

export interface DachengAiConversationListResponse {
  success: boolean;
  items: DachengAiConversationSummary[];
}

export interface DharmaResourceSearchItem {
  id: string;
  title: string;
  sourceName: string;
  url: string;
  snippet: string;
  resourceType: string;
  work?: string;
  juan?: number;
}

export interface DharmaResourceSearchResponse {
  success: boolean;
  source: string;
  items: DharmaResourceSearchItem[];
}

export interface DachengAiStreamEvent {
  type: "meta" | "step" | "delta" | "done" | "error" | "message";
  text: string;
  conversationId?: string;
  provider?: string;
  model?: string;
  usage?: DachengAiUsage;
  title?: string;
  message?: string;
  raw: Record<string, unknown>;
}

export function parseDachengSseChunk(
  chunk: string,
  currentEventName = "message",
) {
  const events: DachengAiStreamEvent[] = [];
  const parts = chunk.split(/\n\n+/);
  for (const part of parts) {
    const lines = part.split(/\r?\n/).filter(Boolean);
    if (lines.length === 0) continue;
    let eventName = currentEventName;
    const dataLines: string[] = [];

    for (const line of lines) {
      if (line.startsWith("event:")) {
        eventName = line.slice("event:".length).trim() || "message";
      } else if (line.startsWith("data:")) {
        dataLines.push(line.slice("data:".length).trim());
      }
    }

    if (dataLines.length === 0) continue;
    const dataText = dataLines.join("\n");
    let payload: Record<string, unknown>;
    try {
      const decoded = JSON.parse(dataText);
      payload = decoded && typeof decoded === "object" ? decoded : { text: String(decoded) };
    } catch {
      payload = { text: dataText };
    }

    const type = eventName as DachengAiStreamEvent["type"];
    const text = String(
      payload.text ?? payload.message ?? payload.title ?? payload.stage ?? "",
    );
    events.push({
      type,
      text,
      conversationId:
        typeof payload.conversationId === "string" ? payload.conversationId : undefined,
      provider: typeof payload.provider === "string" ? payload.provider : undefined,
      model: typeof payload.model === "string" ? payload.model : undefined,
      usage:
        payload.usage && typeof payload.usage === "object"
          ? (payload.usage as DachengAiUsage)
          : undefined,
      title: typeof payload.title === "string" ? payload.title : undefined,
      message: typeof payload.message === "string" ? payload.message : undefined,
      raw: payload,
    });
  }
  return events;
}
