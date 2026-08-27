import type { Metadata } from "next";
import { notFound } from "next/navigation";
import {
  ArrowRight,
  BookOpen,
  CalendarDays,
  ChevronRight,
  Clock3,
  ExternalLink,
  Search,
} from "lucide-react";
import { AppIcon } from "../../../../../components/marketplace/app-icon";
import { AppInstallActions } from "../../../../../components/marketplace/app-install-actions";
import styles from "../../../../../components/marketplace/marketplace.module.css";
import { appEntityId } from "../../../../../lib/ai-discovery";
import {
  getMarketplaceContent,
  marketplaceContent,
  type MarketplaceContentItem,
} from "../../../../../lib/marketplace";
import { siteHref, siteUrl } from "../../../../../lib/site-url";

type ContentPageProps = {
  params: Promise<{ slug: string; contentId: string }>;
};

export const dynamicParams = false;

export function generateStaticParams() {
  return marketplaceContent.map(({ app, item }) => ({
    slug: app.slug,
    contentId: item.id,
  }));
}

function contentTypeLabel(type: MarketplaceContentItem["type"]) {
  switch (type) {
    case "guide":
      return "指南";
    case "template":
      return "模板";
    case "collection":
      return "内容集";
    case "workflow":
      return "工作流";
    case "release":
      return "版本说明";
  }
}

export async function generateMetadata({ params }: ContentPageProps): Promise<Metadata> {
  const { slug, contentId } = await params;
  const result = getMarketplaceContent(slug, contentId);
  if (!result) return {};

  const { app, item } = result;
  const title = `${item.title} | ${app.name} | Fabushi`;
  const url = siteUrl(`/apps/${app.slug}/content/${item.id}`);

  return {
    title,
    description: item.summary,
    alternates: { canonical: url },
    keywords: [app.name, contentTypeLabel(item.type), ...item.keywords],
    openGraph: {
      title,
      description: item.summary,
      url,
      siteName: "Fabushi 应用市场",
      locale: "zh_CN",
      type: "article",
      publishedTime: item.updatedAt,
      modifiedTime: item.updatedAt,
      tags: [...item.keywords],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description: item.summary,
    },
  };
}

