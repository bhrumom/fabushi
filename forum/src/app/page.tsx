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

        <h1>把论坛从占位目录推进成真正能承接互动与治理的独立项目。</h1>
        <p>
          这一版先不追求完整社区能力，而是先把独立运行骨架、sqlite 持久化、页面层主题创建入口、帖子详情回复、审核时间线，以及作者角色与新手引导信号接起来，
          同时把默认运行态收敛成“可持久化但不默认开放写入”，让下一轮可以在更稳的部署边界上接登录、审核和权限规则。
        </p>

        <div className="hero-grid">
          <article className="panel">
            <h2>当前阶段</h2>
            <p>sqlite 持久化闭环加治理时间线与角色引导持久化，并开始把写入能力改成显式开启，避免部署时默认放开匿名写入。</p>
          </article>
          <article className="panel">
            <h2>下一步承接点</h2>
            <p>优先明确论坛独立部署入口，以及登录态、权限态和审核流该落在哪一层服务边界上。</p>
          </article>
        </div>
      </section>

      <section className="thread-grid">
        {snapshot.threads.slice(0, 4).map((thread) => (
          <article key={thread.slug} className="thread-card">
            <div className="thread-meta">
              <span>{thread.author}</span>
              <span>{thread.authorRoleLabel}</span>
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
        <p>论坛页面已经不再直接读取种子文件，而是统一经过仓储边界。当前环境也会明确显示是否处于可写模式，以及当前治理时间线已经累计了多少条事件。</p>
        <p className="code">GET /api/threads</p>
        <p className="code">POST /api/threads</p>
        <p className="code">GET /api/thread/[slug]</p>
        <p className="code">POST /api/thread/[slug]/replies</p>
        <p className="code">GET /api/status</p>
        <div className="footer-note">
          <span>sections: {snapshot.sections.length}</span>
          <span>threads: {snapshot.threads.length}</span>
          <span>moderation events: {snapshot.moderationEvents.length}</span>
          <span>source: {snapshot.source}</span>
          <span>{runtime.writesEnabled ? "writes enabled" : "read-only"}</span>
        </div>
      </section>
    </main>
  );
}
