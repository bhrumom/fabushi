import type { MiniAppHostMethod } from "./miniapp-host-spec.generated";
import { MiniAppHostError, normalizeHostError } from "./errors";
import {
  HOST_API_VERSION,
  type AnyRecord,
  type HostInvokeEnvelope,
  type HostInvokeResponse,
  type InvokeMeta,
  type ReadyOptions,
} from "./types";

export const SDK_VERSION = "0.1.0";

export function isBrowser(): boolean {
  return typeof window !== "undefined" && typeof document !== "undefined";
}

function asRecord(value: unknown): AnyRecord | null {
  return value && typeof value === "object" ? (value as AnyRecord) : null;
}

function createRequestId(): string {
  const random = Math.random().toString(36).slice(2, 10);
  return `req_${Date.now().toString(36)}_${random}`;
}

function normalizeResponse<T>(raw: unknown, requestId: string): HostInvokeResponse<T> {
  const record = asRecord(raw);
  if (!record) return { ok: true, requestId, data: raw as T };
  if (typeof record.ok === "boolean") return record as unknown as HostInvokeResponse<T>;
  return { ok: true, requestId, data: raw as T };
}

export class HostBridge {
  private readonly metaProvider: () => Partial<InvokeMeta>;

  constructor(metaProvider: () => Partial<InvokeMeta> = () => ({})) {
    this.metaProvider = metaProvider;
  }

  isHostEnv(): boolean {
    if (!isBrowser()) return false;
    return Boolean(
      window.flutter_inappwebview?.callHandler || window.FabushiMiniApp?.invoke,
    );
  }

  async ready(options: ReadyOptions = {}): Promise<boolean> {
    if (this.isHostEnv()) return true;
    if (!isBrowser()) return false;

    const timeoutMs = options.timeoutMs ?? 3000;
    await new Promise<void>((resolve) => {
      let settled = false;
      const done = () => {
        if (settled) return;
        settled = true;
        window.removeEventListener("fabushi-miniapp-ready", done);
        resolve();
      };
      window.addEventListener("fabushi-miniapp-ready", done, { once: true });
      window.setTimeout(done, timeoutMs);
    });
    return this.isHostEnv();
  }

  async invoke<T = unknown>(method: MiniAppHostMethod | (string & {}), params: AnyRecord = {}, meta: AnyRecord = {}): Promise<T> {
    if (!isBrowser()) {
      throw new MiniAppHostError({
        code: "host_unavailable",
        message: "当前环境没有可用的小程序宿主",
        recoverable: true,
      });
    }

    const requestId = createRequestId();
    const envelope: HostInvokeEnvelope = {
      requestId,
      hostApiVersion: HOST_API_VERSION,
      method,
      params,
      meta: {
        sdkVersion: SDK_VERSION,
        ...this.metaProvider(),
        ...meta,
      },
    };

    let raw: unknown;
    const callHandler = window.flutter_inappwebview?.callHandler;
    if (typeof callHandler === "function") {
      raw = await callHandler("FabushiMiniAppInvoke", envelope);
    } else if (typeof window.FabushiMiniApp?.invoke === "function") {
      // Backward-compatible path for older injected bridges.
      raw = await window.FabushiMiniApp.invoke(method, params);
    } else {
      throw new MiniAppHostError({
        code: "host_unavailable",
        message: "SDK 尚未连接到全球法布施宿主",
        recoverable: true,
      });
    }

    const response = normalizeResponse<T>(raw, requestId);
    if (!response.ok) throw normalizeHostError(response);
    return response.data;
  }
}
