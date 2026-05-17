import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/what-is-emptiness");
const pageTitle = `空性怎么理解 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理空性怎么理解：空性不是什么都没有，也不是把世界否定掉，而是帮助人看见一切法因缘和合、没有固定不变的自性，并把《心经》里常遇到的“空”接回六度、菩提心、佛学基本概念与日常练习。";

const emptinessFoundations = [
  {
    titleZh: "空性不是“什么都没有”，而是看见一切并不是我们以为的那样固定",
    titleEn: "Emptiness is not nothingness but seeing that things are less fixed than we usually imagine",
    descriptionZh: "很多人第一次听到空性，会误以为佛法在说世界都是假的，或者什么都不必认真。更稳妥的理解是：空性是在提醒我们，很多事物都依赖因缘条件而成立，没有一个永远独立、永远不变的“固定样子”。",
    descriptionEn: "Many people first hear emptiness and think buddhadharma is saying the world is unreal or nothing matters. A steadier understanding is that emptiness points out how things arise through conditions rather than existing as permanently independent and fixed entities.",
  },
  {
    titleZh: "理解空性，不是为了把生活否定掉，而是为了少一点被执着拖着走",
    titleEn: "Understanding emptiness does not cancel life but helps loosen the grip of attachment",
    descriptionZh: "如果把人、事、情绪和判断都抓得太死，烦恼会变得很重。空性的价值，不是在抽离生活，而是在生活里慢慢看见：原来很多痛苦，都和我们把事情看得太实、太绝对有关。",
    descriptionEn: "When people, events, emotions, and judgments are held too rigidly, suffering becomes heavier. The value of emptiness is not escaping life but noticing inside life how much pain comes from treating things as more solid and absolute than they are.",
  },
  {
    titleZh: "空性和慈悲、修行方法并不分开，反而会让心更柔软也更清醒",
    titleEn: "Emptiness does not stand apart from compassion and practice, but can make the mind softer and clearer",
    descriptionZh: "有些人担心理解空性以后会变冷、变淡。更稳妥的理解恰好相反：越能看见一切都因缘和合，越不容易只站在自己的执着里看问题，也越容易生起耐心、宽度和慈悲。",
    descriptionEn: "Some people worry that understanding emptiness will make the heart cold or detached. A steadier view is the opposite: the more we see dependent arising clearly, the less tightly we cling to self-centered perspectives and the more room there is for patience, breadth, and compassion.",
  },
] as const;

const entryPaths = [
  {
    titleZh: "第一步：先从“不是固定不变”开始，而不急着追求很高的义理表达",
    titleEn: "Step 1: Begin with seeing that things are less fixed, without rushing toward lofty doctrine",
    descriptionZh: "初学者不必一开始就把空性讲得很高。更可行的起点，是先在生活里观察：情绪会变、关系会变、判断会变，很多苦也会随着条件变化而转。先从这里理解，会比急着背很多术语更稳。",
    descriptionEn: "Beginners do not need to speak about emptiness in lofty terms immediately. A more workable start is to notice in life that emotions, relationships, and judgments all shift, and that suffering also changes with conditions. This is usually steadier than rushing to memorize doctrine.",
  },
  {
    titleZh: "第二步：把“因缘和合”放回自己最容易执着的地方看",
    titleEn: "Step 2: Return dependent arising to the places where attachment feels strongest",
    descriptionZh: "可以先看自己最容易卡住的是哪一类事：一句话被误解、一次失误、一个身份、一次得失。再慢慢练习问自己：这件事真有我现在感受到的那么绝对、那么固定吗？这样更容易让空性回到现实处境。",
    descriptionEn: "Notice where you cling most strongly: a misunderstood sentence, a mistake, an identity, a gain or loss. Then ask whether the situation is really as absolute and fixed as it feels in the moment. This makes emptiness return to real life instead of remaining abstract.",
  },
  {
    titleZh: "第三步：再让阅读、思惟和日常练习慢慢把理解带深一点",
    titleEn: "Step 3: Let reading, reflection, and daily practice deepen the understanding gradually",
    descriptionZh: "空性不只是想一想就会稳下来。可以先配合导读、经典阅读、短时禅修和简单记录，让自己慢慢看见：执着一松，心怎么会更开一点。Fabushi 更适合承接其中听诵、提醒和简短记录的部分。",
    descriptionEn: "Emptiness does not become steady through a single thought. It deepens through guides, scripture reading, short meditation, and simple review that slowly reveal what happens when clinging softens. Fabushi fits best on the listening, reminder, and short-note side of this rhythm.",
  },
] as const;

const conceptBlocks = [
  {
    titleZh: "因缘和合",
    titleEn: "Dependent arising",
    descriptionZh: "可以先把空性放回因缘和合来理解：很多事物之所以如此呈现，是因为许多条件暂时聚在一起。条件变动，结果也会变动，所以不适合被看成一个永远固定的实在。",
    descriptionEn: "A simple doorway into emptiness is dependent arising: things appear as they do because many conditions gather together temporarily. When conditions change, the result changes too, which is why things are not well understood as eternally fixed realities.",
  },
  {
    titleZh: "无固定自性",
    titleEn: "No fixed self-nature",
    descriptionZh: "这不是说什么都不存在，而是说事物没有一个脱离条件、永远独立不变的本质。这样理解，更容易帮助人松开“它一定就是这样”“我一定就是这样”的抓取。",
    descriptionEn: "This does not mean nothing exists. It means things do not carry a self-existing essence that stands outside conditions. Seen this way, it becomes easier to loosen the grasp that says, 'It must be exactly this way' or 'I must be exactly this way.'",
  },
  {
    titleZh: "中道的理解",
    titleEn: "A middle way understanding",
    descriptionZh: "空性既不落在“什么都没有”的断灭，也不落在“万事万物都固定真实不变”的实有。更稳妥的方向，是一边承认缘起显现，一边不把这些显现抓成永恒不变的实在。",
    descriptionEn: "Emptiness falls neither into the extreme of nothing existing nor into the view that all things are solid and unchanging. The steadier direction is to acknowledge appearances and dependent arising without treating them as permanent absolutes.",
  },
] as const;

const scriptureBridgeSteps = [
  {
    href: "/beginner-sutra-recommendations",
    labelZh: "从《心经》接到空性",
    labelEn: "Heart Sutra to Emptiness",
    titleZh: "如果你是先在《心经》里反复碰到“空”这个字，下一步先把它从熟悉的经句接回更可用的理解。",
    titleEn: "If the Heart Sutra is where the word emptiness first keeps returning, the next step is to bring it from familiar lines into more usable understanding.",
    descriptionZh: "很多人第一次真正碰到空性，不是在概念页里，而是在《心经》或般若类经典的语言里。把这一步说清楚，经典阅读才不容易只停在声音熟悉，却始终不敢继续往前。",
    descriptionEn: "Many people first truly meet emptiness not on a concept page, but in the language of the Heart Sutra or other wisdom texts. Clarifying that bridge helps scripture study move beyond familiar sound into real continuation.",
  },
  {
    href: "/what-are-the-six-paramitas",
    labelZh: "从空性接到六度",
    labelEn: "Emptiness to Six Paramitas",
    titleZh: "如果你已经知道空性不是“什么都没有”，下一步更值得看它怎样回到般若、六度和做人做事里。",
    titleEn: "If emptiness is no longer just mistaken for nothingness, the next useful step is to see how it returns to wisdom, the six paramitas, and ordinary conduct.",
    descriptionZh: "很多人会在这里继续追问：为什么空性不会只停在观念里，而会慢慢回到布施、持戒、忍辱、精进、禅定这些更具体的练习方向？这正是六度最自然接进来的地方。",
    descriptionEn: "Many readers continue by asking why emptiness does not stay as an idea, but gradually returns to generosity, discipline, patience, diligence, and meditation. This is exactly where the six paramitas enter most naturally.",
  },
  {
    href: "/daily-practice",
    labelZh: "从“少一点抓得太死”接回日常功课",
    labelEn: "Loosening Grasping to Daily Practice",
    titleZh: "如果你最关心的是怎样让“少一点僵硬”不只停在理解里，下一步先把它接回晨起、白天和晚间的小练习。",
    titleEn: "If your main concern is how loosening rigid grasping can live beyond explanation, the next step is to return it to small practices across morning, daytime, and evening.",
    descriptionZh: "空性的理解真正留得住，往往不是靠一次想明白，而是靠很轻但持续的功课，让自己在一天里一次次少一点抓死、多一点回观。",
    descriptionEn: "Understanding emptiness usually stays alive not through one decisive insight, but through a light and continuous routine that slowly weakens rigid grasping across the day.",
  },
] as const;

const commonMistakes = [
  {
    titleZh: "把空性理解成“反正什么都没有，所以怎样都无所谓”",
    titleEn: "Turning emptiness into a reason that nothing matters",
    descriptionZh: "这通常会把空性理解偏。佛法不是要人否定因果、责任和关系，而是帮助人看见它们都在因缘中成立，因此更需要清醒和负责，而不是更轻慢。",
    descriptionEn: "This twists emptiness in an unhelpful direction. Buddhadharma is not asking us to deny karma, responsibility, or relationship, but to see that they arise through conditions and therefore call for more clarity and care, not less.",
  },
  {
    titleZh: "把空性说得很高，却没有回到眼前的烦恼和执着",
    titleEn: "Speaking about emptiness loftily without returning to actual attachment and confusion",
    descriptionZh: "如果空性只是口头上的漂亮理解，几天以后往往就散了。更可靠的做法，是回到今天哪一件事最让自己卡住，再慢慢看见里面哪些“固定想法”正在让苦变重。",
    descriptionEn: "If emptiness remains only an elegant idea, it usually fades quickly. The more reliable way is to return to the situation that feels most painful today and slowly notice which fixed assumptions are making the suffering heavier.",
  },
  {
    titleZh: "以为空性和慈悲、修行方法是分开的两条路",
    titleEn: "Assuming emptiness is separate from compassion and practice methods",
    descriptionZh: "真正稳的理解，往往会让人更不那么僵硬地看自己和别人，也更愿意回到禅修、阅读、持戒和日常练习里。空性不是把人带离修行，而是让修行更少落在执着里。",
    descriptionEn: "A steadier understanding often makes the mind less rigid toward self and others, and more willing to return to meditation, reading, ethical care, and daily practice. Emptiness does not pull someone away from practice, but helps practice carry less clinging.",
  },
] as const;

const relatedPaths = [
  {
    href: "/buddhadharma",
    labelZh: "佛法入门",
    labelEn: "Dharma Basics",
    titleZh: "先回到更完整的学佛入门地图。",
    titleEn: "Return to the broader beginner map for buddhadharma.",
    descriptionZh: "如果你还想先看清佛法、修行、经典和概念词条之间的整体关系，这一页更适合先打开。",
    descriptionEn: "Open this first if you still want the wider map of buddhadharma, practice, scripture, and concept pages.",
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
    descriptionZh: "如果你已经发现自己的问题不只停在空性一个词上，而是开始和因果、菩提心、六度连在一起，这一页会更适合先打开。",
    descriptionEn: "Open this first if your question is no longer only about emptiness and is beginning to connect with karma, bodhicitta, and the six paramitas as well.",
  },
  {
    href: "/what-is-karma",
    labelZh: "因果是什么意思",
    labelEn: "What Karma Means",
    titleZh: "把空性放回因缘、行为和结果里一起理解。",
    titleEn: "Read emptiness together with conditions, action, and results.",
    descriptionZh: "如果你想把“因缘和合”放回因果、习惯和日常选择里一起看，这一页更适合继续往下走。",
    descriptionEn: "This is the better next page if you want to read dependent arising together with karma, habits, and ordinary choices.",
  },
  {
    href: "/what-is-bodhicitta",
    labelZh: "菩提心是什么意思",
    labelEn: "What Bodhicitta Means",
    titleZh: "把智慧和慈悲怎样一起长出来放回同一条路上。",
    titleEn: "See how wisdom and compassion grow together on the same path.",
    descriptionZh: "如果你想理解空性为什么不会让心变冷，反而更容易生起菩提心，这一页会更适合继续往下看。",
    descriptionEn: "This page is the better next step if you want to understand why emptiness need not make the heart cold and can instead support bodhicitta.",
  },
  {
    href: "/what-are-the-six-paramitas",
    labelZh: "六度分别是什么",
    labelEn: "Six Paramitas",
    titleZh: "把般若怎样落回六度和日常练习里接起来。",
    titleEn: "See how wisdom returns to the six paramitas and daily practice.",
    descriptionZh: "如果你想知道空性和般若为什么会和布施、持戒、忍辱、精进、禅定一起出现，这一页更适合继续往下看。",
    descriptionEn: "This is the better next page if you want to see why wisdom and emptiness appear together with generosity, discipline, patience, diligence, and meditation.",
  },
  {
    href: "/sutra-guide",
    labelZh: "佛经导读",
    labelEn: "Sutra Guide",
    titleZh: "从经典阅读里慢慢接近般若与空性的语言。",
    titleEn: "Approach the language of wisdom and emptiness through scripture study.",
    descriptionZh: "如果你想知道初学者怎样借由导读与经典慢慢理解空性，这一页会更适合继续往下走。",
    descriptionEn: "This page is the better next stop if you want to approach emptiness gradually through guides and scripture reading.",
  },
  {
    href: "/beginner-sutra-recommendations",
    labelZh: "初学者佛经推荐",
    labelEn: "Beginner Sutra Picks",
    titleZh: "从更适合初学者的经典入口慢慢接近空性。",
    titleEn: "Approach emptiness through beginner-friendly scripture entry points.",
    descriptionZh: "如果你想从《心经》或其他更适合初学者的经典入口慢慢熟悉空性的表达，这一页会更具体。",
    descriptionEn: "This page is more specific if you want to approach emptiness through the Heart Sutra or other scripture entry points suited to beginners.",
  },
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "把空性的理解慢慢接回禅修、听诵、阅读和记录。",
    titleEn: "Return the understanding of emptiness to meditation, listening, reading, and notes.",
    descriptionZh: "如果你更关心空性怎样落回练习方式，而不只是停在概念上，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you want emptiness to return to actual practice methods instead of remaining abstract.",
  },
  {
    href: "/daily-practice",
    labelZh: "日常功课怎么安排",
    labelEn: "Daily Practice",
    titleZh: "让“少一点抓得太死”的理解慢慢回到每天的小动作里。",
    titleEn: "Let the understanding of loosening rigid grasp return to the small actions of a day.",
    descriptionZh: "如果你想把空性从概念接回晨起、白天和晚间的日常节奏，这一页会更具体。",
    descriptionEn: "This page is more concrete if you want emptiness to return from concept into morning, daytime, and evening rhythm.",
  },
  {
    href: "/download",
    labelZh: "下载入口",
    labelEn: "Download",
    titleZh: "把听诵、提醒和简短记录放进日常。",
    titleEn: "Bring listening, reminders, and short notes into daily life.",
    descriptionZh: "准备借助 Fabushi 承接听诵、提醒和轻量记录时，可以直接查看下载入口。",
    descriptionEn: "Go straight to downloads when you are ready to use Fabushi for listening, reminders, and light notes.",
  },
] as const;

const faqItems = [
  {
    questionZh: "空性是不是就是“什么都没有”？",
    questionEn: "Does emptiness mean that nothing exists at all?",
    answerZh: "通常不是这样理解。更稳妥的方向，是说一切法都依赖因缘条件而成立，没有一个永远固定、不依赖任何条件的自性。它不是把生活否定掉，而是帮助人少一点把事情抓得太实、太绝对。",
    answerEn: "Usually not. A steadier understanding is that all phenomena arise through conditions and do not possess an eternal self-existing essence. Emptiness does not cancel life, but helps loosen the tendency to treat things as too solid and absolute.",
  },
  {
    questionZh: "《心经》和空性有什么关系？",
    questionEn: "What does the Heart Sutra have to do with emptiness?",
    answerZh: "很多人第一次真正碰到空性，不是在抽象定义里，而是在《心经》反复听到“色即是空、空即是色”这些句子的时候。问题通常不在于先把每一句都解释完整，而在于先知道：这些句子不是在说“什么都没有”，而是在帮人松开把经验抓得太实、太绝对的习惯。把这一步理清，再回头读《心经》，往往更容易读进去。",
    answerEn: "Many readers first truly meet emptiness through lines in the Heart Sutra rather than abstract definitions. The key is not to explain every phrase immediately, but to understand that these lines are not saying nothing exists. They help loosen rigid grasping so returning to the sutra becomes easier.",
  },
  {
    questionZh: "空性会不会让人变冷漠，觉得什么都无所谓？",
    questionEn: "Will emptiness make a person cold or indifferent, as if nothing matters?",
    answerZh: "如果理解偏了，可能会这样说，但那通常不是佛法要表达的方向。更稳的理解，反而会让人少一点站在自我中心的执着里，更容易看见别人和自己都在因缘里受苦，因此更容易生起耐心和慈悲。",
    answerEn: "A distorted understanding can sound that way, but that is usually not the direction buddhadharma points toward. A steadier understanding often weakens self-centered attachment and makes it easier to see how both self and others suffer through conditions, which can support patience and compassion.",
  },
  {
    questionZh: "初学者一定要先把空性弄得很深，才算学佛吗？",
    questionEn: "Must a beginner understand emptiness deeply before they can really begin buddhadharma?",
    answerZh: "不一定。初学者可以先从更朴素的地方开始，例如看见很多情绪、判断和痛苦并没有想象中那样固定，再随着导读、经典阅读、思惟和练习慢慢把理解带深。",
    answerEn: "Not necessarily. Beginners can start more simply by noticing that many emotions, judgments, and pains are less fixed than they seem, then deepen that understanding gradually through guides, scripture, reflection, and practice.",
  },
  {
    questionZh: "空性和因果会不会矛盾？",
    questionEn: "Do emptiness and karma contradict each other?",
    answerZh: "通常不需要这样理解。正因为一切都在因缘条件中成立，行为、习惯和结果才会彼此影响。空性不是取消因果，反而能帮助人少一点用僵硬的方式理解因果。",
    answerEn: "Usually not. Precisely because things arise through conditions, actions, habits, and results influence one another. Emptiness does not cancel karma, but can help us understand karma with less rigidity.",
  },
  {
    questionZh: "空性和六度是什么关系？",
    questionEn: "How are emptiness and the six paramitas related?",
    answerZh: "可以把空性看成帮助心少一点执著的般若方向，把六度看成这种方向慢慢长成布施、持戒、忍辱、精进、禅定和般若的练习路径。没有空性的照见，六度容易只剩条目；没有六度，空性的理解也容易只停在观念里。",
    answerEn: "You can think of emptiness as the wisdom direction that loosens grasping, and the six paramitas as the way that direction becomes generosity, discipline, patience, diligence, meditation, and wisdom in practice. Without emptiness, the paramitas can shrink into a list. Without the paramitas, emptiness can remain only an idea.",
  },
  {
    questionZh: "Fabushi 在理解空性这件事上最适合帮助什么？",
    questionEn: "What is Fabushi most useful for when reflecting on emptiness?",
    answerZh: "它更适合作为听诵、提醒和简短记录的辅助工具，帮助你把“今天哪些地方抓得太死、哪些地方稍微松一点”慢慢接回日常。更深入的义理理解，仍然要回到佛法学习、导读和持续修行本身。",
    answerEn: "It works best as a support tool for listening, reminders, and short notes so the question of where the mind felt rigid and where it softened can return to daily life. Deeper doctrinal understanding still depends on study, guides, and sustained practice.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "空性怎么理解",
    "空性",
    "什么是空性",
    "心经 空性",
    "佛学基本概念",
    "六度分别是什么",
    "菩提心是什么意思",
    "般若",
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

export default function WhatIsEmptinessPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "空性怎么理解",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: ["空性", "般若", "因缘和合", "心经", "六度", "佛学基本概念入门"],
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
            name: "空性怎么理解",
            item: pageUrl,
          },
        ],
      },
      {
        "@type": "ItemList",
        name: "初学者理解空性的三个入口",
        itemListElement: entryPaths.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.titleZh,
          description: item.descriptionZh,
        })),
      },
      {
        "@type": "ItemList",
        name: "空性的经典与实践桥接路径",
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
            <LocalizedText zh="空性" en="Emptiness" />
          </p>
          <h1>
            <LocalizedText
              zh="空性不是一句很高的玄谈，而是帮助人少一点把自己和世界抓得太死。"
              en="Emptiness is not an abstract slogan, but a way of loosening the mind’s rigid grip on self and world."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="很多人第一次听到“空性”，会觉得它太远、太难，像是很后面才该懂的东西。可更稳妥的理解，往往不是先把它想得很高，而是先看见：很多让自己很苦的执着、判断和情绪，其实并没有想象中那样固定。"
              en="Many people first hear emptiness and feel it is too remote and difficult, something for much later. A steadier understanding is to begin by noticing that many attachments, judgments, and emotions that feel overwhelming are less fixed than they first appear."
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
              zh="很多人真正误会的，不是“空性重不重要”，而是把它听成“什么都没有”或“什么都无所谓”。"
              en="The deeper misunderstanding is often not whether emptiness matters, but hearing it as either nothing exists or nothing matters."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="有人一听到空性，就觉得佛法是不是在说世界都是假的，所以什么都不必当真；也有人一听到“无我”“无自性”，就觉得这离日常生活太远，根本碰不得。可更稳妥的理解，往往不是把空性想成一种否定，而是看见：我们平常之所以苦，很大一部分正因为把人、事、情绪和得失抓得太固定、太绝对。"
              en="Some people hear emptiness and wonder whether buddhadharma is saying the world is unreal and therefore nothing needs to be taken seriously. Others hear talk of no-self or no fixed nature and feel it is too remote from daily life to approach at all. A steadier understanding is to notice how much suffering comes from treating people, events, emotions, and gains and losses as too fixed and absolute."
            />
          </p>
          <p>
            <LocalizedText
              zh="所以，空性并不是把生活否定掉，也不是叫人逃开关系、责任和因果。恰好相反，正因为一切都在因缘条件里成立，所以今天怎么说话、怎么起心动念、怎么回应别人，才会一点一点形成结果。看见这一点，常常会让人少一点僵硬，多一点宽度，也更愿意回到修行。"
              en="Emptiness therefore does not cancel life, nor does it invite us to escape relationship, responsibility, or karma. On the contrary, because everything arises through conditions, the way we speak, intend, and respond matters deeply and gradually forms results. Seeing this often softens rigidity, widens the mind, and makes it easier to return to practice."
            />
          </p>
          <p>
            <LocalizedText
              zh="很多人第一次真正碰到空性，并不是在概念词条里，而是在《心经》或般若类经典的语言里，先反复听到“色即是空、空即是色”这一类句子。可如果这一步没有被接回更清楚的概念和练习，熟悉的经句很容易只停在声音里，下一步该往哪里走却还是不清楚。把《心经》、六度和日常功课重新接回同一条路上，空性才更容易从一时触动慢慢长成可用的理解。"
              en="Many people first truly meet emptiness not through a glossary page, but in the language of the Heart Sutra and other wisdom texts. Without a clearer bridge into concept and practice, familiar lines can remain only familiar sounds while the next step still feels unclear. Returning the Heart Sutra, the six paramitas, and daily practice to one continuous path helps emptiness grow from a passing impression into usable understanding."
            />
          </p>
          <p>
            <LocalizedText
              zh="传统修学常说闻、思、修要相续。空性的理解也是这样：先借由导读和经典慢慢熟悉语言，再回到眼前最容易执着的一件事上去看，最后用一点禅修、听诵和简短记录让自己常常记得“不要抓得太死”。Fabushi 更适合承接其中听诵、提醒和轻量记录的部分。"
              en="Traditional learning often speaks of hearing, reflection, and practice as a living sequence. Emptiness ripens in the same way: begin with guides and scripture language, return to the situation where attachment feels strongest, and then let a little meditation, listening, and brief review remind you not to cling so tightly. Fabushi fits best on the listening, reminder, and light-note side of this rhythm."
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
              zh="先把理解空性的三个基本判断放稳。"
              en="Set three basic judgments in place before going further into emptiness."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {emptinessFoundations.map((item) => (
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
              zh="把空性放回眼前最容易执着的地方看，通常会比空想更容易懂。"
              en="Emptiness usually becomes clearer when it returns to the places where attachment feels strongest."
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
              zh="先分清因缘和合、无固定自性，以及为什么这不等于否定生活。"
              en="Clarify dependent arising, no fixed self-nature, and why this does not cancel ordinary life."
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
              zh="把《心经》里的般若语言、六度里的做法和日常功课里的小动作，重新接回同一条理解路径。"
              en="Return the wisdom language of scripture, the conduct of the paramitas, and the small actions of daily practice to one continuous path of understanding."
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
              zh="先避开几个最容易把空性理解空、理解偏的误区。"
              en="Avoid the patterns that make emptiness sound vague, extreme, or disconnected from practice."
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
              zh="把这张概念页接回更完整的入门、经典、发心、方法和日常路径。"
              en="Use this concept page as a bridge back into the wider beginner, scripture, aspiration, practice, and daily-life paths."
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
              zh="先回答初学者最容易在“空性怎么理解”上继续追问的几个问题。"
              en="Answer the questions beginners most often ask after meeting the idea of emptiness."
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
