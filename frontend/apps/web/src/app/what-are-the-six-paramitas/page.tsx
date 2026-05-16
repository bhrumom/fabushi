import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/what-are-the-six-paramitas");
const pageTitle = `六度分别是什么 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理六度分别是什么：布施、持戒、忍辱、精进、禅定、般若不是孤立清单，而是把菩提心、修行方法与日常功课接回生活的六个方向。";

const sixParamitaFoundations = [
  {
    titleZh: "六度不是背熟六个词，而是让菩提心慢慢长出形状",
    titleEn: "The six paramitas are not six terms to memorize but six ways bodhicitta takes shape",
    descriptionZh: "很多人第一次听到六度，会先把它理解成一张需要背下来的佛学清单。更稳妥的理解是：六度是在说明，发心如果真的想慢慢落回生活，会怎样在待人、处事、练习和看问题的方式里一点点长出来。",
    descriptionEn: "Many people first hear the six paramitas as a buddhist list to memorize. A steadier view is that they describe how aspiration slowly takes shape in relationships, conduct, practice, and the way we see things.",
  },
  {
    titleZh: "六度彼此相连，不是修完一度才轮到下一度",
    titleEn: "The six paramitas support each other instead of appearing one by one in isolation",
    descriptionZh: "布施、持戒、忍辱、精进、禅定、般若并不是六门彼此分开的课。很多时候，一点稳定的禅修会帮助忍辱，一点更清楚的般若会帮助布施和持戒不走偏。它们更像同一条路上的不同面向。",
    descriptionEn: "Generosity, ethical discipline, patience, diligence, meditation, and wisdom are not six disconnected courses. A little steadier meditation can support patience, while clearer wisdom can keep generosity and discipline from becoming distorted. They are different faces of one path.",
  },
  {
    titleZh: "初学者不用一开始六度都做满，先从最容易落地的一度开始",
    titleEn: "Beginners do not need to perfect all six immediately and can begin with the most workable doorway",
    descriptionZh: "对多数初学者来说，六度最有帮助的地方，不是一下子把每一度都做得很满，而是先看自己现在最容易卡在哪一度，再从最能留下来的小动作开始。这样更容易把概念接回日常。",
    descriptionEn: "For most beginners, the value of the six paramitas is not filling out every one of them immediately, but noticing which one feels weakest right now and beginning with the smallest action that can actually stay alive.",
  },
] as const;

const sixParamitas = [
  {
    titleZh: "布施",
    titleEn: "Generosity",
    descriptionZh: "布施不只是给出东西，也包括愿不愿意把时间、注意力、耐心和善意给出去。对初学者来说，它常常是在提醒：修行不只是让自己舒服一点，也是在慢慢松开太紧的自我中心。",
    descriptionEn: "Generosity is not only about giving things away. It also includes whether you can offer time, attention, patience, and goodwill. For beginners, it often loosens a path that circles too tightly around the self.",
  },
  {
    titleZh: "持戒",
    titleEn: "Ethical Discipline",
    descriptionZh: "持戒不只是守一套外在规定，更是在提醒自己：哪些说话、做事和习惯会让心越来越浑，哪些会让方向越来越稳。它帮助修行不只停留在想法里，而回到每天怎样活。",
    descriptionEn: "Ethical discipline is not only a set of outer rules. It asks which habits, words, and actions make the mind more confused and which steady the direction of life. It returns practice to the way a day is actually lived.",
  },
  {
    titleZh: "忍辱",
    titleEn: "Patience",
    descriptionZh: "忍辱不是一味压住自己，也不是假装什么都没发生。更稳妥的理解，是在不顺、委屈、误会和烦躁出现时，不立刻被它们带着走，给自己一点空间，让心不要越走越窄。",
    descriptionEn: "Patience is not self-suppression or pretending nothing happened. It is the ability to meet frustration, misunderstanding, and agitation without immediately being dragged away by them, giving the mind some room to stay wider.",
  },
  {
    titleZh: "精进",
    titleEn: "Diligence",
    descriptionZh: "精进不是把自己逼得很紧，而是愿意一次一次再回来。对初学者来说，真正可靠的精进，往往不是今天做得很多，而是节奏断掉以后，明天还愿不愿意继续。",
    descriptionEn: "Diligence is not about driving yourself harshly. It is the willingness to return again and again. For beginners, its real sign is often not how much happened today, but whether you are willing to begin again tomorrow.",
  },
  {
    titleZh: "禅定",
    titleEn: "Meditation",
    descriptionZh: "禅定帮助心慢慢安住下来，让人不那么轻易被妄念和外境牵着走。它不只是一段坐下来的时间，也是在帮前面的布施、持戒、忍辱和精进有一个能安住和照见的基础。",
    descriptionEn: "Meditation helps the mind settle so it is less easily pulled around by thought and circumstance. It is not only a sitting period, but also a ground that supports generosity, discipline, patience, and diligence with greater steadiness and clarity.",
  },
  {
    titleZh: "般若",
    titleEn: "Wisdom",
    descriptionZh: "般若不是炫耀自己懂很多道理，而是慢慢看清：很多执着、烦恼和判断，为什么会把自己困住。它让六度不只变成“做好事”，而开始有更清楚的方向和看见。",
    descriptionEn: "Wisdom is not showing how much doctrine you know. It is the gradual seeing of why attachment, confusion, and fixed judgment keep trapping the mind. It gives the other paramitas direction and depth beyond merely doing good things.",
  },
] as const;

const practiceSequence = [
  {
    titleZh: "第一步：先看自己现在最容易卡在哪一度",
    titleEn: "Step 1: Notice which paramita feels weakest right now",
    descriptionZh: "有些人更容易卡在耐心，有些人更容易卡在持续性，也有人在关系里更容易看见布施和持戒的难处。先看清自己眼前最真实的一处，比抽象地想“六度都很重要”更容易开始。",
    descriptionEn: "Some people notice the difficulty first in patience, some in continuity, and some in generosity or discipline within relationships. Seeing the most immediate difficulty clearly is often more workable than repeating that all six matter equally.",
  },
  {
    titleZh: "第二步：把它接回说话、做事和固定练习里的一个小动作",
    titleEn: "Step 2: Return it to one small action in speech, conduct, or daily practice",
    descriptionZh: "如果这一度是真的重要，它最后一定要回到生活。例如今天少说一句更刺人的话、晚间多留两分钟回顾、练习断掉以后再回来一次，这些都比只在脑中理解更有力量。",
    descriptionEn: "If a paramita really matters, it has to return to life. Speaking one sharper sentence less, leaving two more minutes for review at night, or returning once more after the rhythm breaks often carries more force than understanding the idea only in the mind.",
  },
  {
    titleZh: "第三步：再用轻量记录看自己在哪一度慢慢稳下来",
    titleEn: "Step 3: Use a light review to see where steadiness is slowly appearing",
    descriptionZh: "不需要很重的笔记。只要记下今天在哪一度上更容易散乱、在哪一度上稍微稳一点，就能帮助自己看见六度不是远处的大词，而是在每天慢慢成形。Fabushi 更适合承接这种提醒和简短记录。",
    descriptionEn: "No heavy note-taking is needed. A short record of where you felt more scattered and where you felt a little steadier already shows that the six paramitas are not distant terms but directions slowly taking form each day. Fabushi fits well on this reminder-and-note side of the rhythm.",
  },
] as const;

const commonMistakes = [
  {
    titleZh: "把六度当成一张背诵清单，却没有回到日常处境",
    titleEn: "Treating the six paramitas as a memorization list without returning to daily life",
    descriptionZh: "如果六度只停留在“布施、持戒、忍辱、精进、禅定、般若”的背诵顺序里，它很容易变成离生活很远的知识点。真正更有力量的，是回到今天待人、说话、练习和面对烦恼时，它们有没有一点形状。",
    descriptionEn: "If the six paramitas stay only as a recited sequence, they easily become distant ideas. Their real force appears when they return to relationships, speech, practice, and the way confusion is met today.",
  },
  {
    titleZh: "只想修自己喜欢的一两度，完全不看其他几度的偏差",
    titleEn: "Holding to one or two favorite paramitas while ignoring the imbalance in the others",
    descriptionZh: "有些人喜欢谈布施，却不肯回头看持戒；有些人愿意坐禅，却不愿看自己在关系里有没有忍辱。六度彼此相连，只抓自己喜欢的部分，修行很容易越来越偏。",
    descriptionEn: "Some people like to speak about generosity but avoid discipline, while others are willing to meditate but refuse to look at patience in relationship. Because the six support each other, holding only the favorite parts can make the path increasingly lopsided.",
  },
  {
    titleZh: "以为六度要等懂很多教理、条件很好时才能开始",
    titleEn: "Assuming the six paramitas can begin only after you know a lot or have ideal conditions",
    descriptionZh: "其实多数初学者都可以从很小的地方开始。少一点急躁、多一点愿意回来，已经和忍辱、精进有关；今天说话更谨慎一点，也已经和持戒有关。六度并不只属于很后面的阶段。",
    descriptionEn: "Most beginners can begin with very small actions. A little less reactivity and a little more willingness to return already touch patience and diligence. Speaking a little more carefully already touches discipline. The six paramitas do not belong only to some distant stage.",
  },
] as const;

const relatedPaths = [
  {
    href: "/what-is-bodhicitta",
    labelZh: "菩提心是什么意思",
    labelEn: "What Bodhicitta Means",
    titleZh: "先回到六度最上游的发心。",
    titleEn: "Return to the intention that gives the six paramitas their direction.",
    descriptionZh: "如果你想先看清六度为什么会和大乘修学连在一起，可以先回到菩提心这一页。",
    descriptionEn: "Return here first if you want to see why the six paramitas belong so naturally to Mahayana aspiration.",
  },
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "把六度放回禅修、听诵、阅读和记录的节奏里。",
    titleEn: "Return the six paramitas to the rhythm of meditation, listening, reading, and notes.",
    descriptionZh: "如果你想知道六度怎样和修行方法互相支撑，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you want to see how the six paramitas support actual practice methods.",
  },
  {
    href: "/daily-practice",
    labelZh: "日常功课怎么安排",
    labelEn: "Daily Practice",
    titleZh: "把六度慢慢接回晨起、白天和晚间的小动作。",
    titleEn: "Bring the six paramitas back into small actions across morning, daytime, and evening.",
    descriptionZh: "如果你更关心六度怎样落进每天的生活节奏，这一页会更具体。",
    descriptionEn: "This page is more concrete if you want the six paramitas to land inside a daily rhythm.",
  },
  {
    href: "/buddhadharma",
    labelZh: "佛法入门",
    labelEn: "Dharma Basics",
    titleZh: "回到更完整的学佛入门地图。",
    titleEn: "Return to the broader beginner map for buddhadharma.",
    descriptionZh: "如果你还想先看佛法、修行、经典和概念词条之间的整体关系，这一页更适合先打开。",
    descriptionEn: "Open this first if you still want the wider map of buddhadharma, practice, scripture, and concept pages.",
  },
  {
    href: "/start-learning-buddhism",
    labelZh: "学佛从哪里开始",
    labelEn: "Where to Begin",
    titleZh: "先把起步问题放轻一点、放清楚一点。",
    titleEn: "Make the beginner question lighter and clearer first.",
    descriptionZh: "如果你现在还在找最适合自己的第一步，这一页会更适合先打开。",
    descriptionEn: "Return here first if you are still looking for the doorway that best fits your present question.",
  },
  {
    href: "/download",
    labelZh: "下载入口",
    labelEn: "Download",
    titleZh: "把提醒、听诵和简短记录放进日常。",
    titleEn: "Bring reminders, listening, and short notes into daily life.",
    descriptionZh: "准备借助 Fabushi 承接听诵、提醒和轻量记录时，可以直接查看下载入口。",
    descriptionEn: "Go straight to downloads when you are ready to use Fabushi for listening, reminders, and light notes.",
  },
] as const;

const faqItems = [
  {
    questionZh: "六度是不是一定要按顺序一度一度修完？",
    questionEn: "Do the six paramitas need to be completed one by one in order?",
    answerZh: "通常不是这样理解。六度彼此相连，很多时候会一起发生作用。初学者更适合先看自己现在最容易卡在哪一度，再从最能落地的小动作开始，而不是等“前一度修完”才碰下一度。",
    answerEn: "Usually not. The six paramitas support each other and often work together. Beginners usually do better by seeing which one feels weakest right now and beginning with the smallest workable action instead of waiting to finish one before touching the next.",
  },
  {
    questionZh: "六度是不是只有出家人或很后面的修行阶段才需要？",
    questionEn: "Are the six paramitas only for monastics or for a later stage of practice?",
    answerZh: "不是。六度当然可以很深，但它们也都能从很小的地方开始。今天更愿意让一步、更谨慎地说话、节奏断掉以后再回来一次，都已经和六度有关。",
    answerEn: "No. The six paramitas can become very deep, but they can also begin in very small ways. Giving a little more space, speaking a little more carefully, or returning after the rhythm breaks already belongs to this training.",
  },
  {
    questionZh: "般若是不是一定要懂很深的空性，才能算开始？",
    questionEn: "Does wisdom mean I need a deep understanding of emptiness before I can begin?",
    answerZh: "不一定。对初学者来说，般若可以先从更朴素的地方开始，例如慢慢看清哪些执着、判断和习惯正在让自己更苦。真正更深的义理会随着阅读、思惟和修行再慢慢展开，不必第一天就讲得很高。",
    answerEn: "Not necessarily. For beginners, wisdom can start more simply by seeing which attachments, judgments, and habits are deepening confusion. Deeper doctrine unfolds through reading, reflection, and practice over time and does not need to become lofty on day one.",
  },
  {
    questionZh: "六度和日常功课有什么关系？",
    questionEn: "How do the six paramitas connect with a daily practice routine?",
    answerZh: "六度不是离开生活另有一套功课。晨起有没有愿意回来、白天待人说话有没有更谨慎一点、晚间有没有回顾自己哪里更容易急躁或散乱，这些都已经在让六度慢慢回到日常。",
    answerEn: "The six paramitas are not a separate life away from ordinary routine. Returning in the morning, speaking more carefully during the day, and noticing where impatience or distraction grew at night are already ways they return to everyday life.",
  },
  {
    questionZh: "Fabushi 在理解六度这件事上最适合帮助什么？",
    questionEn: "What is Fabushi most useful for when reflecting on the six paramitas?",
    answerZh: "它更适合作为听诵、提醒和简短记录的辅助工具，帮助你把“今天哪一度更容易散乱、哪一度稍微稳一点”慢慢接回生活。更深入的义理理解，仍然要回到佛法学习、导读和持续修行本身。",
    answerEn: "It works best as a support tool for listening, reminders, and short notes so the question of where you felt more scattered or more steady today can return to daily life. Deeper understanding still depends on study, guides, and sustained practice.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "六度分别是什么",
    "六度",
    "六度波罗蜜",
    "布施持戒忍辱精进禅定般若",
    "菩提心",
    "大乘修行",
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

export default function WhatAreTheSixParamitasPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "六度分别是什么",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: ["六度", "六度波罗蜜", "菩提心", "大乘修行"],
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
            name: "六度分别是什么",
            item: pageUrl,
          },
        ],
      },
      {
        "@type": "ItemList",
        name: "六度的六个修学方向",
        itemListElement: sixParamitas.map((item, index) => ({
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
            <LocalizedText zh="六度" en="Six Paramitas" />
          </p>
          <h1>
            <LocalizedText
              zh="六度不是六个要背熟的名词，而是把菩提心慢慢活成日常修行的六条路。"
              en="The six paramitas are not six terms to memorize, but six ways aspiration becomes daily practice."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="很多人第一次听到六度，会觉得它很大、很远，像是要等懂很多教理以后才谈得到。更稳妥的理解，往往不是先把它想得很高，而是回到今天：待人、说话、忍耐、精进、安住和看问题的方式，有没有慢慢在改变。"
              en="Many people first hear the six paramitas and feel they are distant, advanced, and far beyond a beginner’s stage. A steadier understanding is to return to today and ask whether speech, conduct, patience, diligence, steadiness, and the way you see things are slowly changing."
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
              zh="很多人真正误会的，不是“六度重不重要”，而是把它想成离生活太远的一张佛学清单。"
              en="The deeper misunderstanding is often not whether the six paramitas matter, but imagining them as a distant list unrelated to ordinary life."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="有人一听到六度，就先想到“布施、持戒、忍辱、精进、禅定、般若”这六个词，接着很快觉得自己离它太远，好像要等学得很深、修得很多以后才有资格去谈。可更稳妥的理解，往往不是把六度想成很远的理想，而是看见：如果菩提心真的开始从一句口号变成生命方向，它最后一定会回到给与、节制、忍耐、持续、安住和智慧上。"
              en="Some people hear the six paramitas as six buddhist terms and quickly feel they are far away, as if one must study deeply before even speaking about them. A steadier understanding is that if bodhicitta really becomes a life direction instead of a slogan, it must eventually return to giving, restraint, patience, continuity, steadiness, and wisdom."
            />
          </p>
          <p>
            <LocalizedText
              zh="所以，六度不是和生活分开的另一套课程。它更像是在提醒人：修行不只是在安静的时候坐一坐，也会反映在今天怎么说话、怎么回应不顺、怎么把节奏接回来、怎么少一点只围着自己打转。对初学者来说，六度最有帮助的地方，不是一次把六个方向都做满，而是先找到自己现在最容易卡住的那一度。"
              en="The six paramitas are therefore not a separate course outside of life. They remind us that practice does not only happen in quiet formal moments, but also in how we speak today, respond to difficulty, return to rhythm, and loosen a path that circles too tightly around the self. For beginners, their real value is not filling out all six at once, but seeing which one feels most difficult right now."
            />
          </p>
          <p>
            <LocalizedText
              zh="传统修学常说闻、思、修要相续。六度真正能留下来的地方，也常常是在这种一点一点的重复里：听到一句提醒以后，今天多忍一下；练习断掉以后，明天再回来；做完一件事以后，回头看自己是更收缩了，还是更宽一点。Fabushi 更适合承接其中听诵、提醒和简短记录的部分，帮助你把六度慢慢接回日常。"
              en="Traditional learning often speaks of hearing, reflection, and practice as a living sequence. The six paramitas stay alive through this kind of repetition: after hearing one reminder, you endure a little more today; after the rhythm breaks, you return tomorrow; after one action, you ask whether the mind became tighter or wider. Fabushi fits best on the listening, reminder, and short-note side of this rhythm."
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
              zh="先把理解六度的三个基本判断放稳。"
              en="Set three basic judgments in place before going further into the six paramitas."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {sixParamitaFoundations.map((item) => (
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
            <LocalizedText zh="六个方向" en="Six Directions" />
          </p>
          <h2>
            <LocalizedText
              zh="先把六度放回待人、处事、练习和看问题的方式里。"
              en="Return the six paramitas to relationships, conduct, practice, and the way you see things."
            />
          </h2>
        </div>
        <div className="editorial-list">
          {sixParamitas.map((item) => (
            <article key={item.titleEn} className="editorial-row static-row">
              <span>
                <LocalizedText zh={item.titleZh} en={item.titleEn} />
              </span>
              <div>
                <strong>
                  <LocalizedText zh={item.titleZh} en={item.titleEn} />
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
            <LocalizedText zh="开始方式" en="How to Begin" />
          </p>
          <h2>
            <LocalizedText
              zh="把六度接回一个小动作，通常会比空想更容易真的开始。"
              en="The six paramitas usually begin more easily through one small action than through abstract reflection alone."
            />
          </h2>
        </div>
        <div className="path-grid">
          {practiceSequence.map((item) => (
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

      <section className="band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="常见误区" en="Common Mistakes" />
          </p>
          <h2>
            <LocalizedText
              zh="先避开几个最容易把六度理解空、理解偏的误区。"
              en="Avoid the patterns that make the six paramitas vague, imbalanced, or overly distant."
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
              zh="把这张概念页接回更完整的入门、发心、方法和日常路径。"
              en="Use this concept page as a bridge back into the wider beginner, aspiration, practice, and daily-life paths."
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
              zh="先回答初学者最容易在“六度分别是什么”上继续追问的几个问题。"
              en="Answer the questions beginners most often ask after meeting the six paramitas."
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
          <a className="secondary-action" href={siteHref("/what-is-bodhicitta")}>
            <LocalizedText zh="返回菩提心是什么意思" en="Back to What Bodhicitta Means" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
