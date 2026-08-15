// Vendored from the user's Grok Bot 0.16.0 shared/os-notification.ts.
export type SandOsNotificationKind = "agent-done" | "agent-needs-input";

export interface SandAgentNotificationSnapshot {
  readonly id: string;
  readonly name: string;
  readonly isRunning: boolean;
  readonly awaitingReason: string | null;
  readonly lastMessageId: string | null;
  readonly lastMessagePreview: string | null;
  readonly notifyEnabled: boolean;
  readonly isHiddenFromSidebar: boolean;
}

export interface SandOsNotificationTransition {
  readonly agentId: string;
  readonly agentName: string;
  readonly kind: SandOsNotificationKind;
  readonly reason: string | null;
  readonly notifyEnabled: boolean;
  readonly isHiddenFromSidebar: boolean;
  readonly lastMessageId: string | null;
  readonly lastMessagePreview: string | null;
}

export const SAND_OS_NOTIFICATION_THROTTLE_MS = 5_000;
const MAX_NOTIFICATION_BODY_LENGTH = 140;

export function diffAgentNotificationTransitions(
  previous: ReadonlyMap<string, SandAgentNotificationSnapshot>,
  next: readonly SandAgentNotificationSnapshot[],
): SandOsNotificationTransition[] {
  const transitions: SandOsNotificationTransition[] = [];
  for (const agent of next) {
    const before = previous.get(agent.id);
    if (before == null) continue;
    const becameAwaiting = agent.awaitingReason != null && before.awaitingReason == null;
    if (becameAwaiting) {
      transitions.push({
        agentId: agent.id,
        agentName: agent.name,
        kind: "agent-needs-input",
        reason: agent.awaitingReason,
        notifyEnabled: agent.notifyEnabled,
        isHiddenFromSidebar: agent.isHiddenFromSidebar,
        lastMessageId: agent.lastMessageId,
        lastMessagePreview: agent.lastMessagePreview,
      });
      continue;
    }
    const finishedTurn = before.isRunning && !agent.isRunning && agent.awaitingReason == null;
    if (finishedTurn) {
      transitions.push({
        agentId: agent.id,
        agentName: agent.name,
        kind: "agent-done",
        reason: null,
        notifyEnabled: agent.notifyEnabled,
        isHiddenFromSidebar: agent.isHiddenFromSidebar,
        lastMessageId: agent.lastMessageId,
        lastMessagePreview: agent.lastMessagePreview,
      });
    }
  }
  return transitions;
}

export interface SandShouldNotifyInput {
  readonly notifyEnabled: boolean;
  readonly isHidden: boolean;
  readonly isWindowFocused: boolean;
  readonly nowMs: number;
  readonly lastNotifiedAtMs: number | null;
  readonly throttleWindowMs: number;
}

export function shouldNotify(input: SandShouldNotifyInput): boolean {
  if (input.isHidden) return false;
  if (!input.notifyEnabled) return false;
  if (input.isWindowFocused) return false;
  if (
    input.lastNotifiedAtMs != null &&
    input.nowMs - input.lastNotifiedAtMs < input.throttleWindowMs
  ) return false;
  return true;
}

export function buildNotificationContent(transition: SandOsNotificationTransition): {
  readonly title: string;
  readonly body: string;
} {
  const name = transition.agentName.trim().length > 0 ? transition.agentName.trim() : "Your agent";
  if (transition.kind === "agent-needs-input") {
    const reason = transition.reason?.trim() ?? "";
    return {
      title: `${name} needs you`,
      body: reason.length > 0 ? truncate(reason) : "Waiting for your input.",
    };
  }
  const summary = transition.lastMessagePreview?.trim() ?? "";
  return {
    title: name,
    body: summary.length > 0 ? truncate(summary) : "Open Grok Bot to see what it did.",
  };
}

