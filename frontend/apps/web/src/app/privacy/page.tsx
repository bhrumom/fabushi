import type { Metadata } from "next";
import { brand, contactChannels } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const privacySections = [
  {
    label: "账户与身份",
    title: "只处理建立账户、维持登录和回应支持请求所必需的信息。",
    description:
      "当你申请测试、订阅发布通知或联系支持时，我们会优先收集完成这件事所需的最少信息，而不是为了营销而扩大范围。",
    points: [
      "常见信息包括邮箱地址、测试申请说明和你主动提供的设备信息。",
      "如果后续开放更多登录方式，会先说明用途和对应的处理边界。",
      "不会因为浏览官网而默认要求你先注册账户。",
    ],
  },
  {
    label: "设备与使用",
    title: "只在改进可用性、排查问题和保持服务稳定时使用必要的技术信息。",
    description:
      "官网、下载页和申请测试页的核心目标是帮助你判断 Fabushi 是否适合自己，因此我们更重视可用性与公开状态说明，而不是追求过度追踪。",
    points: [
      "可能会记录基础的设备、浏览器和访问日志，用于错误排查与站点运维。",
      "如果页面需要接入真实发布状态或公开数据，会优先说明其来源与展示目的。",
      "不会把与你无关的技术信息包装成必须同意的前置条件。",
    ],
  },
  {
    label: "内容与互动",
    title: "你主动提交的申请、反馈和问题说明，只会用于对应的沟通与处理流程。",
    description:
      "申请测试、反馈问题或讨论合作时，最重要的是把你的意图和后续去向讲清楚，让每一条信息都知道自己该落到哪里。",
    points: [
      "测试申请会用于资格筛选、下载通知和后续反馈联络。",
      "问题反馈会用于排查 bug、改进体验和补充 FAQ。",
      "合作沟通会用于判断是否需要进一步邮件或仓库协作。",
    ],
  },
  {
    label: "数据用途",
    title: "收集信息的目的主要是解释产品、承接下载、安排测试和回应支持。",
    description:
      "Fabushi 当前官网的职责很明确：先帮助人理解产品、判断状态、找到入口，再进入更深的使用流程，因此数据用途也应保持克制和可解释。",
    points: [
      "用于发送下载状态、测试资格和必要的支持回复。",
      "用于维护 FAQ、内容专栏和发布说明的准确性。",
      "用于保障站点安全、降低滥用和处理公开反馈。",
    ],
  },
  {
    label: "你的控制权",
    title: "你可以询问、更新或删除与自己相关的信息，并要求我们解释处理范围。",
    description:
      "无论你是第一次申请测试，还是已经在和团队沟通，都应该拥有清楚的退出和确认路径，而不是被迫留在一个不透明的流程里。",
    points: [
      "可以通过支持邮箱询问当前保留了哪些与你相关的申请或反馈信息。",
      "可以要求更新错误信息，或在不影响必要合规与安全记录的前提下申请删除。",
      "如果后续出现范围明显变化的处理方式，官网会先更新说明。",
    ],
  },
  {
    label: "更新与联系",
    title: "隐私说明会随着官网、下载链路和支持流程的变化而更新。",
    description:
      "这页不是为了凑一个合规链接，而是为了让首次访问、测试申请和长期关注 Fabushi 的人，都能先看到边界、支持方式和更新节奏。",
    points: [
      "当官网新增关键入口、表单或数据展示方式时，会同步修订这页说明。",
      "如果你对数据边界有疑问，优先通过公开支持邮箱联系。",
      "与下载、FAQ 和联系页保持互相可跳转，减少来回查找。",
    ],
  },
] as const;

export const metadata: Metadata = {
  title: `隐私说明 | ${brand.name}`,
  description: "查看 Fabushi 对账户、设备、内容互动、支持通道和用户权利的公开隐私说明。",
  alternates: {
    canonical: siteUrl("/privacy"),
  },
  keywords: ["Fabushi 隐私说明", "法布施隐私政策", "法布施支持", "法布施测试申请", "Fabushi 数据边界"],
};

export default function PrivacyPage() {
  const supportEmail = contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@fabushi.com";
  const supportHref = contactChannels.find((item) => item.href.startsWith("mailto:"))?.href ?? "mailto:support@fabushi.com";

  const privacyPageJsonLd = {
    "@context": "https://schema.org",
    "@type": "WebPage",
    name: `${brand.name} 隐私说明`,
    url: siteUrl("/privacy"),
    inLanguage: "zh-CN",
    description: "Fabushi 对账户、设备、内容互动、支持通道和用户权利的公开隐私说明。",
    about: {
      "@type": "Organization",
      name: `${brand.name} Fabushi`,
      url: siteUrl("/"),
      email: supportEmail,
    },
  };

  const breadcrumbJsonLd = {
    "@context": "https://schema.org",
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
        name: "隐私说明",
        item: siteUrl("/privacy"),
      },
    ],
  };

  return (
    <main className="inner-page">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(privacyPageJsonLd) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbJsonLd) }} />

      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">隐私说明</p>
          <h1>先把信息边界、支持路径和用户控制权讲清楚，再谈下载、申请和长期使用。</h1>
          <p className="lede">
            这页不是只给审核或法务看的补充链接，而是让第一次接触 Fabushi 的人，也能先判断这套产品在数据处理、支持响应和公开说明上是否足够可信。
          </p>
        </div>
      </section>

      <section className="band">
        <div className="section-heading">
          <p>我们怎么处理信息</p>
          <h2>官网先服务理解、下载和测试申请，所以隐私边界也应该保持克制、清楚、可复查。</h2>
        </div>
        <div className="governance-grid">
          {privacySections.map((item) => (
            <article key={item.label} className="governance-card">
              <span className="detail-label">{item.label}</span>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
              <ul className="channel-list">
                {item.points.map((point) => (
                  <li key={point}>{point}</li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>联系与下一步</p>
          <h2>如果你关心测试申请、账户边界或反馈处理方式，先走这些公开入口。</h2>
        </div>
        <div className="contact-grid">
          <a className="contact-card" href={supportHref}>
            <span>支持邮箱</span>
            <strong>{supportEmail}</strong>
            <p>适合询问测试申请、下载通知、数据边界和反馈处理方式。</p>
          </a>
          <a className="contact-card" href={siteHref("/contact")}>
            <span>联系页</span>
            <strong>查看公开通道</strong>
            <p>统一查看官网域名、仓库入口和对外沟通方式。</p>
          </a>
          <a className="contact-card" href={siteHref("/download")}>
            <span>下载状态</span>
            <strong>回到下载页</strong>
            <p>先确认当前开放什么、还在准备什么，再决定下一步动作。</p>
          </a>
        </div>
        <div className="inline-cta">
          <a className="primary-action" href={supportHref}>
            联系支持
          </a>
          <a className="secondary-action" href={siteHref("/faq")}>
            查看常见问题
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
