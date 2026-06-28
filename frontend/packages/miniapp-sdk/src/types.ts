export type AnyRecord = Record<string, unknown>;

export const HOST_API_VERSION = "2.0" as const;
export type HostApiVersion = typeof HOST_API_VERSION;

export type MiniAppEventName =
  | "ready"
  | "themeChanged"
  | "viewportChanged"
  | "botMessage"
  | "invoiceClosed"
  | "agentLog";

export interface ReadyOptions {
  timeoutMs?: number;
  miniAppId?: string;
}

export interface InvokeMeta extends AnyRecord {
  sdkVersion: string;
  miniAppId?: string;
}

export interface HostInvokeEnvelope {
  requestId: string;
  hostApiVersion: HostApiVersion;
  method: string;
  params: AnyRecord;
  meta: InvokeMeta;
}

export interface HostErrorBody {
  code: string;
  message: string;
  recoverable?: boolean;
  retryAfterMs?: number;
  details?: AnyRecord;
}

export interface HostInvokeSuccess<T = unknown> {
  ok: true;
  requestId?: string;
  data: T;
  warnings?: string[];
}

export interface HostInvokeFailure {
  ok: false;
  requestId?: string;
  error?: HostErrorBody;
  errorCode?: string;
  message?: string;
  data?: unknown;
}

export type HostInvokeResponse<T = unknown> =
  | HostInvokeSuccess<T>
  | HostInvokeFailure;

export interface MiniAppBotContext {
  botId?: string;
  title?: string;
  miniAppId?: string;
  kind?: string;
  source?: string;
}

export interface MiniAppContext extends AnyRecord {
  hostApiVersion?: string;
  platform?: string;
  trustedOfficial?: boolean;
  sessionId?: string;
  initData?: string;
  bot?: MiniAppBotContext;
}

export interface CapabilityResult {
  capabilities: string[];
}

export interface HostApiMethodSpec extends AnyRecord {
  method: string;
  permission?: string;
  description?: string;
}

export interface HostApiSpec extends AnyRecord {
  hostApiVersion?: string;
  invokePattern?: string;
  permissionGroups?: Record<string, string[]>;
  methods?: HostApiMethodSpec[];
}

export interface FallbackOptions {
  mode?: "open-in-app" | "readonly" | "hidden";
  title: string;
  message?: string;
  appLink?: string;
  ctaLabel?: string;
}

export interface AuthInitData extends AnyRecord {
  initData?: string;
  initDataUnsafe?: AnyRecord;
  authDate?: string;
  nonce?: string;
}

export interface AuthSession extends AnyRecord {
  authenticated?: boolean;
  user?: AnyRecord | null;
  membership?: AnyRecord | null;
}

export interface CreateInvoiceInput extends AnyRecord {
  sku?: string;
  productId?: string;
  title?: string;
  subject?: string;
  description?: string;
  amount: number;
  currency?: "FUDE_JIN" | "CNY" | string;
  priceLabel?: string;
  metadata?: AnyRecord;
}

export interface Invoice extends AnyRecord {
  id: string;
  invoiceId?: string;
  orderId?: string;
  status?: string;
  amount?: number;
  currency?: string;
}

export interface InvoicePaymentResult extends AnyRecord {
  invoiceId?: string;
  orderId?: string;
  status: string;
  paid?: boolean;
  pending?: boolean;
}

export interface WalletBalance extends AnyRecord {
  balance: number;
  lockedBalance?: number;
  currency?: string;
}

export interface AgentStatus extends AnyRecord {
  agentId?: string;
  installId?: string;
  status?: string;
}

export interface SecretRequest extends AnyRecord {
  key: string;
  reason: string;
}

export interface SecretStatus extends AnyRecord {
  key: string;
  available: boolean;
  storage?: string;
}

export interface StorageNamespace {
  getItem(key: string): Promise<string | null>;
  setItem(key: string, value: string): Promise<void>;
  removeItem(key: string): Promise<void>;
  getKeys(prefix?: string): Promise<string[]>;
}

export interface PopupOptions extends AnyRecord {
  title: string;
  message?: string;
  buttonText?: string;
}

export interface ConfirmOptions extends PopupOptions {
  confirmText?: string;
  cancelText?: string;
  destructive?: boolean;
}

export interface MainButtonOptions extends AnyRecord {
  text: string;
  visible?: boolean;
  enabled?: boolean;
  loading?: boolean;
}

declare global {
  interface Window {
    FabushiMiniApp?: {
      ready?: boolean;
      initData?: string;
      initDataUnsafe?: AnyRecord;
      invoke?: (method: string, params?: AnyRecord) => Promise<unknown>;
    };
    flutter_inappwebview?: {
      callHandler?: (handlerName: string, payload: unknown) => Promise<unknown>;
    };
  }
}
