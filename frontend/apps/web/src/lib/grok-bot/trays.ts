// Vendored from the user's Grok Bot 0.16.0 trays-service.ts.
import type { ErrorTray, TrayAction } from "../mahayana-host/contracts";

export type TrayEvent =
  | { type: "pushed"; tray: ErrorTray }
  | { type: "dismissed"; id: string }
  | { type: "cleared" };

export interface PushErrorOptions {
  readonly agentId: string;
  readonly title: string;
  readonly detail?: string;
  readonly requestId?: string;
  readonly errorKind?: "provider_overloaded";
  readonly rawDetail?: string;
  readonly actions?: readonly TrayAction[];
  readonly dedupeKey?: string;
  readonly count?: number;
}

export const MAX_TRAYS = 20;

function newId(): string {
  return crypto.randomUUID();
}

export class TrayManager {
  private readonly listeners = new Set<(event: TrayEvent) => void>();
  private trays: ErrorTray[] = [];

  getTrays(): readonly ErrorTray[] {
    return this.trays;
  }

  pushError({
    agentId,
    title,
    detail,
    requestId,
    errorKind,
    rawDetail,
    actions,
    dedupeKey,
    count,
  }: PushErrorOptions): ErrorTray {
    const now = Date.now();

    if (dedupeKey != null) {
      const index = this.trays.findIndex(
        (tray) => tray.kind === "error" && tray.dedupeKey === dedupeKey,
      );
      const existing = index === -1 ? null : this.trays[index];
      if (existing != null) {
        const updated: ErrorTray = {
          ...existing,
          title,
          detail,
          requestId,
          count: count ?? (existing.count ?? 1) + 1,
          createdAt: now,
          ...(errorKind != null ? { errorKind } : { errorKind: undefined }),
          ...(rawDetail != null ? { rawDetail } : { rawDetail: undefined }),
          ...(actions != null && actions.length > 0 ? { actions: [...actions] } : { actions: undefined }),
        };
        const next = [...this.trays];
        next[index] = updated;
        this.trays = next;
        this.emit({ type: "pushed", tray: updated });
        return updated;
      }
    }

    const tray: ErrorTray = {
      kind: "error",
      id: newId(),
      agentId,
      title,
      detail,
      requestId,
      createdAt: now,
      ...(errorKind != null ? { errorKind } : {}),
      ...(rawDetail != null ? { rawDetail } : {}),
      ...(actions != null && actions.length > 0 ? { actions: [...actions] } : {}),
      ...(dedupeKey != null ? { dedupeKey, count: count ?? 1 } : {}),
    };
    this.trays = [...this.trays, tray];
    this.emit({ type: "pushed", tray });
    this.enforceCap();
    return tray;
  }

  clearAll(): void {
    if (this.trays.length === 0) return;
    this.trays = [];
    this.emit({ type: "cleared" });
  }

  dismiss(id: string): boolean {
    const next = this.trays.filter((tray) => tray.id !== id);
    if (next.length === this.trays.length) return false;
    this.trays = next;
    this.emit({ type: "dismissed", id });
    return true;
  }

  clearForAgent(agentId: string): void {
    const remaining = this.trays.filter((tray) => tray.agentId !== agentId);
    const removed = this.trays.filter((tray) => tray.agentId === agentId);
    if (removed.length === 0) return;
    this.trays = remaining;
    for (const tray of removed) {
      this.emit({ type: "dismissed", id: tray.id });
    }
  }

  subscribe(listener: (event: TrayEvent) => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private enforceCap(): void {
    if (this.trays.length <= MAX_TRAYS) return;
    const overflow = this.trays.length - MAX_TRAYS;
    const dropped = this.trays.slice(0, overflow);
    this.trays = this.trays.slice(overflow);
    for (const tray of dropped) {
      this.emit({ type: "dismissed", id: tray.id });
    }
  }

  private emit(event: TrayEvent): void {
    for (const listener of this.listeners) listener(event);
  }
}
