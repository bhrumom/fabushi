import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/daily-practice");
const pageTitle = `日常功课怎么安排 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理日常功课怎么安排：晨起、白天与晚间可以怎样放进禅修、经文听诵、念佛、阅读与简短回顾，帮助学佛修行真正留在生活里。";

const routinePrinciples = [
  {
    titleZh: "先让功课轻一点，才能让它留下来",
    titleEn: "Make the routine light enough to stay",
    descriptionZh: "很多人一提到日常功课，就会想到必须做很多、做很满。对初学者来说，更稳的起点通常是每天留下一个真实的小动作，而不是把自己一下排得很重。",
    descriptionEn: "Many people hear daily practice and imagine a routine that must be heavy and full. For beginners, a steadier beginning is usually one real small action each day instead of a schedule that becomes too heavy immediately.",
  },
  {
    titleZh: "先定主线，再让其他方法做辅助",
    titleEn: "Choose a main line and let the rest support it",
    descriptionZh: "可以先以短时禅修、经文听诵、念佛或阅读中的一项做主线，再让其他方法帮助自己维持连续，而不是平均分配每一样。",
    descriptionEn: "Let one method such as short meditation, scripture listening, recitation, or reading become the main line first, then allow the others to support continuity instead of giving every method equal weight.",
  },
  {
    titleZh: "功课的重点不是排满，而是相续",
    titleEn: "The point is continuity, not fullness",
    descriptionZh: "传统修学常重视闻、思、修能否慢慢接续起来。日常功课真正有用的地方，不在于今天做了多少，而在于明天还愿不愿意继续。",
    descriptionEn: "Traditional learning often values whether hearing, reflection, and practice can continue into one another. What makes a daily routine useful is not how much happened today, but whether you can return tomorrow.",
  },
] as const;

const dailyMoments = [
  {
    titleZh: "晨起：先把方向安住下来",
    titleEn: "Morning: settle the direction first",
    descriptionZh: "刚起床时，先留几分钟静坐、念佛，或听一小段经文，让这一天的心先有一个回来的地方。功课不必很长，但最好稳定。",
    descriptionEn: "Soon after waking, keep a few minutes for sitting, recitation, or one short scripture passage so the day begins with a place for the mind to return. The routine does not need to be long, but it helps when it is steady.",
  },
  {
    titleZh: "白天：留一个最容易实现的短动作",
    titleEn: "Daytime: keep one easy short action",
    descriptionZh: "通勤、步行、午休前后，都可以放进一段听诵、一轮念佛，或一句简短提醒。白天这一步的价值，是让修行不只留在早晚，而能慢慢回到生活中间。",
    descriptionEn: "Commuting, walking, or the edges of a break can hold one passage of listening, a short recitation, or a single reminder. The value of this daytime step is that practice starts to return to ordinary life instead of staying only in morning and evening blocks.",
  },
  {
    titleZh: "晚间：用很短的回顾把一天收住",
    titleEn: "Evening: close the day with a brief review",
    descriptionZh: "晚上不一定要再做很重的功课。很多时候，只要回顾今天有没有练习、哪里容易散乱、哪一句经文最有触动，再补一小段阅读或静坐，就已经很有帮助。",
    descriptionEn: "The evening does not need another heavy block. Often it is enough to review whether you practiced, where attention scattered, and which line stayed with you, then add a short reading or quiet sit if it still feels natural.",
  },
] as const;

const gentleSchedule = [
  {
    titleZh: "第一步：只先定一个早晚都做得到的动作",
    titleEn: "Step 1: Set one action you can do both morning and night",
    descriptionZh: "例如晨起五分钟静坐，晚间两分钟回顾；或早晨听一段经文，晚上读一小段导读。先让两端连起来，比中间塞很多内容更稳。",
    descriptionEn: "For example, sit for five minutes in the morning and review for two minutes at night, or listen in the morning and read a short guide at night. Connecting the two ends of the day is often steadier than filling the middle with too much content.",
  },
  {
    titleZh: "第二步：再给白天加一个很轻的提醒点",
    titleEn: "Step 2: Add one light reminder point during the day",
    descriptionZh: "不用追求完整流程，只要有一个最容易完成的动作，例如通勤时听诵、午间念佛几分钟，或看到提醒时停一下呼吸，就能让功课开始进入日常。",
    descriptionEn: "Do not chase a full sequence. One easy action such as listening during a commute, reciting for a few minutes at noon, or pausing with the breath when a reminder appears is enough to let practice enter daily life.",
  },
  {
    titleZh: "第三步：一周后再决定要不要加量",
    titleEn: "Step 3: Decide whether to add more only after a week",
    descriptionZh: "先让这条轻节奏活一周，再看自己是适合增加阅读、增加念佛，还是其实还需要再减一点。真正合适的功课，不是看起来很满，而是能继续走下去。",
    descriptionEn: "Let the lighter rhythm stay alive for a week first, then decide whether to add reading, add recitation, or simplify even more. A fitting routine is not the one that looks full, but the one that can keep going.",
  },
] as const;

const commonMistakes = [
  {
    titleZh: "把日常功课想成一次要做完的清单",
    titleEn: "Treating the routine like a checklist to finish",
    descriptionZh: "如果一开始就希望每天把很多项目全部完成，功课很容易变成压力，而不是帮助自己安住和观照的路径。",
    descriptionEn: "When the routine starts as a list that must be completed every day, it quickly becomes pressure instead of a path that steadies awareness.",
  },
  {
    titleZh: "只有早晚有功课，白天完全断开",
    titleEn: "Keeping practice only at the edges of the day",
    descriptionZh: "早晚各做一段当然很好，但若白天完全没有任何提醒或回返点，修行就比较难慢慢进入说话、做事和待人接物里。",
    descriptionEn: "Morning and evening practice are valuable, but if nothing recalls the path during the day, it becomes harder for practice to enter speech, work, and relationships.",
  },
  {
    titleZh: "做了几天后停掉，就以为自己不适合",
    titleEn: "Stopping for a few days and assuming you are not suited to practice",
    descriptionZh: "很多人的问题不是不适合，而是起点太重。节奏断掉以后，把功课再缩小一点重新开始，往往比责备自己更有用。",
    descriptionEn: "Many people are not unsuited to practice; the starting rhythm was simply too heavy. When continuity breaks, shrinking the routine and beginning again is often more useful than self-blame.",
  },
] as const;

const relatedPaths = [
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "先回到更完整的修行方法地图。",
    titleEn: "Return to the broader map of beginner practice methods.",
    descriptionZh: "如果你还在看禅修、听诵、念佛、阅读和记录之间如何配合，可以先回到总览页。",
    descriptionEn: "Return to the overview first if you are still mapping how meditation, listening, recitation, reading, and notes fit together.",
  },
  {
    href: "/start-learning-buddhism",
    labelZh: "学佛从哪里开始",
    labelEn: "Where to Begin",
    titleZh: "先回到更轻、更清楚的起步问题。",
    titleEn: "Return to the lighter and clearer beginner question first.",
    descriptionZh: "如果你还没有决定该从哪一条路开始，这一页会更适合先打开。",
    descriptionEn: "If you still have not decided which path to begin with, this page is the better first stop.",
  },
  {
    href: "/meditation",
    labelZh: "禅修入门",
    labelEn: "Meditation Guide",
    titleZh: "把静坐练习放进更稳定的日常节奏。",
    titleEn: "Place sitting practice into a steadier daily rhythm.",
    descriptionZh: "如果你已经确定禅修是主线，这一页会给出更具体的落地方式。",
    descriptionEn: "If meditation is already your main line, this page gives more direct practical detail.",
  },
  {
    href: "/sutra-guide",
    labelZh: "佛经导读",
    labelEn: "Sutra Guide",
    titleZh: "把听诵和阅读接回每天的功课里。",
    titleEn: "Bring listening and reading back into the daily routine.",
    descriptionZh: "如果你想让佛经学习也进入稳定节奏，这一页会更适合继续往下看。",
    descriptionEn: "If you want sutra study to enter a stable rhythm too, this is the better next page.",
  },
  {
    href: "/download",
    labelZh: "下载入口",
    labelEn: "Download",
    titleZh: "把提醒、听诵和记录放进生活里。",
    titleEn: "Bring reminders, listening, and notes into everyday life.",
    descriptionZh: "准备借助 Fabushi 承接听诵、禅修提醒和简短记录时，可以直接查看下载入口。",
    descriptionEn: "Go straight to downloads when you are ready to use Fabushi for listening, reminders, and simple notes.",
  },
] as const;

const faqItems = [
  {
    questionZh: "日常功课是不是一定要做很多才算认真？",
    questionEn: "Does a daily routine need to be heavy to count as sincere practice?",
    answerZh: "不一定。对初学者来说，功课更重要的是能不能相续。轻一点、真一点、能继续做下去，通常比一开始安排很多却很快中断更有帮助。",
    answerEn: "Not necessarily. For beginners, continuity matters more than intensity. A lighter routine that can stay alive is usually more helpful than a heavy one that stops quickly.",
  },
  {
    questionZh: "日常功课应该先放禅修、念佛，还是先读经？",
    questionEn: "Should a daily routine begin with meditation, recitation, or reading?",
    answerZh: "更适合先看你当下最需要什么。如果需要安定心念，可以先让短时禅修做主线；如果需要更容易进入的节奏，念佛或听诵也可以先开始；如果更需要方向感，则可以先把导读和短段阅读放进功课里。",
    answerEn: "It helps more to ask what you need most right now. If steadiness is the need, let short meditation lead. If you need an easier rhythm, recitation or listening can come first. If you need orientation, begin by placing guide reading into the routine.",
  },
  {
    questionZh: "白天工作忙，还能有日常功课吗？",
    questionEn: "Can I still keep a daily routine when work is busy?",
    answerZh: "可以。日常功课不一定等于大块时间。很多人真正能留下来的，是晨起几分钟、白天一个短提醒点、晚间一点回顾。功课轻一点，反而更容易和现实生活接上。",
    answerEn: "Yes. A daily routine does not require large blocks of time. Many people keep practice alive through a few minutes in the morning, one short reminder during the day, and a little review at night. Lighter often connects better with real life.",
  },
  {
    questionZh: "如果中断了几天，功课是不是就失败了？",
    questionEn: "If I miss a few days, has the routine failed?",
    answerZh: "不是。真正重要的不是从不间断，而是断掉以后能不能重新回来。中断后先把功课缩小一点，再重新开始，通常比硬撑原计划更稳。",
    answerEn: "No. What matters is not never breaking the rhythm, but being able to return after it breaks. When continuity stops, begin again with a smaller version instead of forcing the old plan.",
  },
  {
    questionZh: "Fabushi 在日常功课里最适合扮演什么角色？",
    questionEn: "What role does Fabushi play in a daily practice routine?",
    answerZh: "它更适合作为经文听诵、禅修提醒、简短记录和帮助维持连续性的辅助工具，让功课更容易放进每天的生活，而不是只在偶尔想起时才做。",
    answerEn: "It works best as a support tool for scripture listening, meditation reminders, short notes, and continuity so practice can live inside each day instead of appearing only occasionally.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "日常功课",
    "学佛日常功课",
    "初学者功课安排",
    "居士日常修行",
    "修行方法",
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

export default function DailyPracticePage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "日常功课怎么安排",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: ["日常功课", "学佛修行", "初学者功课安排"],
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
            name: "修行方法总览",
            item: siteUrl("/practice-guide"),
          },
          {
            "@type": "ListItem",
            position: 3,
            name: "日常功课怎么安排",
            item: pageUrl,
          },
        ],
      },
      {
        "@type": "ItemList",
        name: "日常功课的一日节奏",
        itemListElement: dailyMoments.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.titleZh,
          description: item.descriptionZh,
        })),
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
            <LocalizedText zh="日常功课怎么安排" en="Daily Practice" />
          </p>
          <h1>
            <LocalizedText
              zh="把功课排轻一点、排稳一点，反而更容易让修行真正留在生活里。"
              en="A lighter, steadier routine usually lets practice stay inside daily life more deeply."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="晨起、白天和晚间不用都做得很满。先让禅修、听诵、念佛、阅读或简短回顾中有一两步真正留下来，再慢慢把它们接成自己的日常功课。"
              en="Morning, daytime, and evening do not all need to be full. Let one or two steps in meditation, listening, recitation, reading, or review become real first, then connect them gradually into your own daily rhythm."
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
              zh="很多人卡住的不是不会做功课，而是一开始就把功课想得太重。"
              en="Many people do not get stuck because they cannot practice, but because they imagine the routine as too heavy from the beginning."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="一说到日常功课，很多人脑中立刻会出现一张很满的清单：要读经、要听诵、要禅修、要念佛、要记笔记，仿佛这样才算真正开始修行。可多数初学者真正遇到的困难，并不是没有方法，而是第一天就把自己排得太重，结果几天后反而停下来了。"
              en="When people hear daily practice, many immediately picture a full checklist of reading, listening, meditation, recitation, and notes, as if that is the only sincere beginning. Yet for most beginners, the problem is not a lack of methods. It is the weight of the schedule on day one, which often leads to stopping a few days later."
            />
          </p>
          <p>
            <LocalizedText
              zh="比较稳妥的功课，不是看起来最完整的那一种，而是最能留下来的那一种。传统修学常重视闻、思、修能否慢慢接续起来。放到今天的生活里，日常功课更像是一条轻轻贯穿一天的线，而不是早晚各做一大段、白天完全断开。"
              en="The steadier routine is usually not the one that looks most complete, but the one that can truly stay alive. Traditional learning often values whether hearing, reflection, and practice can continue into one another. Inside modern life, a daily routine often works better as a light thread through the day than as two heavy blocks that leave the middle empty."
            />
          </p>
          <p>
            <LocalizedText
              zh="Fabushi 更适合承接这条轻节奏里的辅助部分，例如经文听诵、禅修提醒、简短记录和帮助维持连续性。它不能替代长期学习本身，但能帮助你把“知道应该修”慢慢变成“今天真的做了一点”。"
              en="Fabushi fits best on the support side of this lighter rhythm through scripture listening, meditation reminders, short notes, and continuity. It does not replace long-term learning itself, but it can help practice move from something you know you should do to something you actually touched today."
            />
          </p>
        </div>
      </section>

      <section className="band alt feature-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="基本判断" en="Foundations" />
          </p>
          <h2>
            <LocalizedText
              zh="先把安排日常功课的三个基本判断放稳。"
              en="Set three basic judgments in place before arranging a daily routine."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {routinePrinciples.map((item) => (
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
            <LocalizedText zh="一日节奏" en="Daily Rhythm" />
          </p>
          <h2>
            <LocalizedText
              zh="把日常功课放回晨起、白天和晚间，会比只在脑中想象更容易落地。"
              en="Placing practice into morning, daytime, and evening makes it easier to live than keeping it only in the mind."
            />
          </h2>
        </div>
        <div className="path-grid">
          {dailyMoments.map((item) => (
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
            <LocalizedText zh="轻量安排" en="Light Schedule" />
          </p>
          <h2>
            <LocalizedText
              zh="先用三步把功课排轻一点，再决定要不要慢慢加深。"
              en="Use three steps to lighten the routine first, then decide whether it needs to deepen."
            />
          </h2>
        </div>
        <div className="compare-grid">
          {gentleSchedule.map((item) => (
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
            <LocalizedText zh="常见误区" en="Common Mistakes" />
          </p>
          <h2>
            <LocalizedText
              zh="先避开几个最容易让功课变重、变断的误区。"
              en="Avoid the patterns that most easily make practice too heavy or too fragile."
            />
          </h2>
        </div>
        <div className="evidence-grid">
          {commonMistakes.map((item) => (
            <article key={item.titleEn} className="evidence-card">
              <strong>
                <LocalizedText zh={item.titleZh} en={item.titleEn} />
              </strong>
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
            <LocalizedText zh="继续阅读" en="Keep Going" />
          </p>
          <h2>
            <LocalizedText
              zh="顺着你当下最需要的入口，继续往更具体的页面走。"
              en="Move from this page into the next route that matches what you need most now."
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
              zh="先回答初学者最容易在日常功课上卡住的几个问题。"
              en="Answer the questions beginners most often get stuck on when building a daily routine."
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
          <a className="secondary-action" href={siteHref("/practice-guide")}>
            <LocalizedText zh="返回修行方法总览" en="Back to Practice Guide" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
