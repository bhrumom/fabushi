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
import {
  getUserFacingDescription,
  getUserFacingNote,
  getUserFacingStatus,
  getUserFacingSummary,
} from "../../lib/channel-display";
import { siteHref, siteUrl } from "../../lib/site-url";

const downloadUrl = siteUrl("/download");
const downloadTitle = `法布施大乘 App 下载 | Android、iOS、版本与安装说明 | ${brand.name}`;
const downloadDescription =
  "法布施大乘 App 下载页，集中提供 Android、iOS 下载入口、版本说明、安装步骤、镜像与常见下载问题。";

const downloadFaqs = [
  {
    questionZh: "我应该下载测试版还是正式版？",
    questionEn: "Should I choose beta or stable first?",
    answerZh: "想尽快体验新版本或新功能，可以先看测试版；更在意稳定性，或准备长期使用，就优先看正式版。下载前先确认版本号和发布时间，会更稳。",
    answerEn: "Choose beta if you want the newest build or features first. Choose stable if you care more about installation stability and long-term use. Checking the version number and publish date first is the steadier path.",
  },
  {
    questionZh: "Android 下载慢或安装失败怎么办？",
    questionEn: "What should I do if Android download is slow or installation fails?",
    answerZh: "先尝试当前卡片里的镜像链接，再确认自己下载的是对应平台和版本；如果仍然失败，把设备型号、系统版本和错误截图发到支持邮箱。",
    answerEn: "Try the mirror links on the current card first, then confirm that you downloaded the matching platform and version. If it still fails, send the device model, OS version, and an error screenshot to support.",
  },
  {
    questionZh: "iOS 为什么会打开 TestFlight？",
    questionEn: "Why does iOS open TestFlight?",
    answerZh: "iOS 测试版通过 Apple TestFlight 分发。入口开放后，下载按钮会直接跳转到对应测试页，这是正常流程。",
    answerEn: "iOS beta is distributed through Apple TestFlight. Once access is open, the download button will jump there directly, which is the expected flow.",
  },
] as const;

const installSteps = [
  {
    titleZh: "先确认你的设备平台和版本偏好",
    titleEn: "Confirm your device and version preference first",
    descriptionZh: "Android 与 iOS 入口分开显示；想先体验新功能可以看测试版，更想稳一点就先看正式版。",
    descriptionEn: "Android and iOS paths are listed separately. Choose beta for newer features first, or stable for a calmer install path.",
  },
  {
    titleZh: "进入对应下载入口并完成安装",
    titleEn: "Open the matching download path and install",
    descriptionZh: "Android 可以优先使用主下载入口，较慢时再切到镜像；iOS 测试版会通过 TestFlight 打开。",
    descriptionEn: "Use the main Android link first and switch to a mirror only if needed. iOS beta opens through TestFlight.",
  },
  {
    titleZh: "安装失败时先看 FAQ，再联系支持",
    titleEn: "Check the FAQ first, then contact support if installation fails",
    descriptionZh: "下载或安装异常时，先排查常见问题；仍然无法解决，再把设备信息和错误截图发给支持邮箱。",
    descriptionEn: "If download or installation behaves unexpectedly, check the common questions first. If the issue remains, send device details and screenshots to support.",
  },
] as const;

const DOWNLOAD_NOTES = [
  {
    zh: "下载前先确认平台、版本号和发布时间，避免下错包。",
    en: "Check the platform, version, and publish date before downloading so you get the right build.",
  },
  {
    zh: "Android 下载较慢时，可以优先尝试镜像入口。",
    en: "If Android downloads are slow, try the mirror links first.",
  },
  {
    zh: "iOS 测试版通过 TestFlight 分发，入口开放后会直接跳转。",
    en: "iOS beta is distributed through TestFlight, and the button will jump there once access opens.",
  },
] as const;

