import { brand, contactChannels, faqItems, homeHighlights } from "@fabushi/shared";
import { DownloadLink } from "../components/download-link";
import { SiteFooter } from "../components/site-footer";
import { SiteHeader } from "../components/site-header";
import { ZenOrbit } from "../components/zen-orbit";
import { getOfficialSiteReleaseCollection } from "../lib/official-site-releases";
import { siteHref, siteUrl } from "../lib/site-url";

interface ProductMoment {
  title: string;
  description: string;
  image: string;
}

const HERO_MAIN_IMAGE = "/product/global-donation.svg";
const HERO_SIDE_IMAGE = "/product/group-practice.svg";

const PRODUCT_MOMENTS: ProductMoment[] = [
  {
    title: "全球法布施",
    description: "看见善意如何跨越地域，直接抵达世界各地。",
    image: "/product/global-donation.svg",
  },
  {
    title: "随时随地开始修行",
    description: "打开就能进入禅修状态，把修行节奏留在日常里。",
    image: "/product/start-practice.svg",
  },
  {
    title: "沉浸式禅修体验",
    description: "用更安静、更专注的界面承接每一次练习。",
    image: "/product/immersive-meditation.svg",
  },
  {
    title: "锁定主修功课",
    description: "先确定主线，再围绕自己的路径稳定推进。",
    image: "/product/main-course-lock.svg",
  },
  {
    title: "轻松加入共修小组",
    description: "搜索、申请、加入和管理共修关系都放在同一条路径里。",
    image: "/product/group-practice.svg",
  },
  {
    title: "全球修行排行",
    description: "修行进度和榜单变化一眼可见，方便持续跟进。",
    image: "/product/practice-ranking.svg",
  },
  {
    title: "全球布施排行",
    description: "实时查看全球布施动态，感受功德流动。",
    image: "/product/donation-ranking-live.svg",
  },
  {
    title: "全球布施排行榜",
    description: "用更直观的排行榜界面看见用户与善行的连接。",
    image: "/product/donation-leaderboard.svg",
  },
];

export default async function HomePage() {
  const releaseCollection = await getOfficialSiteReleaseCollection();
  const productMoments = PRODUCT_MOMENTS;
  const channels = [...releaseCollection.betaChannels, ...releaseCollection.stableChannels].slice(0, 3);
  const supportEmail = contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@ombhrum.com";
  const directChannel = releaseCollection.betaChannels.find((item) => !item.primaryHref.startsWith("/contact"));
  const primaryLabel = directChannel?.primaryLabel ?? "查看下载入口";
  const faqPreview = faqItems.slice(0, 4);

  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        name: `${brand.name} 大乘`,
        url: siteUrl("/"),
        email: supportEmail,
        description: brand.mission,
      },
      {
        "@type": "SoftwareApplication",
        name: `${brand.name} 大乘`,
        applicationCategory: "LifestyleApplication",
        operatingSystem: "iOS, Android, Web",
        url: siteUrl("/download"),
        description: brand.tagline,
      },
      {
        "@type": "FAQPage",
        mainEntity: faqPreview.map((item) => ({
          "@type": "Question",
          name: item.question,
          acceptedAnswer: {
            "@type": "Answer",
            text: item.answer,
          },
        })),
      },
    ],
  };

  return (
    <main className="page-shell">
      <script
        type="application/ld+json"
        suppressHydrationWarning
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />

      <header className="hero">
        <SiteHeader />
        <div className="hero-grid">
          <section className="hero-copy" aria-labelledby="home-title">
            <div className="brand-kicker">
              <img src={siteHref("/product/app-icon.png")} alt="" />
              <span>大乘</span>
            </div>
            <h1 id="home-title">法布施</h1>
            <p className="hero-subtitle">{brand.tagline}</p>
            <div className="hero-actions">
              {directChannel ? (
                <DownloadLink className="primary-action" channel={directChannel}>
                  {primaryLabel}
                </DownloadLink>
              ) : (
                <a className="primary-action" href={siteHref("/download")}>
                  {primaryLabel}
                </a>
              )}
              <a className="secondary-action" href={siteHref("/apply")}>
                申请测试
              </a>
            </div>

            <div className="release-pill-grid" aria-label="当前下载状态">
              {channels.length > 0 ? (
                channels.map((item) => (
                  <DownloadLink
                    key={`${item.audience}-${item.platform}`}
                    className="release-pill"
                    channel={item}
                  >
                    <span>{item.title}</span>
                    <strong>{item.status}</strong>
                  </DownloadLink>
                ))
              ) : (
                <a className="release-pill" href={siteHref("/download")}>
                  <span>下载入口</span>
                  <strong>同步中</strong>
                </a>
              )}
            </div>
          </section>

          <section className="hero-visual" aria-label="大乘 产品预览">
            <ZenOrbit />
            <div className="phone-stack">
              <div className="phone-frame main-phone poster-frame">
                <img src={siteHref(HERO_MAIN_IMAGE)} alt="大乘 全球法布施功能海报" />
              </div>
              <div className="phone-frame side-phone poster-frame">
                <img src={siteHref(HERO_SIDE_IMAGE)} alt="大乘 共修小组功能海报" />
              </div>
            </div>
          </section>
        </div>
      </header>

      <section className="band compact-band" id="download">
        <div className="section-heading tight">
          <p>下载</p>
          <h2>按你的平台进入。</h2>
        </div>
        <div className="platform-strip">
          {channels.map((item) => (
            <DownloadLink
              key={`${item.audience}-${item.platform}`}
              className="platform-row"
              channel={item}
            >
              <div>
                <span className="platform-name">{item.title}</span>
                <p>{item.description}</p>
              </div>
              <div className="platform-meta">
                <strong>{item.status}</strong>
                <span>{item.primaryLabel}</span>
              </div>
            </DownloadLink>
          ))}
          <a className="platform-row accent-row" href={siteHref("/download")}>
            <div>
              <span className="platform-name">全部入口</span>
              <p>查看 Android、iOS、正式版和镜像说明。</p>
            </div>
            <div className="platform-meta">
              <strong>下载页</strong>
              <span>进入</span>
            </div>
          </a>
        </div>
      </section>

      <section className="band feature-band" id="features">
        <div className="section-heading tight">
          <p>体验</p>
          <h2>留下真正有用的信息。</h2>
        </div>
        <div className="feature-grid">
          {homeHighlights.map((item) => (
            <article key={item.title} className="feature-card">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band product-band">
        <div className="section-heading tight">
          <p>预览</p>
          <h2>官网截图全部改为手动精选版本。</h2>
        </div>
        <div className="moment-grid showcase-grid">
          {productMoments.map((item) => (
            <article key={item.title} className="moment-card">
              <div className="moment-image">
                <img src={siteHref(item.image)} alt={`${item.title}界面海报`} loading="lazy" />
              </div>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band faq-band" id="faq">
        <div className="section-heading tight">
          <p>FAQ</p>
          <h2>先回答最关键的。</h2>
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
            查看全部常见问题
          </a>
          <a className="secondary-action" href={`mailto:${supportEmail}`}>
            联系支持
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
