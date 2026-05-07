import { fabushiApiClient } from "@fabushi/api-client";
import {
  brand,
  contactChannels,
  faqItems,
  homeActionPaths,
  homeChannelRoles,
  homeHighlights,
  homeTrustSignals,
  homeUseCases,
  launchRoadmap,
} from "@fabushi/shared";
import { SiteFooter } from "../components/site-footer";
import { SiteHeader } from "../components/site-header";
import { getAllArticles, getFeaturedArticles } from "../lib/content";
import { getOfficialSiteReleaseCollection } from "../lib/official-site-releases";
import { siteHref, siteUrl } from "../lib/site-url";

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
  const featuredArticles = getFeaturedArticles();
  const allArticles = getAllArticles();
  const releaseCollection = await getOfficialSiteReleaseCollection();
  const releasePreview = [...releaseCollection.betaChannels, ...releaseCollection.stableChannels].slice(0, 3);
  const supportEmail = contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@fabushi.com";
  const faqPreview = faqItems.slice(0, 4);
  const siteEvidence = [
    {
      label: "可见下载状态",
      value: releasePreview.length > 0 ? `${releasePreview.length} 个入口已同步` : "入口持续同步中",
      detail: "首页和下载页会直接承接当前公开可见的 beta 与正式版状态。",
    },
    {
      label: "公开内容积累",
      value: `${allArticles.length} 篇内容已上线`,
      detail: "路线说明、专题文章与更新内容会持续沉淀，而不是只靠一张首页解释项目。",
    },
    {
      label: "问题预答复",
      value: `${faqItems.length} 个 FAQ 已整理`,
      detail: "把“这是什么、适合谁、是否能下载、各端怎么分工”提前写清楚。",
    },
    {
      label: "稳定联系入口",
      value: `${contactChannels.length} 条公开通道`,
      detail: "测试申请、支持反馈与公开协作都有明确去处，不用靠猜测联系路径。",
    },
  ] as const;
  const definitionBlocks = [
    {
      label: "Fabushi 是什么",
      title: "一个围绕佛法传播、修行记录与同行连接组织起来的数字产品体系。",
      description:
        "官网不是主应用的替代品，而是统一承接理解、下载、测试申请、内容更新与公开协作的第一入口。",
    },
    {
      label: "现在已经开放什么",
      title: "官网、FAQ、下载状态、申请测试与内容专栏已经开始协同工作。",
      description:
        "第一次接触项目的人，已经可以先在这里完成理解、判断与下一步动作，而不必先进入应用再摸索。",
    },
    {
      label: "还在逐步开放什么",
      title: "微信小程序首期能力与更完整的主应用体验会继续按节奏释放。",
      description:
        "这让站点可以真实同步当前状态，而不是过度承诺尚未公开的功能或入口。",
    },
  ] as const;

  const organizationJsonLd = {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: `${brand.name} Fabushi`,
    url: siteUrl("/"),
    email: supportEmail,
    description: brand.mission,
    sameAs: contactChannels.filter((item) => item.href.startsWith("https://")).map((item) => item.href),
  };

  const websiteJsonLd = {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: `${brand.name} Fabushi`,
    url: siteUrl("/"),
    inLanguage: "zh-CN",
    description: "Fabushi 官网，统一承接品牌说明、下载入口、测试申请、FAQ 和内容专栏。",
  };

  const applicationJsonLd = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: `${brand.name} Fabushi`,
    applicationCategory: "LifestyleApplication",
    operatingSystem: "iOS, Android, Web, WeChat Mini Program",
    inLanguage: "zh-CN",
    url: siteUrl("/"),
    downloadUrl: siteUrl("/download"),
    description:
      "Fabushi 法布施是一个围绕佛法传播、修行记录、公开档案、榜单与同行连接组织起来的多端产品体系。",
    featureList: [
      "佛法传播与内容入口",
      "修行记录与隐私边界",
      "公开档案与榜单浏览",
      "下载引导、测试申请与 FAQ",
    ],
  };

  const faqJsonLd = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqPreview.map((item) => ({
      "@type": "Question",
      name: item.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: item.answer,
      },
    })),
  };

  return (
    <main className="page-shell">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(organizationJsonLd) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(websiteJsonLd) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(applicationJsonLd) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }} />

      <header className="hero">
        <SiteHeader />

        <div className="hero-stage">
          <div className="hero-copy">
            <p className="eyebrow">法布施官网 · 品牌入口 / 下载引导 / 内容专栏</p>
            <p className="brand-kicker">
              {brand.name}
              <span>Fabushi</span>
            </p>
            <h1>把佛法传播、修行记录与同行连接，放进一个更清晰的数字入口。</h1>
            <p className="lede">
              官网先负责解释方向、建立信任、呈现下载状态与内容路线；微信小程序负责轻触达；主应用继续承接上传、互动与沉浸式体验。
            </p>
            <div className="hero-actions">
              <a className="primary-action" href={siteHref("/download")}>
                查看下载入口
              </a>
              <a className="secondary-action" href={siteHref("/apply")}>
                申请测试资格
              </a>
              <a className="secondary-action" href={siteHref("/faq")}>
                查看常见问题
              </a>
            </div>
            <div className="hero-signal-bar">
              {homeTrustSignals.map((item) => (
                <article key={item.title} className="signal-chip">
                  <span className="detail-label">{item.title}</span>
                  <strong>{item.summary}</strong>
                </article>
              ))}
            </div>
          </div>

          <aside className="hero-aside">
            <div className="hero-panel">
              <p>一句话理解</p>
              <strong>{brand.name} 是一个围绕佛法传播、修行记录与同行连接展开的数字产品体系。</strong>
              <span>
                官网负责说明与引导，小程序负责微信生态触达，Flutter 主应用承接更完整的浏览、上传、互动与个人使用流程。
              </span>
            </div>
            <div className="hero-proof-list">
              <p className="detail-label">当前公开入口</p>
              {releasePreview.map((item) => (
                <a key={`${item.audience}-${item.platform}`} className="hero-proof-row" href={siteHref(item.primaryHref)}>
                  <div>
                    <strong>{item.title}</strong>
                    <span>{item.description}</span>
                  </div>
                  <em>{item.status}</em>
                </a>
              ))}
            </div>
          </aside>
        </div>
      </header>

      <section className="band quick-paths" id="paths">
        <div className="section-heading">
          <p>快速路径</p>
          <h2>第一次来到这里，通常只需要先完成这三件事里的其中一件。</h2>
        </div>
        <div className="path-grid">
          {homeActionPaths.map((item) => (
            <article key={item.title} className="path-card">
              <span className="detail-label">{item.label}</span>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
              <a className="path-link" href={siteHref(item.href)}>
                {item.ctaLabel}
              </a>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt" id="evidence">
        <div className="section-heading">
          <p>公开事实</p>
          <h2>如果官网想建立信任，就要先给出可验证、可引用、可复查的公开信息。</h2>
        </div>
        <div className="evidence-grid">
          {siteEvidence.map((item) => (
            <article key={item.label} className="evidence-card">
              <span className="detail-label">{item.label}</span>
              <strong>{item.value}</strong>
              <p>{item.detail}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band" id="definition">
        <div className="section-heading">
          <p>先定义清楚</p>
          <h2>让用户和搜索系统都先搞清楚 Fabushi 是什么、已经开放什么、还在推进什么。</h2>
        </div>
        <div className="definition-grid">
          {definitionBlocks.map((item) => (
            <article key={item.label} className="definition-card">
              <span className="detail-label">{item.label}</span>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/faq")}>
            继续看完整 FAQ
          </a>
          <a className="secondary-action" href={siteHref("/download")}>
            查看当前下载状态
          </a>
        </div>
      </section>

      <section className="band alt" id="trust">
        <div className="section-heading">
          <p>为什么先做官网</p>
          <h2>先把入口、分工、状态和信任信息讲清楚，转化路径才不会在第一屏就断掉。</h2>
        </div>
        <div className="narrative-grid">
          {homeTrustSignals.map((item) => (
            <article key={item.title} className="narrative-block">
              <span className="detail-label">{item.title}</span>
              <h3>{item.summary}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band" id="audience">
        <div className="section-heading">
          <p>适用场景</p>
          <h2>Fabushi 官网应该同时服务首次到达、内测申请、合作判断和搜索理解这四种场景。</h2>
        </div>
        <div className="use-case-grid">
          {homeUseCases.map((item) => (
            <article key={item.audience} className="use-case-block">
              <span className="detail-label">{item.audience}</span>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt" id="channel-roles">
        <div className="section-heading">
          <p>入口分工</p>
          <h2>不是每个人都该直接跳进同一个端里，官网要先告诉你该从哪里开始。</h2>
        </div>
        <div className="channel-grid">
          {homeChannelRoles.map((item) => (
            <article key={item.channel} className="channel-card">
              <span className="detail-label">{item.channel}</span>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
              <ul className="channel-list">
                {item.bestFor.map((entry) => (
                  <li key={entry}>{entry}</li>
                ))}
              </ul>
              <a className="path-link" href={siteHref(item.href)}>
                {item.ctaLabel}
              </a>
            </article>
          ))}
        </div>
      </section>

      <section className="band" id="capabilities">
        <div className="section-heading">
          <p>核心能力</p>
          <h2>产品体系不是三套彼此割裂的站点，而是一条从发现、触达到深度使用的连续路径。</h2>
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
          <h2>官网已经开始把公开可见的发布状态直接拉回页面，减少“想下载却找不到入口”的摩擦。</h2>
        </div>
        <div className="platform-strip">
          {releasePreview.map((item) => (
            <a key={`${item.audience}-${item.platform}`} className="platform-row" href={siteHref(item.primaryHref)}>
              <div>
                <span className="platform-name">{item.title}</span>
                <p>{item.description}</p>
              </div>
              <div className="platform-meta">
                <strong>{item.status}</strong>
                <span>{item.primaryLabel}</span>
              </div>
            </a>
          ))}
        </div>
        <div className="status-note-list">
          {releaseCollection.notes.map((item) => (
            <p key={item}>{item}</p>
          ))}
        </div>
      </section>

      <section className="band alt" id="mini-program">
        <div className="section-heading">
          <p>微信小程序</p>
          <h2>首期优先覆盖轻浏览、榜单、公开档案与基础登录，把最容易传播的场景先跑通。</h2>
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
          <h2>一个前端 monorepo，共享接口层、类型、文案和部分纯业务逻辑，让官网与小程序各自发挥但不分家。</h2>
        </div>
        <div className="architecture-grid">
          <div>
            <h3>apps/web</h3>
            <p>Next.js 官网，负责 SEO、落地页、功能说明、下载引导和后续内容运营。</p>
          </div>
          <div>
            <h3>apps/mp-wechat</h3>
            <p>Taro 微信小程序，围绕微信生态内的轻触达和轻交互。</p>
          </div>
          <div>
            <h3>packages/shared</h3>
            <p>品牌信息、导航、固定文案、内容结构与纯前端通用工具。</p>
          </div>
          <div>
            <h3>packages/api-client</h3>
            <p>统一对接现有 flutter.ombhrum.com API 与共享类型。</p>
          </div>
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>接口复用</p>
          <h2>官网已经直接接入现有排行榜接口，证明它不是孤立宣传页，而是会逐步承接真实产品数据的入口层。</h2>
        </div>
        <div className="preview-list">
          {leaderboard.length === 0 ? (
            <p className="empty-copy">当前没有拉到排行榜预览，页面仍会稳定展示其余静态与内容型模块。</p>
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
          <h2>官网不只是一张首页，它还要持续承接路线、更新、专题内容和后续可引用的公开信息。</h2>
        </div>
        <div className="editorial-list">
          {featuredArticles.map((item) => (
            <a key={item.slug} className="editorial-row" href={siteHref(`/insights/${item.slug}`)}>
              <span>{item.category}</span>
              <div>
                <strong>{item.title}</strong>
                <p>{item.description}</p>
                <small>
                  {item.author} · {item.readTime}
                </small>
              </div>
            </a>
          ))}
        </div>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/insights")}>
            查看全部 {allArticles.length} 篇内容
          </a>
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>常见问题</p>
          <h2>把用户最容易问的关键问题提前说清楚，也是在补强搜索和生成式引用最爱抓取的结构化信息。</h2>
        </div>
        <div className="faq-list">
          {faqPreview.map((item) => (
            <details key={item.question} className="faq-item">
              <summary>{item.question}</summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/faq")}>
            查看完整 FAQ
          </a>
          <a className="secondary-action" href={siteHref("/contact")}>
            联系我们
          </a>
        </div>
      </section>

      <section className="band">
        <div className="section-heading">
          <p>联系</p>
          <h2>除了下载入口之外，官网也要把支持、反馈和公开协作的去处讲清楚。</h2>
        </div>
        <div className="contact-grid">
          {contactChannels.map((item) => (
            <a key={item.label} className="contact-card" href={siteHref(item.href)}>
              <span>{item.label}</span>
              <strong>{item.value}</strong>
              <p>{item.note}</p>
            </a>
          ))}
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
