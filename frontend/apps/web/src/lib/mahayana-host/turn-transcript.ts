import type { RuntimeEvent } from './contracts';

export const MAHAYANA_TURN_PROTOCOL_VERSION = 1 as const;

export type MahayanaTurnCompletionStatus = 'completed' | 'interrupted' | 'error';
export type MahayanaTurnStatus = 'running' | MahayanaTurnCompletionStatus;
export type ToolPartStatus = 'generating' | 'running' | 'completed' | 'failed';

export type MahayanaTurnPayload =
  | { type: 'message.start'; payload: { model?: string; provider?: string } }
  | { type: 'message.delta'; payload: { text: string } }
  | { type: 'message.interim'; payload: { text: string } }
  | { type: 'message.complete'; payload: { text: string; status?: MahayanaTurnCompletionStatus; usage?: unknown } }
  | { type: 'reasoning.delta'; payload: { text: string; replace?: boolean } }
  | { type: 'reasoning.available'; payload: { text: string } }
  | { type: 'tool.generating'; payload: { toolId: string; name: string; title?: string } }
  | { type: 'tool.start'; payload: { toolId: string; name: string; title?: string; arguments?: unknown } }
  | { type: 'tool.progress'; payload: { toolId: string; detail?: string; progress?: number; total?: number } }
  | { type: 'tool.complete'; payload: { toolId: string; result?: unknown; error?: string } }
  | { type: 'approval.request'; payload: { approvalId: string; subject: string; detail?: string; proposedRule?: string; metadata?: unknown } }
  | { type: 'approval.resolve'; payload: { approvalId: string; decision: 'allow-once' | 'allow-session' | 'deny' } }
  | { type: 'clarify.request'; payload: { requestId: string; prompt: string; options?: string[]; metadata?: unknown } }
  | { type: 'clarify.resolve'; payload: { requestId: string; value?: unknown; dismissed?: boolean } }
  | { type: 'subagent.start'; payload: { subagentId: string; label: string; agentType?: string } }
  | { type: 'subagent.progress'; payload: { subagentId: string; detail: string } }
  | { type: 'subagent.complete'; payload: { subagentId: string; summary?: string; result?: unknown; error?: string } }
  | { type: 'artifact.available'; payload: { artifactId: string; title: string; kind: string; uri?: string; metadata?: unknown } }
  | { type: 'turn.error'; payload: { code: string; message: string; recoverable?: boolean } };

export type MahayanaTurnEvent = MahayanaTurnPayload & {
  protocolVersion: typeof MAHAYANA_TURN_PROTOCOL_VERSION;
  sessionId: string;
  conversationId?: string;
  turnId: string;
  operationId: string;
  seq: number;
  replayEpoch: number;
  timestampMs: number;
};

type PartBase = {
  id: string;
  seq: number;
};

export type AssistantTextPart = PartBase & {
  kind: 'text';
  text: string;
  sealed: boolean;
};

export type AssistantReasoningPart = PartBase & {
  kind: 'reasoning';
  text: string;
  sealed: boolean;
};

export type AssistantToolPart = PartBase & {
  kind: 'tool';
  toolId: string;
  name: string;
  title?: string;
  arguments?: unknown;
  detail?: string;
  progress?: number;
  total?: number;
  result?: unknown;
  error?: string;
  status: ToolPartStatus;
};

export type AssistantApprovalPart = PartBase & {
  kind: 'approval';
  approvalId: string;
  subject: string;
  detail?: string;
  proposedRule?: string;
  metadata?: unknown;
  decision?: 'allow-once' | 'allow-session' | 'deny';
};

export type AssistantClarifyPart = PartBase & {
  kind: 'clarify';
  requestId: string;
  prompt: string;
  options: string[];
  metadata?: unknown;
  value?: unknown;
  dismissed?: boolean;
  resolved: boolean;
};

export type AssistantSubagentPart = PartBase & {
  kind: 'subagent';
  subagentId: string;
  label: string;
  agentType?: string;
  detail?: string;
  summary?: string;
  result?: unknown;
  error?: string;
  status: 'running' | 'completed' | 'failed';
};

export type AssistantArtifactPart = PartBase & {
  kind: 'artifact';
  artifactId: string;
  title: string;
  artifactKind: string;
  uri?: string;
  metadata?: unknown;
};

