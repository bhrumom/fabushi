import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../../components/localized-text";
import { SiteFooter } from "../../../components/site-footer";
import { SiteHeader } from "../../../components/site-header";
import { getAllArticles, getArticleBySlug } from "../../../lib/content";
import { siteHref, siteUrl } from "../../../lib/site-url";

type ArticlePageParams = Promise<{ slug: string }>;

const TOPIC_GATEWAYS = [
  {
    href: "/start-learning-buddhism",
    labelZh: "学佛从哪里开始",
    labelEn: "Where to Begin",
    titleZh: "如果你是从公告或版本说明页进来的，先把起步顺序放轻一点、放清楚一点。",
    titleEn: "If you arrived from an announcement or release note, begin with a lighter and clearer first-step map.",
    descriptionZh: "这条路径更适合还在分辨先看佛法入门、先读经，还是先安排一点日常练习的人。",
    descriptionEn: "This path fits people who are still sorting out whether to begin with dharma basics, sutras, or a light daily rhythm.",
  },
  {
    href: "/buddhist-concepts",
    labelZh: "佛学基本概念",
    labelEn: "Buddhist Concepts",
    titleZh: "如果你已经发现自己总被因果、菩提心、六度和空性这些词卡住，先回概念地图会更稳。",
    titleEn: "If karma, bodhicitta, the six paramitas, and emptiness keep blocking your reading, return to the concepts map first.",
    descriptionZh: "先把核心概念放回同一张图里，再决定继续看哪一张概念页、佛经页或修行页，路径会更清楚。",
    descriptionEn: "Place the core concepts back on one map before choosing the next concept, scripture, or practice page.",
  },
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "如果你已经知道自己想开始练习，但还不清楚禅修、念佛、听诵和阅读怎样配合，这里更适合继续往下走。",
    titleEn: "If you know you want to practice but still need a clearer map for meditation, recitation, listening, and reading, continue here.",
    descriptionZh: "这条路径把练习方法重新收回同一张地图里，让更新页用户也能自然转进修行内容。",
    descriptionEn: "This path regathers the methods onto one map so readers who came through updates can move naturally into practice content.",
  },
  {
    href: "/nianfo-guide",
    labelZh: "念佛入门",
    labelEn: "Nianfo Guide",
    titleZh: "如果你更需要一条比长时间坐下来更轻、更容易留在通勤与日常里的入口，可以先从念佛入门继续。",
    titleEn: "If you need a lighter doorway that can stay alive during commuting and ordinary pauses, continue into the nianfo guide.",
    descriptionZh: "这条路径更适合想先让一句佛号、一个白天回返点和轻量功课慢慢留下来的人。",
    descriptionEn: "This path better fits people who want one phrase, one daytime return point, and a lighter routine to begin staying alive.",
  },
  {
    href: "/sutra-guide",
    labelZh: "佛经导读",
    labelEn: "Sutra Guide",
    titleZh: "如果你更想从《心经》《阿弥陀经》《普门品》或《金刚经》这些入口开始，这里会更合适。",
    titleEn: "If scripture already feels like the doorway through the Heart Sutra, Amitabha Sutra, Universal Gate Chapter, or Diamond Sutra, continue here.",
    descriptionZh: "这条路径会把佛经入口、听诵问题和下一步桥接路径放清楚，不让阅读停在第一层总览里。",
    descriptionEn: "This path clarifies scripture entry points, listening questions, and next bridges so reading does not stop at a first overview.",
  },
] as const;

const ARTICLE_FAQS = [
  {
    questionZh: "如果我不是来看公告，而是想直接开始学佛，应该先点哪里？",
    questionEn: "If I want to begin learning rather than keep reading updates, where should I click first?",
    answerZh: "大多数第一次从资讯页或文章页进来的人，更适合先看“学佛从哪里开始”。如果你已经知道自己最卡的是概念、修行方法、念佛，还是佛经阅读，再分别进入对应专题会更快。",
    answerEn: "Most first-time visitors who arrive through news or article pages are better served by starting with Where to Begin. If you already know your main question is about concepts, practice methods, nianfo, or scripture reading, the matching topic page will be faster.",
  },
  {
    questionZh: "为什么单篇资讯页里也会放专题入口？",
    questionEn: "Why does a single update article also surface topic gateways?",
    answerZh: "因为官网资讯已经不只是产品更新列表，而是官网总入口的一部分。很多人会先从公告、版本说明或更新页进入网站，再决定自己真正需要的是下载、起步导读、概念解释，还是修行方法，所以文章页也应该承担稳定分发职责。",
    answerEn: "Because official news is no longer only a product-update list, but part of the site’s main entry system. Many readers first enter through announcements, release notes, or updates and only then discover whether they really need downloads, beginner guidance, concept clarification, or practice methods.",
  },
  {
    questionZh: "如果我的目标只是下载 App，应该留在这页还是去下载页？",
    questionEn: "If my goal is only to download the app, should I stay here or go to the download page?",
    answerZh: "如果你的目标只是下载，直接去下载页会更清楚。单篇资讯页会保留相关更新，但不承担下载转化页职责。",
    answerEn: "If your goal is simply to download the app, the dedicated download page is clearer. Article pages can still mention related updates, but they do not act as the download conversion page.",
  },
] as const;

