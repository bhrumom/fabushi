import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import {
  getOfficialSiteReleaseCollection,
  type OfficialSiteChannel,
} from "../../lib/official-site-releases";
import { siteHref } from "../../lib/site-url";

export const metadata: Metadata = {
  title: `下载入口 | ${brand.name}`,
  description: "查看 Fabushi 官网上的 Android Beta、iOS TestFlight 与正式版发布状态。",
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

  return (
    <main className="inner-page">
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
