import Link from "next/link";
import { FORUM_SECTIONS, FORUM_THREADS, getThreadsBySection } from "../../lib/forum-data";

export default function ThreadsPage() {
  return (
    <main>
      <section className="hero">
        <div className="hero-top">
          <span className="badge">帖子列表 / Thread Index</span>
          <nav className="nav">
            <Link href="/">返回首页</Link>
            <a href="/api/threads">查看 API</a>
          </nav>
        </div>
        <h1>先把值得长期讨论的问题摆出来。</h1>
        <p>
          当前列表使用种子内容驱动，但页面结构已经按真实论坛的浏览方式组织：板块、线程摘要、互动指标和详情入口都已具备独立承接点。
        </p>
      </section>

      <section className="section-grid">
        {FORUM_SECTIONS.map((section) => (
          <article key={section.slug} className="panel">
            <h2>{section.name}</h2>
            <p>{section.description}</p>
            <p>当前种子帖子 {getThreadsBySection(section.slug).length} 条</p>
          </article>
        ))}
      </section>

      <section className="thread-grid">
        {FORUM_THREADS.map((thread) => (
          <article key={thread.slug} className="thread-card">
            <div className="thread-meta">
              <span>{thread.author}</span>
              <span>{thread.publishedAt}</span>
              <span>{thread.lastActivity}</span>
            </div>
            <h2>{thread.title}</h2>
            <p>{thread.summary}</p>
            <div className="thread-tags">
              {thread.tags.map((tag) => (
                <span key={tag}>{tag}</span>
              ))}
            </div>
            <div className="footer-note">
              <span>{thread.replyCount} 条回复</span>
              <span>{thread.followCount} 人关注</span>
              <span>{thread.bookmarkCount} 次收藏</span>
            </div>
            <div className="thread-links">
              <Link className="primary-link" href={`/threads/${thread.slug}`}>
                打开详情
              </Link>
            </div>
          </article>
        ))}
      </section>
    </main>
  );
}
