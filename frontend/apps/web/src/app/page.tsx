import { fabushiApiClient } from "@fabushi/api-client";
import { brand, homeHighlights, launchRoadmap, primaryNavigation } from "@fabushi/shared";

async function getLeaderboardPreview() {
  try {
    const data = await fabushiApiClient.get<{
      leaderboard: Array<{
        username: string;
        displayName: string;
        totalBytes: number;
      }>;
    }>("/api/leaderboard?limit=3");
    return data.leaderboard;
  } catch {
    return [];
  }
}

export default async function HomePage() {
  const leaderboard = await getLeaderboardPreview();

  return (
    <main className="page-shell">
      <header className="hero">
        <nav className="topbar">
          <span className="brand-mark">{brand.englishName}</span>
          <div className="nav-links">
            {primaryNavigation.map((item) => (
              <a key={item.href} href={item.href}>
                {item.label}
              </a>
            ))}
          </div>
        </nav>

        <div className="hero-copy">
          <p className="eyebrow">Fabushi Official Site</p>
          <h1>{brand.tagline}</h1>
          <p className="lede">{brand.mission}</p>
          <div className="hero-actions">
            <a className="primary-action" href="#mini-program">
              查看小程序规划
            </a>
            <a className="secondary-action" href="#architecture">
              查看技术架构
            </a>
          </div>
        </div>
      </header>

      <section className="band" id="capabilities">
        <div className="section-heading">
          <p>核心能力</p>
          <h2>官网负责品牌与入口，小程序负责轻场景触达，Flutter 继续承接重体验。</h2>
        </div>
        <div className="feature-grid">
          {homeHighlights.map((item) => (
            <article key={item.title} className="feature-block">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt" id="mini-program">
        <div className="section-heading">
          <p>微信小程序</p>
          <h2>首期建议先覆盖轻浏览、榜单、公开档案与基础登录。</h2>
        </div>
        <ol className="roadmap-list">
          {launchRoadmap.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ol>
      </section>

      <section className="band" id="architecture">
        <div className="section-heading">
          <p>技术架构</p>
          <h2>一个前端 monorepo，共享接口层、类型、文案和部分纯业务逻辑。</h2>
        </div>
        <div className="architecture-grid">
          <div>
            <h3>apps/web</h3>
            <p>Next.js 官网，负责 SEO、落地页、功能说明、后续内容运营。</p>
          </div>
          <div>
            <h3>apps/mp-wechat</h3>
            <p>Taro 微信小程序，围绕微信生态内的轻触达和轻交互。</p>
          </div>
          <div>
            <h3>packages/shared</h3>
            <p>品牌信息、导航、固定文案、纯前端通用工具。</p>
          </div>
          <div>
            <h3>packages/api-client</h3>
            <p>统一对接现有 `flutter.ombhrum.com` API 与共享类型。</p>
          </div>
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>接口复用</p>
          <h2>当前官网已经直接接了现有排行榜接口，作为后端共用的第一块落地验证。</h2>
        </div>
        <div className="preview-list">
          {leaderboard.length === 0 ? (
            <p className="empty-copy">当前没有拉到排行榜预览，页面仍可正常展示静态内容。</p>
          ) : (
            leaderboard.map((item, index) => (
              <div key={item.username} className="preview-row">
                <span>#{index + 1}</span>
                <strong>{item.displayName || item.username}</strong>
                <span>{item.totalBytes.toLocaleString()} bytes</span>
              </div>
            ))
          )}
        </div>
      </section>
    </main>
  );
}
