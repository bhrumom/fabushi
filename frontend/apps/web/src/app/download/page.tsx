import type { Metadata } from "next";
import { brand, contactChannels } from "@fabushi/shared";
import { DownloadClient } from "../../components/download-client";
import type { DownloadChannel } from "../../components/download-client";
import { DownloadLink } from "../../components/download-link";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { GlobalNetworkGlobe } from "../../components/global-network-globe";
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
const downloadTitle = `法布施大乘 App 下载 | iOS、Android、桌面版与安装说明 | ${brand.name}`;
const downloadDescription =
  "法布施大乘 App 下载页，集中提供 iOS、Android、macOS、Windows、Linux 下载入口、版本说明、安装步骤与常见下载问题。";

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
    answerZh: "先重新点击当前卡片里的主下载入口，并确认自己下载的是对应平台和版本；如果仍然失败，把设备型号、系统版本和错误截图发到支持邮箱。",
    answerEn: "Use the main download button on the current card again, then confirm that you downloaded the matching platform and version. If it still fails, send the device model, OS version, and an error screenshot to support.",
  },
  {
    questionZh: "桌面版从哪里下载？",
    questionEn: "Where can I download the desktop app?",
    answerZh: "桌面版按 macOS、Windows、Linux 分开显示，下载按钮会打开对应的 GitHub Release 安装包；同一卡片里也保留备用压缩包格式。",
    answerEn: "Desktop builds are listed separately for macOS, Windows, and Linux. Buttons open the matching GitHub Release installer, with alternate archive formats on the same card.",
  },
  {
    questionZh: "iOS 会打开 TestFlight 还是 App Store？",
    questionEn: "Will iOS open TestFlight or the App Store?",
    answerZh: "iOS 测试版通过 Apple TestFlight 分发；iOS 正式版通过 App Store 安装。下载页会把两个入口分开显示，按你想要的版本选择即可。",
    answerEn: "iOS beta builds are distributed through Apple TestFlight; the stable iOS release installs through the App Store. The download page separates both paths so you can choose the version you want.",
  },
] as const;

const installSteps = [
  {
    titleZh: "先确认你的设备平台和版本偏好",
    titleEn: "Confirm your device and version preference first",
    descriptionZh: "iOS、Android 和桌面端入口分开显示；普通用户优先选择正式版，需要提前体验再看测试版。",
    descriptionEn: "iOS, Android, and desktop paths are listed separately. Start with stable for ordinary use, or choose beta for early access.",
  },
  {
    titleZh: "进入对应下载入口并完成安装",
    titleEn: "Open the matching download path and install",
    descriptionZh: "iOS 正式版会打开 App Store；桌面版会打开 GitHub Release 安装包；Android 测试版继续使用主下载入口。",
    descriptionEn: "iOS stable opens the App Store. Desktop builds open GitHub Release installers, while Android beta keeps using the main download path.",
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
    zh: "iOS 正式版放在最前面，普通用户可直接进入 App Store。",
    en: "The iOS stable release is listed first and opens the App Store directly.",
  },
  {
    zh: "桌面版使用 GitHub Release 下载链接，按 macOS、Windows、Linux 分开显示。",
    en: "Desktop builds use GitHub Release links and are split by macOS, Windows, and Linux.",
  },
  {
    zh: "Android 测试版使用主下载入口，iOS 测试版通过 TestFlight 分发。",
    en: "Android beta uses the main download path, while iOS beta is distributed through TestFlight.",
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
    "macOS 下载",
    "Windows 下载",
    "Linux 下载",
    "桌面版下载",
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

  if (channel.platform === "macOS") {
    return {
      zh: "下载 macOS 桌面版",
      en: "Download macOS Desktop",
    };
  }

  if (channel.platform === "Windows") {
    return {
      zh: "下载 Windows 桌面版",
      en: "Download Windows Desktop",
    };
  }

  if (channel.platform === "Linux") {
    return {
      zh: "下载 Linux 桌面版",
      en: "Download Linux Desktop",
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
        {channel.mirrorLinks.map((link) => (
          <a key={link.href} className="secondary-action compact-action" href={siteHref(link.href)}>
            {link.label}
          </a>
        ))}
        {channel.releasePageHref ? (
          <a className="secondary-action compact-action" href={siteHref(channel.releasePageHref)}>
            <LocalizedText zh="查看发布页" en="View release page" />
          </a>
        ) : null}
      </div>
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
  const stableChannels = releaseCollection.stableChannels;
  const betaChannels = releaseCollection.betaChannels;
  const allChannels = [...stableChannels, ...betaChannels];
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
        about: ["App 下载", "iOS 下载", "Android 下载", "桌面版下载", "安装说明", "版本说明"],
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
        operatingSystem: "iOS, Android, macOS, Windows, Linux",
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
        <GlobalNetworkGlobe />
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
              zh="这一页集中放置 iOS、Android、桌面版、版本说明和安装步骤，让下载路径更短。"
              en="This page keeps iOS, Android, desktop releases, notes, and install steps in one place so the download path stays short."
            />
          </p>
        </div>
      </section>

      <section className="band compact-band" id="stable-channels">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="下载" en="Download" />
          </p>
          <h2>
            <LocalizedText zh="iOS 正式版在最前面，桌面版也都在这里。" en="iOS stable comes first, with every desktop build beside it." />
          </h2>
        </div>
        <div className="download-grid">
          {stableChannels.map((channel) => (
            <ReleaseChannelCard key={`${channel.audience}-${channel.platform}`} channel={channel} />
          ))}
        </div>
      </section>

      <section className="band alt" id="beta-channels">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="测试版" en="Beta" />
          </p>
          <h2>
            <LocalizedText zh="想提前体验，再看测试入口。" en="Use beta paths when you want early access." />
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
