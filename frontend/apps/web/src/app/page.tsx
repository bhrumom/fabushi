import { brand, contactChannels } from "@fabushi/shared";
import { DownloadLink } from "../components/download-link";
import { LocalizedText } from "../components/localized-text";
import { SiteFooter } from "../components/site-footer";
import { SiteHeader } from "../components/site-header";
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
import { ZenOrbit } from "../components/zen-orbit";

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

interface ProductMoment {
  titleZh: string;
  titleEn: string;
  descriptionZh: string;
  descriptionEn: string;
  screenshot: ProductScreenshotKey;
  alt: string;
}

const HERO_MAIN_IMAGE_KEY: ProductScreenshotKey = "global-dharma";
const HERO_SIDE_IMAGE_KEY: ProductScreenshotKey = "main-sutra";

const PRODUCT_MOMENTS: ProductMoment[] = [
  {
    titleZh: "全球法布施",
    titleEn: "Global Giving",
    descriptionZh: "看见善意如何跨越地域，直接抵达世界各地。",
    descriptionEn: "See compassion travel across regions and reach people around the world.",
    screenshot: "global-dharma",
    alt: "Fabushi global dharma screen",
  },
  {
    titleZh: "随时随地开始修行",
    titleEn: "Start Practicing Anytime",
    descriptionZh: "打开就能进入禅修状态，把修行节奏留在日常里。",
    descriptionEn: "Open the app and return to practice without friction.",
    screenshot: "start-meditation",
    alt: "Fabushi meditation entry screen",
  },
  {
    titleZh: "沉浸式禅修体验",
    titleEn: "Immersive Meditation",
    descriptionZh: "用更安静、更专注的界面承接每一次练习。",
    descriptionEn: "A calmer, more focused interface for each meditation session.",
    screenshot: "immersive-meditation",
    alt: "Fabushi immersive meditation screen",
  },
  {
    titleZh: "锁定主修功课",
    titleEn: "Keep Your Main Practice Stable",
    descriptionZh: "先确定主线，再围绕自己的路径稳定推进。",
    descriptionEn: "Choose a main path first, then keep steady progress around it.",
    screenshot: "main-sutra",
    alt: "Fabushi main practice screen",
  },
  {
    titleZh: "轻松加入共修小组",
    titleEn: "Join Group Practice Easily",
    descriptionZh: "搜索、申请、加入和管理共修关系都放在同一条路径里。",
    descriptionEn: "Search, apply, join, and manage group practice from one flow.",
    screenshot: "group-practice",
    alt: "Fabushi group practice screen",
  },
  {
    titleZh: "全球修行排行",
    titleEn: "Global Practice Rankings",
    descriptionZh: "修行进度和榜单变化一眼可见，方便持续跟进。",
    descriptionEn: "Track progress and ranking changes at a glance.",
    screenshot: "global-ranking",
    alt: "Fabushi practice ranking screen",
  },
  {
    titleZh: "全球布施排行",
    titleEn: "Global Donation Activity",
    descriptionZh: "实时查看全球布施动态，感受功德流动。",
    descriptionEn: "Follow donation activity in real time and see merit in motion.",
    screenshot: "global-donation",
    alt: "Fabushi donation activity screen",
  },
];

const FEATURE_HIGHLIGHTS = [
  {
    titleZh: "经文与禅修放在同一处",
    titleEn: "Sutras and meditation in one place",
    descriptionZh: "减少切换成本，让修行从打开应用开始就更顺。",
    descriptionEn: "Reduce context switching so practice starts smoothly the moment the app opens.",
  },
  {
    titleZh: "下载前先看清版本",
    titleEn: "See the version before you download",
    descriptionZh: "首页直接告诉你平台、版本号、发布时间和最近更新。",
    descriptionEn: "The homepage shows the platform, version, publish date, and latest updates before you tap download.",
  },
  {
    titleZh: "下载入口按平台组织",
    titleEn: "Platform-aware download entry",
    descriptionZh: "Android、iOS 和镜像入口分开呈现，减少误点。",
    descriptionEn: "Android, iOS, and mirror links are separated so the right path is easier to choose.",
  },
  {
    titleZh: "全球善行有反馈",
    titleEn: "Global feedback loop",
    descriptionZh: "排行榜、布施动态和共修小组让持续修行更有回应。",
    descriptionEn: "Rankings, donation activity, and group practice create a stronger feedback loop.",
  },
] as const;

