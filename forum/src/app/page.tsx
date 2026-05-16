import Link from "next/link";
import { getForumRuntimeStatus, getForumSnapshot } from "../lib/forum-data";

export const dynamic = "force-dynamic";

export default function HomePage() {
  const snapshot = getForumSnapshot();
  const runtime = getForumRuntimeStatus();

  return (
    <main>
      <section className="hero">
        <div className="hero-top">
          <span className="badge">Fabushi Forum / 独立论坛项目骨架</span>
          <nav className="nav">
            <Link href="/">首页</Link>
            <Link href="/threads">帖子列表</Link>
            <Link href="/threads/new">发起主题</Link>
            <a href="/api/threads">论坛 API</a>
          </nav>
        </div>

        <h1>把论坛从占位目录推进成真正能承接互动的独立项目。</h1>
        <p>
          这一版先不追求完整社区能力，而是先把独立运行骨架、sqlite 最小写入、帖子详情回复和页面层主题创建入口接起来，
          让下一轮可以直接接审核状态、鉴权和更完整的用户流程。
        </p>

        <div className="hero-grid">
          <article className="panel">
            <h2>当前阶段</h2>
            <p>sqlite 最小互动闭环。目标是让论坛从“能启动、能浏览”进入“能发起主题、能回复、能继续扩展”的状态。</p>
          </article>
          <article className="panel">
            <h2>下一步承接点</h2>
            <p>优先把审核事件、角色状态和新手引导沿着同一条页面到仓储链路继续持久化，而不是回到静态占位页面。</p>
          </article>
        </div>
      </section>

      <section className="thread-grid">
        {snapshot.threads.slice(0, 4).map((thread) => (
          <article key={thread.slug} className="thread-card">
            <div className="thread-meta">
              <span>{thread.author}</span>
              <span>{thread.lastActivity}</span>
            </div>
            <h2>{thread.title}</h2>
            <p>{thread.summary}</p>
            <div className="thread-tags">
              {thread.tags.map((tag) => (
                <span key={tag}>{tag}</span>
              ))}
            </div>
            <div className="thread-links">
              <Link className="primary-link" href={`/threads/${thread.slug}`}>
                阅读帖子
              </Link>
            </div>
          </article>
        ))}
      </section>

      <section className="section-grid">
        {snapshot.sections.map((section) => (
          <article key={section.slug} className="panel">
            <h3>{section.name}</h3>
            <p>{section.description}</p>
            <p>{section.moderationFocus}</p>
          </article>
        ))}
      </section>

      <section className="api-note">
        <h2>当前接口边界</h2>
        <p>论坛页面已经不再直接读取种子文件，而是统一经过仓储边界。当前环境也会明确显示是否处于可写模式。</p>
        <p className="code">GET /api/threads</p>
        <p className="code">POST /api/threads</p>
        <p className="code">GET /api/thread/[slug]</p>
        <p className="code">POST /api/thread/[slug]/replies</p>
        <p className="code">GET /api/status</p>
        <div className="footer-note">
          <span>sections: {snapshot.sections.length}</span>
          <span>threads: {snapshot.threads.length}</span>
          <span>source: {snapshot.source}</span>
          <span>{runtime.writesEnabled ? "writes enabled" : "read-only"}</span>
        </div>
      </section>
    </main>
  );
}
