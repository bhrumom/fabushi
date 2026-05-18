import type { Metadata } from "next";
import { brand, contactChannels } from "@fabushi/shared";
import { DownloadLink } from "../components/download-link";
import { LocalizedText } from "../components/localized-text";
import { SiteFooter } from "../components/site-footer";
import { SiteHeader } from "../components/site-header";
import { ZenOrbit } from "../components/zen-orbit";
import {
  FALLBACK_SCREENSHOTS,
  getOfficialSiteReleaseCollection,
  type OfficialSiteChannel,
  type OfficialSiteScreenshots,
} from "../lib/official-site-releases";
import {
  getUserFacingDescription,
  getUserFacingStatus,
} from "../lib/channel-display";
import { siteHref, siteUrl } from "../lib/site-url";

const SCREENSHOT_KEYS = [
  "global-dharma",
  "start-meditation",
  "immersive-meditation",
  "main-sutra",
  "group-practice",
  "global-ranking",
  "global-donation",
  "global-donation-leaderboard",
] as const;
type ProductScreenshotKey = (typeof SCREENSHOT_KEYS)[number];

interface ProductScreenshot {
  titleZh: string;
  titleEn: string;
  descriptionZh: string;
  descriptionEn: string;
  screenshot: ProductScreenshotKey;
  alt: string;
}

const HERO_MAIN_IMAGE_KEY: ProductScreenshotKey = "global-dharma";
const HERO_SIDE_IMAGE_KEY: ProductScreenshotKey = "main-sutra";
const homeUrl = siteUrl("/");
const homeTitle = `全球法布施 App 下载与修行工具首页 | ${brand.name}`;
const homeDescription =
  "全球法布施是法布施大乘 App 的官网首页，集中展示下载入口、核心界面、禅修听诵与佛经学习功能，以及版本、支持与常见问题。";

const APP_SCREENSHOTS: ProductScreenshot[] = [
  {
    titleZh: "全球法布施总览",
    titleEn: "Global Dharma Overview",
    descriptionZh: "把法布施、修行和学习入口收在同一套界面里。",
    descriptionEn: "Bring giving, practice, and learning into one interface.",
    screenshot: "global-dharma",
    alt: "Fabushi global dharma overview screenshot",
  },
  {
    titleZh: "开始禅修",
    titleEn: "Start Meditation",
    descriptionZh: "更轻地进入一次练习，不需要先做复杂设置。",
    descriptionEn: "Enter a session lightly without a complex setup first.",
    screenshot: "start-meditation",
    alt: "Fabushi start meditation screenshot",
  },
  {
    titleZh: "沉浸式练习",
    titleEn: "Immersive Practice",
    descriptionZh: "让一次安静练习更容易稳定留下来。",
    descriptionEn: "Make a quiet session easier to sustain.",
    screenshot: "immersive-meditation",
    alt: "Fabushi immersive meditation screenshot",
  },
  {
    titleZh: "主修功课",
    titleEn: "Main Practice",
    descriptionZh: "把当前最重要的功课固定在自己眼前。",
    descriptionEn: "Keep the main practice path visible every day.",
    screenshot: "main-sutra",
    alt: "Fabushi main practice screenshot",
  },
  {
    titleZh: "共修小组",
    titleEn: "Group Practice",
    descriptionZh: "把申请、加入和共修关系放回一条清楚的路径里。",
    descriptionEn: "Keep applying, joining, and practicing together on one clear path.",
    screenshot: "group-practice",
    alt: "Fabushi group practice screenshot",
  },
  {
    titleZh: "全球修行排行",
    titleEn: "Global Rankings",
    descriptionZh: "更直观看见修行进度与同行者节奏。",
    descriptionEn: "See progress and community rhythm more clearly.",
    screenshot: "global-ranking",
    alt: "Fabushi global rankings screenshot",
  },
  {
    titleZh: "全球法布施入口",
    titleEn: "Giving Entry",
    descriptionZh: "把善意送往世界各地，而不是只停在本地。",
    descriptionEn: "Let giving travel farther than one local circle.",
    screenshot: "global-donation",
    alt: "Fabushi global donation screenshot",
  },
  {
    titleZh: "法布施榜单",
    titleEn: "Giving Leaderboard",
    descriptionZh: "看见法布施参与的持续性与回响。",
    descriptionEn: "See the continuity and response around giving.",
    screenshot: "global-donation-leaderboard",
    alt: "Fabushi donation leaderboard screenshot",
  },
] as const;

