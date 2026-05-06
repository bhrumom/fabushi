import type { Metadata } from "next";
import { brand, downloadOptions, downloadStatusNotes } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";

export const metadata: Metadata = {
  title: `下载入口 | ${brand.name}`,
  description: "查看 Fabushi 官网、Flutter 主应用与微信小程序的当前开放状态和下一步入口。",
};

export default function DownloadPage() {
  return (
    <main className="inner-page">
      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">下载入口</p>
          <h1>把入口讲明白，比把所有端一次性堆出来更重要。</h1>
          <p className="lede">
            法布施当前采用官网、微信小程序和 Flutter 主应用协同推进的方式。不同入口承担不同职责，
            下载页的任务就是帮助用户快速判断自己现在应该从哪里开始。
          </p>
        </div>
      </section>

      <section className="band">
        <div className="download-grid">
          {downloadOptions.map((item) => (
            <a key={item.platform} className="download-card" href={item.ctaHref}>
              <span className="download-status">{item.status}</span>
              <h2>{item.platform}</h2>
              <p>{item.description}</p>
              <strong>{item.ctaLabel}</strong>
            </a>
          ))}
        </div>
        <div className="status-note-list">
          {downloadStatusNotes.map((item) => (
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
          <li>先看官网，了解产品定位、架构方向和当前开放状态。</li>
          <li>如果你更常在微信里传播或查看内容，优先关注小程序首期路线。</li>
          <li>如果你需要更完整、更沉浸的主体验，再申请 Flutter 主应用的测试入口。</li>
        </ol>
      </section>

      <SiteFooter />
    </main>
  );
}
