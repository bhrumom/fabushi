import type { CSSProperties } from "react";
import { brand, contactChannels, faqItems, homeHighlights } from "@fabushi/shared";
import { DownloadLink } from "../components/download-link";
import { SiteFooter } from "../components/site-footer";
import { SiteHeader } from "../components/site-header";
import { ZenOrbit } from "../components/zen-orbit";
import { getOfficialSiteReleaseCollection } from "../lib/official-site-releases";
import { siteHref, siteUrl } from "../lib/site-url";

type PreviewTone = "gold" | "cyan" | "green";

interface ProductMoment {
  title: string;
  description: string;
  eyebrow: string;
  note: string;
  tone: PreviewTone;
}

const previewToneStyles: Record<PreviewTone, CSSProperties> = {
  gold: {
    background:
      "radial-gradient(circle at top, rgba(232, 189, 107, 0.18), transparent 46%), linear-gradient(180deg, rgba(24, 19, 10, 0.96), rgba(10, 12, 18, 0.98))",
  },
  cyan: {
    background:
      "radial-gradient(circle at top, rgba(120, 214, 232, 0.18), transparent 46%), linear-gradient(180deg, rgba(10, 20, 25, 0.96), rgba(10, 12, 18, 0.98))",
  },
  green: {
    background:
      "radial-gradient(circle at top, rgba(158, 215, 191, 0.18), transparent 46%), linear-gradient(180deg, rgba(13, 23, 20, 0.96), rgba(10, 12, 18, 0.98))",
  },
};

const previewCardStyle: CSSProperties = {
  width: "100%",
  height: "100%",
  borderRadius: "18px",
  border: "1px solid rgba(255, 249, 235, 0.14)",
  padding: "20px",
  display: "grid",
  alignContent: "space-between",
  gap: "16px",
  boxShadow: "inset 0 1px 0 rgba(255, 249, 235, 0.04)",
};

const compactPreviewCardStyle: CSSProperties = {
  ...previewCardStyle,
  padding: "16px",
  gap: "12px",
};

const previewEyebrowStyle: CSSProperties = {
  display: "inline-flex",
  width: "max-content",
  maxWidth: "100%",
  padding: "6px 10px",
  borderRadius: "999px",
  border: "1px solid rgba(255, 249, 235, 0.12)",
  background: "rgba(255, 249, 235, 0.06)",
  color: "#ffe3a3",
  fontSize: "0.76rem",
  fontWeight: 800,
  letterSpacing: "0.04em",
};

const previewTitleStyle: CSSProperties = {
  color: "#fff9eb",
  fontSize: "clamp(1.2rem, 2vw, 1.8rem)",
  lineHeight: 1.2,
  fontWeight: 850,
};

const compactPreviewTitleStyle: CSSProperties = {
  ...previewTitleStyle,
  fontSize: "clamp(1rem, 1.6vw, 1.28rem)",
};

const previewTextStyle: CSSProperties = {
  margin: 0,
  color: "#dbe7e0",
  lineHeight: 1.6,
  fontSize: "0.95rem",
};

const previewListStyle: CSSProperties = {
  margin: 0,
  padding: 0,
  listStyle: "none",
  display: "grid",
  gap: "10px",
};

const previewListItemStyle: CSSProperties = {
  padding: "10px 12px",
  borderRadius: "12px",
  border: "1px solid rgba(255, 249, 235, 0.1)",
  background: "rgba(255, 249, 235, 0.05)",
  color: "#fff9eb",
  fontSize: "0.88rem",
  lineHeight: 1.45,
};

const previewPillRowStyle: CSSProperties = {
  display: "flex",
  flexWrap: "wrap",
  gap: "8px",
};

const previewPillStyle: CSSProperties = {
  padding: "7px 10px",
  borderRadius: "999px",
  border: "1px solid rgba(255, 249, 235, 0.1)",
  background: "rgba(255, 249, 235, 0.05)",
  color: "#dbe7e0",
  fontSize: "0.78rem",
  fontWeight: 700,
};

