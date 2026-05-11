import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { getAllArticles } from "../../lib/content";
import { siteHref } from "../../lib/site-url";

export const metadata: Metadata = {
  title: `更新记录 | ${brand.name}`,
  description: "查看 Fabushi 发布、路线和产品更新。",
};

export default function InsightsIndexPage() {
  const articles = getAllArticles();

  return (
    <main className="inner-page">
      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">内容专栏</p>
          <h1>产品更新和路线说明。</h1>
          <p className="lede">只保留和下载、体验、后续版本有关的内容。</p>
        </div>
      </section>

      <section className="band">
        <div className="editorial-list">
          {articles.map((item) => (
            <a key={item.slug} className="editorial-row" href={siteHref(`/insights/${item.slug}`)}>
              <span>{item.category}</span>
              <div>
                <strong>{item.title}</strong>
                <p>{item.description}</p>
                <small>{item.author} · {item.readTime}</small>
              </div>
            </a>
          ))}
        </div>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/apply")}>
            前往申请测试
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