const PRODUCT_BENEFITS = [
  {
    titleZh: "把修行入口留在手机里",
    titleEn: "Keep practice close at hand",
    descriptionZh: "禅修、听诵、佛经与日常节奏可以在同一个 App 里接起来，不需要来回切换很多工具。",
    descriptionEn: "Meditation, listening, sutras, and daily rhythm stay in one app instead of across many tools.",
  },
  {
    titleZh: "先看懂核心界面，再决定要不要下载",
    titleEn: "See the product before you install",
    descriptionZh: "首页直接把关键界面完整摆出来，让人先看清真实体验，而不是只看口号。",
    descriptionEn: "The homepage shows the key screens up front so people can inspect the actual experience first.",
  },
  {
    titleZh: "下载、支持与版本信息放在同一条线里",
    titleEn: "Download, support, and release info stay together",
    descriptionZh: "正式版、测试版、下载说明和支持方式都留在官网，不让安装过程变成找入口。",
    descriptionEn: "Stable, beta, download notes, and support all stay on the site so installation does not turn into a hunt.",
  },
] as const;

const HOME_FAQS = [
  {
    questionZh: "首页现在最适合先做什么？",
    questionEn: "What is the homepage best for now?",
    answerZh: "首页现在主要承担四件事：说明 App 是什么、促成下载、完整展示核心界面，以及给出最基础的支持与信任信息。内容类入口已经收回到顶部导航和底部导航。",
    answerEn: "The homepage now focuses on four jobs: explain the app, support download, show the core screens, and provide basic support and trust signals. Content entry points have been pushed back into the header and footer.",
  },
  {
    questionZh: "我应该从首页直接下载，还是先去下载页？",
    questionEn: "Should I download from the homepage or open the download page first?",
    answerZh: "如果你已经知道自己要安装，可以直接从首页进入下载；如果你还想看版本、镜像和更新说明，再继续进入独立下载页会更稳。",
    answerEn: "If you already know you want to install, the homepage is enough to start. If you want version notes, mirrors, and release details first, the dedicated download page is the steadier next step.",
  },
  {
    questionZh: "官网为什么不再把首页做成资讯或内容门户？",
    questionEn: "Why is the homepage no longer treated like a news or content portal?",
    answerZh: "因为首页权重最高，也最直接影响下载转化。把资讯、专题和学习内容入口收进顶部与底部导航后，首页主体可以更专注地把产品说清楚、把下载链路做顺。",
    answerEn: "Because the homepage carries the strongest authority and the clearest download intent. Once news, topic, and learning entry points move back into the header and footer, the homepage body can focus on product clarity and conversion.",
  },
] as const;

function resolveScreenshot(screenshots: OfficialSiteScreenshots, key: ProductScreenshotKey) {
  return screenshots[key] ?? FALLBACK_SCREENSHOTS[key];
}

