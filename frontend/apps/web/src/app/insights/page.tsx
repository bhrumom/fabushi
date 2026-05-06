import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { getAllArticles } from "../../lib/content";

export const metadata: Metadata = {
  title: `内容专栏 | ${brand.name}`,
  description: "查看 Fabushi 官网、小程序与主应用演进相关的路线、专题与结构说明。",
};

export default function InsightsIndexPage() {
  const articles = getAllArticles();

  return (
    <main className="inner-page">
      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">内容专栏</p>
          <h1>把产品路线、结构判断和阶段性设计写成长期可复用的内容资产。</h1>
          <p className="lede">
            官网需要承接的不只是首页视觉，还包括路线、专题、更新说明和长期积累的结构化内容。
          </p>
        </div>
      </section>

      <section className="band">
        <div className="editorial-list">
          {articles.map((item) => (
            <a key={item.slug} className="editorial-row" href={`/insights/${item.slug}`}>
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
          <a className="secondary-action" href="/feed.json">
            查看 JSON Feed
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
