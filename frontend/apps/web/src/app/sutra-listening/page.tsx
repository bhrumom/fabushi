import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/sutra-listening");
const pageTitle = `经文听诵能代替读经吗 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理经文听诵能不能代替自己读经、听经和读经有什么区别，以及怎样把听诵、短段阅读和简单记录接进稳定的日常节奏。";

const listeningJudgments = [
  {
    titleZh: "听诵先帮助熟悉，阅读更帮助停下来理解",
    titleEn: "Listening builds familiarity while reading deepens understanding",
    descriptionZh: "很多初学者先通过听诵接近经典，是因为声音和节奏更容易先留下来；真正要把一句经文读懂、读进生活里，通常还是需要在安静的时候停下来自己读一小段。",
    descriptionEn: "Many beginners first approach scripture through listening because sound and rhythm stay with them more easily. To let a line of scripture truly land in life, most people still need a quieter moment to read a short section for themselves.",
  },
  {
    titleZh: "两者最好互相配合，不互相替代",
    titleEn: "The two work best together instead of replacing each other",
    descriptionZh: "经文听诵适合在通勤、步行和固定功课前后帮助自己保持熏习；阅读更适合在较安静的时间里停下来理解义理。把两者接起来，通常会比只靠其中一种更稳。",
    descriptionEn: "Sutra listening fits commuting, walking, and the edges of a daily routine, while reading works better in quieter moments for meaning and reflection. Connecting the two is usually steadier than relying on only one.",
  },
  {
    titleZh: "先让节奏活下来，比一开始求全更重要",
    titleEn: "Keeping a rhythm alive matters more than getting everything right immediately",
    descriptionZh: "初学者最容易受挫的，不是今天读得少，而是希望第一次就把一部经典完全弄懂。先听一遍、读一小段、留一个触动自己的句子，往往更容易真正继续下去。",
    descriptionEn: "Beginners usually get discouraged not because they read too little today, but because they expect to understand an entire text immediately. Listening once, reading a short section, and leaving one line that truly stayed often creates a path you can keep.",
  },
] as const;

const practiceRhythm = [
  {
    titleZh: "第一步：先用听诵建立熟悉感",
    titleEn: "Step 1: Use listening to build familiarity first",
    descriptionZh: "如果今天很难完整坐下来读，可以先听一遍经文，让语气、节奏和关键句先进入耳根。对初学者来说，这一步常常比直接逼自己读很多更轻一些。",
    descriptionEn: "If it is hard to sit down and read fully today, start by listening once so the tone, rhythm, and key lines begin to settle. For beginners, this is often gentler than forcing a long reading session immediately.",
  },
  {
    titleZh: "第二步：再读一小段，不急着一次全懂",
    titleEn: "Step 2: Read a short section without forcing total understanding",
    descriptionZh: "听完以后，再回到原文或导读里读一小段，先抓住一两句自己真正能读进去的话。看不懂全部很常见，不代表你不适合从经典开始。",
    descriptionEn: "After listening, return to the text or a guide and read only a short section. Hold onto one or two lines that actually land. Not understanding everything is common and does not mean scripture is the wrong doorway for you.",
  },
  {
    titleZh: "第三步：最后留一句记录，把经典带回生活",
    titleEn: "Step 3: Leave one note that brings the text back into life",
    descriptionZh: "不需要写很重的笔记。只要记下今天哪一句最让你安静下来、最像在回答眼前的处境，佛经学习就会更容易从纸面回到现实生活。",
    descriptionEn: "You do not need heavy notes. One line about what calmed you or seemed to speak to your present life is enough to let sutra study return from the page into ordinary living.",
  },
] as const;

const howToSteps = [
  {
    nameZh: "先听一遍，让经典先熟起来",
    nameEn: "Listen once so scripture becomes familiar first",
    textZh: "如果今天很难完整坐下来读，可以先听一遍经文，让语气、节奏和关键句先进入耳根。先建立熟悉感，通常比一开始就逼自己读很多更稳。",
    textEn: "If it is hard to sit down and read fully today, begin by listening once so the tone, rhythm, and key lines settle first. Building familiarity is usually steadier than forcing a long reading session immediately.",
  },
  {
    nameZh: "再读一小段，只抓住一两句真正读进去的话",
    nameEn: "Read a short section and hold onto one or two lines",
    textZh: "听完以后，再回到原文或导读里读一小段，先抓住一两句自己真正能读进去的话。看不懂全部很常见，不代表你不适合从经典开始。",
    textEn: "After listening, return to the text or a guide and read only a short section. Hold onto one or two lines that truly land. Partial understanding is common and does not mean scripture is the wrong doorway for you.",
  },
  {
    nameZh: "最后留一句记录，把今天听到的内容接回生活",
    nameEn: "Leave one note that brings today’s listening back into life",
    textZh: "不需要写很重的笔记。只要记下今天哪一句最让你安静下来、最像在回答眼前的处境，佛经学习就更容易从纸面回到现实生活。",
    textEn: "You do not need heavy notes. Just record which line calmed you or seemed to answer your present situation so sutra study can return from the page into ordinary living.",
  },
] as const;

const conceptBlocks = [
  {
    titleZh: "熏习",
    titleEn: "Familiarization",
    descriptionZh: "经文听诵最直接的作用，常常不是立刻讲清所有义理，而是让经典语言在心里慢慢熟起来。熟悉感一旦起来，后面的阅读通常也会轻一点。",
    descriptionEn: "One of the most direct gifts of listening is not instant explanation, but letting scriptural language become more familiar inside you. Once that familiarity grows, later reading usually becomes lighter too.",
  },
  {
    titleZh: "义理",
    titleEn: "Meaning and view",
    descriptionZh: "自己阅读的价值，往往在于能停下来想：这句话到底在说什么，和我现在的烦恼、发心、做法有什么关系。这个过程更像慢慢消化，而不是快速刷完。",
    descriptionEn: "The value of reading often lies in being able to pause and ask what a line is really saying, and how it relates to your present confusion, aspiration, and conduct. That process is closer to digestion than speed.",
  },
  {
    titleZh: "闻思修",
    titleEn: "Hear, reflect, practice",
    descriptionZh: "传统学习常把闻、思、修看成相续的过程。先通过听诵和阅读接触经典，再反复思惟，最后回到日常生活里练习，经典才不只停留在声音或文字上。",
    descriptionEn: "Traditional learning often treats hearing, reflection, and practice as a living sequence. You encounter the text through listening and reading, reflect on it, then return it to everyday life so the sutra does not remain only sound or words.",
  },
] as const;

const commonMistakes = [
  {
    titleZh: "把听诵当成完全不用再读经",
    titleEn: "Treating listening as a complete replacement for reading",
    descriptionZh: "听诵很有帮助，但如果一直不回到文字，很容易只留下熟悉感，却少了停下来理解和思惟的空间。",
    descriptionEn: "Listening is deeply useful, but if you never return to the text, familiarity can grow while the space for understanding and reflection stays thin.",
  },
  {
    titleZh: "把读经变成一次就要全部看懂",
    titleEn: "Turning reading into a demand for total understanding in one sitting",
    descriptionZh: "经典本来就需要反复接近。初学者先抓住一句、一个问题、一个方向，通常比逼自己一次全部弄通更容易走得久。",
    descriptionEn: "Scripture is often meant to be approached repeatedly. Holding one line, one question, and one direction usually lasts longer than forcing total mastery in a single sitting.",
  },
  {
    titleZh: "只在零散空档里听，却没有固定回看时间",
    titleEn: "Listening only in scattered moments without a return-to-it time",
    descriptionZh: "如果听诵只留在碎片时间，很容易听过就过去。更稳妥的方式，是隔一两天回到同一段内容，再读一小段，让声音和文字接起来。",
    descriptionEn: "When listening stays only inside scattered spare moments, it can disappear as quickly as it arrives. A steadier move is to return to the same passage after a day or two and read a little so sound and text connect.",
  },
] as const;

const relatedPaths = [
  {
    href: "/sutra-guide",
    labelZh: "佛经导读",
    labelEn: "Sutra Guide",
    titleZh: "先回到更完整的佛经入门地图。",
    titleEn: "Return to the broader beginner map for sutra study.",
    descriptionZh: "如果你想先看佛经学习整体脉络，再理解听诵和阅读在其中的位置，这一页更适合先打开。",
    descriptionEn: "Open this first if you want the broader map of sutra study before locating listening and reading inside it.",
  },
  {
    href: "/beginner-sutra-recommendations",
    labelZh: "初学者佛经推荐",
    labelEn: "Beginner Sutra Picks",
    titleZh: "先把“读哪一部经典开始”单独理清。",
    titleEn: "Clarify which scripture to begin with before shaping the rhythm around it.",
    descriptionZh: "如果你还在想《心经》《阿弥陀经》《普门品》还是《金刚经》更适合作为起点，这一页会更具体。",
    descriptionEn: "If you are still choosing between gateway texts such as the Heart Sutra, Amitabha Sutra, Universal Gate Chapter, or Diamond Sutra, this page goes further.",
  },
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "把听诵、阅读、禅修和记录放回同一条路径。",
    titleEn: "Place listening, reading, meditation, and notes back into one path.",
    descriptionZh: "如果你想知道经文听诵怎样和禅修、念佛、日常记录互相配合，这一页更适合继续往下看。",
    descriptionEn: "This is the better next page if you want to see how listening works with meditation, recitation, and daily notes.",
  },
  {
    href: "/daily-practice",
    labelZh: "日常功课怎么安排",
    labelEn: "Daily Practice",
    titleZh: "把碎片时间里的听诵慢慢接回固定功课。",
    titleEn: "Turn scattered listening into a steadier daily rhythm.",
    descriptionZh: "如果你已经在听经，但卡在晨起、白天和晚间该怎么安排，这一页会更具体。",
    descriptionEn: "If you already listen to sutras but feel stuck on how to place it across morning, daytime, and evening, this page is more concrete.",
  },
  {
    href: "/download",
    labelZh: "下载入口",
    labelEn: "Download",
    titleZh: "把听诵、提醒和简单记录放进日常。",
    titleEn: "Bring listening, reminders, and short notes into daily life.",
    descriptionZh: "准备借助 Fabushi 承接经文听诵、提醒和简单记录时，可以直接查看下载入口。",
    descriptionEn: "Go straight to the download page if you are ready to use Fabushi for sutra listening, reminders, and simple notes.",
  },
] as const;

const faqItems = [
  {
    questionZh: "经文听诵能代替自己读经吗？",
    questionEn: "Can sutra listening replace reading the text yourself?",
    answerZh: "通常不能完全代替。听诵更适合帮助自己熟悉经文、保持熏习和建立节奏，自己阅读更有助于停下来理解义理。多数初学者更稳的方式，是让两者互相配合，而不是只靠其中一种。",
    answerEn: "Usually not completely. Listening helps familiarity, continuity, and rhythm, while reading helps meaning land more clearly. For most beginners, the steadier path is to let the two support each other instead of relying on only one.",
  },
  {
    questionZh: "听经和读经，初学者应该先从哪一个开始？",
    questionEn: "Should a beginner start with listening or with reading?",
    answerZh: "如果现在更难坐下来读，可以先从听诵建立熟悉感，再回到文字里读一小段。如果已经能安静下来，也可以直接从短段阅读开始，再用听诵帮助自己维持连续。关键不是固定顺序，而是找到自己更容易真正开始的入口。",
    answerEn: "If sitting down to read still feels difficult, start with listening for familiarity and then return to a short section of text. If quiet reading already feels possible, begin there and use listening to maintain continuity. The key is not a rigid order but the doorway that helps you truly begin.",
  },
  {
    questionZh: "只在通勤时听经，会不会太浅？",
    questionEn: "Is listening only during a commute too shallow to matter?",
    answerZh: "不一定。通勤时听经本身就能帮助建立熟悉感和连续性，只是更稳妥的做法，是隔一两天回到同一段内容，再读一小段或留一句记录，让它不只停留在背景声音里。",
    answerEn: "Not necessarily. Commute listening can already build familiarity and continuity. What helps more is to revisit the same passage after a day or two, read a little, or leave a short note so it does not remain background sound only.",
  },
  {
    questionZh: "看不懂佛经的时候，听诵还有意义吗？",
    questionEn: "Does listening still matter when I do not understand much of the text yet?",
    answerZh: "有意义。很多初学者一开始并不是先靠理解全部进入经典，而是先通过声音、节奏和反复接触建立亲近感，再慢慢把理解补上。听诵在这个阶段，常常正是帮助自己不要一下子退开的方式。",
    answerEn: "Yes. Many beginners do not enter scripture through total understanding at first, but through sound, rhythm, and repeated contact that gradually build familiarity. At that stage, listening often helps you stay close instead of pulling away too quickly.",
  },
  {
    questionZh: "Fabushi 在经文听诵这一页最适合帮助什么？",
    questionEn: "What is Fabushi most useful for in a sutra listening rhythm?",
    answerZh: "它更适合作为经文听诵、提醒和简单记录的辅助工具，帮助你把经典接进日常节奏，而不是只在偶尔想起时才接触经文。理解义理和长期学习，仍然需要回到经典、导读和持续实践本身。",
    answerEn: "It works best as a support tool for sutra listening, reminders, and short notes so scripture can live inside a daily rhythm instead of appearing only occasionally. Deeper understanding still depends on texts, guides, and sustained practice.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "经文听诵",
    "听经和读经的区别",
    "听诵能代替读经吗",
    "诵经和读经怎么配合",
    "佛经入门",
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

export default function SutraListeningPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "经文听诵能代替读经吗",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: ["经文听诵", "听经和读经的区别", "诵经和读经怎么配合"],
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
            name: "经文听诵能代替读经吗",
            item: pageUrl,
          },
        ],
      },
      {
        "@type": "ItemList",
        name: "经文听诵与阅读的三步节奏",
        itemListElement: practiceRhythm.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.titleZh,
          description: item.descriptionZh,
        })),
      },
      {
        "@type": "HowTo",
        name: "经文听诵接回阅读的三步安排",
        description: "先用听诵建立熟悉感，再读一小段原文或导读，最后留一句记录，把经典慢慢接回生活。",
        totalTime: "P1D",
        supply: [
          {
            "@type": "HowToSupply",
            name: "一小段经文听诵或原文",
          },
          {
            "@type": "HowToSupply",
            name: "一句简短记录",
          },
        ],
        tool: [
          {
            "@type": "HowToTool",
            name: "Fabushi 听诵与提醒功能",
          },
        ],
        step: howToSteps.map((item, index) => ({
          "@type": "HowToStep",
          position: index + 1,
          name: item.nameZh,
          text: item.textZh,
          url: `${pageUrl}#listening-rhythm`,
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
            <LocalizedText zh="经文听诵" en="Sutra Listening" />
          </p>
          <h1>
            <LocalizedText
              zh="经文听诵不能完全代替自己读经，但两者接起来，反而更适合初学者真正开始。"
              en="Sutra listening does not fully replace reading, but the two together often help beginners begin more steadily."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="很多人第一次接触佛经时，先是通勤里反复听，后来才慢慢愿意坐下来读。更稳妥的路径，通常不是在听诵和阅读之间二选一，而是先让经典熟起来，再把理解一点点接回生活。"
              en="Many people first meet scripture through repeated listening during ordinary life and only later feel ready to sit down and read. The steadier path is usually not choosing one against the other, but letting scripture become familiar first and then bringing understanding back into life little by little."
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
              zh="初学者最常卡住的，不是听诵有没有用，而是不知道它该怎样和自己读经接起来。"
              en="The beginner difficulty is usually not whether listening matters, but how it should connect with reading."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="很多人一开始接触佛经时，最自然的入口并不是马上坐下来读一整段，而是在路上、做家务或睡前先听一遍经文。声音先留下来，心里会慢慢熟一点。可再往前走时，新的疑问也会出现：如果我已经常常听，是不是就不用再读？如果每次一读就看不懂，是不是说明自己还不适合从经典开始？"
              en="For many people, the most natural first doorway into scripture is not sitting down to read a full passage right away, but listening on the way somewhere, while doing chores, or before sleep. The sound settles first and familiarity grows. Then another question arrives: if I already listen often, do I still need to read? And if reading feels hard, does that mean scripture is not the right beginning?"
            />
          </p>
          <p>
            <LocalizedText
              zh="更稳妥的理解是：经文听诵和自己读经，各自在做不同的工作。听诵更容易帮助自己熟悉经文节奏、维持熏习和把经典留在日常里；阅读更容易帮助自己停下来、回看一两句话、慢慢理解义理。两者不是互相竞争，而是互相接力。"
              en="A steadier understanding is that listening and reading do different kinds of work. Listening helps familiarity, continuity, and keeping scripture inside daily life. Reading helps you pause, revisit one or two lines, and slowly understand the meaning. They are not competing methods, but a relay."
            />
          </p>
          <p>
            <LocalizedText
              zh="传统学习常把闻、思、修看成相续的过程。对初学者来说，可以先通过听诵让经典熟起来，再读一小段、想一小点、留一句真正触动自己的记录。Fabushi 更适合承接这条路径里的听诵、提醒和简单记录，让你不只是在碎片时间里听过，而是真正有机会把经典接进生活。"
              en="Traditional learning often treats hearing, reflection, and practice as a living sequence. For beginners, that can mean listening until the text feels familiar, then reading a short section, reflecting on one small point, and leaving one line that truly stayed. Fabushi fits best on the listening, reminder, and short-note side of that rhythm so scripture can move from spare moments into lived practice."
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
              zh="先把听诵和阅读之间的三个基本判断放稳。"
              en="Set three basic judgments in place before comparing listening and reading."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {listeningJudgments.map((item) => (
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

      <section className="band" id="listening-rhythm">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="三步节奏" en="Three-Step Rhythm" />
          </p>
          <h2>
            <LocalizedText
              zh="把经文听诵和阅读接起来，通常比单独做其中一种更容易留下来。"
              en="Connecting listening and reading usually lasts better than relying on only one of them."
            />
          </h2>
        </div>
        <div className="path-grid">
          {practiceRhythm.map((item) => (
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
              zh="先分清听诵真正帮助的是哪一层，阅读又在补哪一层。"
              en="Clarify which layer listening supports first and what reading adds next."
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
              zh="先避开几个会让经文听诵停在表面的误区。"
              en="Avoid the patterns that keep sutra listening too close to the surface."
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
              zh="把这张问题页接回更完整的佛经学习与修行路径。"
              en="Use this question page as a bridge back into the wider scripture and practice paths."
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
              zh="先回答“经文听诵能不能代替读经”最常继续追问的几个问题。"
              en="Answer the questions that usually follow asking whether listening can replace reading."
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