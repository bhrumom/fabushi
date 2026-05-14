import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const applyUrl = siteUrl("/apply");
const applyTitle = `Beta Apply | ${brand.name}`;
const applyDescription = "Choose the Fabushi iOS, Android, or partner application path.";

const applicationTracks = [
  {
    nameZh: "iOS TestFlight",
    nameEn: "iOS TestFlight",
    summaryZh: "适合想提前体验 iPhone 或 iPad 新版本的人。",
    summaryEn: "For people who want early access on iPhone or iPad.",
    checklistZh: ["留下 Apple ID 邮箱", "写明设备型号", "告诉我们最想体验的功能"],
    checklistEn: ["Share the Apple ID email", "Include the device model", "Tell us which feature you care about most"],
    ctaHref: "/download",
    ctaLabelZh: "先看 iOS 下载状态",
    ctaLabelEn: "See iOS beta status",
  },
  {
    nameZh: "Android Beta",
    nameEn: "Android Beta",
    summaryZh: "适合想直接安装 APK 并尽快反馈问题的人。",
    summaryEn: "For people who want the APK quickly and can share feedback fast.",
    checklistZh: ["写明手机品牌和系统版本", "说明是否能安装外部 APK", "留下常用邮箱"],
    checklistEn: ["Include phone brand and Android version", "Tell us if side-loading APKs is available", "Leave a regular contact email"],
    ctaHref: "/download",
    ctaLabelZh: "先看 Android 下载状态",
    ctaLabelEn: "See Android beta status",
  },
  {
    nameZh: "合作沟通",
    nameEn: "Partnership",
    summaryZh: "适合机构、共修组织或内容合作方联系。",
    summaryEn: "For organizations, practice groups, or content partnerships.",
    checklistZh: ["说明你的组织或项目", "写明合作诉求", "留下稳定联系邮箱"],
    checklistEn: ["Describe the organization or project", "Explain the kind of collaboration you want", "Leave a reliable contact email"],
    ctaHref: "/contact",
    ctaLabelZh: "前往联系页",
    ctaLabelEn: "Open contact page",
  },
] as const;

const applyTips = [
  {
    zh: "写明平台和设备",
    en: "Mention the platform and device",
  },
  {
    zh: "留下常用邮箱",
    en: "Leave a reachable email",
  },
  {
    zh: "说明最想体验的功能",
    en: "Say which feature you want most",
  },
] as const;

export const metadata: Metadata = {
  title: applyTitle,
  description: applyDescription,
  alternates: {
    canonical: applyUrl,
  },
  keywords: ["Fabushi beta apply", "Android Beta", "TestFlight"],
  openGraph: {
    title: applyTitle,
    description: applyDescription,
    url: applyUrl,
    siteName: "Fabushi",
    locale: "en_US",
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
        name: `${brand.name} Beta Apply`,
        url: applyUrl,
        inLanguage: "en",
        description: applyDescription,
      },
      {
        "@type": "ItemList",
        itemListElement: applicationTracks.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          item: {
            "@type": "EntryPoint",
            name: item.nameEn,
            description: item.summaryEn,
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
          <p className="eyebrow">
            <LocalizedText zh="申请测试" en="Apply" />
          </p>
          <h1>
            <LocalizedText zh="选一个入口，直接发出申请。" en="Choose the right path and send the request directly." />
          </h1>
          <p className="lede">
            <LocalizedText zh="iOS TestFlight、Android Beta 和合作沟通分开处理。" en="iOS TestFlight, Android beta, and partnership requests are handled separately." />
          </p>
        </div>
      </section>

      <section className="band compact-band">
        <div className="application-grid">
          {applicationTracks.map((item) => (
            <article key={item.nameEn} className="application-card">
              <p className="eyebrow">
                <LocalizedText zh={item.nameZh} en={item.nameEn} />
              </p>
              <h2>
                <LocalizedText zh={item.nameZh} en={item.nameEn} />
              </h2>
              <p>
                <LocalizedText zh={item.summaryZh} en={item.summaryEn} />
              </p>
              <ol className="application-list">
                {item.checklistZh.map((_, index) => (
                  <li key={`${item.nameEn}-${index}`}>
                    <LocalizedText zh={item.checklistZh[index]} en={item.checklistEn[index]} />
                  </li>
                ))}
              </ol>
              <a className="primary-action" href={siteHref(item.ctaHref)}>
                <LocalizedText zh={item.ctaLabelZh} en={item.ctaLabelEn} />
              </a>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="准备" en="Prepare" />
          </p>
          <h2>
            <LocalizedText zh="三条信息足够开始。" en="Three details are enough to get started." />
          </h2>
        </div>
        <div className="note-grid">
          {applyTips.map((item) => (
            <p key={item.en}>
              <LocalizedText zh={item.zh} en={item.en} />
            </p>
          ))}
        </div>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/download")}>
            <LocalizedText zh="回到下载" en="Back to downloads" />
          </a>
          <a className="secondary-action" href={siteHref("/privacy")}>
            <LocalizedText zh="隐私说明" en="Privacy" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
