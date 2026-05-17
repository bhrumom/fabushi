import type { Metadata } from "next";
import { brand, contactChannels } from "@fabushi/shared";
import { DownloadLink } from "../components/download-link";
import { LocalizedText } from "../components/localized-text";
import { SiteFooter } from "../components/site-footer";
import { SiteHeader } from "../components/site-header";
import { ZenOrbit } from "../components/zen-orbit";
import { getAllArticles } from "../lib/content";
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

interface ProductMoment {
  titleZh: string;
  titleEn: string;
  descriptionZh: string;
  descriptionEn: string;
  screenshot: ProductScreenshotKey;
  alt: string;
}

interface BulletinItem {
  href: string;
  categoryZh: string;
  categoryEn: string;
  titleZh: string;
  titleEn: string;
  descriptionZh: string;
  descriptionEn: string;
}

const HERO_MAIN_IMAGE_KEY: ProductScreenshotKey = "global-dharma";
const HERO_SIDE_IMAGE_KEY: ProductScreenshotKey = "main-sutra";
const homeUrl = siteUrl("/");
const homeTitle = `学佛入门、佛法导读与官网资讯首页 | ${brand.name}`;
const homeDescription =
  "大乘官网首页聚合学佛从哪里开始、佛法入门、佛学基本概念、佛经导读、念佛入门、听诵和读经怎么配合、修行方法、FAQ 与官网最新内容；App 下载保留为清晰服务入口，不再占据首页主叙事。";

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
];

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
    answerZh: "更重要的是看你当下最需要什么。如果需要方向感，可以先看佛法入门；如果常常卡在因果、菩提心、六度、空性这些词，就先看佛学基本概念入门；如果需要把练习留在生活里，再继续看修行方法总览和日常功课安排。",
    answerEn: "The better question is what you need most right now. If you need orientation, begin with dharma basics. If core terms such as karma, bodhicitta, the six paramitas, or emptiness keep stopping you, begin with the concepts hub. If you need practice to stay inside daily life, continue into the practice guide and daily routine page.",
  },
  {
    questionZh: "佛学基本概念应该先看哪几个？",
    questionEn: "Which buddhist concepts should a beginner clarify first?",
    answerZh: "对很多初学者来说，先把因果、菩提心、六度和空性放进同一张地图里，往往比零散地碰到一个算一个更稳。先看概念总览页，再决定自己现在更该先读哪一张概念页，会更容易继续往下走。",
    answerEn: "For many beginners, it is steadier to place karma, bodhicitta, the six paramitas, and emptiness onto one map before treating them as isolated terms. Start with the concepts hub, then decide which concept page matches the question you are living with now.",
  },
  {
    questionZh: "初学者先读什么佛经会更合适？",
    questionEn: "Which sutra is a better first choice for beginners?",
    answerZh: "可以先按自己现在最想弄明白的问题来选，而不是只按名气来选。想先熟悉佛法常见词汇，可以从《心经》或导读开始；想从愿心、念佛或安住感进入，也可以先看《阿弥陀经》或《普门品》的相关说明。",
    answerEn: "It usually helps to choose by the question you are actually living with instead of fame alone. The Heart Sutra can be a good start for familiar language, while the Amitabha Sutra or Universal Gate Chapter may fit better if aspiration, recitation, or steadiness feel closer.",
  },
  {
    questionZh: "念佛入门是不是要一开始就念很多遍？",
    questionEn: "Does beginner recitation need a large count right away?",
    answerZh: "通常不需要。对多数初学者来说，更稳的起点往往是先让一句佛号和一个固定时段留下来，再慢慢把白天的短回返点接进去。入口够轻，念佛才更容易真的回到生活里，而不是只剩下任务感。",
    answerEn: "Usually not. For most beginners, the steadier start is to let one phrase and one stable time of day stay first, then gradually add one short daytime return. When the doorway stays light, recitation is more likely to enter life instead of becoming only a task.",
  },
  {
    questionZh: "已经在通勤里听经了，下一步怎样不只停在背景声音里？",
    questionEn: "If I already listen during commutes, how do I keep it from staying only in the background?",
    answerZh: "更稳的下一步通常不是继续换更多音频，而是隔一两天回到同一段内容，再读一小段原文或导读，最后留一句记录。这样听诵、阅读和日常节奏才会真正接成同一条线。",
    answerEn: "A steadier next step is usually not switching to more audio, but returning to the same passage after a day or two, reading a short section of the text or guide, and leaving one short note. That is how listening, reading, and daily rhythm begin forming one line together.",
  },
] as const;

