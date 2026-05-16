import Link from "next/link";
import { getForumRuntimeStatus, getForumSnapshot } from "../../../lib/forum-data";
import { ThreadComposer } from "./thread-composer";

export const dynamic = "force-dynamic";

export default function NewThreadPage() {
  const snapshot = getForumSnapshot();
  const runtime = getForumRuntimeStatus();

  return (
    <main>
      <section className="thread-shell">
        <div className="hero-top">
          <span className="badge">发起主题 / Start Thread</span>
          <nav className="nav">
            <Link href="/">首页</Link>
            <Link href="/threads">帖子列表</Link>
            <a href="/api/threads">JSON</a>
          </nav>
        </div>

        <h1>先把问题提清楚，再让讨论慢慢长出来。</h1>
        <p>
          这一页把页面层主题创建入口接到现有 sqlite 写路径，让论坛第一次同时具备“在页面里发起主题”和“在页面里回复主题”的最小互动承接；现在也支持在部署前用写入口令先收住内测写入边界。
        </p>

        <div className="composer-grid">
          <section className="composer-panel">
            <h2>版块与发帖提示</h2>
            <p>
              第一版先不追求复杂模板，而是把“选对版块、写清起点、保持问题聚焦”这些最影响讨论质量的前置动作放到页面里。
            </p>

            <div className="composer-section-list">
              {snapshot.sections.map((section) => (
                <article key={section.slug} className="composer-section-card">
                  <div className="thread-meta">
                    <span>{section.name}</span>
                    <span>{section.threadCount} 条主题</span>
                    <span>{section.replyCount} 条回复</span>
                  </div>
                  <p>{section.description}</p>
                  <p>{section.postingPrompt}</p>
                  <p>{section.moderationFocus}</p>
                </article>
              ))}
            </div>
          </section>

          <ThreadComposer
            sections={snapshot.sections.map((section) => ({
              slug: section.slug,
              name: section.name,
              postingPrompt: section.postingPrompt,
              moderationFocus: section.moderationFocus,
            }))}
            writesEnabled={runtime.writesEnabled}
            requiresAccessCode={runtime.requiresAccessCode}
            dataSource={runtime.dataSource}
          />
        </div>
      </section>
    </main>
  );
}
