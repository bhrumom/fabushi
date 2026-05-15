import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/sutra-guide");
const pageTitle = `佛经导读 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理佛经从哪里开始读、经文听诵与阅读如何配合，以及怎样把佛经学习放进稳定的修行节奏。";

const scriptureFoundations = [
  {
    titleZh: "先求方向清楚，不先求读得很多",
    titleEn: "Choose clarity before quantity",
    descriptionZh: "初学者最容易卡住的不是佛经太少，而是一下子面对太多经名、太多版本和太多期待。先理清自己为什么读，经常比多读几部更重要。",
    descriptionEn: "Beginners usually get stuck not because there are too few sutras, but because there are too many names, editions, and expectations at once. Knowing why you are reading often matters more than reading many texts quickly.",
  },
  {
    titleZh: "听诵和阅读各有作用",
    titleEn: "Listening and reading do different work",
    descriptionZh: "听诵更容易帮助熟悉经文节奏和语感，阅读更容易帮助停下来理解义理，两者可以互相配合，而不是互相替代。",
    descriptionEn: "Listening helps you absorb the rhythm and feel of a sutra, while reading helps you pause and understand the meaning. They support each other instead of replacing each other.",
  },
  {
    titleZh: "把佛经放回修行生活里",
    titleEn: "Return sutra study to lived practice",
    descriptionZh: "经典不是只拿来收藏知识点，更重要的是帮助自己调整发心、看法和日常行动。读得慢一点，但能回到生活里，往往更有力量。",
    descriptionEn: "Sutras are not only for collecting ideas. Their deeper value is in reshaping intention, view, and daily action. Reading more slowly but bringing it back into life is often more transformative.",
  },
] as const;

const entryPaths = [
  {
    titleZh: "先从短篇、常见、容易进入的经典开始",
    titleEn: "Start with shorter and widely read sutras",
    descriptionZh: "很多初学者会先接触《心经》或《阿弥陀经》这类篇幅较短、流通较广的经典，先建立熟悉感，再决定要不要继续深入其他经文。",
    descriptionEn: "Many beginners begin with shorter and widely read sutras such as the Heart Sutra or Amitabha Sutra so they can build familiarity first before going deeper.",
  },
  {
    titleZh: "再按自己当下最关心的问题选主题",
    titleEn: "Then choose by the question you are living with",
    descriptionZh: "如果你更关心发心、智慧、净土愿行或日常修持，可以围绕自己眼前最想弄明白的问题去选佛经，这样更容易读进去。",
    descriptionEn: "If your present concern is aspiration, wisdom, Pure Land practice, or daily discipline, choose sutras around that living question. It is usually easier to stay engaged that way.",
  },
  {
    titleZh: "把听诵、阅读和一点记录接起来",
    titleEn: "Connect listening, reading, and a short note",
    descriptionZh: "先听一遍建立熟悉感，再读一小段，最后记下今天真正触动自己的一个意思，比机械地刷很多内容更容易留下痕迹。",
    descriptionEn: "Listen once to build familiarity, read a short section, then leave one note about what truly landed for you. That usually stays with you longer than mechanically finishing large amounts of material.",
  },
] as const;

const conceptBlocks = [
  {
    titleZh: "经文听诵",
    titleEn: "Sutra listening",
    descriptionZh: "更适合用来熟悉经文语气、建立日常熏习和维持节奏，尤其适合通勤、步行或固定功课前后的短时间。",
    descriptionEn: "Useful for absorbing a sutra's tone, building daily familiarity, and keeping rhythm, especially during short windows such as commuting or walking.",
  },
  {
    titleZh: "义理阅读",
    titleEn: "Meaning-focused reading",
    descriptionZh: "更适合在安静一点的时间里慢慢读，遇到不懂的地方先记下来，不急着一次全部弄通。先把关键句读进去，比急着求全更稳。",
    descriptionEn: "Best done in a quieter moment. When a passage is unclear, note it and keep going instead of forcing total understanding in one sitting. Getting one key line to land is often enough for now.",
  },
  {
    titleZh: "闻思修",
    titleEn: "Hear, reflect, practice",
    descriptionZh: "传统学习里常把闻、思、修看成前后相续的过程。先接触经文，再反复思惟，再回到日常实践里验证，佛经才不会只停留在纸面。",
    descriptionEn: "Traditional learning often treats hearing, reflection, and practice as a sequence. Encounter the text, reflect on it, then bring it into daily practice so the sutra does not stay on the page alone.",
  },
] as const;

const relatedPaths = [
  {
    href: "/buddhadharma",
    labelZh: "佛法入门",
    labelEn: "Dharma Basics",
    titleZh: "先回到更完整的学佛入门地图。",
    titleEn: "Return to the broader beginner map for buddhadharma.",
    descriptionZh: "如果你还在分辨佛法、修行、禅修和经文之间的关系，先从佛法入门页看整体脉络。",
    descriptionEn: "If you are still mapping buddhadharma, practice, meditation, and scripture, start from the broader beginner hub first.",
  },
  {
    href: "/meditation",
    labelZh: "禅修入门",
    labelEn: "Meditation Guide",
    titleZh: "把佛经阅读和禅修练习互相接起来。",
    titleEn: "Let sutra reading and meditation reinforce each other.",
    descriptionZh: "如果你想知道经文听诵和禅修如何一起放进日常，这一页可以继续往下接。",
    descriptionEn: "If you want scripture listening and meditation to live in the same daily rhythm, this is the next page to open.",
  },
  {
    href: "/download",
    labelZh: "下载入口",
    labelEn: "Download",
    titleZh: "把经文听诵和修行记录留在生活里。",
    titleEn: "Keep sutra listening and practice notes inside daily life.",
    descriptionZh: "准备通过 Fabushi 辅助经文听诵、禅修和日常提醒时，可以直接查看下载入口。",
    descriptionEn: "When you are ready to use Fabushi for scripture listening, meditation, and reminders, go straight to the download page.",
  },
] as const;

const faqItems = [
  {
    questionZh: "初学者适合先读什么佛经？",
    questionEn: "Which sutra is good for a beginner to start with?",
    answerZh: "通常更适合先从篇幅较短、流通较广、自己也更容易接近的经典开始，例如《心经》或《阿弥陀经》这类常见短篇。关键不是一次选最难的，而是先建立稳定阅读与听诵节奏。",
    answerEn: "Beginners often do best with shorter, widely read sutras they can approach more easily, such as the Heart Sutra or Amitabha Sutra. The key is not to choose the hardest text first, but to build a steady rhythm of reading and listening.",
  },
  {
    questionZh: "经文听诵能代替自己阅读吗？",
    questionEn: "Can listening to sutras replace reading them?",
    answerZh: "不能完全代替。听诵适合熟悉经文和保持熏习，阅读更有助于停下来理解义理。两者配合起来，通常比只靠其中一种更稳。",
    answerEn: "Not completely. Listening helps familiarity and continuity, while reading helps with understanding the meaning. Used together, they are usually steadier than relying on only one.",
  },
  {
    questionZh: "看不懂佛经，是不是说明现在还不适合读？",
    questionEn: "If I do not understand a sutra, does that mean I am not ready?",
    answerZh: "不一定。看不懂是很常见的起点。可以先抓住一两个能读懂的句子，配合导读、注解或听诵慢慢进入，不需要一开始就把每句话都弄通。",
    answerEn: "Not at all. Not understanding everything is a common starting point. Begin with one or two lines you can really absorb, and use guides, commentary, or listening to enter gradually.",
  },
  {
    questionZh: "一开始需要读很多部经典吗？",
    questionEn: "Do I need to read many sutras at the beginning?",
    answerZh: "通常不需要。先选一两部和自己当前问题最贴近的经典，反复听、反复读、反复想，比匆忙看很多部更容易真正留下来。",
    answerEn: "Usually not. Pick one or two sutras that match the question you are living with and return to them repeatedly. That often stays with you better than rushing through many texts.",
  },
  {
    questionZh: "Fabushi 在佛经导读里最适合扮演什么角色？",
    questionEn: "What role does Fabushi play in a sutra study routine?",
    answerZh: "它更适合作为经文听诵、提醒和简单记录的辅助工具，帮助你把佛经学习放进日常节奏，而不是只在想起来时才接触经典。",
    answerEn: "It works best as a support tool for scripture listening, reminders, and short notes so sutra study can stay inside everyday life instead of happening only occasionally.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: ["佛经", "佛经导读", "佛经入门", "初学者读什么佛经", "经文听诵", "Fabushi"],
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

export default function SutraGuidePage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "佛经导读",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: ["佛经导读", "佛经入门", "经文听诵"],
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
            <LocalizedText zh="佛经导读" en="Sutra Guide" />
          </p>
          <h1>
            <LocalizedText
              zh="从读什么、怎么读，到听诵与理解的关系，找到更适合初学者的佛经入门方式。"
              en="Find a gentler way into sutra study by clarifying what to read, how to read, and how listening supports understanding."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="当很多经典名字同时出现时，先不急着求多。先从更容易进入、也更贴近自己当下问题的经典开始，反而更容易建立长期节奏。"
              en="When many scripture names appear at once, do not rush for quantity. Begin with texts that are easier to enter and closer to the question you are actually living with."
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
              zh="佛经入门真正难的，往往不是没得读，而是不知道先从哪里读。"
              en="The real difficulty for beginners is usually not a lack of sutras, but not knowing where to begin."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="很多人刚接触佛法时，第一反应是佛经太多：经名很多、版本很多、法门很多，反而不知道第一步该放在哪里。于是很容易出现一种情况：收藏了很多内容，真正慢慢读进去的却很少。这不是因为不够用心，而是入门顺序还没有理清。"
              en="When people first encounter buddhadharma, the problem is often abundance. There are many sutras, many editions, and many traditions, so the first step becomes blurry. The result is common: a lot gets saved, but very little is truly read slowly. That is usually a question of sequence, not sincerity."
            />
          </p>
          <p>
            <LocalizedText
              zh="更稳妥的方式，是先问自己为什么读佛经。是想建立学佛方向、安定心念、理解某个概念，还是想把听诵和修行节奏接进日常？先把这个问题看清，再去选经典，会比一开始追求读得多、读得快更容易进入。"
              en="A steadier approach is to ask why you want to read sutras right now. Are you trying to orient your learning, steady the mind, clarify a concept, or connect listening and practice inside daily life? Once that question becomes clearer, the right text is easier to choose."
            />
          </p>
          <p>
            <LocalizedText
              zh="传统学习里常会把闻、思、修看成相续的过程。对初学者来说，可以先通过听诵熟悉经文，再通过短段阅读理解一点义理，最后把触动自己的内容带回日常观察和行动里。Fabushi 更适合承接这条路径中的听诵、提醒和简短记录，让佛经学习不只停留在偶尔想起。"
              en="Traditional learning often treats hearing, reflection, and practice as a living sequence. Beginners can first become familiar through listening, then read a short section for meaning, and finally bring what resonates back into daily observation and action. Fabushi fits best on the listening, reminder, and short-note side of that rhythm."
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
              zh="先把佛经入门的三个基本判断放稳。"
              en="Set three basic judgments in place before you begin."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {scriptureFoundations.map((item) => (
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
            <LocalizedText zh="入门路径" en="Entry Paths" />
          </p>
          <h2>
            <LocalizedText
              zh="把初学者常见的佛经入门方式拆成三步。"
              en="Break a beginner sutra routine into three workable steps."
            />
          </h2>
        </div>
        <div className="path-grid">
          {entryPaths.map((item) => (
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
              zh="先分清听诵、阅读和闻思修的关系。"
              en="Clarify how listening, reading, and practice relate to each other."
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
            <LocalizedText zh="继续阅读" en="Keep Going" />
          </p>
          <h2>
            <LocalizedText
              zh="把佛经导读页接回更完整的学习和使用路径。"
              en="Use this guide as a bridge into broader learning and product paths."
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
              zh="先回答佛经入门最容易遇到的几个问题。"
              en="Answer the questions beginners usually hit first in sutra study."
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
