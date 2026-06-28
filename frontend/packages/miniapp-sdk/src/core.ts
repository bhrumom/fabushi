import { AgentModule } from "./agent";
import { AuthModule } from "./auth";
import { MiniAppHostError } from "./errors";
import { EventBus, type MiniAppEventHandler } from "./events";
import { HostBridge } from "./host-bridge";
import { isMockableMethod, invokeMockHost } from "./mock";
import { PaymentsModule } from "./payments";
import { SecretsModule } from "./secrets";
import { StorageModule } from "./storage";
import { UiModule } from "./ui";
import type {
  AnyRecord,
  CapabilityResult,
  FallbackOptions,
  HostApiSpec,
  MiniAppContext,
  MiniAppEventName,
  ReadyOptions,
} from "./types";

export interface FbAppOptions {
  miniAppId?: string;
  fallbackMode?: "mock" | "throw";
}

function isBrowser(): boolean {
  return typeof window !== "undefined" && typeof document !== "undefined";
}

function removeExistingFallback(): void {
  if (!isBrowser()) return;
  document.getElementById("fabushi-miniapp-fallback")?.remove();
}

function escapeText(value: string): string {
  return value.replace(/[&<>"]/g, (char) => {
    switch (char) {
      case "&":
        return "&amp;";
      case "<":
        return "&lt;";
      case ">":
        return "&gt;";
      case '"':
        return "&quot;";
      default:
        return char;
    }
  });
}

export class FbApp {
  readonly events = new EventBus();
  readonly auth: AuthModule;
  readonly payments: PaymentsModule;
  readonly agent: AgentModule;
  readonly secrets: SecretsModule;
  readonly storage: StorageModule;
  readonly ui: UiModule;
  readonly bridge: HostBridge;

  private readonly options: Required<FbAppOptions>;
  private latestCapabilities = new Set<string>();
  private latestContext: MiniAppContext | null = null;

  constructor(options: FbAppOptions = {}) {
    this.options = {
      miniAppId: options.miniAppId ?? "",
      fallbackMode: options.fallbackMode ?? "mock",
    };
    this.bridge = new HostBridge(() => ({ miniAppId: this.options.miniAppId || undefined }));

    const invoker = this.invoke.bind(this);
    this.auth = new AuthModule(invoker);
    this.payments = new PaymentsModule(invoker);
    this.agent = new AgentModule(invoker);
    this.secrets = new SecretsModule(invoker);
    this.storage = new StorageModule(invoker);
    this.ui = new UiModule(invoker);
  }

  isHostEnv(): boolean {
    return this.bridge.isHostEnv();
  }

  async ready(options: ReadyOptions = {}): Promise<boolean> {
    const hostReady = await this.bridge.ready({ ...options, miniAppId: this.options.miniAppId });
    if (hostReady) this.events.dispatchHostEvent("ready", { host: true });
    return hostReady;
  }

  async invoke<T = unknown>(method: string, params: AnyRecord = {}, meta: AnyRecord = {}): Promise<T> {
    if (this.isHostEnv()) return this.bridge.invoke<T>(method, params, meta);
    if (this.options.fallbackMode === "mock" && isMockableMethod(method)) {
      return invokeMockHost<T>(method, params);
    }
    throw new MiniAppHostError({
      code: "host_unavailable",
      message: "请在全球法布施 App 内打开后使用完整能力",
      recoverable: true,
      details: { method },
    });
  }

  async getContext(): Promise<MiniAppContext> {
    const context = await this.invoke<MiniAppContext>("app.getContext");
    this.latestContext = context;
    return context;
  }

  async getCapabilities(): Promise<string[]> {
    const data = await this.invoke<CapabilityResult>("app.getCapabilities");
    const capabilities = Array.isArray(data.capabilities) ? data.capabilities : [];
    this.latestCapabilities = new Set(capabilities);
    return capabilities;
  }

  getCachedContext(): MiniAppContext | null {
    return this.latestContext;
  }

  hasCapability(permission: string): boolean {
    return this.latestCapabilities.has(permission);
  }

  getHostApiSpec(): Promise<HostApiSpec> {
    return this.invoke<HostApiSpec>("app.getHostApiSpec");
  }

  on<T = unknown>(eventName: MiniAppEventName, handler: MiniAppEventHandler<T>): () => void {
    return this.events.on(eventName, handler);
  }

  once<T = unknown>(eventName: MiniAppEventName, handler: MiniAppEventHandler<T>): () => void {
    return this.events.once(eventName, handler);
  }

  off<T = unknown>(eventName: MiniAppEventName, handler: MiniAppEventHandler<T>): void {
    this.events.off(eventName, handler);
  }

  showFallback(options: FallbackOptions): void {
    if (!isBrowser() || options.mode === "hidden") return;
    removeExistingFallback();
    const root = document.createElement("div");
    root.id = "fabushi-miniapp-fallback";
    root.setAttribute("role", "status");
    root.style.cssText = [
      "min-height:100vh",
      "display:flex",
      "align-items:center",
      "justify-content:center",
      "background:#0f1722",
      "color:#fff",
      "font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif",
      "padding:24px",
      "box-sizing:border-box",
      "text-align:center",
    ].join(";");
    const message = options.message ?? "当前页面需要全球法布施 App 宿主能力。";
    const button = options.appLink
      ? `<a href="${escapeText(options.appLink)}" style="display:inline-flex;margin-top:18px;padding:12px 18px;border-radius:999px;background:#3390ec;color:#fff;text-decoration:none;font-weight:700">${escapeText(options.ctaLabel ?? "在 App 内打开")}</a>`
      : "";
    root.innerHTML = `<div style="max-width:420px"><h1 style="font-size:22px;margin:0 0 10px">${escapeText(options.title)}</h1><p style="margin:0;color:#aeb8c5;line-height:1.65">${escapeText(message)}</p>${button}</div>`;
    document.body.appendChild(root);
  }
}

export function createFbApp(options: FbAppOptions = {}): FbApp {
  return new FbApp(options);
}