export type AssistantErrorPart = PartBase & {
  kind: 'error';
  code: string;
  message: string;
  recoverable: boolean;
};

export type AssistantTurnPart =
  | AssistantTextPart
  | AssistantReasoningPart
  | AssistantToolPart
  | AssistantApprovalPart
  | AssistantClarifyPart
  | AssistantSubagentPart
  | AssistantArtifactPart
  | AssistantErrorPart;

export type AssistantTurn = {
  id: string;
  protocolVersion: typeof MAHAYANA_TURN_PROTOCOL_VERSION;
  sessionId: string;
  conversationId?: string;
  turnId: string;
  operationId: string;
  status: MahayanaTurnStatus;
  parts: AssistantTurnPart[];
  model?: string;
  provider?: string;
  usage?: unknown;
  lastSeq: number;
  replayEpoch: number;
  createdAtMs: number;
  updatedAtMs: number;
};

function cloneTurn(turn: AssistantTurn): AssistantTurn {
  return { ...turn, parts: turn.parts.map((part) => ({ ...part })) };
}

function createTurn(event: MahayanaTurnEvent): AssistantTurn {
  return {
    id: `turn:${event.sessionId}:${event.turnId}`,
    protocolVersion: MAHAYANA_TURN_PROTOCOL_VERSION,
    sessionId: event.sessionId,
    conversationId: event.conversationId,
    turnId: event.turnId,
    operationId: event.operationId,
    status: 'running',
    parts: [],
    lastSeq: event.seq,
    replayEpoch: event.replayEpoch,
    createdAtMs: event.timestampMs,
    updatedAtMs: event.timestampMs,
  };
}

function sealStreamingParts(turn: AssistantTurn): void {
  for (const part of turn.parts) {
    if ((part.kind === 'text' || part.kind === 'reasoning') && !part.sealed) part.sealed = true;
  }
}

function upsertPart<T extends AssistantTurnPart>(
  turn: AssistantTurn,
  predicate: (part: AssistantTurnPart) => part is T,
  create: () => NoInfer<T>,
  update: (part: T) => void,
): T {
  const existing = turn.parts.find(predicate);
  if (existing) {
    update(existing);
    return existing;
  }
  const next = create();
  turn.parts.push(next);
  return next;
}

function appendText(turn: AssistantTurn, event: MahayanaTurnEvent & { type: 'message.delta' }): void {
  const last = turn.parts.at(-1);
  if (last?.kind === 'text' && !last.sealed) {
    last.text += event.payload.text;
    return;
  }
  turn.parts.push({ kind: 'text', id: `text:${event.seq}`, seq: event.seq, text: event.payload.text, sealed: false });
}

function appendReasoning(turn: AssistantTurn, event: MahayanaTurnEvent & { type: 'reasoning.delta' }): void {
  const last = turn.parts.at(-1);
  if (last?.kind === 'reasoning' && !last.sealed) {
    last.text = event.payload.replace ? event.payload.text : `${last.text}${event.payload.text}`;
    return;
  }
  turn.parts.push({ kind: 'reasoning', id: `reasoning:${event.seq}`, seq: event.seq, text: event.payload.text, sealed: false });
}

function completeText(turn: AssistantTurn, text: string, seq: number): void {
  const lastText = [...turn.parts].reverse().find((part): part is AssistantTextPart => part.kind === 'text');
  if (lastText && !lastText.sealed) {
    if (text) lastText.text = text;
    lastText.sealed = true;
    return;
  }
  if (text) turn.parts.push({ kind: 'text', id: `text:${seq}:final`, seq, text, sealed: true });
}

