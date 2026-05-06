import type { Metadata } from "next";
import { betaApplicationTracks, brand } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref } from "../../lib/site-url";

export const metadata: Metadata = {
  title: `申请测试 | ${brand.name}`,
  description: "查看 Fabushi 当前可申请的测试与合作入口，并按不同场景选择对应通道。",
};

export default function ApplyPage() {
  return (
    <main className="inner-page">
      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">申请测试</p>
          <h1>先把申请入口分清楚，后续沟通和发放资格才不会乱成一团。</h1>
          <p className="lede">
            当前官网阶段最需要的是把 iOS、Android 和合作沟通三条入口拆清楚，
            让不同目的的人能直接走到正确通道，而不是先发来一封没有上下文的邮件。
          </p>
        </div>
      </section>

      <section className="band">
        <div className="section-heading">
          <p>申请通道</p>
          <h2>按你的目标选择入口，会比一股脑挤到同一个邮箱主题里更高效。</h2>
        </div>
        <div className="application-grid">
          {betaApplicationTracks.map((item) => (
            <article key={item.name} className="application-card">
              <div>
                <p className="eyebrow">{item.name}</p>
                <h2>{item.name}</h2>
              </div>
              <p className="application-summary">{item.summary}</p>
              <ol className="application-list">
                {item.checklist.map((entry) => (
                  <li key={entry}>{entry}</li>
                ))}
              </ol>
              <a className="primary-action" href={siteHref(item.ctaHref)}>
                {item.ctaLabel}
              </a>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>申请建议</p>
          <h2>把基本信息一次带全，往返确认会少很多。</h2>
        </div>
        <ol className="roadmap-list">
          <li>说明你最关心的是传播、修行记录、榜单社交，还是渠道合作。</li>
          <li>如果是设备测试，请把平台、机型或系统版本一并写清楚。</li>
          <li>如果你愿意持续反馈问题，也建议在申请邮件里直接写明。</li>
        </ol>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/download")}>
            回到下载入口
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
