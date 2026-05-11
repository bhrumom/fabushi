import type { Metadata } from "next";
import { brand, contactChannels } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const contactUrl = siteUrl("/contact");
const contactTitle = `联系 | ${brand.name}`;
const contactDescription = "Fabushi 支持邮箱、官网域名和 GitHub 仓库入口。";

export const metadata: Metadata = {
  title: contactTitle,
  description: contactDescription,
  alternates: {
    canonical: contactUrl,
  },
  keywords: ["联系 Fabushi", "法布施支持邮箱", "Fabushi GitHub"],
  openGraph: {
    title: contactTitle,
    description: contactDescription,
    url: contactUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: contactTitle,
    description: contactDescription,
  },
};

export default function ContactPage() {
  const supportEmail = contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@fabushi.com";
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "ContactPage",
    name: `${brand.name} 联系方式`,
    url: contactUrl,
    inLanguage: "zh-CN",
    description: contactDescription,
    mainEntity: {
      "@type": "Organization",
      name: `${brand.name} Fabushi`,
      url: siteUrl("/"),
      email: supportEmail,
      sameAs: contactChannels.filter((item) => item.href.startsWith("https://")).map((item) => item.href),
    },
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
          <p className="eyebrow">联系</p>
          <h1>下载、反馈、合作，都从这里开始。</h1>
          <p className="lede">发邮件时请带上平台、设备、问题截图或合作方向。</p>
        </div>
      </section>

      <section className="band compact-band">
        <div className="contact-grid">
          {contactChannels.map((item) => (
            <a key={item.label} className="contact-card" href={siteHref(item.href)}>
              <span>{item.label}</span>
              <strong>{item.value}</strong>
              <p>{item.note}</p>
            </a>
          ))}
        </div>
        <div className="inline-cta">
          <a className="primary-action" href={`mailto:${supportEmail}`}>
            发送邮件
          </a>
          <a className="secondary-action" href={siteHref("/download")}>
            返回下载
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
