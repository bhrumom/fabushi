import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const faqUrl = siteUrl("/faq");
const faqTitle = `App 下载常见问题 | iOS、Android、桌面版与安装说明 | ${brand.name}`;
const faqDescription =
  "集中说明法布施大乘 App 的下载问题：正式版和测试版怎么选、桌面版从哪里下载、Android 下载慢怎么办、iOS 如何选择 TestFlight 或 App Store、安装失败怎么排查，以及联系支持前需要准备什么。";

const faqItems = [
  {
    questionZh: "我应该先下载正式版还是测试版？",
    questionEn: "Should I install the stable build or the beta build first?",
    answerZh: "更在意稳定性、准备长期使用，优先看正式版；想尽快体验新版本或新功能，再看测试版。下载前先确认平台、版本号和发布时间，会更稳。",
    answerEn: "Choose stable if you care more about installation stability and long-term use. Choose beta if you want newer builds or features first. It is steadier to confirm the platform, version, and publish date before downloading.",
  },
  {
    questionZh: "Android 下载慢或安装失败怎么办？",
    questionEn: "What should I do if Android download is slow or installation fails?",
    answerZh: "先重新点击当前版本卡片里的主下载入口，再确认下载的是对应平台和版本；如果仍然失败，把设备型号、系统版本和错误截图发给支持邮箱。",
    answerEn: "Use the main download button on the current release card again, then confirm that you downloaded the matching platform and version. If it still fails, send the device model, OS version, and an error screenshot to support.",
  },
  {
    questionZh: "iOS 应该选 TestFlight 还是 App Store？",
    questionEn: "Should I choose TestFlight or the App Store on iOS?",
    answerZh: "想体验测试版就选择 TestFlight；想直接安装正式版就选择 App Store。现在 iOS 正式版已经上架，普通用户优先选择 App Store 会更稳。",
    answerEn: "Choose TestFlight if you want the beta build. Choose the App Store if you want the stable release. The iOS stable release is now live, so most users should start with the App Store.",
  },
  {
    questionZh: "macOS、Windows、Linux 桌面版在哪里？",
    questionEn: "Where are the macOS, Windows, and Linux desktop builds?",
    answerZh: "进入下载页后，iOS 正式版会排在最前面，后面会按 macOS、Windows、Linux 分别显示桌面版 GitHub Release 下载入口和备用格式。",
    answerEn: "Open the download page: iOS stable appears first, followed by separate macOS, Windows, and Linux GitHub Release download paths with alternate formats.",
  },
  {
    questionZh: "下载前我最少要确认哪些信息？",
    questionEn: "What should I confirm before downloading?",
    answerZh: "至少先确认设备平台、版本偏好、发布时间，以及 iOS 是否要走 App Store 或 TestFlight。这样能明显减少下错包或装不上去的概率。",
    answerEn: "At minimum, confirm the device platform, version preference, publish date, and whether iOS should use the App Store or TestFlight. That reduces the chance of downloading the wrong build or hitting an avoidable install failure.",
  },
  {
    questionZh: "联系支持前最好准备什么？",
    questionEn: "What should I prepare before contacting support?",
    answerZh: "把设备型号、系统版本、下载入口、版本号，以及错误截图或报错文案一起发出，支持会更快定位问题。",
    answerEn: "Send the device model, OS version, download path, version number, and an error screenshot or message. That gives support enough context to diagnose the issue faster.",
  },
] as const;

export const metadata: Metadata = {
  title: faqTitle,
  description: faqDescription,
  alternates: {
    canonical: faqUrl,
  },
  keywords: [
    "下载 FAQ",
    "App 下载常见问题",
    "Android 下载",
    "iOS 下载",
    "macOS 下载",
    "Windows 下载",
    "Linux 下载",
    "桌面版下载",
    "TestFlight",
    "安装失败",
    "R2 下载",
    "版本说明",
    "Fabushi",
  ],
  openGraph: {
    title: faqTitle,
    description: faqDescription,
    url: faqUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: faqTitle,
    description: faqDescription,
  },
};

export default function FaqPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "App 下载常见问题",
        url: faqUrl,
        description: faqDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: [
          "App 下载",
          "Android 下载",
          "iOS 下载",
          "TestFlight",
          "安装说明",
          "版本说明",
        ],
      },
      {
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
            name: "下载 FAQ",
            item: faqUrl,
          },
        ],
      },
      {
        "@type": "FAQPage",
        mainEntity: faqItems.map((item) => ({
          "@type": "Question",
          name: item.questionZh,
          acceptedAnswer: {
            "@type": "Answer",
            text: item.answerZh,
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
            <LocalizedText zh="下载 FAQ" en="Download FAQ" />
          </p>
          <h1>
            <LocalizedText zh="先把下载、安装和版本选择里最常卡住的问题讲清楚。" en="Clarify the download, installation, and version questions that block setup most often." />
          </h1>
          <p className="lede">
            <LocalizedText zh="这一页只保留和下载转化直接相关的问题，帮助更快完成平台选择、安装排查和支持沟通。" en="This page keeps only the questions that directly support download conversion, platform choice, installation troubleshooting, and support handoff." />
          </p>
        </div>
      </section>

      <section className="band compact-band">
        <div className="faq-list full">
          {faqItems.map((item) => (
            <details key={item.questionEn} className="faq-item">
              <summary>
                <LocalizedText zh={item.questionZh} en={item.questionEn} />
              </summary>
              <p>
                <LocalizedText zh={item.answerZh} en={item.answerEn} />
              </p>
            </details>
          ))}
        </div>
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/download")}>
            <LocalizedText zh="查看下载入口" en="View downloads" />
          </a>
          <a className="secondary-action" href={siteHref("/contact")}>
            <LocalizedText zh="联系支持" en="Contact support" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
