import type { Metadata } from "next";
import { brand, contactChannels } from "@fabushi/shared";
import { DownloadClient } from "../../components/download-client";
import type { DownloadChannel } from "../../components/download-client";
import { DownloadLink } from "../../components/download-link";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { ZenOrbit } from "../../components/zen-orbit";
import {
  getOfficialSiteReleaseCollection,
  type OfficialSiteChannel,
} from "../../lib/official-site-releases";
import { siteHref, siteUrl } from "../../lib/site-url";

const downloadUrl = siteUrl("/download");
const downloadTitle = `Download | ${brand.name}`;
const downloadDescription = "Choose Android beta, iOS TestFlight, or stable download paths for Fabushi.";

const downloadFaqs = [
  {
    questionZh: "我应该先点哪个入口？",
    questionEn: "Which button should I open first?",
    answerZh: "想尽快体验新版本，先看测试版；更想要稳定，就等正式版。",
    answerEn: "Pick beta for the newest release quickly. Wait for stable if you want the calmer path.",
  },
  {
    questionZh: "Android 下载慢怎么办？",
    questionEn: "What if Android downloads are slow?",
    answerZh: "优先尝试卡片里的镜像链接；如果仍不可用，把平台和错误截图发到支持邮箱。",
    answerEn: "Try the mirror links on the card first. If that still fails, send the platform and screenshot to support.",
  },
  {
    questionZh: "iOS 为什么会跳到 TestFlight？",
    questionEn: "Why does iOS open TestFlight?",
    answerZh: "iOS 内测通过 Apple TestFlight 分发。公开加入链接开放后，下载页会直接显示。",
    answerEn: "iOS beta is distributed through Apple TestFlight. Once public access is ready, the page links there directly.",
  },
] as const;

