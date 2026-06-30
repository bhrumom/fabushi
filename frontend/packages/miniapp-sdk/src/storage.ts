import type { AnyRecord, StorageNamespace } from "./types";
import type { HostInvoker } from "./auth";

type NamespaceName = "cloud" | "device" | "secure";

class HostStorageNamespace implements StorageNamespace {
  private readonly invoke: HostInvoker;
  private readonly namespace: NamespaceName;

  constructor(invoke: HostInvoker, namespace: NamespaceName) {
    this.invoke = invoke;
    this.namespace = namespace;
  }

  async getItem(key: string): Promise<string | null> {
    const data = await this.invoke<{ value?: string | null }>("storage.getItem", {
      namespace: this.namespace,
      key,
    });
    return data.value ?? null;
  }

  async setItem(key: string, value: string): Promise<void> {
    await this.invoke<AnyRecord>("storage.setItem", {
      namespace: this.namespace,
      key,
      value,
    });
  }

  async removeItem(key: string): Promise<void> {
    await this.invoke<AnyRecord>("storage.removeItem", {
      namespace: this.namespace,
      key,
    });
  }

  async getKeys(prefix = ""): Promise<string[]> {
    const data = await this.invoke<{ keys?: string[] }>("storage.getKeys", {
      namespace: this.namespace,
      prefix,
    });
    return Array.isArray(data.keys) ? data.keys : [];
  }
}

export class StorageModule {
  readonly cloudStorage: StorageNamespace;
  readonly deviceStorage: StorageNamespace;
  readonly secureStorage: StorageNamespace;

  constructor(invoke: HostInvoker) {
    this.cloudStorage = new HostStorageNamespace(invoke, "cloud");
    this.deviceStorage = new HostStorageNamespace(invoke, "device");
    this.secureStorage = new HostStorageNamespace(invoke, "secure");
  }
}
