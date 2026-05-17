import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/daily-practice");
const pageTitle = `日常功课怎么安排 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理日常功课怎么安排：晨起、白天与晚间可以怎样放进禅修、经文听诵、念佛、阅读与简短回顾，先读什么佛经更合适、听诵以后怎样接回晨起与晚间阅读，以及怎样把《心经》《阿弥陀经》《普门品》《金刚经》的入口真正留在生活里。";

const cardStyles = `
  .practice-card-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 18px;
  }

  .practice-card-shell {
    display: grid;
    gap: 12px;
  }

  .practice-card-toggle {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
  }

  .practice-card {
    position: relative;
    display: block;
    min-height: 368px;
    cursor: pointer;
    perspective: 1800px;
  }

  .practice-card-toggle:focus-visible + .practice-card {
    outline: 2px solid var(--gold-soft);
    outline-offset: 4px;
    border-radius: 8px;
  }

  .practice-card-inner {
    position: relative;
    min-height: 368px;
    transform-style: preserve-3d;
    transition: transform 760ms cubic-bezier(0.22, 0.61, 0.36, 1);
  }

  .practice-card:hover .practice-card-inner,
  .practice-card-toggle:checked + .practice-card .practice-card-inner {
    transform: rotateY(180deg);
  }

  .practice-card-face {
    position: absolute;
    inset: 0;
    display: grid;
    align-content: start;
    gap: 16px;
    padding: 22px;
    border: 1px solid var(--line);
    border-radius: 8px;
    background: linear-gradient(180deg, rgba(255, 249, 235, 0.08), rgba(10, 15, 22, 0.96));
    box-shadow: var(--shadow);
    backface-visibility: hidden;
  }

  .practice-card-back {
    transform: rotateY(180deg);
    align-content: space-between;
    background: linear-gradient(180deg, rgba(8, 12, 18, 0.98), rgba(18, 24, 34, 0.98));
  }

  .practice-card-visual {
    position: relative;
    min-height: 148px;
    border: 1px solid var(--line);
    border-radius: 8px;
    overflow: hidden;
    padding: 18px;
    display: grid;
    align-content: end;
    gap: 8px;
    background:
      radial-gradient(circle at top right, rgba(255, 249, 235, 0.2), transparent 42%),
      linear-gradient(145deg, rgba(232, 189, 107, 0.16), rgba(120, 214, 232, 0.1));
  }

  .practice-card-visual::before,
  .practice-card-visual::after {
    content: "";
    position: absolute;
    border-radius: 999px;
    border: 1px solid rgba(255, 249, 235, 0.18);
    opacity: 0.7;
  }

  .practice-card-visual::before {
    inset: 14px 18px auto auto;
    width: 84px;
    height: 84px;
  }

  .practice-card-visual::after {
    inset: auto auto 14px 18px;
    width: 120px;
    height: 120px;
  }

  .practice-tone-gold .practice-card-visual {
    background:
      radial-gradient(circle at top right, rgba(255, 227, 163, 0.24), transparent 42%),
      linear-gradient(145deg, rgba(232, 189, 107, 0.22), rgba(120, 214, 232, 0.08));
  }

  .practice-tone-cyan .practice-card-visual {
    background:
      radial-gradient(circle at top right, rgba(120, 214, 232, 0.26), transparent 42%),
      linear-gradient(145deg, rgba(120, 214, 232, 0.18), rgba(158, 215, 191, 0.1));
  }

  .practice-tone-jade .practice-card-visual {
    background:
      radial-gradient(circle at top right, rgba(158, 215, 191, 0.24), transparent 42%),
      linear-gradient(145deg, rgba(158, 215, 191, 0.18), rgba(232, 189, 107, 0.08));
  }

  .practice-tone-earth .practice-card-visual {
    background:
      radial-gradient(circle at top right, rgba(255, 249, 235, 0.18), transparent 42%),
      linear-gradient(145deg, rgba(255, 249, 235, 0.08), rgba(120, 214, 232, 0.06));
  }

  .practice-card-symbol {
    position: relative;
    z-index: 1;
    color: var(--ink);
    font-size: clamp(1.9rem, 4vw, 3rem);
    font-weight: 900;
    line-height: 1;
  }

  .practice-card-visual small {
    position: relative;
    z-index: 1;
    color: var(--gold-soft);
    font-size: 0.78rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .practice-card-kicker,
  .practice-card-hint,
  .practice-card-stage {
    margin: 0;
    color: var(--gold-soft);
    font-size: 0.78rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .practice-card-copy,
  .practice-card-back-copy {
    display: grid;
    gap: 10px;
  }

  .practice-card-copy h3,
  .practice-card-back-copy h3 {
    margin: 0;
    color: var(--ink);
    font-size: 1.16rem;
    line-height: 1.36;
  }

  .practice-card-copy p,
  .practice-card-back-copy p {
    margin: 0;
    color: var(--muted);
    line-height: 1.7;
  }

  .practice-card-hint {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    color: var(--muted-strong);
  }

  .practice-card-hint::before {
    content: "";
    width: 34px;
    height: 1px;
    background: rgba(255, 249, 235, 0.26);
  }

  .practice-card-link {
    display: inline-flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    min-height: 48px;
    padding: 12px 16px;
    border: 1px solid var(--line);
    border-radius: 8px;
    background: rgba(255, 249, 235, 0.05);
    color: var(--muted-strong);
    transition: transform 180ms ease, border-color 180ms ease, background-color 180ms ease;
  }

  .practice-card-link strong {
    color: var(--ink);
    font-size: 1rem;
    line-height: 1.3;
  }

  .practice-card-link span {
    color: var(--gold-soft);
    font-size: 0.82rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .practice-card-link:hover {
    transform: translateY(-1px);
    border-color: var(--line-strong);
    background: rgba(255, 249, 235, 0.08);
  }

  .practice-card-note {
    display: inline-flex;
    align-items: center;
    gap: 10px;
    margin-top: 10px;
    padding: 10px 14px;
    border: 1px solid var(--line);
    border-radius: 8px;
    background: rgba(255, 249, 235, 0.04);
    color: var(--muted-strong);
  }

  @media (prefers-reduced-motion: reduce) {
    .practice-card-inner {
      transition: none;
    }
  }

  @media (max-width: 760px) {
    .practice-card,
    .practice-card-inner {
      min-height: 344px;
    }
  }
`;

type CardTone = "gold" | "cyan" | "jade" | "earth";

interface FlipCardItem {
  id: string;
  tone: CardTone;
  eyebrowZh: string;
  eyebrowEn: string;
  labelZh: string;
  labelEn: string;
  visualZh: string;
  visualEn: string;
  frontTitleZh: string;
  frontTitleEn: string;
  frontBodyZh: string;
  frontBodyEn: string;
  backTitleZh: string;
  backTitleEn: string;
  backBodyZh: string;
  backBodyEn: string;
  href?: string;
  ctaZh?: string;
  ctaEn?: string;
}

const rhythmCards: FlipCardItem[] = [
  {
    id: "morning-rhythm",
    tone: "gold",
    eyebrowZh: "一日节奏",
    eyebrowEn: "Daily Rhythm",
    labelZh: "晨起先安住",
    labelEn: "Morning First",
    visualZh: "晨起",
    visualEn: "Morning",
    frontTitleZh: "先让晨起有一个真实回返点，而不是一醒来就被整天带着走。",
    frontTitleEn: "Give the morning one real point of return before the whole day carries you away.",
    frontBodyZh: "先留几分钟静坐、念佛，或听一小段经文，比一开始就排很多项目更容易留下来。",
    frontBodyEn: "A few minutes of sitting, recitation, or one short scripture passage usually stays more easily than a full schedule right away.",
    backTitleZh: "晨起这一张卡想帮你做什么",
    backTitleEn: "What this morning card is for",
    backBodyZh: "它不是让你早晨做得很满，而是先让一天开始时，心里有一个愿意回来的地方。只要这一步稳定了，白天和晚间才更容易慢慢接上。",
    backBodyEn: "This card does not ask for a full morning. It asks for a place the mind is willing to return to at the start of the day so daytime and evening can join more naturally later.",
  },
  {
    id: "daytime-rhythm",
    tone: "cyan",
    eyebrowZh: "一日节奏",
    eyebrowEn: "Daily Rhythm",
    labelZh: "白天留短动作",
    labelEn: "One Daytime Action",
    visualZh: "白天",
    visualEn: "Daytime",
    frontTitleZh: "白天最值钱的，不是做很多，而是留一个最容易实现的短动作。",
    frontTitleEn: "The most valuable daytime move is not doing a lot, but keeping one action that is easy to realize.",
    frontBodyZh: "通勤、步行、午休前后，都可以放进一段听诵、一轮念佛，或一句简短提醒。",
    frontBodyEn: "A commute, walk, or the edges of a break can hold one listening passage, one short recitation, or a brief reminder.",
    backTitleZh: "白天这一张卡想帮你做什么",
    backTitleEn: "What this daytime card is for",
    backBodyZh: "这一步是在避免功课只留在早晚两端。白天哪怕只有一个很轻的回返点，修行也更容易开始回到说话、做事和与人相处里。",
    backBodyEn: "This step keeps the routine from living only at the edges of the day. Even one light daytime return point helps practice re-enter speech, work, and relationships.",
  },
  {
    id: "evening-rhythm",
    tone: "jade",
    eyebrowZh: "一日节奏",
    eyebrowEn: "Daily Rhythm",
    labelZh: "晚间用短回顾收住",
    labelEn: "Close with Review",
    visualZh: "晚间",
    visualEn: "Evening",
    frontTitleZh: "晚间不一定再做很重，只要把今天怎样走过轻轻收住。",
    frontTitleEn: "The evening does not need to be heavy. It only needs to gather the day gently back together.",
    frontBodyZh: "回顾今天有没有练习、哪一句最有触动，再补一小段阅读或静坐，就已经很有帮助。",
    frontBodyEn: "Review whether you practiced, which line stayed with you, then add a short reading or quiet sit if it still feels natural.",
    backTitleZh: "晚间这一张卡想帮你做什么",
    backTitleEn: "What this evening card is for",
    backBodyZh: "晚间卡不是为了一天结束前再加任务，而是让你有一个很轻的机会，把听过、做过和散掉的地方重新看见一次。",
    backBodyEn: "This evening card is not another task before bed. It is a light chance to see once more what you heard, what you practiced, and where the rhythm scattered.",
  },
];

const scriptureCards: FlipCardItem[] = [
  {
    id: "scripture-entry",
    tone: "gold",
    eyebrowZh: "经典接回功课",
    eyebrowEn: "Scripture Into Routine",
    labelZh: "先把入口经选清楚",
    labelEn: "Choose the First Sutra",
    visualZh: "入口经",
    visualEn: "Gateway",
    frontTitleZh: "很多人功课排不下来，不是不肯练，而是先卡在“到底从哪部经进”。",
    frontTitleEn: "Many people cannot settle into a routine not because they resist practice, but because they are still stuck on which sutra should come first.",
    frontBodyZh: "先把《心经》《阿弥陀经》《普门品》还是《金刚经》更适合作为起点单独理清。",
    frontBodyEn: "Clarify first whether the Heart Sutra, Amitabha Sutra, Universal Gate Chapter, or Diamond Sutra fits best as the beginning.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "先把入口经典选清楚，晨起、白天和晚间要怎么接，通常也会一起变清楚。不要让功课一开始就背着“先读哪部经”这个没落地的问题。",
    backBodyEn: "Once the gateway text is clearer, morning, daytime, and evening rhythm usually become clearer too. Do not let the whole routine start by carrying an unanswered question about which sutra comes first.",
    href: "/beginner-sutra-recommendations",
    ctaZh: "继续看初学者佛经推荐",
    ctaEn: "Open beginner sutra picks",
  },
  {
    id: "scripture-listening",
    tone: "cyan",
    eyebrowZh: "经典接回功课",
    eyebrowEn: "Scripture Into Routine",
    labelZh: "听诵接回文字",
    labelEn: "Return Listening to Text",
    visualZh: "听诵",
    visualEn: "Listening",
    frontTitleZh: "真正的难点常常不是“要不要听”，而是听了以后怎样回到文字。",
    frontTitleEn: "The real difficulty is often not whether to listen, but how listening returns to the written text.",
    frontBodyZh: "把声音、文字和一句记录接成同一条线，功课才不会只剩背景声音。",
    frontBodyEn: "Once sound, text, and one short note join the same line, the routine stops becoming only background sound.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "晨起先听一小段，白天回到同一段，晚间再读一小段原文或导读，让熟悉感慢慢长成理解。这里接得住，功课才真的开始和经典连上。",
    backBodyEn: "Listen to one short passage in the morning, return to the same one during the day, then read a little of the text or a guide at night so familiarity slowly grows into understanding. When this bridge holds, the routine finally joins scripture for real.",
    href: "/sutra-listening",
    ctaZh: "继续看听诵和读经怎么配合",
    ctaEn: "Open listening and reading guide",
  },
  {
    id: "scripture-map",
    tone: "jade",
    eyebrowZh: "经典接回功课",
    eyebrowEn: "Scripture Into Routine",
    labelZh: "回佛经导读重整理",
    labelEn: "Return to Sutra Guide",
    visualZh: "总导读",
    visualEn: "Guide",
    frontTitleZh: "当经典已经开始进入功课，就回到总导读把整条路重新理一遍。",
    frontTitleEn: "Once scripture has begun to enter the routine, return to the wider guide and reorganize the whole path once again.",
    frontBodyZh: "这样不是重复看总览，而是把晨起、白天和晚间节奏重新接回更完整的佛经学习地图。",
    frontBodyEn: "This is not repeating an overview. It reconnects morning, daytime, and evening rhythm to a fuller map of scripture study.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "当你已经不只在问“先读什么”，而开始问“怎么读、怎么和练习配合”，佛经导读会比继续只在功课页里找答案更稳。",
    backBodyEn: "When the question is no longer only what to read first but how to read and how scripture works with practice, the sutra guide is a steadier next step than staying only on the routine page.",
    href: "/sutra-guide",
    ctaZh: "继续看佛经导读",
    ctaEn: "Open sutra guide",
  },
];

const conceptCards: FlipCardItem[] = [
  {
    id: "concept-karma",
    tone: "gold",
    eyebrowZh: "概念回路",
    eyebrowEn: "Concept Bridge",
    labelZh: "因果会解释为什么总断",
    labelEn: "Karma Explains Breaks",
    visualZh: "因果",
    visualEn: "Karma",
    frontTitleZh: "为什么明明知道要修，节奏却总是断，往往会回到因果、习惯和结果。",
    frontTitleEn: "Why the rhythm keeps breaking often returns to karma, habit, and result.",
    frontBodyZh: "这不是把中断看成失败，而是开始看见小动作怎样慢慢养成后面的方向。",
    frontBodyEn: "This does not treat interruption as failure, but begins to show how small actions slowly shape the direction that follows.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "如果你最常卡在“为什么留不住节奏”，先回因果页，会比继续硬排更多动作更稳。它会把习惯、选择和结果怎样互相牵动说得更清楚。",
    backBodyEn: "If your main friction is why the rhythm will not stay, returning to the karma page is usually steadier than adding more actions. It clarifies how habit, choice, and result move together.",
    href: "/what-is-karma",
    ctaZh: "继续进入因果页",
    ctaEn: "Open karma guide",
  },
  {
    id: "concept-bodhicitta",
    tone: "jade",
    eyebrowZh: "概念回路",
    eyebrowEn: "Concept Bridge",
    labelZh: "菩提心会解释为什么不只是在完成任务",
    labelEn: "Bodhicitta Widens the Why",
    visualZh: "菩提心",
    visualEn: "Bodhicitta",
    frontTitleZh: "如果功课只剩“今天有没有做完”，它很容易越做越硬。",
    frontTitleEn: "When the routine becomes only whether it was completed today, it quickly turns rigid.",
    frontBodyZh: "回到菩提心，会更容易看见晨起、白天和晚间这些小动作为什么不只是维持自己。",
    frontBodyEn: "Returning to bodhicitta makes it easier to see why the small actions of morning, daytime, and evening are more than self-maintenance.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "这一步会把“我为什么做这份功课”放清楚。功课一旦有了发心，节奏就不再只是任务单，而开始长出更宽的方向与柔软。",
    backBodyEn: "This step clarifies why the routine is being kept at all. Once aspiration is present, the rhythm stops being only a checklist and begins to grow wider direction and softness.",
    href: "/what-is-bodhicitta",
    ctaZh: "继续进入菩提心页",
    ctaEn: "Open bodhicitta guide",
  },
  {
    id: "concept-paramitas",
    tone: "cyan",
    eyebrowZh: "概念回路",
    eyebrowEn: "Concept Bridge",
    labelZh: "六度会解释功课怎样落回做人做事",
    labelEn: "Six Paramitas Return to Life",
    visualZh: "六度",
    visualEn: "Paramitas",
    frontTitleZh: "功课为什么不只是一张任务清单，常常会在六度这里被说清楚。",
    frontTitleEn: "Why a routine is more than a checklist is often clarified through the six paramitas.",
    frontBodyZh: "布施、持戒、忍辱、精进、禅定和般若，都会慢慢回到晨起、白天和晚间的节奏里。",
    frontBodyEn: "Generosity, discipline, patience, diligence, meditation, and wisdom all return gradually to morning, daytime, and evening rhythm.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "如果你想知道为什么功课越走越像待人处事和修心的训练，而不只是完成项目，六度页会把这一步讲得更具体。",
    backBodyEn: "If you want to see why a routine slowly becomes training in conduct and mind rather than only finished tasks, the six paramitas page explains that step more concretely.",
    href: "/what-are-the-six-paramitas",
    ctaZh: "继续进入六度页",
    ctaEn: "Open six paramitas guide",
  },
  {
    id: "concept-emptiness",
    tone: "earth",
    eyebrowZh: "概念回路",
    eyebrowEn: "Concept Bridge",
    labelZh: "空性会解释怎样少一点抓得太死",
    labelEn: "Emptiness Softens Rigid Grasping",
    visualZh: "空性",
    visualEn: "Emptiness",
    frontTitleZh: "很多功课之所以越做越紧，是因为人把节奏、成败和判断都抓得太死。",
    frontTitleEn: "Many routines grow tighter because rhythm, success, and judgment are held too rigidly.",
    frontBodyZh: "回到空性，不是为了把生活否定掉，而是让晨起、白天和晚间多一点回观与松动。",
    frontBodyEn: "Returning to emptiness does not cancel life. It lets morning, daytime, and evening hold more reflection and less rigidity.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "如果你已经发现自己最常卡在“为什么一散掉就觉得全盘失败”，空性页会帮助你把这种抓得太死的感觉慢慢松开。",
    backBodyEn: "If your main friction has become the feeling that one break means the whole path has failed, the emptiness page helps loosen that rigid grip step by step.",
    href: "/what-is-emptiness",
    ctaZh: "继续进入空性页",
    ctaEn: "Open emptiness guide",
  },
];

const routinePrinciples = [
  {
    titleZh: "先让功课轻一点，才能让它留下来",
    titleEn: "Make the routine light enough to stay",
    descriptionZh: "对初学者来说，更稳的起点通常不是第一天就排很满，而是每天留下一个真实的小动作，让自己愿意明天再回来一次。",
    descriptionEn: "For beginners, the steadier beginning is usually not a full first day, but one real small action that leaves you willing to return tomorrow.",
  },
  {
    titleZh: "先定主线，再让其他方法做辅助",
    titleEn: "Choose a main line and let the rest support it",
    descriptionZh: "可以先以短时禅修、经文听诵、念佛或阅读中的一项做主线，再让其他方法帮助自己维持连续，而不是平均分配每一样。",
    descriptionEn: "Let one method such as short meditation, scripture listening, recitation, or reading become the main line first, then let the others support continuity instead of competing equally.",
  },
  {
    titleZh: "功课的重点不是排满，而是相续",
    titleEn: "The point is continuity, not fullness",
    descriptionZh: "真正有用的地方，不在于今天做了多少，而在于明天还愿不愿意继续回来。能相续，才慢慢长出力量。",
    descriptionEn: "What matters most is not how much happened today, but whether you are willing to return tomorrow. Continuity is what slowly grows strength.",
  },
] as const;

const gentleSchedule = [
  {
    titleZh: "第一步：先定一个早晚都做得到的动作",
    titleEn: "Step 1: Set one action for morning and night",
    descriptionZh: "例如晨起五分钟静坐，晚间两分钟回顾；或早晨听一段经文，晚上读一小段导读。先让两端连起来，比中间塞很多内容更稳。",
    descriptionEn: "For example, sit for five minutes in the morning and review for two minutes at night, or listen in the morning and read a short guide at night. Connecting the two ends of the day is steadier than filling the middle too early.",
  },
  {
    titleZh: "第二步：白天只加一个最容易实现的提醒点",
    titleEn: "Step 2: Add one easy daytime reminder",
    descriptionZh: "不用追求完整流程，只要有一个最容易完成的动作，例如通勤时听诵、午间念佛几分钟，或看到提醒时停一下呼吸，就足够让功课开始进入日常。",
    descriptionEn: "Do not chase a complete sequence. One easy move such as listening during a commute, reciting for a few minutes at noon, or pausing with the breath when a reminder appears is enough to let practice enter daily life.",
  },
  {
    titleZh: "第三步：一周后再决定要不要加量",
    titleEn: "Step 3: Decide whether to deepen only after a week",
    descriptionZh: "先让这条轻节奏活一周，再看自己是适合增加阅读、增加念佛，还是其实还需要再减一点。真正合适的功课，不是看起来很满，而是能继续走下去。",
    descriptionEn: "Let the lighter rhythm stay alive for a week first, then decide whether to add reading, add recitation, or simplify further. A fitting routine is not the one that looks full, but the one that can keep going.",
  },
] as const;

const commonMistakes = [
  {
    titleZh: "把日常功课想成一次要做完的清单",
    titleEn: "Treating the routine like a checklist to finish",
    descriptionZh: "如果一开始就希望每天把很多项目全部完成，功课很容易变成压力，而不是帮助自己安住和观照的路径。",
    descriptionEn: "When the routine starts as a list that must be completed every day, it quickly becomes pressure instead of a path that steadies awareness.",
  },
  {
    titleZh: "只有早晚有功课，白天完全断开",
    titleEn: "Keeping practice only at the edges of the day",
    descriptionZh: "早晚各做一段当然很好，但若白天完全没有任何提醒或回返点，修行就比较难慢慢进入说话、做事和待人接物里。",
    descriptionEn: "Morning and evening practice are valuable, but if nothing recalls the path during the day, it becomes harder for practice to enter speech, work, and relationships.",
  },
  {
    titleZh: "做了几天后停掉，就以为自己不适合",
    titleEn: "Stopping for a few days and assuming you are not suited to practice",
    descriptionZh: "很多人的问题不是不适合，而是起点太重。节奏断掉以后，把功课再缩小一点重新开始，往往比责备自己更有用。",
    descriptionEn: "Many people are not unsuited to practice; the starting rhythm was simply too heavy. When continuity breaks, shrinking the routine and beginning again is often more useful than self-blame.",
  },
] as const;

const relatedPaths = [
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "先回到更完整的修行方法地图。",
    titleEn: "Return to the broader map of beginner practice methods.",
    descriptionZh: "如果你还在看禅修、听诵、念佛、阅读和记录之间如何配合，可以先回到总览页。",
    descriptionEn: "Return to the overview first if you are still mapping how meditation, listening, recitation, reading, and notes fit together.",
  },
  {
    href: "/beginner-sutra-recommendations",
    labelZh: "初学者佛经推荐",
    labelEn: "Beginner Sutra Picks",
    titleZh: "先把“从哪部经进”放清楚，功课才更容易真正落下来。",
    titleEn: "Clarify which sutra to begin with before the routine carries too many questions at once.",
    descriptionZh: "如果你已经知道自己想从经典进入，但卡在《心经》《阿弥陀经》《普门品》还是《金刚经》更适合作为起点，这一页会更具体。",
    descriptionEn: "Open this first if scripture is your doorway but you still need to choose between the Heart Sutra, Amitabha Sutra, Universal Gate Chapter, or Diamond Sutra.",
  },
  {
    href: "/sutra-listening",
    labelZh: "听诵和读经怎么配合",
    labelEn: "Listening and Reading",
    titleZh: "把通勤里的听诵、安静时的阅读和一句记录接回同一条功课线。",
    titleEn: "Reconnect listening on the move, reading in quiet moments, and one short note inside the same routine.",
    descriptionZh: "如果你已经在听经，却还不知道怎样把它接回晨起、白天和晚间，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you already listen to sutras but still need to reconnect that rhythm with morning, daytime, and evening.",
  },
  {
    href: "/buddhist-concepts",
    labelZh: "佛学基本概念",
    labelEn: "Buddhist Concepts",
    titleZh: "先回到一张更完整的概念地图，再决定自己卡在哪个概念上。",
    titleEn: "Return to a wider concepts map before choosing which concept needs attention now.",
    descriptionZh: "如果你已经发现自己并不只是缺功课安排，而是总被因果、菩提心、六度、空性这些词反复卡住，这一页会更适合先打开。",
    descriptionEn: "Open this first if you have started to see that the problem is not only routine design, but repeated friction around karma, bodhicitta, the six paramitas, or emptiness.",
  },
  {
    href: "/start-learning-buddhism",
    labelZh: "学佛从哪里开始",
    labelEn: "Where to Begin",
    titleZh: "先回到更轻、更清楚的起步问题。",
    titleEn: "Return to the lighter and clearer beginner question first.",
    descriptionZh: "如果你还没有决定该从哪一条路开始，这一页会更适合先打开。",
    descriptionEn: "If you still have not decided which path to begin with, this page is the better first stop.",
  },
  {
    href: "/download",
    labelZh: "下载入口",
    labelEn: "Download",
    titleZh: "把提醒、听诵和记录放进生活里。",
    titleEn: "Bring reminders, listening, and notes into everyday life.",
    descriptionZh: "准备借助 Fabushi 承接听诵、禅修提醒和简短记录时，可以直接查看下载入口。",
    descriptionEn: "Go straight to downloads when you are ready to use Fabushi for listening, reminders, and simple notes.",
  },
] as const;

const faqItems = [
  {
    questionZh: "日常功课是不是一定要做很多才算认真？",
    questionEn: "Does a daily routine need to be heavy to count as sincere practice?",
    answerZh: "不一定。对初学者来说，功课更重要的是能不能相续。轻一点、真一点、能继续做下去，通常比一开始安排很多却很快中断更有帮助。",
    answerEn: "Not necessarily. For beginners, continuity matters more than intensity. A lighter routine that can stay alive is usually more helpful than a heavy one that stops quickly.",
  },
  {
    questionZh: "如果我想从佛经开始，第一周的日常功课怎么接？",
    questionEn: "If I want to begin from sutras, how should the first week of daily practice connect?",
    answerZh: "更稳的起点通常不是一下安排很多，而是先选一部更贴近自己当下问题的经典，再让晨起、白天和晚间各有一个很轻的小动作。例如晨起先听一小段，白天留一个提醒点或一句佛号，晚间再回到原文或导读读一小段。先让同一部经典连续出现几天，往往比每天都换内容更容易留下来。",
    answerEn: "A steadier beginning is usually not to schedule many things at once, but to choose one scripture that fits your present question and then give morning, daytime, and evening one small action each. Let the same sutra return for a few days before changing tracks.",
  },
  {
    questionZh: "听诵以后，怎样把经典接回晨起、白天和晚间？",
    questionEn: "After listening, how do I return scripture to morning, daytime, and evening?",
    answerZh: "可以把听诵当成把经典带进一天的第一步，而不是最后一步。晨起先听一小段，白天在通勤、步行或空档里回到同一段内容，晚间再读一小段原文或导读，把声音慢慢接回理解。这样听诵就不会只停在背景声音里。",
    answerEn: "Treat listening as the first step that brings scripture into the day rather than the final step. Morning can start with one short passage, daytime can return to the same section, and evening can bring it back to text or a guide so familiarity grows into understanding.",
  },
  {
    questionZh: "因果是什么意思，和日常功课有什么关系？",
    questionEn: "What does karma have to do with a daily practice routine?",
    answerZh: "如果不知道因果怎样和习惯、选择、结果连在一起，功课很容易只剩一阵一阵的热情。回到因果，会更容易看见：晨起有没有回来、白天有没有一个提醒点、晚间断掉以后有没有重来，这些很小的动作，正在慢慢形成后面的方向。",
    answerEn: "When karma is separated from habit, choice, and result, a routine can shrink into bursts of enthusiasm. Returning to karma helps show how small returns across the day are already shaping the path that follows.",
  },
  {
    questionZh: "菩提心是什么意思，和日常功课有什么关系？",
    questionEn: "What does bodhicitta have to do with a daily practice routine?",
    answerZh: "如果没有发心，功课很容易只剩完成任务。更稳的方向，是让晨起、白天和晚间的这些小动作，慢慢回到“我为什么学、愿意把这条路带向哪里”这件事上。这样功课才不只是维持自己，而会开始长出更宽的方向和柔软。",
    answerEn: "Without aspiration, a daily routine can shrink into task completion. A steadier direction is to let the small actions of morning, daytime, and evening return to the question of why you practice and what direction you want the path to grow toward.",
  },
  {
    questionZh: "如果中断了几天，功课是不是就失败了？",
    questionEn: "If I miss a few days, has the routine failed?",
    answerZh: "不是。真正重要的不是从不间断，而是断掉以后能不能重新回来。中断后先把功课缩小一点，再重新开始，通常比硬撑原计划更稳。",
    answerEn: "No. What matters is not never breaking the rhythm, but being able to return after it breaks. When continuity stops, begin again with a smaller version instead of forcing the old plan.",
  },
  {
    questionZh: "空性怎么理解，和日常功课有什么关系？",
    questionEn: "How does understanding emptiness relate to a daily practice routine?",
    answerZh: "如果把空性只当成很远的名相，功课很容易变成完成任务。更稳的方向，是在晨起、白天和晚间慢慢看见：很多情绪和判断并没有想象中那样固定。这样禅修、听诵、念佛和回顾，就会变成帮助自己少一点抓得太死、更多一点清醒和柔软的练习。",
    answerEn: "If emptiness is treated as a remote term, a daily routine can shrink into task completion. A steadier direction is to notice across morning, daytime, and evening that many emotions and judgments are less fixed than they seemed.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "日常功课",
    "学佛日常功课",
    "初学者功课安排",
    "居士日常修行",
    "先读什么佛经",
    "听诵和读经怎么配合",
    "佛经导读",
    "佛学基本概念",
    "因果是什么意思",
    "菩提心是什么意思",
    "六度分别是什么",
    "空性怎么理解",
    "修行方法",
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

function PracticeFlipCard({ item }: { item: FlipCardItem }) {
  return (
    <div className="practice-card-shell">
      <input
        className="practice-card-toggle"
        type="checkbox"
        id={item.id}
        aria-label={`${item.labelZh} / ${item.labelEn}`}
      />
      <label className={`practice-card practice-tone-${item.tone}`} htmlFor={item.id}>
        <span className="practice-card-inner">
          <span className="practice-card-face practice-card-front">
            <span className="practice-card-visual" aria-hidden="true">
              <span className="practice-card-symbol">
                <LocalizedText zh={item.visualZh} en={item.visualEn} />
              </span>
              <small>
                <LocalizedText zh={item.labelZh} en={item.labelEn} />
              </small>
            </span>
            <span className="practice-card-copy">
              <p className="practice-card-kicker">
                <LocalizedText zh={item.eyebrowZh} en={item.eyebrowEn} />
              </p>
              <h3>
                <LocalizedText zh={item.frontTitleZh} en={item.frontTitleEn} />
              </h3>
              <p>
                <LocalizedText zh={item.frontBodyZh} en={item.frontBodyEn} />
              </p>
            </span>
            <span className="practice-card-hint">
              <LocalizedText zh="翻卡看下一步" en="Flip for the next step" />
            </span>
          </span>
          <span className="practice-card-face practice-card-back">
            <span className="practice-card-back-copy">
              <p className="practice-card-stage">
                <LocalizedText zh="背面摘要" en="Back Summary" />
              </p>
              <h3>
                <LocalizedText zh={item.backTitleZh} en={item.backTitleEn} />
              </h3>
              <p>
                <LocalizedText zh={item.backBodyZh} en={item.backBodyEn} />
              </p>
            </span>
            {item.href ? (
              <a className="practice-card-link" href={siteHref(item.href)}>
                <strong>
                  <LocalizedText zh={item.ctaZh ?? item.labelZh} en={item.ctaEn ?? item.labelEn} />
                </strong>
                <span>
                  <LocalizedText zh="继续阅读" en="Continue" />
                </span>
              </a>
            ) : null}
          </span>
        </span>
      </label>
    </div>
  );
}

export default function DailyPracticePage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "日常功课怎么安排",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: [
          "日常功课",
          "经文听诵",
          "佛经导读",
          "因果",
          "菩提心",
          "六度",
          "空性",
          "初学者功课安排",
        ],
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
            name: "修行方法总览",
            item: siteUrl("/practice-guide"),
          },
          {
            "@type": "ListItem",
            position: 3,
            name: "日常功课怎么安排",
            item: pageUrl,
          },
        ],
      },
      {
        "@type": "ItemList",
        name: "日常功课卡牌：一日节奏",
        itemListElement: rhythmCards.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.labelZh,
          description: item.frontBodyZh,
        })),
      },
      {
        "@type": "ItemList",
        name: "日常功课卡牌：经典接回功课",
        itemListElement: scriptureCards.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.labelZh,
          url: siteUrl(item.href ?? "/daily-practice"),
          description: item.frontBodyZh,
        })),
      },
      {
        "@type": "ItemList",
        name: "日常功课卡牌：概念回路",
        itemListElement: conceptCards.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.labelZh,
          url: siteUrl(item.href ?? "/daily-practice"),
          description: item.frontBodyZh,
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
            <LocalizedText zh="日常功课怎么安排" en="Daily Practice" />
          </p>
          <h1>
            <LocalizedText
              zh="把功课排轻一点、排稳一点，反而更容易让修行真正留在生活里。"
              en="A lighter, steadier routine usually lets practice stay inside daily life more deeply."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="晨起、白天和晚间不用都做得很满。先让禅修、听诵、念佛、阅读或简短回顾中有一两步真正留下来，再慢慢把它们接成自己的日常功课。"
              en="Morning, daytime, and evening do not all need to be full. Let one or two steps in meditation, listening, recitation, reading, or review become real first, then connect them gradually into your own daily rhythm."
            />
          </p>
        </div>
      </section>

      <section className="band compact-band">
        <style dangerouslySetInnerHTML={{ __html: cardStyles }} />
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="卡牌总览" en="Card Overview" />
          </p>
          <h2>
            <LocalizedText
              zh="先翻卡看摘要，再顺着自己当下最需要的一张，继续读下面正文或跳进下一页。"
              en="Flip through the summaries first, then follow the card that best matches your present need into the detail below or the next page."
            />
          </h2>
          <p className="practice-card-note">
            <LocalizedText
              zh="这一页现在改成“卡牌摘要入口 + 详情正文”的混合结构：正面先帮你判断入口，背面再给出更短的下一步。"
              en="This page now uses a mixed structure of card summaries plus long-form detail: the front helps you choose a doorway, and the back gives a shorter next step."
            />
          </p>
        </div>
        <div className="practice-card-grid">
          {rhythmCards.map((item) => (
            <PracticeFlipCard key={item.id} item={item} />
          ))}
        </div>
      </section>

      <section className="band alt feature-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="经典接回功课卡牌" en="Scripture Cards" />
          </p>
          <h2>
            <LocalizedText
              zh="把“先读哪部经、怎样听、怎样回到晚间阅读”这些真实问题，直接收进功课路径里。"
              en="Bring the real questions of which sutra to begin with, how to listen, and how to return to evening reading directly into the routine itself."
            />
          </h2>
        </div>
        <div className="practice-card-grid">
          {scriptureCards.map((item) => (
            <PracticeFlipCard key={item.id} item={item} />
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="概念回路卡牌" en="Concept Cards" />
          </p>
          <h2>
            <LocalizedText
              zh="练着练着又回到因果、菩提心、六度和空性，往往不是岔开，而是路径开始变深。"
              en="When practice keeps returning to karma, bodhicitta, the six paramitas, and emptiness, the path is often deepening rather than drifting."
            />
          </h2>
        </div>
        <div className="practice-card-grid">
          {conceptCards.map((item) => (
            <PracticeFlipCard key={item.id} item={item} />
          ))}
        </div>
      </section>

      <section className="band compact-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="导读" en="Guide" />
          </p>
          <h2>
            <LocalizedText
              zh="很多人卡住的不是不会做功课，而是一开始就把功课想得太重。"
              en="Many people do not get stuck because they cannot practice, but because they imagine the routine as too heavy from the beginning."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="一说到日常功课，很多人脑中立刻会出现一张很满的清单：要读经、要听诵、要禅修、要念佛、要记笔记，仿佛这样才算真正开始修行。可多数初学者真正遇到的困难，并不是没有方法，而是第一天就把自己排得太重，结果几天后反而停下来了。"
              en="When people hear daily practice, many immediately picture a full checklist of reading, listening, meditation, recitation, and notes, as if that were the only sincere beginning. Yet for most beginners, the problem is not a lack of methods. It is the weight of the schedule on day one, which often leads to stopping a few days later."
            />
          </p>
          <p>
            <LocalizedText
              zh="比较稳妥的功课，不是看起来最完整的那一种，而是最能留下来的那一种。传统修学常重视闻、思、修能否慢慢接续起来。放到今天的生活里，日常功课更像是一条轻轻贯穿一天的线，而不是早晚各做一大段、白天完全断开。"
              en="The steadier routine is usually not the one that looks most complete, but the one that can truly stay alive. Traditional learning often values whether hearing, reflection, and practice can continue into one another. Inside modern life, a daily routine often works better as a light thread through the day than as two heavy blocks that leave the middle empty."
            />
          </p>
          <p>
            <LocalizedText
              zh="很多人排功课时，问题其实会慢慢变成：如果我是从《心经》或《阿弥陀经》开始，晨起该听还是读？白天只有碎片时间，经典怎么不只停在背景声音里？晚间又该怎样把听过的一句接回一点阅读或回顾？这些都不是岔题，而是日常功课真正开始落地时最自然会出现的问题。"
              en="As people begin arranging a routine, the question often shifts into whether the Heart Sutra or Amitabha Sutra should lead the day, whether morning should begin with listening or reading, how scripture can avoid becoming background sound during the day, and how one heard line can return to evening reading or review. These are not detours. They are the natural questions that appear when a daily routine begins to become real."
            />
          </p>
          <p>
            <LocalizedText
              zh="比较稳的方式，常常不是把经典和功课分成两条线，而是先定一部较合适的入口经典，再让晨起有一小段听诵或念佛，白天留一个提醒点，晚间回到原文或导读里读一小段。这样经典不只是偶尔想起时才接触，而会慢慢变成一天里的真实回返点。"
              en="A steadier way is usually not to separate scripture from routine, but to choose one fitting gateway text first, then give the morning a short listening or recitation action, the daytime one reminder point, and the evening a short return to the text or a guide. Scripture then becomes a real point of return inside the day instead of something touched only occasionally."
            />
          </p>
          <p>
            <LocalizedText
              zh="日常功课的价值，也不只是把几个动作做完。随着晨起、白天和晚间慢慢出现回返点，人会开始看见：很多急躁、执着和判断，并没有想象中那样固定。功课越回到这里，练习就越不只是完成任务，而是在帮助自己多一点清醒和柔软。"
              en="The value of a daily routine is not only finishing a few actions. As morning, daytime, and evening gain small points of return, people often begin to see that agitation, attachment, and judgment are less fixed than they seemed. The more practice returns here, the less it becomes task completion and the more it supports clarity and softness."
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
              zh="先把安排日常功课的三个基本判断放稳。"
              en="Set three basic judgments in place before arranging a daily routine."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {routinePrinciples.map((item) => (
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

      <section className="band alt">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="轻量安排" en="Light Schedule" />
          </p>
          <h2>
            <LocalizedText
              zh="先用三步把功课排轻一点，再决定要不要慢慢加深。"
              en="Use three steps to lighten the routine first, then decide whether it needs to deepen."
            />
          </h2>
        </div>
        <div className="compare-grid">
          {gentleSchedule.map((item) => (
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
              zh="先避开几个最容易让功课变重、变断的误区。"
              en="Avoid the patterns that most easily make practice too heavy or too fragile."
            />
          </h2>
        </div>
        <div className="evidence-grid">
          {commonMistakes.map((item) => (
            <article key={item.titleEn} className="evidence-card">
              <strong>
                <LocalizedText zh={item.titleZh} en={item.titleEn} />
              </strong>
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
              zh="顺着你当下最需要的入口，继续往更具体的页面走。"
              en="Move from this page into the next route that matches what you need most now."
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
              zh="先回答初学者最容易在日常功课上卡住的几个问题。"
              en="Answer the questions beginners most often get stuck on when building a daily routine."
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
          <a className="secondary-action" href={siteHref("/beginner-sutra-recommendations")}>
            <LocalizedText zh="继续看初学者佛经推荐" en="Continue to Beginner Sutra Picks" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
