import type { AnyRecord, MiniAppEventName } from "./types";

export type MiniAppEventHandler<T = unknown> = (payload: T) => void;

type HandlerSet = Set<MiniAppEventHandler<unknown>>;

const hostEventMap: Record<MiniAppEventName, string> = {
  ready: "fabushi-miniapp-ready",
  themeChanged: "fabushi-theme-changed",
  viewportChanged: "fabushi-viewport-changed",
  botMessage: "fabushi-bot-message",
  invoiceClosed: "fabushi-invoice-closed",
  agentLog: "fabushi-agent-log",
};

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function normalizePayload(event: Event): unknown {
  if ("detail" in event) return (event as CustomEvent).detail;
  return undefined;
}

export class EventBus {
  private readonly handlers = new Map<MiniAppEventName, HandlerSet>();
  private readonly domSubscriptions = new Map<MiniAppEventName, EventListener>();

  on<T = unknown>(eventName: MiniAppEventName, handler: MiniAppEventHandler<T>): () => void {
    let set = this.handlers.get(eventName);
    if (!set) {
      set = new Set();
      this.handlers.set(eventName, set);
      this.subscribeDomEvent(eventName);
    }
    set.add(handler as MiniAppEventHandler<unknown>);
    return () => this.off(eventName, handler);
  }

  once<T = unknown>(eventName: MiniAppEventName, handler: MiniAppEventHandler<T>): () => void {
    const unsubscribe = this.on<T>(eventName, (payload) => {
      unsubscribe();
      handler(payload);
    });
    return unsubscribe;
  }

  off<T = unknown>(eventName: MiniAppEventName, handler: MiniAppEventHandler<T>): void {
    const set = this.handlers.get(eventName);
    if (!set) return;
    set.delete(handler as MiniAppEventHandler<unknown>);
    if (set.size === 0) {
      this.handlers.delete(eventName);
      this.unsubscribeDomEvent(eventName);
    }
  }

  emit<T = unknown>(eventName: MiniAppEventName, payload?: T): void {
    const set = this.handlers.get(eventName);
    if (!set) return;
    for (const handler of [...set]) handler(payload);
  }

  dispatchHostEvent(eventName: MiniAppEventName, payload: AnyRecord = {}): void {
    this.emit(eventName, payload);
    if (!isBrowser()) return;
    window.dispatchEvent(new CustomEvent(hostEventMap[eventName], { detail: payload }));
  }

  private subscribeDomEvent(eventName: MiniAppEventName): void {
    if (!isBrowser() || this.domSubscriptions.has(eventName)) return;
    const listener: EventListener = (event) => this.emit(eventName, normalizePayload(event));
    this.domSubscriptions.set(eventName, listener);
    window.addEventListener(hostEventMap[eventName], listener);
  }

  private unsubscribeDomEvent(eventName: MiniAppEventName): void {
    if (!isBrowser()) return;
    const listener = this.domSubscriptions.get(eventName);
    if (!listener) return;
    window.removeEventListener(hostEventMap[eventName], listener);
    this.domSubscriptions.delete(eventName);
  }
}
