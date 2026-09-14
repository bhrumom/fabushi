from __future__ import annotations

import re
from pathlib import Path

PATH = Path("desktop/src/messaging-shell-v2.tsx")
source = PATH.read_text(encoding="utf-8")


def replace_once(old: str, new: str, label: str) -> None:
    global source
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    source = source.replace(old, new, 1)


def replace_regex(pattern: str, replacement: str, label: str) -> None:
    global source
    source, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")


replace_once(
    "import {\n  SidebarContactGroupManager,\n  projectSidebarContactGroups,\n  useSidebarContactGroups,\n} from './sidebar-contact-groups';\n",
    "import {\n  SidebarContactGroupManager,\n  projectSidebarContactGroups,\n  useSidebarContactGroups,\n} from './sidebar-contact-groups';\n"
    "import { MahayanaAssistantTurnView } from './mahayana-assistant-turn-view';\n"
    "import {\n  assistantTurnPlainText,\n  createAssistantTurn,\n  reduceAssistantTurn,\n  type AssistantTurn,\n} from './mahayana-assistant-turn';\n",
    "assistant turn imports",
)

replace_once(
    "  kind?: 'message' | 'action' | 'thinking';\n",
    "  kind?: 'message' | 'assistant-turn' | 'action' | 'thinking';\n",
    "display message kind",
)
replace_once(
    "  actionStatus?: 'running' | 'completed' | 'failed';\n",
    "  actionStatus?: 'running' | 'completed' | 'failed';\n  assistantTurn?: AssistantTurn;\n",
    "assistant turn payload",
)

helpers = r'''  function clearAgentOperation\(operationId: string, terminalStatus: 'completed' \| 'failed' = 'completed'\) \{.*?\n  function showSelfConversation'''
replacement_helpers = '''  function clearAgentOperation(operationId: string) {
    if (agentOperationIdRef.current !== operationId) return;
    agentOperationIdRef.current = null;
    setAgentOperationId(null);
    agentRequestPendingRef.current = false;
  }

  function appendAssistantTurnEvent(event: RuntimeEvent) {
    const operationId = 'operationId' in event && typeof event.operationId === 'string'
      ? event.operationId
      : undefined;
    if (!operationId) return;
    setMessages((current) => {
      const index = current.findIndex((message) =>
        message.kind === 'assistant-turn' && message.operationId === operationId,
      );
      const existingTurn = index >= 0 ? current[index]?.assistantTurn : undefined;
      const assistantTurn = reduceAssistantTurn(existingTurn ?? createAssistantTurn(operationId), event);
      const next: DisplayMessage = {
        id: `${operationId}:assistant-turn`,
        source: 'legacy',
        role: 'peer',
        text: assistantTurnPlainText(assistantTurn),
        createdAtMs: assistantTurn.createdAtMs,
        kind: 'assistant-turn',
        operationId,
        streaming: assistantTurn.status === 'running',
        assistantTurn,
      };
      if (index < 0) return [...current, next];
      return current.map((message, messageIndex) => messageIndex === index ? next : message);
    });
  }

  function showSelfConversation'''
replace_regex(helpers, replacement_helpers, "legacy split-row helpers")

chat_message = r'''      case 'chat\.message':.*?\n      case 'chat\.delta':'''
replacement_chat_message = '''      case 'chat.message':
        if (event.role === 'assistant' && event.operationId && claimAgentOperation(event.operationId)) {
          appendAssistantTurnEvent(event);
          break;
        }
        setMessages((current) => {
          if (event.role === 'user') {
            const optimisticIndex = current.findIndex((message) =>
              message.role === 'me' && message.optimistic === true && message.text === event.text,
            );
            if (optimisticIndex >= 0) {
              return current.map((message, messageIndex) => messageIndex === optimisticIndex
                ? { ...message, optimistic: false, operationId: event.operationId ?? message.operationId }
                : message);
            }
            if (current.some((message) =>
              message.role === 'me' && message.text === event.text &&
              (!event.operationId || message.operationId === event.operationId))) return current;
          }
          return [...current, {
            id: nextRequestId('message'),
            source: 'legacy',
            role: event.role === 'user' ? 'me' : 'peer',
            text: event.text,
            createdAtMs: Date.now(),
            kind: 'message',
            operationId: event.operationId,
            streaming: false,
          }];
        });
        break;
      case 'chat.delta':'''
replace_regex(chat_message, replacement_chat_message, "chat.message projection")

chat_delta = r'''      case 'chat\.delta':.*?\n      case 'operation\.started':'''
replacement_chat_delta = '''      case 'chat.delta':
        if (claimAgentOperation(event.operationId)) {
          appendAssistantTurnEvent(event);
          break;
        }
        setMessages((current) => {
          const index = current.findIndex((message) => message.kind === 'message' && message.operationId === event.operationId && message.streaming);
          if (index < 0) return [...current, { id: `${event.operationId}:stream`, source: 'legacy', role: 'peer', text: event.delta, createdAtMs: Date.now(), kind: 'message', operationId: event.operationId, streaming: true }];
          return current.map((message, messageIndex) => messageIndex === index ? { ...message, text: `${message.text}${event.delta}`, kind: 'message', streaming: true } : message);
        });
        break;
      case 'operation.started':'''
replace_regex(chat_delta, replacement_chat_delta, "chat.delta projection")

operation_started = r'''      case 'operation\.started':.*?\n      case 'model\.routed':'''
replacement_operation_started = '''      case 'operation.started':
        if (claimAgentOperation(event.operationId)) {
          setPendingSend(true);
          appendAssistantTurnEvent(event);
        }
        break;
      case 'model.routed':'''
