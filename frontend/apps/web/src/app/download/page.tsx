import type { Metadata } from "next";
import { brand, contactChannels } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import {
  getOfficialSiteReleaseCollection,
  type OfficialSiteChannel,
} from "../../lib/official-site-releases";
import { siteHref, siteUrl } from "../../lib/site-url";

export const metadata: Metadata = {
  title: `下载入口 | ${brand.name}`,
  description: "查看 Fabushi 官网上的 Android Beta、iOS TestFlight 与正式版发布状态。",
  alternates: {
    canonical: siteUrl("/download"),
  },
  keywords: [
    "法布施下载",
    "Fabushi 下载",
    "Android Beta",
    "iOS TestFlight",
    "法布施官网",
    "法布施正式版",
  ],
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
  const allChannels = [...releaseCollection.betaChannels, ...releaseCollection.stableChannels];
  const supportEmail = contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@fabushi.com";
  const recommendationPaths = [
    {
      label: "想最快看到最新改动",
      title: "优先看 Android beta 或 iOS TestFlight。",
      description: "这两条通道会最先承接最新一轮可公开测试的安装包和状态更新，适合愿意跟着版本节奏一起体验的人。",
    },
    {
      label: "想先判断自己适不适合加入测试",
      title: "先看版本说明、更新时间和适用提示，再决定要不要安装。",
      description: "下载页现在会把版本、发布时间、更新摘要和补充说明直接写在入口旁边，避免你先下载再回头找上下文。",
    },
    {
      label: "更看重稳定与人工验收",
      title: "优先等正式版入口，而不是直接进入 beta。",
      description: "正式版只在人工验收完成后才会上架到官网，更适合不希望承担测试波动、需要更稳妥安装入口的人。",
    },
  ] as const;
  const preInstallChecklist = [
    "你现在更想优先体验最新改动，还是更想降低安装后的波动与反复更新。",
    "你是否已经看过对应入口旁边的版本、更新时间和更新摘要，而不是只看按钮名称。",
    "如果你准备反馈问题或申请资格，是否已经知道该走下载、申请测试还是联系支持这三条不同路径。",
  ] as const;

  const downloadPageJsonLd = {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    name: `${brand.name} 下载入口`,
    url: siteUrl("/download"),
    inLanguage: "zh-CN",
    description: "查看 Fabushi Android beta、iOS TestFlight 与正式版的当前可见下载状态。",
    mainEntity: {
      "@type": "ItemList",
      itemListElement: allChannels.map((channel, index) => ({
        "@type": "ListItem",
        position: index + 1,
        item: {
          "@type": "SoftwareApplication",
          name: channel.title,
          operatingSystem: channel.platform,
          description: channel.description,
          url: siteUrl("/download"),
          downloadUrl: siteHref(channel.primaryHref),
          applicationCategory: channel.audience === "stable" ? "ProductivityApplication" : "BetaSoftwareApplication",
        },
      })),
    },
    provider: {
      "@type": "Organization",
      name: `${brand.name} Fabushi`,
      email: supportEmail,
      url: siteUrl("/"),
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
        name: "下载入口",
        item: siteUrl("/download"),
      },
    ],
  };

  return (
    <main className="inner-page">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(downloadPageJsonLd) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbJsonLd) }} />

      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">下载入口</p>
          <h1>官网现在直接承接测试版与正式版入口，不再只停留在等待名单。</h1>
          <p className="lede">
            Android beta 会跟着最新 GitHub Release 自动更新，iOS beta 会在 TestFlight 上传成功后同步到官网。
            正式版则通过人工验证后的手动发布动作上架，避免把未经确认的安装包直接挂出去。
          </p>
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
          <p>选择建议</p>
          <h2>如果你不确定现在该点哪一个入口，先按你的风险偏好和目的来选。</h2>
        </div>
        <div className="path-grid">
          {recommendationPaths.map((item) => (
            <article key={item.title} className="path-card">
              <span className="detail-label">{item.label}</span>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>安装前确认</p>
          <h2>真正点下载前，先确认这三件事，能少走很多回头路。</h2>
        </div>
        <ol className="roadmap-list">
          {preInstallChecklist.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ol>
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
          <li>先看官网，了解当前开放的是测试版还是已经过人工验收的正式版。</li>
          <li>如果你在国内网络环境下下载较慢，优先尝试页面里的 GitHub 镜像入口。</li>
          <li>如果 iOS TestFlight 还没有公开加入链接，先查看 release 状态或联系支持邮箱。</li>
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

      <SiteFooter />
    </main>
  );
}