function truncate(text: string): string {
  const collapsed = text.replace(/\s+/g, " ").trim();
  if (collapsed.length <= MAX_NOTIFICATION_BODY_LENGTH) return collapsed;
  return `${collapsed.slice(0, MAX_NOTIFICATION_BODY_LENGTH - 1).trimEnd()}…`;
}

export class SandOsNotificationDecider {
  private previous = new Map<string, SandAgentNotificationSnapshot>();
  private readonly lastNotifiedAtMs = new Map<string, number>();
  private readonly accountedMessageId = new Map<string, string | null>();

  constructor(private readonly throttleWindowMs = SAND_OS_NOTIFICATION_THROTTLE_MS) {}

  decide(input: {
    readonly agents: readonly SandAgentNotificationSnapshot[];
    readonly isWindowFocused: boolean;
    readonly nowMs: number;
  }): SandOsNotificationTransition[] {
    const out = this.gateTransitions(
      diffAgentNotificationTransitions(this.previous, input.agents),
      input,
    );
    const nextPrevious = new Map<string, SandAgentNotificationSnapshot>();
    for (const agent of input.agents) {
      if (!this.accountedMessageId.has(agent.id)) {
        this.accountedMessageId.set(agent.id, agent.lastMessageId);
      }
      nextPrevious.set(agent.id, agent);
    }
    this.previous = nextPrevious;
    return out;
  }

  seedBaseline(agents: readonly SandAgentNotificationSnapshot[]): void {
    for (const agent of agents) {
      if (!this.previous.has(agent.id)) this.previous.set(agent.id, agent);
      if (!this.accountedMessageId.has(agent.id)) {
        this.accountedMessageId.set(agent.id, agent.lastMessageId);
      }
    }
  }

  decideAgent(
    agent: SandAgentNotificationSnapshot,
    input: { readonly isWindowFocused: boolean; readonly nowMs: number },
  ): SandOsNotificationTransition[] {
    const out = this.gateTransitions(
      diffAgentNotificationTransitions(this.previous, [agent]),
      input,
    );
    if (!this.accountedMessageId.has(agent.id)) {
      this.accountedMessageId.set(agent.id, agent.lastMessageId);
    }
    this.previous.set(agent.id, agent);
    return out;
  }

  observeAgent(agent: SandAgentNotificationSnapshot): void {
    if (!this.accountedMessageId.has(agent.id)) {
      this.accountedMessageId.set(agent.id, agent.lastMessageId);
    }
    this.previous.set(agent.id, agent);
  }

  private gateTransitions(
    transitions: readonly SandOsNotificationTransition[],
    input: { readonly isWindowFocused: boolean; readonly nowMs: number },
  ): SandOsNotificationTransition[] {
    const out: SandOsNotificationTransition[] = [];
    for (const transition of transitions) {
      const accounted = this.accountedMessageId.get(transition.agentId) ?? null;
      if (
        transition.kind === "agent-done" &&
        (transition.lastMessageId == null || transition.lastMessageId === accounted)
      ) continue;
      this.accountedMessageId.set(transition.agentId, transition.lastMessageId);
      const key = throttleKey(transition.agentId, transition.kind);
      const passes = shouldNotify({
        notifyEnabled: transition.notifyEnabled,
        isHidden: transition.isHiddenFromSidebar,
        isWindowFocused: input.isWindowFocused,
        nowMs: input.nowMs,
        lastNotifiedAtMs: this.lastNotifiedAtMs.get(key) ?? null,
        throttleWindowMs: this.throttleWindowMs,
      });
      if (passes) {
        this.lastNotifiedAtMs.set(key, input.nowMs);
        out.push(transition);
      }
    }
    return out;
  }

  forget(agentId: string): void {
    this.previous.delete(agentId);
    this.accountedMessageId.delete(agentId);
    this.lastNotifiedAtMs.delete(throttleKey(agentId, "agent-done"));
    this.lastNotifiedAtMs.delete(throttleKey(agentId, "agent-needs-input"));
  }
}

function throttleKey(agentId: string, kind: SandOsNotificationKind): string {
  return `${agentId}:${kind}`;
}