replace_regex(operation_started, replacement_operation_started, "operation.started projection")

model_routed = r'''      case 'model\.routed':.*?\n      case 'agent\.step':'''
replacement_model_routed = '''      case 'model.routed':
        if (claimAgentOperation(event.operationId)) appendAssistantTurnEvent(event);
        break;
      case 'agent.step':'''
replace_regex(model_routed, replacement_model_routed, "model.routed metadata projection")

agent_step = r'''      case 'agent\.step':.*?\n      case 'operation\.interrupted':'''
replacement_agent_step = '''      case 'agent.step':
        if (claimAgentOperation(event.operationId)) appendAssistantTurnEvent(event);
        break;
      case 'operation.interrupted':'''
replace_regex(agent_step, replacement_agent_step, "agent.step projection")

operation_interrupted = r'''      case 'operation\.interrupted':.*?\n      case 'operation\.completed':'''
replacement_operation_interrupted = '''      case 'operation.interrupted':
        if (agentOperationIdRef.current === event.operationId) appendAssistantTurnEvent(event);
        clearAgentOperation(event.operationId);
        setPendingSend(false);
        break;
      case 'operation.completed':'''
replace_regex(operation_interrupted, replacement_operation_interrupted, "operation.interrupted projection")

operation_completed = r'''      case 'operation\.completed':.*?\n      case 'miniapp\.opened':'''
replacement_operation_completed = '''      case 'operation.completed':
        if (agentOperationIdRef.current === event.operationId) appendAssistantTurnEvent(event);
        clearAgentOperation(event.operationId);
        setPendingSend(false);
        break;
      case 'miniapp.opened':'''
replace_regex(operation_completed, replacement_operation_completed, "operation.completed projection")

operation_failed = r'''      case 'operation\.failed':.*?\n      case 'host\.closed':'''
replacement_operation_failed = '''      case 'operation.failed':
        if (agentOperationIdRef.current === event.operationId) appendAssistantTurnEvent(event);
        clearAgentOperation(event.operationId);
        setPendingSend(false);
        setError(event.message);
        break;
      case 'host.closed':'''
replace_regex(operation_failed, replacement_operation_failed, "operation.failed projection")

replace_once(
    "          appendAgentThinking(accepted.operationId, '正在思考');\n",
    "          appendAssistantTurnEvent({ type: 'operation.started', timestamp: new Date().toISOString(), operationId: accepted.operationId, label: '正在思考', interruptible: true });\n",
    "optimistic assistant turn",
)

render_pattern = r'''              \{renderedMessages\.map\(\(message\) => message\.kind === 'thinking' \? \(.*?              \)\)\}\n              \{!matchingMessages\.length \?'''
render_replacement = '''              {renderedMessages.map((message) => message.kind === 'assistant-turn' && message.assistantTurn ? (
                <MahayanaAssistantTurnView
                  key={`${message.source}:${message.id}`}
                  turn={message.assistantTurn}
                  label={activePeer.title}
                  avatar={<BotMark
                    botId={`peer:${activePeer.kind}:${activePeer.actorId ?? activePeer.id}`}
                    state={message.assistantTurn.status === 'running' ? 'thinking' : message.assistantTurn.status === 'failed' ? 'error' : 'result'}
                    size={30}
                    className={styles.agentStreamAvatar}
                    label={activePeer.title}
                  />}
                />
              ) : (
                <article
                  key={`${message.source}:${message.id}`}
                  className={message.role === 'me' ? styles.messageMine : styles.messagePeer}
                  data-agent-id={`message-actions:${message.source}:${message.id}`}
                  data-agent-invoke="contextmenu"
                  data-agent-message-role={message.role}
                  onContextMenu={(event) => {
                    if (message.kind === 'assistant-turn' || message.kind === 'action' || message.kind === 'thinking') return;
                    event.preventDefault();
                    event.stopPropagation();
                    setMessageMenu({ message, x: event.clientX, y: event.clientY });
                  }}
                >
                  {message.pinned ? <Pin size={11} /> : null}
                  {message.mediaType === 'photo' && blobMediaUrl(message.media) ? <img className={extra.messageMedia} src={blobMediaUrl(message.media)} alt={message.media?.fileName ?? '图片'} /> : null}
                  {message.mediaType === 'video' && blobMediaUrl(message.media) ? <video className={extra.messageMedia} controls playsInline autoPlay={desktopPreferences.autoPlayMedia} src={blobMediaUrl(message.media)} /> : null}
                  {message.mediaType === 'document' && blobMediaUrl(message.media) ? <a className={extra.messageFile} href={blobMediaUrl(message.media)} download={message.media?.fileName}><FileText size={17} />{message.media?.fileName ?? '文件'}</a> : null}
                  <p>{message.text}</p>
                  {message.reactions?.length ? <div className={extra.reactions}>{message.reactions.map((reaction) => <span key={reaction}>{reaction}</span>)}</div> : null}
                  <small>{formatTime(message.createdAtMs)} {message.role === 'me' ? <Check size={12} /> : null}</small>
                </article>
              ))}
              {!matchingMessages.length ?'''
replace_regex(render_pattern, render_replacement, "message transcript renderer")

if "appendAgentThinking" in source or "upsertAgentAction" in source:
    raise SystemExit("legacy split agent row helpers remain after migration")
if "MahayanaAssistantTurnView" not in source or "kind: 'assistant-turn'" not in source:
    raise SystemExit("assistant turn migration markers missing")

PATH.write_text(source, encoding="utf-8")
