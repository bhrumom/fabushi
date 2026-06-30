import { MiniAppHostError } from "./errors";
import { HOST_API_VERSION, type AnyRecord } from "./types";

const startedAt = new Date().toISOString();
const invoices = new Map<string, AnyRecord>();
const memory = new Map<string, string>();

function createId(prefix: string): string {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

function asText(value: unknown, fallback = ""): string {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

export function isMockableMethod(method: string): boolean {
  return method.startsWith("app.") ||
    method.startsWith("auth.") ||
    method.startsWith("payments.") ||
    method.startsWith("wallet.") ||
    method.startsWith("storage.") ||
    method.startsWith("ui.");
}

export async function invokeMockHost<T = unknown>(method: string, params: AnyRecord = {}): Promise<T> {
  switch (method) {
    case "app.getContext":
      return {
        hostApiVersion: HOST_API_VERSION,
        platform: "browser",
        trustedOfficial: false,
        sessionId: "mock-browser-session",
        bot: {
          botId: "browser.preview",
          title: "浏览器预览",
          miniAppId: "browser.preview",
          source: "fallback",
        },
        startedAt,
      } as T;
    case "app.getCapabilities":
      return {
        capabilities: [
          "app.context",
          "auth.session",
          "payments.invoice.mock",
          "wallet.balance.mock",
          "storage.device",
          "ui.fallback",
        ],
      } as T;
    case "app.getHostApiSpec":
      return {
        hostApiVersion: HOST_API_VERSION,
        invokePattern: "fbApp.invoke(method, params)",
        fallback: true,
        methods: [
          { method: "app.getContext", permission: "app.context" },
          { method: "app.getCapabilities", permission: "app.context" },
          { method: "payments.createInvoice", permission: "payments.invoice.mock" },
          { method: "payments.openInvoice", permission: "payments.invoice.mock" },
        ],
      } as T;
    case "auth.getInitData":
      return {
        initData: "",
        initDataUnsafe: { fallback: true, auth_date: Math.floor(Date.now() / 1000) },
      } as T;
    case "auth.getSession":
      return { authenticated: false, user: null, membership: null } as T;
    case "auth.requireLogin":
      throw new MiniAppHostError({
        code: "host_unavailable",
        message: "请在全球法布施 App 内登录后继续",
        recoverable: true,
      });
    case "payments.createInvoice": {
      const invoiceId = createId("mock_inv");
      const invoice = {
        id: invoiceId,
        invoiceId,
        sku: asText(params.sku, asText(params.productId, "mock_sku")),
        title: asText(params.title, asText(params.subject, "模拟账单")),
        amount: typeof params.amount === "number" ? params.amount : 0,
        currency: asText(params.currency, "FUDE_JIN"),
        status: "created",
        mock: true,
      };
      invoices.set(invoiceId, invoice);
      return invoice as T;
    }
    case "payments.openInvoice": {
      const invoiceId = asText(params.invoiceId, asText(params.id));
      const invoice = invoices.get(invoiceId) ?? { id: invoiceId, invoiceId, mock: true };
      const result = { ...invoice, status: "paid", paid: true, pending: false };
      if (invoiceId) invoices.set(invoiceId, result);
      return result as T;
    }
    case "payments.queryInvoice": {
      const invoiceId = asText(params.invoiceId, asText(params.id));
      return (invoices.get(invoiceId) ?? { id: invoiceId, invoiceId, status: "not_found", mock: true }) as T;
    }
    case "wallet.getBalance":
    case "payments.getWalletBalance":
      return { balance: 0, lockedBalance: 0, currency: "FUDE_JIN", mock: true } as T;
    case "storage.getItem":
      return { value: memory.get(String(params.namespace ?? "device") + ":" + String(params.key)) ?? null } as T;
    case "storage.setItem":
      memory.set(String(params.namespace ?? "device") + ":" + String(params.key), String(params.value ?? ""));
      return { ok: true } as T;
    case "storage.removeItem":
      memory.delete(String(params.namespace ?? "device") + ":" + String(params.key));
      return { ok: true } as T;
    case "storage.getKeys": {
      const namespace = `${String(params.namespace ?? "device")}:`;
      const prefix = asText(params.prefix);
      return {
        keys: [...memory.keys()]
          .filter((key) => key.startsWith(namespace))
          .map((key) => key.slice(namespace.length))
          .filter((key) => !prefix || key.startsWith(prefix)),
      } as T;
    }
    case "ui.showPopup":
    case "ui.setMainButton":
    case "ui.setBackButton":
    case "ui.hapticImpact":
    case "ui.close":
      return { ok: true, mock: true } as T;
    default:
      throw new MiniAppHostError({
        code: "host_unavailable",
        message: "请在全球法布施 App 内打开后使用完整能力",
        recoverable: true,
        details: { method },
      });
  }
}
