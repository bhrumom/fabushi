import type { Metadata } from "next";
import { notFound } from "next/navigation";
import {
  ArrowRight,
  Check,
  ChevronRight,
  LockKeyhole,
  Search,
  ShieldCheck,
  Sparkles,
} from "lucide-react";
import { AppIcon } from "../../../components/marketplace/app-icon";
import { AppInstallActions } from "../../../components/marketplace/app-install-actions";
import styles from "../../../components/marketplace/marketplace.module.css";
import { appEntityId, appMachineUrl } from "../../../lib/ai-discovery";
import {
  MARKETPLACE_CATEGORY_LABELS,
  getMarketplaceApp,
  marketplaceApps,
} from "../../../lib/marketplace";
import { siteHref, siteUrl } from "../../../lib/site-url";

type AppDetailsPageProps = {
  params: Promise<{ slug: string }>;
};

export const dynamicParams = false;

export function generateStaticParams() {
  return marketplaceApps.map((app) => ({ slug: app.slug }));
}

export async function generateMetadata({ params }: AppDetailsPageProps): Promise<Metadata> {
  const { slug } = await params;
  const app = getMarketplaceApp(slug);
  if (!app) return {};

  const title = `${app.name} | Fabushi 应用市场`;
  const description = `${app.subtitle}。${app.description}`;
  const url = siteUrl(`/apps/${app.slug}`);

  return {
    title,
    description,
    alternates: { canonical: url },
    keywords: [app.name, app.englishName, ...app.tags, ...app.capabilities, "Fabushi Mini App"],
    openGraph: {
      title,
      description,
      url,
      siteName: "Fabushi 应用市场",
      locale: "zh_CN",
      type: "website",
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
    },
  };
}