const HERO_GUIDE_LINKS = [
  {
    href: "/insights",
    zh: "官网资讯",
    en: "Site News",
  },
  {
    href: "/start-learning-buddhism",
    zh: "学佛从哪里开始",
    en: "Where to Begin",
  },
  {
    href: "/buddhist-concepts",
    zh: "佛学基本概念",
    en: "Buddhist Concepts",
  },
  {
    href: "/sutra-guide",
    zh: "佛经导读",
    en: "Sutra Guide",
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
    href: "/buddhist-concepts",
    labelZh: "佛学基本概念入门",
    labelEn: "Buddhist Concepts",
    titleZh: "先把因果、菩提心、六度和空性放回同一张概念地图里。",
    titleEn: "Place karma, bodhicitta, the six paramitas, and emptiness back on one concept map.",
    descriptionZh: "如果你已经发现自己总被这些名相反复挡住，却还看不清它们彼此是什么关系，这一页会更适合继续往下看。",
    descriptionEn: "This page is the better next step if these terms keep stopping you and you still need a clearer sense of how they relate to one another.",
  },
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "把禅修、听诵、念佛、阅读和记录放回同一张地图里。",
    titleEn: "Place meditation, listening, recitation, reading, and notes back onto one map.",
    descriptionZh: "如果你已经知道要开始练习，但还不清楚这些方法该怎么配合，这一页更适合先打开。",
    descriptionEn: "Open this first if you know you want to practice but still need a clearer map for how the methods support each other.",
  },
  {
    href: "/nianfo-guide",
    labelZh: "念佛入门",
    labelEn: "Nianfo Guide",
    titleZh: "先让一句佛号和白天的回返点慢慢留下来。",
    titleEn: "Let one recited phrase and one daytime return point begin to stay.",
    descriptionZh: "如果你更需要一条比长时间坐下来更轻、更容易接进通勤与日常空档的练习入口，这一页会更合适。",
    descriptionEn: "This page is a better fit if you need a lighter practice entry that can return during commuting and ordinary pauses.",
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
    titleZh: "先把常见经典入口、阅读问题和下一步路径放清楚。",
    titleEn: "Clarify the common scripture doorways, reading questions, and next-step paths first.",
    descriptionZh: "如果你已经知道想从经典进入，但还需要一张更完整的佛经入门地图，这一页更适合先打开。",
    descriptionEn: "This page is the better first stop if scripture already feels like your doorway and you need a fuller beginner map.",
  },
  {
    href: "/sutra-listening",
    labelZh: "听诵和读经怎么配合",
    labelEn: "Listening and Reading",
    titleZh: "把通勤里的听诵、安静时的阅读和一句记录接回同一条线。",
    titleEn: "Reconnect listening on the move, reading in quiet moments, and one short note inside the same line.",
    descriptionZh: "如果你已经开始听经，却还不知道怎样把熟悉感接回文字、义理和稳定节奏，这一页会更适合继续往下看。",
    descriptionEn: "This page is a better next step if you have begun listening but still need to return that familiarity to text, meaning, and stable rhythm.",
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
    "学佛从哪里开始",
    "佛法入门",
    "佛学基本概念",
    "佛经导读",
    "修行方法",
    "念佛入门",
    "经文听诵",
    "听诵和读经怎么配合",
    "官网资讯",
    "佛教 FAQ",
    "初学者佛经推荐",
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

export default async function HomePage() {
  const releaseCollection = await getOfficialSiteReleaseCollection();
  const screenshots = {
    ...FALLBACK_SCREENSHOTS,
    ...releaseCollection.screenshots,
  };
  const allArticles = getAllArticles();
  const featuredArticle = allArticles[0] ?? null;
  const spotlightArticles = allArticles.slice(1, 4);
  const channels = [...releaseCollection.betaChannels, ...releaseCollection.stableChannels].slice(0, 2);
  const supportEmail =
    contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@ombhrum.com";
  const latestRelease = releaseCollection.releases[0] ?? null;

  const bulletinItems: BulletinItem[] = [
    ...(latestRelease
      ? [
          {
            href: "/download#release-changelog",
            categoryZh: "重要公告",
            categoryEn: "Notice",
            titleZh: latestRelease.title,
            titleEn: latestRelease.title,
            descriptionZh:
              latestRelease.summary[0] ?? "查看最近版本、发布时间和下载说明。",
            descriptionEn:
              latestRelease.summary[0] ?? "Check the latest release, publish date, and download notes.",
          },
        ]
      : []),
    ...allArticles.slice(0, 2).map((article) => ({
      href: `/insights/${article.slug}`,
      categoryZh: "官网资讯",
      categoryEn: "Site News",
      titleZh: article.title,
      titleEn: article.title,
      descriptionZh: article.description,
      descriptionEn: article.description,
    })),
  ];

  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "大乘官网首页",
        url: siteUrl("/"),
        description: homeDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
      },
      {
        "@type": "Organization",
        name: `${brand.name} Fabushi`,
        url: siteUrl("/"),
        email: supportEmail,
        description: "Fabushi offers meditation, sutra listening, and global giving.",
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
                <LocalizedText zh="大乘官网首页" en="Fabushi Home" />
              </span>
            </div>
            <h1 id="home-title">
              <LocalizedText zh="学佛入门、佛法导读与官网资讯入口" en="Dharma Guides, Learning Paths, and Site News" />
            </h1>
            <p className="hero-subtitle">
              <LocalizedText
                zh="首页先承担资讯导览、学习路径与官网总入口职责；App 下载仍然保留，但回到清晰的服务入口位置，不再压过内容主叙事。"
                en="The homepage now leads with guidance, learning paths, and official site news, while app download remains a clear service entry instead of dominating the main story."
              />
            </p>
            <div className="hero-actions">
              <a className="primary-action" href={siteHref("/start-learning-buddhism")}>
                <LocalizedText zh="先看学佛从哪里开始" en="Start with Where to Begin" />
              </a>
              <a className="secondary-action" href={siteHref("/insights")}>
                <LocalizedText zh="查看官网资讯" en="View Site News" />
              </a>
              <a className="secondary-action" href={siteHref("/download")}>
                <LocalizedText zh="下载 App" en="Download App" />
              </a>
            </div>
            <div className="release-section-stack" aria-label="Homepage shortcuts / 首页入口">
              <p className="eyebrow">
                <LocalizedText zh="先从这些入口开始" en="Start here" />
              </p>
              <div className="site-nav-links">
                {HERO_GUIDE_LINKS.map((item) => (
                  <a key={item.href} href={siteHref(item.href)}>
                    <LocalizedText zh={item.zh} en={item.en} />
                  </a>
                ))}
              </div>
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

      <section className="band compact-band" id="bulletins">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="焦点快讯" en="Bulletins" />
          </p>
          <h2>
            <LocalizedText zh="先把最近最值得知道的入口放在首屏之后。" en="Put the most important recent entry points right after the hero." />
          </h2>
        </div>
        <div className="editorial-list">
          {bulletinItems.map((item) => (
            <a key={item.href} className="editorial-row" href={siteHref(item.href)}>
              <span>
                <LocalizedText zh={item.categoryZh} en={item.categoryEn} />
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
      </section>

      <section className="band alt" id="latest-news">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="最新资讯" en="Latest News" />
          </p>
          <h2>
            <LocalizedText zh="首页先承担官网资讯首页职责，再把人带去专题页和下载页。" en="The homepage first acts as a news hub, then guides people into topic pages and services." />
          </h2>
        </div>
        {featuredArticle ? (
          <div className="editorial-list">
            <a className="editorial-row" href={siteHref(`/insights/${featuredArticle.slug}`)}>
              <span>{featuredArticle.category}</span>
              <div>
                <strong>{featuredArticle.title}</strong>
                <p>{featuredArticle.description}</p>
                <small>
                  {featuredArticle.author} · {featuredArticle.readTime}
                </small>
              </div>
            </a>
            {spotlightArticles.map((item) => (
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
        ) : null}
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/insights")}>
            <LocalizedText zh="进入官网资讯" en="Open Site News" />
          </a>
        </div>
      </section>

      <section className="band" id="dharma-paths">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="宗派与修行导览" en="Learning Paths" />
          </p>
          <h2>
            <LocalizedText
              zh="把之前已经写好的内容收成静态卡片集群，让首页更像内容总入口，而不是下载落地页。"
              en="Gather existing content into static card clusters so the homepage works as a true content gateway instead of a download landing page."
            />
          </h2>
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
      </section>

      <section className="band alt product-band" id="feature-preview">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="专题与产品预览" en="Preview" />
          </p>
          <h2>
            <LocalizedText zh="保留克制的配图卡片，但只作为摘要入口，不让视觉盖过正文导览。" en="Keep restrained image cards as summary entry points without letting visuals overpower the homepage guidance." />
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
              zh="把高频问题做成 SEO 安全的 FAQ 卡片集群，不使用翻转。"
              en="Keep common questions in an SEO-safe FAQ cluster without flip interactions."
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

      <section className="band" id="services">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="服务入口" en="Service Entry" />
          </p>
          <h2>
            <LocalizedText zh="把 App 下载放回服务区，而不是首页主叙事中间。" en="Keep app download in the service zone instead of the middle of the homepage narrative." />
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
      </section>

      <SiteFooter />
    </main>
  );
}
