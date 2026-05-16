import type { Metadata } from "next";
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
const homeUrl = siteUrl("/");
const homeTitle = `学佛从哪里开始、修行方法与佛经学习 | ${brand.name}`;
const homeDescription =
  "Fabushi 提供学佛从哪里开始、佛法入门、修行方法总览、日常功课安排、佛经导读与初学者佛经推荐，以及经文听诵、禅修、修行记录和下载入口。";

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
    questionZh: "学佛从哪里开始，才不会一开始就太重？",
    questionEn: "How can I begin buddhadharma without making it too heavy immediately?",
    answerZh: "更稳的起点通常不是一下子学很多，而是先看清自己当下最需要的入口。可以先从“学佛从哪里开始”理清方向，再决定先走佛法入门、修行方法，还是佛经导读。",
    answerEn: "A steadier beginning is usually not to learn everything at once, but to clarify the doorway that matches your present question. Start with where to begin, then decide whether dharma basics, practice methods, or sutra study should come first.",
  },
  {
    questionZh: "先读经、先禅修，还是先把日常功课排出来？",
    questionEn: "Should I begin with sutras, meditation, or a daily routine?",
    answerZh: "更重要的是看你当下最需要什么。如果需要方向感，可以先看佛法入门或佛经导读；如果需要把练习留在生活里，可以先看修行方法总览和日常功课安排。",
    answerEn: "The better question is what you need most right now. If you need orientation, begin with dharma basics or the sutra guide. If you need practice to stay inside daily life, begin with the practice guide and daily routine page.",
  },
  {
    questionZh: "日常功课是不是一定要排得很满才算认真？",
    questionEn: "Does a daily practice routine need to be full to count as sincere?",
    answerZh: "不一定。对初学者来说，轻一点、稳一点、能继续做下去，通常比一开始排得很满更有帮助。先让一两个真实动作留下来，再慢慢扩展，往往更稳。",
    answerEn: "Not necessarily. For beginners, lighter, steadier, and sustainable usually helps more than a full schedule on day one. Let one or two real actions remain first, then expand gradually.",
  },
  {
    questionZh: "初学者先读什么佛经会更合适？",
    questionEn: "Which sutra is a better first choice for beginners?",
    answerZh: "可以先按自己现在最想弄明白的问题来选，而不是只按名气来选。想先熟悉佛法常见词汇，可以从《心经》或导读开始；想从愿心、念佛或安住感进入，也可以先看《阿弥陀经》或《普门品》的相关说明。",
    answerEn: "It usually helps to choose by the question you are actually living with instead of fame alone. The Heart Sutra can be a good start for familiar language, while the Amitabha Sutra or Universal Gate Chapter may fit better if aspiration, recitation, or steadiness feel closer.",
  },
] as const;

const DHARMA_PATHS = [
  {
    href: "/start-learning-buddhism",
    labelZh: "学佛从哪里开始",
    labelEn: "Where to Begin",
    titleZh: "先把学佛的第一步放轻一点、放清楚一点。",
    titleEn: "Make the first step into buddhadharma lighter and clearer.",
    descriptionZh: "如果你最关心的是先读经、先禅修，还是先建立日常节奏，这一页会更直接地回答。",
    descriptionEn: "If your main question is whether to begin with sutras, meditation, or a daily rhythm, this page answers it more directly.",
  },
  {
    href: "/buddhadharma",
    labelZh: "佛法入门",
    labelEn: "Dharma Basics",
    titleZh: "先看清佛法、修行与日常实践之间的关系。",
    titleEn: "See how buddhadharma, practice, and daily life fit together.",
    descriptionZh: "如果你想先理清佛法是什么、佛教与修行有什么关系，这里是更完整的入门地图。",
    descriptionEn: "If you first need to clarify what buddhadharma is and how Buddhism relates to practice, this is the broader beginner map.",
  },
  {
    href: "/meditation",
    labelZh: "禅修入门",
    labelEn: "Meditation Guide",
    titleZh: "把禅修变成短时、稳定、可持续的日常练习。",
    titleEn: "Turn meditation into a short, steady, sustainable daily rhythm.",
    descriptionZh: "如果你更关心禅修怎么开始、一次多久、分心怎么办，这一页会更具体。",
    descriptionEn: "If your question is how to begin meditation, how long to sit, or what to do with distraction, this page goes deeper.",
  },
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "先把禅修、听诵、念佛、阅读和记录放回同一张地图里。",
    titleEn: "Place meditation, listening, recitation, reading, and notes back onto one map.",
    descriptionZh: "如果你已经知道要开始练习，但还不清楚这些方法该怎么配合，这一页更适合先打开。",
    descriptionEn: "Open this first if you know you want to practice but still need a clearer map for how the methods support each other.",
  },
  {
    href: "/daily-practice",
    labelZh: "日常功课怎么安排",
    labelEn: "Daily Practice",
    titleZh: "把晨起、白天和晚间的轻量功课慢慢接起来。",
    titleEn: "Connect a lighter morning, daytime, and evening rhythm that can stay alive.",
    descriptionZh: "如果你最关心第一周功课怎么排、白天怎么接进生活，这一页会更具体。",
    descriptionEn: "If your main question is how to arrange the first week and carry practice through the day, this page is more specific.",
  },
  {
    href: "/sutra-guide",
    labelZh: "佛经导读",
    labelEn: "Sutra Guide",
    titleZh: "从读什么、怎么读，到听诵与阅读如何配合。",
    titleEn: "Clarify what to read first and how listening supports reading.",
    descriptionZh: "如果你想知道初学者读什么佛经、经文听诵怎样帮助理解，这一页更适合继续往下看。",
    descriptionEn: "If you want to know which sutra to start with and how listening helps understanding, this is the next page to open.",
  },
  {
    href: "/beginner-sutra-recommendations",
    labelZh: "初学者佛经推荐",
    labelEn: "Beginner Sutra Picks",
    titleZh: "把“先读什么佛经”这个问题单独说明白。",
    titleEn: "Answer the question of which sutra to begin with more directly.",
    descriptionZh: "如果你已经确定想从经典进入，但卡在《心经》《阿弥陀经》《普门品》或《金刚经》之间，这一页更适合继续往下走。",
    descriptionEn: "If scripture already feels like the doorway but you are choosing between the Heart Sutra, Amitabha Sutra, Universal Gate Chapter, or Diamond Sutra, this page goes further.",
  },
] as const;