const PRODUCT_MOMENTS: ProductMoment[] = [
  {
    title: "全球法布施",
    description: "看见善意如何跨越地域，直接抵达世界各地。",
    eyebrow: "法布施",
    note: "展示全球布施流向、动态反馈和传播节奏。",
    tone: "gold",
  },
  {
    title: "随时随地开始修行",
    description: "打开就能进入禅修状态，把修行节奏留在日常里。",
    eyebrow: "修行入口",
    note: "把开始、继续和记录路径放在同一屏内。",
    tone: "green",
  },
  {
    title: "沉浸式禅修体验",
    description: "用更安静、更专注的界面承接每一次练习。",
    eyebrow: "沉浸体验",
    note: "弱化干扰元素，保留最核心的专注信息。",
    tone: "cyan",
  },
  {
    title: "锁定主修功课",
    description: "先确定主线，再围绕自己的路径稳定推进。",
    eyebrow: "主修管理",
    note: "明确主线课程，减少切换带来的打断感。",
    tone: "gold",
  },
  {
    title: "轻松加入共修小组",
    description: "搜索、申请、加入和管理共修关系都放在同一条路径里。",
    eyebrow: "共修协作",
    note: "把查找、加入和跟进整合成连续动作。",
    tone: "green",
  },
  {
    title: "全球修行排行",
    description: "修行进度和榜单变化一眼可见，方便持续跟进。",
    eyebrow: "修行排行",
    note: "强调进度变化、排名趋势和持续反馈。",
    tone: "cyan",
  },
  {
    title: "全球布施排行",
    description: "实时查看全球布施动态，感受功德流动。",
    eyebrow: "布施动态",
    note: "用实时信息呈现全球范围内的善行流动。",
    tone: "gold",
  },
  {
    title: "全球布施排行榜",
    description: "用更直观的排行榜界面看见用户与善行的连接。",
    eyebrow: "排行榜",
    note: "用更直接的榜单视角突出人与善行的关联。",
    tone: "cyan",
  },
];