const FAQ_PREVIEW = [
  {
    questionZh: "我应该下载哪个版本？",
    questionEn: "Which version should I download?",
    answerZh: "想尽快体验新功能，先下测试版；更重视稳定性，就等正式版。",
    answerEn: "Choose beta if you want the newest features quickly. Wait for stable if you prefer a calmer release.",
  },
  {
    questionZh: "iOS 为什么会跳到 TestFlight？",
    questionEn: "Why does iOS open TestFlight?",
    answerZh: "iOS 内测通过 Apple TestFlight 分发，公开加入后官网会直接带你过去。",
    answerEn: "iOS beta builds are distributed through Apple TestFlight, and the site takes you there when public access is ready.",
  },
  {
    questionZh: "Android 下载慢怎么办？",
    questionEn: "What if Android downloads are slow?",
    answerZh: "国内网络环境下可以优先尝试镜像入口，原始链接仍会保留。",
    answerEn: "If the original Android download is slow, try the mirror links first. The original link stays available too.",
  },
  {
    questionZh: "官网会显示我下载的是哪个版本吗？",
    questionEn: "Will the site show which version I am downloading?",
    answerZh: "会。首页和下载页都会显示版本号、发布时间和最近更新。",
    answerEn: "Yes. The homepage and download page both show the version, publish date, and recent updates.",
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

export default async function HomePage() {
  const releaseCollection = await getOfficialSiteReleaseCollection();
  const screenshots = {
    ...FALLBACK_SCREENSHOTS,
    ...releaseCollection.screenshots,
  };
  const channels = [...releaseCollection.betaChannels, ...releaseCollection.stableChannels].slice(0, 3);
  const supportEmail = contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@ombhrum.com";
  const androidBetaChannel = releaseCollection.betaChannels.find((item) => item.platform === "Android");
  const iosBetaChannel = releaseCollection.betaChannels.find((item) => item.platform === "iOS");
  const latestRelease = releaseCollection.releases[0];

  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        name: `${brand.name} Fabushi`,
        url: siteUrl("/"),
        email: supportEmail,
        description: "Fabushi offers meditation, sutra listening, and global giving.",
      },
      {
        "@type": "SoftwareApplication",
        name: `${brand.name} Fabushi`,
        applicationCategory: "LifestyleApplication",
        operatingSystem: "iOS, Android, Web",
        url: siteUrl("/download"),
        description: "Meditation, sutra listening, and global dharma sharing.",
      },
      {
        "@type": "FAQPage",
        mainEntity: FAQ_PREVIEW.map((item) => ({
          "@type": "Question",
          name: item.questionEn,
          acceptedAnswer: {
            "@type": "Answer",
            text: item.answerEn,
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
                <LocalizedText zh="大乘" en="Fabushi" />
              </span>
            </div>
            <h1 id="home-title">
              <LocalizedText zh="法布施" en="Dharma Sharing" />
            </h1>
            <p className="hero-subtitle">
              <LocalizedText
                zh="经文听诵、禅修、法流视频、修行记录与全球法布施。"
                en="Sutra listening, meditation, dharma videos, practice tracking, and global giving in one place."
              />
            </p>
            <div className="hero-actions">
              {androidBetaChannel ? (
                <DownloadLink className="primary-action" channel={androidBetaChannel}>
                  <LocalizedText zh="下载 Android 测试版" en="Download Android Beta" />
                </DownloadLink>
              ) : (
                <a className="primary-action" href={siteHref("/download")}>
                  <LocalizedText zh="查看下载入口" en="View downloads" />
                </a>
              )}
              {iosBetaChannel ? (
                <DownloadLink className="primary-action" channel={iosBetaChannel}>
                  <LocalizedText zh="下载 iOS 测试版" en="Download iOS Beta" />
                </DownloadLink>
              ) : (
                <a className="secondary-action" href={siteHref("/apply")}>
                  <LocalizedText zh="申请测试" en="Apply for beta" />
                </a>
              )}
            </div>

            <div className="release-pill-grid" aria-label="Current download status / 当前下载状态">
              {channels.length > 0 ? (
                channels.map((item) => {
                  const titleCopy = item.title;
                  const actionCopy = getChannelActionCopy(item);
                  const statusCopy = getUserFacingStatus(item);
                  const publishedAt = formatPublishedAt(item.publishedAt);
                  return (
                    <DownloadLink
                      key={`${item.audience}-${item.platform}`}
                      className="release-pill"
                      channel={item}
                    >
                      <span>{titleCopy}</span>
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
                    <LocalizedText zh="下载入口" en="Downloads" />
                  </span>
                  <strong>
                    <LocalizedText zh="入口整理中" en="Links coming soon" />
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

      <section className="band compact-band" id="download">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="下载" en="Download" />
          </p>
          <h2>
            <LocalizedText zh="按你的平台进入。" en="Pick the path that matches your platform." />
          </h2>
        </div>
        <div className="platform-strip">
          {channels.map((item) => {
            const titleCopy = item.title;
            const actionCopy = getChannelActionCopy(item);
            const descriptionCopy = getUserFacingDescription(item);
            const statusCopy = getUserFacingStatus(item);
            const publishedAt = formatPublishedAt(item.publishedAt);
            return (
              <DownloadLink
                key={`${item.audience}-${item.platform}`}
                className="platform-row detailed"
                channel={item}
              >
                <div>
                  <span className="platform-name">{titleCopy}</span>
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
                <LocalizedText zh="全部入口" en="All downloads" />
              </span>
              <p>
                <LocalizedText
                  zh="查看 Android、iOS、正式版、镜像和最近更新。"
                  en="See Android, iOS, stable, mirror links, and recent updates in one place."
                />
              </p>
            </div>
            <div className="platform-meta">
              <strong>
                <LocalizedText zh="下载页" en="Download page" />
              </strong>
              <span>
                <LocalizedText zh="进入" en="Open" />
              </span>
            </div>
          </a>
        </div>
      </section>

      {latestRelease ? (
        <section className="band alt" id="updates">
          <div className="section-heading tight">
            <p>
              <LocalizedText zh="版本更新" en="Release update" />
            </p>
            <h2>
              <LocalizedText zh="下载前，先看最近版本和更新摘要。" en="Check the latest version and update summary before you download." />
            </h2>
          </div>
          <article className="release-card homepage-release-card">
            <div className="release-card-header">
              <div>
                <p className="eyebrow">
                  <LocalizedText zh="最新版本" en="Latest release" />
                </p>
                <h2>{latestRelease.title}</h2>
              </div>
              {latestRelease.publishedAt ? <span className="download-status">{formatPublishedAt(latestRelease.publishedAt)}</span> : null}
            </div>
            <div className="release-card-meta">
              <span>
                <LocalizedText zh="版本" en="Version" /> {latestRelease.tag}
              </span>
              <span>
                <LocalizedText zh="类型" en="Type" /> <LocalizedText zh="官方更新" en="Official update" />
              </span>
            </div>
            {latestRelease.summary.length > 0 ? (
              <ul className="release-summary-list">
                {latestRelease.summary.slice(0, 4).map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            ) : null}
            <div className="release-card-actions">
              <a className="primary-action" href={siteHref("/download#release-changelog")}>
                <LocalizedText zh="查看完整下载内容说明" en="View full download notes" />
              </a>
              <a className="secondary-action" href={siteHref("/download")}>
                <LocalizedText zh="查看全部下载入口" en="See all downloads" />
              </a>
            </div>
          </article>
        </section>
      ) : null}

      <section className="band feature-band" id="features">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="体验" en="Experience" />
          </p>
          <h2>
            <LocalizedText zh="下载前就先知道真正有用的信息。" en="See the details that matter before you download." />
          </h2>
        </div>
        <div className="feature-grid">
          {FEATURE_HIGHLIGHTS.map((item) => (
            <article key={item.titleEn} className="feature-card">
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

      <section className="band product-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="预览" en="Preview" />
          </p>
          <h2>
            <LocalizedText zh="精选功能截图。" en="Key moments from the product." />
          </h2>
        </div>
        <div className="moment-grid showcase-grid">
          {PRODUCT_MOMENTS.map((item) => (
            <article key={item.titleEn} className="moment-card">
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

      <section className="band faq-band" id="faq">
        <div className="section-heading tight">
          <p>FAQ</p>
          <h2>
            <LocalizedText zh="先回答最关键的。" en="Answer the questions that block people first." />
          </h2>
        </div>
        <div className="faq-list">
          {FAQ_PREVIEW.map((item) => (
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