export const metadata: Metadata = {
  title: downloadTitle,
  description: downloadDescription,
  keywords: [
    "法布施大乘 App 下载",
    "Fabushi 下载",
    "Android 下载",
    "iOS 下载",
    "TestFlight",
    "安装说明",
    "版本说明",
    "佛教 app",
  ],
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
  const summary = getUserFacingSummary(channel);
  const actionCopy = getChannelActionCopy(channel);
  const statusCopy = getUserFacingStatus(channel);
  const descriptionCopy = getUserFacingDescription(channel);
  const noteCopy = getUserFacingNote(channel);

  return (
    <article className="release-card">
      <div className="release-card-header">
        <div>
          <p className="eyebrow">
            <LocalizedText
              zh={channel.audience === "beta" ? "测试版" : "正式版"}
              en={channel.audience === "beta" ? "Beta" : "Stable"}
            />
          </p>
          <h2>{channel.title}</h2>
        </div>
        <span className="download-status">
          <LocalizedText zh={statusCopy.zh} en={statusCopy.en} />
        </span>
      </div>
      <p>
        <LocalizedText zh={descriptionCopy.zh} en={descriptionCopy.en} />
      </p>
      {(channel.version || publishedAt) && (
        <div className="release-card-meta">
          {channel.version ? (
            <span>
              <LocalizedText zh="版本" en="Version" /> v{channel.version}
            </span>
          ) : null}
          {publishedAt ? (
            <span>
              <LocalizedText zh="发布时间" en="Published" /> {publishedAt}
            </span>
          ) : null}
        </div>
      )}
      {summary.length > 0 ? (
        <ul className="release-summary-list">
          {summary.map((item) => (
            <li key={item.en}>
              <LocalizedText zh={item.zh} en={item.en} />
            </li>
          ))}
        </ul>
      ) : null}
      <div className="release-card-actions">
        <DownloadLink className="primary-action" channel={channel}>
          <LocalizedText zh={actionCopy.zh} en={actionCopy.en} />
        </DownloadLink>
        {channel.releasePageHref ? (
          <a className="secondary-action" href={siteHref("/download#release-changelog")}>
            <LocalizedText zh="查看下载内容说明" en="View download notes" />
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
      {noteCopy ? (
        <p className="release-note">
          <LocalizedText zh={noteCopy.zh} en={noteCopy.en} />
        </p>
      ) : null}
    </article>
  );
}

export default async function DownloadPage() {
  const releaseCollection = await getOfficialSiteReleaseCollection();
  const betaChannels = releaseCollection.betaChannels;
  const stableChannels = releaseCollection.stableChannels;
  const allChannels = [...betaChannels, ...stableChannels];
  const supportEmail =
    contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@ombhrum.com";

  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "CollectionPage",
        name: "法布施大乘 App 下载",
        url: downloadUrl,
        description: downloadDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: ["App 下载", "Android 下载", "iOS 下载", "安装说明", "版本说明"],
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
            name: "下载 App",
            item: downloadUrl,
          },
        ],
      },
      {
        "@type": "SoftwareApplication",
        name: `${brand.name} Fabushi`,
        applicationCategory: "LifestyleApplication",
        operatingSystem: "Android, iOS",
        url: downloadUrl,
        downloadUrl,
        description: downloadDescription,
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
        "@type": "HowTo",
        name: "法布施大乘 App 下载与安装步骤",
        description: "先确认平台与版本，再选择下载入口，安装失败时先查 FAQ，再联系支持。",
        step: installSteps.map((item, index) => ({
          "@type": "HowToStep",
          position: index + 1,
          name: item.titleZh,
          text: item.descriptionZh,
          url: `${downloadUrl}#install-steps`,
        })),
      },
      {
        "@type": "FAQPage",
        mainEntity: downloadFaqs.map((item) => ({
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

      <section className="inner-hero download-hero">
        <SiteHeader />
        <ZenOrbit />
        <div className="inner-copy">
          <p className="eyebrow">
            <LocalizedText zh="下载" en="Download" />
          </p>
          <h1>
            <LocalizedText
              zh="选对平台入口，再下载对应版本。"
              en="Choose the right platform path before downloading the matching version."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="这一页集中放置 Android、iOS、版本说明、镜像和安装步骤，让下载路径更短。"
              en="This page keeps Android, iOS, release notes, mirrors, and install steps in one place so the download path stays short."
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
                    <LocalizedText zh="测试资格整理中" en="Beta access is being prepared" />
                  </h2>
                </div>
                <span className="download-status">
                  <LocalizedText zh="暂未开放" en="Not open yet" />
                </span>
              </div>
              <p>
                <LocalizedText
                  zh="当前还没有公开可点的测试入口。可以先提交测试申请。"
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

      <section className="band" id="install-steps">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="安装步骤" en="Install Steps" />
          </p>
          <h2>
            <LocalizedText zh="按这三步走，下载与安装会更稳。" en="Follow these three steps for a steadier download and install flow." />
          </h2>
        </div>
        <div className="editorial-list">
          {installSteps.map((item, index) => (
            <article key={item.titleEn} className="editorial-row">
              <span>
                <LocalizedText zh={`步骤 ${index + 1}`} en={`Step ${index + 1}`} />
              </span>
              <div>
                <strong>
                  <LocalizedText zh={item.titleZh} en={item.titleEn} />
                </strong>
                <p>
                  <LocalizedText zh={item.descriptionZh} en={item.descriptionEn} />
                </p>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="说明" en="Notes" />
          </p>
          <h2>
            <LocalizedText zh="下载前只看这几条。" en="A few things worth checking before you download." />
          </h2>
        </div>
        <div className="note-grid">
          {DOWNLOAD_NOTES.map((item) => (
            <p key={item.en}>
              <LocalizedText zh={item.zh} en={item.en} />
            </p>
          ))}
          <p>
            <LocalizedText
              zh={`遇到下载或安装问题，发邮件到 ${supportEmail}。`}
              en={`If download or install fails, email ${supportEmail}.`}
            />
          </p>
        </div>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/faq")}>
            <LocalizedText zh="查看常见问题" en="View FAQ" />
          </a>
          <a className="secondary-action" href={`mailto:${supportEmail}`}>
            <LocalizedText zh="联系支持" en="Contact support" />
          </a>
        </div>
      </section>

      <section className="band">
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
        <section className="band alt" id="release-changelog">
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
                  <h3>{entry.title}</h3>
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
              </article>
            ))}
          </div>
        </section>
      )}

      <SiteFooter />
    </main>
  );
}
