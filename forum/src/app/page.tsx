import Link from "next/link";
import { FORUM_SECTIONS, FORUM_THREADS, getForumSnapshot } from "../lib/forum-data";

export default function HomePage() {
  const snapshot = getForumSnapshot();

  return (
    <main>
      <section className="hero">
        <div className="hero-top">
          <span className="badge">Fabushi Forum / 独立论坛项目骨架</span>
          <nav className="nav">
            <Link href="/">首页</Link>
            <Link href="/threads">帖子列表</Link>
            <a href="/api/threads">只读 API</a>
          </nav>
        </div>

        <h1>把论坛从占位目录推进成真正可启动的独立项目。</h1>
        <p>
          这一版先不追求完整社区能力，而是先把独立运行骨架、种子数据、帖子列表、帖子详情和只读接口立住，
          让下一轮可以直接接真实数据模型、发帖流程、鉴权和治理能力。
        </p>

        <div className="hero-grid">
          <article className="panel">
            <h2>当前阶段</h2>
            <p>独立论坛应用初始化。目标是从空目录进入“能启动、能浏览、能继续扩展”的状态。</p>
          </article>
          <article className="panel">
            <h2>下一步承接点</h2>
            <p>优先把种子数据替换成真实持久化模型，并补最小可用的发帖和首条回复流程。</p>
          </article>
        </div>
      </section>

      <section className="thread-grid">
        {FORUM_THREADS.slice(0, 4).map((thread) => (
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
        {FORUM_SECTIONS.map((section) => (
          <article key={section.slug} className="panel">
            <h3>{section.name}</h3>
            <p>{section.description}</p>
            <p>{section.moderationFocus}</p>
          </article>
        ))}
      </section>

      <section className="api-note">
        <h2>当前只读边界</h2>
        <p>种子数据已经通过独立应用自己的 JSON 路由暴露出来，后续可以在不重写页面结构的前提下切到真实数据层。</p>
        <p className="code">GET /api/threads</p>
        <p className="code">GET /api/thread/[slug]</p>
        <div className="footer-note">
          <span>sections: {snapshot.sections.length}</span>
          <span>threads: {snapshot.threads.length}</span>
          <span>source: {snapshot.source}</span>
        </div>
      </section>
    </main>
  );
}
