import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/buddhadharma");
const pageTitle = `佛法入门 | ${brand.name}`;
const pageDescription =
  "从佛法是什么、初学者如何开始，到禅修、经文、因果与日常修行路径，Fabushi 提供清晰的入门导读。";

const dharmaHighlights = [
  {
    titleZh: "先理解佛法的方向",
    titleEn: "Start with the direction of buddhadharma",
    descriptionZh: "先分清佛法、佛教、修行和日常实践的关系，再决定自己要从哪一步开始。",
    descriptionEn: "Understand how buddhadharma, Buddhism, practice, and daily discipline fit together before you choose your first step.",
  },
  {
    titleZh: "把入门拆成更容易执行的步骤",
    titleEn: "Break beginner practice into workable steps",
    descriptionZh: "概念理解、经文阅读、禅修练习和日常记录可以分开推进，不需要一开始就全部做满。",
    descriptionEn: "Concepts, scripture reading, meditation, and daily tracking can move forward one by one. You do not need to do everything at once.",
  },
  {
    titleZh: "工具只是辅助，不替代学习本身",
    titleEn: "Tools support practice without replacing study",
    descriptionZh: "Fabushi 适合承接听诵、禅修和日常提醒，但系统学习仍要回到经典、老师与长期实践。",
    descriptionEn: "Fabushi can support sutra listening, meditation, and daily reminders, while deeper learning still depends on texts, teachers, and sustained practice.",
  },
] as const;

const learningPaths = [
  {
    href: "/start-learning-buddhism",
    labelZh: "学佛从哪里开始",
    labelEn: "Where to Begin",
    titleZh: "把入门顺序拆成更清楚的第一步。",
    titleEn: "Turn the beginner sequence into a clearer first step.",
    descriptionZh: "如果你最关心的是先读经、先禅修，还是先建立日常节奏，这一页会更聚焦地回答。",
    descriptionEn: "If your main question is whether to begin with sutras, meditation, or a daily rhythm, this page answers it more directly.",
  },
  {
    href: "/what-is-karma",
    labelZh: "因果是什么意思",
    labelEn: "What Karma Means",
    titleZh: "先把学佛里最常先遇到的核心概念说明白。",
    titleEn: "Clarify one of the first core concepts many beginners meet in buddhadharma.",
    descriptionZh: "如果你已经开始接触佛法，但常把因果理解成简单报应，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you have begun meeting buddhadharma but still hear karma as simple punishment or payback.",
  },
  {
    href: "/what-is-bodhicitta",
    labelZh: "菩提心是什么意思",
    labelEn: "What Bodhicitta Means",
    titleZh: "把大乘修学里最关键的发心先放清楚。",
    titleEn: "Clarify one of the most central intentions in Mahayana practice.",
    descriptionZh: "如果你已经开始接触佛法，但常把菩提心理解成空泛口号或只是一种好心，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you have begun meeting buddhadharma but still hear bodhicitta as either a vague slogan or simple kindness.",
  },
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "先把禅修、听诵、念佛和日常记录放回同一条路径里。",
    titleEn: "See how meditation, listening, recitation, and simple notes fit into one path.",
    descriptionZh: "如果你更关心学佛修行可以从哪些方法开始、怎么安排日常节奏，这一页会更合适。",
    descriptionEn: "If your main question is which methods to begin with and how to shape a daily rhythm, this page is the better next stop.",
  },
  {
    href: "/daily-practice",
    labelZh: "日常功课怎么安排",
    labelEn: "Daily Practice",
    titleZh: "把晨起、白天和晚间的轻功课慢慢接起来。",
    titleEn: "Connect a lighter routine across morning, daytime, and evening.",
    descriptionZh: "如果你已经知道要开始修行，但卡在功课怎么安排、怎么做得下去，这一页会更具体。",
    descriptionEn: "If you already know you want to practice but feel stuck on how to arrange a routine that can last, this page is more concrete.",
  },
  {
    href: "/meditation",
    labelZh: "禅修入门",
    labelEn: "Meditation Guide",
    titleZh: "先从短时、稳定、可持续的禅修练习开始。",
    titleEn: "Start with short, steady, sustainable meditation practice.",
    descriptionZh: "如果你最关心的是禅修怎么开始、一次多久、容易卡在哪里，这一页会更具体。",
    descriptionEn: "If your main question is how to begin meditation, how long to sit, and where beginners get stuck, this page goes deeper.",
  },
  {
    href: "/sutra-guide",
    labelZh: "佛经导读",
    labelEn: "Sutra Guide",
    titleZh: "先把佛经读什么、怎么读、听诵与阅读的关系理清。",
    titleEn: "Clarify what to read first and how listening supports understanding.",
    descriptionZh: "如果你更关心初学者读什么佛经、经文听诵怎么配合阅读，这一页会更适合继续往下走。",
    descriptionEn: "If your question is which sutra to start with and how listening fits with reading, this page is the better next stop.",
  },
  {
    href: "/sutra-listening",
    labelZh: "听诵和读经怎么配合",
    labelEn: "Listening and Reading",
    titleZh: "把“听诵能不能代替读经”这类问题单独说清楚。",
    titleEn: "Clarify how listening and reading support each other in beginner scripture study.",
    descriptionZh: "如果你已经开始接触经典，但更卡在听诵和阅读怎么配合、碎片时间里听经怎样接回文本，这一页会更具体。",
    descriptionEn: "This page is more specific if you are already touching scripture but feel stuck on how listening and reading should work together.",
  },
  {
    href: "/beginner-sutra-recommendations",
    labelZh: "初学者佛经推荐",
    labelEn: "Beginner Sutra Picks",
    titleZh: "把“先读什么佛经”这个问题单独理清。",
    titleEn: "Answer the question of which sutra to begin with more directly.",
    descriptionZh: "如果你最卡的是《心经》、" +
      "《阿弥陀经》、" +
      "《普门品》还是《金刚经》更适合作为起点，这一页会更具体。",
    descriptionEn: "If your main difficulty is choosing whether the Heart Sutra, Amitabha Sutra, Universal Gate Chapter, or Diamond Sutra is the better starting point, this page is more specific.",
  },
  {
    href: "/faq",
    labelZh: "常见问题",
    labelEn: "FAQ",
    titleZh: "先清掉下载、测试和使用前的阻碍。",
    titleEn: "Clear the practical blockers before you start.",
    descriptionZh: "如果你准备安装 Fabushi 或了解测试入口，先从这里开始会更顺。",
    descriptionEn: "Start here if you need download help, beta access details, or product basics before you begin.",
  },
  {
    href: "/insights",
    labelZh: "内容专栏",
    labelEn: "Insights",
    titleZh: "查看官网与产品的持续更新。",
    titleEn: "Follow product and site updates.",
    descriptionZh: "版本说明、官网结构变化和后续内容建设会继续记录在专栏里。",
    descriptionEn: "Release notes, site structure changes, and future content work continue in the insights section.",
  },
  {
    href: "/download",
    labelZh: "下载入口",
    labelEn: "Download",
    titleZh: "把经文听诵、禅修与修行记录放进日常。",
    titleEn: "Bring sutra listening, meditation, and practice tracking into daily life.",
    descriptionZh: "如果你已经准备开始使用产品，可以直接查看 Android、iOS 和镜像入口。",
    descriptionEn: "If you are ready to use the product, go straight to the Android, iOS, and mirror download paths.",
  },
] as const;

