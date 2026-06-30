"use client";

export const MINIAPP_SDK_VERSION = "1.4.0";

export type HostInvokeResponse<T = any> = {
  ok?: boolean;
  requestId?: string;
  data?: T;
  errorCode?: string;
  message?: string;
};

export type MiniAppProduct = {
  productId: string;
  title?: string;
  priceLabel?: string;
};

export type EntitlementState = "unlocked" | "locked" | "unavailable";

export type MiniAppCommandEvent = {
  id?: string;
  commandId?: string;
  command?: string;
  args?: string;
  text?: string;
  rawText?: string;
  background?: boolean;
  source?: string;
  createdAt?: string;
};

export class HostInvokeError extends Error {
  code?: string;
  data?: any;
  requestId?: string;

  constructor(response: HostInvokeResponse) {
    super(response?.message || "宿主调用失败");
    this.name = "HostInvokeError";
    this.code = response?.errorCode;
    this.data = response?.data;
    this.requestId = response?.requestId;
  }
}

function hostSdk() {
  return (window as any).FabushiMiniApp;
}

export function isHostReady() {
  return Boolean(hostSdk()?.ready);
}

export function getInitData() {
  if (typeof window === "undefined") return { startParam: null };
  const searchParams = new URLSearchParams(window.location.search);
  const startParamBase64 = searchParams.get("tgWebAppStartParam");
  if (startParamBase64) {
    try {
      let b64 = startParamBase64.replace(/-/g, '+').replace(/_/g, '/');
      const pad = b64.length % 4;
      if (pad) b64 += '='.repeat(4 - pad);
      const decodedStr = new TextDecoder().decode(
        Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
      );
      return { startParam: decodedStr };
    } catch (e) {
      console.error("Failed to parse startParam:", e);
    }
  }
  return { startParam: null };
}

export function onBotMessage(callback: (msg: string) => void) {
  const handler = (event: any) => {
    if (event.detail && typeof event.detail.text === "string") {
      callback(event.detail.text);
    }
  };
  window.addEventListener("fabushi-bot-message", handler);

  return () => {
    window.removeEventListener("fabushi-bot-message", handler);
  };
}

function commandKey(commandEvent: MiniAppCommandEvent) {
  return (
    commandEvent.commandId ||
    commandEvent.id ||
    [
      commandEvent.createdAt,
      commandEvent.command,
      commandEvent.rawText || commandEvent.text,
    ]
      .filter(Boolean)
      .join(":")
  );
}

function readStoredCommandQueue(): MiniAppCommandEvent[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem("__fabushiMiniAppCommandQueue") || "[]";
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function clearStoredCommandQueue() {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem("__fabushiMiniAppCommandQueue", "[]");
  } catch {
    // ignore storage failures
  }
}

function pendingCommands(): MiniAppCommandEvent[] {
  if (typeof window === "undefined") return [];
  const commands: MiniAppCommandEvent[] = [];
  const anyWindow = window as any;
  if (anyWindow.__fabushiLastMiniAppCommand) {
    commands.push(anyWindow.__fabushiLastMiniAppCommand);
  }
  if (Array.isArray(anyWindow.__fabushiMiniAppCommandQueue)) {
    commands.push(...anyWindow.__fabushiMiniAppCommandQueue);
    anyWindow.__fabushiMiniAppCommandQueue = [];
  }
  commands.push(...readStoredCommandQueue());
  clearStoredCommandQueue();
  return commands;
}

