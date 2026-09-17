import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../components/localized-text";
import { SiteFooter } from "../components/site-footer";
import { SiteHeader } from "../components/site-header";
import { siteHref, siteUrl } from "../lib/site-url";

const WEB_APP_URL = "https://web.ombhrum.com/";
const homeUrl = siteUrl("/");
const homeTitle = "Fabushi | Messenger、AI Agents 与 Mini Apps";
const homeDescription =
  "Fabushi 官方网站。了解跨平台 Messenger、AI Agents、Mini Apps、WebMCP、应用市场与各平台下载方式；Web 应用独立运行在 web.ombhrum.com。";

const PRODUCT_AREAS = [
  {
    titleZh: "Messenger",
    titleEn: "Messenger",
    bodyZh: "把联系人、群组、Bot 与 AI Agent 放进同一套消息体验，避免在多个产品界面之间切换。",
    bodyEn: "Keep people, groups, bots, and AI agents inside one coherent messaging experience.",
  },
  {
    titleZh: "AI Agents",
    titleEn: "AI Agents",
    bodyZh: "大乘运行时承载思考、工具调用、自动化与电脑能力，让 Agent 的工作过程直接回到会话。",
    bodyEn: "Mahayana carries reasoning, tools, automations, and computer capabilities back into the conversation.",
  },
  {
    titleZh: "Mini Apps 与 WebMCP",
    titleEn: "Mini Apps & WebMCP",
    bodyZh: "像消息应用里的小程序一样发现、安装、打开和调用应用，同时让 Bot 与 Web UI 保持同步。",
    bodyEn: "Discover and run Mini Apps from conversations while keeping bot actions and Web UI in sync.",
  },
] as const;

const PLATFORM_LINKS = [
  { href: WEB_APP_URL, zh: "Fabushi Web", en: "Fabushi Web", external: true },
  { href: "/download", zh: "桌面与移动端", en: "Desktop & Mobile", external: false },
  { href: "/apps", zh: "应用与 Mini Apps", en: "Apps & Mini Apps", external: false },
  { href: "/faq", zh: "常见问题", en: "FAQ", external: false },
] as const;

export const metadata: Metadata = {
  title: homeTitle,
  description: homeDescription,
  alternates: { canonical: homeUrl },
  keywords: [
    "Fabushi",
    "Messenger",
    "AI Agent",
    "Mahayana",
    "Mini App",
    "WebMCP",
    "应用市场",
    "跨平台",
  ],
  openGraph: {
    title: homeTitle,
    description: homeDescription,
    url: homeUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: homeTitle,
    description: homeDescription,
  },
};

export default function HomePage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        "@id": `${homeUrl}#organization`,
        name: brand.name,
        alternateName: "Fabushi",
        url: homeUrl,
      },
      {
        "@type": "WebSite",
        "@id": `${homeUrl}#website`,
        name: "Fabushi",
        url: homeUrl,
        publisher: { "@id": `${homeUrl}#organization` },
      },
      {
        "@type": "SoftwareApplication",
        name: "Fabushi",
        applicationCategory: "CommunicationApplication",
        operatingSystem: "Web, macOS, Windows, Linux, iOS, Android",
        url: homeUrl,
        installUrl: siteUrl("/download"),
        description: homeDescription,
      },
    ],
  };

  return (
    <main className="page-shell">
      <script
        type="application/ld+json"
        suppressHydrationWarning
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />

      <header className="hero">
        <SiteHeader />
        <div className="hero-grid">
          <section className="hero-copy" aria-labelledby="home-title">
            <div className="brand-kicker">
              <img src={siteHref("/product/app-icon.png")} alt="" />
              <span>FABUSHI</span>
            </div>
            <h1 id="home-title">
              <LocalizedText
                zh={
                  <>
                    <span className="hero-title-line">消息、AI 与应用，</span>
                    <span className="hero-title-line">在一个地方协作。</span>
                  </>
                }
                en={
                  <>
                    <span className="hero-title-line">Messaging, AI, and apps.</span>
                    <span className="hero-title-line">One connected place.</span>
                  </>
                }
              />
            </h1>
            <p className="hero-subtitle">
              <LocalizedText
                zh="Fabushi 是跨平台 Messenger 与 AI Agent Host。官网用于了解产品、应用、下载与支持；真正的浏览器应用独立运行在 web.ombhrum.com。"
                en="Fabushi is a cross-platform Messenger and AI Agent Host. This site explains the product, apps, downloads, and support; the browser application runs separately at web.ombhrum.com."
              />
            </p>
            <div className="hero-actions">
              <a className="primary-action" href={WEB_APP_URL}>
                <LocalizedText zh="打开 Fabushi Web" en="Open Fabushi Web" />
              </a>
              <a className="secondary-action" href={siteHref("/download")}>
                <LocalizedText zh="下载 App" en="Download App" />
              </a>
            </div>
          </section>

          <section className="hero-visual" aria-label="Fabushi product overview">
            <div className="feature-grid">
              {PRODUCT_AREAS.map((item) => (
                <article className="feature-card" key={item.titleEn}>
                  <p className="eyebrow">{item.titleEn}</p>
                  <h2>
                    <LocalizedText zh={item.titleZh} en={item.titleEn} />
                  </h2>
                  <p>
                    <LocalizedText zh={item.bodyZh} en={item.bodyEn} />
                  </p>
                </article>
              ))}
            </div>
          </section>
        </div>
      </header>

      <section className="band alt" id="platforms">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="产品入口" en="Product entry points" />
          </p>
          <h2>
            <LocalizedText
              zh="像 Telegram 一样，把官网和 Web 应用明确分开。"
              en="Like Telegram, keep the informational website and the Web application clearly separated."
            />
          </h2>
          <p>
            <LocalizedText
              zh="ombhrum.com 是产品信息与公开入口；web.ombhrum.com 是登录后直接使用的完整 Fabushi Web。"
              en="ombhrum.com is the public product website; web.ombhrum.com is the full signed-in Fabushi Web experience."
            />
          </p>
        </div>
        <div className="feature-grid">
          {PLATFORM_LINKS.map((item) => (
            <a
              className="feature-card"
              key={item.en}
              href={item.external ? item.href : siteHref(item.href)}
            >
              <p className="eyebrow">{item.external ? "WEB APP" : "FABUSHI"}</p>
              <h3>
                <LocalizedText zh={item.zh} en={item.en} />
              </h3>
              <p>→</p>
            </a>
          ))}
        </div>
      </section>

      <section className="band" id="about">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="一套产品，多端一致" en="One product, consistent everywhere" />
          </p>
          <h2>
            <LocalizedText
              zh="Web、桌面和移动端共享同一账号、会话与能力模型。"
              en="Web, desktop, and mobile share the same account, conversations, and capability model."
            />
          </h2>
          <p>
            <LocalizedText
              zh="你可以先从 Web 开始，也可以下载 macOS、Windows、Linux、iOS 或 Android。官网只负责介绍和分发，不再把完整聊天应用塞进主域名首页。"
              en="Start on the Web or install macOS, Windows, Linux, iOS, or Android. The official site stays focused on information and distribution instead of embedding the complete messenger at the root domain."
            />
          </p>
          <div className="inline-cta">
            <a className="primary-action" href={WEB_APP_URL}>
              <LocalizedText zh="立即使用 Web" en="Use Web now" />
            </a>
            <a className="secondary-action" href={siteHref("/apps")}>
              <LocalizedText zh="浏览应用" en="Browse apps" />
            </a>
          </div>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
