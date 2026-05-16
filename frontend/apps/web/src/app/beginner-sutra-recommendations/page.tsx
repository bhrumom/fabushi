import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/beginner-sutra-recommendations");
const pageTitle = `初学者先读什么佛经 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理先读什么佛经更合适：从《心经》《阿弥陀经》《普门品》《金刚经》这些常见入口，理解各自更适合回答什么问题，并把听诵、阅读与日常修行接起来。";

const selectionPrinciples = [
  {
    titleZh: "先按自己当下的问题选，不先按“最有名”选",
    titleEn: "Choose by your living question before choosing by fame",
    descriptionZh: "初学者容易一上来就想找最权威、最完整、最有名的一部经典，但真正更稳的起点，往往是先看哪一部更贴近你眼下最想弄明白的问题。",
    descriptionEn: "Beginners often look first for the most famous or comprehensive text, but a steadier start is usually the sutra that speaks more directly to the question you are actually living with now.",
  },
  {
    titleZh: "先求能反复读进去，不先求一次读很多",
    titleEn: "Choose what you can return to, not what you can finish quickly",
    descriptionZh: "与其一下子摊开很多经典，不如先找到一两部你愿意反复听、反复读、反复想的经文。能留下来，比一开始读得广更重要。",
    descriptionEn: "Instead of opening many texts at once, it is usually better to begin with one or two sutras you are willing to hear, read, and reflect on repeatedly. What stays matters more than what starts wide.",
  },
  {
    titleZh: "让听诵、阅读和一点记录互相配合",
    titleEn: "Let listening, reading, and one small note support each other",
    descriptionZh: "传统学习常说闻、思、修要相续。对初学者来说，可以先通过听诵熟悉经文，再读一点导读或原文，最后留下一个触动自己的意思，佛经学习就更容易真正进入生活。",
    descriptionEn: "Traditional learning often speaks of hearing, reflection, and practice as a living sequence. Beginners can first listen for familiarity, then read a little guide or text, and finally leave one idea that truly landed so sutra study can move into life.",
  },
] as const;

const sutraRecommendations = [
  {
    titleZh: "《心经》",
    titleEn: "Heart Sutra",
    fitZh: "适合想先接触佛法核心词汇、感受经典语言节奏的人。",
    fitEn: "A good first doorway if you want to meet core buddhist language and feel the rhythm of scripture.",
    descriptionZh: "《心经》篇幅短、流通广，很多初学者会先从它建立熟悉感。它不一定在第一次就能完全读懂，但很适合先反复听、反复读，让“色即是空”等关键句慢慢进入心里。",
    descriptionEn: "The Heart Sutra is short and widely shared, so many beginners use it to build familiarity first. It does not need to be fully understood at once, but it works well as a text you can hear and read repeatedly until a few key lines begin to land.",
  },
  {
    titleZh: "《阿弥陀经》",
    titleEn: "Amitabha Sutra",
    fitZh: "适合想从净土愿行、念佛和较温和的阅读入口开始的人。",
    fitEn: "A gentle starting point if you feel drawn toward Pure Land aspiration and recitation practice.",
    descriptionZh: "如果你更容易通过愿心、称名和安住的感觉进入修行，《阿弥陀经》常是很自然的入口。它也很适合和念佛、听诵一起放进日常，先建立安稳而连续的节奏。",
    descriptionEn: "If aspiration, name-recitation, and a calmer devotional tone feel more accessible to you, the Amitabha Sutra is often a natural entry point. It also pairs well with listening and recitation inside a simple daily rhythm.",
  },
  {
    titleZh: "《普门品》",
    titleEn: "Universal Gate Chapter",
    fitZh: "适合当下压力较重、需要从慈悲与依止感进入经典的人。",
    fitEn: "Helpful when life feels heavy and you need to enter scripture through compassion and refuge.",
    descriptionZh: "很多人会从《普门品》感受到经典和现实处境之间的连接，因为它更容易让人把“遇到苦恼时如何安住身心”带回日常。对初学者来说，它常比纯概念性的内容更容易先读进去。",
    descriptionEn: "Many readers feel that the Universal Gate Chapter connects scripture to lived difficulty more directly, especially around staying steady when life feels troubled. For beginners, it can be easier to enter than more abstract material.",
  },
  {
    titleZh: "《金刚经》",
    titleEn: "Diamond Sutra",
    fitZh: "适合已经有一点基础，想继续松动固着看法的人。",
    fitEn: "Often better once you have a little footing and want to loosen rigid views more deeply.",
    descriptionZh: "《金刚经》对很多人很有吸引力，但它常常不像短篇导读那样容易立刻读懂。更稳的方式，通常是先把《心经》或其他较容易进入的经典读熟，再慢慢回到《金刚经》，这样会更容易留下真正的理解。",
    descriptionEn: "The Diamond Sutra attracts many beginners, but it is usually less immediate than shorter gateway texts. A steadier path is to first grow familiar with something gentler, then return to the Diamond Sutra with more patience and context.",
  },
] as const;

const matchingQuestions = [
  {
    titleZh: "如果你最想先建立方向",
    titleEn: "If your first need is orientation",
    descriptionZh: "可以先从《心经》或配套导读开始，让自己先熟悉佛法常见词汇，再决定要不要继续向更深的义理推进。",
    descriptionEn: "Begin with the Heart Sutra or a paired guide so basic buddhist language becomes more familiar before you push toward deeper doctrine.",
  },
  {
    titleZh: "如果你更想让心安定下来",
    titleEn: "If steadiness matters most right now",
    descriptionZh: "《阿弥陀经》或《普门品》通常更容易和听诵、念佛、短时安住接在一起，比较适合先把节奏放进生活。",
    descriptionEn: "The Amitabha Sutra or Universal Gate Chapter often connect more naturally with listening, recitation, and brief moments of steadiness inside ordinary life.",
  },
  {
    titleZh: "如果你已经读过一点，想再往前走",
    titleEn: "If you already have a little familiarity and want to continue",
    descriptionZh: "这时再回到《金刚经》或其他更需要反复思惟的经典，通常会比一开始硬读更容易真正进入。",
    descriptionEn: "This is often the better moment to return to the Diamond Sutra or other texts that require slower reflection instead of forcing them too early.",
  },
] as const;

const readingRhythm = [
  {
    titleZh: "先听一遍，先熟悉语气和节奏",
    titleEn: "Listen once before trying to master the page",
    descriptionZh: "先通过听诵建立一点亲近感，再去看文字，通常比一上来就埋头读更轻一些。Fabushi 更适合承接这个阶段的听诵、提醒和回看。",
    descriptionEn: "Listening first can create a sense of familiarity before you face the written text. Fabushi fits well on this listening, reminder, and return-to-it side of the rhythm.",
  },
  {
    titleZh: "再读一小段，不急着一次全懂",
    titleEn: "Read only a short section instead of forcing total understanding",
    descriptionZh: "初学者最容易挫败的，不是读得少，而是期待第一次就把一整部经典弄懂。先读一段、抓住一句、留一个问题，反而更容易继续下去。",
    descriptionEn: "Beginners usually suffer more from expecting instant total understanding than from reading too little. One short section, one line that lands, and one living question is already enough for today.",
  },
  {
    titleZh: "最后记下一点真正触动自己的意思",
    titleEn: "Leave one small note about what truly stayed with you",
    descriptionZh: "不需要做很重的笔记，只要留下一句今天真正让你安静下来、或改变看法的话，佛经学习就更容易从纸面回到生活里。",
    descriptionEn: "No heavy note-taking is required. One line that calmed you or shifted your view is enough to let the sutra move from the page back into life.",
  },
] as const;

const commonMistakes = [
  {
    titleZh: "把“推荐书单”当成固定标准答案",
    titleEn: "Treating a recommendation list like a fixed universal answer",
    descriptionZh: "不同人进入佛法的因缘和问题并不一样，所以“先读什么佛经”更像是在帮你找入口，而不是规定每个人都必须按同一顺序走。",
    descriptionEn: "People enter buddhadharma through different conditions and questions, so a recommendation list should help you find an entry point rather than force one identical sequence on everyone.",
  },
  {
    titleZh: "一开始就追求读很多、读很深",
    titleEn: "Trying to read too much or too deeply right away",
    descriptionZh: "经文学习如果一开始就太重，很容易只剩收藏和焦虑。先把最轻的节奏养出来，再慢慢扩展，通常更可靠。",
    descriptionEn: "When scripture study becomes too heavy too early, it often turns into saved links and pressure. It is usually better to first grow the lightest living rhythm and expand later.",
  },
  {
    titleZh: "把看不懂当成不能开始",
    titleEn: "Treating partial understanding as a reason not to begin",
    descriptionZh: "很多经典本来就需要慢慢熟悉。看不懂并不等于不适合开始，只是说明现在更适合从较短的内容、导读和听诵先进入。",
    descriptionEn: "Many sutras are meant to be grown into slowly. Not understanding everything does not mean you should not begin. It often just means you need a shorter text, a guide, or listening as the first doorway.",
  },
] as const;

const relatedPaths = [
  {
    href: "/sutra-guide",
    labelZh: "佛经导读",
    labelEn: "Sutra Guide",
    titleZh: "先回到更完整的佛经入门地图。",
    titleEn: "Return to the broader beginner map for sutra study.",
    descriptionZh: "如果你想先看佛经学习的整体脉络，再决定选哪一部经典开始，这一页会更适合先打开。",
    descriptionEn: "Open this first if you want the broader map of sutra study before choosing a first text.",
  },
  {
    href: "/sutra-listening",
    labelZh: "听诵和读经怎么配合",
    labelEn: "Listening and Reading",
    titleZh: "选好起点之后，再把听诵和阅读的关系理清。",
    titleEn: "Once you have a first text in mind, clarify how listening and reading should work together.",
    descriptionZh: "如果你已经想从某一部经典开始，但卡在经文听诵能不能代替阅读、怎样把两者接起来，这一页会更具体。",
    descriptionEn: "This page is more specific if you already have a first text in mind but feel stuck on whether listening can replace reading and how the two should connect.",
  },
  {
    href: "/start-learning-buddhism",
    labelZh: "学佛从哪里开始",
    labelEn: "Where to Begin",
    titleZh: "把经典阅读放回更完整的入门顺序里。",
    titleEn: "Put scripture back into the wider beginner sequence.",
    descriptionZh: "如果你还在判断自己应该先读经、先禅修，还是先建立日常节奏，这一页会更适合继续往下看。",
    descriptionEn: "If you are still deciding whether scripture, meditation, or a daily rhythm should come first, this page helps frame that choice.",
  },
  {
    href: "/buddhadharma",
    labelZh: "佛法入门",
    labelEn: "Dharma Basics",
    titleZh: "先回到更完整的学佛入门地图。",
    titleEn: "Return to the broader beginner map for buddhadharma.",
    descriptionZh: "如果你还在分辨佛法、经典、禅修和日常实践的关系，这一页会更适合先建立整体感。",
    descriptionEn: "Open this if you still need the wider map of buddhadharma, scripture, meditation, and daily life.",
  },
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "把读经、听诵和日常修行重新接回同一条路径。",
    titleEn: "Reconnect sutra reading, listening, and daily practice inside one path.",
    descriptionZh: "如果你已经开始读经，下一步想知道怎样和禅修、念佛、记录配合，这一页更适合继续往下走。",
    descriptionEn: "If you have already started reading and want to know how it can work with meditation, recitation, and notes, this is the better next page.",
  },
  {
    href: "/download",
    labelZh: "下载入口",
    labelEn: "Download",
    titleZh: "把听诵、提醒和记录放进日常。",
    titleEn: "Bring listening, reminders, and notes into daily life.",
    descriptionZh: "准备借助 Fabushi 承接经文听诵、修行提醒和简单记录时，可以直接查看下载入口。",
    descriptionEn: "If you are ready to use Fabushi for scripture listening, reminders, and simple notes, go straight to the download page.",
  },
] as const;

const faqItems = [
  {
    questionZh: "初学者一定要先从《心经》开始吗？",
    questionEn: "Does every beginner need to start with the Heart Sutra?",
    answerZh: "不一定。《心经》确实是很多人会先接触的短篇经典，但它不是唯一入口。如果你更容易从愿心、念佛或慈悲观照进入，《阿弥陀经》或《普门品》也可能更适合你当下的起点。",
    answerEn: "Not necessarily. The Heart Sutra is a common short entry point, but it is not the only one. If devotion, recitation, or compassion feel more accessible, the Amitabha Sutra or Universal Gate Chapter may fit your present starting point better.",
  },
  {
    questionZh: "《金刚经》适不适合第一部就读？",
    questionEn: "Is the Diamond Sutra a good very first sutra?",
    answerZh: "有些人会直接从《金刚经》开始，但对多数初学者来说，先从更短、更容易反复听读的经典进入，通常会更稳。等有一点熟悉感后，再回到《金刚经》，往往更容易读进去。",
    answerEn: "Some readers do begin there, but for many beginners it is steadier to enter through a shorter text that is easier to hear and revisit. Returning to the Diamond Sutra after some familiarity often works better.",
  },
  {
    questionZh: "一开始需要同时读很多部佛经吗？",
    questionEn: "Do I need to read many sutras at the beginning?",
    answerZh: "通常不需要。先选一两部和自己当前问题更贴近的经典，反复听、反复读、反复想，会比同时摊开很多部更容易真正留下来。",
    answerEn: "Usually not. One or two sutras that match your present question, revisited through listening, reading, and reflection, often stay more deeply than many opened at once.",
  },
  {
    questionZh: "如果现在看不懂佛经，是不是应该先放下？",
    questionEn: "If I do not understand much yet, should I stop reading sutras for now?",
    answerZh: "不必。更稳妥的做法通常是换成更短的经典、配合导读和听诵，先抓住一两个能读进去的句子。看不懂全部很常见，不代表你不能开始。",
    answerEn: "Not at all. A steadier move is usually to choose a shorter text, add a guide, and listen alongside it so one or two lines can truly land. Partial understanding is common and does not mean you should stop.",
  },
  {
    questionZh: "Fabushi 在佛经入门阶段最适合帮助什么？",
    questionEn: "What is Fabushi most useful for at the beginner sutra stage?",
    answerZh: "它更适合作为经文听诵、提醒和简单记录的辅助工具，帮助你把经典学习接进日常节奏，而不是只在偶尔想起时才接触佛经。",
    answerEn: "It works best as a support tool for scripture listening, reminders, and short notes so sutra study can live inside a daily rhythm instead of happening only occasionally.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "初学者先读什么佛经",
    "初学者佛经推荐",
    "学佛先读什么经",
    "佛经入门",
    "心经",
    "阿弥陀经",
    "普门品",
    "金刚经",
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

export default function BeginnerSutraRecommendationsPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "CollectionPage",
        name: "初学者先读什么佛经",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: ["初学者佛经推荐", "佛经入门", "学佛先读什么经"],
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
            name: "佛经导读",
            item: siteUrl("/sutra-guide"),
          },
          {
            "@type": "ListItem",
            position: 4,
            name: "初学者先读什么佛经",
            item: pageUrl,
          },
        ],
      },
      {
        "@type": "ItemList",
        name: "初学者常见佛经入口",
        itemListElement: sutraRecommendations.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.titleZh,
          description: item.fitZh,
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
            <LocalizedText zh="初学者佛经推荐" en="Beginner Sutra Picks" />
          </p>
          <h1>
            <LocalizedText
              zh="先读什么佛经，不必靠“最难”来决定，而要看哪一部更能让你真正开始。"
              en="Your first sutra does not need to be the hardest one. It needs to be the one that actually helps you begin."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="如果你正在想初学者先读什么佛经，更稳妥的答案通常不是一张固定书单，而是先看自己当下更需要方向、安定，还是慈悲与愿心，再选更容易反复听读的一部经典开始。"
              en="If you are wondering which sutra to read first, the steadier answer is usually not a rigid list but a better match between your present need and a text you can actually return to again and again."
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
              zh="初学者最容易卡住的，往往不是没有经典可读，而是一下子面对太多入口。"
              en="The beginner difficulty is usually not a lack of texts, but too many doorways arriving at once."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="很多人刚想读佛经时，第一反应是找一份“最权威”的推荐书单。可真正会让人停下来的，往往不是书单不够完整，而是一下子面对太多经名、太多版本、太多期待，反而不知道第一步该放在哪里。于是常见的结果是：收藏了很多，真正反复读进去的却很少。"
              en="When people first want to read sutras, many begin by searching for the most authoritative recommendation list. What usually blocks them is not that the list is incomplete, but that too many names, editions, and expectations arrive at once. The common result is clear: a lot gets saved, and very little is actually revisited."
            />
          </p>
          <p>
            <LocalizedText
              zh="比较稳妥的方式，是先不急着求多，而是先看自己现在最需要什么。有人是想先接触佛法核心词汇，有人是想先让心安定下来，有人则是想从慈悲、愿心和日常依止感进入。问题一旦更清楚，适合自己的第一部经典通常也会更容易浮出来。"
              en="A steadier way is to stop chasing quantity first and ask what you need most right now. Some want to meet the core language of buddhadharma, some want a calmer heart, and some need to enter through compassion, aspiration, and a felt sense of refuge. Once the living question is clearer, the first sutra usually becomes clearer too."
            />
          </p>
          <p>
            <LocalizedText
              zh="传统学习常会把闻、思、修看成相续的过程。对初学者来说，这并不意味着一开始就要把很多经都读完，而是可以先通过听诵建立熟悉感，再读一小段原文或导读，最后留下一点真正触动自己的意思。Fabushi 更适合承接这条路径里的听诵、提醒和简短记录，让佛经学习不只停留在偶尔想起。"
              en="Traditional learning often treats hearing, reflection, and practice as a living sequence. For beginners, that does not mean finishing many texts at once. It can begin with listening for familiarity, reading a short section or guide, and leaving one idea that truly stayed with you. Fabushi fits best on the listening, reminder, and short-note side of that path."
            />
          </p>
        </div>
      </section>

      <section className="band alt feature-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="选择原则" en="How to Choose" />
          </p>
          <h2>
            <LocalizedText
              zh="先把“初学者先读什么佛经”的三个判断放稳。"
              en="Set three basic judgments in place before you choose a first sutra."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {selectionPrinciples.map((item) => (
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
            <LocalizedText zh="常见入口" en="Common First Sutras" />
          </p>
          <h2>
            <LocalizedText
              zh="把很多初学者常会先接触的四个经典入口放在一起看。"
              en="See four sutra doorways that many beginners commonly meet first."
            />
          </h2>
        </div>
        <div className="editorial-list">
          {sutraRecommendations.map((item) => (
            <article key={item.titleEn} className="editorial-row static-row">
              <span>
                <LocalizedText zh={item.titleZh} en={item.titleEn} />
              </span>
              <div>
                <strong>
                  <LocalizedText zh={item.fitZh} en={item.fitEn} />
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
            <LocalizedText zh="按问题选" en="Choose by Question" />
          </p>
          <h2>
            <LocalizedText
              zh="先看自己当下最想解决什么，再决定哪一部更适合作为起点。"
              en="Decide what you most need right now before choosing the better starting text."
            />
          </h2>
        </div>
        <div className="compare-grid">
          {matchingQuestions.map((item) => (
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
            <LocalizedText zh="阅读节奏" en="Reading Rhythm" />
          </p>
          <h2>
            <LocalizedText
              zh="把第一部经典的节奏定轻一点，反而更容易真的读下去。"
              en="Keep the rhythm around your first sutra light enough that it can actually stay."
            />
          </h2>
        </div>
        <div className="path-grid">
          {readingRhythm.map((item) => (
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
              zh="先避开几个会让佛经入门变重的误区。"
              en="Avoid the patterns that make sutra study heavier than it needs to be."
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
              zh="把这张问题页接回更完整的佛经学习和修行路径。"
              en="Use this question page as a bridge back into the wider sutra and practice paths."
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
              zh="先回答“初学者先读什么佛经”最容易继续追问的几个问题。"
              en="Answer the questions that usually come right after asking which sutra to begin with."
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
          <a className="secondary-action" href={siteHref("/sutra-guide")}>
            <LocalizedText zh="返回佛经导读" en="Back to Sutra Guide" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