export function onAnyBotCommand(callback: (event: MiniAppCommandEvent) => void) {
  if (typeof window === "undefined") return () => {};

  const seenCommandIds = new Set<string>();
  const deliver = (detail: unknown) => {
    if (!detail || typeof detail !== "object") return;
    const commandEvent = detail as MiniAppCommandEvent;
    const key = commandKey(commandEvent);
    if (key) {
      if (seenCommandIds.has(key)) return;
      seenCommandIds.add(key);
    }
    callback(commandEvent);
  };

  const handler = (event: any) => {
    deliver(event.detail);
  };
  window.addEventListener("fabushi-miniapp-command", handler);

  const drainHostQueue = async () => {
    if (!isHostReady()) return;
    try {
      const data = await invokeHost<{ commands?: MiniAppCommandEvent[] }>(
        "bot.takePendingCommands",
        {},
      );
      (data?.commands || []).forEach(deliver);
    } catch {
      // The host queue is a best-effort message bus fallback. Event delivery
      // and localStorage delivery above remain available when this fails.
    }
  };

  const schedule =
    window.queueMicrotask || ((fn: VoidFunction) => window.setTimeout(fn, 0));
  schedule(() => {
    pendingCommands().forEach(deliver);
    drainHostQueue();
  });
  const unsubscribeReady = onMiniAppReady(drainHostQueue);
  const pollId = window.setInterval(drainHostQueue, 1000);
  const stopPollId = window.setTimeout(() => window.clearInterval(pollId), 30000);

  return () => {
    window.removeEventListener("fabushi-miniapp-command", handler);
    unsubscribeReady();
    window.clearInterval(pollId);
    window.clearTimeout(stopPollId);
  };
}

export function onBotCommand(
  command: string,
  callback: (args: string, event?: MiniAppCommandEvent) => void,
) {
  return onAnyBotCommand((event) => {
    if (event.command === command) {
      callback(event.args || "", event);
    }
  });
}

function registerBotCommandWhenReady(
  command: string,
  description: string,
) {
  if (typeof window === "undefined") return () => {};

  let disposed = false;
  const commandSpec = [{ command, description }];
  const register = () => {
    if (disposed || !isHostReady()) return;
    miniAppHost.bot.setCommands(commandSpec).catch(() => {});
  };

  register();
  const unsubscribeReady = onMiniAppReady(register);
  window.setTimeout(register, 250);
  window.setTimeout(register, 1000);

  return () => {
    disposed = true;
    unsubscribeReady();
  };
}

export function exposeBotCommand(
  command: string,
  callback: (args: string, event?: MiniAppCommandEvent) => void | Promise<void>,
  options: { description?: string } = {},
) {
  const unregisterCommand = registerBotCommandWhenReady(
    command,
    options.description || "",
  );
  const unsubscribeCommand = onBotCommand(command, callback);
  return () => {
    unregisterCommand();
    unsubscribeCommand();
  };
}

export function onMiniAppReady(callback: () => void) {
  if (isHostReady()) {
    window.queueMicrotask(callback);
    return () => {};
  }
  window.addEventListener("fabushi-miniapp-ready", callback);
  return () => window.removeEventListener("fabushi-miniapp-ready", callback);
}

export function isHostErrorCode(error: unknown, ...codes: string[]) {
  return error instanceof HostInvokeError && typeof error.code === "string" && codes.includes(error.code);
}

export async function invokeHost<T = any>(
  method: string,
  params: Record<string, any> = {},
): Promise<T> {
  const sdk = hostSdk();
  if (!sdk?.invoke) throw new Error("SDK 尚未就绪");
  
  let res = await sdk.invoke(method, params);
  
  // 拦截并自动处理需要登录的错误
  if (!res?.ok && res?.errorCode === "login_required" && method !== "auth.requireLogin") {
    const loginRes = await sdk.invoke("auth.requireLogin", { force: false });
    if (loginRes?.ok) {
      // 重新尝试原始请求
      res = await sdk.invoke(method, params);
    }
  }

  if (!res?.ok) throw new HostInvokeError(res);
  return res.data as T;
}

export function createEntitlementCache(storageKey: string, product: MiniAppProduct) {
  const read = () => {
    try {
      const raw = window.localStorage.getItem(storageKey);
      if (!raw) return false;
      const record = JSON.parse(raw);
      return record?.productId === product.productId && record?.paid === true;
    } catch {
      return false;
    }
  };

  const save = (payment: any) => {
    const record = {
      productId: product.productId,
      title: product.title,
      priceLabel: product.priceLabel,
      paid: true,
      paidAt: new Date().toISOString(),
      payment,
    };
    window.localStorage.setItem(storageKey, JSON.stringify(record));
  };

  const clear = () => {
    window.localStorage.removeItem(storageKey);
  };

  return { read, save, clear };
}

