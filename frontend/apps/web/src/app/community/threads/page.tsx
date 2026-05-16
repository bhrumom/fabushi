import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../../components/localized-text";
import { SiteFooter } from "../../../components/site-footer";
import { SiteHeader } from "../../../components/site-header";
import {
  FORUM_SECTIONS,
  FORUM_THREADS,
  getForumSectionBySlug,
  getForumThreadsBySection,
} from "../../../lib/community";
import { siteHref, siteUrl } from "../../../lib/site-url";

const threadsUrl = siteUrl("/community/threads");
const threadsTitle = `论坛示例帖子 | ${brand.name}`;
const threadsDescription =
  "Fabushi 佛法论坛首批示例帖子列表，展示论坛将如何承载新手提问、经论研读、禅修问答与修学日志。";

export const metadata: Metadata = {
  title: threadsTitle,
  description: threadsDescription,
  alternates: {
    canonical: threadsUrl,
  },
  keywords: ["佛法论坛帖子", "学佛讨论", "禅修问答", "经论研读", "Fabushi forum threads"],
  openGraph: {
    title: threadsTitle,
    description: threadsDescription,
    url: threadsUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: threadsTitle,
    description: threadsDescription,
  },
};

export default function CommunityThreadsPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "CollectionPage",
        name: "Fabushi 论坛示例帖子",
        url: threadsUrl,
        description: threadsDescription,
      },
      {
        "@type": "ItemList",
        name: "Fabushi 首批论坛帖子",
        itemListElement: FORUM_THREADS.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          url: siteUrl(`/community/threads/${item.slug}`),
          name: item.titleZh,
          description: item.summaryZh,
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
            <LocalizedText zh="论坛帖子索引" en="Thread Index" />
          </p>
          <h1>
            <LocalizedText
              zh="从种子帖子开始，把论坛真正走成可浏览的讨论空间。"
              en="Start with seed threads and turn the forum into a space people can actually browse."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="这里收拢了 Fabushi 佛法论坛首批示例帖子。它们还不是完整社区流量，但已经把论坛最核心的讨论方向、提问方式和沉淀逻辑公开出来。"
              en="This page gathers the first Fabushi forum starter threads. It is not the full community yet, but it already exposes the discussion directions, question style, and archiving logic the forum will build on."
            />
          </p>
        </div>
      </section>

      <section className="band compact-band">
        <div className="recommended-banner">
          <LocalizedText
            zh="当前目标不是制造热闹，而是先让“新手起步、经论研读、禅修问答、修学日志”四类讨论路径有清晰落点。"
            en="The immediate goal is not volume but clear landing zones for newcomer questions, sutra study, meditation practice, and practice journals."
          />
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="论坛首轮内容会优先采用“种子帖子 + 后续沉淀”的方式推进。也就是说，先把值得长期讨论的问题摆出来，再逐步补回复、收藏、关注和精华归档。"
              en="The first content pass uses a seed-thread model: publish questions worth discussing over time, then layer in replies, bookmarks, follows, and featured archiving."
            />
          </p>
          <p>
            <LocalizedText
              zh="你现在看到的每一条帖子，既是示例内容，也是后续真实数据模型、板块结构和新手引导流程的原型。"
              en="Each thread here is both sample content and a prototype for the future data model, board structure, and newcomer guidance flow."
            />
          </p>
          <div className="inline-cta">
            <a className="primary-action" href={siteHref("/community")}>
              <LocalizedText zh="回看论坛入口" en="Back to forum entry" />
            </a>
            <a className="secondary-action" href={siteHref("/contact")}>
              <LocalizedText zh="反馈你最想先参与的话题" en="Share which topic you want first" />
            </a>
          </div>
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="板块概览" en="Board Snapshot" />
          </p>
          <h2>
            <LocalizedText
              zh="先让每个板块都有第一条像样的讨论。"
              en="Make sure each board begins with a discussion worth entering."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {FORUM_SECTIONS.map((section) => {
            const count = getForumThreadsBySection(section.slug).length;
            return (
              <article key={section.slug} className="definition-card">
                <h3>
                  <LocalizedText zh={section.titleZh} en={section.titleEn} />
                </h3>
                <p>
                  <LocalizedText zh={section.summaryZh} en={section.summaryEn} />
                </p>
                <p>
                  <LocalizedText
                    zh={`当前示例帖子 ${count} 条`}
                    en={`${count} starter thread${count === 1 ? "" : "s"} so far`}
                  />
                </p>
              </article>
            );
          })}
        </div>
      </section>

      <section className="band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="帖子列表" en="Threads" />
          </p>
          <h2>
            <LocalizedText
              zh="先浏览问题，再决定论坛后续要把哪些能力补齐。"
              en="Browse the questions first, then decide which forum capabilities need to be added next."
            />
          </h2>
        </div>
        <div className="editorial-list">
          {FORUM_THREADS.map((thread) => {
            const section = getForumSectionBySlug(thread.sectionSlug);
            return (
              <a
                key={thread.slug}
                className="editorial-row"
                href={siteHref(`/community/threads/${thread.slug}`)}
              >
                <span>
                  <LocalizedText
                    zh={section?.titleZh ?? thread.sectionSlug}
                    en={section?.titleEn ?? thread.sectionSlug}
                  />
                </span>
                <div>
                  <strong>
                    <LocalizedText zh={thread.titleZh} en={thread.titleEn} />
                  </strong>
                  <p>
                    <LocalizedText zh={thread.summaryZh} en={thread.summaryEn} />
                  </p>
                  <small>
                    <LocalizedText
                      zh={`${thread.repliesCount} 条回复 · ${thread.followsCount} 人关注 · ${thread.bookmarksCount} 次收藏 · ${thread.lastActivityZh}`}
                      en={`${thread.repliesCount} replies · ${thread.followsCount} follows · ${thread.bookmarksCount} bookmarks · ${thread.lastActivityEn}`}
                    />
                  </small>
                </div>
              </a>
            );
          })}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="为什么先这样做" en="Why This First" />
          </p>
          <h2>
            <LocalizedText
              zh="论坛真正的骨架，不只是页面，而是被长期复用的问题结构。"
              en="The real backbone of the forum is not just pages, but question structures that can be reused over time."
            />
          </h2>
        </div>
        <div className="governance-grid">
          <article className="governance-card">
            <h3>
              <LocalizedText zh="先把提问方式做对" en="Start with good question framing" />
            </h3>
            <p>
              <LocalizedText
                zh="如果最早的讨论就能带出出处、上下文、适用对象和复盘方式，后续的数据层与治理逻辑会更容易接上。"
                en="If the earliest threads already model sources, context, intended audience, and review patterns, later data and moderation layers can grow on steadier ground."
              />
            </p>
          </article>
          <article className="governance-card">
            <h3>
              <LocalizedText zh="先把沉淀点暴露出来" en="Expose archive points early" />
            </h3>
            <p>
              <LocalizedText
                zh="每条示例帖子都已经预留了“摘要、标签、回帖提示、后续可整理内容”的结构，方便后面接精华归档。"
                en="Each thread already carries summary, tags, reply prompts, and archive-ready structure so featured knowledge pages can be added later."
              />
            </p>
          </article>
          <article className="governance-card">
            <h3>
              <LocalizedText zh="先看浏览闭环哪里最缺" en="Find the next missing piece" />
            </h3>
            <p>
              <LocalizedText
                zh="当列表和详情页都出现后，我们就能更准确判断接下来该优先做发帖、回复表单，还是审核和新手引导。"
                en="Once both list and detail views exist, it becomes much easier to judge whether posting, reply forms, moderation, or onboarding should come next."
              />
            </p>
          </article>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
