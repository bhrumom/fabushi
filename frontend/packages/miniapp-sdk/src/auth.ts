import type { AnyRecord, AuthInitData, AuthSession } from "./types";

export type HostInvoker = <T = unknown>(method: string, params?: AnyRecord, meta?: AnyRecord) => Promise<T>;

export class AuthModule {
  private readonly invoke: HostInvoker;

  constructor(invoke: HostInvoker) {
    this.invoke = invoke;
  }

  getInitData(): Promise<AuthInitData> {
    return this.invoke<AuthInitData>("auth.getInitData");
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
