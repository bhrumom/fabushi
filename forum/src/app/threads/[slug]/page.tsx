import Link from "next/link";
import { notFound } from "next/navigation";
import { getForumRuntimeStatus, getThreadDetailBySlug } from "../../../lib/forum-data";
import { ThreadReplyForm } from "./reply-form";

export const dynamic = "force-dynamic";

interface ThreadPageProps {
  params: Promise<{ slug: string }>;
}

export default async function ThreadDetailPage({ params }: ThreadPageProps) {
  const { slug } = await params;
  const detail = getThreadDetailBySlug(slug);

  if (!detail) {
    notFound();
  }

  const runtime = getForumRuntimeStatus();
  const { thread, section, replies, moderationEvents } = detail;

  return (
    <main>
      <section className="thread-shell">
        <div className="hero-top">
          <span className="badge">{section?.name ?? thread.sectionSlug}</span>
          <nav className="nav">
            <Link href="/">首页</Link>
            <Link href="/threads">帖子列表</Link>
            <a href={`/api/thread/${thread.slug}`}>JSON</a>
          </nav>
        </div>

        <h1>{thread.title}</h1>
        <p>{thread.summary}</p>
        <div className="thread-meta">
          <span>{thread.author}</span>
          <span>{thread.authorRoleLabel}</span>
          <span>{thread.publishedAt}</span>
        </div>
        <p className="reply-form-hint">当前引导信号：{thread.guidanceSignal}</p>

        <div className="metrics">
          <article className="metric">
            <strong>{thread.replyCount}</strong>
            <span>当前回复数</span>
          </article>
          <article className="metric">
            <strong>{thread.followCount}</strong>
            <span>当前关注数</span>
          </article>
          <article className="metric">
            <strong>{thread.bookmarkCount}</strong>
            <span>当前收藏数</span>
          </article>
        </div>

        <div className="thread-tags">
          {thread.tags.map((tag) => (
            <span key={tag}>{tag}</span>
          ))}
          <span>{thread.knowledgeStage === "candidate" ? "候选资料" : "讨论中"}</span>
          <span>{thread.moderationState === "published" ? "已发布" : "需复核"}</span>
        </div>

        <section className="list-block">
          <h2>开场帖</h2>
          <ul>
            {thread.openingPost.map((paragraph) => (
              <li key={paragraph}>{paragraph}</li>
            ))}
          </ul>
        </section>

        <ThreadReplyForm threadSlug={thread.slug} writesEnabled={runtime.writesEnabled} dataSource={runtime.dataSource} />

        <section className="reply-stack">
          <div className="section-heading">
            <div>
              <h2>当前回复</h2>
              <p>
                {runtime.writesEnabled
                  ? "新回复提交后会把角色状态、引导信号和正文一起写入 sqlite，并在刷新后直接显示在这里。"
                  : "当前环境会继续回读已有帖子和回复，但不会默认开放新写入；等部署环境确认后再显式打开 FORUM_ENABLE_WRITES。"}
              </p>
            </div>
          </div>

          {replies.map((reply) => (
            <article key={reply.id} className="reply-card">
              <div className="reply-top">
                <div className="thread-meta">
                  <span>{reply.author}</span>
                  <span>{reply.roleLabel}</span>
                  <span>{reply.publishedAt}</span>
                </div>
                <span className="reply-signal">{reply.trustSignal}</span>
              </div>
              <p className="reply-form-hint">引导信号：{reply.guidanceSignal}</p>

              {reply.body.map((paragraph) => (
                <p key={paragraph}>{paragraph}</p>
              ))}
            </article>
          ))}
        </section>

        <section className="list-block">
          <h2>审核时间线</h2>
          {moderationEvents.length > 0 ? (
            <ul>
              {moderationEvents.map((event) => (
                <li key={event.id}>
                  <strong>{event.actorLabel}</strong>
                  {" · "}
                  {event.createdAt}
                  {" · "}
                  {event.summary}
                </li>
              ))}
            </ul>
          ) : (
            <p>当前线程还没有新的审核事件，后续真实治理动作会继续沿着这条时间线落库。</p>
          )}
        </section>

        <section className="list-block">
          <h2>当前值得沉淀的要点</h2>
          <ul>
            {thread.takeaways.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </section>

        <section className="api-note">
          <h2>后续扩展位置</h2>
          <p>下一轮可以在这条已持久化的角色与引导链路上继续接更明确的审核动作、登录态和新手承接流程。</p>
          <div className="footer-note">
            <span>作者：{thread.author}</span>
            <span>作者角色：{thread.authorRoleLabel}</span>
            <span>最近活动：{thread.lastActivity}</span>
          </div>
        </section>
      </section>
    </main>
  );
}
