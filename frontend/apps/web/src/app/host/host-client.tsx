import {
  mahayanaHostFeatures,
  type MahayanaHostFeatureId,
  type MahayanaHostFeatureState,
} from "@fabushi/shared";
import React, {
  useEffect,
  useMemo,
  useRef,
  useState,
  type FormEvent,
} from "react";
import styles from "./host.module.css";
import type {
  ApprovalRequestedEvent,
  RuntimeCommand,
} from "../../lib/mahayana-host/contracts";
import { MockMahayanaHostTransport } from "../../lib/mahayana-host/mock-transport";
import { isTauriMahayanaHostAvailable } from "../../lib/mahayana-host/tauri-transport";
import type { MahayanaHostTransport } from "../../lib/mahayana-host/transport";

const miniAppId = "global-dharma";

type FeatureStates = Record<
  MahayanaHostFeatureId,
  MahayanaHostFeatureState
>;

function createInitialFeatureStates(): FeatureStates {
  return Object.fromEntries(
    mahayanaHostFeatures.map((feature) => [feature.id, "pending"]),
  ) as FeatureStates;
}

export default function HostClient() {
  const transport = useMemo<MahayanaHostTransport>(
    () => new MockMahayanaHostTransport(),
    [],
  );
  const requestSequence = useRef(0);
  const [hostStatus, setHostStatus] = useState("initializing");
  const [input, setInput] = useState("");
  const [messages, setMessages] = useState<
    Array<{
      role: "user" | "assistant";
      text: string;
      operationId?: string;
    }>
  >([]);
  const [marketplaceState, setMarketplaceState] = useState("not-installed");
  const [openedMiniApp, setOpenedMiniApp] = useState<string | null>(null);
  const [approval, setApproval] = useState<ApprovalRequestedEvent | null>(null);
  const [approvalState, setApprovalState] = useState("not-requested");
  const [activeOperationId, setActiveOperationId] = useState<string | null>(null);
  const [operationState, setOperationState] = useState("idle");
  const [sessionState, setSessionState] = useState("active");
  const [featureStates, setFeatureStates] = useState<FeatureStates>(
    createInitialFeatureStates,
  );
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const pass = (featureId: MahayanaHostFeatureId) => {
      setFeatureStates((current) => ({
        ...current,
        [featureId]: "passed",
      }));
    };

    const unsubscribe = transport.subscribe((event) => {
      switch (event.type) {
        case "host.ready":
          setHostStatus("ready");
          pass("runtime.boot");
          break;
        case "chat.message":
          setMessages((current) => {
            if (event.role === "assistant" && event.operationId) {
              const index = current.findIndex(
                (message) => message.operationId === event.operationId,
              );
              if (index >= 0) {
                return current.map((message, messageIndex) =>
                  messageIndex === index
                    ? { ...message, text: event.text }
                    : message,
                );
              }
            }
            return [
              ...current,
              {
                role: event.role,
                text: event.text,
                operationId: event.operationId,
              },
            ];
          });
          if (event.role === "assistant") pass("chat.send");
          break;
        case "chat.delta":
          setMessages((current) => {
            const index = current.findIndex(
              (message) => message.operationId === event.operationId,
            );
            if (index < 0) {
              return [
                ...current,
                {
                  role: "assistant",
                  text: event.delta,
                  operationId: event.operationId,
                },
              ];
            }
            return current.map((message, messageIndex) =>
              messageIndex === index
                ? { ...message, text: `${message.text}${event.delta}` }
                : message,
            );
          });
          break;
        case "marketplace.installed":
          setMarketplaceState("installed");
          pass("marketplace.install");
          break;
        case "miniapp.opened":
          setOpenedMiniApp(event.miniAppId);
          pass("miniapp.open");
          break;
        case "approval.requested":
          setApproval(event);
          setApprovalState("pending");
          break;
        case "approval.resolved":
          setApproval(null);
          setApprovalState(event.decision === "allow-once" ? "allowed" : "denied");
          pass("capability.approval");
          break;
        case "operation.started":
          if (event.interruptible) {
            setActiveOperationId(event.operationId);
            setOperationState("running");
          }
          break;
        case "operation.interrupted":
          setActiveOperationId(null);
          setOperationState("interrupted");
          pass("operation.interrupt");
          break;
        case "operation.completed":
          setActiveOperationId((current) =>
            current === event.operationId ? null : current,
          );
          setOperationState((current) =>
            current === "running" ? "completed" : current,
          );
          break;
        case "operation.failed":
          setActiveOperationId((current) =>
            current === event.operationId ? null : current,
          );
          setOperationState("failed");
          setError(`${event.code}: ${event.message}`);
          break;
        case "session.cleared":
          setSessionState("cleared");
          pass("session.clear");
          break;
        case "host.closed":
          setHostStatus("closed");
          break;
      }
    });

    const configuredMode =
      typeof process !== "undefined"
        ? process.env.NEXT_PUBLIC_MAHAYANA_HOST_MODE
        : undefined;
    const mode =
      configuredMode === "production" || configuredMode === "test"
        ? configuredMode
        : isTauriMahayanaHostAvailable()
          ? "production"
          : "test";

    void transport
      .initialize({ profileId: "default", mode })
      .catch((cause: unknown) => {
        setHostStatus("failed");
        setError(cause instanceof Error ? cause.message : String(cause));
      });

    return () => {
      unsubscribe();
      void transport.close();
    };
  }, [transport]);

  const nextRequestId = (prefix: string) => {
    requestSequence.current += 1;
    return `${prefix}-${requestSequence.current}`;
  };

  const run = async (action: () => Promise<unknown>) => {
    setError(null);
    try {
      await action();
    } catch (cause: unknown) {
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  };

  const execute = (command: RuntimeCommand) => transport.execute(command);

  const sendMessage = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const text = input.trim();
    if (!text) return;
    setInput("");
    await run(() =>
      execute({ type: "chat.send", requestId: nextRequestId("chat"), text }),
    );
  };

  return (
    <main className={styles.page} data-testid="mahayana-host">
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>Mahayana Rust Core · React Host</p>
          <h1>极速功能自动化测试宿主</h1>
        </div>
        <output
          className={styles.status}
          data-testid="host-status"
          aria-live="polite"
        >
          {hostStatus}
        </output>
      </header>

      {error ? <p role="alert" className={styles.error}>{error}</p> : null}

      <div className={styles.grid}>
        <section className={styles.card} aria-labelledby="chat-title">
          <h2 id="chat-title">聊天</h2>
          <div className={styles.messages} data-testid="messages" aria-live="polite">
            {messages.length === 0 ? (
              <p className={styles.muted}>发送一条消息验证 Runtime 事件链。</p>
            ) : (
              messages.map((message, index) => (
                <p
                  key={`${message.role}-${index}`}
                  data-testid={`message-${message.role}`}
                  className={styles.message}
                >
                  <strong>{message.role === "user" ? "用户" : "Mahayana"}：</strong>
                  {message.text}
                </p>
              ))
            )}
          </div>
          <form className={styles.form} onSubmit={(event) => void sendMessage(event)}>
            <input
              data-testid="chat-input"
              aria-label="消息内容"
              value={input}
              onChange={(event) => setInput(event.target.value)}
              placeholder="输入消息"
              disabled={hostStatus !== "ready"}
            />
            <button data-testid="send-message" type="submit" disabled={hostStatus !== "ready"}>
              发送
            </button>
          </form>
        </section>

        <section className={styles.card} aria-labelledby="marketplace-title">
          <h2 id="marketplace-title">Marketplace 与 MiniApp</h2>
          <p>官方小程序：全球法布施</p>
          <div className={styles.actions}>
            <button
              data-testid="install-miniapp"
              type="button"
              onClick={() =>
                void run(() =>
                  execute({
                    type: "marketplace.install",
                    requestId: nextRequestId("install"),
                    miniAppId,
                  }),
                )
              }
            >
              安装
            </button>
            <button
              data-testid="open-miniapp"
              type="button"
              disabled={marketplaceState !== "installed"}
              onClick={() =>
                void run(() =>
                  execute({
                    type: "miniapp.open",
                    requestId: nextRequestId("open"),
                    miniAppId,
                  }),
                )
              }
            >
              打开
            </button>
          </div>
          <output data-testid="marketplace-state">{marketplaceState}</output>

          {openedMiniApp ? (
            <article className={styles.miniApp} data-testid="miniapp-panel">
              <h3>{openedMiniApp}</h3>
              <p>隔离 MiniApp 容器已打开。</p>
              <button
                data-testid="request-capability"
                type="button"
                onClick={() =>
                  void run(() =>
                    execute({
                      type: "capability.request",
                      requestId: nextRequestId("capability"),
                      miniAppId,
                      capability: "microphone.request",
                      reason: "为语音布施功能录制音频",
                    }),
                  )
                }
              >
                请求麦克风权限
              </button>
            </article>
          ) : null}
          <output data-testid="approval-state">{approvalState}</output>
        </section>

        <section className={styles.card} aria-labelledby="runtime-title">
          <h2 id="runtime-title">Runtime 控制</h2>
          <div className={styles.actions}>
            <button
              data-testid="start-long-operation"
              type="button"
              onClick={() =>
                void run(() =>
                  execute({
                    type: "runtime.longTask",
                    requestId: nextRequestId("long-task"),
                    label: "长任务测试",
                  }),
                )
              }
            >
              启动长任务
            </button>
            <button
              data-testid="interrupt-operation"
              type="button"
              disabled={!activeOperationId}
              onClick={() =>
                activeOperationId
                  ? void run(() => transport.interrupt(activeOperationId))
                  : undefined
              }
            >
              中断
            </button>
          </div>
          <output data-testid="operation-state">{operationState}</output>

          <button
            data-testid="clear-session"
            type="button"
            onClick={() =>
              void run(() =>
                execute({
                  type: "session.clear",
                  requestId: nextRequestId("session"),
                }),
              )
            }
          >
            清除安全会话
          </button>
          <output data-testid="session-state">{sessionState}</output>
        </section>

        <section className={styles.card} aria-labelledby="coverage-title">
          <h2 id="coverage-title">功能覆盖 Gate</h2>
          <p className={styles.muted}>
            新功能加入目录后默认是 pending；用户旅程没有覆盖它时，Actions 会失败。
          </p>
          <ul className={styles.coverage} data-testid="feature-coverage">
            {mahayanaHostFeatures.map((feature) => (
              <li
                key={feature.id}
                data-testid={`feature-result-${feature.id}`}
                data-state={featureStates[feature.id]}
              >
                <span>{feature.label}</span>
                <strong>{featureStates[feature.id]}</strong>
              </li>
            ))}
          </ul>
        </section>
      </div>

      {approval ? (
        <div className={styles.backdrop}>
          <section className={styles.dialog} role="dialog" aria-modal="true" aria-labelledby="approval-title">
            <h2 id="approval-title">能力审批</h2>
            <p>{approval.miniAppId} 请求 {approval.capability}</p>
            <p>{approval.reason}</p>
            <div className={styles.actions}>
              <button
                data-testid="approve-capability"
                type="button"
                onClick={() =>
                  void run(() =>
                    transport.resolveApproval({
                      approvalId: approval.approvalId,
                      decision: "allow-once",
                    }),
                  )
                }
              >
                本次允许
              </button>
              <button
                data-testid="deny-capability"
                type="button"
                onClick={() =>
                  void run(() =>
                    transport.resolveApproval({
                      approvalId: approval.approvalId,
                      decision: "deny",
                    }),
                  )
                }
              >
                拒绝
              </button>
            </div>
          </section>
        </div>
      ) : null}
    </main>
  );
}
