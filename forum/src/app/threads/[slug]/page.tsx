import Link from "next/link";
import { notFound } from "next/navigation";
import { getSectionBySlug, getThreadBySlug } from "../../../lib/forum-data";

interface ThreadPageProps {
  params: Promise<{ slug: string }>;
}

export default async function ThreadDetailPage({ params }: ThreadPageProps) {
  const { slug } = await params;
  const thread = getThreadBySlug(slug);

  if (!thread) {
    notFound();
  }

  const section = getSectionBySlug(thread.sectionSlug);

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
        </div>

        <section className="list-block">
          <h2>开场帖</h2>
          <ul>
            {thread.openingPost.map((paragraph) => (
              <li key={paragraph}>{paragraph}</li>
            ))}
          </ul>
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
          <p>这里下一轮可以直接接真实回复流、收藏操作、关注状态、新手引导提示和审核事件时间线。</p>
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
