import type { Metadata } from "next";
import { betaApplicationTracks, brand } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const applyUrl = siteUrl("/apply");
const applyTitle = `申请测试 | ${brand.name}`;
const applyDescription = "选择 Fabushi iOS、Android 或合作申请入口。";

const applyTips = ["写明平台和设备", "留下常用邮箱", "说明最想体验的功能"] as const;

export const metadata: Metadata = {
  title: applyTitle,
  description: applyDescription,
  alternates: {
    canonical: applyUrl,
  },
  keywords: ["法布施内测", "Fabushi 申请测试", "Android Beta", "TestFlight"],
  openGraph: {
    title: applyTitle,
    description: applyDescription,
    url: applyUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: applyTitle,
    description: applyDescription,
  },
};

export default function ApplyPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "CollectionPage",
        name: `${brand.name} 申请测试`,
        url: applyUrl,
        inLanguage: "zh-CN",
        description: applyDescription,
      },
      {
        "@type": "ItemList",
        itemListElement: betaApplicationTracks.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          item: {
            "@type": "EntryPoint",
            name: item.name,
            description: item.summary,
            urlTemplate: siteHref(item.ctaHref),
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
          <p className="eyebrow">申请测试</p>
          <h1>选一个入口，直接发出申请。</h1>
          <p className="lede">iOS TestFlight、Android Beta 和合作沟通分开处理。</p>
        </div>
      </section>

      <section className="band compact-band">
        <div className="application-grid">
          {betaApplicationTracks.map((item) => (
            <article key={item.name} className="application-card">
              <p className="eyebrow">{item.name}</p>
              <h2>{item.name}</h2>
              <p>{item.summary}</p>
              <ol className="application-list">
                {item.checklist.map((entry) => (
                  <li key={entry}>{entry}</li>
                ))}
              </ol>
              <a className="primary-action" href={siteHref(item.ctaHref)}>
                {item.ctaLabel}
              </a>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading tight">
          <p>准备</p>
          <h2>三条信息足够开始。</h2>
        </div>
        <div className="note-grid">
          {applyTips.map((item) => (
            <p key={item}>{item}</p>
          ))}
        </div>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/download")}>
            回到下载
          </a>
          <a className="secondary-action" href={siteHref("/privacy")}>
            隐私说明
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
