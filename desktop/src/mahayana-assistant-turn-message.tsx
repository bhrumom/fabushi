import type {
  AssistantApprovalPart,
  AssistantArtifactPart,
  AssistantClarifyPart,
  AssistantErrorPart,
  AssistantReasoningPart,
  AssistantSubagentPart,
  AssistantTextPart,
  AssistantToolPart,
  AssistantTurn,
  AssistantTurnPart,
} from '../../frontend/apps/web/src/lib/mahayana-host/turn-transcript';
import styles from './mahayana-assistant-turn-message.module.css';

type Props = {
  turn: AssistantTurn;
};

function textPart(part: AssistantTextPart) {
  return (
    <div className={styles.text} data-testid="mahayana-turn-text" data-part-id={part.id}>
      {part.text}
    </div>
  );
}

function reasoningPart(part: AssistantReasoningPart) {
  return (
    <details className={styles.reasoning} data-testid="mahayana-turn-reasoning" data-part-id={part.id} open={!part.sealed}>
      <summary>{part.sealed ? '思考过程' : '思考中…'}</summary>
      <div>{part.text}</div>
    </details>
  );
}

function toolPart(part: AssistantToolPart) {
  const statusLabel = part.status === 'running'
    ? '运行中'
    : part.status === 'generating'
      ? '准备中'
      : part.status === 'failed'
        ? '失败'
        : '完成';
  return (
    <div
      className={styles.tool}
      data-testid="mahayana-turn-tool"
      data-part-id={part.id}
      data-tool-id={part.toolId}
      data-status={part.status}
    >
      <span className={styles.toolIndicator} aria-hidden="true">●</span>
      <span className={styles.toolTitle}>{part.title || part.name}</span>
      <span className={styles.status}>{statusLabel}</span>
      {part.detail ? <span className={styles.detail}>{part.detail}</span> : null}
      {part.error ? <span className={styles.error}>{part.error}</span> : null}
    </div>
  );
}

function approvalPart(part: AssistantApprovalPart) {
  return (
    <div className={styles.request} data-testid="mahayana-turn-approval" data-part-id={part.id} data-resolved={Boolean(part.decision)}>
      <strong>{part.subject}</strong>
      {part.detail ? <span>{part.detail}</span> : null}
      {part.decision ? <span className={styles.status}>{part.decision}</span> : <span className={styles.status}>等待授权</span>}
    </div>
  );
}

function clarifyPart(part: AssistantClarifyPart) {
  return (
    <div className={styles.request} data-testid="mahayana-turn-clarify" data-part-id={part.id} data-resolved={part.resolved}>
      <strong>{part.prompt}</strong>
      {part.options.length > 0 ? <span>{part.options.join(' · ')}</span> : null}
      <span className={styles.status}>{part.resolved ? '已回答' : '等待回答'}</span>
    </div>
  );
}

function subagentPart(part: AssistantSubagentPart) {
  return (
    <div className={styles.tool} data-testid="mahayana-turn-subagent" data-part-id={part.id} data-status={part.status}>
      <span className={styles.toolIndicator} aria-hidden="true">◇</span>
      <span className={styles.toolTitle}>{part.label}</span>
      <span className={styles.status}>{part.status === 'running' ? '工作中' : part.status === 'failed' ? '失败' : '完成'}</span>
      {part.detail ? <span className={styles.detail}>{part.detail}</span> : null}
      {part.summary ? <span className={styles.detail}>{part.summary}</span> : null}
      {part.error ? <span className={styles.error}>{part.error}</span> : null}
    </div>
  );
}

function artifactPart(part: AssistantArtifactPart) {
  return (
    <div className={styles.artifact} data-testid="mahayana-turn-artifact" data-part-id={part.id}>
      <span aria-hidden="true">↗</span>
      {part.uri ? <a href={part.uri}>{part.title}</a> : <span>{part.title}</span>}
      <span className={styles.status}>{part.artifactKind}</span>
    </div>
  );
}

function errorPart(part: AssistantErrorPart) {
  return (
    <div className={styles.error} role="alert" data-testid="mahayana-turn-error" data-part-id={part.id}>
      {part.message}
      {part.recoverable ? <span className={styles.status}>可恢复</span> : null}
    </div>
  );
}

function renderPart(part: AssistantTurnPart) {
  switch (part.kind) {
    case 'text':
      return textPart(part);
    case 'reasoning':
      return reasoningPart(part);
    case 'tool':
      return toolPart(part);
    case 'approval':
      return approvalPart(part);
    case 'clarify':
      return clarifyPart(part);
    case 'subagent':
      return subagentPart(part);
    case 'artifact':
      return artifactPart(part);
    case 'error':
      return errorPart(part);
  }
}

export default function MahayanaAssistantTurnMessage({ turn }: Props) {
  return (
    <article
      className={styles.turn}
      data-testid="mahayana-assistant-turn"
      data-turn-id={turn.turnId}
      data-operation-id={turn.operationId}
      data-status={turn.status}
      data-replay-epoch={turn.replayEpoch}
    >
      <div className={styles.identity} aria-label="Mahayana">
        <span className={styles.avatar} aria-hidden="true">M</span>
        <span>Mahayana</span>
      </div>
      <div className={styles.parts}>
        {turn.parts.map((part) => <div key={part.id} className={styles.part}>{renderPart(part)}</div>)}
        {turn.status === 'running' && turn.parts.length === 0 ? <span className={styles.status}>思考中…</span> : null}
      </div>
    </article>
  );
}
