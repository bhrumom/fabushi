"use client";

import { useDeferredValue, useState, useTransition, type FormEvent } from "react";
import { useRouter } from "next/navigation";

interface ThreadReplyFormProps {
  threadSlug: string;
  writesEnabled: boolean;
  dataSource: string;
}

type FormTone = "error" | "success";

function getParagraphs(value: string) {
  return value
    .split(/\n+/)
    .map((paragraph) => paragraph.trim())
    .filter(Boolean);
}

export function ThreadReplyForm({ threadSlug, writesEnabled, dataSource }: ThreadReplyFormProps) {
  const router = useRouter();
  const [author, setAuthor] = useState("");
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
      setMessage(`当前 ${dataSource} 模式还是只读，切到 sqlite 后才能在页面里直接提交回复。`);
      return;
    }

    const trimmedAuthor = author.trim();
    const paragraphs = getParagraphs(body);

    if (!trimmedAuthor || paragraphs.length === 0) {
      setTone("error");
      setMessage("请先填写称呼和回复内容。");
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
              body: paragraphs,
            }),
          });

          const payload = (await response.json().catch(() => null)) as { error?: string } | null;

          if (!response.ok) {
            throw new Error(payload?.error ?? "提交回复失败，请稍后再试。");
          }

          setAuthor("");
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
          <p>先把页面层接到 sqlite 回复接口，确认真实互动不只停留在 API。</p>
        </div>
        <span className="reply-runtime">{writesEnabled ? `当前数据源：${dataSource} / 可写` : `当前数据源：${dataSource} / 只读`}</span>
      </div>

      {!writesEnabled ? (
        <p className="reply-form-hint">
          当前运行环境还在只读模式。把 `FORUM_DATA_SOURCE` 切到 `sqlite` 后，这里就能直接提交最小回复。
        </p>
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
              ? `当前会提交 ${paragraphCount} 段内容。接口会自动补默认角色标签和信任信号。`
              : "回复支持按空行切成多段，先把最小交流闭环跑通。"}
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