async function checkEntitlement(productId: string): Promise<EntitlementState> {
  try {
    const entitlement = await invokeHost<{ unlocked?: boolean }>(
      "payments.checkEntitlement",
      { productId },
    );
    return entitlement?.unlocked === true ? "unlocked" : "locked";
  } catch (error) {
    if (isHostErrorCode(error, "unknown_method")) {
      const entitlement = await invokeHost<{ unlocked?: boolean }>(
        "payments.alipay.checkEntitlement",
        { productId },
      );
      return entitlement?.unlocked === true ? "unlocked" : "locked";
    }
    if (isHostErrorCode(error, "permission_denied")) return "unavailable";
    if (isHostErrorCode(error, "login_required")) return "locked";
    throw error;
  }
}

export const miniAppHost = {
  invoke: invokeHost,
  app: {
    getContext: () => invokeHost("app.getContext"),
    getCapabilities: () => invokeHost<{ capabilities?: string[] }>("app.getCapabilities"),
    getHostApiSpec: () => invokeHost("app.getHostApiSpec"),
    getTheme: () => invokeHost("app.getTheme"),
  },
  auth: {
    getSession: () => invokeHost("auth.getSession"),
    requireLogin: () => invokeHost("auth.requireLogin"),
    getAccessToken: () => invokeHost("auth.getAccessToken"),
  },
  payments: {
    checkEntitlement,
    requestPayment: (params: Record<string, any>) => invokeHost("payments.requestPayment", params),
    alipay: {
      createOrder: (params: Record<string, any>) => invokeHost("payments.alipay.createOrder", params),
      pay: (params: Record<string, any>) => invokeHost("payments.alipay.pay", params),
      queryOrder: (orderId: string) => invokeHost("payments.alipay.queryOrder", { orderId }),
      checkEntitlement,
    },
  },
  wallet: {
    getBalance: (currency = "FUDE_GOLD") => invokeHost("wallet.getBalance", { currency }),
  },
  bot: {
    sendMessage: (params: Record<string, any>) => invokeHost("bot.sendMessage", params),
    postMessage: (params: Record<string, any>) => invokeHost("bot.postMessage", params),
    reportCommandResult: (params: Record<string, any>) => invokeHost("bot.reportCommandResult", params),
    takePendingCommands: () => invokeHost<{ commands?: MiniAppCommandEvent[] }>("bot.takePendingCommands", {}),
    openPanel: (params: Record<string, any> = {}) => invokeHost("bot.openPanel", params),
    setPanelState: (params: Record<string, any>) => invokeHost("bot.setPanelState", params),
    setCommands: (commands: Array<{ command: string; description: string }>) => invokeHost("bot.setCommands", { commands }),
    close: () => invokeHost("bot.close", {}),
    getInitData,
    onMessage: onBotMessage,
    onAnyCommand: onAnyBotCommand,
    onCommand: onBotCommand,
    exposeCommand: exposeBotCommand,
  },
  dharma: {
    getSendStatus: () => invokeHost("dharma.getSendStatus"),
    setSendOptions: (params: Record<string, any>) => invokeHost("dharma.setSendOptions", params),
    selectHighEnergyMaterial: () => invokeHost("dharma.selectHighEnergyMaterial"),
    startGlobalSend: (params: Record<string, any>) => invokeHost("dharma.startGlobalSend", params),
    stopGlobalSend: () => invokeHost("dharma.stopGlobalSend"),
  },
  flashcards: {
    createDeck: (params: Record<string, any>) => invokeHost("flashcards.createDeck", params),
    openDeck: (deckId: string) => invokeHost("flashcards.openDeck", { deckId }),
  },
  platformPublish: {
    createDraft: (params: Record<string, any>) => invokeHost("platformPublish.createDraft", params),
    publishDraft: (params: Record<string, any>) => invokeHost("platformPublish.publishDraft", params),
  },
  files: {
    pick: (params: Record<string, any> = {}) => invokeHost("files.pick", params),
  },
  fs: {
    writeFile: (params: Record<string, any>) => invokeHost("fs.writeFile", params),
    readFile: (path: string) => invokeHost("fs.readFile", { path }),
  },
  shell: {
    execute: (params: Record<string, any>) => invokeHost("shell.execute", params),
  },
  browser: {
    open: (url: string) => invokeHost("browser.open", { url }),
  },
};