export function reduceAssistantTurn(current: AssistantTurn | undefined, event: MahayanaTurnEvent): AssistantTurn {
  const turn = current ? cloneTurn(current) : createTurn(event);
  if (turn.turnId !== event.turnId || turn.operationId !== event.operationId || turn.sessionId !== event.sessionId) {
    throw new Error('Mahayana turn event coordinates do not match the projected assistant turn');
  }
  if (event.replayEpoch < turn.replayEpoch) return turn;
  if (event.replayEpoch === turn.replayEpoch && event.seq <= turn.lastSeq && current) return turn;
  if (event.replayEpoch > turn.replayEpoch) {
    turn.replayEpoch = event.replayEpoch;
  }

  switch (event.type) {
    case 'message.start':
      turn.model = event.payload.model ?? turn.model;
      turn.provider = event.payload.provider ?? turn.provider;
      turn.status = 'running';
      break;
    case 'message.delta':
      appendText(turn, event);
      turn.status = 'running';
      break;
    case 'message.interim':
      completeText(turn, event.payload.text, event.seq);
      sealStreamingParts(turn);
      break;
    case 'message.complete':
      completeText(turn, event.payload.text, event.seq);
      sealStreamingParts(turn);
      turn.status = event.payload.status ?? 'completed';
      turn.usage = event.payload.usage ?? turn.usage;
      break;
    case 'reasoning.delta':
      appendReasoning(turn, event);
      turn.status = 'running';
      break;
    case 'reasoning.available': {
      const lastReasoning = [...turn.parts].reverse().find((part): part is AssistantReasoningPart => part.kind === 'reasoning');
      if (lastReasoning && !lastReasoning.sealed) {
        lastReasoning.text = event.payload.text;
        lastReasoning.sealed = true;
      } else if (event.payload.text) {
        turn.parts.push({ kind: 'reasoning', id: `reasoning:${event.seq}:available`, seq: event.seq, text: event.payload.text, sealed: true });
      }
      break;
    }
    case 'tool.generating':
      sealStreamingParts(turn);
      upsertPart(
        turn,
        (part): part is AssistantToolPart => part.kind === 'tool' && part.toolId === event.payload.toolId,
        () => ({ kind: 'tool', id: `tool:${event.payload.toolId}`, seq: event.seq, toolId: event.payload.toolId, name: event.payload.name, title: event.payload.title, status: 'generating' }),
        (part) => { part.name = event.payload.name; part.title = event.payload.title ?? part.title; part.status = 'generating'; },
      );
      break;
    case 'tool.start':
      sealStreamingParts(turn);
      upsertPart(
        turn,
        (part): part is AssistantToolPart => part.kind === 'tool' && part.toolId === event.payload.toolId,
        () => ({ kind: 'tool', id: `tool:${event.payload.toolId}`, seq: event.seq, toolId: event.payload.toolId, name: event.payload.name, title: event.payload.title, arguments: event.payload.arguments, status: 'running' }),
        (part) => { part.name = event.payload.name; part.title = event.payload.title ?? part.title; part.arguments = event.payload.arguments ?? part.arguments; part.status = 'running'; },
      );
      break;
    case 'tool.progress':
      upsertPart(
        turn,
        (part): part is AssistantToolPart => part.kind === 'tool' && part.toolId === event.payload.toolId,
        () => ({ kind: 'tool', id: `tool:${event.payload.toolId}`, seq: event.seq, toolId: event.payload.toolId, name: event.payload.toolId, detail: event.payload.detail, progress: event.payload.progress, total: event.payload.total, status: 'running' }),
        (part) => { part.detail = event.payload.detail ?? part.detail; part.progress = event.payload.progress ?? part.progress; part.total = event.payload.total ?? part.total; },
      );
      break;
    case 'tool.complete':
      upsertPart(
        turn,
        (part): part is AssistantToolPart => part.kind === 'tool' && part.toolId === event.payload.toolId,
        () => ({ kind: 'tool', id: `tool:${event.payload.toolId}`, seq: event.seq, toolId: event.payload.toolId, name: event.payload.toolId, result: event.payload.result, error: event.payload.error, status: event.payload.error ? 'failed' : 'completed' }),
        (part) => { part.result = event.payload.result; part.error = event.payload.error; part.status = event.payload.error ? 'failed' : 'completed'; },
      );
      break;
    case 'approval.request':
      sealStreamingParts(turn);
      upsertPart(
        turn,
        (part): part is AssistantApprovalPart => part.kind === 'approval' && part.approvalId === event.payload.approvalId,
        () => ({ kind: 'approval', id: `approval:${event.payload.approvalId}`, seq: event.seq, approvalId: event.payload.approvalId, subject: event.payload.subject, detail: event.payload.detail, proposedRule: event.payload.proposedRule, metadata: event.payload.metadata }),
        (part) => { part.subject = event.payload.subject; part.detail = event.payload.detail ?? part.detail; part.proposedRule = event.payload.proposedRule ?? part.proposedRule; part.metadata = event.payload.metadata ?? part.metadata; },
      );
      break;
    case 'approval.resolve':
      upsertPart(
        turn,
        (part): part is AssistantApprovalPart => part.kind === 'approval' && part.approvalId === event.payload.approvalId,
        () => ({ kind: 'approval', id: `approval:${event.payload.approvalId}`, seq: event.seq, approvalId: event.payload.approvalId, subject: 'Approval', decision: event.payload.decision }),
        (part) => { part.decision = event.payload.decision; },
      );
      break;
    case 'clarify.request':
      sealStreamingParts(turn);
      upsertPart(
        turn,
        (part): part is AssistantClarifyPart => part.kind === 'clarify' && part.requestId === event.payload.requestId,
        () => ({ kind: 'clarify', id: `clarify:${event.payload.requestId}`, seq: event.seq, requestId: event.payload.requestId, prompt: event.payload.prompt, options: event.payload.options ?? [], metadata: event.payload.metadata, resolved: false }),
        (part) => { part.prompt = event.payload.prompt; part.options = event.payload.options ?? part.options; part.metadata = event.payload.metadata ?? part.metadata; },
      );
      break;
    case 'clarify.resolve':
      upsertPart(
        turn,
        (part): part is AssistantClarifyPart => part.kind === 'clarify' && part.requestId === event.payload.requestId,
        () => ({ kind: 'clarify', id: `clarify:${event.payload.requestId}`, seq: event.seq, requestId: event.payload.requestId, prompt: 'Clarification', options: [], value: event.payload.value, dismissed: event.payload.dismissed, resolved: true }),
        (part) => { part.value = event.payload.value; part.dismissed = event.payload.dismissed; part.resolved = true; },
      );
      break;
    case 'subagent.start':
      sealStreamingParts(turn);
      upsertPart(
        turn,
        (part): part is AssistantSubagentPart => part.kind === 'subagent' && part.subagentId === event.payload.subagentId,
        () => ({ kind: 'subagent', id: `subagent:${event.payload.subagentId}`, seq: event.seq, subagentId: event.payload.subagentId, label: event.payload.label, agentType: event.payload.agentType, status: 'running' }),
        (part) => { part.label = event.payload.label; part.agentType = event.payload.agentType ?? part.agentType; part.status = 'running'; },
      );
      break;
    case 'subagent.progress':
      upsertPart(
        turn,
        (part): part is AssistantSubagentPart => part.kind === 'subagent' && part.subagentId === event.payload.subagentId,
        () => ({ kind: 'subagent', id: `subagent:${event.payload.subagentId}`, seq: event.seq, subagentId: event.payload.subagentId, label: event.payload.subagentId, detail: event.payload.detail, status: 'running' }),
        (part) => { part.detail = event.payload.detail; },
      );
      break;
    case 'subagent.complete':
      upsertPart(
        turn,
        (part): part is AssistantSubagentPart => part.kind === 'subagent' && part.subagentId === event.payload.subagentId,
        () => ({ kind: 'subagent', id: `subagent:${event.payload.subagentId}`, seq: event.seq, subagentId: event.payload.subagentId, label: event.payload.subagentId, summary: event.payload.summary, result: event.payload.result, error: event.payload.error, status: event.payload.error ? 'failed' : 'completed' }),
        (part) => { part.summary = event.payload.summary; part.result = event.payload.result; part.error = event.payload.error; part.status = event.payload.error ? 'failed' : 'completed'; },
      );
      break;
    case 'artifact.available':
      sealStreamingParts(turn);
      upsertPart(
        turn,
        (part): part is AssistantArtifactPart => part.kind === 'artifact' && part.artifactId === event.payload.artifactId,
        () => ({ kind: 'artifact', id: `artifact:${event.payload.artifactId}`, seq: event.seq, artifactId: event.payload.artifactId, title: event.payload.title, artifactKind: event.payload.kind, uri: event.payload.uri, metadata: event.payload.metadata }),
        (part) => { part.title = event.payload.title; part.artifactKind = event.payload.kind; part.uri = event.payload.uri ?? part.uri; part.metadata = event.payload.metadata ?? part.metadata; },
      );
      break;
    case 'turn.error':
      sealStreamingParts(turn);
      turn.parts.push({ kind: 'error', id: `error:${event.seq}`, seq: event.seq, code: event.payload.code, message: event.payload.message, recoverable: event.payload.recoverable ?? false });
      turn.status = 'error';
      break;
  }

  turn.lastSeq = Math.max(turn.lastSeq, event.seq);
  turn.updatedAtMs = Math.max(turn.updatedAtMs, event.timestampMs);
  return turn;
}

