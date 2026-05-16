import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import {
  FORUM_SECTIONS,
  GOVERNANCE_SIGNALS,
  LAUNCH_STEPS,
  STARTER_THREADS,
} from "../../lib/community";
import { siteHref, siteUrl } from "../../lib/site-url";

const communityUrl = siteUrl("/community");
const communityTitle = `佛法论坛 | ${brand.name}`;
const communityDescription =
  "Fabushi 佛法论坛首版入口，公开展示板块结构、讨论方向、治理原则与后续迭代路径。";

export const metadata: Metadata = {
  title: communityTitle,
  description: communityDescription,
  alternates: {
    canonical: communityUrl,
  },
  keywords: [
    "佛法论坛",
    "佛教社区",
    "学佛问答",
    "禅修讨论",
    "Fabushi community",
  ],
  openGraph: {
    title: communityTitle,
    description: communityDescription,
    url: communityUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: communityTitle,
    description: communityDescription,
  },
};

export default function CommunityPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "CollectionPage",
        name: "Fabushi 佛法论坛",
        url: communityUrl,
        description: communityDescription,
      },
      {
        "@type": "ItemList",
        name: "Fabushi 佛法论坛板块",
        itemListElement: FORUM_SECTIONS.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.titleZh,
          description: item.summaryZh,
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

      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">
            <LocalizedText zh="论坛首版" en="Community MVP" />
          </p>
          <h1>
            <LocalizedText
              zh="把佛法讨论做成能长期沉淀的社区。"
              en="Build a dharma community that can compound over time."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="这里先公开论坛的首版结构：板块怎么分、首批讨论从哪里开始、秩序怎么维持，以及后面会怎样一步步补上真实互动能力。"
              en="This first version makes the community structure public: how the boards are organized, where early discussions begin, how order is maintained, and how real interaction will be added step by step."
            />
          </p>
        </div>
      </section>

      <section className="band compact-band">
        <div className="recommended-banner">
          <LocalizedText
            zh="当前阶段：论坛公开入口已经建立，下一步优先补发帖、回复、收藏、关注和新手引导。"
            en="Current stage: the public forum entry is live, and the next priority is posting, replies, bookmarks, follows, and newcomer guidance."
          />
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="这不是一个追求热闹的泛讨论区。Fabushi 论坛会优先服务真实修学者和认真提问的新手，让高质量讨论慢慢沉淀成可复用的知识，而不是被时间线冲散。"
              en="This is not meant to become a noisy general chat zone. The Fabushi forum is designed first for sincere newcomers and long-term practitioners, so good discussions can accumulate into reusable knowledge instead of disappearing in a feed."
            />
          </p>
          <p>
            <LocalizedText
              zh="首版先把社区骨架搭清楚，再逐步接入账户、互动和治理能力。这样做的目标不是拖慢进度，而是确保论坛一开始就有方向、有边界，也有持续扩展的余地。"
              en="The first release starts by making the community skeleton clear, then adds accounts, interaction, and governance in layers. The goal is not to move slowly, but to make sure the forum begins with direction, boundaries, and room to grow."
            />
          </p>
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="板块结构" en="Board Structure" />
          </p>
          <h2>
            <LocalizedText
              zh="先把讨论空间分清楚，后续内容才有沉淀的可能。"
              en="Clear discussion spaces first, so later knowledge has somewhere to settle."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {FORUM_SECTIONS.map((item) => (
            <article key={item.slug} className="definition-card">
              <h3>
                <LocalizedText zh={item.titleZh} en={item.titleEn} />
              </h3>
              <p>
                <LocalizedText zh={item.summaryZh} en={item.summaryEn} />
              </p>
              <p>
                <LocalizedText zh={item.guidanceZh} en={item.guidanceEn} />
              </p>
            </article>
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="首批讨论题" en="Starter Threads" />
          </p>
          <h2>
            <LocalizedText
              zh="论坛不是先空着等人来，而是先给出值得讨论的问题。"
              en="The forum should not wait empty for people to arrive. It should begin with good questions."
            />
          </h2>
        </div>
        <div className="editorial-list">
          {STARTER_THREADS.map((item) => (
            <article key={item.titleEn} className="editorial-row">
              <span>
                <LocalizedText zh={item.sectionZh} en={item.sectionEn} />
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
            <LocalizedText zh="治理原则" en="Governance" />
          </p>
          <h2>
            <LocalizedText
              zh="秩序不是靠压制建立的，而是靠清晰边界和稳定引导。"
              en="Order is not built by force alone. It comes from clear boundaries and steady guidance."
            />
          </h2>
        </div>
        <div className="governance-grid">
          {GOVERNANCE_SIGNALS.map((item) => (
            <article key={item.titleEn} className="governance-card">
              <h3>
                <LocalizedText zh={item.titleZh} en={item.titleEn} />
              </h3>
              <p>
                <LocalizedText zh={item.descriptionZh} en={item.descriptionEn} />
              </p>
            </article>
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="迭代路径" en="Launch Path" />
          </p>
          <h2>
            <LocalizedText
              zh="从公开入口开始，一步步走到真实可用的论坛。"
              en="Start with a public entry, then move step by step toward a working forum."
            />
          </h2>
        </div>
        <div className="path-grid">
          {LAUNCH_STEPS.map((item) => (
            <article key={item.titleEn} className="path-card">
              <h3>
                <LocalizedText zh={item.titleZh} en={item.titleEn} />
              </h3>
              <p>
                <LocalizedText zh={item.descriptionZh} en={item.descriptionEn} />
              </p>
            </article>
          ))}
        </div>
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/")}>
            <LocalizedText zh="回到首页" en="Back to home" />
          </a>
          <a className="secondary-action" href={siteHref("/contact")}>
            <LocalizedText zh="联系团队反馈论坛需求" en="Contact the team with forum feedback" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}