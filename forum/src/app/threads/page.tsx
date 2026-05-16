import Link from "next/link";
import { getForumRuntimeStatus, getForumSnapshot } from "../../lib/forum-data";

export const dynamic = "force-dynamic";

export default function ThreadsPage() {
  const snapshot = getForumSnapshot();
  const runtime = getForumRuntimeStatus();

  return (
    <main>
      <section className="hero">
        <div className="hero-top">
          <span className="badge">帖子列表 / Thread Index</span>
          <nav className="nav">
            <Link href="/">返回首页</Link>
            <Link href="/threads/new">发起主题</Link>
            <a href="/api/threads">查看 API</a>
          </nav>
        </div>
        <h1>先把值得长期讨论的问题摆出来。</h1>
        <p>
          当前列表已经按真实论坛的浏览方式组织：板块、线程摘要、互动指标、详情入口和主题创建入口都开始沿着同一条独立论坛链路推进。
        </p>

        <div className="thread-action-bar">
          <div>
            <h2>开始一条新主题</h2>
            <p>
              {runtime.writesEnabled
                ? "当前运行环境已经允许页面层直接发起主题，作者角色和新手引导信号也会随主题一起落库。"
                : `当前 ${runtime.dataSource} 模式还是只读，但页面层发帖入口已经可以先承接结构和表单交互，切到 sqlite 后即可直接发布。`}
            </p>
          </div>
          <Link className="primary-link" href="/threads/new">
            发起主题
          </Link>
        </div>
      </section>

      <section className="section-grid">
        {snapshot.sections.map((section) => (
          <article key={section.slug} className="panel">
            <h2>{section.name}</h2>
            <p>{section.description}</p>
            <p>{section.postingPrompt}</p>
            <p>当前种子帖子 {section.threadCount} 条</p>
          </article>
        ))}
      </section>

      <section className="thread-grid">
        {snapshot.threads.map((thread) => (
          <article key={thread.slug} className="thread-card">
            <div className="thread-meta">
              <span>{thread.author}</span>
              <span>{thread.authorRoleLabel}</span>
              <span>{thread.publishedAt}</span>
              <span>{thread.lastActivity}</span>
            </div>
            <h2>{thread.title}</h2>
            <p>{thread.summary}</p>
            <p className="reply-form-hint">当前引导信号：{thread.guidanceSignal}</p>
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