export function reduceAssistantTurns(current: AssistantTurn[], event: MahayanaTurnEvent): AssistantTurn[] {
  const index = current.findIndex((turn) => turn.sessionId === event.sessionId && turn.turnId === event.turnId);
  if (index < 0) return [...current, reduceAssistantTurn(undefined, event)];
  return current.map((turn, turnIndex) => turnIndex === index ? reduceAssistantTurn(turn, event) : turn);
}

export type LegacyTurnCoordinates = {
  sessionId: string;
  conversationId?: string;
  seq: number;
  replayEpoch?: number;
  timestampMs?: number;
};

function legacyEnvelope(
  operationId: string,
  coordinates: LegacyTurnCoordinates,
  event: MahayanaTurnPayload,
): MahayanaTurnEvent {
  return {
    ...event,
    protocolVersion: MAHAYANA_TURN_PROTOCOL_VERSION,
    sessionId: coordinates.sessionId,
    conversationId: coordinates.conversationId,
    turnId: operationId,
    operationId,
    seq: coordinates.seq,
    replayEpoch: coordinates.replayEpoch ?? 0,
    timestampMs: coordinates.timestampMs ?? Date.now(),
  } as MahayanaTurnEvent;
}

/**
 * Compatibility bridge while legacy RuntimeEvent producers migrate into the
 * Rust turn protocol. It deliberately drops model-routing telemetry from the
 * primary transcript: routing remains inspector metadata, not a chat card.
 */
