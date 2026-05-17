import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/what-is-bodhicitta");
const pageTitle = `菩提心是什么意思 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理菩提心是什么意思：菩提心不是一时的好心，也不只是口号，而是愿意走向觉悟、同时把众生利益放进发心、选择、六度、《普门品》等经典阅读与日常练习里的方向。";

const bodhicittaFoundations = [
  {
    titleZh: "菩提心不是一时的好心情，而是修行方向开始转向",
    titleEn: "Bodhicitta is not a passing good mood but a shift in direction",
    descriptionZh: "很多人第一次听到菩提心，会把它理解成“心地善良一点”。更稳妥的理解是：它不只是情绪上的温柔，而是愿意把觉悟之路和众生利益一起放进生命方向里的发心。",
    descriptionEn: "Many people first hear bodhicitta and think it only means being a little kinder. A steadier view is that it is not just a gentle feeling, but the intention to place awakening and the welfare of others inside the direction of one’s life.",
  },
  {
    titleZh: "菩提心既不是只顾别人，也不是只顾自己解脱",
    titleEn: "Bodhicitta is neither self-neglect nor self-centered liberation",
    descriptionZh: "如果只剩“我要先把自己修好”，容易越走越窄；如果只剩“我要照顾所有人”，又容易空转和耗竭。菩提心更像是让智慧与慈悲一起长出来，而不是偏向任何一边。",
    descriptionEn: "If practice becomes only about fixing oneself, the path can become narrow. If it becomes only about saving everyone immediately, it can turn vague and exhausting. Bodhicitta is closer to allowing wisdom and compassion to grow together.",
  },
  {
    titleZh: "理解菩提心，不是为了说大话，而是为了让每天的选择慢慢不同",
    titleEn: "Understanding bodhicitta changes daily choices instead of producing big slogans",
    descriptionZh: "真正有力量的地方，不是把菩提心挂在嘴边，而是慢慢问自己：今天的学习、说话、做事，是不是还只围着自己的得失打转，还是开始有一点更宽的发心？",
    descriptionEn: "Its real force is not in grand language, but in slowly asking whether today’s study, speech, and action are still circling only around personal gain and loss or beginning to widen into a broader intention.",
  },
] as const;

const entryPaths = [
  {
    titleZh: "第一步：先看清自己学佛，到底只想减轻烦恼，还是也想让心越来越能承接别人",
    titleEn: "Step 1: Notice whether practice only seeks relief or also grows capacity for others",
    descriptionZh: "很多人开始学佛，都是从自己的痛苦和困惑起步，这很自然。菩提心不是否定这个起点，而是在这里慢慢多问一句：如果我真的越来越明白，能不能也让这种明白对别人有益？",
    descriptionEn: "Many people begin buddhadharma from their own pain and confusion, and that is natural. Bodhicitta does not reject that doorway. It simply adds another question: if understanding grows, can that understanding also become beneficial to others?",
  },
  {
    titleZh: "第二步：先从眼前的人和事里练习，不先追求很大的愿词",
    titleEn: "Step 2: Practice with the people and situations already in front of you",
    descriptionZh: "初学者不需要一开始就把愿说得很大。更可行的做法，是先在说话、做事、回应烦恼和面对关系时，练习少一点自我中心，多一点愿意利益人的方向。",
    descriptionEn: "Beginners do not need grand vows immediately. A more workable start is to practice a little less self-centeredness and a little more willingness to be of benefit in speech, action, difficulty, and relationships.",
  },
  {
    titleZh: "第三步：再用稳定的小练习，把发心留下来",
    titleEn: "Step 3: Keep the intention alive through small steady practice",
    descriptionZh: "菩提心不是想一次就结束，而是要靠重复熏习慢慢变稳。哪怕只是每天读一点导读、听一点经文、坐一点禅修，再留下一句提醒，也比偶尔感动一下更容易真正留下来。",
    descriptionEn: "Bodhicitta does not stay alive through one inspiring moment alone. It becomes steady through repetition. Even a little reading, listening, meditation, and one short reminder each day usually carries it further than occasional emotional intensity.",
  },
] as const;

const conceptBlocks = [
  {
    titleZh: "发心",
    titleEn: "The arising of intention",
    descriptionZh: "可以先把菩提心理解成修行方向真正转过来的那一刻：不再只想着怎样让自己轻松一点，而是开始愿意朝向觉悟，也愿意让这种修学能真实利益众生。",
    descriptionEn: "Bodhicitta can first be understood as the moment the path really turns: practice is no longer only about making oneself more comfortable, but about moving toward awakening in a way that can genuinely benefit others.",
  },
  {
    titleZh: "愿菩提心",
    titleEn: "Aspirational bodhicitta",
    descriptionZh: "这一层更像是方向感和愿力。即使现在能力还很有限，仍然愿意把“成就智慧、利益众生”放进自己修学的方向里。它先让路不再只通向自己。",
    descriptionEn: "This layer is closer to direction and aspiration. Even when capacity is still limited, one is willing to place awakening and benefiting beings inside the overall path of practice. It is what keeps the road from leading only back to oneself.",
  },
  {
    titleZh: "行菩提心",
    titleEn: "Engaged bodhicitta",
    descriptionZh: "如果愿心没有慢慢落到说话、待人、忍耐、学习和日常练习里，就容易只停在口头。行菩提心更像是把发心一点一点接回生活，让慈悲和智慧开始有了实际形状。",
    descriptionEn: "If aspiration never returns to speech, patience, learning, relationships, and daily practice, it easily remains verbal. Engaged bodhicitta is the gradual return of intention into ordinary life so compassion and wisdom begin to take actual form.",
  },
] as const;

const scriptureBridgeSteps = [
  {
    href: "/beginner-sutra-recommendations",
    labelZh: "从《普门品》接到菩提心",
    labelEn: "Universal Gate to Bodhicitta",
    titleZh: "如果你是从《普门品》里的慈悲与依止感被打动，下一步先把这种感受接回更清楚的发心方向。",
    titleEn: "If the Universal Gate Chapter first moved you through compassion and refuge, the next step is to return that feeling to a clearer direction of aspiration.",
    descriptionZh: "很多人第一次真正碰到菩提心，不是在概念词条里，而是在《普门品》或观音法门的语气里，开始隐约感觉修行不只为了自己轻松一点。把这一步说清楚，感动才不容易只停在当下。",
    descriptionEn: "Many people first touch bodhicitta not through a glossary page, but through the tone of compassion in the Universal Gate Chapter or Guanyin practice. Clarifying that bridge keeps the feeling from stopping in the moment alone.",
  },
  {
    href: "/what-are-the-six-paramitas",
    labelZh: "从菩提心接到六度",
    labelEn: "Bodhicitta to Six Paramitas",
    titleZh: "如果你已经知道菩提心不是一句口号，下一步更值得看它怎样长成布施、持戒、忍辱、精进、禅定和般若。",
    titleEn: "If bodhicitta is no longer just a slogan, the next useful step is to see how it grows into generosity, discipline, patience, diligence, meditation, and wisdom.",
    descriptionZh: "很多人会在这里继续追问：为什么发心不会只停在心里，而会慢慢变成做人做事和修行节奏？这正是六度最自然接进来的地方。",
    descriptionEn: "Many readers continue by asking why aspiration does not remain only in the heart but gradually becomes conduct and practice rhythm. This is exactly where the six paramitas enter most naturally.",
  },
  {
    href: "/daily-practice",
    labelZh: "从发心接回日常功课",
    labelEn: "Aspiration to Daily Practice",
    titleZh: "如果你最关心的是怎样让发心不要只停在一时触动，下一步先把它接回晨起、白天和晚间的小练习。",
    titleEn: "If your main concern is how aspiration can remain more than a passing feeling, the next step is to return it to small practices across morning, daytime, and evening.",
    descriptionZh: "菩提心真正留得住，往往不是靠一次很强的感动，而是靠很轻但持续的功课把它慢慢放进生活里。",
    descriptionEn: "Bodhicitta usually stays alive not through one intense inspiration, but through a light and continuous routine that slowly places it inside ordinary life.",
  },
] as const;

const commonMistakes = [
  {
    titleZh: "把菩提心理解成“人好一点就够了”",
    titleEn: "Reducing bodhicitta to simply being nice",
    descriptionZh: "善良当然重要，但菩提心不只是温和和好意。它还牵涉对觉悟方向的理解、对众生处境的体会，以及愿意把自己的修行慢慢转成更宽阔路径的决心。",
    descriptionEn: "Kindness matters, but bodhicitta is not only softness or good manners. It also involves understanding the direction of awakening, feeling the condition of beings, and being willing to let one’s practice open into a wider path.",
  },
  {
    titleZh: "把菩提心说得很大，却没有回到日常行为",
    titleEn: "Speaking grandly about bodhicitta without daily embodiment",
    descriptionZh: "如果发心只停留在感动或口号里，过几天往往就散了。更可靠的做法，是回到每天怎样学习、怎样回应别人、怎样面对烦恼，让愿心一点一点有落点。",
    descriptionEn: "If bodhicitta stays only as inspiration or slogan, it usually fades quickly. The more reliable way is to return to how you study, respond to others, and meet confusion each day so the aspiration has somewhere to land.",
  },
  {
    titleZh: "因为讲众生，就忽略自己的承受力和次第",
    titleEn: "Forgetting one’s actual capacity in the name of helping others",
    descriptionZh: "菩提心不是逼自己立刻承担一切，也不是把疲惫当成慈悲。对初学者来说，先把发心放进可持续的节奏里，反而更不容易退失。",
    descriptionEn: "Bodhicitta does not mean forcing yourself to carry everything immediately or confusing exhaustion with compassion. For beginners, placing intention inside a sustainable rhythm is often what keeps it from collapsing.",
  },
] as const;

const relatedPaths = [
  {
    href: "/buddhadharma",
    labelZh: "佛法入门",
    labelEn: "Dharma Basics",
    titleZh: "先回到更完整的学佛入门地图。",
    titleEn: "Return to the broader beginner map for buddhadharma.",
    descriptionZh: "如果你还想先看清佛法、修行、经典和日常实践之间的整体关系，这一页更适合先打开。",
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
    href: "/buddhist-concepts",
    labelZh: "佛学基本概念",
    labelEn: "Buddhist Concepts",
    titleZh: "先回到一张更完整的概念地图，再决定自己现在更该继续看哪一个词。",
    titleEn: "Return to a wider concepts map before deciding which concept deserves attention next.",
    descriptionZh: "如果你已经发现自己的问题不只停在菩提心一个词上，而是开始和因果、六度、空性连在一起，这一页会更适合先打开。",
    descriptionEn: "Open this first if your question is no longer only about bodhicitta and is beginning to connect with karma, the six paramitas, and emptiness as well.",
  },
  {
    href: "/what-is-karma",
    labelZh: "因果是什么意思",
    labelEn: "What Karma Means",
    titleZh: "把发心和行为怎样慢慢形成结果一起看。",
    titleEn: "Read intention together with the way actions gradually become results.",
    descriptionZh: "如果你想把“发心”这件事放回因果、习惯和日常选择里一起理解，这一页更适合继续往下看。",
    descriptionEn: "This is the better next page if you want to understand intention together with karma, habits, and ordinary choices.",
  },
  {
    href: "/sutra-guide",
    labelZh: "佛经导读",
    labelEn: "Sutra Guide",
    titleZh: "把慈悲、发心和经典阅读重新放回同一条路上。",
    titleEn: "Return compassion, aspiration, and scripture reading to the same path.",
    descriptionZh: "如果你已经发现自己常常是从《普门品》、听诵或经典语气里先被打动，这一页会更适合继续往下走。",
    descriptionEn: "This page is the better next step if you often find yourself moved first through the Universal Gate Chapter, listening, or the tone of scripture itself.",
  },
  {
    href: "/beginner-sutra-recommendations",
    labelZh: "初学者佛经推荐",
    labelEn: "Beginner Sutra Picks",
    titleZh: "把《普门品》为什么常会把人带到菩提心，放回更具体的经典入口里。",
    titleEn: "Return the bridge from the Universal Gate Chapter to bodhicitta to a more specific beginner scripture entry point.",
    descriptionZh: "如果你已经发现自己的问题更贴近《普门品》、慈悲和依止感，而不是抽象概念本身，这一页会更适合继续往下看。",
    descriptionEn: "This page is more specific if your question is already closer to the Universal Gate Chapter, compassion, and refuge than to abstract concept language alone.",
  },
  {
    href: "/what-are-the-six-paramitas",
    labelZh: "六度分别是什么",
    labelEn: "Six Paramitas",
    titleZh: "把菩提心怎样落回做人、修心和练习里接起来。",
    titleEn: "See how bodhicitta returns to conduct, training, and ordinary life.",
    descriptionZh: "如果你想知道发心为什么会继续长成布施、持戒、忍辱、精进、禅定和般若，这一页更适合继续往下看。",
    descriptionEn: "This is the better next page if you want to see how aspiration unfolds into generosity, discipline, patience, diligence, meditation, and wisdom.",
  },
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "把愿心放回禅修、听诵、阅读和记录的节奏里。",
    titleEn: "Return aspiration to the rhythm of meditation, listening, reading, and notes.",
    descriptionZh: "如果你更关心菩提心要怎样慢慢落到练习方式上，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you want to see how bodhicitta slowly lands inside actual practice methods.",
  },
  {
    href: "/daily-practice",
    labelZh: "日常功课怎么安排",
    labelEn: "Daily Practice",
    titleZh: "让发心在每天很小的动作里慢慢站稳。",
    titleEn: "Let aspiration become steadier through the small actions of a day.",
    descriptionZh: "如果你想把菩提心从概念接回晨起、白天和晚间的日常节奏，这一页会更具体。",
    descriptionEn: "This page is more concrete if you want to return bodhicitta from concept into morning, daytime, and evening rhythm.",
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
    questionZh: "菩提心是不是只要“人很好”就算有了？",
    questionEn: "Is bodhicitta just the same as being a very nice person?",
    answerZh: "不完全是。善良当然重要，但菩提心还包含一个更明确的方向：愿意朝向觉悟，同时不把修行只缩成自己的得失。它比“好心一点”更深，也更需要长期练习。",
    answerEn: "Not exactly. Kindness matters, but bodhicitta also carries a clearer direction: moving toward awakening without reducing practice to personal gain and loss alone. It is deeper than simply being nice and needs longer cultivation.",
  },
  {
    questionZh: "初学者能力有限，也可以谈菩提心吗？",
    questionEn: "Can a beginner with limited capacity still speak about bodhicitta?",
    answerZh: "可以。初学者不需要一开始就承担很大的事。更实际的起点，是先把发心放进今天怎样说话、怎样学习、怎样回应别人和怎样练习里。菩提心本来就不是一下完成的。",
    answerEn: "Yes. A beginner does not need huge capacity immediately. The more practical start is to place intention inside how you speak, learn, respond, and practice today. Bodhicitta is not something completed all at once.",
  },
  {
    questionZh: "发了菩提心，是不是就不能照顾自己了？",
    questionEn: "If I cultivate bodhicitta, does that mean I should stop caring for myself?",
    answerZh: "不是。真正稳的菩提心，不是把自己耗尽，而是让自己的学习、练习和照顾身心，也慢慢成为利益众生的一部分。把自己照顾到能继续走下去，反而更稳。",
    answerEn: "No. Steady bodhicitta is not self-destruction. It lets your own study, practice, and care for body and mind become part of a path that can truly benefit others. Sustaining yourself is often what keeps the path alive.",
  },
  {
    questionZh: "《普门品》和菩提心有什么关系？",
    questionEn: "What does the Universal Gate Chapter have to do with bodhicitta?",
    answerZh: "很多人先从《普门品》感到慈悲和依止感，但继续往前时，常会追问：这种感受为什么不会只停在一时安慰，而会慢慢长成更宽的发心？这正是它和菩提心最自然接起来的地方。",
    answerEn: "Many readers first feel compassion and refuge through the Universal Gate Chapter, then begin to ask how that feeling becomes more than temporary comfort and grows into a wider aspiration. That is where it most naturally connects with bodhicitta.",
  },
  {
    questionZh: "菩提心和六度是什么关系？",
    questionEn: "How are bodhicitta and the six paramitas related?",
    answerZh: "可以把菩提心看成方向，把六度看成这种方向慢慢长成做法和习惯的路径。没有发心，六度容易只剩条目；没有六度，发心也容易只停在感动和口号里。",
    answerEn: "You can think of bodhicitta as direction and the six paramitas as the way that direction slowly becomes practice and habit. Without aspiration, the paramitas can shrink into a list. Without the paramitas, aspiration can remain only inspiration or slogan.",
  },
  {
    questionZh: "菩提心一定要先懂很多教理，才能开始吗？",
    questionEn: "Do I need to understand a lot of doctrine before I can begin cultivating bodhicitta?",
    answerZh: "不一定。理解当然会慢慢加深，但起点可以很朴素：先愿意少一点只围着自己打转，多一点愿意让学习和练习对别人也有益处。然后再随着阅读、思考和练习慢慢加深。",
    answerEn: "Not necessarily. Understanding can deepen over time, but the starting point can be simple: become a little less self-enclosed and a little more willing for study and practice to benefit others too. Reading, reflection, and practice then deepen it gradually.",
  },
  {
    questionZh: "Fabushi 在培养菩提心这件事上最适合帮助什么？",
    questionEn: "What is Fabushi most useful for when trying to cultivate bodhicitta?",
    answerZh: "它更适合作为听诵、提醒和简短记录的辅助工具，帮助你把“今天的发心有没有留住”这件事慢慢接回日常。更深入的理解，仍然要回到佛法学习、经典导读和长期实践。",
    answerEn: "It works best as a support tool for listening, reminders, and short notes so the question of whether today’s intention stayed alive can return to daily rhythm. Deeper understanding still depends on study, scripture guides, and sustained practice.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "菩提心是什么意思",
    "菩提心",
    "发菩提心",
    "普门品 菩提心",
    "观音 慈悲",
    "六度分别是什么",
    "大乘佛教",
    "学佛入门",
    "佛法入门",
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

export default function WhatIsBodhicittaPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "菩提心是什么意思",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: ["菩提心", "发菩提心", "大乘佛教", "普门品", "六度"],
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
            item: siteUrl("/buddhist-concepts"),
          },
          {
            "@type": "ListItem",
            position: 4,
            name: "菩提心是什么意思",
            item: pageUrl,
          },
        ],
      },
      {
        "@type": "ItemList",
        name: "初学者理解菩提心的三个入口",
        itemListElement: entryPaths.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.titleZh,
          description: item.descriptionZh,
        })),
      },
      {
        "@type": "ItemList",
        name: "菩提心的经典与实践桥接路径",
        itemListElement: scriptureBridgeSteps.map((item, index) => ({
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
            <LocalizedText zh="菩提心" en="Bodhicitta" />
          </p>
          <h1>
            <LocalizedText
              zh="菩提心不是一句很高的口号，而是修行开始不只围着自己转的那一刻。"
              en="Bodhicitta is not a lofty slogan, but the moment practice stops circling only around oneself."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="很多人第一次听到“菩提心”，会觉得它太大、太远，像是很后面才该懂的东西。可更稳妥的理解，往往不是先把它想得很高，而是回到日常，看见自己的学习、说话、做事，是否开始有一点不只为了自己轻松一点，而也愿意让别人真正得益。"
              en="Many people first hear bodhicitta and feel it is too high and too far away, something for much later. A steadier understanding is not to place it above life, but to return to daily study, speech, and action and notice whether they are slowly becoming less self-enclosed and more genuinely beneficial to others."
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
              zh="很多人真正误会的，不是“菩提心重不重要”，而是把它想成太远、太大、太不像今天就能练的东西。"
              en="The deeper misunderstanding is often not whether bodhicitta matters, but imagining it as too distant and too large to be practiced today."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="有人一听到菩提心，就觉得那是大菩萨才谈的事，和初学者没什么关系；也有人把它理解成“要对所有人都很好”，结果不是空转，就是很快耗尽。可更稳妥的理解，往往不是把菩提心想成一句巨大的愿词，而是看见自己的修行是不是还只围着“我怎么舒服一点、我怎么少烦一点”打转，还是开始愿意让学习和练习对众生也有真实益处。"
              en="Some people hear bodhicitta and think it belongs only to great bodhisattvas, far from beginner practice. Others reduce it to being nice to everyone and quickly become vague or exhausted. A steadier understanding is to ask whether practice still circles only around personal comfort and relief, or whether it is beginning to let study and training become of genuine benefit to other beings as well."
            />
          </p>
          <p>
            <LocalizedText
              zh="所以，菩提心并不是否定自己的痛苦，也不是要求人立刻承担一切。很多人开始学佛，本来就是因为自己先有烦恼、先有困惑。菩提心真正加进来的，是一个更宽的方向：如果我真的越来越明白、越来越稳，这种明白和稳，能不能不只停在我这里？"
              en="Bodhicitta does not deny one’s own suffering, nor does it demand carrying everything immediately. Many people begin buddhadharma because their own confusion and pain are already present. What bodhicitta adds is a wider direction: if understanding and steadiness really grow, can they stop ending only with me?"
            />
          </p>
          <p>
            <LocalizedText
              zh="很多人第一次真正碰到菩提心，并不是在概念词条里，而是在读《普门品》、听观音圣号，或被慈悲与依止感安住时，开始隐约感觉修行不只为了自己轻松一点。可如果这一步没有被接回更清楚的概念和练习，感动很容易停在当下，过几天又散掉。把《普门品》、愿心和日常小练习重新接回同一条路上，菩提心才更容易从一时触动慢慢长成方向。"
              en="Many people first touch bodhicitta not through a concept page, but while reading the Universal Gate Chapter, hearing Guanyin recitation, or being steadied by compassion and refuge. Without a clearer bridge into concept and practice, that feeling can fade quickly. Returning the Universal Gate Chapter, aspiration, and small daily practice to the same path helps bodhicitta grow from a passing impression into direction."
            />
          </p>
          <p>
            <LocalizedText
              zh="对初学者来说，理解菩提心最可靠的方式，通常不是先讲得很大，而是让它慢慢落回每天怎样学习、怎样回应别人、怎样面对烦恼、怎样保持练习。传统修学常说闻、思、修要相续，菩提心真正能留下来的地方，也常常在这种一点一点的重复里。Fabushi 更适合承接其中听诵、提醒和简短记录的部分，帮助你把发心慢慢留在日常节奏里。"
              en="For beginners, the most reliable way to understand bodhicitta is usually not through large language, but by letting it return to how you study, respond to others, meet difficulty, and keep practicing each day. Traditional learning often speaks of hearing, reflection, and practice as one living sequence. Bodhicitta tends to remain through exactly that kind of repetition. Fabushi fits best on the listening, reminder, and short-note side of this rhythm so aspiration can stay inside ordinary life."
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
              zh="先把理解菩提心的三个基本判断放稳。"
              en="Set three basic judgments in place before thinking further about bodhicitta."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {bodhicittaFoundations.map((item) => (
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
            <LocalizedText zh="进入方式" en="Entry Paths" />
          </p>
          <h2>
            <LocalizedText
              zh="把菩提心放回眼前的人、眼前的事和每天的小练习里，通常会比空想更容易懂。"
              en="Bodhicitta becomes easier to understand when it returns to the people, situations, and small practices already in front of you."
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
              zh="先分清发心、愿心和怎样把它接回生活。"
              en="Clarify the arising of intention, aspiration, and the way it returns to life."
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

      <section className="band feature-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="下一步接哪里" en="Where to Go Next" />
          </p>
          <h2>
            <LocalizedText
              zh="把《普门品》里的慈悲、六度里的做法和日常功课里的小动作，重新接回同一条发心路径。"
              en="Return the compassion of scripture, the conduct of the paramitas, and the small actions of daily practice to one continuous path of aspiration."
            />
          </h2>
        </div>
        <div className="editorial-list">
          {scriptureBridgeSteps.map((item) => (
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

      <section className="band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="常见误区" en="Common Mistakes" />
          </p>
          <h2>
            <LocalizedText
              zh="先避开几个最容易把菩提心理解空、理解偏的误区。"
              en="Avoid the patterns that make bodhicitta vague, performative, or distorted."
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
              zh="把这张概念页接回更完整的入门、经典、修行和日常路径。"
              en="Use this concept page as a bridge back into the wider beginner, scripture, practice, and daily-life paths."
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
              zh="先回答初学者最容易在“菩提心是什么意思”上继续追问的几个问题。"
              en="Answer the questions beginners most often ask after meeting the idea of bodhicitta."
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
          <a className="secondary-action" href={siteHref("/buddhist-concepts")}>
            <LocalizedText zh="继续看佛学基本概念" en="Continue to Buddhist Concepts" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
