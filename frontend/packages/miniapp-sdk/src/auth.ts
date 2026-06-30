import { isUnknownMethod } from "./errors";
import type { AnyRecord, AuthInitData, AuthSession } from "./types";

export type HostInvoker = <T = unknown>(method: string, params?: AnyRecord, meta?: AnyRecord) => Promise<T>;

function browserInitDataFallback(): AuthInitData {
  if (typeof window === "undefined") return {};
  return {
    initData: window.FabushiMiniApp?.initData ?? "",
    initDataUnsafe: window.FabushiMiniApp?.initDataUnsafe ?? {},
  };
}

export class AuthModule {
  private readonly invoke: HostInvoker;

  constructor(invoke: HostInvoker) {
    this.invoke = invoke;
  }

  async getInitData(): Promise<AuthInitData> {
    try {
      return await this.invoke<AuthInitData>("auth.getInitData");
    } catch (error) {
      if (!isUnknownMethod(error)) throw error;
      return browserInitDataFallback();
    }
  }

  getSession(): Promise<AuthSession> {
    return this.invoke<AuthSession>("auth.getSession");
  }

  requireLogin(): Promise<AuthSession> {
    return this.invoke<AuthSession>("auth.requireLogin");
  }

  async getScopedToken(scope: string, reason: string): Promise<{ token: string; tokenType?: string; expiresAt?: string }> {
    return this.invoke("auth.getScopedToken", { scope, reason });
  }
}