export default async function ContentPage({ params }: ContentPageProps) {
  const { slug, contentId } = await params;
  const result = getMarketplaceContent(slug, contentId);
  if (!result) notFound();

  const { app, item } = result;
  const url = siteUrl(`/apps/${app.slug}/content/${item.id}`);
  const relatedContent = [
    ...app.content.filter((candidate) => candidate.id !== item.id).map((candidate) => ({ app, item: candidate })),
    ...marketplaceContent.filter(
      (candidate) => candidate.app.id !== app.id && candidate.item.keywords.some((keyword) => item.keywords.includes(keyword)),
    ),
    ...marketplaceContent.filter((candidate) => candidate.app.id !== app.id),
  ]
    .filter(
      (candidate, index, values) =>
        values.findIndex(
          (value) => value.app.id === candidate.app.id && value.item.id === candidate.item.id,
        ) === index,
    )
    .slice(0, 4);

  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": item.type === "release" ? "TechArticle" : "Article",
        "@id": `${url}#article`,
        headline: item.title,
        description: item.summary,
        url,
        datePublished: item.updatedAt,
        dateModified: item.updatedAt,
        articleSection: contentTypeLabel(item.type),
        keywords: item.keywords.join(", "),
        wordCount: item.body.join("").length,
        author: {
          "@type": "Organization",
          name: app.developer,
          url: siteUrl(`/apps/${app.slug}`),
        },
        publisher: {
          "@type": "Organization",
          name: "Fabushi",
          url: siteUrl("/"),
        },
        isPartOf: {
          "@type": ["SoftwareApplication", "WebApplication"],
          "@id": appEntityId(app),
          name: app.name,
          url: siteUrl(`/apps/${app.slug}`),
        },
        mainEntityOfPage: url,
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "应用市场", item: siteUrl("/") },
          { "@type": "ListItem", position: 2, name: app.name, item: siteUrl(`/apps/${app.slug}`) },
          { "@type": "ListItem", position: 3, name: item.title, item: url },
        ],
      },
    ],
  };

  return (
    <div className={styles.detailShell}>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />

      <header className={styles.detailHeader}>
        <div className={styles.detailHeaderInner}>
          <a className={styles.detailBrand} href={siteHref("/")}>
            <span className={styles.brandMark}>法</span>
            <span>Fabushi 内容搜索</span>
          </a>
          <nav className={styles.detailNav}>
            <a href={siteHref("/")}>应用市场</a>
            <a href={siteHref("/search")}>搜索内容</a>
            <a href={siteHref(`/apps/${app.slug}`)}>{app.name}</a>
            <a href={siteHref(`/miniapps/${app.id}`)}>打开应用</a>
          </nav>
        </div>
      </header>

      <main className={styles.detailMain}>
        <nav className={styles.breadcrumbs} aria-label="面包屑">
          <a href={siteHref("/")}>应用市场</a>
          <ChevronRight />
          <a href={siteHref(`/apps/${app.slug}`)}>{app.name}</a>
          <ChevronRight />
          <span>{item.title}</span>
        </nav>

        <div className={styles.articleLayout}>
          <article className={styles.articleCard}>
            <p className={styles.articleEyebrow}>
              {app.name} · {contentTypeLabel(item.type)}
            </p>
            <h1>{item.title}</h1>
            <p className={styles.articleSummary}>{item.summary}</p>
            <div className={styles.articleMeta}>
              <span><CalendarDays /> 更新于 {item.updatedAt}</span>
              <span><Clock3 /> 阅读约 {item.readingMinutes} 分钟</span>
              <span><BookOpen /> 内容 ID：{item.id}</span>
            </div>

            <div className={styles.articleBody}>
              {item.body.map((paragraph, index) => (
                <p key={`${item.id}:${index}`}>{paragraph}</p>
              ))}
            </div>

            <aside className={styles.articleCallout}>
              <strong>这是一个可直接搜索的内容入口</strong>
              <p>
                该页面使用稳定内容 ID、永久 URL、独立标题与摘要。用户可以从搜索结果直达这里，不必先进入应用首页逐层寻找。
              </p>
            </aside>

            <div className={styles.tagList}>
              {item.keywords.map((keyword) => (
                <a
                  key={keyword}
                  className={styles.detailTag}
                  href={siteHref(`/search?q=${encodeURIComponent(keyword)}`)}
                >
                  {keyword}
                </a>
              ))}
            </div>
          </article>

          <aside className={styles.articleAside}>
            <section className={styles.articleAppCard}>
              <div className={styles.articleAppTop}>
                <AppIcon label={app.icon} tone={app.tone} size="small" />
                <div>
                  <h2>{app.name}</h2>
                  <p>{app.subtitle}</p>
                </div>
              </div>
              <p>{app.description}</p>
              <div className={styles.articleAppActions}>
                <AppInstallActions appId={app.id} appName={app.name} />
                <a className={styles.detailSecondary} href={siteHref(`/apps/${app.slug}`)}>
                  查看应用详情 <ArrowRight />
                </a>
              </div>
            </section>

            <section className={styles.sidebarCard}>
              <h3>继续搜索</h3>
              <p>搜索应用、功能、指南、模板和工作流，并直接打开对应内容。</p>
              <div className={styles.articleAppActions}>
                <a className={styles.detailPrimary} href={siteHref(`/search?q=${encodeURIComponent(item.keywords[0] ?? app.name)}`)}>
                  搜索相关内容 <Search />
                </a>
              </div>
            </section>

            <section className={styles.sidebarCard}>
              <h3>相关内容</h3>
              <div className={styles.contentList}>
                {relatedContent.map(({ app: relatedApp, item: relatedItem }) => (
                  <a
                    key={`${relatedApp.id}:${relatedItem.id}`}
                    className={styles.contentListItem}
                    href={siteHref(`/apps/${relatedApp.slug}/content/${relatedItem.id}`)}
                  >
                    <span>
                      <h3>{relatedItem.title}</h3>
                      <p>{relatedApp.name} · {contentTypeLabel(relatedItem.type)}</p>
                    </span>
                    <ChevronRight />
                  </a>
                ))}
              </div>
            </section>

            <section className={styles.sidebarCard}>
              <h3>机器可读入口</h3>
              <p>公开搜索索引提供应用、内容 ID、关键词与永久链接，便于搜索引擎和 AI Agent 发现。</p>
              <div className={styles.articleAppActions}>
                <a className={styles.detailSecondary} href={siteHref("/search-index.json")}>
                  打开 JSON 索引 <ExternalLink />
                </a>
              </div>
            </section>
          </aside>
        </div>
      </main>
    </div>
  );
}
