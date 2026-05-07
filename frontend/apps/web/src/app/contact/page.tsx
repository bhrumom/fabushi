import type { Metadata } from "next";
import { brand, contactChannels } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

export const metadata: Metadata = {
  title: `联系 | ${brand.name}`,
  description: "查看 Fabushi 的支持邮箱、官网域名和公开仓库入口。",
  alternates: {
    canonical: siteUrl("/contact"),
  },
  keywords: ["联系 Fabushi", "法布施支持邮箱", "法布施官网", "Fabushi GitHub", "法布施合作"],
};

export default function ContactPage() {
  const supportEmail = contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@fabushi.com";
  const contactPageJsonLd = {
    "@context": "https://schema.org",
    "@type": "ContactPage",
    name: `${brand.name} 联系方式`,
    url: siteUrl("/contact"),
    inLanguage: "zh-CN",
    description: "Fabushi 的支持邮箱、官网域名与公开仓库入口。",
    mainEntity: {
      "@type": "Organization",
      name: `${brand.name} Fabushi`,
      url: siteUrl("/"),
      email: supportEmail,
      sameAs: contactChannels.filter((item) => item.href.startsWith("https://")).map((item) => item.href),
      contactPoint: [
        {
          "@type": "ContactPoint",
          contactType: "customer support",
          email: supportEmail,
          availableLanguage: ["zh-CN"],
        },
      ],
    },
  };

  return (
    <main className="inner-page">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(contactPageJsonLd) }} />

      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">联系</p>
          <h1>官网至少要给出清楚、稳定、能回应的联系入口。</h1>
          <p className="lede">
            当前最重要的是把支持邮箱、官网域名和公开仓库入口放到明确位置，让下载申请、测试资格和问题反馈都有固定去处。
          </p>
        </div>
      </section>

      <section className="band">
        <div className="contact-grid">
          {contactChannels.map((item) => (
            <a key={item.label} className="contact-card" href={siteHref(item.href)}>
              <span>{item.label}</span>
              <strong>{item.value}</strong>
              <p>{item.note}</p>
            </a>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>建议用途</p>
          <h2>把沟通入口的职责区分清楚，能减少很多来回确认。</h2>
        </div>
        <ol className="roadmap-list">
          <li>下载申请、测试资格和正式链接通知，优先走支持邮箱。</li>
          <li>公开开发进度、问题跟踪和可复查记录，优先走 GitHub 仓库。</li>
          <li>品牌介绍、专题内容和长期对外入口，统一落到官网域名。</li>
        </ol>
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/apply")}>
            去申请测试
          </a>
          <a className="secondary-action" href={siteHref("/download")}>
            回到下载页
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
