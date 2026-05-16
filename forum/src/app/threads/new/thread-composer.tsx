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
  requiresAccessCode: boolean;
  dataSource: string;
}

type FormTone = "error" | "success";

const ROLE_OPTIONS = ["新手提问者", "持续修学者", "带新同修", "资料整理者"];

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

export function ThreadComposer({ sections, writesEnabled, requiresAccessCode, dataSource }: ThreadComposerProps) {
  const router = useRouter();
  const [sectionSlug, setSectionSlug] = useState(sections[0]?.slug ?? "");
  const [title, setTitle] = useState("");
  const [author, setAuthor] = useState("");
  const [authorRoleLabel, setAuthorRoleLabel] = useState(ROLE_OPTIONS[0]);
  const [guidanceSignal, setGuidanceSignal] = useState("");
  const [writeAccessCode, setWriteAccessCode] = useState("");
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
      setMessage(
        `当前 ${dataSource} 模式还没有开放写入；请保持 FORUM_DATA_SOURCE=sqlite，并把 FORUM_ENABLE_WRITES=true 后再直接发布主题。`,
      );
      return;
    }

    if (!selectedSection) {
      setTone("error");
      setMessage("当前还没有可选版块，暂时无法发起主题。");
      return;
    }

    const trimmedTitle = title.trim();
    const trimmedAuthor = author.trim();
    const trimmedGuidanceSignal = guidanceSignal.trim();
    const trimmedWriteAccessCode = writeAccessCode.trim();
    const paragraphs = getParagraphs(openingPost);
    const tags = getTags(tagsInput);

    if (!trimmedTitle || !trimmedAuthor || !trimmedGuidanceSignal || paragraphs.length === 0) {
      setTone("error");
      setMessage("请先填写标题、称呼、作者角色、引导信号和开场帖内容。");
      return;
    }

    if (requiresAccessCode && !trimmedWriteAccessCode) {
      setTone("error");
      setMessage("当前写入环境还要求写入口令；请先填写正确口令后再发布主题。");
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
              authorRoleLabel,
              guidanceSignal: trimmedGuidanceSignal,
              writeAccessCode: trimmedWriteAccessCode,
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
          setGuidanceSignal("");
          setWriteAccessCode("");
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
          <p>
            这一步会在开放写入时把作者角色和新手引导信号一起写入持久化层；如果当前环境仍处于内测口令模式，也会在这里一起校验。
          </p>
        </div>
        <span className="reply-runtime">{writesEnabled ? `当前数据源：${dataSource} / 可写` : `当前数据源：${dataSource} / 只读`}</span>
      </div>

      {!writesEnabled ? (
        <p className="reply-form-hint">
          当前运行环境还在只读模式。先把 `FORUM_DATA_SOURCE` 设为 `sqlite`，再显式打开 `FORUM_ENABLE_WRITES=true`，这里才会直接提交新主题。
        </p>
      ) : requiresAccessCode ? (
        <p className="reply-form-hint">当前运行环境已经开放写入，但仍要求有效写入口令，适合先做小范围内测。</p>
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
            <span>作者角色</span>
            <select
              className="reply-input composer-select"
              name="authorRoleLabel"
              value={authorRoleLabel}
              onChange={(event) => setAuthorRoleLabel(event.target.value)}
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
              placeholder="例如：请先给我一条最容易开始的下一步建议。"
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
              ? `当前会提交 ${paragraphCount} 段开场帖${tagCount > 0 ? `，并附带 ${tagCount} 个标签` : ""}，同时把作者角色和引导信号一起落库${requiresAccessCode ? "，并校验写入口令" : ""}。`
              : `开场帖支持按空行分段；第一版先把标题、版块、角色状态和引导信号稳定落库${requiresAccessCode ? "，再用写入口令收住内测写入边界" : ""}。`}
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