export const metadata: Metadata = {
  title: homeTitle,
  description: homeDescription,
  alternates: {
    canonical: homeUrl,
  },
  keywords: [
    "学佛从哪里开始",
    "佛法入门",
    "修行方法总览",
    "禅修入门",
    "日常功课怎么安排",
    "佛经导读",
    "初学者先读什么佛经",
    "经文听诵",
    "Fabushi",
    "法布施",
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
        "@type": "ItemList",
        name: "Fabushi 佛法学习路径",
        itemListElement: DHARMA_PATHS.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.labelZh,
          url: siteUrl(item.href),
          description: item.descriptionZh,
        })),
      },
      {
        "@type": "FAQPage",
        mainEntity: FAQ_PREVIEW.map((item) => ({
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

      <section className="band alt" id="dharma-paths">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="学佛路径" en="Dharma Paths" />
          </p>
          <h2>
            <LocalizedText
              zh="先把“从哪里开始”理清，再把更具体的修行与佛经问题接上去。"
              en="Clarify where to start first, then connect the more specific practice and sutra questions."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="很多人第一次接触佛法时，真正卡住的不是没有内容，而是不知道该先理解佛法、先练禅修，还是先读佛经。现在官网已经把这条入门路径拆成了“先回答起步问题，再进入更具体页面”的几层入口。"
              en="When people first meet buddhadharma, the real difficulty is often not a lack of material but not knowing whether to begin with basic understanding, meditation, or sutra study. The site now breaks that path into layers that first answer the beginner question, then move into more specific pages."
            />
          </p>
          <p>
            <LocalizedText
              zh="你可以先从“学佛从哪里开始”回答眼前的问题，再回到佛法入门看整体地图；如果问题已经变成“怎样练得更稳”或“先读什么佛经”，就直接继续进入修行方法总览、日常功课安排，或初学者佛经推荐这些第二层页面。"
              en="You can begin with the page that answers where to start, then return to dharma basics for the broader map. If the question has already become how to practice more steadily or which sutra to begin with, move straight into the practice guide, daily routine page, or beginner sutra picks."
            />
          </p>
        </div>
        <div className="editorial-list">
          {DHARMA_PATHS.map((item) => (
            <a key={item.href} className="editorial-row" href={siteHref(item.href)}>
              <span>
                <LocalizedText zh={item.labelZh} en={item.labelEn} />
              </span>
              <div>
                <strong>
                  <LocalizedText zh={item.titleZh} en={item.titleEn} />
                </strong>
                <p>
                  <LocalizedText zh={item.descriptionZh} en={item.descriptionEn} />
                </p>
              </div>
            </a>
          ))}
        </div>
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/start-learning-buddhism")}>
            <LocalizedText zh="先看学佛从哪里开始" en="Start with Where to Begin" />
          </a>
          <a className="secondary-action" href={siteHref("/practice-guide")}>
            <LocalizedText zh="继续看修行方法总览" en="Continue to the Practice Guide" />
          </a>
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
            <LocalizedText
              zh="先把初学者最常卡住的几个问题说清楚。"
              en="Clarify the questions beginners most often get stuck on first."
            />
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
