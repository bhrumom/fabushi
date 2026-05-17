import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const faqUrl = siteUrl("/faq");
const faqTitle = `学佛常见问题 | ${brand.name}`;
const faqDescription =
  "面向初学者整理学佛常见问题：学佛从哪里开始、先读经还是先禅修、佛学基本概念先看哪些、因果是什么意思、菩提心是什么意思、六度分别是什么、空性怎么理解，以及 Fabushi 在日常练习里最适合帮助什么。";

const faqItems = [
  {
    questionZh: "学佛从哪里开始，才不会一开始就太重？",
    questionEn: "How can I begin buddhadharma without making it too heavy immediately?",
    answerZh: "更稳的起点通常不是一下子学很多，而是先看清自己当下最需要的入口。可以先从“学佛从哪里开始”理清方向，再决定先走佛法入门、佛学基本概念、修行方法，还是佛经导读。",
    answerEn: "A steadier beginning is usually not to learn everything at once, but to clarify the doorway that matches your present question. Start by seeing where to begin, then choose whether dharma basics, core concepts, practice methods, or sutra study should come first.",
  },
  {
    questionZh: "先读经、先禅修，还是先把日常功课排出来？",
    questionEn: "Should I begin with sutras, meditation, or a daily routine?",
    answerZh: "更重要的是看你当下最需要什么。如果需要方向感，可以先看佛法入门；如果常常卡在因果、菩提心、六度、空性这些词，就先看佛学基本概念入门；如果需要把练习留在生活里，再继续看修行方法总览和日常功课安排。",
    answerEn: "The better question is what you need most right now. If you need orientation, begin with dharma basics. If core terms such as karma, bodhicitta, the six paramitas, or emptiness keep stopping you, begin with the concepts hub. If you need practice to stay inside daily life, continue into the practice guide and daily routine page.",
  },
  {
    questionZh: "佛学基本概念应该先看哪几个？",
    questionEn: "Which buddhist concepts should a beginner clarify first?",
    answerZh: "对很多初学者来说，先把因果、菩提心、六度和空性放进同一张地图里，往往比零散地碰到一个算一个更稳。先看概念总览页，再决定自己现在更该先读哪一张概念页，会更容易继续往下走。",
    answerEn: "For many beginners, it is steadier to place karma, bodhicitta, the six paramitas, and emptiness onto one map before treating them as isolated terms. Start with the concepts hub, then decide which concept page best matches the question you are living with now.",
  },
  {
    questionZh: "因果是不是就是做好事得好报、做坏事受惩罚？",
    questionEn: "Is karma just reward for good deeds and punishment for bad ones?",
    answerZh: "更稳妥的理解不是这样简单。因果更像是起心动念、说话做事和长期习惯怎样慢慢形成结果，中间还会受到很多因缘影响，所以不适合被理解成一句立刻兑现的判断。",
    answerEn: "A steadier understanding is not that simple. Karma is closer to the way intention, speech, action, and repeated habits gradually shape results together with many conditions, rather than an instant verdict.",
  },
  {
    questionZh: "菩提心是不是只要对人好一点就够了？",
    questionEn: "Is bodhicitta simply a matter of being a little nicer to people?",
    answerZh: "不完全是。善意当然重要，但菩提心更深一层，它牵涉愿意把觉悟之路和众生利益一起放进修行方向里，而不是只让学习围着自己的得失打转。",
    answerEn: "Not exactly. Kindness matters, but bodhicitta points more deeply toward placing awakening and the welfare of others inside the direction of practice instead of circling only around personal gain and loss.",
  },
  {
    questionZh: "六度是不是一定要等懂很多教理以后，才谈得到？",
    questionEn: "Do the six paramitas only matter after I understand a lot of doctrine?",
    answerZh: "不一定。对初学者来说，六度可以先从很小的地方开始，例如今天多一点耐心、少一点急躁、练习断掉以后再回来一次。它不是离生活很远的清单，而是把发心慢慢接回日常的六个方向。",
    answerEn: "Not necessarily. For beginners, the six paramitas can begin in very small ways, such as a little more patience today, a little less reactivity, or returning once more after the rhythm breaks. They are not distant doctrine, but six directions that slowly bring aspiration back into daily life.",
  },
  {
    questionZh: "空性是不是就是“什么都没有”？",
    questionEn: "Does emptiness mean that nothing exists at all?",
    answerZh: "通常不是这样理解。更稳妥的方向，是说一切法都依赖因缘条件而成立，没有一个永远固定、不依赖任何条件的自性。它不是把生活否定掉，而是帮助人少一点把事情抓得太实、太绝对。",
    answerEn: "Usually not. A steadier understanding is that all phenomena arise through conditions and do not possess an eternal self-existing essence. Emptiness does not cancel life, but helps loosen the tendency to treat things as too solid and absolute.",
  },
  {
    questionZh: "Fabushi 在学佛入门阶段最适合帮助什么？",
    questionEn: "What is Fabushi most useful for at the beginner stage?",
    answerZh: "它更适合作为经文听诵、禅修提醒、简单记录和维持连续性的辅助工具，帮助你把修行节奏留在日常里。系统学习仍然要回到经典、老师和长期实践。",
    answerEn: "It works best as a support tool for scripture listening, meditation reminders, simple notes, and continuity so practice can stay inside daily life. Deeper learning still depends on texts, teachers, and sustained practice.",
  },
] as const;

export const metadata: Metadata = {
  title: faqTitle,
  description: faqDescription,
  alternates: {
    canonical: faqUrl,
  },
  keywords: [
    "学佛常见问题",
    "学佛从哪里开始",
    "佛法入门",
    "佛学基本概念",
    "因果是什么意思",
    "菩提心是什么意思",
    "六度分别是什么",
    "空性怎么理解",
    "初学者佛经推荐",
    "修行方法",
    "Fabushi",
  ],
  openGraph: {
    title: faqTitle,
    description: faqDescription,
    url: faqUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: faqTitle,
    description: faqDescription,
  },
};

export default function FaqPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "学佛常见问题",
        url: faqUrl,
        description: faqDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: [
          "学佛常见问题",
          "学佛从哪里开始",
          "佛法入门",
          "佛学基本概念",
          "因果",
          "菩提心",
          "六度",
          "空性",
        ],
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
            name: "学佛常见问题",
            item: faqUrl,
          },
        ],
      },
      {
        "@type": "FAQPage",
        mainEntity: faqItems.map((item) => ({
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

      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">
            <LocalizedText zh="学佛常见问题" en="Beginner FAQ" />
          </p>
          <h1>
            <LocalizedText zh="先把学佛入门最常卡住的几个问题放清楚。" en="Clarify the beginner questions that most often block the next step." />
          </h1>
          <p className="lede">
            <LocalizedText zh="从学佛从哪里开始，到因果、菩提心、六度、空性，再到佛经、禅修和日常功课，这一页先把最常见的问题收在一起。" en="From where to begin, to karma, bodhicitta, the six paramitas, emptiness, sutras, meditation, and daily rhythm, this page gathers the questions beginners ask most often." />
          </p>
        </div>
      </section>

      <section className="band compact-band">
        <div className="faq-list full">
          {faqItems.map((item) => (
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
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/start-learning-buddhism")}>
            <LocalizedText zh="先看学佛从哪里开始" en="Start with Where to Begin" />
          </a>
          <a className="secondary-action" href={siteHref("/download")}>
            <LocalizedText zh="再看下载入口" en="Then View Downloads" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
