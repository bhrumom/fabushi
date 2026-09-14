import {
  Bot,
  CheckCircle2,
  ChevronDown,
  FileText,
  LoaderCircle,
  ShieldAlert,
  Square,
  Terminal,
  XCircle,
} from 'lucide-react';
import React, { useEffect, useMemo, useReducer, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import type {
  ApprovalResolution,
  RuntimeEvent,
} from '../../frontend/apps/web/src/lib/mahayana-host/contracts';
import {
  MAHAYANA_COMMAND_EVENT_NAME,
  MAHAYANA_RUNTIME_EVENT_NAME,
  type MahayanaCommandBridgeDetail,
} from '../../frontend/apps/web/src/lib/mahayana-host/electron-transport';
import {
  agentWorkbenchReducer,
  type AgentApprovalProjection,
  type AgentCardProjection,
  type AgentObservationProjection,
  type AgentRunProjection,
  type AgentStepProjection,
  type AgentToolResultProjection,
  type AgentWorkbenchSnapshot,
} from './mahayana-agent-workbench';
import styles from './mahayana-agent-inline-report.module.css';

const STORAGE_KEY = 'fabushi.desktop.mahayana-agent-workbench.v1';
const REPORT_PORTAL_ID = 'mahayana-agent-inline-report-portal';

type ReducerAction = Parameters<typeof agentWorkbenchReducer>[1];

type ActivePeerContext = {
  key: string;
  agentId?: string;
  label?: string;
};

type TurnPart =
  | { type: 'message'; id: string; timestampMs: number; text: string }
  | { type: 'step'; id: string; timestampMs: number; step: AgentStepProjection }
  | { type: 'tool'; id: string; timestampMs: number; tool: AgentToolResultProjection }
  | { type: 'approval'; id: string; timestampMs: number; approval: AgentApprovalProjection }
  | { type: 'artifact'; id: string; timestampMs: number; card: AgentCardProjection }
  | { type: 'observation'; id: string; timestampMs: number; observation: AgentObservationProjection };

function emptySnapshot(): AgentWorkbenchSnapshot {
  return {
    version: 1,
    activeConversationKey: 'mahayana-assistant',
    knownBotIds: ['mahayana-assistant'],
    runs: [],
  };
}

function readSnapshot(): AgentWorkbenchSnapshot {
  if (typeof window === 'undefined') return emptySnapshot();
  try {
    const parsed = JSON.parse(window.localStorage.getItem(STORAGE_KEY) || 'null') as Partial<AgentWorkbenchSnapshot> | null;
    if (!parsed || parsed.version !== 1 || !Array.isArray(parsed.runs)) return emptySnapshot();
    return {
      version: 1,
      activeConversationKey: typeof parsed.activeConversationKey === 'string' && parsed.activeConversationKey
        ? parsed.activeConversationKey
        : 'mahayana-assistant',
      knownBotIds: Array.isArray(parsed.knownBotIds)
        ? parsed.knownBotIds.filter((id): id is string => typeof id === 'string')
        : ['mahayana-assistant'],
      runs: parsed.runs
        .filter((run): run is AgentRunProjection => Boolean(run && typeof run === 'object' && run.id))
        .map((run) => ({
          ...run,
          steps: Array.isArray(run.steps) ? run.steps : [],
          messages: Array.isArray(run.messages) ? run.messages : [],
          approvals: Array.isArray(run.approvals) ? run.approvals : [],
          cards: Array.isArray(run.cards) ? run.cards : [],
          observations: Array.isArray(run.observations) ? run.observations : [],
          toolResults: Array.isArray(run.toolResults) ? run.toolResults : [],
        })),
    };
  } catch {
    return emptySnapshot();
  }
}

function directBotMark(parent: HTMLElement): HTMLElement | null {
  return Array.from(parent.children).find((child) =>
    child instanceof HTMLElement && child.dataset.engine === 'fabushi-motion-v3',
  ) as HTMLElement | null;
}

function activePeerButton(): HTMLButtonElement | null {
  return Array.from(document.querySelectorAll<HTMLButtonElement>('button[data-testid^="peer-"]'))
    .find((button) => button.className.includes('peerActive')) || null;
}

function actorIdFromBotMark(botId: string | undefined): string | undefined {
  if (!botId) return undefined;
  const prefix = ['peer:bot:', 'peer:agent:'].find((candidate) => botId.startsWith(candidate));
  return prefix ? botId.slice(prefix.length) || undefined : undefined;
}

function contextFromActivePeer(): ActivePeerContext | null {
  const button = activePeerButton();
  const testId = button?.getAttribute('data-testid') || '';
  if (!button || !testId.startsWith('peer-')) return null;
  const rawKey = testId.slice('peer-'.length);
  const mark = directBotMark(button);
  const agentId = actorIdFromBotMark(mark?.dataset.botId);
  const label = mark?.getAttribute('aria-label') || button.textContent?.trim() || undefined;

  if (rawKey.startsWith('legacy:conversation:')) {
    return { key: rawKey.slice('legacy:conversation:'.length), agentId, label };
  }
  if (rawKey.startsWith('selfhosted:')) return { key: rawKey, agentId, label };
  if (rawKey.startsWith('legacy:bot:') || rawKey.startsWith('account:bot:')) {
    return { key: agentId || rawKey.split(':').slice(2).join(':'), agentId, label };
  }
  return { key: rawKey, agentId, label };
}

function runForPeer(runs: AgentRunProjection[], peer: ActivePeerContext | null): AgentRunProjection | undefined {
  if (!peer) return undefined;
  const reversed = [...runs].reverse();
  return reversed.find((run) => run.conversationKey === peer.key)
    || (peer.agentId ? reversed.find((run) => run.agentId === peer.agentId) : undefined);
}

function latestAssistantMessage(run: AgentRunProjection) {
  return [...run.messages].reverse().find((message) => message.role === 'assistant' && message.text.trim());
}

function peerMessageArticles(messageArea: HTMLElement): HTMLElement[] {
  return Array.from(messageArea.children).filter((child): child is HTMLElement =>
    child instanceof HTMLElement && child.tagName === 'ARTICLE' && child.className.includes('messagePeer'),
  );
}

function matchingAssistantArticle(messageArea: HTMLElement, run: AgentRunProjection | undefined): HTMLElement | null {
  if (!run) return null;
  const targetText = latestAssistantMessage(run)?.text.trim() || '';
  if (!targetText) return null;
  const normalizedTarget = targetText.replace(/\s+/gu, ' ').trim();
  return peerMessageArticles(messageArea).reverse().find((article) => {
    const text = article.querySelector('p')?.textContent?.replace(/\s+/gu, ' ').trim() || '';
    return text === normalizedTarget
      || (normalizedTarget.length > 80 && text.startsWith(normalizedTarget.slice(0, 80)));
  }) || null;
}

function ensurePortal(messageArea: HTMLElement | null, before: HTMLElement | null): HTMLElement | null {
  const existing = document.getElementById(REPORT_PORTAL_ID);
  if (!messageArea) {
    existing?.remove();
    return null;
  }
  const root = existing || document.createElement('div');
  root.id = REPORT_PORTAL_ID;
  if (root.className !== styles.portalRoot) root.className = styles.portalRoot;
  if (root.parentElement !== messageArea || (before && root.nextElementSibling !== before)) {
    messageArea.insertBefore(root, before);
  }
  return root;
}

function setFinalOutputArticle(article: HTMLElement | null): void {
  document.querySelectorAll<HTMLElement>('[data-agent-final-output="true"]').forEach((element) => {
    if (element !== article) delete element.dataset.agentFinalOutput;
  });
  if (article) article.dataset.agentFinalOutput = 'true';
}

function jsonPreview(value: unknown): string {
  try {
    const text = JSON.stringify(value, null, 2);
    return text.length > 1600 ? `${text.slice(0, 1600)}\n…` : text;
  } catch {
    return String(value);
  }
}

function visibleStep(step: AgentStepProjection): boolean {
  // Routing and runtime bookkeeping remain available in the diagnostic event
  // stream but are not assistant prose. Hermes-style chat surfaces only the
  // work that helps a user follow the turn.
  return step.kind !== 'model' && step.kind !== 'runtime';
}

function stepTitle(step: AgentStepProjection): string {
  if (step.kind === 'plan' && step.title === 'Mahayana 已接管任务') return '正在思考';
  return step.title;
}

function turnParts(run: AgentRunProjection): TurnPart[] {
  const finalAssistantId = latestAssistantMessage(run)?.id;
  const parts: TurnPart[] = [
    ...run.messages
      .filter((message) => message.role === 'assistant' && message.id !== finalAssistantId && message.text.trim())
      .map((message): TurnPart => ({
        type: 'message',
        id: `message:${message.id}`,
        timestampMs: message.createdAtMs,
        text: message.text,
      })),
    ...run.steps
      .filter(visibleStep)
      .map((step): TurnPart => ({
        type: 'step',
        id: `step:${step.id}`,
        timestampMs: step.startedAtMs,
        step,
      })),
    ...run.toolResults.map((tool): TurnPart => ({
      type: 'tool',
      id: `tool:${tool.id}`,
      timestampMs: tool.createdAtMs,
      tool,
    })),
    ...run.approvals.map((approval): TurnPart => ({
      type: 'approval',
      id: `approval:${approval.approvalId}`,
      timestampMs: approval.requestedAtMs,
      approval,
    })),
    ...run.cards.map((card): TurnPart => ({
      type: 'artifact',
      id: `artifact:${card.id}`,
      timestampMs: card.createdAtMs,
      card,
    })),
    ...run.observations.map((observation): TurnPart => ({
      type: 'observation',
      id: `observation:${observation.kind}:${observation.id}`,
      timestampMs: run.updatedAtMs,
      observation,
    })),
  ];
  return parts.sort((left, right) => left.timestampMs - right.timestampMs);
}

function StepIcon({ status }: { status: AgentStepProjection['status'] }) {
  if (status === 'completed') return <CheckCircle2 size={14} />;
  if (status === 'failed') return <XCircle size={14} />;
  return <LoaderCircle className={styles.spin} size={14} />;
}

function TurnPartView({
  part,
  onResolveApproval,
}: {
  part: TurnPart;
  onResolveApproval: (approvalId: string, decision: ApprovalResolution['decision']) => void;
}) {
  if (part.type === 'message') {
    return <p className={styles.assistantSegment} data-testid="agent-inline-message-part">{part.text}</p>;
  }

  if (part.type === 'step') {
    const { step } = part;
    return (
      <div className={styles.partRow} data-testid="agent-inline-step" data-status={step.status} data-kind={step.kind}>
        <span className={styles.partIcon}><StepIcon status={step.status} /></span>
        <div className={styles.partCopy}>
          <strong>{stepTitle(step)}</strong>
          {step.detail ? <small>{step.detail}</small> : null}
          {typeof step.progress === 'number' && typeof step.total === 'number' && step.total > 0 ? (
            <span className={styles.progress} aria-label={`${step.progress}/${step.total}`}>
              <i style={{ width: `${Math.min(100, Math.max(0, (step.progress / step.total) * 100))}%` }} />
            </span>
          ) : null}
        </div>
      </div>
    );
  }

  if (part.type === 'tool') {
    return (
      <div className={styles.partRow} data-testid="agent-inline-tool" data-status="completed" data-kind="tool">
        <span className={styles.partIcon}><CheckCircle2 size={14} /></span>
        <details className={styles.toolDetail}>
          <summary>
            <Terminal size={13} />
            <strong>{part.tool.tool}</strong>
            <span>{part.tool.server}</span>
            <ChevronDown size={12} />
          </summary>
          <pre>{jsonPreview(part.tool.result)}</pre>
        </details>
      </div>
    );
  }

  if (part.type === 'approval') {
    const approval = part.approval;
    return (
      <div className={styles.partRow} data-testid="agent-inline-approval" data-status={approval.decision ? 'completed' : 'running'} data-kind="approval">
        <span className={styles.partIcon}><ShieldAlert size={14} /></span>
        <div className={styles.partCopy}>
          <strong>{approval.subject || approval.capability}</strong>
          <small>{approval.detail || approval.reason}</small>
          {approval.proposedRule ? <code>{approval.proposedRule}</code> : null}
          {approval.decision ? <em>已处理 · {approval.decision}</em> : (
            <span className={styles.approvalActions}>
              <button type="button" onClick={() => onResolveApproval(approval.approvalId, 'allow-once')}>仅本次允许</button>
              <button type="button" onClick={() => onResolveApproval(approval.approvalId, 'allow-session')}>本会话允许</button>
              <button type="button" onClick={() => onResolveApproval(approval.approvalId, 'deny')}>拒绝</button>
            </span>
          )}
        </div>
      </div>
    );
  }

  if (part.type === 'observation') {
    return (
      <div className={styles.partRow} data-testid="agent-inline-observation" data-status={part.observation.status || 'running'} data-kind={part.observation.kind}>
        <span className={styles.partIcon}><Bot size={14} /></span>
        <div className={styles.partCopy}>
          <strong>{part.observation.label}</strong>
          {part.observation.detail ? <small>{part.observation.detail}</small> : null}
        </div>
      </div>
    );
  }

  return (
    <div className={styles.partRow} data-testid="agent-inline-artifact" data-status="completed" data-kind="artifact">
      <span className={styles.partIcon}><FileText size={14} /></span>
      <details className={styles.toolDetail}>
        <summary>
          <FileText size={13} />
          <strong>生成交付物</strong>
          <span>{part.card.card.kind}</span>
          <ChevronDown size={12} />
        </summary>
        <pre>{jsonPreview(part.card.card)}</pre>
      </details>
    </div>
  );
}

function AssistantTurnParts({ run }: { run: AgentRunProjection }) {
  const [actionError, setActionError] = useState<string | null>(null);
  const parts = useMemo(() => turnParts(run), [run]);
  const active = run.status === 'queued' || run.status === 'running' || run.status === 'waiting-for-approval';

  const interrupt = () => {
    if (!run.operationId || !window.mahayana?.invoke) return;
    setActionError(null);
    void window.mahayana.invoke<void>('feature.interrupt', { operationId: run.operationId })
      .catch((error) => setActionError(error instanceof Error ? error.message : String(error)));
  };

  const resolveApproval = (approvalId: string, decision: ApprovalResolution['decision']) => {
    if (!window.mahayana?.invoke) return;
    setActionError(null);
    void window.mahayana.invoke<void>('feature.approval.resolve', { resolution: { approvalId, decision } })
      .catch((error) => setActionError(error instanceof Error ? error.message : String(error)));
  };

  return (
    <section
      className={styles.turnParts}
      data-testid="agent-inline-report"
      data-agent-transcript-parts="true"
      data-status={run.status}
      data-run-id={run.id}
    >
      <div className={styles.partFeed} data-testid="agent-inline-feed">
        {parts.map((part) => <TurnPartView key={part.id} part={part} onResolveApproval={resolveApproval} />)}
        {!parts.length && active ? (
          <div className={styles.partRow} data-testid="agent-inline-step" data-status="running" data-kind="thinking">
            <span className={styles.partIcon}><LoaderCircle className={styles.spin} size={14} /></span>
            <div className={styles.partCopy}><strong>正在思考</strong></div>
          </div>
        ) : null}
      </div>
      {run.error ? <div className={styles.error}><XCircle size={14} /><span>{run.error}</span></div> : null}
      {actionError ? <div className={styles.error}><XCircle size={14} /><span>{actionError}</span></div> : null}
      {active && run.interruptible && run.operationId ? (
        <button type="button" className={styles.stopButton} data-testid="agent-inline-stop" onClick={interrupt}>
          <Square size={11} />停止
        </button>
      ) : null}
    </section>
  );
}

export default function MahayanaAgentInlineReport() {
  const [snapshot, dispatch] = useReducer(
    (state: AgentWorkbenchSnapshot, action: ReducerAction) => agentWorkbenchReducer(state, action),
    undefined,
    readSnapshot,
  );
  const [peer, setPeer] = useState<ActivePeerContext | null>(null);
  const [portal, setPortal] = useState<HTMLElement | null>(null);
  const snapshotRef = useRef(snapshot);
  snapshotRef.current = snapshot;

  useEffect(() => {
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot));
    } catch {
      // The native durable-state bridge remains authoritative when storage is unavailable.
    }
  }, [snapshot]);

  useEffect(() => {
    const onCommand = (event: Event) => {
      const detail = (event as CustomEvent<MahayanaCommandBridgeDetail>).detail;
      if (detail) dispatch({ type: 'bridge-command', detail });
    };
    const onRuntime = (event: Event) => {
      const detail = (event as CustomEvent<RuntimeEvent>).detail;
      if (detail) dispatch({ type: 'runtime-event', event: detail });
    };
    window.addEventListener(MAHAYANA_COMMAND_EVENT_NAME, onCommand);
    window.addEventListener(MAHAYANA_RUNTIME_EVENT_NAME, onRuntime);
    return () => {
      window.removeEventListener(MAHAYANA_COMMAND_EVENT_NAME, onCommand);
      window.removeEventListener(MAHAYANA_RUNTIME_EVENT_NAME, onRuntime);
    };
  }, []);

  useEffect(() => {
    let disposed = false;
    const refresh = () => {
      if (disposed) return;
      const nextPeer = contextFromActivePeer();
      setPeer((current) => current?.key === nextPeer?.key && current?.agentId === nextPeer?.agentId && current?.label === nextPeer?.label ? current : nextPeer);
      const workspace = document.querySelector<HTMLElement>('[data-testid="messenger-workspace"]');
      const messageArea = workspace?.querySelector<HTMLElement>('[class*="messageArea"]') || null;
      const selectedRun = runForPeer(snapshotRef.current.runs, nextPeer);
      const assistantArticle = messageArea ? matchingAssistantArticle(messageArea, selectedRun) : null;
      setFinalOutputArticle(assistantArticle);
      const root = ensurePortal(messageArea, assistantArticle);
      setPortal((current) => current === root ? current : root);
    };

    const observer = new MutationObserver((records) => {
      const relevant = records.some((record) => {
        if (record.type === 'attributes') {
          return record.attributeName === 'class' && (record.target as HTMLElement).id !== REPORT_PORTAL_ID;
        }
        if (record.type !== 'childList') return false;
        return [...record.addedNodes, ...record.removedNodes]
          .some((node) => !(node instanceof HTMLElement) || node.id !== REPORT_PORTAL_ID);
      });
      if (relevant) refresh();
    });
    observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['class'] });
    const interval = window.setInterval(refresh, 750);
    refresh();
    return () => {
      disposed = true;
      observer.disconnect();
      window.clearInterval(interval);
      document.getElementById(REPORT_PORTAL_ID)?.remove();
      setFinalOutputArticle(null);
    };
  }, []);

  useEffect(() => {
    const workspace = document.querySelector<HTMLElement>('[data-testid="messenger-workspace"]');
    const messageArea = workspace?.querySelector<HTMLElement>('[class*="messageArea"]') || null;
    const selectedRun = runForPeer(snapshot.runs, peer);
    const assistantArticle = messageArea ? matchingAssistantArticle(messageArea, selectedRun) : null;
    setFinalOutputArticle(assistantArticle);
    const root = ensurePortal(messageArea, assistantArticle);
    if (root !== portal) setPortal(root);
  }, [peer, portal, snapshot.runs]);

  const run = useMemo(() => runForPeer(snapshot.runs, peer), [peer, snapshot.runs]);
  if (!portal || !run) return null;
  return createPortal(<AssistantTurnParts run={run} />, portal);
}
