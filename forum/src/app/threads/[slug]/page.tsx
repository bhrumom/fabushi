import Link from "next/link";
import { notFound } from "next/navigation";
import { getThreadDetailBySlug } from "../../../lib/forum-data";

interface ThreadPageProps {
  params: Promise<{ slug: string }>;
}

export default async function ThreadDetailPage({ params }: ThreadPageProps) {
  const { slug } = await params;
  const detail = getThreadDetailBySlug(slug);

  if (!detail) {
    notFound();
  }

  const { thread, section, replies } = detail;

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

        <section className="reply-stack">
          <div className="section-heading">
            <div>
              <h2>首批回复样例</h2>
              <p>这一层已经开始承接真实论坛会需要的回复、治理提示和后续沉淀信号。</p>
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

              {reply.body.map((paragraph) => (
                <p key={paragraph}>{paragraph}</p>
              ))}
            </article>
          ))}
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
          <p>下一轮可以直接把这里的结构接到真实持久化层、发帖表单、回复提交和审核事件时间线上。</p>
          <div className="footer-note">
            <span>作者：{thread.author}</span>
            <span>发布时间：{thread.publishedAt}</span>
            <span>最近活动：{thread.lastActivity}</span>
          </div>
        </section>
      </section>
    </main>
  );
}