export default async function AppDetailsPage({ params }: AppDetailsPageProps) {
  const { slug } = await params;
  const app = getMarketplaceApp(slug);
  if (!app) notFound();

  const url = siteUrl(`/apps/${app.slug}`);
  const relatedApps = marketplaceApps
    .filter((candidate) => candidate.id !== app.id)
    .sort((left, right) => Number(right.category === app.category) - Number(left.category === app.category))
    .slice(0, 3);
  const faqs = [
    {
      question: `如何开始使用${app.name}？`,
      answer: "可以直接点击“立即打开”试用，也可以先安装到“我的应用”，之后从 Fabushi 网页、桌面端或移动端继续使用。",
    },
    {
      question: `${app.name}会申请哪些权限？`,
      answer: `${app.permissions.join("；")}。涉及写入、外部系统或本地改动的操作会在执行前单独确认。`,
    },
    {
      question: `${app.name}如何收费？`,
      answer: `${app.pricing.label}。${app.pricing.detail}`,
    },
  ];

  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": ["SoftwareApplication", "WebApplication"],
        "@id": appEntityId(app),
        identifier: app.id,
        name: app.name,
        alternateName: app.englishName,
        description: app.description,
        url,
        mainEntityOfPage: url,
        inLanguage: ["zh-CN", "en"],
        applicationSuite: "Fabushi",
        isAccessibleForFree: true,
        installUrl: siteUrl(`/apps/${app.slug}`),
        downloadUrl: siteUrl("/download"),
        sameAs: [appMachineUrl(app)],
        applicationCategory: MARKETPLACE_CATEGORY_LABELS[app.category],
        applicationSubCategory: app.tags,
        operatingSystem: "Web, macOS, Windows, Linux, iOS, Android",
        softwareVersion: app.version,
        dateModified: app.updatedAt,
        featureList: app.capabilities,
        permissions: app.permissions.join("；"),
        publisher: {
          "@type": "Organization",
          "@id": siteUrl("/#organization"),
          name: app.developer,
          url: siteUrl("/"),
        },
        provider: { "@id": siteUrl("/#organization") },
        creator: { "@id": siteUrl("/#organization") },
        offers: {
          "@type": "Offer",
          price: "0",
          priceCurrency: "CNY",
          description: app.pricing.detail,
          availability: "https://schema.org/InStock",
          url,
        },
        additionalProperty: [
          {
            "@type": "PropertyValue",
            name: "capabilities",
            value: app.capabilities.join("；"),
          },
          {
            "@type": "PropertyValue",
            name: "permissions",
            value: app.permissions.join("；"),
          },
          {
            "@type": "PropertyValue",
            name: "agentInterface",
            value: "WebMCP",
            url: siteUrl("/llms.txt"),
          },
          {
            "@type": "PropertyValue",
            name: "machineReadableRecord",
            value: appMachineUrl(app),
          },
        ],
        potentialAction: {
          "@type": "UseAction",
          target: {
            "@type": "EntryPoint",
            urlTemplate: siteUrl(`/miniapps/${app.id}`),
            actionPlatform: [
              "https://schema.org/DesktopWebPlatform",
              "https://schema.org/MobileWebPlatform",
            ],
          },
        },
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "应用市场", item: siteUrl("/") },
          { "@type": "ListItem", position: 2, name: MARKETPLACE_CATEGORY_LABELS[app.category], item: siteUrl(`/?category=${app.category}`) },
          { "@type": "ListItem", position: 3, name: app.name, item: url },
        ],
      },
      {
        "@type": "FAQPage",
        mainEntity: faqs.map((faq) => ({
          "@type": "Question",
          name: faq.question,
          acceptedAnswer: { "@type": "Answer", text: faq.answer },
        })),
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
            <span>Fabushi 应用市场</span>
          </a>
          <nav className={styles.detailNav}>
            <a href={siteHref("/")}>发现应用</a>
            <a href={siteHref("/search")}>搜索内容</a>
            <a href={siteHref("/miniapps/bot-father/commerce")}>开发者中心</a>
            <a href={siteHref("/download")}>下载客户端</a>
          </nav>
        </div>
      </header>

      <main className={styles.detailMain}>
        <nav className={styles.breadcrumbs} aria-label="面包屑">
          <a href={siteHref("/")}>应用市场</a>
          <ChevronRight />
          <a href={siteHref(`/?category=${app.category}`)}>{MARKETPLACE_CATEGORY_LABELS[app.category]}</a>
          <ChevronRight />
          <span>{app.name}</span>
        </nav>

        <section className={styles.appHeroCard}>
          <AppIcon label={app.icon} tone={app.tone} size="large" />
          <div className={styles.appHeroCopy}>
            <div className={styles.appHeroTitleLine}>
              <h1>{app.name}</h1>
              {app.verified ? (
                <span className={styles.verified} title="已验证开发者" aria-label="已验证开发者">
                  <Check />
                </span>
              ) : null}
            </div>
            <p className={styles.appHeroSubtitle}>{app.subtitle}</p>
            <p className={styles.appHeroDescription}>{app.description}</p>
            <div className={styles.appHeroDeveloper}>
              <span>由 {app.developer} 开发</span>
              <span className={styles.detailBadge}>已验证</span>
              <span className={styles.detailBadge}>Mini App</span>
              <span className={styles.detailBadge}>WebMCP</span>
            </div>
          </div>
          <div className={styles.heroInstall}>
            <AppInstallActions appId={app.id} appName={app.name} />
            <small>{app.pricing.label} · 安装后可在所有 Fabushi 客户端继续</small>
          </div>
        </section>

        <section className={styles.statsGrid} aria-label="应用信息">
          <div className={styles.statItem}>
            <small>分类</small>
            <strong>{MARKETPLACE_CATEGORY_LABELS[app.category]}</strong>
          </div>
          <div className={styles.statItem}>
            <small>版本</small>
            <strong>v{app.version}</strong>
          </div>
          <div className={styles.statItem}>
            <small>最近更新</small>
            <strong>{app.updatedAt}</strong>
          </div>
          <div className={styles.statItem}>
            <small>内容入口</small>
            <strong>{app.content.length} 条可搜索内容</strong>
          </div>
        </section>

        <div className={styles.detailGrid}>
          <div className={styles.detailCard}>
            <section className={styles.detailSection}>
              <h2>像原生应用一样打开</h2>
              <p>无需跳转到另一个网站或重新登录。应用在统一容器中全屏运行，同时保留平台导航、权限确认与跨端状态。</p>
              <div className={styles.screenshotGrid} aria-label={`${app.name} 界面预览`}>
                {app.highlights.map((highlight) => (
                  <article key={highlight.title} className={styles.screenshotCard}>
                    <strong>{highlight.title}</strong>
                    <p>{highlight.description}</p>
                  </article>
                ))}
              </div>
            </section>

            <section className={styles.detailSection}>
              <h2>主要功能</h2>
              <p>上架信息与实际运行能力使用同一份应用身份，避免“详情页写一套、应用里做另一套”。</p>
              <div className={styles.featureGrid}>
                {app.capabilities.map((capability, index) => (
                  <article key={capability} className={styles.featureItem}>
                    <strong>{capability}</strong>
                    <p>{app.highlights[index % app.highlights.length]?.description}</p>
                  </article>
                ))}
              </div>
            </section>

            <section className={styles.detailSection}>
              <h2>内容级搜索入口</h2>
              <p>应用不是只有一个商店页面。指南、模板、内容集和工作流都拥有稳定 URL，可被站内搜索、外部搜索引擎和 AI Agent 精确发现。</p>
              <div className={styles.contentList}>
                {app.content.map((item) => (
                  <a
                    key={item.id}
                    className={styles.contentListItem}
                    href={siteHref(`/apps/${app.slug}/content/${item.id}`)}
                  >
                    <span>
                      <h3>{item.title}</h3>
                      <p>{item.summary}</p>
                    </span>
                    <ArrowRight />
                  </a>
                ))}
              </div>
            </section>

            <section className={styles.detailSection}>
              <h2>常见问题</h2>
              <div className={styles.faqList}>
                {faqs.map((faq) => (
                  <article key={faq.question} className={styles.faqItem}>
                    <strong>{faq.question}</strong>
                    <p>{faq.answer}</p>
                  </article>
                ))}
              </div>
            </section>
          </div>

          <aside>
            <section className={styles.sidebarCard}>
              <h2>应用信息</h2>
              <div className={styles.sidebarRows}>
                <div className={styles.sidebarRow}><span>开发者</span><strong>{app.developer}</strong></div>
                <div className={styles.sidebarRow}><span>价格</span><strong>{app.pricing.label}</strong></div>
                <div className={styles.sidebarRow}><span>版本</span><strong>{app.version}</strong></div>
                <div className={styles.sidebarRow}><span>更新日期</span><strong>{app.updatedAt}</strong></div>
              </div>
            </section>

            <section className={styles.sidebarCard}>
              <h3>权限说明</h3>
              <p>只在需要时申请；写入、外部系统和本地改动会在执行前确认。</p>
              <ul className={styles.list}>
                {app.permissions.map((permission) => (
                  <li key={permission}><LockKeyhole /> <span>{permission}</span></li>
                ))}
              </ul>
            </section>

            <section className={styles.sidebarCard}>
              <h3>能力与标签</h3>
              <div className={styles.tagList}>
                {app.tags.map((tag) => <span key={tag} className={styles.detailTag}>{tag}</span>)}
              </div>
            </section>

            <section className={styles.sidebarCard}>
              <h3>可被 AI Agent 调用</h3>
              <p>应用的 MCP 工具可映射为 WebMCP 网站工具，搜索、读取和操作使用同一能力定义。</p>
              <ul className={styles.list}>
                <li><Search /> <span>可发现的搜索入口</span></li>
                <li><ShieldCheck /> <span>只读与写入权限分离</span></li>
                <li><Sparkles /> <span>结构化工具结果</span></li>
              </ul>
            </section>

            <section className={styles.sidebarCard}>
              <h3>更多同类应用</h3>
              <div className={styles.contentList}>
                {relatedApps.map((related) => (
                  <a key={related.id} className={styles.contentListItem} href={siteHref(`/apps/${related.slug}`)}>
                    <span>
                      <h3>{related.name}</h3>
                      <p>{related.subtitle}</p>
                    </span>
                    <ChevronRight />
                  </a>
                ))}
              </div>
            </section>
          </aside>
        </div>
      </main>
    </div>
  );
}
