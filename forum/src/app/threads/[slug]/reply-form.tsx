"use client";

import { useDeferredValue, useState, useTransition, type FormEvent } from "react";
import { useRouter } from "next/navigation";

interface ThreadReplyFormProps {
  threadSlug: string;
  writesEnabled: boolean;
  requiresAccessCode: boolean;
  dataSource: string;
}

type FormTone = "error" | "success";

const ROLE_OPTIONS = ["新加入同修", "持续修学者", "带新同修", "资料整理协作"];

function getParagraphs(value: string) {
  return value
    .split(/\n+/)
    .map((paragraph) => paragraph.trim())
    .filter(Boolean);
}

export function ThreadReplyForm({ threadSlug, writesEnabled, requiresAccessCode, dataSource }: ThreadReplyFormProps) {
  const router = useRouter();
  const [author, setAuthor] = useState("");
  const [roleLabel, setRoleLabel] = useState(ROLE_OPTIONS[0]);
  const [guidanceSignal, setGuidanceSignal] = useState("");
  const [writeAccessCode, setWriteAccessCode] = useState("");
  const [body, setBody] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [tone, setTone] = useState<FormTone | null>(null);
  const [isPending, startTransition] = useTransition();
  const deferredBody = useDeferredValue(body);
  const paragraphCount = getParagraphs(deferredBody).length;

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (!writesEnabled) {
      setTone("error");
      setMessage(
        `当前 ${dataSource} 模式还没有开放写入；请保持 FORUM_DATA_SOURCE=sqlite，并把 FORUM_ENABLE_WRITES=true 后再直接提交回复。`,
      );
      return;
    }

    const trimmedAuthor = author.trim();
    const trimmedGuidanceSignal = guidanceSignal.trim();
    const trimmedWriteAccessCode = writeAccessCode.trim();
    const paragraphs = getParagraphs(body);

    if (!trimmedAuthor || !trimmedGuidanceSignal || paragraphs.length === 0) {
      setTone("error");
      setMessage("请先填写称呼、角色状态、引导信号和回复内容。");
      return;
    }

    if (requiresAccessCode && !trimmedWriteAccessCode) {
      setTone("error");
      setMessage("当前写入环境还要求写入口令；请先填写正确口令后再提交回复。");
      return;
    }

    startTransition(() => {
      void (async () => {
        try {
          setTone(null);
          setMessage(null);

          const response = await fetch(`/api/thread/${threadSlug}/replies`, {
            method: "POST",
            headers: {
              "content-type": "application/json",
            },
            body: JSON.stringify({
              author: trimmedAuthor,
              roleLabel,
              guidanceSignal: trimmedGuidanceSignal,
              writeAccessCode: trimmedWriteAccessCode,
              body: paragraphs,
            }),
          });

          const payload = (await response.json().catch(() => null)) as { error?: string } | null;

          if (!response.ok) {
            throw new Error(payload?.error ?? "提交回复失败，请稍后再试。");
          }

          setAuthor("");
          setGuidanceSignal("");
          setWriteAccessCode("");
          setBody("");
          setTone("success");
          setMessage("回复已写入当前线程，页面正在刷新。");
          router.refresh();
        } catch (error) {
          setTone("error");
          setMessage(error instanceof Error ? error.message : "提交回复失败，请稍后再试。");
        }
      })();
    });
  }

  return (
    <section className="reply-composer" aria-labelledby="reply-composer-heading">
      <div className="section-heading">
        <div>
          <h2 id="reply-composer-heading">写一条最小回复</h2>
          <p>
            这一步会在开放写入时把回复者的角色状态和当前引导信号一起写入 sqlite；如果当前环境仍处于内测口令模式，也会在这里一起校验。
          </p>
        </div>
        <span className="reply-runtime">{writesEnabled ? `当前数据源：${dataSource} / 可写` : `当前数据源：${dataSource} / 只读`}</span>
      </div>

      {!writesEnabled ? (
        <p className="reply-form-hint">
          当前运行环境还在只读模式。先把 `FORUM_DATA_SOURCE` 设为 `sqlite`，再显式打开 `FORUM_ENABLE_WRITES=true`，这里才会直接提交最小回复。
        </p>
      ) : requiresAccessCode ? (
        <p className="reply-form-hint">当前运行环境已经开放写入，但仍要求有效写入口令，适合先做小范围内测。</p>
      ) : null}

      <form className="reply-form" onSubmit={handleSubmit}>
        <div className="reply-form-grid">
          <label className="reply-field">
            <span>你的称呼</span>
            <input
              className="reply-input"
              name="author"
              value={author}
              onChange={(event) => setAuthor(event.target.value)}
              placeholder="例如：新加入同修"
              disabled={!writesEnabled || isPending}
              autoComplete="name"
            />
          </label>

          <label className="reply-field">
            <span>角色状态</span>
            <select
              className="reply-input composer-select"
              name="roleLabel"
              value={roleLabel}
              onChange={(event) => setRoleLabel(event.target.value)}
              disabled={!writesEnabled || isPending}
            >
              {ROLE_OPTIONS.map((option) => (
                <option key={option} value={option}>
                  {option}
                </option>
              ))}
            </select>
          </label>

          <label className="reply-field">
            <span>引导信号</span>
            <input
              className="reply-input"
              name="guidanceSignal"
              value={guidanceSignal}
              onChange={(event) => setGuidanceSignal(event.target.value)}
              placeholder="例如：我想先补一条最容易执行的下一步建议。"
              disabled={!writesEnabled || isPending}
            />
          </label>

          {requiresAccessCode ? (
            <label className="reply-field">
              <span>写入口令</span>
              <input
                className="reply-input"
                name="writeAccessCode"
                value={writeAccessCode}
                onChange={(event) => setWriteAccessCode(event.target.value)}
                placeholder="例如：forum-preview-2026"
                disabled={!writesEnabled || isPending}
                autoComplete="off"
              />
            </label>
          ) : null}

          <label className="reply-field">
            <span>回复内容</span>
            <textarea
              className="reply-textarea"
              name="body"
              value={body}
              onChange={(event) => setBody(event.target.value)}
              placeholder="可以直接写一段，也可以换行写成两三段。"
              disabled={!writesEnabled || isPending}
            />
          </label>
        </div>

        <div className="reply-form-footer">
          <p className="reply-form-hint">
            {paragraphCount > 0
              ? `当前会提交 ${paragraphCount} 段内容，并把回复者角色和引导信号一起落库${requiresAccessCode ? "，同时校验写入口令" : ""}。`
              : `回复支持按空行切成多段，第一版先把角色状态和引导信号稳定接进真实回复流${requiresAccessCode ? "，再用写入口令收住内测写入边界" : ""}。`}
          </p>
          <button className="submit-button" type="submit" disabled={!writesEnabled || isPending}>
            {isPending ? "提交中..." : "提交回复"}
          </button>
        </div>

        {message ? (
          <p className="reply-form-message" data-tone={tone ?? undefined}>
            {message}
          </p>
        ) : null}
      </form>
    </section>
  );
}
