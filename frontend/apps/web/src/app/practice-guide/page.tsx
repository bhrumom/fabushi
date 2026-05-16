import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/practice-guide");
const pageTitle = `修行方法总览 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理学佛修行可以从哪些方法开始：禅修、经文听诵、阅读、念佛与日常记录如何配合，才能把修行留在生活里。";

const practicePrinciples = [
  {
    titleZh: "先定一条主线，不先把所有方法排满",
    titleEn: "Choose one main line before filling the whole schedule",
    descriptionZh: "初学者最容易累的，不是方法太少，而是一下子把禅修、听诵、阅读、念佛和记录都塞进同一天。先有主线，再加辅助，通常更容易走得久。",
    descriptionEn: "Beginners usually tire out not because there are too few methods, but because meditation, listening, reading, chanting, and tracking all get pushed into the same day at once. Choose one main line first and add support gradually.",
  },
  {
    titleZh: "先让节奏变小，才能让修行留下来",
    titleEn: "Make the rhythm small enough to stay",
    descriptionZh: "每天留五到十分钟的真实练习，往往比偶尔安排很满却无法持续，更能让修行慢慢扎根。",
    descriptionEn: "Five to ten minutes of real daily practice often roots more deeply than occasional heavy routines that never stay alive.",
  },
  {
    titleZh: "让方法彼此配合，而不是彼此竞争",
    titleEn: "Let the methods support each other instead of compete",
    descriptionZh: "听诵可以帮助熟悉经文，阅读帮助理解义理，禅修帮助安定和观照，简单记录帮助保持连续。把它们放在同一条路径里，会比分散地做更稳。",
    descriptionEn: "Listening builds familiarity, reading supports understanding, meditation steadies awareness, and simple notes keep continuity. When these methods support the same path, practice becomes steadier.",
  },
] as const;

const practiceMethods = [
  {
    titleZh: "短时禅修",
    titleEn: "Short meditation",
    descriptionZh: "适合用来安定心念、建立觉察和维持每天都有一点点练习的节奏。对多数初学者来说，先从短时开始会比一开始久坐更实际。",
    descriptionEn: "Useful for steadying the mind, training awareness, and keeping a living daily rhythm. For most beginners, short sessions are a more workable start than long sittings.",
  },
  {
    titleZh: "经文听诵与短段阅读",
    titleEn: "Sutra listening and short reading",
    descriptionZh: "听诵帮助熟悉经文的节奏和语感，阅读帮助停下来理解一点义理。两者交替进行，通常比只靠其中一种更容易留下痕迹。",
    descriptionEn: "Listening helps you become familiar with the rhythm of scripture, while reading helps meaning land more clearly. Alternating the two is often steadier than relying on only one.",
  },
  {
    titleZh: "念佛与持名",
    titleEn: "Name-recitation practice",
    descriptionZh: "对很多人来说，念佛是最容易进入、也最容易放进通勤、步行和日常空档里的修行方法之一。关键不是求多，而是让心念有可回到的地方。",
    descriptionEn: "For many people, name-recitation is one of the easiest methods to bring into commuting, walking, and everyday gaps. The point is not quantity, but giving the mind a place to return.",
  },
  {
    titleZh: "简短记录与回顾",
    titleEn: "Short notes and review",
    descriptionZh: "每天只记今天练了什么、哪里容易散乱、哪一句经文最有触动，已经足够帮助自己保持连续，也更容易看见习惯如何慢慢变化。",
    descriptionEn: "A short note about what you practiced, where attention scattered, or which line of scripture stayed with you is already enough to support continuity and reveal change over time.",
  },
] as const;

const weeklyRhythm = [
  {
    titleZh: "第一步：先定一个最轻的每日动作",
    titleEn: "Step 1: Set the lightest daily action first",
    descriptionZh: "可以是每天五分钟禅修、听一段经文，或念佛几分钟。先让这一个动作稳定下来，再决定要不要加别的。",
    descriptionEn: "This can be five minutes of meditation, one short passage of listening, or a few minutes of recitation. Let one action stabilize before adding more.",
  },
  {
    titleZh: "第二步：再配一个辅助动作",
    titleEn: "Step 2: Add one supporting action",
    descriptionZh: "主线稳定后，再加一个能互相支撑的方法，例如禅修后读一小段导读，或听诵后留一句记录。辅助动作不需要很重，只要能帮助主线留住。",
    descriptionEn: "Once the main line is steady, add one supporting method such as reading a short guide after meditation or leaving one note after listening. The support action should stay light and help the main line remain alive.",
  },
  {
    titleZh: "第三步：一周后再回头微调",
    titleEn: "Step 3: Adjust only after a week",
    descriptionZh: "一开始不需要天天换方法。先做一周，再看自己更适合继续加阅读、加念佛，还是把原来的节奏再简化一点。",
    descriptionEn: "There is no need to change methods every day at the beginning. Practice for a week first, then decide whether to add reading, recitation, or simplify the rhythm even more.",
  },
] as const;

const relatedPaths = [
  {
    href: "/start-learning-buddhism",
    labelZh: "学佛从哪里开始",
    labelEn: "Where to Begin",
    titleZh: "先把学佛的第一步放轻一点、放清楚一点。",
    titleEn: "Make the first step into buddhadharma lighter and clearer.",
    descriptionZh: "如果你现在最卡的是不知道先从哪一条路开始，先回到这页会更合适。",
    descriptionEn: "Return here first if your main difficulty is still deciding where to begin.",
  },
  {
    href: "/daily-practice",
    labelZh: "日常功课怎么安排",
    labelEn: "Daily Practice",
    titleZh: "把晨起、白天和晚间的轻量功课慢慢接起来。",
    titleEn: "Connect a lighter routine across morning, daytime, and evening.",
    descriptionZh: "如果你已经确定要开始练习，但卡在功课怎么安排、怎么做得更稳，这一页会更具体。",
    descriptionEn: "If you already know you want to practice but feel stuck on arranging a routine that can last, this page is more concrete.",
  },
  {
    href: "/buddhadharma",
    labelZh: "佛法入门",
    labelEn: "Dharma Basics",
    titleZh: "先看更完整的学佛入门地图。",
    titleEn: "Return to the broader beginner map for buddhadharma.",
    descriptionZh: "如果你还在分辨佛法、修行、经典和日常实践之间的关系，这一页会更适合先打开。",
    descriptionEn: "Open this if you still need the wider map of buddhadharma, practice, scripture, and daily life.",
  },
  {
    href: "/meditation",
    labelZh: "禅修入门",
    labelEn: "Meditation Guide",
    titleZh: "把禅修变成短时、稳定、可持续的日常练习。",
    titleEn: "Turn meditation into a short, steady, sustainable daily rhythm.",
    descriptionZh: "如果你已经确定想先从禅修开始，这一页会给出更具体的落地方式。",
    descriptionEn: "If you already know you want meditation to be the first method, this page goes into more practical detail.",
  },
  {
    href: "/sutra-guide",
    labelZh: "佛经导读",
    labelEn: "Sutra Guide",
    titleZh: "把听诵、阅读和理解义理重新接回修行。",
    titleEn: "Reconnect listening, reading, and understanding to practice.",
    descriptionZh: "如果你更想从经典进入修行，这一页会更适合继续往下看。",
    descriptionEn: "If scripture feels like the right doorway into practice, this is the better next page.",
  },
  {
    href: "/download",
    labelZh: "下载入口",
    labelEn: "Download",
    titleZh: "把听诵、提醒和记录放进日常。",
    titleEn: "Bring listening, reminders, and notes into daily life.",
    descriptionZh: "准备借助 Fabushi 承接经文听诵、禅修和简单记录时，可以直接查看下载入口。",
    descriptionEn: "When you are ready to use Fabushi for listening, meditation, and simple notes, go straight to the download page.",
  },
] as const;

const faqItems = [
  {
    questionZh: "学佛修行是不是方法越多越好？",
    questionEn: "Is it better to practice more methods from the beginning?",
    answerZh: "通常不是。对初学者来说，先定一条能留下来的主线，再慢慢增加辅助方法，往往比同时做很多更容易持续，也更容易真正看见变化。",
    answerEn: "Usually not. For beginners, one sustainable main line plus gradual support methods is often steadier than trying to do everything at once.",
  },
  {
    questionZh: "初学者应该先禅修、先念佛，还是先读经？",
    questionEn: "Should a beginner start with meditation, recitation, or reading?",
    answerZh: "更重要的是看你当下最需要什么。如果需要先安定心念，可以先从短时禅修开始；如果需要更容易进入的节奏，念佛或听诵也可以先成为主线；如果你更需要理解方向，可以先从导读和短段阅读开始。",
    answerEn: "The better question is what you need most right now. Meditation can come first if you need steadiness, recitation or listening can come first if you need an easier rhythm, and reading can come first if you need clearer direction.",
  },
  {
    questionZh: "日常功课一定要安排很多吗？",
    questionEn: "Does a daily routine need to be heavy to count?",
    answerZh: "不需要。很多人真正能留下来的修行，反而是很轻的节奏，例如每天几分钟禅修、听一段经文、念几分钟佛号，再留下一点记录。轻一点，往往更容易真做下去。",
    answerEn: "No. Many routines that truly stay alive are actually very light: a few minutes of meditation, one short scripture passage, a few minutes of recitation, and one small note. Lighter often means more real.",
  },
  {
    questionZh: "听诵、阅读和禅修能不能放在一起？",
    questionEn: "Can listening, reading, and meditation belong to the same routine?",
    answerZh: "可以，但更适合有主次。先定一条主线，再让其他方法做辅助，会比每一样都平均分配更稳。很多初学者会用听诵熟悉经文，用短时禅修安定身心，再用简单阅读或记录帮助理解。",
    answerEn: "Yes, but it helps to give them different weights. Choose one main line and let the others support it. Many beginners use listening for familiarity, short meditation for steadiness, and a little reading or note-taking for understanding.",
  },
  {
    questionZh: "Fabushi 在修行方法总览里最适合扮演什么角色？",
    questionEn: "What role does Fabushi play in a beginner practice routine?",
    answerZh: "它更适合作为经文听诵、禅修提醒、修行记录和保持连续性的辅助工具，帮助你把练习接进生活，而不是只停留在偶尔想起时才做。",
    answerEn: "It works best as a support tool for scripture listening, meditation reminders, practice notes, and continuity so practice can live inside everyday life instead of appearing only occasionally.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "修行方法",
    "学佛修行",
    "佛教修行方法",
    "初学者怎么修行",
    "日常功课",
    "念佛",
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

export default function PracticeGuidePage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "CollectionPage",
        name: "修行方法总览",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: ["修行方法", "学佛修行", "日常功课"],
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
            name: "修行方法总览",
            item: pageUrl,
          },
        ],
      },
      {
        "@type": "ItemList",
        name: "初学者常见修行方法",
        itemListElement: practiceMethods.map((item, index) => ({
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
            <LocalizedText zh="修行方法总览" en="Practice Guide" />
          </p>
          <h1>
            <LocalizedText
              zh="先把修行方法拆成几条能留下来的路径，再慢慢接回日常生活。"
              en="Break practice into paths that can actually stay, then let them return to daily life."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="禅修、经文听诵、阅读、念佛和简单记录，并不是彼此竞争的方法。更关键的是先找到一条主线，再让其他做辅助。"
              en="Meditation, scripture listening, reading, recitation, and short notes do not need to compete with each other. The real task is to choose one main line and let the others support it."
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
              zh="修行方法真正难的，往往不是没有方法，而是刚开始就把自己压得太重。"
              en="The real difficulty is usually not a lack of methods, but beginning under too much weight."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="很多人刚接触佛法时，第一反应是想把禅修、听诵、念佛、读经和日常功课一次排满，仿佛这样才算认真。可真正的问题往往不是不够认真，而是节奏太重，结果三天后就停了。对初学者来说，修行更像是一条要慢慢养出来的生活路径，而不是一张第一天就必须填满的清单。"
              en="When people first meet buddhadharma, many try to pack meditation, listening, recitation, reading, and daily practice into the same schedule at once, as if that proves sincerity. The real problem is usually not a lack of sincerity, but a rhythm that is too heavy to survive. For beginners, practice is more like a way of living that grows slowly than a checklist to complete on day one."
            />
          </p>
          <p>
            <LocalizedText
              zh="比较稳妥的做法，是先让自己每天有一个最轻但真实的动作。可以是坐几分钟禅修，也可以是听一段经文、念一小段佛号，或读一点导读。传统学习里常说闻、思、修要相续，对初学者来说，这并不意味着一天里要把所有事情都做满，而是让接触、理解和实践慢慢连起来。"
              en="A steadier approach is to keep one light but real daily action. It can be a few minutes of meditation, one short scripture passage, a small round of recitation, or a little reading. Traditional learning often treats hearing, reflection, and practice as a sequence. For beginners, that does not mean filling the whole day, but letting contact, understanding, and lived practice connect gradually."
            />
          </p>
          <p>
            <LocalizedText
              zh="Fabushi 更适合承接这条路径里的辅助部分，例如经文听诵、禅修提醒、简单记录和保持连续性。它不能替代长期学习本身，但可以帮助你把修行方法从“知道很多”变成“今天真的做了一点”。"
              en="Fabushi fits best on the support side of this path through scripture listening, meditation reminders, simple notes, and continuity. It does not replace long-term learning, but it can help practice move from knowing many ideas to actually doing a little today."
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
              zh="先把修行方法的三个基本判断放稳。"
              en="Set three basic judgments in place before you build a routine."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {practicePrinciples.map((item) => (
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
            <LocalizedText zh="常见方法" en="Common Methods" />
          </p>
          <h2>
            <LocalizedText
              zh="先看初学者最常接触的几种修行方法，各自适合做什么。"
              en="See the common methods beginners encounter first and what each one does best."
            />
          </h2>
        </div>
        <div className="path-grid">
          {practiceMethods.map((item) => (
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
            <LocalizedText zh="第一周节奏" en="First Week" />
          </p>
          <h2>
            <LocalizedText
              zh="把第一周能做的事拆成三步，会比空想更容易真正留下来。"
              en="Break the first week into three steps so the rhythm can actually stay."
            />
          </h2>
        </div>
        <div className="compare-grid">
          {weeklyRhythm.map((item) => (
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
              zh="顺着你当下最需要的入口，继续往更具体的页面走。"
              en="Move from this overview into the page that matches what you need most now."
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
              zh="先回答初学者最容易在修行方法上卡住的几个问题。"
              en="Answer the questions beginners most often get stuck on when choosing methods."
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
          <a className="secondary-action" href={siteHref("/start-learning-buddhism")}>
            <LocalizedText zh="回到学佛从哪里开始" en="Back to Where to Begin" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