function formatPublishedAt(value?: string) {
  if (!value) {
    return null;
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toISOString().slice(0, 10);
}

function getChannelActionCopy(channel: OfficialSiteChannel) {
  if (channel.platform === "iOS") {
    return {
      zh: channel.audience === "beta" ? "下载 iOS 测试版" : "下载 iOS 正式版",
      en: channel.audience === "beta" ? "Download iOS Beta" : "Download iOS Stable",
    };
  }

  return {
    zh: channel.audience === "beta" ? "下载 Android 测试版" : "下载 Android 正式版",
    en: channel.audience === "beta" ? "Download Android Beta" : "Download Android Stable",
  };
}

export const metadata: Metadata = {
  title: homeTitle,
  description: homeDescription,
  alternates: {
    canonical: homeUrl,
  },
  keywords: [
    "全球法布施",
    "法布施大乘",
    "Fabushi app",
    "佛教 app 下载",
    "禅修 app",
    "佛经听诵 app",
    "学佛 app",
    "佛法修行工具",
  ],
  openGraph: {
    title: homeTitle,
    description: homeDescription,
    url: homeUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: homeTitle,
    description: homeDescription,
  },
};

export default async function HomePage() {
  const releaseCollection = await getOfficialSiteReleaseCollection();
  const screenshots = {
    ...FALLBACK_SCREENSHOTS,
    ...releaseCollection.screenshots,
  };
  const channels = [...releaseCollection.betaChannels, ...releaseCollection.stableChannels].slice(0, 2);
  const supportEmail =
    contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@ombhrum.com";
  const latestRelease = releaseCollection.releases[0] ?? null;

  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "全球法布施首页",
        url: homeUrl,
        description: homeDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: homeUrl,
        },
      },
      {
        "@type": "Organization",
        name: `${brand.name} Fabushi`,
        url: homeUrl,
        email: supportEmail,
        description: "Fabushi offers meditation, sutra listening, and global giving.",
      },
      {
        "@type": "SoftwareApplication",
        name: `${brand.name} Fabushi`,
        applicationCategory: "LifestyleApplication",
        operatingSystem: "iOS, Android",
        downloadUrl: siteUrl("/download"),
        description: homeDescription,
        screenshot: APP_SCREENSHOTS.map((item) => siteUrl(resolveScreenshot(screenshots, item.screenshot))),
      },
      {
        "@type": "FAQPage",
        mainEntity: HOME_FAQS.map((item) => ({
          "@type": "Question",
          name: item.questionZh,
          acceptedAnswer: {
            "@type": "Answer",
            text: item.answerZh,
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
              <span>
                <LocalizedText zh="法布施大乘 App" en="Fabushi App" />
              </span>
            </div>
            <h1 id="home-title">
              <LocalizedText zh="全球法布施" en="Global Dharma Sharing" />
            </h1>
            <p className="hero-subtitle">
              <LocalizedText
                zh="把禅修、听诵、佛经学习与全球法布施放进同一个 App，先看清界面，再决定下载。"
                en="Bring meditation, listening, sutra study, and global giving into one app, then decide to download after seeing the interface clearly."
              />
            </p>
            <div className="hero-actions">
              <a className="primary-action" href={siteHref("/download")}>
                <LocalizedText zh="下载 App" en="Download App" />
              </a>
              <a className="secondary-action" href={siteHref("/download#release-changelog")}>
                <LocalizedText zh="查看版本说明" en="View release notes" />
              </a>
            </div>
            <div className="release-pill-grid" aria-label="Quick service entry / 服务入口">
              {channels.length > 0 ? (
                channels.map((item) => {
                  const statusCopy = getUserFacingStatus(item);
                  const actionCopy = getChannelActionCopy(item);
                  const publishedAt = formatPublishedAt(item.publishedAt);
                  return (
                    <DownloadLink
                      key={`${item.audience}-${item.platform}`}
                      className="release-pill"
                      channel={item}
                    >
                      <span>{item.title}</span>
                      <strong>
                        <LocalizedText zh={statusCopy.zh} en={statusCopy.en} />
                      </strong>
                      {(item.version || publishedAt) && (
                        <small>
                          {item.version ? `v${item.version}` : ""}
                          {item.version && publishedAt ? " · " : ""}
                          {publishedAt ?? ""}
                        </small>
                      )}
                      <em>
                        <LocalizedText zh={actionCopy.zh} en={actionCopy.en} />
                      </em>
                    </DownloadLink>
                  );
                })
              ) : (
                <a className="release-pill" href={siteHref("/download")}>
                  <span>
                    <LocalizedText zh="App 下载" en="App Download" />
                  </span>
                  <strong>
                    <LocalizedText zh="查看全部下载入口" en="See all download paths" />
                  </strong>
                </a>
              )}
            </div>
          </section>

          <section className="hero-visual" aria-label="Fabushi product preview">
            <ZenOrbit />
            <div className="phone-stack">
              <div className="phone-frame main-phone poster-frame">
                <img
                  src={siteHref(resolveScreenshot(screenshots, HERO_MAIN_IMAGE_KEY))}
                  alt="Fabushi homepage screenshot"
                />
              </div>
              <div className="phone-frame side-phone poster-frame">
                <img
                  src={siteHref(resolveScreenshot(screenshots, HERO_SIDE_IMAGE_KEY))}
                  alt="Fabushi feature preview screenshot"
                />
              </div>
            </div>
          </section>
        </div>
      </header>

      <section className="band alt product-band" id="app-screenshots">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="App 截图" en="App Screens" />
          </p>
          <h2>
            <LocalizedText
              zh="先把关键界面尽量完整地摆出来，让首页直接承担理解与转化。"
              en="Show the key screens as fully as possible so the homepage carries both understanding and conversion."
            />
          </h2>
        </div>
        <div className="moment-grid showcase-grid">
          {APP_SCREENSHOTS.map((item) => (
            <article key={item.titleEn} className="moment-card guide-card">
              <div className="moment-image">
                <img
                  src={siteHref(resolveScreenshot(screenshots, item.screenshot))}
                  alt={item.alt}
                  loading="lazy"
                />
              </div>
              <h3>
                <LocalizedText zh={item.titleZh} en={item.titleEn} />
              </h3>
              <p>
                <LocalizedText zh={item.descriptionZh} en={item.descriptionEn} />
              </p>
            </article>
          ))}
        </div>
      </section>

      <section className="band" id="product-value">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="产品说明" en="Product Value" />
          </p>
          <h2>
            <LocalizedText
              zh="首页只把最该知道的三件事讲清楚。"
              en="Keep the homepage focused on the three things people most need to understand."
            />
          </h2>
        </div>
        <div className="editorial-list">
          {PRODUCT_BENEFITS.map((item) => (
            <article key={item.titleEn} className="editorial-row">
              <span>
                <LocalizedText zh="核心价值" en="Core Value" />
              </span>
              <div>
                <strong>
                  <LocalizedText zh={item.titleZh} en={item.titleEn} />
                </strong>
                <p>
                  <LocalizedText zh={item.descriptionZh} en={item.descriptionEn} />
                </p>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt" id="service-entry">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="下载与支持" en="Download and Support" />
          </p>
          <h2>
            <LocalizedText
              zh="把下载、版本、支持和最基础的信任信息放回同一个服务区。"
              en="Keep download, release details, support, and the basic trust signals inside one service zone."
            />
          </h2>
        </div>
        <div className="platform-strip">
          {channels.map((item) => {
            const descriptionCopy = getUserFacingDescription(item);
            const statusCopy = getUserFacingStatus(item);
            const actionCopy = getChannelActionCopy(item);
            const publishedAt = formatPublishedAt(item.publishedAt);
            return (
              <DownloadLink
                key={`${item.audience}-${item.platform}`}
                className="platform-row detailed"
                channel={item}
              >
                <div>
                  <span className="platform-name">{item.title}</span>
                  <p>
                    <LocalizedText zh={descriptionCopy.zh} en={descriptionCopy.en} />
                  </p>
                  {(item.version || publishedAt) && (
                    <div className="platform-detail-line">
                      {item.version ? <span>v{item.version}</span> : null}
                      {publishedAt ? <span>{publishedAt}</span> : null}
                    </div>
                  )}
                </div>
                <div className="platform-meta">
                  <strong>
                    <LocalizedText zh={statusCopy.zh} en={statusCopy.en} />
                  </strong>
                  <span>
                    <LocalizedText zh={actionCopy.zh} en={actionCopy.en} />
                  </span>
                </div>
              </DownloadLink>
            );
          })}
          <a className="platform-row accent-row" href={siteHref("/download")}>
            <div>
              <span className="platform-name">
                <LocalizedText zh="全部下载入口" en="All Downloads" />
              </span>
              <p>
                <LocalizedText zh="进入独立下载页，查看正式版、测试版、镜像和更新日志。" en="Open the dedicated download page for stable, beta, mirror links, and release notes." />
              </p>
            </div>
            <div className="platform-meta">
              <strong>
                <LocalizedText zh="下载页" en="Download Page" />
              </strong>
              <span>
                <LocalizedText zh="进入" en="Open" />
              </span>
            </div>
          </a>
        </div>
        <div className="note-grid">
          <p>
            <LocalizedText
              zh={latestRelease ? `最近版本：${latestRelease.title}` : "最近版本与下载说明会同步更新到官网下载页。"}
              en={latestRelease ? `Latest release: ${latestRelease.title}` : "Latest release notes stay synced on the official download page."}
            />
          </p>
          <p>
            <LocalizedText zh={`下载或安装遇到问题，可联系 ${supportEmail}。`} en={`If download or install fails, contact ${supportEmail}.`} />
          </p>
          <p>
            <LocalizedText zh="隐私说明、FAQ 和官网资讯保留在导航中，不再挤进首页主体里。" en="Privacy, FAQ, and site news stay in navigation instead of crowding the homepage body." />
          </p>
        </div>
      </section>

      <section className="band faq-band" id="faq">
        <div className="section-heading tight">
          <p>FAQ</p>
          <h2>
            <LocalizedText
              zh="只保留最直接影响下载理解的几个问题。"
              en="Keep only the questions that most directly support understanding and download intent."
            />
          </h2>
        </div>
        <div className="faq-list">
          {HOME_FAQS.map((item) => (
            <details key={item.questionEn} className="faq-item">
              <summary>
                <LocalizedText zh={item.questionZh} en={item.questionEn} />
              </summary>
              <p>
                <LocalizedText zh={item.answerZh} en={item.answerEn} />
              </p>
            </details>
          ))}
        </div>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/faq")}>
            <LocalizedText zh="查看全部常见问题" en="View all FAQs" />
          </a>
          <a className="secondary-action" href={`mailto:${supportEmail}`}>
            <LocalizedText zh="联系支持" en="Contact support" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
