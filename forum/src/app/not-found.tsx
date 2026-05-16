import Link from "next/link";

export default function NotFoundPage() {
  return (
    <main>
      <section className="thread-shell">
        <div className="hero-top">
          <span className="badge">未找到 / Not Found</span>
          <nav className="nav">
            <Link href="/">首页</Link>
            <Link href="/threads">帖子列表</Link>
          </nav>
        </div>
        <h1>这个帖子还没有进入当前论坛骨架。</h1>
        <p>目前独立论坛项目只带了首批种子帖子。下一轮如果接入真实数据层，这里会自然接到数据库和权限边界上。</p>
      </section>
    </main>
  );
}
