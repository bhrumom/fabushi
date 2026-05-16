import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../../../components/localized-text";
import { SiteFooter } from "../../../../components/site-footer";
import { SiteHeader } from "../../../../components/site-header";
import {
  FORUM_THREADS,
  getForumSectionBySlug,
  getForumThreadBySlug,
} from "../../../../lib/community";
import { siteHref, siteUrl } from "../../../../lib/site-url";

type ThreadPageParams = {
  slug: string;
};

interface ThreadPageProps {
  params: Promise<ThreadPageParams>;
}

export const dynamicParams = false;

export function generateStaticParams() {
  return FORUM_THREADS.map((thread) => ({ slug: thread.slug }));
}

export async function generateMetadata({ params }: ThreadPageProps): Promise<Metadata> {
  const { slug } = await params;
  const thread = getForumThreadBySlug(slug);

  if (!thread) {
    return {
      title: `论坛帖子 | ${brand.name}`,
      description: "Fabushi 佛法论坛帖子详情。",
    };
  }

  const section = getForumSectionBySlug(thread.sectionSlug);
  const threadUrl = siteUrl(`/community/threads/${slug}`);
  const title = `${thread.titleZh} | ${brand.name}`;
  const description = thread.summaryZh;

  return {
    title,
    description,
    alternates: {
      canonical: threadUrl,
    },
    keywords: [thread.titleZh, section?.titleZh ?? "佛法论坛", ...thread.tagsZh],
    openGraph: {
      title,
      description,
      url: threadUrl,
      siteName: "Fabushi",
      locale: "zh_CN",
      type: "article",
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
    },
  };
}

export default async function CommunityThreadDetailPage({ params }: ThreadPageProps) {
  const { slug } = await params;
  const thread = getForumThreadBySlug(slug);

  if (!thread) {
    notFound();
  }

  const section = getForumSectionBySlug(thread.sectionSlug);
  const threadUrl = siteUrl(`/community/threads/${slug}`);
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "DiscussionForumPosting",
        headline: thread.titleZh,
        description: thread.summaryZh,
        url: threadUrl,
        articleSection: section?.titleZh ?? thread.sectionSlug,
        author: {
          "@type": "Person",
          name: thread.authorZh,
        },
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          {
            "@type": "ListItem",
            position: 1,
            name: "Fabushi 佛法论坛",
            item: siteUrl("/community"),
          },
          {
            "@type": "ListItem",
            position: 2,
            name: "论坛示例帖子",
            item: siteUrl("/community/threads"),
          },
          {
            "@type": "ListItem",
            position: 3,
            name: thread.titleZh,
            item: threadUrl,
          },
        ],
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
            <LocalizedText
              zh={section?.titleZh ?? thread.sectionSlug}
              en={section?.titleEn ?? thread.sectionSlug}
            />
          </p>
          <h1>
            <LocalizedText zh={thread.titleZh} en={thread.titleEn} />
          </h1>
          <p className="lede">
            <LocalizedText zh={thread.summaryZh} en={thread.summaryEn} />
          </p>
        </div>
      </section>

      <section className="band compact-band">
        <div className="recommended-banner">
          <LocalizedText
            zh={`${thread.authorZh} · ${thread.roleZh} · ${thread.publishedLabelZh}`}
            en={`${thread.authorEn} · ${thread.roleEn} · ${thread.publishedLabelEn}`}
          />
        </div>
        <div className="definition-grid">
          <article className="definition-card">
            <h3>
              <LocalizedText zh="最近动态" en="Latest activity" />
            </h3>
            <p>
              <LocalizedText zh={thread.lastActivityZh} en={thread.lastActivityEn} />
            </p>
          </article>
          <article className="definition-card">
            <h3>
              <LocalizedText zh="互动信号" en="Signals" />
            </h3>
            <p>
              <LocalizedText
                zh={`${thread.repliesCount} 条回复 · ${thread.followsCount} 人关注 · ${thread.bookmarksCount} 次收藏`}
                en={`${thread.repliesCount} replies · ${thread.followsCount} follows · ${thread.bookmarksCount} bookmarks`}
              />
            </p>
          </article>
          <article className="definition-card">
            <h3>
              <LocalizedText zh="标签" en="Tags" />
            </h3>
            <p>
              <LocalizedText zh={thread.tagsZh.join(" · ")} en={thread.tagsEn.join(" · ")} />
            </p>
          </article>
          <article className="definition-card">
            <h3>
              <LocalizedText zh="为什么先做这条" en="Why this thread first" />
            </h3>
            <p>
              <LocalizedText zh={thread.featuredReasonZh} en={thread.featuredReasonEn} />
            </p>
          </article>
        </div>
      </section>

      <section className="band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="发起帖正文" en="Opening post" />
          </p>
          <h2>
            <LocalizedText
              zh="先把问题说清楚，后面的讨论才会越来越好。"
              en="A clear opening question gives the rest of the discussion somewhere solid to go."
            />
          </h2>
        </div>
        <div className="article-body">
          {thread.openingPostZh.map((paragraph, index) => (
            <p key={paragraph}>
              <LocalizedText zh={paragraph} en={thread.openingPostEn[index]} />
            </p>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="当前沉淀点" en="Archive points" />
          </p>
          <h2>
            <LocalizedText
              zh="这条帖子后续最值得沉淀成什么。"
              en="What this thread is most likely to mature into later."
            />
          </h2>
        </div>
        <div className="governance-grid">
          {thread.takeawaysZh.map((item, index) => (
            <article key={item} className="governance-card">
              <h3>
                <LocalizedText zh={`重点 ${index + 1}`} en={`Point ${index + 1}`} />
              </h3>
              <p>
                <LocalizedText zh={item} en={thread.takeawaysEn[index]} />
              </p>
            </article>
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="建议回帖方向" en="Suggested reply prompts" />
          </p>
          <h2>
            <LocalizedText
              zh="让回复更具体，也让后续整理更容易。"
              en="Help replies become more concrete and easier to organize later."
            />
          </h2>
        </div>
        <div className="editorial-list">
          {thread.replyPromptsZh.map((item, index) => (
            <article key={item} className="editorial-row">
              <span>
                <LocalizedText zh={`提示 ${index + 1}`} en={`Prompt ${index + 1}`} />
              </span>
              <div>
                <strong>
                  <LocalizedText zh={item} en={thread.replyPromptsEn[index]} />
                </strong>
              </div>
            </article>
          ))}
        </div>
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/community/threads")}>
            <LocalizedText zh="回到帖子列表" en="Back to thread index" />
          </a>
          <a className="secondary-action" href={siteHref("/community")}>
            <LocalizedText zh="回到论坛入口" en="Back to forum entry" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
