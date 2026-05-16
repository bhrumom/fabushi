import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/what-is-karma");
const pageTitle = `因果是什么意思 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理因果是什么意思：因果不是简单报应，而是起心动念、说话做事与习惯怎样慢慢形成结果，并说明因果、业力与日常修行的关系。";

const karmaFoundations = [
  {
    titleZh: "因果不是神秘惩罚，而是行为怎样慢慢形成结果",
    titleEn: "Karma is not a mysterious punishment but the way actions become results",
    descriptionZh: "很多人一听到因果，就先想到“做错一件事就会被惩罚”。更稳妥的理解是：起心动念、说话做事和反复养成的习惯，会慢慢带出相应的方向和结果。",
    descriptionEn: "Many people hear karma and immediately imagine punishment for a single mistake. A steadier view is that intention, speech, action, and repeated habits gradually shape a direction and its results.",
  },
  {
    titleZh: "因果不是单线条报应，因和缘会一起作用",
    titleEn: "Karma is not a one-line reward system because causes and conditions work together",
    descriptionZh: "同样一件事，为什么在不同人身上会长成不同结果，往往不是只看一个因，而要连同很多条件一起看。佛法谈因果，也常提醒人看见因缘和合，而不是把世界想成简单算账。",
    descriptionEn: "The same event can unfold differently for different people because more than one cause is involved. Buddhism speaks of karma while also pointing to conditions, not a simplistic system of cosmic bookkeeping.",
  },
  {
    titleZh: "明白因果不是为了紧张，而是为了把选择变清楚",
    titleEn: "Understanding karma is not for fear but for clearer choices",
    descriptionZh: "学佛讲因果，不是要把人推向紧张和自责，而是帮助人看见：今天一个念头、一句话、一个动作，都在慢慢塑造后面的生活。能看清这一点，修行才比较容易落回日常。",
    descriptionEn: "The purpose of understanding karma is not anxiety or self-blame. It helps us see how today’s thoughts, words, and actions are already shaping tomorrow’s life so practice can return to daily living.",
  },
] as const;

const observationPaths = [
  {
    titleZh: "第一步：先从一句话、一个念头、一个动作看起",
    titleEn: "Step 1: Start with one thought, one sentence, or one action",
    descriptionZh: "因果最容易理解的入口，不一定是很大的命题，而是回头看今天自己怎样起心、怎样说话、怎样做事。很多结果，往往就是从这些很小的地方开始累起来。",
    descriptionEn: "The easiest doorway into karma is often not a huge idea, but noticing how you thought, spoke, and acted today. Many results begin accumulating from these smaller places.",
  },
  {
    titleZh: "第二步：再去看习惯怎样把方向越拉越稳",
    titleEn: "Step 2: Notice how habits keep pulling a direction into place",
    descriptionZh: "偶尔一次的善念或烦躁，并不一定立刻决定很多事；但反复出现的习惯，会越来越像一条路。佛法谈业力，常常就是在提醒人留意这种“反复做了什么，自己就慢慢成为什么”。",
    descriptionEn: "A single moment of kindness or irritation may not determine much immediately, but repeated habits begin to form a path. This is one of the most practical ways karma becomes visible.",
  },
  {
    titleZh: "第三步：最后回到当下还能转的地方",
    titleEn: "Step 3: Return to what can still be changed now",
    descriptionZh: "讲因果并不是为了把人锁在已经发生的事情里，而是让人看见：只要因和缘还在变化，方向就还有机会调整。学佛真正有力量的地方，也常常在这里。",
    descriptionEn: "Karma is not meant to trap a person inside what has already happened. As long as causes and conditions are still changing, direction can still be adjusted. Much of the strength of practice begins here.",
  },
] as const;

const conceptBlocks = [
  {
    titleZh: "业",
    titleEn: "Action and imprint",
    descriptionZh: "佛法里常说的“业”，可以先理解成带着意向去做、去说、去想之后，留在身心里的力量和倾向。它不是一句吓人的话，而是在解释习惯为什么会反复长成同一类结果。",
    descriptionEn: "Karma can first be understood as the force and tendency left in body and mind after intentional thought, speech, and action. It is not meant as a threat, but as an explanation of why patterns keep reproducing themselves.",
  },
  {
    titleZh: "缘",
    titleEn: "Conditions",
    descriptionZh: "只看“因”很容易把世界想得太简单。很多结果之所以会出现，还要看环境、关系、时机和自己当下的状态。把“缘”看进去，因果才不会被误会成机械报应。",
    descriptionEn: "Looking only at cause makes the world too simple. Results also depend on environment, relationships, timing, and present state. Seeing conditions prevents karma from collapsing into a mechanical reward-and-punishment story.",
  },
  {
    titleZh: "转变",
    titleEn: "Turning the direction",
    descriptionZh: "理解因果最重要的，不是急着判断过去，而是知道现在还能从发心、说话、做事和日常习惯上慢慢转向。修行之所以有意义，也正因为方向不是完全定死的。",
    descriptionEn: "The most important point is not to judge the past too quickly, but to see how direction can still shift through intention, speech, action, and daily habits. Practice matters because the path is not fixed once and for all.",
  },
] as const;

const commonMistakes = [
  {
    titleZh: "把因果理解成立刻兑奖或立刻受罚",
    titleEn: "Treating karma like instant reward or punishment",
    descriptionZh: "很多人一听“因果”，就期待今天做了什么，明天马上得到对应结果。现实和佛法里的因果都没有这么单线条，很多变化往往需要时间，也会受到很多条件影响。",
    descriptionEn: "Many people expect a one-day action to produce a next-day consequence. Life and karma do not usually move in such a straight line; many results unfold with time and through many conditions.",
  },
  {
    titleZh: "轻率把别人的遭遇解释成“报应”",
    titleEn: "Quickly labeling another person’s suffering as karmic payback",
    descriptionZh: "这是很需要避开的误区。别人的处境往往牵涉很复杂的因缘，不适合被轻率解释成一句“你这是报应”。学佛讲因果，更该让人长出谨慎、同理和自我反省，而不是增加冷漠。",
    descriptionEn: "This is an important mistake to avoid. Other people’s situations involve complex causes and conditions and should not be reduced to a cold sentence about payback. Understanding karma should deepen care, caution, and self-reflection, not judgment.",
  },
  {
    titleZh: "因为讲因果，就只剩害怕和自责",
    titleEn: "Reducing karma to fear and self-blame",
    descriptionZh: "如果理解因果以后，只剩“我是不是都做错了”，那通常说明抓错了重点。因果真正要帮助人看见的，是现在还能怎样慢慢调整方向，而不是把自己困在过去。",
    descriptionEn: "If karma only leaves you asking whether everything has already gone wrong, the point has usually been missed. Its real value is in seeing how direction can still be adjusted now rather than getting trapped in the past.",
  },
] as const;

const relatedPaths = [
  {
    href: "/buddhadharma",
    labelZh: "佛法入门",
    labelEn: "Dharma Basics",
    titleZh: "先回到更完整的学佛入门地图。",
    titleEn: "Return to the broader beginner map for buddhadharma.",
    descriptionZh: "如果你还想把佛法、修行、经典和日常实践之间的关系先整体看清，这一页更适合先打开。",
    descriptionEn: "Open this first if you still want the wider map of buddhadharma, practice, scripture, and daily life.",
  },
  {
    href: "/start-learning-buddhism",
    labelZh: "学佛从哪里开始",
    labelEn: "Where to Begin",
    titleZh: "把起步问题放轻一点、放清楚一点。",
    titleEn: "Make the beginner question lighter and clearer first.",
    descriptionZh: "如果你现在还在找最适合自己的第一步，可以先回到起步页。",
    descriptionEn: "Return here first if you are still looking for the doorway that fits your present question best.",
  },
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "把因果放回禅修、听诵、念佛和阅读的日常节奏里。",
    titleEn: "Return karma to the daily rhythm of meditation, listening, recitation, and reading.",
    descriptionZh: "如果你更关心理解因果以后，练习方式要怎样慢慢落到生活里，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you want to see how understanding karma returns to actual daily practice.",
  },
  {
    href: "/daily-practice",
    labelZh: "日常功课怎么安排",
    labelEn: "Daily Practice",
    titleZh: "从每天很小的动作里重新看见因果。",
    titleEn: "See karma again through the small actions of an ordinary day.",
    descriptionZh: "如果你想把“因果不是大道理，而是每天怎样做”接回现实节奏，这一页会更具体。",
    descriptionEn: "This page is more concrete if you want to connect karma with the small patterns of an ordinary day.",
  },
  {
    href: "/faq",
    labelZh: "常见问题",
    labelEn: "FAQ",
    titleZh: "先清掉下载、测试和使用前的实际问题。",
    titleEn: "Clear the practical questions before you begin using the product.",
    descriptionZh: "如果你正准备安装 Fabushi 或了解产品入口，可以先从这里开始。",
    descriptionEn: "Start here if you are preparing to install Fabushi or need product entry details first.",
  },
  {
    href: "/download",
    labelZh: "下载入口",
    labelEn: "Download",
    titleZh: "把提醒、听诵和记录放进日常。",
    titleEn: "Bring reminders, listening, and notes into daily life.",
    descriptionZh: "准备借助 Fabushi 承接听诵、提醒和简短记录时，可以直接查看下载入口。",
    descriptionEn: "Go straight to downloads when you are ready to use Fabushi for listening, reminders, and short notes.",
  },
] as const;

const faqItems = [
  {
    questionZh: "因果是不是做好事就立刻有好报，做坏事就立刻有坏报？",
    questionEn: "Does karma mean good actions bring immediate reward and bad actions immediate punishment?",
    answerZh: "通常不是这样简单。因果更像是一种方向和累积：不同的行为会慢慢形成不同的结果，但中间还会受到时间、环境和很多条件影响，所以不一定立刻显现。",
    answerEn: "Usually not in such a simple way. Karma is more like direction and accumulation: actions gradually shape results, but timing, environment, and many conditions also matter, so the outcome does not always appear immediately.",
  },
  {
    questionZh: "因果和命运是不是一回事？",
    questionEn: "Is karma the same thing as fate?",
    answerZh: "不完全一样。把因果理解成命运，容易让人觉得一切都已经定死。更稳妥的理解是：过去会带来影响，但现在的发心、选择和习惯，仍然会继续参与塑造后面的方向。",
    answerEn: "Not exactly. Treating karma as fate makes everything feel fixed. A steadier view is that the past influences the present, but present intention, choice, and habit still keep shaping what comes next.",
  },
  {
    questionZh: "学佛讲因果，会不会让人更焦虑？",
    questionEn: "Can learning about karma make a person more anxious?",
    answerZh: "如果只把因果理解成随时会被惩罚，确实容易焦虑；但这通常不是佛法更稳妥的理解方式。明白因果真正有帮助的地方，是看见自己仍然可以从今天的念头、说话和行动开始慢慢调整。",
    answerEn: "It can if karma is reduced to the fear of constant punishment, but that is not the steadier Buddhist understanding. Its real help is in seeing that adjustment can begin now through thoughts, speech, and action.",
  },
  {
    questionZh: "过去做错很多事，是不是就已经没有办法了？",
    questionEn: "If I have made many mistakes in the past, is it already too late?",
    answerZh: "不是。佛法谈因果，并不是为了把人困在过去，而是为了让人看见：只要现在还在起心动念、还在做选择，方向就还可以慢慢转。承认、调整、少做会加重烦恼的事，本身就是新的因。",
    answerEn: "No. Karma is not taught to trap a person in the past, but to show that as long as intention and choice are still alive, direction can still shift. Acknowledging, adjusting, and reducing what deepens confusion are already new causes.",
  },
  {
    questionZh: "Fabushi 在理解因果这件事上最适合帮助什么？",
    questionEn: "What is Fabushi most useful for when reflecting on karma?",
    answerZh: "它更适合作为听诵、提醒和简短记录的辅助工具，帮助你把“今天怎样起心、怎样说话、怎样练习”慢慢接回日常节奏。更深入的理解，仍然要回到佛法学习、经典导读和长期实践。",
    answerEn: "It works best as a support tool for listening, reminders, and short notes so the way you think, speak, and practice today can return to daily rhythm. Deeper understanding still depends on study, scripture guides, and sustained practice.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "因果是什么意思",
    "因果",
    "佛教因果",
    "因果报应",
    "业力",
    "学佛入门",
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

export default function WhatIsKarmaPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "因果是什么意思",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: ["因果", "佛教因果", "业力"],
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
            name: "因果是什么意思",
            item: pageUrl,
          },
        ],
      },
      {
        "@type": "ItemList",
        name: "理解因果的三个观察入口",
        itemListElement: observationPaths.map((item, index) => ({
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
            <LocalizedText zh="因果" en="Karma" />
          </p>
          <h1>
            <LocalizedText
              zh="因果不是简单报应，而是今天怎样起心、怎样说话、怎样做事，正在慢慢形成后面的生活。"
              en="Karma is not simple payback, but the way today’s intention, speech, and action gradually shape the life that follows."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="很多人第一次听到“因果”，不是立刻明白，反而会更紧张：是不是做错一件事就会马上受罚？更稳妥的理解，通常不是往神秘或恐惧走，而是回到日常，看见一个念头、一句话、一个习惯，怎样慢慢把方向带出来。"
              en="The first encounter with karma often creates tension instead of clarity. A steadier understanding does not move toward mystery or fear, but back into ordinary life where one thought, one sentence, and one habit gradually shape a direction."
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
              zh="很多人真正误会的，不是“有没有因果”，而是把因果想得太像一句立刻兑现的判断。"
              en="The deeper misunderstanding is often not whether karma exists, but imagining it as an immediate verdict."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="有些人一遇到不顺，就会急着问：“这是不是报应？”也有人一听到佛法讲因果，就觉得那是一种很重、很可怕、会让人处处紧张的世界观。可更稳妥的理解，往往不是把因果看成一句随时降下来的判断，而是看见：人怎样起心、怎样说话、怎样做事，又怎样反复养成习惯，这些都会慢慢长成后面的生活。"
              en="Some people meet difficulty and immediately ask whether it is karmic payback. Others hear karma in Buddhism and imagine a heavy worldview full of tension and threat. A steadier understanding is not to treat karma as a sentence falling from above, but to notice how intention, speech, action, and repeated habit gradually become the life that follows."
            />
          </p>
          <p>
            <LocalizedText
              zh="佛法讲因果，也常提醒人同时看见因与缘。很多结果并不是由一个单独原因马上推出，而是许多条件一起作用。这样去看，因果就不再像一种简单惩罚，而更像是在提醒我们：任何方向，都是一点一点被养出来的；任何调整，也常常要从一点一点重新养回来。"
              en="Buddhism speaks of karma while also asking us to see causes together with conditions. Many results do not arise from one isolated reason, but through many factors working together. From that angle, karma stops looking like punishment and begins to look like a reminder: every direction is cultivated little by little, and every real adjustment often returns the same way."
            />
          </p>
          <p>
            <LocalizedText
              zh="所以，理解因果最有力量的地方，不是急着解释别人，也不是只回头追究过去，而是把眼光放回今天：说这句话时心里是什么发心？做这件事时是在增长贪、嗔、痴，还是在让自己更清明一点？传统修学常说闻、思、修要相续，对初学者来说，因果真正能帮助的，也正是在这里。Fabushi 更适合承接其中听诵、提醒和简短记录的部分，帮助你把这些观察慢慢留在日常里。"
              en="That is why the strength of karma does not lie in explaining other people or chasing the past, but in returning attention to today: what intention was alive in this sentence, and did this action strengthen confusion or clarity? Traditional learning often speaks of hearing, reflection, and practice as a living sequence. Karma becomes useful for beginners in exactly that way. Fabushi fits best on the listening, reminder, and short-note side of that sequence so these observations can stay inside daily life."
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
              zh="先把理解因果的三个基本判断放稳。"
              en="Set three basic judgments in place before thinking further about karma."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {karmaFoundations.map((item) => (
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
            <LocalizedText zh="观察入口" en="Observation Paths" />
          </p>
          <h2>
            <LocalizedText
              zh="把因果放回一个念头、一句话、一个习惯里，通常会比空想更容易懂。"
              en="Karma becomes easier to understand when it returns to one thought, one sentence, and one habit."
            />
          </h2>
        </div>
        <div className="path-grid">
          {observationPaths.map((item) => (
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
            <LocalizedText zh="关键概念" en="Key Concepts" />
          </p>
          <h2>
            <LocalizedText
              zh="先分清业、缘和还能转的方向。"
              en="Clarify action, conditions, and the possibility of turning direction."
            />
          </h2>
        </div>
        <div className="compare-grid">
          {conceptBlocks.map((item) => (
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
              zh="先避开几个最容易把因果理解重、理解偏的误区。"
              en="Avoid the patterns that make karma heavier or narrower than it needs to be."
            />
          </h2>
        </div>
        <div className="compare-grid">
          {commonMistakes.map((item) => (
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
              zh="把这张概念页接回更完整的入门、修行和日常路径。"
              en="Use this concept page as a bridge back into the wider beginner, practice, and daily-life paths."
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
              zh="先回答初学者最容易在“因果是什么意思”上继续追问的几个问题。"
              en="Answer the questions beginners most often ask after meeting the idea of karma."
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
