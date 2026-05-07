import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import {
  getOfficialSiteReleaseCollection,
  type OfficialSiteChannel,
} from "../../lib/official-site-releases";
import { siteHref, siteUrl } from "../../lib/site-url";

const downloadUrl = siteUrl("/download");
const downloadTitle = `下载入口 | ${brand.name}`;
const downloadDescription =
  "查看 Fabushi 官网上的 Android Beta、iOS TestFlight 与正式版发布状态，并根据你的场景选择合适入口。";

const decisionPaths = [
  {
    title: "想先体验最新进度",
    recommendation: "优先看 Beta 渠道",
    description: "适合愿意更早体验新版本、也能接受内测节奏和偶发问题的人。",
    checkpoints: ["Android Beta 会跟随最新 GitHub Release 自动同步", "iOS Beta 会在 TestFlight 上传成功后补到官网", "如果你准备反馈问题，这条路径最合适"],
  },
  {
    title: "想要更稳的安装体验",
    recommendation: "等待正式版入口",
    description: "适合第一次接触项目、暂时不想承担测试波动，或者准备推荐给更多人的用户。",
    checkpoints: ["正式版只在人工验收通过后才会上线", "官网不会提前挂出未经确认的正式安装包", "入口一旦公开，会直接替换为正式版下载路径"],
  },
  {
    title: "先判断自己该走哪条路",
    recommendation: "先看推荐路径和 FAQ",
    description: "适合还不确定自己是来下载、申请资格，还是先了解发布状态的人。",
    checkpoints: ["先分清 Beta 与正式版的职责差异", "下载慢时优先尝试镜像链接", "还没有公开入口时，直接去申请测试或联系支持"],
  },
] as const;

const releasePrinciples = [
  {
    title: "Beta 测试版",
    summary: "更快同步、更适合早期反馈，也更可能跟着交付节奏持续变化。",
    bullets: ["入口优先由自动同步链路更新", "适合主动体验新功能和报告问题的人", "下载说明会跟着 release 资产一起刷新"],
  },
  {
    title: "正式版",
    summary: "更强调稳定性和人工确认，不会因为有构建产物就立刻公开挂出。",
    bullets: ["必须经过人工验收后才会发布", "更适合第一次安装或对稳定性更敏感的人", "官网只展示已经确认可公开分发的入口"],
  },
] as const;

const downloadFaqs = [
  {
    question: "我应该优先下 Beta，还是等正式版？",
    answer:
      "如果你愿意更早体验最新进度，并能接受测试节奏，优先看 Beta。若你更在意稳定性、或者准备第一次接触项目，建议先等正式版入口。",
  },
  {
    question: "为什么官网不把所有构建产物都直接挂出来？",
    answer:
      "因为下载页的职责不是展示所有产物，而是只给用户当前真正适合点击的入口。正式版尤其需要经过人工验收，避免用户拿到还不适合公开分发的安装包。",
  },
  {
    question: "如果页面上还没有公开入口，我下一步该做什么？",
    answer:
      "先看当前 release 状态和推荐路径。如果是想参与体验，可以直接申请测试；如果是想确认发布时间或下载问题，优先联系支持邮箱。",
  },
] as const;

export const metadata: Metadata = {
  title: downloadTitle,
  description: downloadDescription,
  keywords: ["Fabushi 下载", "法布施下载", "Android Beta", "iOS TestFlight", "正式版发布"],
  alternates: {
    canonical: downloadUrl,
  },
  openGraph: {
    title: downloadTitle,
    description: downloadDescription,
    url: downloadUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: downloadTitle,
    description: downloadDescription,
  },
};

function formatPublishedAt(value?: string) {
  if (!value) {
    return null;
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "short",
    day: "numeric",
  }).format(date);
}

