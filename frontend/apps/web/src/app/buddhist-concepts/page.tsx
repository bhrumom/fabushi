import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/buddhist-concepts");
const pageTitle = `佛学基本概念入门 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理佛学基本概念入门：从因果、菩提心、六度、空性，到这些概念怎样回到佛经阅读、修行方法与日常功课。";

const conceptPrinciples = [
  {
    titleZh: "概念不是背名词，而是帮助修行方向慢慢站稳",
    titleEn: "Concepts are not vocabulary drills but ways of stabilizing direction",
    descriptionZh: "很多人一开始听到因果、菩提心、六度、空性，会觉得这些词离生活很远。更稳妥的理解是：这些概念真正有用的地方，不在于让人背得更多，而在于帮助人看清为什么要学、怎样练，以及心会往哪里走。",
    descriptionEn: "When beginners first meet karma, bodhicitta, the six paramitas, and emptiness, the language can feel distant. A steadier view is that these concepts matter not for memorizing more words, but for clarifying why we learn, how we practice, and where the heart is moving.",
  },
  {
    titleZh: "先抓住最常反复碰到的四组概念，比一口气学完更可靠",
    titleEn: "It is steadier to begin with the four concepts you keep meeting most often",
    descriptionZh: "初学者不需要第一天就把所有佛学名相弄懂。先把因果、菩提心、六度和空性这些最常在入门、修行、佛经阅读里反复出现的概念放清楚，往往已经能让后面的路顺很多。",
    descriptionEn: "Beginners do not need to master every buddhist term on day one. Clarifying the concepts that keep returning across beginner guides, practice pages, and sutra reading already makes the next steps much easier.",
  },
  {
    titleZh: "概念页最有价值的时候，是它们能重新接回修行和日常",
    titleEn: "Concept pages matter most when they return to practice and daily life",
    descriptionZh: "如果概念只停在解释层，很快又会变得抽象。更有力量的方式，是让因果回到选择，菩提心回到发心，六度回到做人做事，空性回到最容易执着的地方。",
    descriptionEn: "If concepts stay only at the level of explanation, they soon become abstract again. They gain force when karma returns to choice, bodhicitta to aspiration, the six paramitas to conduct, and emptiness to the places where grasping is strongest.",
  },
] as const;

const conceptPaths = [
  {
    href: "/what-is-karma",
    labelZh: "因果是什么意思",
    labelEn: "What Karma Means",
    titleZh: "先把“因果是不是报应”这类最常见的误解放清楚。",
    titleEn: "Clarify the common beginner confusion around whether karma means simple payback.",
    descriptionZh: "如果你总觉得因果像一句马上兑现的判断，这一页更适合先打开。它会把因果、业力、习惯和结果怎样慢慢形成说得更具体。",
    descriptionEn: "Open this first if karma still sounds like an instant verdict. It explains more concretely how intention, habit, and result gradually form together.",
  },
  {
    href: "/what-is-bodhicitta",
    labelZh: "菩提心是什么意思",
    labelEn: "What Bodhicitta Means",
    titleZh: "把大乘修学里最关键的发心从口号接回方向。",
    titleEn: "Return one of the central Mahayana intentions from slogan to lived direction.",
    descriptionZh: "如果你常把菩提心理解成“人好一点就够了”，这一页会更适合继续往下看。它会把愿心、利他和日常练习之间的关系说清楚。",
    descriptionEn: "This is the better next page if bodhicitta still sounds like simply being nice. It clarifies how aspiration, benefiting others, and daily practice fit together.",
  },
  {
    href: "/what-are-the-six-paramitas",
    labelZh: "六度分别是什么",
    labelEn: "Six Paramitas",
    titleZh: "把发心怎样慢慢长成做人、修心和练习的六个方向接起来。",
    titleEn: "See how aspiration gradually becomes six directions of training and conduct.",
    descriptionZh: "如果你已经听过布施、持戒、忍辱、精进、禅定、般若，但仍觉得它们像一张离生活很远的表，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you have heard the six paramitas but they still feel like a list far away from ordinary life.",
  },
  {
    href: "/what-is-emptiness",
    labelZh: "空性怎么理解",
    labelEn: "How to Understand Emptiness",
    titleZh: "把“空”从抽象词句慢慢接回因缘、经验和不那么僵硬的看法。",
    titleEn: "Return emptiness from abstraction to dependent arising, lived experience, and a less rigid way of seeing.",
    descriptionZh: "如果你最卡的是“空性是不是就是什么都没有”，这一页更适合继续往下看。它会把空性和生活经验之间的距离拉近一些。",
    descriptionEn: "This is the better next page if your main question is whether emptiness means nothingness. It brings emptiness closer to ordinary experience.",
  },
] as const;

const integrationSteps = [
  {
    titleZh: "第一步：先从你已经反复碰到的词开始，不先追求全懂",
    titleEn: "Step 1: Start with the concept you keep meeting most often",
    descriptionZh: "如果你最近总是碰到因果，就先把因果看清；如果最近一直卡在“菩提心到底是什么意思”，就先从菩提心进去。先抓住最贴近自己当下问题的一个入口，比一下子全懂更可靠。",
    descriptionEn: "If karma keeps returning in your reading, clarify karma first. If you are repeatedly stuck on what bodhicitta means, begin there. Starting with the concept nearest to your present question is steadier than trying to understand everything at once.",
  },
  {
    titleZh: "第二步：读完概念页后，立刻接回修行方法或佛经问题页",
    titleEn: "Step 2: After reading a concept page, return it to practice or scripture questions immediately",
    descriptionZh: "概念最怕只停在脑子里。看完因果以后，可以回到日常功课；看完菩提心和六度以后，可以回到修行方法；看完空性以后，也可以回到《心经》或佛经导读继续往下走。",
    descriptionEn: "Concepts grow weakest when they stay in the head alone. After karma, return to daily routine; after bodhicitta and the six paramitas, return to practice methods; after emptiness, return to the Heart Sutra or the sutra guide.",
  },
  {
    titleZh: "第三步：让一个概念在这一周里真正影响一个选择",
    titleEn: "Step 3: Let one concept influence one real choice this week",
    descriptionZh: "比起收藏很多解释，更有力量的是问一句：这一周里，因果会不会让我说话慢一点？菩提心会不会让我少一点只围着自己打转？六度会不会让我在挫败里多一点忍耐？空性会不会让我少一点把事情抓死？",
    descriptionEn: "More useful than collecting explanations is asking one concrete question this week: will karma slow my speech a little, will bodhicitta widen my concern beyond myself, will the six paramitas bring more patience into frustration, and will emptiness soften rigid grasping?",
  },
] as const;

const commonMistakes = [
  {
    titleZh: "把概念页当成要背完的知识清单",
    titleEn: "Treating concept pages like a list to memorize",
    descriptionZh: "如果一开始就想把所有名相都记住，通常会越学越重。更稳妥的做法，是先弄懂最贴近自己问题的一两组概念，让它们先在生活里活起来。",
    descriptionEn: "Trying to memorize every term at once usually makes study heavier. A steadier way is to understand one or two concept groups that already match your question and let them become alive in life first.",
  },
  {
    titleZh: "只读概念，不接回修行方法和日常节奏",
    titleEn: "Reading concepts without returning them to practice rhythm",
    descriptionZh: "如果看完概念页以后，没有继续回到禅修、听诵、日常功课或佛经阅读，理解很快又会飘掉。概念真正有力的时候，是它们能把你带回下一步。",
    descriptionEn: "If concept reading never returns to meditation, listening, daily practice, or scripture study, the understanding quickly drifts away. Concepts become strong when they carry you into a next step.",
  },
  {
    titleZh: "一碰到难词就觉得“这离我太远”",
    titleEn: "Assuming difficult language means the topic is too far away",
    descriptionZh: "很多概念一开始听起来确实陌生，但它们往往都在回答生活里很具体的问题，例如为什么习惯会形成结果、为什么修行不能只围着自己、为什么练习要慢慢回到忍耐和节奏、为什么事情没有想象中那么固定。",
    descriptionEn: "Many concepts do sound unfamiliar at first, but they are often answering very concrete questions in life: how habits become results, why practice cannot circle only around oneself, why training returns to patience and rhythm, and why things are less fixed than they seem.",
  },
] as const;

const relatedPaths = [
  {
    href: "/start-learning-buddhism",
    labelZh: "学佛从哪里开始",
    labelEn: "Where to Begin",
    titleZh: "先把整体起步顺序放轻一点、放清楚一点。",
    titleEn: "Clarify the wider beginner sequence first.",
    descriptionZh: "如果你还在找整个入门阶段的第一步，而不只是概念入口，这一页更适合先打开。",
    descriptionEn: "Open this first if you still need the first step for the whole beginner stage, not only a concept entry point.",
  },
  {
    href: "/buddhadharma",
    labelZh: "佛法入门",
    labelEn: "Dharma Basics",
    titleZh: "回到更完整的佛法入门地图。",
    titleEn: "Return to the broader map of buddhadharma basics.",
    descriptionZh: "如果你想把概念、修行方法、佛经阅读和日常实践放回同一张图里，这一页更适合继续往下看。",
    descriptionEn: "This is the better next page if you want concepts, practice methods, scripture study, and daily life back on one map.",
  },
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "把概念直接接回禅修、听诵、念佛和记录的实际方法。",
    titleEn: "Return concepts directly to meditation, listening, recitation, and note-taking methods.",
    descriptionZh: "如果你已经把概念看懂一些，下一步想知道怎样落回练习方式，这一页更适合继续往下走。",
    descriptionEn: "This page is the better next step if the concepts are clearer and you now want to see how they land inside actual methods of practice.",
  },
  {
    href: "/beginner-sutra-recommendations",
    labelZh: "初学者佛经推荐",
    labelEn: "Beginner Sutra Picks",
    titleZh: "把概念问题重新接回读哪部经更合适。",
    titleEn: "Return concept questions to the question of which sutra fits best first.",
    descriptionZh: "如果你已经发现自己的问题更接近《心经》、" +
      "《阿弥陀经》、" +
      "《普门品》或《金刚经》，这一页会更具体。",
    descriptionEn: "This page is more specific if your questions are already pulling you toward the Heart Sutra, Amitabha Sutra, Universal Gate Chapter, or Diamond Sutra.",
  },
  {
    href: "/sutra-guide",
    labelZh: "佛经导读",
    labelEn: "Sutra Guide",
    titleZh: "把概念理解重新放回佛经阅读和经文听诵里。",
    titleEn: "Return concept understanding to scripture reading and listening.",
    descriptionZh: "如果你已经发现很多概念其实都在读经时反复出现，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you have realized many of these concepts keep returning through sutra reading and listening.",
  },
] as const;

const faqItems = [
  {
    questionZh: "佛学基本概念是不是一定要一口气全懂？",
    questionEn: "Do I need to understand all the basic buddhist concepts at once?",
    answerZh: "不需要。对初学者来说，更可靠的方式通常是先抓住最常反复碰到的一两个概念，例如先看因果，或先看菩提心，再慢慢把其他概念接进来。重要的不是一下子全懂，而是让理解开始有顺序。",
    answerEn: "No. For beginners, it is usually steadier to begin with one or two concepts that keep returning, such as karma or bodhicitta, and then let the others come in gradually. The goal is not instant mastery but a workable order of understanding.",
  },
  {
    questionZh: "应该先懂因果，还是先懂空性？",
    questionEn: "Should I understand karma first or emptiness first?",
    answerZh: "很多初学者会先从因果进入，因为它和习惯、选择、结果之间的关系更容易贴近生活。空性当然也重要，但如果现在最常卡的是“事情为什么会这样形成”，先从因果进去通常更稳；如果已经被《心经》或“空”这个字反复困住，再先看空性也可以。",
    answerEn: "Many beginners enter through karma first because it relates more directly to habit, choice, and result in everyday life. Emptiness matters too, but if your main question is how things keep taking shape, karma is often steadier first. If the Heart Sutra or the language of emptiness already keeps troubling you, starting there can also be right.",
  },
  {
    questionZh: "这些概念会不会离日常生活太远？",
    questionEn: "Are these concepts too far from ordinary life?",
    answerZh: "通常不是。因果会回到今天的说话和选择，菩提心会回到发心是不是还只围着自己，六度会回到忍耐、精进和待人处事，空性会回到我们是不是把事情抓得太死。它们都不是只放在书里的词。",
    answerEn: "Usually not. Karma returns to speech and choice today, bodhicitta returns to whether aspiration still circles only around oneself, the six paramitas return to patience, diligence, and conduct, and emptiness returns to whether we are gripping things too rigidly. None of them need stay only in books.",
  },
  {
    questionZh: "读佛经时碰到概念看不懂怎么办？",
    questionEn: "What should I do when a sutra introduces concepts I do not understand?",
    answerZh: "可以先把那个概念单独抽出来看，不必硬撑着整段都懂完。例如读《心经》时卡在空性，就先去看空性导读；读《普门品》时卡在慈悲为什么会长成更宽的方向，就先去看菩提心。这样回头再读经，通常更容易读进去。",
    answerEn: "You can pull the concept out and clarify it on its own instead of forcing yourself through the whole passage. If the Heart Sutra stalls you on emptiness, open the emptiness guide first. If the Universal Gate Chapter raises questions about compassion widening into a larger path, open bodhicitta first. Returning afterward usually makes the text easier to enter.",
  },
  {
    questionZh: "Fabushi 在理解佛学概念这件事上最适合帮助什么？",
    questionEn: "What is Fabushi most useful for when learning buddhist concepts?",
    answerZh: "它更适合作为听诵、提醒和简短记录的辅助工具，帮助你把“今天碰到的概念”和“今天真的做了什么”接在一起。更系统的理解，仍然要回到导读、经典、老师和长期练习。",
    answerEn: "It works best as a support tool for listening, reminders, and short notes so the concept you met today can connect with what you actually did today. Deeper understanding still depends on guides, texts, teachers, and sustained practice.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "佛学基本概念",
    "佛教概念入门",
    "佛法概念",
    "因果是什么意思",
    "菩提心是什么意思",
    "六度分别是什么",
    "空性怎么理解",
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

export default function BuddhistConceptsPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "CollectionPage",
        name: "佛学基本概念入门",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: ["佛学基本概念", "因果", "菩提心", "六度", "空性"],
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
            name: "佛学基本概念入门",
            item: pageUrl,
          },
        ],
      },
      {
        "@type": "ItemList",
        name: "佛学基本概念路径",
        itemListElement: conceptPaths.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.labelZh,
          url: siteUrl(item.href),
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
            <LocalizedText zh="佛学基本概念入门" en="Buddhist Concepts" />
          </p>
          <h1>
            <LocalizedText
              zh="把因果、菩提心、六度和空性放回同一张更容易走的入门地图里。"
              en="Place karma, bodhicitta, the six paramitas, and emptiness back on one beginner map."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="很多人不是不愿意学佛，而是刚碰到这些词就觉得太远、太抽象。这一页先把最常反复出现的几组基础概念放清楚，再把它们接回佛经阅读、修行方法与日常节奏。"
              en="Many people are not unwilling to begin buddhadharma. The difficulty is that these concepts can feel too far away or too abstract too quickly. This page clarifies the core concepts that return most often and then connects them back to scripture, practice, and daily rhythm."
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
              zh="先把概念收成一张图，后面的修行路径才不会越走越散。"
              en="When the concepts gather into one map first, the practice path is less likely to scatter."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="很多初学者一开始最常遇到的阻碍，并不是没有内容，而是总在不同页面、不同经典和不同建议里，反复碰到因果、菩提心、六度、空性这些词，却不知道它们彼此是什么关系。词越多，心里越容易觉得佛法离自己很远。"
              en="One of the most common beginner obstacles is not a lack of material, but meeting words such as karma, bodhicitta, the six paramitas, and emptiness across different pages, texts, and advice without knowing how they relate. The more language appears, the easier buddhadharma feels far away."
            />
          </p>
          <p>
            <LocalizedText
              zh="比较稳妥的方式，不是急着一下子学完所有佛学名相，而是先抓住最常出现、也最容易影响方向的几组概念。因果会帮助人看见习惯和选择怎样形成结果；菩提心会帮助人看见修行为什么不能只围着自己；六度会把这种发心接回做人做事与练习节奏；空性则会帮助人少一点把经验和情绪抓得太死。"
              en="A steadier way is not to rush through every buddhist term, but to first hold the concepts that appear most often and most strongly shape direction. Karma clarifies how habit and choice become results. Bodhicitta shows why practice cannot circle only around oneself. The six paramitas return that aspiration to conduct and rhythm. Emptiness loosens the tendency to hold experience too rigidly."
            />
          </p>
          <p>
            <LocalizedText
              zh="真正有价值的概念页，也不应该只停在解释上。看完以后，最好立刻回到佛经阅读、修行方法、日常功课或经文听诵里，看看这些概念怎样开始影响这一周真实的一点点选择。Fabushi 更适合承接这种“把理解慢慢留在日常里”的部分。"
              en="A useful concept page should not stop at explanation alone. After reading, it helps to return immediately to scripture, practice methods, daily routine, or listening and see how one concept begins to influence one real choice this week. Fabushi fits best on the side of helping that understanding stay inside daily life."
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
              zh="先把理解佛学概念时最稳的三个判断放好。"
              en="Set three steady judgments in place before going deeper into concepts."
            />
          </h2>
        </div>
        <div className="feature-grid">
          {conceptPrinciples.map((item) => (
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
            <LocalizedText zh="概念路径" en="Concept Paths" />
          </p>
          <h2>
            <LocalizedText
              zh="先从你现在最常反复碰到的那个概念入口开始。"
              en="Begin with the concept doorway that is already returning most often in your life."
            />
          </h2>
        </div>
        <div className="editorial-list">
          {conceptPaths.map((item) => (
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

      <section className="band alt feature-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="怎么使用" en="How to Use This" />
          </p>
          <h2>
            <LocalizedText
              zh="把概念从“看懂一点”接回“这一周真的有一点变化”。"
              en="Move a concept from partial understanding into one real change this week."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {integrationSteps.map((item) => (
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
            <LocalizedText zh="常见误区" en="Common Mistakes" />
          </p>
          <h2>
            <LocalizedText
              zh="先避开几个会让佛学概念越学越重的误区。"
              en="Avoid the patterns that make buddhist concepts feel heavier than they need to be."
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

      <section className="band alt">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="继续阅读" en="Keep Going" />
          </p>
          <h2>
            <LocalizedText
              zh="把概念页重新接回更完整的起步、修行和佛经路径。"
              en="Return this concept hub to the wider beginner, practice, and scripture paths."
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
              zh="先回答理解佛学基本概念时最容易遇到的几个问题。"
              en="Answer the questions people most often hit when learning basic buddhist concepts."
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
          <a className="primary-action" href={siteHref("/start-learning-buddhism")}>
            <LocalizedText zh="先看学佛从哪里开始" en="Start with Where to Begin" />
          </a>
          <a className="secondary-action" href={siteHref("/practice-guide")}>
            <LocalizedText zh="继续看修行方法总览" en="Continue to the Practice Guide" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