export const metadata: Metadata = {
  title: downloadTitle,
  description: downloadDescription,
  keywords: ["Fabushi download", "Android Beta", "iOS TestFlight", "release notes"],
  alternates: {
    canonical: downloadUrl,
  },
  openGraph: {
    title: downloadTitle,
    description: downloadDescription,
    url: downloadUrl,
    siteName: "Fabushi",
    locale: "en_US",
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

  return date.toISOString().slice(0, 10);
}

function getChannelActionCopy(channel: OfficialSiteChannel) {
  if (channel.audience === "stable" && channel.primaryHref.startsWith("/contact")) {
    return {
      zh: "查看状态",
      en: "View status",
    };
  }

  if (channel.platform === "iOS") {
    return {
      zh: channel.audience === "beta" ? "下载 iOS 测试版" : "下载 iOS 正式版",
      en: channel.audience === "beta" ? "Download iOS Beta" : "Download iOS Stable",
    };
  }

  return {
    zh: channel.audience === "beta" ? "下载 Android 测试版" : "下载 Android 正式版",
    en: channel.audience === "beta" ? "Download Android Beta" : "Download Android Stable",
  };
}

function ReleaseChannelCard({ channel }: { channel: OfficialSiteChannel }) {
  const publishedAt = formatPublishedAt(channel.publishedAt);
  const summary = channel.updateSummary.slice(0, 3);
  const actionCopy = getChannelActionCopy(channel);

  return (
    <article className="release-card">
      <div className="release-card-header">
        <div>
          <p className="eyebrow">
            <LocalizedText zh={channel.audience === "beta" ? "测试版" : "正式版"} en={channel.audience === "beta" ? "Beta" : "Stable"} />
          </p>
          <h2>{channel.title}</h2>
        </div>
        <span className="download-status">{channel.status}</span>
      </div>
      <p>{channel.description}</p>
      {(channel.version || publishedAt) && (
        <div className="release-card-meta">
          {channel.version ? <span><LocalizedText zh="版本" en="Version" /> v{channel.version}</span> : null}
          {publishedAt ? <span><LocalizedText zh="发布时间" en="Published" /> {publishedAt}</span> : null}
        </div>
      )}
      {summary.length > 0 ? (
        <ul className="release-summary-list">
          {summary.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
      ) : null}
      <div className="release-card-actions">
        <DownloadLink className="primary-action" channel={channel}>
          <LocalizedText zh={actionCopy.zh} en={actionCopy.en} />
        </DownloadLink>
        {channel.releasePageHref ? (
          <a className="secondary-action" href={siteHref(channel.releasePageHref)}>
            <LocalizedText zh="查看 Release" en="View release" />
          </a>
        ) : null}
      </div>
      {channel.mirrorLinks.length > 0 && (
        <div className="mirror-links" aria-label={`${channel.title} mirror links`}>
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
        name: `${brand.name} Download`,
        url: downloadUrl,
        description: downloadDescription,
        inLanguage: "en",
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
          name: item.questionEn,
          acceptedAnswer: {
            "@type": "Answer",
            text: item.answerEn,
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
          <p className="eyebrow">
            <LocalizedText zh="下载" en="Download" />
          </p>
          <h1>
            <LocalizedText zh="选一个入口，知道自己下的是哪个版本。" en="Pick a download path and know exactly which version you are getting." />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="Android Beta、iOS TestFlight、发布时间和更新摘要会在这里一起同步。"
              en="Android beta, iOS TestFlight, publish time, and update summaries are synced here together."
            />
          </p>
        </div>
      </section>

      <section className="band compact-band" id="beta-channels">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="下载" en="Download" />
          </p>
          <h2>
            <LocalizedText zh="先从最合适的平台入口开始。" en="Start with the path that matches your device." />
          </h2>
        </div>
        {betaChannels.length > 0 ? (
          <DownloadClient channels={betaChannels as DownloadChannel[]} />
        ) : (
          <div className="download-grid">
            <article className="release-card">
              <div className="release-card-header">
                <div>
                  <p className="eyebrow">
                    <LocalizedText zh="测试版" en="Beta" />
                  </p>
                  <h2>
                    <LocalizedText zh="Beta 同步中" en="Beta is syncing" />
                  </h2>
                </div>
                <span className="download-status">
                  <LocalizedText zh="暂未开放" en="Not open yet" />
                </span>
              </div>
              <p>
                <LocalizedText
                  zh="当前还没有可公开点击的 Beta 入口。可以先提交测试申请。"
                  en="There is no public beta button yet. You can still apply for access first."
                />
              </p>
              <div className="release-card-actions">
                <a className="primary-action" href={siteHref("/apply")}>
                  <LocalizedText zh="申请测试" en="Apply" />
                </a>
              </div>
            </article>
          </div>
        )}
      </section>

      <section className="band alt" id="stable-channels">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="正式版" en="Stable" />
          </p>
          <h2>
            <LocalizedText zh="适合想要更稳安装的人。" en="For people who would rather wait for a steadier install path." />
          </h2>
        </div>
        <div className="download-grid">
          {stableChannels.map((channel) => (
            <ReleaseChannelCard key={`${channel.audience}-${channel.platform}`} channel={channel} />
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="说明" en="Notes" />
          </p>
          <h2>
            <LocalizedText zh="下载前只看这三条。" en="Three things worth checking before you download." />
          </h2>
        </div>
        <div className="note-grid">
          {notes.map((item) => (
            <p key={item}>{item}</p>
          ))}
          <p>
            <LocalizedText zh={`遇到下载或安装问题，发邮件到 ${supportEmail}。`} en={`If download or install fails, email ${supportEmail}.`} />
          </p>
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading tight">
          <p>FAQ</p>
          <h2>
            <LocalizedText zh="少一点犹豫。" en="Remove the last bit of hesitation." />
          </h2>
        </div>
        <div className="faq-list full">
          {downloadFaqs.map((item) => (
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
      </section>

      {releaseCollection.releases.length > 0 && (
        <section className="band" id="release-changelog">
          <div className="section-heading tight">
            <p>
              <LocalizedText zh="更新日志" en="Release log" />
            </p>
            <h2>
              <LocalizedText zh="最近更新了什么。" en="What changed recently." />
            </h2>
          </div>
          <div className="changelog-timeline">
            {releaseCollection.releases.map((entry) => (
              <article key={entry.tag} className="changelog-entry">
                <div className="changelog-meta">
                  <h3>
                    <a href={entry.htmlUrl} target="_blank" rel="noopener noreferrer">
                      {entry.title}
                    </a>
                  </h3>
                  <time dateTime={entry.publishedAt}>{formatPublishedAt(entry.publishedAt)}</time>
                </div>
                <div className="release-card-meta compact">
                  <span>
                    <LocalizedText zh="版本" en="Version" /> {entry.tag}
                  </span>
                </div>
                {entry.summary.length > 0 && (
                  <ul className="release-summary-list compact">
                    {entry.summary.map((line, i) => (
                      <li key={`${entry.tag}-${i}`}>{line}</li>
                    ))}
                  </ul>
                )}
                <a
                  className="secondary-action"
                  href={entry.htmlUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <LocalizedText zh="查看完整发布说明" en="View full release notes" />
                </a>
              </article>
            ))}
          </div>
        </section>
      )}

      <SiteFooter />
    </main>
  );
}