function ReleaseChannelCard({ channel }: { channel: OfficialSiteChannel }) {
  const publishedAt = formatPublishedAt(channel.publishedAt);

  return (
    <article className="release-card">
      <div className="release-card-header">
        <div>
          <p className="eyebrow">{channel.audience === "beta" ? "测试版" : "正式版"}</p>
          <h2>{channel.title}</h2>
        </div>
        <span className="download-status">{channel.status}</span>
      </div>
      <p>{channel.description}</p>
      {(channel.version || publishedAt) && (
        <div className="release-card-meta">
          {channel.version ? <span>版本 {channel.version}</span> : null}
          {publishedAt ? <span>更新于 {publishedAt}</span> : null}
        </div>
      )}
      {channel.updateSummary.length > 0 && (
        <ul className="release-update-list">
          {channel.updateSummary.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
      )}
      <div className="release-card-actions">
        <a className="primary-action" href={siteHref(channel.primaryHref)}>
          {channel.primaryLabel}
        </a>
        {channel.releasePageHref ? (
          <a className="secondary-action" href={siteHref(channel.releasePageHref)}>
            查看 Release
          </a>
        ) : null}
      </div>
      {channel.mirrorLinks.length > 0 && (
        <div className="release-mirror-block">
          <p>国内下载镜像</p>
          <div className="inline-cta">
            {channel.mirrorLinks.map((item) => (
              <a key={item.href} className="secondary-action" href={siteHref(item.href)}>
                {item.label}
              </a>
            ))}
          </div>
        </div>
      )}
      {channel.note ? <p className="release-note">{channel.note}</p> : null}
    </article>
  );
}

export default async function DownloadPage() {
  const releaseCollection = await getOfficialSiteReleaseCollection();

  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "首页", item: siteUrl("/") },
          { "@type": "ListItem", position: 2, name: "下载入口", item: downloadUrl },
        ],
      },
      {
        "@type": "CollectionPage",
        name: `${brand.name} 下载入口`,
        url: downloadUrl,
        description: downloadDescription,
        inLanguage: "zh-CN",
      },
      {
        "@type": "FAQPage",
        mainEntity: downloadFaqs.map((item) => ({
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
    <main className="inner-page">
      <script
        type="application/ld+json"
        suppressHydrationWarning
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />

      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">下载入口</p>
          <h1>把入口分清楚，比把所有包一股脑挂出来更重要。</h1>
          <p className="lede">
            这页的任务不是堆下载按钮，而是先帮你判断：现在该去 Beta、该等正式版，还是该先申请测试资格。
            Android Beta、iOS TestFlight 与正式版发布状态都会在这里持续同步。
          </p>
        </div>
      </section>

      <section className="band">
        <div className="section-heading">
          <p>先做判断</p>
          <h2>如果你只想知道下一步该点哪里，先按场景选路径，而不是先猜平台状态。</h2>
        </div>
        <div className="decision-grid">
          {decisionPaths.map((item) => (
            <article key={item.title} className="decision-card">
              <p className="eyebrow">{item.title}</p>
              <h3>{item.recommendation}</h3>
              <p>{item.description}</p>
              <ul className="decision-list">
                {item.checkpoints.map((entry) => (
                  <li key={entry}>{entry}</li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>版本差异</p>
          <h2>Beta 和正式版的区别，不只是“能不能下载”，而是入口更新方式和适合人群完全不同。</h2>
        </div>
        <div className="compare-grid">
          {releasePrinciples.map((item) => (
            <article key={item.title} className="compare-card">
              <h3>{item.title}</h3>
              <p>{item.summary}</p>
              <ul className="compare-list">
                {item.bullets.map((entry) => (
                  <li key={entry}>{entry}</li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading">
          <p>Beta 渠道</p>
          <h2>安装包发布完成后，这里的测试入口会自动跟上最新一轮交付结果。</h2>
        </div>
        <div className="release-section-stack">
          {releaseCollection.betaChannels.map((channel) => (
            <ReleaseChannelCard key={`${channel.audience}-${channel.platform}`} channel={channel} />
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>正式版</p>
          <h2>正式版入口只在人工验收通过后，由手动 GitHub Action 发布到官网。</h2>
        </div>
        <div className="release-section-stack">
          {releaseCollection.stableChannels.map((channel) => (
            <ReleaseChannelCard key={`${channel.audience}-${channel.platform}`} channel={channel} />
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading">
          <p>同步说明</p>
          <h2>官网上的下载说明现在会跟着发布资产一起更新，而不是靠手工改文案。</h2>
        </div>
        <div className="status-note-list">
          {releaseCollection.notes.map((item) => (
            <p key={item}>{item}</p>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>推荐路径</p>
          <h2>如果你现在只是第一次接触这个项目，建议先这样走。</h2>
        </div>
        <ol className="roadmap-list">
          <li>先看官网判断当前开放的是测试版，还是已经过人工验收的正式版。</li>
          <li>如果你愿意更早体验新版本，再进入 Beta；如果更在意稳定性，就等正式版入口。</li>
          <li>如果下载较慢，优先尝试页面里的镜像链接；如果还没有公开入口，直接申请测试或联系支持。</li>
        </ol>
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/apply")}>
            前往申请测试
          </a>
          <a className="secondary-action" href={siteHref("/contact")}>
            查看联系信息
          </a>
        </div>
      </section>

      <section className="band">
        <div className="section-heading">
          <p>常见问题</p>
          <h2>把下载前最容易犹豫的几个问题先回答出来，用户和搜索系统都更容易做出正确判断。</h2>
        </div>
        <div className="faq-list full">
          {downloadFaqs.map((item) => (
            <details key={item.question} className="faq-item">
              <summary>{item.question}</summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