const faqItems = [
  {
    questionZh: "佛法入门最适合先学什么？",
    questionEn: "What should a beginner study first in buddhadharma?",
    answerZh: "先建立对佛法基本方向的理解，例如什么是修行、为什么重视因果和正见，再逐步加入经文阅读、禅修和日常功课。",
    answerEn: "Start by understanding the basic direction of buddhadharma: what practice means, why karma and right view matter, and then add scripture reading, meditation, and daily discipline step by step.",
  },
  {
    questionZh: "学佛一定要先读很多佛经吗？",
    questionEn: "Do I need to read many sutras before I begin?",
    answerZh: "不必一开始就求多。更重要的是先建立稳定节奏，理解核心概念，再逐渐扩展阅读范围。",
    answerEn: "No. It is more important to build a steady rhythm, understand core concepts, and expand your reading gradually.",
  },
  {
    questionZh: "禅修、听诵和日常记录之间应该怎么安排？",
    questionEn: "How should meditation, sutra listening, and daily tracking fit together?",
    answerZh: "可以先固定一条主线，例如每天短时禅修，再用听诵和记录帮助自己维持连续性，不必同时追求过多项目。",
    answerEn: "Choose one main line first, such as a short daily meditation session, then use listening and tracking to keep continuity without taking on too many practices at once.",
  },
  {
    questionZh: "Fabushi 适合拿来做什么？",
    questionEn: "What is Fabushi best used for?",
    answerZh: "它更适合作为经文听诵、禅修、修行记录和日常提醒的辅助工具，帮助初学者把修行节奏留在生活里。",
    answerEn: "It works best as a support tool for sutra listening, meditation, practice tracking, and daily reminders so beginners can keep a steady rhythm inside ordinary life.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "佛法",
    "佛法入门",
    "佛教入门",
    "学佛从哪里开始",
    "因果是什么意思",
    "禅修入门",
    "Fabushi",
  ],
  openGraph: {
    title: pageTitle,
    description: pageDescription,
    url: pageUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: pageTitle,
    description: pageDescription,
  },
};

