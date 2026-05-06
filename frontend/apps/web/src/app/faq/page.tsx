import type { Metadata } from "next";
import { brand, faqItems } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";

export const metadata: Metadata = {
  title: `常见问题 | ${brand.name}`,
  description: "查看官网、微信小程序与主应用之间的职责划分，以及首期上线范围。",
};

export default function FaqPage() {
  return (
    <main className="inner-page">
      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">常见问题</p>
          <h1>把最容易反复解释的问题写出来，官网才真正开始工作。</h1>
          <p className="lede">
            这一页优先回答官网、微信小程序和 Flutter 主应用之间的关系，以及为什么当前要拆出新的前端 monorepo。
          </p>
        </div>
      </section>

      <section className="band">
        <div className="faq-list full">
          {faqItems.map((item) => (
            <details key={item.question} className="faq-item" open>
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