export function generateStaticParams() {
  return getAllArticles().map((article) => ({ slug: article.slug }));
}

export async function generateMetadata({ params }: { params: ArticlePageParams }): Promise<Metadata> {
  const { slug } = await params;
  const article = getArticleBySlug(slug);
  if (!article) {
    return {};
  }

  const articleUrl = siteUrl(`/insights/${article.slug}`);

  return {
    title: `${article.title} | ${brand.name}`,
    description: article.description,
    alternates: {
      canonical: articleUrl,
    },
    keywords: [
      article.category,
      article.title,
      "官网资讯",
      "版本更新",
      "内容建设",
      `${brand.name} 官网资讯`,
    ],
    openGraph: {
      title: `${article.title} | ${brand.name}`,
      description: article.description,
      url: articleUrl,
      siteName: "Fabushi",
      locale: "zh_CN",
      type: "article",
      publishedTime: article.publishedAt,
      modifiedTime: article.updatedAt ?? article.publishedAt,
      authors: [article.author],
      section: article.category,
    },
    twitter: {
      card: "summary_large_image",
      title: `${article.title} | ${brand.name}`,
      description: article.description,
    },
  };
}

export default async function InsightArticlePage({ params }: { params: ArticlePageParams }) {
  const { slug } = await params;
  const article = getArticleBySlug(slug);

  if (!article) {
    notFound();
  }

  const articleUrl = siteUrl(`/insights/${article.slug}`);
  const relatedArticles = getAllArticles().filter((item) => item.slug !== article.slug).slice(0, 3);
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "BlogPosting",
        headline: article.title,
        description: article.description,
        url: articleUrl,
        mainEntityOfPage: articleUrl,
        articleSection: article.category,
        datePublished: article.publishedAt,
        dateModified: article.updatedAt ?? article.publishedAt,
        author: {
          "@type": "Person",
          name: article.author,
        },
        publisher: {
          "@type": "Organization",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          {
            "@type": "ListItem",
            position: 1,
            name: "首页",
            item: siteUrl("/"),
          },
          {
            "@type": "ListItem",
            position: 2,
            name: "官网资讯",
            item: siteUrl("/insights"),
          },
          {
            "@type": "ListItem",
            position: 3,
            name: article.title,
            item: articleUrl,
          },
        ],
      },
      {
        "@type": "ItemList",
        name: "文章页专题入口",
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
        mainEntity: ARTICLE_FAQS.map((item) => ({
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

      <section className="inner-hero article">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">{article.category}</p>
          <h1>{article.title}</h1>
          <p className="lede">{article.description}</p>
          <span className="article-date">
            {article.publishedAt} · {article.author} · {article.readTime}
          </span>
        </div>
      </section>

      <article className="article-body">
        {article.body.map((paragraph) => (
          <p key={paragraph}>{paragraph}</p>
        ))}
      </article>

      <section className="band alt">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="专题入口" en="Topic Gateways" />
          </p>
          <h2>
            <LocalizedText
              zh="读完更新以后，直接从这里继续进入更适合你的学习路径。"
              en="After the update, continue from here into the learning path that fits best now."
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

      {relatedArticles.length > 0 ? (
        <section className="band">
          <div className="section-heading tight">
            <p>
              <LocalizedText zh="相关文章" en="Related Updates" />
            </p>
            <h2>
              <LocalizedText zh="继续了解官网最近的更新。" en="Continue with recent official-site updates." />
            </h2>
          </div>
          <div className="editorial-list">
            {relatedArticles.map((item) => (
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
      ) : null}

      <section className="band faq-band">
        <div className="section-heading tight">
          <p>FAQ</p>
          <h2>
            <LocalizedText
              zh="先把文章页、专题页和下载页的分工讲清楚。"
              en="Clarify the roles of article pages, topic pages, and the download page."
            />
          </h2>
        </div>
        <div className="faq-list full">
          {ARTICLE_FAQS.map((item) => (
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
          <a className="secondary-action" href={siteHref("/insights")}>
            <LocalizedText zh="返回官网资讯" en="Back to Official News" />
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
