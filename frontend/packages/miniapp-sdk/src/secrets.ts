import type { AnyRecord, SecretRequest, SecretStatus } from "./types";
import type { HostInvoker } from "./auth";

export class SecretsModule {
  private readonly invoke: HostInvoker;

  constructor(invoke: HostInvoker) {
    this.invoke = invoke;
  }

  requestSecret(input: SecretRequest): Promise<SecretStatus> {
    return this.invoke("secrets.request", input);
  }

  listSecretStatus(agentId?: string): Promise<{ secrets: SecretStatus[] }> {
    return this.invoke("secrets.listStatus", { agentId });
  }

  clearSecret(key: string, agentId?: string): Promise<AnyRecord> {
    return this.invoke("secrets.clear", { key, agentId });
  }
}
