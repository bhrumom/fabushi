export { FbApp, createFbApp, type FbAppOptions } from "./core";
export { MiniAppHostError, isMiniAppHostError } from "./errors";
export { SDK_VERSION } from "./host-bridge";
export { HOST_API_VERSION } from "./types";
export type {
  AgentStatus,
  AnyRecord,
  AuthInitData,
  AuthSession,
  CapabilityResult,
  CreateInvoiceInput,
  FallbackOptions,
  HostApiSpec,
  Invoice,
  InvoicePaymentResult,
  MainButtonOptions,
  MiniAppContext,
  MiniAppEventName,
  PopupOptions,
  ReadyOptions,
  SecretRequest,
  SecretStatus,
  StorageNamespace,
  WalletBalance,
} from "./types";

export const fbApp = createFbApp();
