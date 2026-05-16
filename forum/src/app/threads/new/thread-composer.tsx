"use client";

import { useDeferredValue, useState, useTransition, type FormEvent } from "react";
import { useRouter } from "next/navigation";

interface ComposerSection {
  slug: string;
  name: string;
  postingPrompt: string;
  moderationFocus: string;
}

interface ThreadComposerProps {
  sections: ComposerSection[];
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

function getTags(value: string) {
  return value
    .split(/[，,\n]+/)
    .map((tag) => tag.trim())
    .filter(Boolean);
}

export function ThreadComposer({ sections, writesEnabled, dataSource }: ThreadComposerProps) {
  const router = useRouter();
  const [sectionSlug, setSectionSlug] = useState(sections[0]?.slug ?? "");
  const [title, setTitle] = useState("");
  const [author, setAuthor] = useState("");
  const [tagsInput, setTagsInput] = useState("");
  const [openingPost, setOpeningPost] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [tone, setTone] = useState<FormTone | null>(null);
  const [isPending, startTransition] = useTransition();
  const deferredOpeningPost = useDeferredValue(openingPost);
  const deferredTags = useDeferredValue(tagsInput);
  const paragraphCount = getParagraphs(deferredOpeningPost).length;
  const tagCount = getTags(deferredTags).length;
  const selectedSection = sections.find((section) => section.slug === sectionSlug) ?? sections[0];

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (!writesEnabled) {
      setTone("error");
      setMessage(`当前 ${dataSource} 模式还是只读，切到 sqlite 后才能在页面里直接发布主题。`);
      return;
    }

    if (!selectedSection) {
      setTone("error");
      setMessage("当前还没有可选版块，暂时无法发起主题。");
      return;
    }

    const trimmedTitle = title.trim();
    const trimmedAuthor = author.trim();
    const paragraphs = getParagraphs(openingPost);
    const tags = getTags(tagsInput);

    if (!trimmedTitle || !trimmedAuthor || paragraphs.length === 0) {
      setTone("error");
      setMessage("请先选择版块，并填写标题、称呼和开场帖内容。");
      return;
    }

    startTransition(() => {
      void (async () => {
        try {
          setTone(null);
          setMessage(null);

          const response = await fetch("/api/threads", {
            method: "POST",
            headers: {
              "content-type": "application/json",
            },
            body: JSON.stringify({
              sectionSlug: selectedSection.slug,
              title: trimmedTitle,
              author: trimmedAuthor,
              tags,
              openingPost: paragraphs,
            }),
          });

          const payload = (await response.json().catch(() => null)) as {
            error?: string;
            thread?: { slug?: string };
          } | null;

          if (!response.ok) {
            throw new Error(payload?.error ?? "发布主题失败，请稍后再试。");
          }

          const createdSlug = payload?.thread?.slug;

          if (!createdSlug) {
            throw new Error("主题已创建，但没有返回详情地址。");
          }

          setTitle("");
          setAuthor("");
          setTagsInput("");
          setOpeningPost("");
          setTone("success");
          setMessage("主题已创建，正在跳转到详情页。");
          router.push(`/threads/${createdSlug}`);
        } catch (error) {
          setTone("error");
          setMessage(error instanceof Error ? error.message : "发布主题失败，请稍后再试。");
        }
      })();
    });
  }

  return (
    <section className="composer-panel" aria-labelledby="thread-composer-heading">
      <div className="section-heading">
        <div>
          <h2 id="thread-composer-heading">发起一条最小主题</h2>
          <p>先把页面层接到已有的线程创建接口，确认“浏览列表 -> 发起主题 -> 进入详情页”的链路已经成立。</p>
        </div>
        <span className="reply-runtime">{writesEnabled ? `当前数据源：${dataSource} / 可写` : `当前数据源：${dataSource} / 只读`}</span>
      </div>

      {!writesEnabled ? (
        <p className="reply-form-hint">
          当前运行环境还在只读模式。把 `FORUM_DATA_SOURCE` 切到 `sqlite` 后，这里就能直接提交新主题。
        </p>
      ) : null}

      <form className="reply-form" onSubmit={handleSubmit}>
        <div className="composer-form-grid">
          <label className="reply-field">
            <span>选择版块</span>
            <select
              className="reply-input composer-select"
              name="sectionSlug"
              value={sectionSlug}
              onChange={(event) => setSectionSlug(event.target.value)}
              disabled={!writesEnabled || isPending || sections.length === 0}
            >
              {sections.map((section) => (
                <option key={section.slug} value={section.slug}>
                  {section.name}
                </option>
              ))}
            </select>
          </label>

          <label className="reply-field">
            <span>主题标题</span>
            <input
              className="reply-input"
              name="title"
              value={title}
              onChange={(event) => setTitle(event.target.value)}
              placeholder="例如：刚开始读经时，怎样记录自己真正看不懂的地方？"
              disabled={!writesEnabled || isPending}
            />
          </label>

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
            <span>标签</span>
            <input
              className="reply-input"
              name="tags"
              value={tagsInput}
              onChange={(event) => setTagsInput(event.target.value)}
              placeholder="用逗号分开，例如：新手，读经，提问"
              disabled={!writesEnabled || isPending}
            />
          </label>
        </div>

        <label className="reply-field">
          <span>开场帖</span>
          <textarea
            className="reply-textarea composer-textarea"
            name="openingPost"
            value={openingPost}
            onChange={(event) => setOpeningPost(event.target.value)}
            placeholder="先写清你的起点、当前困惑，以及你已经尝试过什么。"
            disabled={!writesEnabled || isPending}
          />
        </label>

        {selectedSection ? (
          <div className="composer-inline-note">
            <p className="reply-form-hint">当前版块：{selectedSection.name}</p>
            <p className="reply-form-hint">发帖提示：{selectedSection.postingPrompt}</p>
            <p className="reply-form-hint">治理重点：{selectedSection.moderationFocus}</p>
          </div>
        ) : null}

        <div className="reply-form-footer">
          <p className="reply-form-hint">
            {paragraphCount > 0
              ? `当前会提交 ${paragraphCount} 段开场帖${tagCount > 0 ? `，并附带 ${tagCount} 个标签` : ""}。接口会自动生成摘要。`
              : "开场帖支持按空行分段；第一版先让标题、版块和开场帖稳定落库。"}
          </p>
          <button className="submit-button" type="submit" disabled={!writesEnabled || isPending || !selectedSection}>
            {isPending ? "发布中..." : "发布主题"}
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
