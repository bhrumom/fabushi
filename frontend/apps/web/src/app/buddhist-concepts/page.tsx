import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/buddhist-concepts");
const pageTitle = `佛学基本概念入门 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理佛学基本概念入门：从因果、菩提心、六度、空性，到这些概念怎样回到《心经》《普门品》《金刚经》《阿弥陀经》的阅读问题、修行方法与日常功课。";

const cardStyles = `
  .flip-card-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 18px;
  }

  .flip-card-shell {
    display: grid;
    gap: 12px;
  }

  .flip-card-toggle {
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

  .flip-card {
    position: relative;
    display: block;
    min-height: 380px;
    cursor: pointer;
    perspective: 1800px;
  }

  .flip-card-toggle:focus-visible + .flip-card {
    outline: 2px solid var(--gold-soft);
    outline-offset: 4px;
    border-radius: 8px;
  }

  .flip-card-inner {
    position: relative;
    min-height: 380px;
    transform-style: preserve-3d;
    transition: transform 760ms cubic-bezier(0.22, 0.61, 0.36, 1);
  }

  .flip-card:hover .flip-card-inner,
  .flip-card-toggle:checked + .flip-card .flip-card-inner {
    transform: rotateY(180deg);
  }

  .flip-card-face {
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

  .flip-card-back {
    transform: rotateY(180deg);
    justify-content: space-between;
    background: linear-gradient(180deg, rgba(8, 12, 18, 0.98), rgba(18, 24, 34, 0.98));
  }

  .flip-card-visual {
    position: relative;
    min-height: 150px;
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

  .flip-card-visual::before,
  .flip-card-visual::after {
    content: "";
    position: absolute;
    border-radius: 999px;
    border: 1px solid rgba(255, 249, 235, 0.18);
    opacity: 0.7;
  }

  .flip-card-visual::before {
    inset: 14px 18px auto auto;
    width: 86px;
    height: 86px;
  }

  .flip-card-visual::after {
    inset: auto auto 14px 18px;
    width: 122px;
    height: 122px;
  }

  .tone-gold .flip-card-visual {
    background:
      radial-gradient(circle at top right, rgba(255, 227, 163, 0.24), transparent 42%),
      linear-gradient(145deg, rgba(232, 189, 107, 0.22), rgba(120, 214, 232, 0.08));
  }

  .tone-cyan .flip-card-visual {
    background:
      radial-gradient(circle at top right, rgba(120, 214, 232, 0.26), transparent 42%),
      linear-gradient(145deg, rgba(120, 214, 232, 0.18), rgba(158, 215, 191, 0.1));
  }

  .tone-jade .flip-card-visual {
    background:
      radial-gradient(circle at top right, rgba(158, 215, 191, 0.24), transparent 42%),
      linear-gradient(145deg, rgba(158, 215, 191, 0.18), rgba(232, 189, 107, 0.08));
  }

  .tone-earth .flip-card-visual {
    background:
      radial-gradient(circle at top right, rgba(255, 249, 235, 0.18), transparent 42%),
      linear-gradient(145deg, rgba(255, 249, 235, 0.08), rgba(120, 214, 232, 0.06));
  }

  .flip-card-symbol {
    position: relative;
    z-index: 1;
    color: var(--ink);
    font-size: clamp(2rem, 4vw, 3rem);
    font-weight: 900;
    line-height: 1;
  }

  .flip-card-visual small {
    position: relative;
    z-index: 1;
    color: var(--gold-soft);
    font-size: 0.78rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .flip-card-kicker,
  .flip-card-hint,
  .flip-card-stage {
    margin: 0;
    color: var(--gold-soft);
    font-size: 0.78rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .flip-card-copy,
  .flip-card-back-copy {
    display: grid;
    gap: 10px;
  }

  .flip-card-copy h3,
  .flip-card-back-copy h3 {
    margin: 0;
    color: var(--ink);
    font-size: 1.18rem;
    line-height: 1.36;
  }

  .flip-card-copy p,
  .flip-card-back-copy p {
    margin: 0;
    color: var(--muted);
    line-height: 1.7;
  }

  .flip-card-hint {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    color: var(--muted-strong);
  }

  .flip-card-hint::before {
    content: "";
    width: 34px;
    height: 1px;
    background: rgba(255, 249, 235, 0.26);
  }

  .flip-card-link {
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

  .flip-card-link strong {
    color: var(--ink);
    font-size: 1rem;
    line-height: 1.3;
  }

  .flip-card-link span {
    color: var(--gold-soft);
    font-size: 0.82rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .flip-card-link:hover {
    transform: translateY(-1px);
    border-color: var(--line-strong);
    background: rgba(255, 249, 235, 0.08);
  }

  .card-intro-note {
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
    .flip-card-inner {
      transition: none;
    }
  }

  @media (max-width: 760px) {
    .flip-card,
    .flip-card-inner {
      min-height: 350px;
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

const orientationCards: FlipCardItem[] = [
  {
    id: "orientation-direction",
    tone: "gold",
    eyebrowZh: "起步判断",
    eyebrowEn: "Orientation",
    labelZh: "概念不是背名词",
    labelEn: "Concepts Are Direction",
    visualZh: "方向",
    visualEn: "Direction",
    frontTitleZh: "概念不是背名词，而是帮助修行方向站稳。",
    frontTitleEn: "Concepts are not vocabulary drills but supports for a steadier direction.",
    frontBodyZh: "如果只把因果、菩提心、六度、空性当成要记住的词，学习很快就会变重。",
    frontBodyEn: "If karma, bodhicitta, the six paramitas, and emptiness become words to memorize, learning quickly grows heavy.",
    backTitleZh: "背面看什么",
    backTitleEn: "What the back means",
    backBodyZh: "更稳的理解，是把这些概念看成帮助人看清为什么学、怎样练，以及心会慢慢往哪里走的地图。",
    backBodyEn: "A steadier understanding treats these concepts as a map that clarifies why we learn, how we practice, and where the heart slowly moves.",
  },
  {
    id: "orientation-four",
    tone: "jade",
    eyebrowZh: "起步判断",
    eyebrowEn: "Orientation",
    labelZh: "先抓四组高频概念",
    labelEn: "Start with Four High-Frequency Concepts",
    visualZh: "四门",
    visualEn: "Four Doors",
    frontTitleZh: "先抓最常反复碰到的四组概念，比一口气学完更可靠。",
    frontTitleEn: "It is steadier to begin with the four concepts that keep returning than to chase complete understanding at once.",
    frontBodyZh: "初学者最容易在入门页、修行页和佛经页之间反复遇到的，往往就是因果、菩提心、六度和空性。",
    frontBodyEn: "Across beginner, practice, and sutra pages, the concepts beginners most often meet are usually karma, bodhicitta, the six paramitas, and emptiness.",
    backTitleZh: "为什么先看这四组",
    backTitleEn: "Why these four first",
    backBodyZh: "这四组概念既高频，又能直接回到习惯、发心、做人做事与看待经验的方式，足够撑起后面的阅读和练习。",
    backBodyEn: "These four are both frequent and directly tied to habit, aspiration, conduct, and how experience is held, which is enough to support the next steps in reading and practice.",
  },
  {
    id: "orientation-return",
    tone: "cyan",
    eyebrowZh: "起步判断",
    eyebrowEn: "Orientation",
    labelZh: "看完就接回练习",
    labelEn: "Return Concepts to Practice",
    visualZh: "回路",
    visualEn: "Return Loop",
    frontTitleZh: "概念页最有价值的时候，是它能马上接回佛经、方法和日常。",
    frontTitleEn: "Concept pages matter most when they return quickly to scripture, methods, and daily life.",
    frontBodyZh: "如果看完以后没有下一步，概念很容易又变回抽象解释。",
    frontBodyEn: "Without a next step after reading, concepts easily drift back into abstraction.",
    backTitleZh: "更稳的使用方式",
    backTitleEn: "A steadier way to use them",
    backBodyZh: "翻完卡牌以后，顺着下方入口继续到佛经导读、修行方法或日常功课，让一张概念卡真的影响这一周的一个选择。",
    backBodyEn: "After flipping a card, continue into the sutra guide, practice methods, or daily routine so one concept card can shape one real choice this week.",
  },
];

const conceptCards: FlipCardItem[] = [
  {
    id: "karma",
    tone: "gold",
    eyebrowZh: "概念入口",
    eyebrowEn: "Concept Door",
    labelZh: "因果是什么意思",
    labelEn: "What Karma Means",
    visualZh: "因果",
    visualEn: "Karma",
    frontTitleZh: "先把“因果是不是报应”放清楚。",
    frontTitleEn: "Clarify whether karma is only reward and punishment.",
    frontBodyZh: "适合已经被“为什么知道要修，却总留不住节奏”这类问题卡住的人先翻开。",
    frontBodyEn: "Best for readers already caught by the question of why rhythm keeps breaking even when they know they should practice.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "这一页会把因果、业力、习惯和结果怎样慢慢形成说得更具体，也更容易接回日常选择和功课安排。",
    backBodyEn: "This page explains more concretely how karma, habit, and result gradually take shape and return to daily choices and routine design.",
    href: "/what-is-karma",
    ctaZh: "继续进入因果页",
    ctaEn: "Open karma guide",
  },
  {
    id: "bodhicitta",
    tone: "jade",
    eyebrowZh: "概念入口",
    eyebrowEn: "Concept Door",
    labelZh: "菩提心是什么意思",
    labelEn: "What Bodhicitta Means",
    visualZh: "菩提心",
    visualEn: "Bodhicitta",
    frontTitleZh: "把“对人好一点”背后更宽的发心看清。",
    frontTitleEn: "See the wider aspiration beneath the idea of simply being kind.",
    frontBodyZh: "适合已经开始追问：修行为什么不能只围着自己的得失打转的人。",
    frontBodyEn: "Best for readers beginning to ask why practice cannot revolve only around personal gain and loss.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "这一页会把愿心、利他和日常练习之间的关系收紧，让发心不再只是口号，而是能慢慢带路的方向。",
    backBodyEn: "This page tightens the relationship between aspiration, benefiting others, and ordinary practice so bodhicitta becomes a guiding direction rather than a slogan.",
    href: "/what-is-bodhicitta",
    ctaZh: "继续进入菩提心页",
    ctaEn: "Open bodhicitta guide",
  },
  {
    id: "paramitas",
    tone: "cyan",
    eyebrowZh: "概念入口",
    eyebrowEn: "Concept Door",
    labelZh: "六度分别是什么",
    labelEn: "Six Paramitas",
    visualZh: "六度",
    visualEn: "Six Paramitas",
    frontTitleZh: "把发心怎样落回做人、修心和练习里说清楚。",
    frontTitleEn: "Clarify how aspiration returns to conduct, training, and ordinary practice.",
    frontBodyZh: "适合已经听过布施、持戒、忍辱、精进、禅定、般若，却还觉得它们像远处清单的人。",
    frontBodyEn: "Best for readers who have heard the six paramitas but still experience them as a distant list.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "这一页会把六度重新接回人与人之间的相处、练习节奏和遇到挫败时怎样不立刻散掉。",
    backBodyEn: "This page returns the six paramitas to relationships, training rhythm, and the question of how not to scatter when frustration appears.",
    href: "/what-are-the-six-paramitas",
    ctaZh: "继续进入六度页",
    ctaEn: "Open six paramitas guide",
  },
  {
    id: "emptiness",
    tone: "earth",
    eyebrowZh: "概念入口",
    eyebrowEn: "Concept Door",
    labelZh: "空性怎么理解",
    labelEn: "How to Understand Emptiness",
    visualZh: "空性",
    visualEn: "Emptiness",
    frontTitleZh: "把“空是不是就是什么都没有”先放清楚。",
    frontTitleEn: "Clarify whether emptiness means that nothing exists at all.",
    frontBodyZh: "适合已经被《心经》或“空”这个字反复触动，却还没有一张更完整概念图的人。",
    frontBodyEn: "Best for readers repeatedly stirred by the Heart Sutra or the word emptiness without yet having a clearer concept map.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "这一页会把空性从抽象词句接回因缘、经验和少一点抓得太死的看法，让它不再离生活太远。",
    backBodyEn: "This page returns emptiness from abstraction to dependent arising, lived experience, and a less rigid way of seeing so it no longer feels distant from life.",
    href: "/what-is-emptiness",
    ctaZh: "继续进入空性页",
    ctaEn: "Open emptiness guide",
  },
];

const scriptureCards: FlipCardItem[] = [
  {
    id: "heart-sutra",
    tone: "cyan",
    eyebrowZh: "经典桥接",
    eyebrowEn: "Scripture Bridge",
    labelZh: "《心经》接向空性",
    labelEn: "Heart Sutra to Emptiness",
    visualZh: "心经",
    visualEn: "Heart Sutra",
    frontTitleZh: "先把熟悉的经句，接回更可用的空性理解。",
    frontTitleEn: "Bring familiar lines back into a more usable understanding of emptiness.",
    frontBodyZh: "适合已经对“色即是空”很熟，却还不知道它怎样回到经验里的人。",
    frontBodyEn: "Best for readers familiar with 'form is emptiness' but unsure how that returns to lived experience.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "先把空性的误解和基本方向看清，再回头读《心经》，通常比硬撑整页经文更容易真正读进去。",
    backBodyEn: "Clarifying the main misunderstanding and basic direction of emptiness before returning to the Heart Sutra is often steadier than forcing the whole text at once.",
    href: "/what-is-emptiness",
    ctaZh: "继续进入空性页",
    ctaEn: "Continue to emptiness",
  },
  {
    id: "universal-gate",
    tone: "jade",
    eyebrowZh: "经典桥接",
    eyebrowEn: "Scripture Bridge",
    labelZh: "《普门品》接向菩提心",
    labelEn: "Universal Gate to Bodhicitta",
    visualZh: "普门品",
    visualEn: "Universal Gate",
    frontTitleZh: "把慈悲与依止感，接回更宽的发心。",
    frontTitleEn: "Return compassion and refuge to a wider aspiration.",
    frontBodyZh: "适合已经被《普门品》安住，却想继续知道这种感受为什么不会只停在一时安慰的人。",
    frontBodyEn: "Best for readers steadied by the Universal Gate Chapter who now want to know why that feeling grows beyond temporary comfort.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "这一跳会把慈悲从“被安住”带到“愿意把路带向众生”，让《普门品》和菩提心之间的关系更清楚。",
    backBodyEn: "This bridge carries compassion from simply feeling held to the wish to orient the path toward others, clarifying why the Universal Gate Chapter connects so naturally with bodhicitta.",
    href: "/what-is-bodhicitta",
    ctaZh: "继续进入菩提心页",
    ctaEn: "Continue to bodhicitta",
  },
  {
    id: "diamond-sutra",
    tone: "gold",
    eyebrowZh: "经典桥接",
    eyebrowEn: "Scripture Bridge",
    labelZh: "《金刚经》接向六度",
    labelEn: "Diamond Sutra to Six Paramitas",
    visualZh: "金刚经",
    visualEn: "Diamond Sutra",
    frontTitleZh: "把般若怎样回到做人做事里慢慢接起来。",
    frontTitleEn: "See how wisdom returns gradually to conduct and training.",
    frontBodyZh: "适合已经被《金刚经》松动了固着看法，却还想知道下一步怎么练的人。",
    frontBodyEn: "Best for readers loosened by the Diamond Sutra who now need a clearer next step in practice.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "六度会把般若重新接回布施、持戒、忍辱、精进和禅定，让智慧不只留在观念里。",
    backBodyEn: "The six paramitas return wisdom to generosity, discipline, patience, diligence, and meditation so insight does not remain only an idea.",
    href: "/what-are-the-six-paramitas",
    ctaZh: "继续进入六度页",
    ctaEn: "Continue to six paramitas",
  },
  {
    id: "amitabha-sutra",
    tone: "earth",
    eyebrowZh: "经典桥接",
    eyebrowEn: "Scripture Bridge",
    labelZh: "《阿弥陀经》接向日常功课",
    labelEn: "Amitabha Sutra to Daily Practice",
    visualZh: "阿弥陀经",
    visualEn: "Amitabha Sutra",
    frontTitleZh: "把愿心、听诵和轻量功课放进每天的节奏。",
    frontTitleEn: "Place aspiration, listening, and a light routine into the day.",
    frontBodyZh: "适合已经觉得《阿弥陀经》很安住，却还不知道晨起、白天和晚间怎样接起来的人。",
    frontBodyEn: "Best for readers steadied by the Amitabha Sutra but still unsure how morning, daytime, and evening should connect.",
    backTitleZh: "这张卡会带你去哪",
    backTitleEn: "Where this card leads",
    backBodyZh: "这一跳不是立刻讲透全部义理，而是先让听诵、念佛、晨起和晚间回顾真的落进生活，再慢慢往下走。",
    backBodyEn: "This bridge does not force full doctrine at once. It first lets listening, recitation, morning rhythm, and evening review actually land in life before moving further.",
    href: "/daily-practice",
    ctaZh: "继续进入日常功课页",
    ctaEn: "Continue to daily practice",
  },
];

const practiceCards: FlipCardItem[] = [
  {
    id: "use-one",
    tone: "gold",
    eyebrowZh: "卡牌用法",
    eyebrowEn: "How to Use",
    labelZh: "先抓当下最卡的一张卡",
    labelEn: "Start with the Card That Matches Today",
    visualZh: "一步",
    visualEn: "Step One",
    frontTitleZh: "先从你最近最常反复碰到的词开始，不必急着全懂。",
    frontTitleEn: "Start with the concept that keeps returning lately instead of rushing to understand everything.",
    frontBodyZh: "如果最近一直碰到因果，就先翻因果；如果一直卡在“空”，就先翻空性。",
    frontBodyEn: "If karma keeps returning, begin there. If emptiness is the term that keeps stopping you, begin there instead.",
    backTitleZh: "这一张卡想帮你做到什么",
    backTitleEn: "What this card helps you do",
    backBodyZh: "先抓住最贴近当下问题的一张卡，通常比一次塞进太多概念更能让理解留下来，也更容易接回真实生活。",
    backBodyEn: "Holding the card closest to the present question usually lets understanding stay longer and return to real life more easily than taking in too many concepts at once.",
  },
  {
    id: "use-two",
    tone: "jade",
    eyebrowZh: "卡牌用法",
    eyebrowEn: "How to Use",
    labelZh: "翻完就接回佛经或练习",
    labelEn: "Return Cards to Scripture or Practice",
    visualZh: "二步",
    visualEn: "Step Two",
    frontTitleZh: "读完概念卡后，立刻接回修行方法、佛经问题或日常功课。",
    frontTitleEn: "After reading a concept card, return it immediately to methods, scripture questions, or daily routine.",
    frontBodyZh: "概念最怕只停在脑子里；一接回下一步，它就开始变成路径。",
    frontBodyEn: "Concepts grow weakest when they stay only in the head. Once returned to a next step, they begin to become path.",
    backTitleZh: "这一张卡想帮你做到什么",
    backTitleEn: "What this card helps you do",
    backBodyZh: "看完因果就回到日常功课，看完菩提心和六度就回到修行方法，看完空性就回到《心经》或佛经导读，让概念真的带路。",
    backBodyEn: "After karma, return to daily routine. After bodhicitta and the six paramitas, return to practice methods. After emptiness, return to the Heart Sutra or sutra guide so the concept can truly lead.",
  },
  {
    id: "use-three",
    tone: "cyan",
    eyebrowZh: "卡牌用法",
    eyebrowEn: "How to Use",
    labelZh: "让一张卡影响这一周一个选择",
    labelEn: "Let One Card Shape One Choice This Week",
    visualZh: "三步",
    visualEn: "Step Three",
    frontTitleZh: "不要只收藏解释，试着让一张卡真的影响本周一个动作。",
    frontTitleEn: "Do not only collect explanations. Let one card influence one real move this week.",
    frontBodyZh: "例如让因果放慢一句话，让菩提心放宽一个只围着自己的念头，让空性松一点执着。",
    frontBodyEn: "For example, let karma slow one sentence, let bodhicitta widen one self-centered impulse, or let emptiness soften one rigid grasp.",
    backTitleZh: "这一张卡想帮你做到什么",
    backTitleEn: "What this card helps you do",
    backBodyZh: "卡牌真正有力量的时候，不是翻过一次就结束，而是它会在这一周里慢慢改变说话、选择、忍耐或回顾自己的方式。",
    backBodyEn: "A card becomes powerful not when it is flipped once, but when it slowly changes speech, choice, patience, or self-review over the week.",
  },
];

const mistakeCards: FlipCardItem[] = [
  {
    id: "mistake-memorize",
    tone: "earth",
    eyebrowZh: "常见误区",
    eyebrowEn: "Common Mistake",
    labelZh: "把概念页当知识清单",
    labelEn: "Treating Concepts as a Checklist",
    visualZh: "误区",
    visualEn: "Mistake",
    frontTitleZh: "一开始就想把所有名相背完，学习会很快变重。",
    frontTitleEn: "Trying to memorize every term at once makes the path heavy quickly.",
    frontBodyZh: "这会让概念和现实生活越拉越远。",
    frontBodyEn: "It pushes concepts farther away from real life.",
    backTitleZh: "更稳的替代方式",
    backTitleEn: "A steadier alternative",
    backBodyZh: "先抓和自己当下问题最贴近的一两组概念，让它们先在说话、选择和练习里活起来，其他概念再慢慢接入。",
    backBodyEn: "Begin with one or two concept groups closest to the present question and let them come alive first in speech, choice, and practice before adding more.",
  },
  {
    id: "mistake-no-return",
    tone: "gold",
    eyebrowZh: "常见误区",
    eyebrowEn: "Common Mistake",
    labelZh: "只读概念，不接回练习",
    labelEn: "Reading Without Returning to Practice",
    visualZh: "脱节",
    visualEn: "Disconnect",
    frontTitleZh: "只在概念页停留，理解很快又会飘掉。",
    frontTitleEn: "Staying only on concept pages lets understanding drift away quickly.",
    frontBodyZh: "这是很多人觉得“明明看懂一点，过两天又没了”的原因。",
    frontBodyEn: "This is often why people feel they understood something for a moment and then lost it a few days later.",
    backTitleZh: "更稳的替代方式",
    backTitleEn: "A steadier alternative",
    backBodyZh: "翻完卡以后，立刻顺着下方入口进入佛经导读、修行方法或日常功课，让理解变成下一步行动。",
    backBodyEn: "After flipping a card, go straight into the sutra guide, practice methods, or daily routine so understanding becomes the next action.",
  },
  {
    id: "mistake-too-far",
    tone: "jade",
    eyebrowZh: "常见误区",
    eyebrowEn: "Common Mistake",
    labelZh: "一碰到难词就觉得太远",
    labelEn: "Assuming Difficult Terms Are Too Far Away",
    visualZh: "太远",
    visualEn: "Too Far",
    frontTitleZh: "很多概念听起来陌生，但它们常在回答非常具体的生活问题。",
    frontTitleEn: "Many concepts sound unfamiliar, but they often answer very concrete questions in life.",
    frontBodyZh: "例如为什么习惯会形成结果、为什么修行不能只围着自己、为什么事情没那么固定。",
    frontBodyEn: "For example, how habits become results, why practice cannot revolve only around oneself, and why things are less fixed than they seem.",
    backTitleZh: "更稳的替代方式",
    backTitleEn: "A steadier alternative",
    backBodyZh: "先把陌生词翻成自己此刻真的在问的问题，再决定要进哪一张卡，概念就不容易继续悬在空中。",
    backBodyEn: "Translate the unfamiliar term into the question you are actually living with now, then choose the next card from there so the concept stops hanging in the air.",
  },
];

const relatedCards: FlipCardItem[] = [
  {
    id: "related-start",
    tone: "gold",
    eyebrowZh: "继续阅读",
    eyebrowEn: "Keep Going",
    labelZh: "学佛从哪里开始",
    labelEn: "Where to Begin",
    visualZh: "起步",
    visualEn: "Start",
    frontTitleZh: "如果你还在找整个入门阶段的第一步，先回起步页。",
    frontTitleEn: "Return to the beginner page first if you still need the first step for the whole path.",
    frontBodyZh: "这张页会把先看整体、先练习、先读经还是先看概念的顺序理得更轻。",
    frontBodyEn: "That page lightens the order between beginning with the wider map, practice, sutra study, or concepts.",
    backTitleZh: "为什么下一步去这里",
    backTitleEn: "Why go here next",
    backBodyZh: "当问题还停在“我到底该先从哪条路开始”时，起步页比继续深挖单张概念卡更适合作为下一跳。",
    backBodyEn: "When the question is still simply where to begin, the beginner page is steadier than going deeper into one concept card immediately.",
    href: "/start-learning-buddhism",
    ctaZh: "继续进入起步页",
    ctaEn: "Open where to begin",
  },
  {
    id: "related-basics",
    tone: "earth",
    eyebrowZh: "继续阅读",
    eyebrowEn: "Keep Going",
    labelZh: "佛法入门",
    labelEn: "Dharma Basics",
    visualZh: "佛法",
    visualEn: "Basics",
    frontTitleZh: "想把概念、佛经、修行和日常放回一张更大地图里，先回佛法入门。",
    frontTitleEn: "Return to dharma basics if you want concepts, scripture, practice, and daily life back on one wider map.",
    frontBodyZh: "适合已经不只想看一个概念，而是想重新看到整体方向的人。",
    frontBodyEn: "Best for readers who now need the broader direction instead of only one concept doorway.",
    backTitleZh: "为什么下一步去这里",
    backTitleEn: "Why go here next",
    backBodyZh: "佛法入门页会把概念卡收回更完整的学习地图，让你看见它们在整条路上的位置，而不是只停在局部。",
    backBodyEn: "The dharma basics page returns these concept cards to a fuller learning map so their place on the wider path becomes easier to see.",
    href: "/buddhadharma",
    ctaZh: "继续进入佛法入门",
    ctaEn: "Open dharma basics",
  },
  {
    id: "related-practice",
    tone: "jade",
    eyebrowZh: "继续阅读",
    eyebrowEn: "Keep Going",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    visualZh: "方法",
    visualEn: "Practice",
    frontTitleZh: "概念清楚一点后，下一步就让它回到禅修、听诵、念佛和记录。",
    frontTitleEn: "Once the concepts are a little clearer, return them to meditation, listening, recitation, and notes.",
    frontBodyZh: "适合已经准备把“懂一点”接成“开始练一点”的人。",
    frontBodyEn: "Best for readers ready to turn understanding into the beginning of regular practice.",
    backTitleZh: "为什么下一步去这里",
    backTitleEn: "Why go here next",
    backBodyZh: "修行方法总览页会把概念直接接回练习方式，让发心、六度、空性不只停在理解层，而开始落回动作层。",
    backBodyEn: "The practice guide returns these concepts directly to methods so bodhicitta, the six paramitas, and emptiness move from understanding into action.",
    href: "/practice-guide",
    ctaZh: "继续进入修行方法",
    ctaEn: "Open practice guide",
  },
  {
    id: "related-sutra",
    tone: "cyan",
    eyebrowZh: "继续阅读",
    eyebrowEn: "Keep Going",
    labelZh: "佛经导读",
    labelEn: "Sutra Guide",
    visualZh: "经典",
    visualEn: "Sutras",
    frontTitleZh: "如果这些概念主要是在读经时反复碰到，下一步回佛经导读。",
    frontTitleEn: "Return to the sutra guide if these concepts mainly keep appearing while you read scripture.",
    frontBodyZh: "它会把读什么、怎么读、怎么和听诵配合重新整理成一条路。",
    frontBodyEn: "It reorganizes what to read, how to read, and how listening works together with reading into one path.",
    backTitleZh: "为什么下一步去这里",
    backTitleEn: "Why go here next",
    backBodyZh: "佛经导读页能把单张概念卡重新接回读经问题，不让理解断在一个词上，而是继续走进经典本身。",
    backBodyEn: "The sutra guide reconnects a single concept card to real reading questions so understanding does not stop at one term but continues into the texts themselves.",
    href: "/sutra-guide",
    ctaZh: "继续进入佛经导读",
    ctaEn: "Open sutra guide",
  },
];

const faqCards: FlipCardItem[] = [
  {
    id: "faq-all",
    tone: "gold",
    eyebrowZh: "FAQ 卡牌",
    eyebrowEn: "FAQ Card",
    labelZh: "是不是一定要一口气全懂？",
    labelEn: "Do I Need to Understand Everything at Once?",
    visualZh: "全懂",
    visualEn: "All at Once",
    frontTitleZh: "佛学基本概念是不是一定要一口气全懂？",
    frontTitleEn: "Do I need to understand all the basic buddhist concepts at once?",
    frontBodyZh: "很多初学者正是在这里把学习一下拉得太重。",
    frontBodyEn: "Many beginners make the path too heavy at exactly this point.",
    backTitleZh: "简短回答",
    backTitleEn: "Short answer",
    backBodyZh: "不需要。更稳的方式通常是先抓住最近最常反复碰到的一两个概念，让理解开始有顺序，而不是追求第一天就全懂。",
    backBodyEn: "No. A steadier way is usually to begin with one or two concepts that keep returning lately so understanding gains order instead of demanding total mastery on day one.",
  },
  {
    id: "faq-karma-emptiness",
    tone: "earth",
    eyebrowZh: "FAQ 卡牌",
    eyebrowEn: "FAQ Card",
    labelZh: "先看因果还是空性？",
    labelEn: "Karma First or Emptiness First?",
    visualZh: "先后",
    visualEn: "Sequence",
    frontTitleZh: "应该先懂因果，还是先懂空性？",
    frontTitleEn: "Should I understand karma first or emptiness first?",
    frontBodyZh: "这个问题常常不是标准答案，而是看你现在最常被哪类问题卡住。",
    frontBodyEn: "This usually depends less on a fixed rule and more on the question that is already stopping you now.",
    backTitleZh: "简短回答",
    backTitleEn: "Short answer",
    backBodyZh: "很多人会先从因果进入，因为它更贴近日常习惯与选择；如果你已经被《心经》或“空”这个字反复困住，先看空性也完全可以。",
    backBodyEn: "Many people enter through karma first because it sits closer to habit and choice. If the Heart Sutra or the language of emptiness already keeps catching you, starting with emptiness can be exactly right.",
  },
  {
    id: "faq-daily-life",
    tone: "jade",
    eyebrowZh: "FAQ 卡牌",
    eyebrowEn: "FAQ Card",
    labelZh: "这些概念会不会太远？",
    labelEn: "Are These Concepts Too Far Away?",
    visualZh: "日常",
    visualEn: "Daily Life",
    frontTitleZh: "这些概念会不会离日常生活太远？",
    frontTitleEn: "Are these concepts too far from ordinary life?",
    frontBodyZh: "这是很多人刚碰到名相时最自然的反应。",
    frontBodyEn: "This is one of the most natural first reactions when unfamiliar terms appear.",
    backTitleZh: "简短回答",
    backTitleEn: "Short answer",
    backBodyZh: "通常不是。因果会回到今天的说话和选择，菩提心会回到发心是不是只围着自己，六度会回到忍耐和做人做事，空性会回到是不是把事情抓得太死。",
    backBodyEn: "Usually not. Karma returns to speech and choice, bodhicitta to whether aspiration circles only around oneself, the six paramitas to patience and conduct, and emptiness to whether we grip things too rigidly.",
  },
  {
    id: "faq-sutra-concepts",
    tone: "cyan",
    eyebrowZh: "FAQ 卡牌",
    eyebrowEn: "FAQ Card",
    labelZh: "读经时看不懂怎么办？",
    labelEn: "What if I Do Not Understand While Reading?",
    visualZh: "读经",
    visualEn: "Reading",
    frontTitleZh: "读佛经时碰到概念看不懂怎么办？",
    frontTitleEn: "What should I do when a sutra introduces concepts I do not understand?",
    frontBodyZh: "很多人不是不想读，而是读到一句就被概念绊住。",
    frontBodyEn: "Many readers do want to continue, but one concept stops them after a single line.",
    backTitleZh: "简短回答",
    backTitleEn: "Short answer",
    backBodyZh: "可以先把那个概念单独抽出来看，不必硬撑着整段都懂完。读《心经》卡在空性，就先去看空性页；读《普门品》卡在慈悲为何会长成更宽的方向，就先去看菩提心页。",
    backBodyEn: "Pull the concept out and look at it on its own instead of forcing the whole passage. If the Heart Sutra stalls you on emptiness, read the emptiness page first. If the Universal Gate Chapter stalls you on how compassion widens into a path, go first to bodhicitta.",
  },
  {
    id: "faq-heart-sutra",
    tone: "earth",
    eyebrowZh: "FAQ 卡牌",
    eyebrowEn: "FAQ Card",
    labelZh: "为什么《心经》总把人带到空性？",
    labelEn: "Why Does the Heart Sutra Lead to Emptiness?",
    visualZh: "心经",
    visualEn: "Heart Sutra",
    frontTitleZh: "《心经》为什么常把人带到空性？",
    frontTitleEn: "Why does the Heart Sutra so often lead people into the question of emptiness?",
    frontBodyZh: "因为很多人先被经句打动，却还没有足够的概念地图去接住它。",
    frontBodyEn: "Because many readers are moved by the lines before they have a clear enough concept map to hold them.",
    backTitleZh: "简短回答",
    backTitleEn: "Short answer",
    backBodyZh: "问题很快会变成：空性到底是不是什麽都没有？这正是《心经》和空性页最自然接起来的地方，也是先翻这一张卡的价值。",
    backBodyEn: "The question quickly becomes whether emptiness means nothingness. That is exactly where the Heart Sutra and the emptiness page connect most naturally, and why flipping that card first helps.",
  },
  {
    id: "faq-universal-gate",
    tone: "jade",
    eyebrowZh: "FAQ 卡牌",
    eyebrowEn: "FAQ Card",
    labelZh: "为什么《普门品》常连到菩提心？",
    labelEn: "Why Does the Universal Gate Chapter Connect to Bodhicitta?",
    visualZh: "普门品",
    visualEn: "Universal Gate",
    frontTitleZh: "《普门品》为什么常和菩提心连在一起？",
    frontTitleEn: "Why does the Universal Gate Chapter often connect naturally with bodhicitta?",
    frontBodyZh: "很多人先感到慈悲和依止感，下一步才开始问这种感受为什么会继续长成更宽的方向。",
    frontBodyEn: "Many readers first feel compassion and refuge, then begin to ask why that feeling grows into a wider direction.",
    backTitleZh: "简短回答",
    backTitleEn: "Short answer",
    backBodyZh: "它们相接的关键，在于慈悲不会只停在一时安慰，而会慢慢长成愿意把修行带向众生利益的发心，这正是菩提心页会继续说明的部分。",
    backBodyEn: "They connect because compassion does not need to stay as temporary comfort. It can widen into the aspiration to carry practice toward the welfare of others, which is exactly what the bodhicitta page continues to explain.",
  },
];

function FlipCard({ item }: { item: FlipCardItem }) {
  const toggleId = `flip-card-${item.id}`;

  return (
    <article className={`flip-card-shell tone-${item.tone}`}>
      <input id={toggleId} className="flip-card-toggle" type="checkbox" />
      <label className="flip-card" htmlFor={toggleId}>
        <div className="flip-card-inner">
          <div className="flip-card-face flip-card-front">
            <div className="flip-card-visual" aria-hidden="true">
              <span className="flip-card-symbol">{item.visualZh}</span>
              <small>{item.visualEn}</small>
            </div>
            <div className="flip-card-copy">
              <p className="flip-card-kicker">
                <LocalizedText zh={item.eyebrowZh} en={item.eyebrowEn} />
              </p>
              <h3>
                <LocalizedText zh={item.frontTitleZh} en={item.frontTitleEn} />
              </h3>
              <p>
                <LocalizedText zh={item.frontBodyZh} en={item.frontBodyEn} />
              </p>
            </div>
            <p className="flip-card-hint">
              <LocalizedText zh="点开翻面" en="Tap to flip" />
            </p>
          </div>
          <div className="flip-card-face flip-card-back">
            <div className="flip-card-back-copy">
              <p className="flip-card-stage">
                <LocalizedText zh={item.labelZh} en={item.labelEn} />
              </p>
              <h3>
                <LocalizedText zh={item.backTitleZh} en={item.backTitleEn} />
              </h3>
              <p>
                <LocalizedText zh={item.backBodyZh} en={item.backBodyEn} />
              </p>
            </div>
            <p className="flip-card-hint">
              <LocalizedText zh="再点一次回到正面" en="Tap again to return" />
            </p>
          </div>
        </div>
      </label>
      {item.href && item.ctaZh && item.ctaEn ? (
        <a className="flip-card-link" href={siteHref(item.href)}>
          <strong>
            <LocalizedText zh={item.ctaZh} en={item.ctaEn} />
          </strong>
          <span>
            <LocalizedText zh={item.labelZh} en={item.labelEn} />
          </span>
        </a>
      ) : null}
    </article>
  );
}

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
    "心经 空性",
    "普门品 菩提心",
    "金刚经 六度",
    "阿弥陀经 日常功课",
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
        about: ["佛学基本概念", "因果", "菩提心", "六度", "空性", "心经", "普门品", "金刚经", "阿弥陀经"],
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
        itemListElement: conceptCards.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.labelZh,
          url: siteUrl(item.href ?? "/buddhist-concepts"),
          description: item.backBodyZh,
        })),
      },
      {
        "@type": "ItemList",
        name: "经典入口与概念路径",
        itemListElement: scriptureCards.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.labelZh,
          url: siteUrl(item.href ?? "/buddhist-concepts"),
          description: item.backBodyZh,
        })),
      },
      {
        "@type": "FAQPage",
        mainEntity: faqCards.map((item) => ({
          "@type": "Question",
          name: item.frontTitleZh,
          acceptedAnswer: {
            "@type": "Answer",
            text: item.backBodyZh,
          },
        })),
      },
    ],
  };

  return (
    <main className="inner-page">
      <style jsx global>{cardStyles}</style>
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
              zh="把因果、菩提心、六度和空性，收成一组更容易翻看、更容易走下去的概念卡牌。"
              en="Turn karma, bodhicitta, the six paramitas, and emptiness into a concept deck that is easier to scan and easier to keep walking with."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="很多人不是不愿意学佛，而是总在不同页面、不同经典和不同建议里反复碰到这些词，却不知道先看哪一个、看完又该往哪里走。这一页把概念入口、经典桥接、起步方法和 FAQ 收成可翻转的卡牌，让你先看见自己当下最该翻开的那一张。"
              en="Many people are not unwilling to begin buddhadharma. They simply keep meeting the same words across different pages, sutras, and advice without knowing which one to open first or where to go next. This page gathers concept doors, scripture bridges, beginner use notes, and FAQ into a set of flip cards so you can start with the one that matches your present question."
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
              zh="先把概念收成一张可翻看的地图，后面的佛经、修行和日常路径才不容易越走越散。"
              en="Gather the concepts into a flip-through map first so the later paths of scripture, practice, and daily life do not scatter."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="很多初学者真正卡住的，并不是没有内容，而是总在不同地方反复碰到因果、菩提心、六度、空性这些词，却不知道它们彼此是什么关系。词越来越多，心里反而更容易觉得佛法离自己很远。"
              en="What often stops beginners is not a lack of content, but meeting karma, bodhicitta, the six paramitas, and emptiness again and again in different places without knowing how they relate. As the language multiplies, buddhadharma can begin to feel farther away instead of closer."
            />
          </p>
          <p>
            <LocalizedText
              zh="这次把页面改成卡牌，不是为了做样子，而是为了让每一张卡只承载一个问题：正面先帮你判断“这是不是我现在最该看的入口”，背面再给出更完整的解释，然后顺着卡下方的继续入口走到对应页面。这样概念就不只停在解释层，而会开始带路。"
              en="This page is card-based for a practical reason rather than decoration. Each card now carries one question: the front helps you judge whether it is the right doorway for this moment, the back gives the fuller explanation, and the link underneath sends you into the matching page. In that form, concepts stop being explanation alone and begin to guide movement."
            />
          </p>
          <p className="card-intro-note">
            <LocalizedText zh="先看正面，确认是不是你的问题，再翻到背面读完整解释。" en="Read the front first, see whether it matches your question, then flip for the fuller explanation." />
          </p>
        </div>
      </section>

      <section className="band alt feature-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="起步判断" en="Orientation" />
          </p>
          <h2>
            <LocalizedText
              zh="先把理解佛学概念时最稳的三个判断放好。"
              en="Set three steady judgments in place before going deeper into the concept deck."
            />
          </h2>
        </div>
        <div className="flip-card-grid">
          {orientationCards.map((item) => (
            <FlipCard key={item.id} item={item} />
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="概念卡牌" en="Concept Deck" />
          </p>
          <h2>
            <LocalizedText
              zh="先翻开你现在最常反复碰到的那一张概念卡。"
              en="Begin with the concept card that is already returning most often in your life."
            />
          </h2>
        </div>
        <div className="flip-card-grid">
          {conceptCards.map((item) => (
            <FlipCard key={item.id} item={item} />
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="经典桥接卡牌" en="Scripture Bridges" />
          </p>
          <h2>
            <LocalizedText
              zh="把《心经》《普门品》《金刚经》《阿弥陀经》常见入口，直接接回已经存在的概念页和功课页。"
              en="Connect the common entry points of the Heart Sutra, Universal Gate Chapter, Diamond Sutra, and Amitabha Sutra directly to the concept and routine pages that already exist."
            />
          </h2>
        </div>
        <div className="flip-card-grid">
          {scriptureCards.map((item) => (
            <FlipCard key={item.id} item={item} />
          ))}
        </div>
      </section>

      <section className="band feature-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="怎么使用" en="How to Use" />
          </p>
          <h2>
            <LocalizedText
              zh="把概念从“看懂一点”接回“这一周真的有一点变化”。"
              en="Move a concept from partial understanding into one real change this week."
            />
          </h2>
        </div>
        <div className="flip-card-grid">
          {practiceCards.map((item) => (
            <FlipCard key={item.id} item={item} />
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="常见误区卡牌" en="Common Mistakes" />
          </p>
          <h2>
            <LocalizedText
              zh="先避开几个会让佛学概念越学越重、越学越散的误区。"
              en="Avoid the patterns that make buddhist concepts feel heavier and more fragmented than they need to be."
            />
          </h2>
        </div>
        <div className="flip-card-grid">
          {mistakeCards.map((item) => (
            <FlipCard key={item.id} item={item} />
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="继续阅读卡牌" en="Keep Going" />
          </p>
          <h2>
            <LocalizedText
              zh="顺着你当下最需要的方向，把概念重新接回起步、佛法、修行和佛经路径。"
              en="Reconnect concepts to the beginner, dharma, practice, and scripture paths that match what you need most now."
            />
          </h2>
        </div>
        <div className="flip-card-grid">
          {relatedCards.map((item) => (
            <FlipCard key={item.id} item={item} />
          ))}
        </div>
      </section>

      <section className="band faq-band">
        <div className="section-heading tight">
          <p>FAQ</p>
          <h2>
            <LocalizedText
              zh="把最常继续追问的问题，也收成可翻看的 FAQ 卡牌。"
              en="Turn the most common follow-up questions into a flip-through FAQ deck as well."
            />
          </h2>
        </div>
        <div className="flip-card-grid">
          {faqCards.map((item) => (
            <FlipCard key={item.id} item={item} />
          ))}
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