export default function BuddhadharmaPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "CollectionPage",
        name: "佛法入门",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
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
            name: "佛法入门",
            item: pageUrl,
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
            <LocalizedText zh="佛法入门" en="Dharma Basics" />
          </p>
          <h1>
            <LocalizedText
              zh="从佛法是什么开始，建立更清晰的修行入门路径。"
              en="Start with what buddhadharma is and build a clearer path into practice."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="先理解佛法、禅修、经文、因果和日常修行之间的关系，再决定你最适合从哪里开始。"
              en="Understand how buddhadharma, meditation, scripture, karma, and daily discipline fit together before choosing your first step."
            />
          </p>
        </div>
      </section>

      <section className="band compact-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="导读" en="Guide" />
          </p>
          <h2>
            <LocalizedText
              zh="先把方向看清，再把练习留在日常里。"
              en="See the direction clearly first, then keep practice inside daily life."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="佛法不是只停留在概念上的知识点，而是一条帮助人理解身心、因果、烦恼和行动方式的修行路径。初学者最容易卡住的，不是信息太少，而是同时面对太多术语、太多方法和太多期待。"
              en="Buddhadharma is not just a set of abstract concepts. It is a path for understanding the mind, karma, suffering, and the way we act. Beginners usually get stuck not because there is too little information, but because there are too many terms, methods, and expectations all at once."
            />
          </p>
          <p>
            <LocalizedText
              zh="比较稳妥的开始方式，是先建立一个能长期坚持的节奏：先理解基本方向，再加入短时禅修、经文听诵或阅读，最后再慢慢扩展到更系统的内容。这样做更容易把修行从“偶尔想起”变成“每天都有一点点进展”。"
              en="A steadier way to begin is to build a rhythm you can keep: understand the basics first, add short meditation sessions and scripture listening or reading, and only then expand into broader study. That is usually how practice moves from an occasional thought to something that grows a little every day."
            />
          </p>
          <p>
            <LocalizedText
              zh="Fabushi 更适合承接这条入门路径里的实践部分，例如经文听诵、禅修、修行记录和日常提醒。它不能替代经典、老师和长期学习，但可以帮助你把修行节奏真正放进生活。"
              en="Fabushi is best used for the practical side of that beginner path: sutra listening, meditation, practice tracking, and daily reminders. It does not replace texts, teachers, or long-term study, but it can help practice live inside ordinary life."
            />
          </p>
        </div>
      </section>

      <section className="band alt feature-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="重点" en="Highlights" />
          </p>
          <h2>
            <LocalizedText
              zh="把入门拆成更容易理解和执行的三步。"
              en="Break the beginner journey into three easier steps."
            />
          </h2>
        </div>
        <div className="feature-grid">
          {dharmaHighlights.map((item) => (
            <article key={item.titleEn} className="feature-card">
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
            <LocalizedText zh="继续阅读" en="Keep Going" />
          </p>
          <h2>
            <LocalizedText
              zh="顺着这一页往下走，进入更具体的入口。"
              en="Use this page as the first stop, then move into the next useful path."
            />
          </h2>
        </div>
        <div className="editorial-list">
          {learningPaths.map((item) => (
            <a key={item.href} className="editorial-row" href={siteHref(item.href)}>
              <span>
                <LocalizedText zh={item.labelZh} en={item.labelEn} />
              </span>
              <div>
                <strong>
                  <LocalizedText zh={item.titleZh} en={item.titleEn} />
                </strong>
                <p>
                  <LocalizedText zh={item.descriptionZh} en={item.descriptionEn} />
                </p>
              </div>
            </a>
          ))}
        </div>
      </section>

      <section className="band faq-band">
        <div className="section-heading tight">
          <p>FAQ</p>
          <h2>
            <LocalizedText
              zh="先回答学佛入门最容易遇到的几个问题。"
              en="Answer the questions beginners usually hit first."
            />
          </h2>
        </div>
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
          <a className="primary-action" href={siteHref("/download")}>
            <LocalizedText zh="下载法布施" en="Download Fabushi" />
          </a>
          <a className="secondary-action" href={siteHref("/faq")}>
            <LocalizedText zh="查看常见问题" en="View FAQ" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
