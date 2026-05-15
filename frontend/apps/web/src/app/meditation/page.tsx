import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/meditation");
const pageTitle = `禅修入门 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理禅修怎么开始、一次练多久、常见误区，以及如何把禅修放进稳定的日常节奏。";

const meditationFoundations = [
  {
    titleZh: "先求稳定，不先求强烈体验",
    titleEn: "Build stability before chasing intensity",
    descriptionZh: "初学者更需要的是短时、规律、可持续的练习，而不是一开始就追求很深的体验。",
    descriptionEn: "Beginners benefit more from short, regular, sustainable sessions than from chasing intense experiences on day one.",
  },
  {
    titleZh: "禅修重在回到当下与观照身心",
    titleEn: "Meditation returns attention to the present",
    descriptionZh: "呼吸、身体感受、起心动念，都是帮助自己看见惯性和烦恼的入口。",
    descriptionEn: "Breath, bodily sensation, and mental movement all become entrances for seeing habitual patterns more clearly.",
  },
  {
    titleZh: "把练习留在生活里才更有意义",
    titleEn: "Practice matters when it stays inside daily life",
    descriptionZh: "真正关键的不是某一次坐得多好，而是你能否把觉察带回说话、做事和待人处事里。",
    descriptionEn: "What matters is not one perfect session, but whether awareness returns with you into speech, work, and relationships.",
  },
] as const;

const practiceSteps = [
  {
    titleZh: "第一步：先固定时长",
    titleEn: "Step 1: Fix the duration first",
    descriptionZh: "从每天 5 到 10 分钟开始，比偶尔坐很久更容易形成长期节奏。",
    descriptionEn: "Starting with five to ten minutes a day is usually more sustainable than occasional long sessions.",
  },
  {
    titleZh: "第二步：只抓一个观察对象",
    titleEn: "Step 2: Use one anchor",
    descriptionZh: "可以先用呼吸、身体感受或一句简短经句作为注意力锚点，避免一次放进太多方法。",
    descriptionEn: "Use one anchor such as breath, body sensation, or a short line of scripture instead of mixing too many methods at once.",
  },
  {
    titleZh: "第三步：练完后留下一点记录",
    titleEn: "Step 3: Leave a short record after each session",
    descriptionZh: "只记练了多久、心是否散乱、下一次准备怎么调整，就已经足够有帮助。",
    descriptionEn: "A short note about duration, distraction, and what to adjust next time is already enough to help continuity.",
  },
] as const;

const comparisonPoints = [
  {
    titleZh: "禅修不是单纯放空",
    titleEn: "Meditation is not blankness",
    descriptionZh: "禅修并不是把脑中念头全部压掉，而是带着清醒和觉察去看见它们如何生起、停留与变化。",
    descriptionEn: "Meditation is not about suppressing every thought, but noticing how thoughts arise, stay, and change with clarity.",
  },
  {
    titleZh: "禅修和一般放松练习并不完全相同",
    titleEn: "Meditation is not only relaxation",
    descriptionZh: "放松可能是结果之一，但佛法语境里的禅修更强调正念、观照和修心，而不只是舒缓情绪。",
    descriptionEn: "Relaxation can happen, but buddhadharma practice places more emphasis on mindfulness, observation, and training the mind than on mood relief alone.",
  },
  {
    titleZh: "冥想与禅修常被混用，但语境不同",
    titleEn: "Meditation and mindfulness language often overlap",
    descriptionZh: "现代人常把冥想当作通用词；若放在学佛语境里，禅修通常更明确地连到戒、定、慧和修行路径。",
    descriptionEn: "Many people use meditation as a general term, while buddhist practice often ties meditation more explicitly to discipline, concentration, insight, and a path of cultivation.",
  },
] as const;

const relatedPaths = [
  {
    href: "/buddhadharma",
    labelZh: "佛法入门",
    labelEn: "Dharma Basics",
    titleZh: "先回到更完整的学佛入门地图。",
    titleEn: "Return to the broader beginner map for buddhadharma.",
    descriptionZh: "如果你还在分辨佛法、修行、经文和日常实践的关系，先从主题中心页看全局。",
    descriptionEn: "If you are still mapping buddhadharma, practice, scripture, and daily discipline, start with the broader topic hub.",
  },
  {
    href: "/faq",
    labelZh: "常见问题",
    labelEn: "FAQ",
    titleZh: "先处理下载和使用上的实际阻碍。",
    titleEn: "Clear practical product questions first.",
    descriptionZh: "如果你准备通过 Fabushi 辅助禅修和听诵，这里能先解决下载与测试入口问题。",
    descriptionEn: "If you plan to use Fabushi for meditation and listening, the FAQ clears download and beta-entry blockers first.",
  },
  {
    href: "/download",
    labelZh: "下载入口",
    labelEn: "Download",
    titleZh: "把禅修节奏和修行记录放进日常。",
    titleEn: "Bring meditation rhythm and practice tracking into daily life.",
    descriptionZh: "准备开始使用产品时，可以直接查看 Android、iOS 和镜像下载入口。",
    descriptionEn: "When you are ready to use the product, go straight to Android, iOS, and mirror download paths.",
  },
] as const;

const faqItems = [
  {
    questionZh: "初学者禅修一次坐多久比较合适？",
    questionEn: "How long should a beginner meditate each time?",
    answerZh: "通常从 5 到 10 分钟开始最容易坚持。比起偶尔一次坐很久，稳定的小步前进更适合入门。",
    answerEn: "Five to ten minutes is usually the easiest starting point. Small, steady sessions are better for beginners than occasional long ones.",
  },
  {
    questionZh: "禅修时一直胡思乱想怎么办？",
    questionEn: "What if my mind keeps wandering during meditation?",
    answerZh: "分心本身就是练习的一部分。发现跑掉了，再轻轻回到呼吸或身体感受，不需要急着责备自己。",
    answerEn: "Wandering is part of the practice. Notice it, then return gently to breath or bodily sensation without blaming yourself.",
  },
  {
    questionZh: "禅修一定要打坐很久才有效吗？",
    questionEn: "Do I need long sitting sessions for meditation to work?",
    answerZh: "不一定。对初学者来说，短时但规律的练习往往比不稳定的长时间练习更有效。",
    answerEn: "No. For beginners, short and regular sessions are often more effective than irregular long ones.",
  },
  {
    questionZh: "Fabushi 在禅修入门里最适合扮演什么角色？",
    questionEn: "What role does Fabushi play in beginner meditation?",
    answerZh: "它更适合作为提醒、听诵、记录和保持连续性的辅助工具，帮助你把练习变成更稳定的生活节奏。",
    answerEn: "It works best as a support tool for reminders, scripture listening, session notes, and continuity so meditation can become part of daily life.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: ["禅修", "禅修入门", "初学者禅修", "冥想和禅修区别", "学佛入门", "Fabushi"],
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

export default function MeditationPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "禅修入门",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: ["禅修", "佛法入门", "修行方法"],
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
            item: siteUrl("/buddhadharma"),
          },
          {
            "@type": "ListItem",
            position: 3,
            name: "禅修入门",
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
            <LocalizedText zh="禅修入门" en="Meditation Guide" />
          </p>
          <h1>
            <LocalizedText
              zh="从短时、稳定、可持续的练习开始禅修。"
              en="Start meditation with short, steady, sustainable practice."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="先理解禅修在佛法里的位置，再安排每天可执行的小步练习，会比一开始追求很深的体验更稳。"
              en="Understand the place of meditation inside buddhadharma first, then build a daily rhythm of small workable sessions instead of chasing dramatic experiences." 
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
              zh="禅修入门的难点，通常不是方法太少，而是开始得太重。"
              en="The real difficulty for beginners is usually not too few methods, but starting too heavily."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="很多人一提到禅修，就会立刻联想到必须久坐、必须一念不生，或者必须很快得到明显变化。这样反而容易让初学者在一开始就挫败。更现实的方式，是先把禅修当成一种训练觉察与稳定心念的日常练习。"
              en="Many people hear meditation and immediately imagine long sessions, a completely quiet mind, or rapid transformation. That expectation often discourages beginners. A more realistic starting point is to treat meditation as daily training in awareness and steadiness."
            />
          </p>
          <p>
            <LocalizedText
              zh="在佛法语境里，禅修并不只是为了舒服或放松，而是帮助我们更清楚地看见自己的习气、烦恼和反应模式。哪怕每天只有几分钟，只要能保持连续，禅修就会慢慢从技巧变成习惯。"
              en="Inside buddhadharma, meditation is not only for comfort or relaxation. It helps us see habitual reactions, afflictions, and mental patterns more clearly. Even a few minutes a day can matter if the rhythm stays continuous."
            />
          </p>
          <p>
            <LocalizedText
              zh="Fabushi 更适合作为这条路径里的辅助工具，例如经文听诵、定时提醒和简单记录，让你把禅修留在生活里，而不是停留在偶尔想起时才做。"
              en="Fabushi works well as a support tool for this path through scripture listening, reminders, and simple records so meditation stays inside ordinary life instead of happening only when you happen to remember it."
            />
          </p>
        </div>
      </section>

      <section className="band alt feature-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="基础理解" en="Foundations" />
          </p>
          <h2>
            <LocalizedText
              zh="先把禅修的三个基本判断放稳。"
              en="Set three basic judgments in place before you begin."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {meditationFoundations.map((item) => (
            <article key={item.titleEn} className="definition-card">
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
            <LocalizedText zh="练习步骤" en="Practice Steps" />
          </p>
          <h2>
            <LocalizedText
              zh="把禅修入门拆成三步，更容易开始，也更容易坚持。"
              en="Break beginner meditation into three steps that are easier to start and keep."
            />
          </h2>
        </div>
        <div className="path-grid">
          {practiceSteps.map((item) => (
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
      </section>

      <section className="band alt">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="常见辨析" en="Common Distinctions" />
          </p>
          <h2>
            <LocalizedText
              zh="先澄清几个常被混在一起的说法。"
              en="Clarify the ideas that often get mixed together."
            />
          </h2>
        </div>
        <div className="compare-grid">
          {comparisonPoints.map((item) => (
            <article key={item.titleEn} className="compare-card">
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
              zh="顺着禅修入门页继续往下走，连接到更完整的学习和使用路径。"
              en="Use this page as a bridge into broader study and practical product paths."
            />
          </h2>
        </div>
        <div className="editorial-list">
          {relatedPaths.map((item) => (
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
              zh="先回答禅修入门最容易卡住的几个问题。"
              en="Answer the questions beginners most often get stuck on."
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
          <a className="secondary-action" href={siteHref("/buddhadharma")}>
            <LocalizedText zh="返回佛法入门" en="Back to Dharma Basics" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
