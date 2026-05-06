import { fabushiApiClient } from "@fabushi/api-client";
import {
  brand,
  downloadOptions,
  faqItems,
  homeHighlights,
  insightArticles,
  launchRoadmap,
} from "@fabushi/shared";
import { SiteFooter } from "../components/site-footer";
import { SiteHeader } from "../components/site-header";

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
        <SiteHeader />

        <div className="hero-copy">
          <p className="eyebrow">法布施官网</p>
          <p className="brand-kicker">{brand.name}</p>
          <h1>官网负责入口，小程序负责触达，主应用负责完整体验。</h1>
          <p className="lede">{brand.mission}</p>
          <div className="hero-actions">
            <a className="primary-action" href="/download">
              查看下载入口
            </a>
            <a className="secondary-action" href="/faq">
              查看常见问题
            </a>
          </div>
        </div>

        <div className="hero-panel">
          <p>当前推进</p>
          <strong>Next.js 官网 + Taro 微信小程序 + 现有 Workers API 共用</strong>
          <span>前端新工作区已经拆出 monorepo，后续会沿着下载、FAQ、内容专栏和小程序首期链路继续推进。</span>
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

      <section className="band cinematic">
        <div className="section-heading">
          <p>下载入口</p>
          <h2>先把不同入口说清楚，用户才知道该去哪里开始。</h2>
        </div>
        <div className="platform-strip">
          {downloadOptions.map((item) => (
            <a key={item.platform} className="platform-row" href={item.ctaHref}>
              <div>
                <span className="platform-name">{item.platform}</span>
                <p>{item.description}</p>
              </div>
              <div className="platform-meta">
                <strong>{item.status}</strong>
                <span>{item.ctaLabel}</span>
              </div>
            </a>
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
          <h2>官网已经直接接了现有排行榜接口，作为“后端继续共用”的第一块落地验证。</h2>
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

      <section className="band">
        <div className="section-heading">
          <p>内容专栏</p>
          <h2>官网不只是一张首页，还要能持续承接路线、更新和专题内容。</h2>
        </div>
        <div className="editorial-list">
          {insightArticles.map((item) => (
            <a key={item.slug} className="editorial-row" href={`/insights/${item.slug}`}>
              <span>{item.category}</span>
              <div>
                <strong>{item.title}</strong>
                <p>{item.description}</p>
              </div>
            </a>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>常见问题</p>
          <h2>先把用户最容易问的几件事说清楚，官网才真正开始工作。</h2>
        </div>
        <div className="faq-list">
          {faqItems.slice(0, 3).map((item) => (
            <details key={item.question} className="faq-item">
              <summary>{item.question}</summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
        <div className="inline-cta">
          <a className="secondary-action" href="/faq">
            查看完整 FAQ
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
