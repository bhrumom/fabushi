import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/start-learning-buddhism");
const pageTitle = `学佛从哪里开始 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理学佛从哪里开始：先建立方向，再选一条可持续的练习主线，把佛经、禅修、因果理解、菩提心、六度、空性与日常功课接进生活。";

const starterPrinciples = [
  {
    titleZh: "先求方向清楚，不先求知道很多",
    titleEn: "Choose clarity before quantity",
    descriptionZh: "学佛一开始最容易累的，不是内容太少，而是一下子接触太多名相、法门和期待。先把方向理清，比急着补很多知识更重要。",
    descriptionEn: "Beginners usually tire out not because there is too little to learn, but because too many terms, methods, and expectations arrive at once. Clarity matters more than speed at the beginning.",
  },
  {
    titleZh: "先选一条主线，不先把所有方法都塞进来",
    titleEn: "Choose one main line first",
    descriptionZh: "可以先从佛法入门、禅修入门，或佛经导读里选一个最贴近自己当下问题的入口，而不是同时做满所有项目。",
    descriptionEn: "Start with the entry point that matches the question you are living with right now, whether that is dharma basics, meditation, or scripture, instead of forcing every method into day one.",
  },
  {
    titleZh: "先让练习变小，才能让它留下来",
    titleEn: "Make practice small enough to stay",
    descriptionZh: "每天留一点点阅读、听诵、禅修或记录，比偶尔做很多却无法持续，更适合初学者真正进入修行。",
    descriptionEn: "A little reading, listening, meditation, or reflection each day usually serves beginners better than occasional bursts that never become steady.",
  },
] as const;

const firstSteps = [
  {
    titleZh: "第一步：先问自己，为什么现在想学佛",
    titleEn: "Step 1: Ask why you want to begin now",
    descriptionZh: "有人是想先安定心念，有人是想理解佛法到底在讲什么，也有人是想把经文听诵和日常修持接进生活。先看清自己的问题，后面的入口就会更明确。",
    descriptionEn: "Some people want steadier attention, some want to understand what buddhadharma is actually pointing to, and some want to connect scripture and daily discipline into life. When the question becomes clear, the next step becomes simpler.",
  },
  {
    titleZh: "第二步：先选一个最容易进入的入口",
    titleEn: "Step 2: Pick the easiest workable entry point",
    descriptionZh: "如果你需要整体方向，先看佛法入门；如果你更想从练习开始，先看禅修入门；如果你更想从经典进入，先看佛经导读。先有入口，再慢慢扩展。",
    descriptionEn: "If you need the bigger picture, start with dharma basics. If you want practice first, start with meditation. If scripture feels closest, begin with the sutra guide. Enter first, then expand.",
  },
  {
    titleZh: "第三步：把第一周的节奏定得足够轻",
    titleEn: "Step 3: Keep the first week intentionally light",
    descriptionZh: "例如每天 5 到 10 分钟禅修，或听一段经文、读一小段导读，再留下几句记录。让节奏先活下来，比一开始做得很满更重要。",
    descriptionEn: "For example, meditate five to ten minutes a day, or listen to one short passage and read a small section before leaving a brief note. Keeping the rhythm alive matters more than doing a lot immediately.",
  },
] as const;

const commonMistakes = [
  {
    titleZh: "一开始就想把佛经读很多",
    titleEn: "Trying to read too many sutras immediately",
    descriptionZh: "初学者更需要的是找到一两部自己真的能读进去、也愿意反复回看的经典，而不是同时摊开很多内容。",
    descriptionEn: "Beginners usually need one or two texts they can really return to, not a large stack opened all at once.",
  },
  {
    titleZh: "一开始就把功课排得太满",
    titleEn: "Filling the routine too heavily from the start",
    descriptionZh: "如果每天安排得太复杂，很容易两三天后就中断。先做小、做稳，后面再加，通常更可靠。",
    descriptionEn: "A routine that is too complex often collapses within a few days. Small and steady is usually the more reliable start.",
  },
  {
    titleZh: "只收藏资料，却没有留下实际节奏",
    titleEn: "Collecting resources without a living rhythm",
    descriptionZh: "学佛入门真正有帮助的，不是收藏了多少链接，而是今天有没有读一点、坐一点、想一点，让理解回到生活。",
    descriptionEn: "What helps most is not how many links you save, but whether today included a little reading, sitting, and reflection that returns insight to ordinary life.",
  },
] as const;

const relatedPaths = [
  {
    href: "/buddhadharma",
    labelZh: "佛法入门",
    labelEn: "Dharma Basics",
    titleZh: "先看完整的学佛入门地图。",
    titleEn: "See the broader beginner map for buddhadharma.",
    descriptionZh: "如果你想先弄清佛法、修行、禅修和日常实践之间的关系，这一页更适合先打开。",
    descriptionEn: "Open this first if you want the wider map of buddhadharma, practice, meditation, and daily discipline.",
  },
  {
    href: "/what-is-karma",
    labelZh: "因果是什么意思",
    labelEn: "What Karma Means",
    titleZh: "先把初学者最常先遇到的核心概念放清楚。",
    titleEn: "Clarify one of the first core concepts beginners usually meet.",
    descriptionZh: "如果你现在最卡的是“因果到底是不是报应”，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if your question has already become whether karma simply means reward, punishment, or payback.",
  },
  {
    href: "/what-is-bodhicitta",
    labelZh: "菩提心是什么意思",
    labelEn: "What Bodhicitta Means",
    titleZh: "先把大乘修学里最关键的发心放清楚。",
    titleEn: "Clarify one of the most central intentions in Mahayana practice.",
    descriptionZh: "如果你现在最卡的是“菩提心到底是不是一种好心”，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if your question has already become whether bodhicitta is merely a kind feeling or a wider direction of practice.",
  },
  {
    href: "/what-are-the-six-paramitas",
    labelZh: "六度分别是什么",
    labelEn: "Six Paramitas",
    titleZh: "把发心怎样落回做人、修心和练习里接起来。",
    titleEn: "See how aspiration returns to conduct, training, and ordinary life.",
    descriptionZh: "如果你现在最卡的是“六度到底和日常修行有什么关系”，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if your question has already become how the six paramitas relate to ordinary practice.",
  },
  {
    href: "/what-is-emptiness",
    labelZh: "空性怎么理解",
    labelEn: "How to Understand Emptiness",
    titleZh: "把空性从抽象词句慢慢接回眼前最容易执着的地方。",
    titleEn: "Return emptiness from abstract language to the places where attachment feels strongest.",
    descriptionZh: "如果你现在最卡的是“空性是不是就是什么都没有”，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if your question has already become whether emptiness means nothingness or something usable in life.",
  },
  {
    href: "/beginner-sutra-recommendations",
    labelZh: "初学者佛经推荐",
    labelEn: "Beginner Sutra Picks",
    titleZh: "把“先读什么佛经”这个问题单独理清。",
    titleEn: "Answer the question of which sutra to begin with more directly.",
    descriptionZh: "如果你已经确定想从经典进入，但卡在《心经》、" +
      "《阿弥陀经》、" +
      "《普门品》还是《金刚经》更适合作为起点，这一页会更具体。",
    descriptionEn: "If you already know scripture is the doorway but feel stuck on whether the Heart Sutra, Amitabha Sutra, Universal Gate Chapter, or Diamond Sutra is the better start, this page is more specific.",
  },
  {
    href: "/sutra-listening",
    labelZh: "听诵和读经怎么配合",
    labelEn: "Listening and Reading",
    titleZh: "如果你想先靠听诵接近经典，再慢慢回到阅读。",
    titleEn: "See how listening can become a gentler doorway back into reading.",
    descriptionZh: "如果你更想知道经文听诵能不能代替读经、通勤里听经怎样接回阅读，这一页会更适合继续往下看。",
    descriptionEn: "This page is the better next step if you want to know whether listening can replace reading and how commute listening can return to the text.",
  },
  {
    href: "/daily-practice",
    labelZh: "日常功课怎么安排",
    labelEn: "Daily Practice",
    titleZh: "把最轻的晨起、白天和晚间功课慢慢接起来。",
    titleEn: "Connect the lightest morning, daytime, and evening practice into a living rhythm.",
    descriptionZh: "如果你最卡的是第一周功课怎么安排、怎样做得更稳，这一页会更适合继续往下走。",
    descriptionEn: "If your main difficulty is how to arrange the first week and make it steadier, this page is the better next step.",
  },
  {
    href: "/meditation",
    labelZh: "禅修入门",
    labelEn: "Meditation Guide",
    titleZh: "从最容易执行的练习开始安定心念。",
    titleEn: "Begin with the most workable practice for steadying the mind.",
    descriptionZh: "如果你最需要的是一个短时、稳定、可持续的修行入口，禅修入门会更具体。",
    descriptionEn: "If what you need most is a short, steady, sustainable entry into practice, the meditation guide is more concrete.",
  },
  {
    href: "/sutra-guide",
    labelZh: "佛经导读",
    labelEn: "Sutra Guide",
    titleZh: "从经典阅读与经文听诵进入佛法。",
    titleEn: "Enter buddhadharma through scripture reading and listening.",
    descriptionZh: "如果你更想知道初学者先读什么佛经、听诵和阅读如何配合，这一页更适合继续往下看。",
    descriptionEn: "If your question is which sutra to begin with and how listening works with reading, this is the better next page.",
  },
  {
    href: "/download",
    labelZh: "下载入口",
    labelEn: "Download",
    titleZh: "把提醒、听诵和记录放进日常。",
    titleEn: "Bring reminders, listening, and notes into daily life.",
    descriptionZh: "准备借助 Fabushi 承接经文听诵、禅修和修行记录时，可以直接查看下载入口。",
    descriptionEn: "If you are ready to use Fabushi for listening, meditation, and simple practice notes, go straight to the download page.",
  },
] as const;

const faqItems = [
  {
    questionZh: "学佛一定要先皈依吗？",
    questionEn: "Do I need to formally take refuge before I begin?",
    answerZh: "不一定。很多人会先从理解佛法、阅读导读、听诵或简单禅修开始，再在因缘成熟时向可信任的法师进一步请益。正式皈依是重要的决定，但不必把它变成理解佛法之前的门槛。",
    answerEn: "Not necessarily. Many people begin with understanding the basics, reading guides, listening, or simple meditation, and then seek deeper guidance from a trusted teacher when the conditions are ready. Formal refuge is meaningful, but it does not have to become a barrier to beginning.",
  },
  {
    questionZh: "学佛是先读经，还是先禅修？",
    questionEn: "Should I start with sutras or with meditation?",
    answerZh: "更重要的是看你当下最需要什么。如果你需要整体方向，可以先读导读和基础内容；如果你更需要稳定心念，也可以先从短时禅修开始。很多初学者最后会走到阅读和练习相互支撑的节奏。",
    answerEn: "The better question is what you need most right now. If you need orientation, begin with basic reading and guides. If you need steadiness, begin with short meditation sessions. Many beginners eventually benefit from letting reading and practice support each other.",
  },
  {
    questionZh: "初学者每天做多久比较合适？",
    questionEn: "How much should a beginner do each day?",
    answerZh: "通常从一段很轻的节奏开始更容易持续，例如每天 5 到 10 分钟禅修，或读一小段、听一小段经文，再留下一点记录。能持续，比一开始做很多更重要。",
    answerEn: "A light routine is usually easier to sustain, such as five to ten minutes of meditation, or a short segment of reading and listening followed by a quick note. Continuity matters more than volume at the start.",
  },
  {
    questionZh: "一开始看不懂很多术语怎么办？",
    questionEn: "What if I do not understand many buddhist terms at first?",
    answerZh: "这很常见。先抓住自己能理解的一两个概念，配合导读页慢慢进入，不需要第一天就把所有名相都弄懂。学佛入门更像是逐步熟悉，而不是一次背完。",
    answerEn: "That is very common. Hold onto one or two ideas you can really understand and use guide pages to enter gradually. Beginning buddhadharma is more like growing familiar over time than mastering every term at once.",
  },
  {
    questionZh: "Fabushi 最适合在学佛入门阶段做什么？",
    questionEn: "What is Fabushi most useful for at the beginner stage?",
    answerZh: "它更适合作为经文听诵、禅修提醒、简单记录和维持连续性的辅助工具，帮助你把修行节奏留在日常里。系统学习仍然要回到经典、老师和长期实践。",
    answerEn: "It works best as a support tool for scripture listening, meditation reminders, simple notes, and continuity so practice can stay inside daily life. Deeper learning still depends on texts, teachers, and sustained practice.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "学佛从哪里开始",
    "学佛入门",
    "佛法入门",
    "初学者学佛",
    "因果是什么意思",
    "空性怎么理解",
    "六度分别是什么",
    "佛教入门",
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

export default function StartLearningBuddhismPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "学佛从哪里开始",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: ["学佛从哪里开始", "佛法入门", "修行方法"],
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
            name: "学佛从哪里开始",
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
            <LocalizedText zh="学佛从哪里开始" en="Where to Begin" />
          </p>
          <h1>
            <LocalizedText
              zh="把学佛的第一步放轻一点、放清楚一点，反而更容易真正开始。"
              en="Make the first step into buddhadharma lighter and clearer so it can actually begin."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="先建立方向，再选一个最贴近自己当下问题的入口，把佛经、禅修、因果理解和日常练习慢慢接进生活，不必一开始就做得很满。"
              en="Start by setting direction, then choose the entry point that matches your present question and let scripture, meditation, karma, and daily practice enter life gradually instead of all at once."
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
              zh="学佛入门最难的，往往不是没有方法，而是不知道第一步该放在哪里。"
              en="The hardest part for beginners is usually not a lack of methods, but not knowing where the first step belongs."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="很多人刚接触佛法时，会同时遇到很多术语、很多法门、很多建议。有人告诉你先读经，有人告诉你先禅修，也有人说要先建立功课。听得越多，越容易觉得自己还没准备好开始。其实，多数初学者缺的不是更多信息，而是一个更轻、更清楚的起点。"
              en="When people first encounter buddhadharma, many terms, methods, and suggestions arrive at once. One person says to begin with sutras, another says to meditate first, and another says to build a daily routine. The more advice appears, the easier it is to feel unready. What most beginners need is not more information, but a lighter and clearer starting point."
            />
          </p>
          <p>
            <LocalizedText
              zh="比较稳妥的做法，是先问自己现在最想解决什么问题。是想先理解佛法到底在讲什么，还是想先让心安定一点，或是想把阅读、听诵和修持接进生活？问题一旦更清楚，第一步通常就不会那么难选。"
              en="A steadier approach is to ask what question you are really trying to solve right now. Do you want to understand what buddhadharma is pointing to, steady the mind a little more, or bring reading, listening, and practice into ordinary life? Once the question becomes clearer, the first step is usually easier to choose."
            />
          </p>
          <p>
            <LocalizedText
              zh="对多数人来说，学佛入门不需要一开始就把全部功课排满。先找到一条能够留下来的主线，例如读一点导读、坐一点禅修、听一点经文，再用简单记录帮助自己保持连续，往往比一次做很多更容易真正走下去。Fabushi 更适合承接这种节奏里的听诵、提醒和记录部分。"
              en="For most people, beginning buddhadharma does not require filling the whole day with practice immediately. It is often better to choose one line that can stay alive, such as reading a little, sitting a little, and listening a little, then using simple notes to maintain continuity. Fabushi fits best on the listening, reminder, and note-taking side of that rhythm."
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
              zh="先把学佛从哪里开始的三个判断放稳。"
              en="Set three basic judgments in place before you begin."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {starterPrinciples.map((item) => (
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
            <LocalizedText zh="起步步骤" en="First Steps" />
          </p>
          <h2>
            <LocalizedText
              zh="把第一周能做的事拆成三步，会比空想更容易落地。"
              en="Break the first week into three small steps so it becomes real instead of abstract."
            />
          </h2>
        </div>
        <div className="path-grid">
          {firstSteps.map((item) => (
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
            <LocalizedText zh="常见误区" en="Common Mistakes" />
          </p>
          <h2>
            <LocalizedText
              zh="先避开几个容易让入门变重的误区。"
              en="Avoid the patterns that make the beginner stage heavier than it needs to be."
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
              zh="按照你当下最需要的入口，继续往下一页走。"
              en="Move to the page that matches what you need most right now."
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
              zh="先回答学佛入门最容易问到的几个问题。"
              en="Answer the questions beginners most often ask first."
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
