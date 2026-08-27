import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ArrowRight, ChevronRight, ExternalLink, Search, Sparkles } from "lucide-react";
import { AppIcon } from "../../../components/marketplace/app-icon";
import { AppInstallActions } from "../../../components/marketplace/app-install-actions";
import styles from "../../../components/marketplace/marketplace.module.css";
import {
  appEntityId,
  appMachineUrl,
  fabushiAnswerIntents,
  getAnswerIntent,
} from "../../../lib/ai-discovery";
import { getMarketplaceApp } from "../../../lib/marketplace";
import { siteHref, siteUrl } from "../../../lib/site-url";

type AnswerPageProps = {
  params: Promise<{ slug: string }>;
};

export const dynamicParams = false;

export function generateStaticParams() {
  return fabushiAnswerIntents.map((answer) => ({ slug: answer.slug }));
}

export async function generateMetadata({ params }: AnswerPageProps): Promise<Metadata> {
  const { slug } = await params;
  const answer = getAnswerIntent(slug);
  if (!answer) return {};

  const title = `${answer.question} | Fabushi Answers`;
  const url = siteUrl(`/answers/${answer.slug}`);

  return {
    title,
    description: answer.answer,
    alternates: { canonical: url },
    keywords: [...answer.keywords, "Fabushi Mini App", "AI 应用发现"],
    openGraph: {
      title,
      description: answer.answer,
      url,
      siteName: "Fabushi",
      locale: "zh_CN",
      type: "article",
      publishedTime: answer.updatedAt,
      modifiedTime: answer.updatedAt,
    },
    twitter: {
      card: "summary_large_image",
      title,
      description: answer.answer,
    },
  };
}

export default async function AnswerPage({ params }: AnswerPageProps) {
  const { slug } = await params;
  const answer = getAnswerIntent(slug);
  if (!answer) notFound();

  const app = getMarketplaceApp(answer.recommendedAppSlug);
  if (!app) notFound();

  const url = siteUrl(`/answers/${answer.slug}`);
  const relatedApps = answer.relatedAppSlugs
    .map((appSlug) => getMarketplaceApp(appSlug))
    .filter((candidate) => Boolean(candidate));

  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "QAPage",
        "@id": `${url}#page`,
        url,
        inLanguage: "zh-CN",
        datePublished: answer.updatedAt,
        dateModified: answer.updatedAt,
        mainEntity: {
          "@type": "Question",
          "@id": `${url}#question`,
          name: answer.question,
          text: answer.question,
          keywords: answer.keywords.join(", "),
          acceptedAnswer: {
            "@type": "Answer",
            "@id": `${url}#answer`,
            text: answer.answer,
            url,
            about: { "@id": appEntityId(app) },
          },
        },
      },
      {
        "@type": ["SoftwareApplication", "WebApplication"],
        "@id": appEntityId(app),
        name: app.name,
        alternateName: app.englishName,
        description: app.description,
        url: siteUrl(`/apps/${app.slug}`),
        softwareVersion: app.version,
        featureList: app.capabilities,
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "Fabushi", item: siteUrl("/") },
          { "@type": "ListItem", position: 2, name: "Answers", item: siteUrl("/ai/answers.json") },
          { "@type": "ListItem", position: 3, name: answer.question, item: url },
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
            <span>Fabushi Answers</span>
          </a>
          <nav className={styles.detailNav}>
            <a href={siteHref("/")}>打开 Fabushi</a>
            <a href={siteHref("/apps")}>应用市场</a>
            <a href={siteHref("/search")}>搜索</a>
            <a href={siteHref("/ai/answers.json")}>AI JSON</a>
          </nav>
        </div>
      </header>

      <main className={styles.detailMain}>
        <nav className={styles.breadcrumbs} aria-label="面包屑">
          <a href={siteHref("/")}>Fabushi</a>
          <ChevronRight />
          <a href={siteHref("/ai/answers.json")}>Answers</a>
          <ChevronRight />
          <span>{answer.question}</span>
        </nav>

        <div className={styles.articleLayout}>
          <article className={styles.articleCard}>
            <p className={styles.articleEyebrow}>
              <Sparkles /> AI 应用发现
            </p>
            <h1>{answer.question}</h1>
            <p className={styles.articleSummary}>{answer.answer}</p>

            <aside className={styles.articleCallout}>
              <strong>推荐：{app.name}</strong>
              <p>{app.description}</p>
            </aside>

            <h2>为什么适合</h2>
            <div className={styles.detailHighlightGrid}>
              {app.highlights.map((highlight) => (
                <section key={highlight.title} className={styles.detailHighlightCard}>
                  <h3>{highlight.title}</h3>
                  <p>{highlight.description}</p>
                </section>
              ))}
            </div>

            <h2>可用能力</h2>
            <div className={styles.tagList}>
              {app.capabilities.map((capability) => (
                <span key={capability} className={styles.detailTag}>
                  {capability}
                </span>
              ))}
            </div>

            <h2>权限与边界</h2>
            <p>{app.permissions.join("；")}。涉及写入、安装、外部系统或本地改动时，Fabushi Host 会保留用户确认。</p>

            <div className={styles.tagList}>
              {answer.keywords.map((keyword) => (
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
              <div className={styles.articleAppActions}>
                <AppInstallActions appId={app.id} appName={app.name} />
                <a className={styles.detailSecondary} href={siteHref(`/apps/${app.slug}`)}>
                  查看应用实体 <ArrowRight />
                </a>
              </div>
            </section>

            <section className={styles.sidebarCard}>
              <h3>机器可读记录</h3>
              <p>AI 可以读取稳定 entity ID、能力、权限、版本、内容和启动入口。</p>
              <div className={styles.articleAppActions}>
                <a className={styles.detailSecondary} href={appMachineUrl(app)}>
                  打开应用 JSON <ExternalLink />
                </a>
                <a className={styles.detailSecondary} href={siteHref("/ai/answers.json")}>
                  打开 Answers feed <ExternalLink />
                </a>
              </div>
            </section>

            {relatedApps.length > 0 ? (
              <section className={styles.sidebarCard}>
                <h3>相关应用</h3>
                <div className={styles.contentList}>
                  {relatedApps.map((relatedApp) =>
                    relatedApp ? (
                      <a
                        key={relatedApp.id}
                        className={styles.contentListItem}
                        href={siteHref(`/apps/${relatedApp.slug}`)}
                      >
                        <span>
                          <h3>{relatedApp.name}</h3>
                          <p>{relatedApp.subtitle}</p>
                        </span>
                        <ChevronRight />
                      </a>
                    ) : null,
                  )}
                </div>
              </section>
            ) : null}

            <section className={styles.sidebarCard}>
              <h3>继续搜索</h3>
              <p>搜索更多应用、能力、指南、模板和工作流。</p>
              <div className={styles.articleAppActions}>
                <a
                  className={styles.detailPrimary}
                  href={siteHref(`/search?q=${encodeURIComponent(answer.keywords[0] ?? app.name)}`)}
                >
                  搜索相关能力 <Search />
                </a>
              </div>
            </section>
          </aside>
        </div>
      </main>
    </div>
  );
}