export function legacyRuntimeEventToTurnEvent(
  event: RuntimeEvent,
  coordinates: LegacyTurnCoordinates,
): MahayanaTurnEvent | null {
  if (event.type === 'operation.started') {
    return legacyEnvelope(event.operationId, coordinates, { type: 'message.start', payload: {} });
  }
  if (event.type === 'chat.delta') {
    return legacyEnvelope(event.operationId, coordinates, { type: 'message.delta', payload: { text: event.delta } });
  }
  if (event.type === 'chat.message' && event.role === 'assistant' && event.operationId) {
    return legacyEnvelope(event.operationId, coordinates, { type: 'message.complete', payload: { text: event.text, status: 'completed' } });
  }
  if (event.type === 'agent.step' && event.operationId) {
    if (event.status === 'running') {
      return legacyEnvelope(event.operationId, coordinates, {
        type: 'tool.start',
        payload: { toolId: event.stepId, name: event.kind || 'tool', title: event.title, arguments: event.detail ? { detail: event.detail } : undefined },
      });
    }
    return legacyEnvelope(event.operationId, coordinates, {
      type: 'tool.complete',
      payload: { toolId: event.stepId, result: event.status === 'completed' ? { detail: event.detail } : undefined, error: event.status === 'failed' ? event.detail || event.title : undefined },
    });
  }
  if (event.type === 'approval.requested') {
    const operationId = `approval:${event.approvalId}`;
    return legacyEnvelope(operationId, coordinates, {
      type: 'approval.request',
      payload: {
        approvalId: event.approvalId,
        subject: event.subject || event.capability || 'Approval required',
        detail: event.detail || event.reason,
        proposedRule: event.proposedRule,
        metadata: { miniAppId: event.miniAppId, capability: event.capability, kind: event.kind, location: event.location },
      },
    });
  }
  if (event.type === 'approval.resolved') {
    const operationId = `approval:${event.approvalId}`;
    return legacyEnvelope(operationId, coordinates, { type: 'approval.resolve', payload: { approvalId: event.approvalId, decision: event.decision } });
  }
  if (event.type === 'artifact.delivered' && event.operationId) {
    return legacyEnvelope(event.operationId, coordinates, {
      type: 'artifact.available',
      payload: { artifactId: event.artifact.id, title: event.artifact.title, kind: 'miniapp', metadata: event.artifact },
    });
  }
  if (event.type === 'operation.interrupted') {
    return legacyEnvelope(event.operationId, coordinates, { type: 'message.complete', payload: { text: '', status: 'interrupted' } });
  }
  if (event.type === 'operation.failed') {
    return legacyEnvelope(event.operationId, coordinates, { type: 'turn.error', payload: { code: event.code, message: event.message, recoverable: false } });
  }
  return null;
}