export default async function HomePage() {
  const releaseCollection = await getOfficialSiteReleaseCollection();
  const channels = [...releaseCollection.betaChannels, ...releaseCollection.stableChannels].slice(0, 3);
  const supportEmail = contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@ombhrum.com";
  const directChannel = releaseCollection.betaChannels.find((item) => !item.primaryHref.startsWith("/contact"));
  const primaryLabel = directChannel?.primaryLabel ?? "查看下载入口";
  const faqPreview = faqItems.slice(0, 4);

  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        name: `${brand.name} 大乘`,
        url: siteUrl("/"),
        email: supportEmail,
        description: brand.mission,
      },
      {
        "@type": "SoftwareApplication",
        name: `${brand.name} 大乘`,
        applicationCategory: "LifestyleApplication",
        operatingSystem: "iOS, Android, Web",
        url: siteUrl("/download"),
        description: brand.tagline,
      },
      {
        "@type": "FAQPage",
        mainEntity: faqPreview.map((item) => ({
          "@type": "Question",
          name: item.question,
          acceptedAnswer: {
            "@type": "Answer",
            text: item.answer,
          },
        })),
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
              <span>大乘</span>
            </div>
            <h1 id="home-title">法布施</h1>
            <p className="hero-subtitle">{brand.tagline}</p>
            <div className="hero-actions">
              {directChannel ? (
                <DownloadLink className="primary-action" channel={directChannel}>
                  {primaryLabel}
                </DownloadLink>
              ) : (
                <a className="primary-action" href={siteHref("/download")}>
                  {primaryLabel}
                </a>
              )}
              <a className="secondary-action" href={siteHref("/apply")}>
                申请测试
              </a>
            </div>

            <div className="release-pill-grid" aria-label="当前下载状态">
              {channels.length > 0 ? (
                channels.map((item) => (
                  <DownloadLink
                    key={`${item.audience}-${item.platform}`}
                    className="release-pill"
                    channel={item}
                  >
                    <span>{item.title}</span>
                    <strong>{item.status}</strong>
                  </DownloadLink>
                ))
              ) : (
                <a className="release-pill" href={siteHref("/download")}>
                  <span>下载入口</span>
                  <strong>同步中</strong>
                </a>
              )}
            </div>
          </section>

          <section className="hero-visual" aria-label="大乘 产品预览">
            <ZenOrbit />
            <div className="phone-stack">
              <div className="phone-frame main-phone poster-frame">
                <div style={{ ...previewCardStyle, ...previewToneStyles.gold }}>
                  <div style={{ display: "grid", gap: "12px" }}>
                    <span style={previewEyebrowStyle}>全球法布施</span>
                    <strong style={previewTitleStyle}>看见善意如何跨越地域</strong>
                    <p style={previewTextStyle}>用稳定的首页预览展示核心能力，不再依赖缺失截图文件。</p>
                  </div>
                  <ul style={previewListStyle}>
                    <li style={previewListItemStyle}>全球动态流向一眼可见</li>
                    <li style={previewListItemStyle}>布施反馈与节奏持续同步</li>
                    <li style={previewListItemStyle}>下载入口与产品信息直接连通</li>
                  </ul>
                </div>
              </div>
              <div className="phone-frame side-phone poster-frame">
                <div style={{ ...compactPreviewCardStyle, ...previewToneStyles.cyan }}>
                  <div style={{ display: "grid", gap: "10px" }}>
                    <span style={previewEyebrowStyle}>共修小组</span>
                    <strong style={compactPreviewTitleStyle}>加入与跟进放在同一路径</strong>
                  </div>
                  <div style={previewPillRowStyle}>
                    <span style={previewPillStyle}>搜索小组</span>
                    <span style={previewPillStyle}>提交申请</span>
                    <span style={previewPillStyle}>持续跟进</span>
                  </div>
                </div>
              </div>
            </div>
          </section>
        </div>
      </header>

      <section className="band compact-band" id="download">
        <div className="section-heading tight">
          <p>下载</p>
          <h2>按你的平台进入。</h2>
        </div>
        <div className="platform-strip">
          {channels.map((item) => (
            <DownloadLink
              key={`${item.audience}-${item.platform}`}
              className="platform-row"
              channel={item}
            >
              <div>
                <span className="platform-name">{item.title}</span>
                <p>{item.description}</p>
              </div>
              <div className="platform-meta">
                <strong>{item.status}</strong>
                <span>{item.primaryLabel}</span>
              </div>
            </DownloadLink>
          ))}
          <a className="platform-row accent-row" href={siteHref("/download")}>
            <div>
              <span className="platform-name">全部入口</span>
              <p>查看 Android、iOS、正式版和镜像说明。</p>
            </div>
            <div className="platform-meta">
              <strong>下载页</strong>
              <span>进入</span>
            </div>
          </a>
        </div>
      </section>

      <section className="band feature-band" id="features">
        <div className="section-heading tight">
          <p>体验</p>
          <h2>留下真正有用的信息。</h2>
        </div>
        <div className="feature-grid">
          {homeHighlights.map((item) => (
            <article key={item.title} className="feature-card">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band product-band">
        <div className="section-heading tight">
          <p>预览</p>
          <h2>手动精选功能预览。</h2>
        </div>
        <div className="moment-grid showcase-grid">
          {PRODUCT_MOMENTS.map((item) => (
            <article key={item.title} className="moment-card">
              <div className="moment-image">
                <div style={{ ...previewCardStyle, ...previewToneStyles[item.tone] }}>
                  <div style={{ display: "grid", gap: "12px" }}>
                    <span style={previewEyebrowStyle}>{item.eyebrow}</span>
                    <strong style={compactPreviewTitleStyle}>{item.title}</strong>
                  </div>
                  <p style={previewTextStyle}>{item.note}</p>
                </div>
              </div>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band faq-band" id="faq">
        <div className="section-heading tight">
          <p>FAQ</p>
          <h2>先回答最关键的。</h2>
        </div>
        <div className="faq-list">
          {faqPreview.map((item) => (
            <details key={item.question} className="faq-item">
              <summary>{item.question}</summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/faq")}>
            查看全部常见问题
          </a>
          <a className="secondary-action" href={`mailto:${supportEmail}`}>
            联系支持
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
