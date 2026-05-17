import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { getAllArticles } from "../../lib/content";
import { siteHref, siteUrl } from "../../lib/site-url";

const insightsUrl = siteUrl("/insights");
const insightsTitle = `官网资讯与内容建设 | ${brand.name}`;
const insightsDescription =
  "查看大乘官网的公告、版本更新、下载说明与内容建设进展，并从这里继续进入学佛从哪里开始、佛法入门、佛学基本概念、修行方法与佛经导读专题。";

const TOPIC_GATEWAYS = [
  {
    href: "/start-learning-buddhism",
    labelZh: "学佛从哪里开始",
    labelEn: "Where to Begin",
    titleZh: "如果你是第一次进站，先把入口顺序放轻一点、放清楚一点。",
    titleEn: "If this is your first stop, begin with the lightest and clearest entry path.",
    descriptionZh: "这条路径更适合还在分辨先看佛法入门、先读经，还是先安排一点日常练习的人。",
    descriptionEn: "This path fits people who are still sorting out whether to begin with dharma basics, sutras, or a light daily rhythm.",
  },
  {
    href: "/buddhist-concepts",
    labelZh: "佛学基本概念",
    labelEn: "Buddhist Concepts",
    titleZh: "先把因果、菩提心、六度和空性放回同一张概念地图里。",
    titleEn: "Place karma, bodhicitta, the six paramitas, and emptiness back on one concept map.",
    descriptionZh: "如果你已经发现自己总被这些名相卡住，这一页会比继续零散搜索更稳。",
    descriptionEn: "This is the steadier next step when these terms keep interrupting your reading and practice.",
  },
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "把禅修、念佛、听诵、阅读和记录重新收成一张练习地图。",
    titleEn: "Gather meditation, recitation, listening, reading, and notes back onto one practice map.",
    descriptionZh: "如果你已经知道要开始练习，但还不清楚这些方法怎样互相配合，这里更适合继续往下走。",
    descriptionEn: "Open this when you know you want to practice but still need a clearer sense of how the methods support each other.",
  },
  {
    href: "/sutra-guide",
    labelZh: "佛经导读",
    labelEn: "Sutra Guide",
    titleZh: "把佛经入口、听诵问题和下一步桥接路径放清楚。",
    titleEn: "Clarify the scripture doorways, listening questions, and the next bridges.",
    descriptionZh: "如果你更想从《心经》《阿弥陀经》《普门品》或《金刚经》这些入口开始，这里会更合适。",
    descriptionEn: "This is a better next page when scripture already feels like the doorway through the Heart Sutra, Amitabha Sutra, Universal Gate Chapter, or Diamond Sutra.",
  },
] as const;

const INSIGHT_FAQS = [
  {
    questionZh: "这页主要看什么？",
    questionEn: "What is this page mainly for?",
    answerZh: "这里主要汇总官网公告、版本与下载说明、内容建设进展，并把已经成形的佛法专题入口集中放在同一页里。这样你不用在资讯页和专题页之间来回找路。",
    answerEn: "This page collects official announcements, release and download notes, and content-building updates while also grouping the site’s established dharma topic gateways in one place.",
  },
  {
    questionZh: "如果我不是来看公告，而是想直接开始学佛，应该先点哪里？",
    questionEn: "If I want to begin learning rather than read updates, where should I click first?",
    answerZh: "大多数第一次来的人，更适合先看“学佛从哪里开始”。如果你已经知道自己最卡的是概念、修行方法或佛经阅读，再分别进入对应专题会更快。",
    answerEn: "Most first-time visitors are better served by starting with Where to Begin. If you already know your main question is about concepts, practice methods, or scripture reading, the matching topic page will be faster.",
  },
  {
    questionZh: "下载 App 应该在这里看，还是去下载页？",
    questionEn: "Should I look for app downloads here or on the download page?",
    answerZh: "如果你的目标只是下载，直接去下载页会更清楚。资讯页保留下载相关公告和版本说明，但不再承担下载转化页的职责。",
    answerEn: "If your goal is simply to download the app, the dedicated download page is clearer. The insights page can still mention release or download announcements, but it no longer acts as the download conversion page.",
  },
] as const;

export const metadata: Metadata = {
  title: insightsTitle,
  description: insightsDescription,
  alternates: {
    canonical: insightsUrl,
  },
  keywords: [
    "官网资讯",
    "官网内容建设",
    "版本更新",
    "下载说明",
    "学佛从哪里开始",
    "佛法入门",
    "佛学基本概念",
    "修行方法",
    "佛经导读",
    "Fabushi",
  ],
  openGraph: {
    title: insightsTitle,
    description: insightsDescription,
    url: insightsUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: insightsTitle,
    description: insightsDescription,
  },
};

export default function InsightsIndexPage() {
  const articles = getAllArticles();
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "CollectionPage",
        name: "大乘官网资讯与内容建设",
        url: insightsUrl,
        description: insightsDescription,
        inLanguage: "zh-CN",
        hasPart: articles.map((item) => ({
          "@type": "Article",
          headline: item.title,
          description: item.description,
          url: siteUrl(`/insights/${item.slug}`),
        })),
      },
      {
        "@type": "ItemList",
        name: "官网专题入口",
        itemListElement: TOPIC_GATEWAYS.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.labelZh,
          url: siteUrl(item.href),
          description: item.descriptionZh,
        })),
      },
      {
        "@type": "FAQPage",
        mainEntity: INSIGHT_FAQS.map((item) => ({
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
    <main className="inner-page">
      <script
        type="application/ld+json"
        suppressHydrationWarning
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />

      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">
            <LocalizedText zh="官网资讯" en="Official News" />
          </p>
          <h1>
            <LocalizedText
              zh="公告、版本更新与官网内容建设进展。"
              en="Announcements, releases, and official-site content progress."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="这里保留官网公告、版本与下载说明，也把已经成形的佛法专题入口集中收在一起，方便从资讯继续进入学习路径，而不是停在更新列表里。"
              en="This page keeps official announcements, release and download notes, while also gathering the site’s established dharma gateways so readers can move from updates into the learning paths instead of stopping at a news list."
            />
          </p>
        </div>
      </section>

      <section className="band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="最新资讯" en="Latest Updates" />
          </p>
          <h2>
            <LocalizedText
              zh="先把官网最近发生了什么放清楚。"
              en="Start with what the official site has changed recently."
            />
          </h2>
        </div>
        <div className="editorial-list">
          {articles.map((item) => (
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
      </section>

      <section className="band alt">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="专题入口" en="Topic Gateways" />
          </p>
          <h2>
            <LocalizedText
              zh="这里不做翻转卡片，直接用 SEO 安全的静态入口把资讯页接回内容专题。"
              en="Keep these gateways static and crawl-safe instead of using flip cards on a news-oriented page."
            />
          </h2>
        </div>
        <div className="editorial-list">
          {TOPIC_GATEWAYS.map((item) => (
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

      <section className="band">
        <div className="section-heading tight">
          <p>FAQ</p>
          <h2>
            <LocalizedText
              zh="先把资讯页、专题页和下载页的分工讲清楚。"
              en="Clarify the roles of the news page, topic pages, and download page."
            />
          </h2>
        </div>
        <div className="faq-list full">
          {INSIGHT_FAQS.map((item) => (
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
          <a className="primary-action" href={siteHref("/start-learning-buddhism")}>
            <LocalizedText zh="先看学佛从哪里开始" en="Start with Where to Begin" />
          </a>
          <a className="secondary-action" href={siteHref("/download")}>
            <LocalizedText zh="进入下载页" en="Open Download Page" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}