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
  .daily-card-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 18px;
  }

  .daily-card {
    display: grid;
    gap: 16px;
    padding: 22px;
    border: 1px solid var(--line);
    border-radius: 8px;
    background: linear-gradient(180deg, rgba(255, 249, 235, 0.08), rgba(10, 15, 22, 0.96));
    box-shadow: var(--shadow);
  }

  .daily-card-visual {
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

  .daily-card-visual::before,
  .daily-card-visual::after {
    content: "";
    position: absolute;
    border-radius: 999px;
    border: 1px solid rgba(255, 249, 235, 0.18);
    opacity: 0.72;
  }

  .daily-card-visual::before {
    inset: 14px 18px auto auto;
    width: 82px;
    height: 82px;
  }

  .daily-card-visual::after {
    inset: auto auto 16px 18px;
    width: 118px;
    height: 118px;
  }

  .daily-tone-gold .daily-card-visual {
    background:
      radial-gradient(circle at top right, rgba(255, 227, 163, 0.24), transparent 42%),
      linear-gradient(145deg, rgba(232, 189, 107, 0.22), rgba(120, 214, 232, 0.08));
  }

  .daily-tone-cyan .daily-card-visual {
    background:
      radial-gradient(circle at top right, rgba(120, 214, 232, 0.26), transparent 42%),
      linear-gradient(145deg, rgba(120, 214, 232, 0.18), rgba(158, 215, 191, 0.1));
  }

  .daily-tone-jade .daily-card-visual {
    background:
      radial-gradient(circle at top right, rgba(158, 215, 191, 0.24), transparent 42%),
      linear-gradient(145deg, rgba(158, 215, 191, 0.18), rgba(232, 189, 107, 0.08));
  }

  .daily-tone-earth .daily-card-visual {
    background:
      radial-gradient(circle at top right, rgba(255, 249, 235, 0.18), transparent 42%),
      linear-gradient(145deg, rgba(255, 249, 235, 0.08), rgba(120, 214, 232, 0.06));
  }

  .daily-card-symbol {
    position: relative;
    z-index: 1;
    color: var(--ink);
    font-size: clamp(2rem, 4vw, 3rem);
    font-weight: 900;
    line-height: 1;
  }

  .daily-card-visual small,
  .daily-card-kicker,
  .daily-card-stage {
    position: relative;
    z-index: 1;
    margin: 0;
    color: var(--gold-soft);
    font-size: 0.78rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .daily-card-copy,
  .daily-card-summary {
    display: grid;
    gap: 10px;
  }

  .daily-card-copy h3,
  .daily-card-summary h3 {
    margin: 0;
    color: var(--ink);
    font-size: 1.16rem;
    line-height: 1.36;
  }

  .daily-card-copy p,
  .daily-card-summary p {
    margin: 0;
    color: var(--muted);
    line-height: 1.7;
  }

  .daily-card-summary {
    padding-top: 14px;
    border-top: 1px solid rgba(255, 249, 235, 0.12);
  }

  .daily-card-link {
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

  .daily-card-link strong {
    color: var(--ink);
    font-size: 1rem;
    line-height: 1.3;
  }

  .daily-card-link span {
    color: var(--gold-soft);
    font-size: 0.82rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .daily-card-link:hover {
    transform: translateY(-1px);
    border-color: var(--line-strong);
    background: rgba(255, 249, 235, 0.08);
  }

  .daily-card-note {
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
`;

type CardTone = "gold" | "cyan" | "jade" | "earth";

interface DailyCardItem {
  tone: CardTone;
  eyebrowZh: string;
  eyebrowEn: string;
  labelZh: string;
  labelEn: string;
  visualZh: string;
  visualEn: string;
  titleZh: string;
  titleEn: string;
  bodyZh: string;
  bodyEn: string;
  summaryTitleZh: string;
  summaryTitleEn: string;
  summaryBodyZh: string;
  summaryBodyEn: string;
  href?: string;
  ctaZh?: string;
  ctaEn?: string;
}

const rhythmCards: DailyCardItem[] = [
  {
    tone: "gold",
    eyebrowZh: "一日节奏",
    eyebrowEn: "Daily Rhythm",
    labelZh: "晨起先安住",
    labelEn: "Morning First",
    visualZh: "晨起",
    visualEn: "Morning",
    titleZh: "先让晨起有一个真实回返点，而不是一醒来就被整天带着走。",
    titleEn: "Give the morning one real point of return before the whole day carries you away.",
    bodyZh: "先留几分钟静坐、念佛，或听一小段经文，比一开始就排很多项目更容易留下来。",
    bodyEn: "A few minutes of sitting, recitation, or one short scripture passage usually stays more easily than a full schedule right away.",
    summaryTitleZh: "这张卡先帮你定什么",
    summaryTitleEn: "What this card sets first",
    summaryBodyZh: "晨起不用很满，只要先让自己醒来以后有一个愿意回来的地方。只要这一步稳定了，白天和晚间才更容易慢慢接上。",
    summaryBodyEn: "The morning does not need to be full. It only needs one place the mind is willing to return to so daytime and evening can join more naturally later.",
  },
  {
    tone: "cyan",
    eyebrowZh: "一日节奏",
    eyebrowEn: "Daily Rhythm",
    labelZh: "白天留短动作",
    labelEn: "One Daytime Action",
    visualZh: "白天",
    visualEn: "Daytime",
    titleZh: "白天最值钱的，不是做很多，而是留一个最容易实现的短动作。",
    titleEn: "The most valuable daytime move is not doing a lot, but keeping one action that is easy to realize.",
    bodyZh: "通勤、步行、午休前后，都可以放进一段听诵、一轮念佛，或一句简短提醒。",
    bodyEn: "A commute, walk, or the edges of a break can hold one listening passage, one short recitation, or a brief reminder.",
    summaryTitleZh: "这张卡先帮你避免什么",
    summaryTitleEn: "What this card helps prevent",
    summaryBodyZh: "这一步是在避免功课只留在早晚两端。白天哪怕只有一个很轻的回返点，修行也更容易开始回到说话、做事和与人相处里。",
    summaryBodyEn: "It keeps the routine from living only at the edges of the day. Even one light daytime return helps practice re-enter speech, work, and relationships.",
  },
  {
    tone: "jade",
    eyebrowZh: "一日节奏",
    eyebrowEn: "Daily Rhythm",
    labelZh: "晚间用短回顾收住",
    labelEn: "Close with Review",
    visualZh: "晚间",
    visualEn: "Evening",
    titleZh: "晚间不一定再做很重，只要把今天怎样走过轻轻收住。",
    titleEn: "The evening does not need to be heavy. It only needs to gather the day gently back together.",
    bodyZh: "回顾今天有没有练习、哪一句最有触动，再补一小段阅读或静坐，就已经很有帮助。",
    bodyEn: "Review whether you practiced, which line stayed with you, then add a short reading or quiet sit if it still feels natural.",
    summaryTitleZh: "这张卡把什么接回来",
    summaryTitleEn: "What this card brings back",
    summaryBodyZh: "晚间卡不是为了再加任务，而是让你重新看见今天真正留下了什么。这样第二天更容易继续回来，而不是把功课越排越重。",
    summaryBodyEn: "This card is not another task. It helps you see what truly stayed today so tomorrow becomes easier to return to without making the routine heavier.",
    href: "/nianfo-guide",
    ctaZh: "继续看念佛入门怎么开始",
    ctaEn: "Open the nianfo guide",
  },
];

const scriptureCards: DailyCardItem[] = [
  {
    tone: "gold",
    eyebrowZh: "经典接回功课",
    eyebrowEn: "Scripture Into Routine",
    labelZh: "先把入口经选清楚",
    labelEn: "Choose the First Sutra",
    visualZh: "入口经",
    visualEn: "Gateway",
    titleZh: "很多人功课排不下来，不是不肯练，而是先卡在到底从哪部经进。",
    titleEn: "Many people cannot settle into a routine not because they resist practice, but because they are still stuck on which sutra should come first.",
    bodyZh: "先把《心经》《阿弥陀经》《普门品》还是《金刚经》更适合作为起点单独理清。",
    bodyEn: "Clarify first whether the Heart Sutra, Amitabha Sutra, Universal Gate Chapter, or Diamond Sutra fits best as the beginning.",
    summaryTitleZh: "这张卡会带你去哪",
    summaryTitleEn: "Where this card leads",
    summaryBodyZh: "先把入口经典选清楚，晨起、白天和晚间要怎么接，通常也会一起变清楚。不要让功课一开始就背着先读哪部经这个没落地的问题。",
    summaryBodyEn: "Once the gateway text is clearer, morning, daytime, and evening rhythm usually become clearer too. Do not let the whole routine start by carrying an unanswered question about which sutra comes first.",
    href: "/beginner-sutra-recommendations",
    ctaZh: "继续看初学者佛经推荐",
    ctaEn: "Open beginner sutra picks",
  },
  {
    tone: "cyan",
    eyebrowZh: "经典接回功课",
    eyebrowEn: "Scripture Into Routine",
    labelZh: "听诵接回文字",
    labelEn: "Return Listening to Text",
    visualZh: "听诵",
    visualEn: "Listening",
    titleZh: "真正的难点常常不是要不要听，而是听了以后怎样回到文字。",
    titleEn: "The real difficulty is often not whether to listen, but how listening returns to the written text.",
    bodyZh: "把声音、文字和一句记录接成同一条线，功课才不会只剩背景声音。",
    bodyEn: "Once sound, text, and one short note join the same line, the routine stops becoming only background sound.",
    summaryTitleZh: "这张卡会把哪一步接出来",
    summaryTitleEn: "What this card draws out",
    summaryBodyZh: "晨起先听一小段，白天回到同一段，晚间再读一小段原文或导读，让熟悉感慢慢长成理解。这里接得住，功课才真的开始和经典连上。",
    summaryBodyEn: "Listen to one short passage in the morning, return to the same one during the day, then read a little of the text or a guide at night so familiarity slowly grows into understanding.",
    href: "/sutra-listening",
    ctaZh: "继续看听诵和读经怎么配合",
    ctaEn: "Open listening and reading guide",
  },
  {
    tone: "jade",
    eyebrowZh: "经典接回功课",
    eyebrowEn: "Scripture Into Routine",
    labelZh: "回佛经导读重整理",
    labelEn: "Return to Sutra Guide",
    visualZh: "总导读",
    visualEn: "Guide",
    titleZh: "当经典已经开始进入功课，就回到总导读把整条路重新理一遍。",
    titleEn: "Once scripture has begun to enter the routine, return to the wider guide and reorganize the whole path once again.",
    bodyZh: "这样不是重复看总览，而是把晨起、白天和晚间节奏重新接回更完整的佛经学习地图。",
    bodyEn: "This is not repeating an overview. It reconnects morning, daytime, and evening rhythm to a fuller map of scripture study.",
    summaryTitleZh: "这张卡会把你送去哪",
    summaryTitleEn: "Where this card leads",
    summaryBodyZh: "当你已经不只在问先读什么，而开始问怎么读、怎么和练习配合，佛经导读会比继续只在功课页里找答案更稳。",
    summaryBodyEn: "When the question is no longer only what to read first but how to read and how scripture works with practice, the sutra guide becomes the steadier next step.",
    href: "/sutra-guide",
    ctaZh: "继续看佛经导读",
    ctaEn: "Open sutra guide",
  },
];

const conceptCards: DailyCardItem[] = [
  {
    tone: "gold",
    eyebrowZh: "概念回路",
    eyebrowEn: "Concept Bridge",
    labelZh: "因果会解释为什么总断",
    labelEn: "Karma Explains Breaks",
    visualZh: "因果",
    visualEn: "Karma",
    titleZh: "为什么明明知道要修，节奏却总是断，往往会回到因果、习惯和结果。",
    titleEn: "Why the rhythm keeps breaking often returns to karma, habit, and result.",
    bodyZh: "这不是把中断看成失败，而是开始看见小动作怎样慢慢养成后面的方向。",
    bodyEn: "This does not treat interruption as failure, but begins to show how small actions slowly shape the direction that follows.",
    summaryTitleZh: "这张卡适合什么时候看",
    summaryTitleEn: "When this card fits best",
    summaryBodyZh: "如果你最常卡在为什么留不住节奏，先回因果页，会比继续硬排更多动作更稳。它会把习惯、选择和结果怎样互相牵动说得更清楚。",
    summaryBodyEn: "If your main friction is why the rhythm will not stay, returning to the karma page is usually steadier than adding more actions.",
    href: "/what-is-karma",
    ctaZh: "继续看因果是什么意思",
    ctaEn: "Open the karma guide",
  },
  {
    tone: "jade",
    eyebrowZh: "概念回路",
    eyebrowEn: "Concept Bridge",
    labelZh: "菩提心会解释为什么不只是在完成任务",
    labelEn: "Bodhicitta Widens the Why",
    visualZh: "菩提心",
    visualEn: "Bodhicitta",
    titleZh: "如果功课只剩今天有没有做完，它很容易越做越硬。",
    titleEn: "When the routine becomes only whether it was completed today, it quickly turns rigid.",
    bodyZh: "回到菩提心，会更容易看见晨起、白天和晚间这些小动作为什么不只是维持自己。",
    bodyEn: "Returning to bodhicitta makes it easier to see why the small actions of morning, daytime, and evening are more than self-maintenance.",
    summaryTitleZh: "这张卡把什么放清楚",
    summaryTitleEn: "What this card clarifies",
    summaryBodyZh: "功课一旦有了发心，就不再只是任务单，而开始长出更宽的方向和柔软。这个问题一旦看清，节奏通常也会变轻。",
    summaryBodyEn: "Once aspiration is present, the rhythm stops being only a checklist and begins to grow wider direction and softness.",
    href: "/what-is-bodhicitta",
    ctaZh: "继续看菩提心是什么意思",
    ctaEn: "Open the bodhicitta guide",
  },
  {
    tone: "cyan",
    eyebrowZh: "概念回路",
    eyebrowEn: "Concept Bridge",
    labelZh: "六度会解释功课怎样落回做人做事",
    labelEn: "Six Paramitas Return to Life",
    visualZh: "六度",
    visualEn: "Paramitas",
    titleZh: "功课为什么不只是一张任务清单，常常会在六度这里被说清楚。",
    titleEn: "Why a routine is more than a checklist is often clarified through the six paramitas.",
    bodyZh: "布施、持戒、忍辱、精进、禅定和般若，都会慢慢回到晨起、白天和晚间的节奏里。",
    bodyEn: "Generosity, discipline, patience, diligence, meditation, and wisdom all return gradually to morning, daytime, and evening rhythm.",
    summaryTitleZh: "这张卡会把哪一步接出来",
    summaryTitleEn: "What this card draws out",
    summaryBodyZh: "如果你想知道为什么功课越走越像待人处事和修心的训练，而不只是完成项目，六度页会把这一步讲得更具体。",
    summaryBodyEn: "If you want to see why a routine slowly becomes training in conduct and mind rather than only finished tasks, the six paramitas page explains that step more concretely.",
    href: "/what-are-the-six-paramitas",
    ctaZh: "继续看六度分别是什么",
    ctaEn: "Open the six paramitas guide",
  },
  {
    tone: "earth",
    eyebrowZh: "概念回路",
    eyebrowEn: "Concept Bridge",
    labelZh: "空性会解释怎样少一点抓得太死",
    labelEn: "Emptiness Softens Rigid Grasping",
    visualZh: "空性",
    visualEn: "Emptiness",
    titleZh: "很多功课之所以越做越紧，是因为人把节奏、成败和判断都抓得太死。",
    titleEn: "Many routines grow tighter because rhythm, success, and judgment are held too rigidly.",
    bodyZh: "回到空性，不是为了把生活否定掉，而是让晨起、白天和晚间多一点回观与松动。",
    bodyEn: "Returning to emptiness does not cancel life. It lets morning, daytime, and evening hold more reflection and less rigidity.",
    summaryTitleZh: "这张卡适合什么时候看",
    summaryTitleEn: "When this card fits best",
    summaryBodyZh: "如果你已经发现自己最常卡在一散掉就觉得全盘失败，空性页会帮助你把这种抓得太死的感觉慢慢松开。",
    summaryBodyEn: "If your main friction has become the feeling that one break means the whole path has failed, the emptiness page helps loosen that rigid grip step by step.",
    href: "/what-is-emptiness",
    ctaZh: "继续看空性怎么理解",
    ctaEn: "Open the emptiness guide",
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
    descriptionEn: "For example, sit for five minutes in the morning and review for two minutes at night, or listen in the morning and read a short guide at night.",
  },
  {
    titleZh: "第二步：白天只加一个最容易实现的提醒点",
    titleEn: "Step 2: Add one easy daytime reminder",
    descriptionZh: "不用追求完整流程，只要有一个最容易完成的动作，例如通勤时听诵、午间念佛几分钟，或看到提醒时停一下呼吸，就足够让功课开始进入日常。",
    descriptionEn: "Do not chase a complete sequence. One easy move such as listening during a commute, reciting for a few minutes at noon, or pausing with the breath when a reminder appears is enough.",
  },
  {
    titleZh: "第三步：一周后再决定要不要加深",
    titleEn: "Step 3: Adjust only after a week",
    descriptionZh: "先让同一条线活过一周，再看自己更适合加阅读、加念佛，还是把原来的节奏再简化一点。不要第一天就同时改太多东西。",
    descriptionEn: "Let one line stay alive for a week first, then decide whether to add reading, recitation, or simplify the rhythm even more.",
  },
] as const;

const commonMistakes = [
  {
    titleZh: "一开始就把功课排成很重的清单",
    titleEn: "Turning practice into a heavy checklist from day one",
    descriptionZh: "如果入口太重，功课很容易两三天后就断掉。更稳的方向，是先让一句经文、一句佛号或一个固定时段真的留得下来。",
    descriptionEn: "When the doorway is too heavy, the routine often breaks within a few days. A steadier direction is to let one phrase, one passage, or one fixed window actually stay alive first.",
  },
  {
    titleZh: "只在早晚做，白天完全没有回返点",
    titleEn: "Keeping practice only at the edges of the day",
    descriptionZh: "早晚当然重要，但如果白天完全没有任何回来的机会，功课就比较难慢慢回到说话、做事和待人处事里。",
    descriptionEn: "Morning and evening matter, but with no daytime return point, practice has a harder time returning to speech, work, and relationship.",
  },
  {
    titleZh: "练习一断就觉得全盘失败",
    titleEn: "Treating one break as total failure",
    descriptionZh: "真正重要的不是从不间断，而是断掉以后愿不愿意重新回来。中断以后先把功课缩小一点，通常比硬撑原计划更稳。",
    descriptionEn: "What matters is not never breaking the rhythm, but being willing to return after it breaks. Restarting with a smaller version is often steadier than forcing the old plan.",
  },
] as const;

const relatedPaths = [
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "先回到更完整的方法地图，再决定哪一条最适合作为主线。",
    titleEn: "Return to the wider methods map before deciding which line should lead.",
    descriptionZh: "如果你还在分辨禅修、听诵、念佛和阅读该怎么配合，这一页更适合先打开。",
    descriptionEn: "Open this first if you still need the wider map for how meditation, listening, recitation, and reading support one another.",
  },
  {
    href: "/beginner-sutra-recommendations",
    labelZh: "初学者佛经推荐",
    labelEn: "Beginner Sutra Picks",
    titleZh: "先把先读哪部经这一步理清，功课节奏才更容易落地。",
    titleEn: "Clarify which sutra to begin with before the routine asks too many questions at once.",
    descriptionZh: "如果你已经知道自己想从经典进入，但卡在《心经》《阿弥陀经》《普门品》还是《金刚经》，这一页会更具体。",
    descriptionEn: "This page is more specific if you already know scripture is the doorway but still need to choose between key entry texts.",
  },
  {
    href: "/sutra-listening",
    labelZh: "听诵和读经怎么配合",
    labelEn: "Listening and Reading",
    titleZh: "把通勤里的听诵、安静时的阅读和一句记录接回同一条练习线。",
    titleEn: "Reconnect listening on the move, reading in quiet moments, and one short note inside the same practice line.",
    descriptionZh: "如果你已经开始听经，却还不知道怎样把它接回阅读、念佛和记录，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you have already begun listening to sutras but still need to reconnect it with reading, recitation, and notes.",
  },
  {
    href: "/nianfo-guide",
    labelZh: "念佛入门怎么开始",
    labelEn: "Beginning Nianfo",
    titleZh: "把一句佛号慢慢接回晨起、白天和晚间。",
    titleEn: "Let one phrase of recitation settle lightly across morning, daytime, and evening.",
    descriptionZh: "如果你已经发现念佛更适合作为主线，这一页会给出更轻、更稳的起步方式。",
    descriptionEn: "This page is the better next step if recitation already feels like the right main line.",
  },
  {
    href: "/buddhist-concepts",
    labelZh: "佛学基本概念",
    labelEn: "Buddhist Concepts",
    titleZh: "先回到一张更完整的概念地图，再决定自己卡在哪个概念上。",
    titleEn: "Return to a wider concepts map before choosing which concept needs attention now.",
    descriptionZh: "如果你已经发现自己不是缺方法，而是总被因果、菩提心、六度、空性这些词反复卡住，这一页会更适合先打开。",
    descriptionEn: "Open this first if you have started to see that the problem is not a lack of methods, but repeated friction around key concepts.",
  },
  {
    href: "/download",
    labelZh: "下载入口",
    labelEn: "Download",
    titleZh: "把听诵、提醒和简单记录放进日常。",
    titleEn: "Bring listening, reminders, and simple notes into daily life.",
    descriptionZh: "准备借助 Fabushi 承接听诵、提醒和简短记录时，可以直接查看下载入口。",
    descriptionEn: "Go straight to downloads when you are ready to use Fabushi for listening, reminders, and simple notes.",
  },
] as const;

const faqItems = [
  {
    questionZh: "日常功课是不是一定要排很多才算认真？",
    questionEn: "Does a daily routine need to be heavy to count as sincere?",
    answerZh: "不需要。对初学者来说，更稳的起点通常不是一开始就排很多，而是先让一两个真实动作每天留下来。轻一点，反而更容易真正做下去。",
    answerEn: "No. For beginners, the steadier beginning is usually not a heavy plan, but one or two real actions that can stay each day.",
  },
  {
    questionZh: "先读经、先禅修，还是先把功课排出来？",
    questionEn: "Should I begin with sutras, meditation, or a daily routine first?",
    answerZh: "更重要的是看你当下最需要什么。如果需要安定，可以先从短时禅修开始；如果需要方向，可以先理清先读哪部经；如果最需要的是把练习留在生活里，就先把日常节奏排轻一点、排稳一点。",
    answerEn: "The better question is what you need most right now. If you need steadiness, begin with short meditation. If you need direction, choose the first sutra. If you need practice to stay inside life, begin by building a lighter daily rhythm.",
  },
  {
    questionZh: "先读什么佛经，和日常功课有什么关系？",
    questionEn: "What does choosing a first sutra have to do with a daily routine?",
    answerZh: "很多人功课排不下来，不是因为没有方法，而是先卡在入口经典没选清楚。先把入口经理清，晨起、白天和晚间要怎么接，通常也会一起变清楚。",
    answerEn: "Many people cannot settle into a routine not because they lack methods, but because the gateway text is still unclear. Once the entry sutra is clearer, the daily rhythm often becomes clearer too.",
  },
  {
    questionZh: "听诵和读经怎么配合，才不会只剩背景声音？",
    questionEn: "How should listening and reading work together so scripture does not become background sound?",
    answerZh: "可以把听诵当成把经典带进一天的第一步，而不是最后一步。晨起先听一小段，白天在通勤、步行或空档里回到同一段内容，晚间再读一小段原文或导读，把声音慢慢接回理解。",
    answerEn: "Treat listening as the first step that brings scripture into the day rather than the final step. Morning can start with one short passage, daytime can return to the same section, and evening can bring it back to text or a guide.",
  },
  {
    questionZh: "如果中断了几天，功课是不是就失败了？",
    questionEn: "If I miss a few days, has the routine failed?",
    answerZh: "不是。真正重要的不是从不间断，而是断掉以后能不能重新回来。中断后先把功课缩小一点，再重新开始，通常比硬撑原计划更稳。",
    answerEn: "No. What matters is not never breaking the rhythm, but being able to return after it breaks. Begin again with a smaller version instead of forcing the old plan.",
  },
  {
    questionZh: "空性怎么理解，和日常功课有什么关系？",
    questionEn: "How does understanding emptiness relate to a daily practice routine?",
    answerZh: "如果把空性只当成很远的名相，功课很容易变成完成任务。更稳的方向，是在晨起、白天和晚间慢慢看见很多情绪和判断并没有想象中那样固定，这样练习就会帮助自己少一点抓得太死。",
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

function DailyPracticeCard({ item }: { item: DailyCardItem }) {
  return (
    <article className={`daily-card daily-tone-${item.tone}`}>
      <div className="daily-card-visual" aria-hidden="true">
        <span className="daily-card-symbol">
          <LocalizedText zh={item.visualZh} en={item.visualEn} />
        </span>
        <small>
          <LocalizedText zh={item.labelZh} en={item.labelEn} />
        </small>
      </div>
      <div className="daily-card-copy">
        <p className="daily-card-kicker">
          <LocalizedText zh={item.eyebrowZh} en={item.eyebrowEn} />
        </p>
        <h3>
          <LocalizedText zh={item.titleZh} en={item.titleEn} />
        </h3>
        <p>
          <LocalizedText zh={item.bodyZh} en={item.bodyEn} />
        </p>
      </div>
      <div className="daily-card-summary">
        <p className="daily-card-stage">
          <LocalizedText zh="下一步摘要" en="Next Step Summary" />
        </p>
        <h3>
          <LocalizedText zh={item.summaryTitleZh} en={item.summaryTitleEn} />
        </h3>
        <p>
          <LocalizedText zh={item.summaryBodyZh} en={item.summaryBodyEn} />
        </p>
      </div>
      {item.href ? (
        <a className="daily-card-link" href={siteHref(item.href)}>
          <strong>
            <LocalizedText zh={item.ctaZh ?? item.labelZh} en={item.ctaEn ?? item.labelEn} />
          </strong>
          <span>
            <LocalizedText zh="继续阅读" en="Continue" />
          </span>
        </a>
      ) : null}
    </article>
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
          url: siteUrl(item.href ?? "/daily-practice"),
          description: item.summaryBodyZh,
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
          description: item.summaryBodyZh,
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
          description: item.summaryBodyZh,
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
              zh="先用静态卡牌判断入口，再顺着自己当下最需要的一张，继续读下面正文或跳进下一页。"
              en="Use static cards to choose a doorway first, then continue into the detail below or the next page."
            />
          </h2>
          <p className="daily-card-note">
            <LocalizedText
              zh="这一页现在改成 SEO 更稳的静态卡牌摘要入口，不再使用翻转交互；关键信息、下一步和链接都直接可见。"
              en="This page now uses SEO-safer static summary cards instead of flip interactions, so key guidance, next steps, and links stay directly visible."
            />
          </p>
        </div>
        <div className="daily-card-grid">
          {rhythmCards.map((item) => (
            <DailyPracticeCard key={item.labelEn} item={item} />
          ))}
        </div>
      </section>

      <section className="band alt feature-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="经典接回功课" en="Scripture Cards" />
          </p>
          <h2>
            <LocalizedText
              zh="把先读哪部经、怎样听、怎样回到晚间阅读这些真实问题，直接收进功课路径里。"
              en="Bring the real questions of which sutra to begin with, how to listen, and how to return to evening reading directly into the routine itself."
            />
          </h2>
        </div>
        <div className="daily-card-grid">
          {scriptureCards.map((item) => (
            <DailyPracticeCard key={item.labelEn} item={item} />
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="概念回路" en="Concept Cards" />
          </p>
          <h2>
            <LocalizedText
              zh="练着练着又回到因果、菩提心、六度和空性，往往不是岔开，而是路径开始变深。"
              en="When practice keeps returning to karma, bodhicitta, the six paramitas, and emptiness, the path is often deepening rather than drifting."
            />
          </h2>
        </div>
        <div className="daily-card-grid">
          {conceptCards.map((item) => (
            <DailyPracticeCard key={item.labelEn} item={item} />
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
              en="The steadier routine is usually not the one that looks most complete, but the one that can truly stay alive. Traditional learning often values whether hearing, reflection, and practice can continue into one another."
            />
          </p>
          <p>
            <LocalizedText
              zh="很多人排功课时，问题其实会慢慢变成：如果我是从《心经》或《阿弥陀经》开始，晨起该听还是读？白天只有碎片时间，经典怎么不只停在背景声音里？晚间又该怎样把听过的一句接回一点阅读或回顾？这些都不是岔题，而是日常功课真正开始落地时最自然会出现的问题。"
              en="As people begin arranging a routine, the question often shifts into whether the Heart Sutra or Amitabha Sutra should lead the day, whether morning should begin with listening or reading, how scripture can avoid becoming background sound during the day, and how one heard line can return to evening reading or review."
            />
          </p>
          <p>
            <LocalizedText
              zh="比较稳的方式，常常不是把经典和功课分成两条线，而是先定一部较合适的入口经典，再让晨起有一小段听诵或念佛，白天留一个提醒点，晚间回到原文或导读里读一小段。这样经典不只是偶尔想起时才接触，而会慢慢变成一天里的真实回返点。"
              en="A steadier way is usually not to separate scripture from routine, but to choose one fitting gateway text first, then give the morning a short listening or recitation action, the daytime one reminder point, and the evening a short return to the text or a guide."
            />
          </p>
          <p>
            <LocalizedText
              zh="日常功课的价值，也不只是把几个动作做完。随着晨起、白天和晚间慢慢出现回返点，人会开始看见：很多急躁、执着和判断，并没有想象中那样固定。功课越回到这里，练习就越不只是完成任务，而是在帮助自己多一点清醒和柔软。"
              en="The value of a daily routine is not only finishing a few actions. As morning, daytime, and evening gain small points of return, people often begin to see that agitation, attachment, and judgment are less fixed than they seemed."
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
