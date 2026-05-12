import type { Metadata } from "next";
import { brand, contactChannels } from "@fabushi/shared";
import { DownloadClient } from "../../components/download-client";
import type { DownloadChannel } from "../../components/download-client";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { ZenOrbit } from "../../components/zen-orbit";
import {
  getOfficialSiteReleaseCollection,
  type OfficialSiteChannel,
} from "../../lib/official-site-releases";
import { siteHref, siteUrl } from "../../lib/site-url";

const downloadUrl = siteUrl("/download");
const downloadTitle = `下载 | ${brand.name}`;
const downloadDescription = "选择 Fabushi Android Beta、iOS TestFlight 或正式版入口。";

const downloadFaqs = [
  {
    question: "我应该先点哪个入口？",
    answer: "想尽快体验新版本，先看 Beta；想要更稳，等正式版；不确定时先申请测试。",
  },
  {
    question: "Android 下载慢怎么办？",
    answer: "优先尝试卡片里的镜像链接；如果仍不可用，把平台和错误截图发到支持邮箱。",
  },
  {
    question: "iOS 为什么可能跳到 TestFlight？",
    answer: "iOS 内测通过 Apple TestFlight 分发。公开加入链接开放后，下载页会直接显示。",
  },
] as const;

export const metadata: Metadata = {
  title: downloadTitle,
  description: downloadDescription,
  keywords: ["Fabushi 下载", "法布施下载", "Android Beta", "iOS TestFlight"],
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
  if (!value) return null;

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;

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
          {publishedAt ? <span>{publishedAt}</span> : null}
        </div>
      )}
      <div className="release-card-actions">
        <a className="primary-action" href={siteHref(channel.primaryHref)}>
          {channel.primaryLabel}
        </a>
        {channel.releasePageHref ? (
          <a className="secondary-action" href={siteHref(channel.releasePageHref)}>
            Release
          </a>
        ) : null}
      </div>
      {channel.mirrorLinks.length > 0 && (
        <div className="mirror-links" aria-label={`${channel.title} 镜像下载`}>
          {channel.mirrorLinks.map((item) => (
            <a key={item.href} href={siteHref(item.href)}>
              {item.label}
            </a>
          ))}
        </div>
      )}
      {channel.note ? <p className="release-note">{channel.note}</p> : null}
    </article>
  );
}

export default async function DownloadPage() {
  const releaseCollection = await getOfficialSiteReleaseCollection();
  const betaChannels = releaseCollection.betaChannels;
  const stableChannels = releaseCollection.stableChannels;
  const allChannels = [...betaChannels, ...stableChannels];
  const supportEmail = contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@ombhrum.com";
  const notes = releaseCollection.notes.slice(0, 3);

  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "CollectionPage",
        name: `${brand.name} 下载`,
        url: downloadUrl,
        description: downloadDescription,
        inLanguage: "zh-CN",
      },
      {
        "@type": "ItemList",
        itemListElement: allChannels.map((channel, index) => ({
          "@type": "ListItem",
          position: index + 1,
          item: {
            "@type": "SoftwareApplication",
            name: channel.title,
            operatingSystem: channel.platform,
            downloadUrl: siteHref(channel.primaryHref),
            description: channel.description,
          },
        })),
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

      <section className="inner-hero download-hero">
        <SiteHeader />
        <ZenOrbit />
        <div className="inner-copy">
          <p className="eyebrow">下载</p>
          <h1>选择你的入口。</h1>
          <p className="lede">Android Beta、iOS TestFlight 和正式版状态会在这里同步。</p>
        </div>
      </section>

      <section className="band compact-band" id="beta-channels">
        <div className="section-heading tight">
          <p>下载</p>
          <h2>选择适合你的入口。</h2>
        </div>
        {betaChannels.length > 0 ? (
          <DownloadClient channels={betaChannels as DownloadChannel[]} />
        ) : (
          <div className="download-grid">
            <article className="release-card">
              <div className="release-card-header">
                <div>
                  <p className="eyebrow">测试版</p>
                  <h2>Beta 同步中</h2>
                </div>
                <span className="download-status">暂未开放</span>
              </div>
              <p>当前还没有可公开点击的 Beta 入口。可以先提交测试申请。</p>
              <div className="release-card-actions">
                <a className="primary-action" href={siteHref("/apply")}>
                  申请测试
                </a>
              </div>
            </article>
          </div>
        )}
      </section>

      <section className="band alt" id="stable-channels">
        <div className="section-heading tight">
          <p>正式版</p>
          <h2>适合想要更稳安装的人。</h2>
        </div>
        <div className="download-grid">
          {stableChannels.map((channel) => (
            <ReleaseChannelCard key={`${channel.audience}-${channel.platform}`} channel={channel} />
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading tight">
          <p>说明</p>
          <h2>下载前只看这三条。</h2>
        </div>
        <div className="note-grid">
          {notes.map((item) => (
            <p key={item}>{item}</p>
          ))}
          <p>遇到下载或安装问题，发邮件到 {supportEmail}。</p>
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading tight">
          <p>FAQ</p>
          <h2>少一点犹豫。</h2>
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
