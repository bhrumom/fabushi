import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/nianfo-guide");
const pageTitle = `念佛入门怎么开始 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理念佛入门怎么开始：先用一句佛号安住心念，再把晨起、白天和晚间的轻量节奏接起来，并把念佛和佛经听诵、日常功课、菩提心、因果与六度慢慢放回同一条修行路径。";

const cardStyles = `
  .nianfo-card-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 18px;
  }

  .nianfo-card {
    display: grid;
    gap: 16px;
    padding: 22px;
    border: 1px solid var(--line);
    border-radius: 8px;
    background: linear-gradient(180deg, rgba(255, 249, 235, 0.08), rgba(10, 15, 22, 0.96));
    box-shadow: var(--shadow);
  }

  .nianfo-card-visual {
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

  .nianfo-card-visual::before,
  .nianfo-card-visual::after {
    content: "";
    position: absolute;
    border-radius: 999px;
    border: 1px solid rgba(255, 249, 235, 0.18);
    opacity: 0.72;
  }

  .nianfo-card-visual::before {
    inset: 14px 18px auto auto;
    width: 82px;
    height: 82px;
  }

  .nianfo-card-visual::after {
    inset: auto auto 16px 18px;
    width: 118px;
    height: 118px;
  }

  .nianfo-tone-gold .nianfo-card-visual {
    background:
      radial-gradient(circle at top right, rgba(255, 227, 163, 0.24), transparent 42%),
      linear-gradient(145deg, rgba(232, 189, 107, 0.22), rgba(120, 214, 232, 0.08));
  }

  .nianfo-tone-cyan .nianfo-card-visual {
    background:
      radial-gradient(circle at top right, rgba(120, 214, 232, 0.26), transparent 42%),
      linear-gradient(145deg, rgba(120, 214, 232, 0.18), rgba(158, 215, 191, 0.1));
  }

  .nianfo-tone-jade .nianfo-card-visual {
    background:
      radial-gradient(circle at top right, rgba(158, 215, 191, 0.24), transparent 42%),
      linear-gradient(145deg, rgba(158, 215, 191, 0.18), rgba(232, 189, 107, 0.08));
  }

  .nianfo-tone-earth .nianfo-card-visual {
    background:
      radial-gradient(circle at top right, rgba(255, 249, 235, 0.18), transparent 42%),
      linear-gradient(145deg, rgba(255, 249, 235, 0.08), rgba(120, 214, 232, 0.06));
  }

  .nianfo-card-symbol {
    position: relative;
    z-index: 1;
    color: var(--ink);
    font-size: clamp(2rem, 4vw, 3rem);
    font-weight: 900;
    line-height: 1;
  }

  .nianfo-card-visual small,
  .nianfo-card-kicker,
  .nianfo-card-stage {
    position: relative;
    z-index: 1;
    margin: 0;
    color: var(--gold-soft);
    font-size: 0.78rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .nianfo-card-copy,
  .nianfo-card-summary {
    display: grid;
    gap: 10px;
  }

  .nianfo-card-copy h3,
  .nianfo-card-summary h3 {
    margin: 0;
    color: var(--ink);
    font-size: 1.16rem;
    line-height: 1.36;
  }

  .nianfo-card-copy p,
  .nianfo-card-summary p {
    margin: 0;
    color: var(--muted);
    line-height: 1.7;
  }

  .nianfo-card-summary {
    padding-top: 14px;
    border-top: 1px solid rgba(255, 249, 235, 0.12);
  }

  .nianfo-card-link {
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

  .nianfo-card-link strong {
    color: var(--ink);
    font-size: 1rem;
    line-height: 1.3;
  }

  .nianfo-card-link span {
    color: var(--gold-soft);
    font-size: 0.82rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .nianfo-card-link:hover {
    transform: translateY(-1px);
    border-color: var(--line-strong);
    background: rgba(255, 249, 235, 0.08);
  }

  .nianfo-card-note {
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

interface NianfoCardItem {
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

const starterCards: NianfoCardItem[] = [
  {
    tone: "gold",
    eyebrowZh: "入门节奏",
    eyebrowEn: "Starter Rhythm",
    labelZh: "先让一句佛号留下来",
    labelEn: "Let One Phrase Stay",
    visualZh: "佛号",
    visualEn: "Name",
    titleZh: "念佛入门最稳的开始，通常不是数量很多，而是先让一句佛号真的留得下来。",
    titleEn: "The steadiest beginning for nianfo is usually not a large count, but letting one phrase of recitation truly stay.",
    bodyZh: "先在晨起或睡前留两三分钟，轻声念、默念都可以。重点不是声音多大，而是心里有没有一个愿意回来的地方。",
    bodyEn: "Begin with two or three minutes in the morning or before sleep. Gentle vocal recitation or silent repetition both work. The point is not volume, but whether the heart has a place it is willing to return to.",
    summaryTitleZh: "这张卡先帮你定什么",
    summaryTitleEn: "What this card sets first",
    summaryBodyZh: "先把入口缩小到一句佛号和一个固定时段。入口够轻，连续几天以后，念佛才会开始从“记得做一项功课”变成“心里自然会回来”的节奏。",
    summaryBodyEn: "This card reduces the doorway to one phrase and one stable time of day. When the entry is light enough to stay for a few days, recitation begins shifting from a task you remember to a rhythm the heart returns to naturally.",
  },
  {
    tone: "cyan",
    eyebrowZh: "入门节奏",
    eyebrowEn: "Starter Rhythm",
    labelZh: "白天留一个短回返点",
    labelEn: "Keep One Daytime Return",
    visualZh: "白天",
    visualEn: "Daytime",
    titleZh: "念佛要真正进入生活，往往不是只靠早晚两段，而是白天也留一个最容易实现的回返点。",
    titleEn: "For recitation to really enter daily life, it usually needs more than morning and evening alone. Keep one easy daytime return point as well.",
    bodyZh: "通勤、步行、排队或工作转场时，都可以留一小段默念。哪怕只有几十秒，也比整天完全断开更能让功课慢慢活起来。",
    bodyEn: "A commute, walk, queue, or pause between tasks can each hold a short stretch of silent recitation. Even a few seconds keeps the practice more alive than a whole day of complete disconnection.",
    summaryTitleZh: "这张卡先帮你避免什么",
    summaryTitleEn: "What this card helps prevent",
    summaryBodyZh: "它在避免念佛只变成早晚两端的动作。白天哪怕只有一次轻轻回念，练习也更容易开始回到说话、做事和待人处事里。",
    summaryBodyEn: "It prevents recitation from shrinking into an action that lives only at the edges of the day. Even one light daytime return lets practice begin re-entering speech, work, and relationship.",
  },
  {
    tone: "jade",
    eyebrowZh: "入门节奏",
    eyebrowEn: "Starter Rhythm",
    labelZh: "晚间用短回顾收住",
    labelEn: "Close with Review",
    visualZh: "晚间",
    visualEn: "Evening",
    titleZh: "晚间不用再加很重的功课，只要轻轻收住今天念佛有没有回来过、哪一刻最容易散掉。",
    titleEn: "The evening does not need a heavy extra routine. It only needs to gather the day gently and notice whether recitation returned and where it scattered most easily.",
    bodyZh: "可以补一小段导读、听一段经文，或只留一句记录。先让自己看见今天真正留住了什么，比一开始排得很满更稳。",
    bodyEn: "You can add a short guide, one scripture passage, or only a single note. Seeing what truly stayed today is steadier than making the whole routine too full at the beginning.",
    summaryTitleZh: "这张卡把什么接回来",
    summaryTitleEn: "What this card brings back",
    summaryBodyZh: "它把“今天有没有回来过一次”重新看见。晚间的轻回顾能让念佛不只是白天一闪而过，而是慢慢变成愿意继续走下去的路径。",
    summaryBodyEn: "It brings back the simple question of whether you returned at least once today. A light evening review keeps recitation from becoming a passing moment and helps it grow into a path you are willing to continue.",
    href: "/daily-practice",
    ctaZh: "继续看日常功课怎么安排",
    ctaEn: "Open the daily practice guide",
  },
];

const bridgeCards: NianfoCardItem[] = [
  {
    tone: "gold",
    eyebrowZh: "经典接回念佛",
    eyebrowEn: "Scripture and Recitation",
    labelZh: "先把入口经典选清楚",
    labelEn: "Choose the Entry Text",
    visualZh: "经典",
    visualEn: "Scripture",
    titleZh: "很多人念佛迟迟留不下来，不是不愿意练，而是还没把自己要从哪一部经典、哪一句佛号进来理清。",
    titleEn: "Many people cannot keep recitation alive not because they resist practice, but because they still have not clarified which text or phrase should become the doorway.",
    bodyZh: "如果你想从《阿弥陀经》、观音圣号或更轻的听诵入口开始，先把入口选清楚，后面的晨起、白天和晚间才更容易接起来。",
    bodyEn: "If you want to begin through the Amitabha Sutra, Guanyin recitation, or a lighter listening entry, clarifying that doorway first makes morning, daytime, and evening rhythm easier to connect.",
    summaryTitleZh: "这张卡会把你送去哪",
    summaryTitleEn: "Where this card leads",
    summaryBodyZh: "先把“从哪一部经、哪一句佛号进”收清楚，很多“要不要加别的方法”的犹豫也会一起变少。让入口先稳定，比一开始四处分散更稳。",
    summaryBodyEn: "Once you settle which text or phrase you are entering through, much of the hesitation about whether to add other methods also begins to quiet down. A stable doorway is steadier than scattering across too many directions at once.",
    href: "/beginner-sutra-recommendations",
    ctaZh: "继续看初学者佛经推荐",
    ctaEn: "Open beginner sutra picks",
  },
  {
    tone: "cyan",
    eyebrowZh: "经典接回念佛",
    eyebrowEn: "Scripture and Recitation",
    labelZh: "把听诵接回一句佛号",
    labelEn: "Return Listening to Recitation",
    visualZh: "听诵",
    visualEn: "Listening",
    titleZh: "真正的卡点常常不是“要不要听”，而是听诵以后怎样把那一点安住感接回一句佛号。",
    titleEn: "The real friction is often not whether to listen, but how listening returns the steadiness it gives into one living phrase of recitation.",
    bodyZh: "晨起先听一小段，白天回到同一段，晚间再用一句佛号把它轻轻收住，声音和佛号就比较不会分成两条线。",
    bodyEn: "Listen to one short passage in the morning, return to the same section during the day, then let one phrase of recitation gather it gently at night so sound and recitation do not split into separate tracks.",
    summaryTitleZh: "这张卡先帮你看什么",
    summaryTitleEn: "What this card helps you see",
    summaryBodyZh: "它会把“听经”和“念佛”重新接回同一条线。听诵先帮你熟悉语境，佛号再把这份熟悉感接回一整天真正会出现的回返点。",
    summaryBodyEn: "It reconnects listening and recitation into one line. Listening helps establish the atmosphere first, and the recited phrase returns that familiarity to a return point that can actually arise during the day.",
    href: "/sutra-listening",
    ctaZh: "继续看听诵和读经怎么配合",
    ctaEn: "Open listening and reading guide",
  },
  {
    tone: "jade",
    eyebrowZh: "经典接回念佛",
    eyebrowEn: "Scripture and Recitation",
    labelZh: "念佛不是只求数量",
    labelEn: "Recitation Is Not Only Count",
    visualZh: "方向",
    visualEn: "Direction",
    titleZh: "如果念佛只剩“今天念了多少”，它很容易越做越硬；把愿心和方向放回去，节奏才更容易柔软下来。",
    titleEn: "When recitation becomes only about how much was done today, it quickly grows rigid. When aspiration and direction return, the rhythm becomes easier to soften.",
    bodyZh: "念佛和日常功课真正要接住的，不只是重复，而是让自己一次次回到愿意清醒、愿意柔软、愿意把这条路继续带向众生利益的方向。",
    bodyEn: "What recitation and daily routine finally need to hold is not repetition alone, but the repeated return to clarity, softness, and a path willing to grow toward the welfare of others.",
    summaryTitleZh: "这张卡把什么放清楚",
    summaryTitleEn: "What this card clarifies",
    summaryBodyZh: "它把“为什么念佛”先放稳。功课一旦有了愿心，就不再只是完成数量，而开始变成一条更宽、更能长期走下去的修行路径。",
    summaryBodyEn: "It steadies the question of why you recite in the first place. Once aspiration is present, the routine stops being only about quantity and becomes a wider path that can be lived for longer.",
    href: "/what-is-bodhicitta",
    ctaZh: "继续看菩提心是什么意思",
    ctaEn: "Open the bodhicitta guide",
  },
];

const conceptCards: NianfoCardItem[] = [
  {
    tone: "gold",
    eyebrowZh: "概念回路",
    eyebrowEn: "Concept Bridge",
    labelZh: "因果会解释为什么总断",
    labelEn: "Karma Explains Breaks",
    visualZh: "因果",
    visualEn: "Karma",
    titleZh: "为什么明明知道该念，节奏却总留不住，往往会回到因果、习惯和结果怎样慢慢形成。",
    titleEn: "Why the recitation rhythm keeps failing often returns to how karma, habit, and result gradually take shape together.",
    bodyZh: "回到因果，不是为了责备自己，而是看见每天一句佛号、一次回念，怎样真的会慢慢改变后面的走向。",
    bodyEn: "Returning to karma is not about blame, but about seeing how one phrase and one return point each day really does begin changing what follows.",
    summaryTitleZh: "这张卡适合什么时候看",
    summaryTitleEn: "When this card fits best",
    summaryBodyZh: "如果你最常卡在“知道应该念，却总是断掉”，先回因果页会比继续给自己加更多动作更稳。它能把习惯、选择和结果怎样互相牵动说得更清楚。",
    summaryBodyEn: "If your main friction is knowing you should recite but still breaking the rhythm, the karma page is often steadier than adding more actions. It clarifies how habit, choice, and result move each other.",
    href: "/what-is-karma",
    ctaZh: "继续看因果是什么意思",
    ctaEn: "Open the karma guide",
  },
  {
    tone: "cyan",
    eyebrowZh: "概念回路",
    eyebrowEn: "Concept Bridge",
    labelZh: "六度会解释念佛怎样落回做人做事",
    labelEn: "The Six Paramitas Return Recitation to Life",
    visualZh: "六度",
    visualEn: "Paramitas",
    titleZh: "念佛为什么不只是重复一件事，常常会在六度这里被说清楚。",
    titleEn: "Why recitation is more than repetition is often clarified through the six paramitas.",
    bodyZh: "布施、持戒、忍辱、精进、禅定和般若，会把一句佛号慢慢带回耐心、方向、待人处事和日常选择里。",
    bodyEn: "Generosity, discipline, patience, diligence, meditation, and wisdom slowly return one phrase of recitation to patience, direction, conduct, and daily choice.",
    summaryTitleZh: "这张卡会把哪一步接出来",
    summaryTitleEn: "What this card draws out",
    summaryBodyZh: "它会把“念佛怎样不只留在口里”说清楚。练习真正开始落地，往往不是数量上去了，而是做人做事和心念也慢慢跟着转。",
    summaryBodyEn: "It clarifies how recitation stops living only on the lips. Practice often begins landing for real not when the count increases, but when conduct and the heart begin changing with it.",
    href: "/what-are-the-six-paramitas",
    ctaZh: "继续看六度分别是什么",
    ctaEn: "Open the six paramitas guide",
  },
  {
    tone: "earth",
    eyebrowZh: "概念回路",
    eyebrowEn: "Concept Bridge",
    labelZh: "先回概念地图，再决定往哪一页继续",
    labelEn: "Return to the Concepts Map",
    visualZh: "地图",
    visualEn: "Map",
    titleZh: "如果你已经发现自己不只是缺方法，而是总被名相挡住，先回概念总览会更稳。",
    titleEn: "If you have begun to see the friction is not only method but repeated blockage around core terms, returning to the concepts hub is steadier first.",
    bodyZh: "因果、菩提心、六度、空性常会一起出现。先把它们放回同一张地图，再决定当前更该继续看哪一张概念页，路径会更清楚。",
    bodyEn: "Karma, bodhicitta, the six paramitas, and emptiness often travel together. Placing them back on one map before choosing the next concept page usually makes the path clearer.",
    summaryTitleZh: "这张卡在什么时候最有用",
    summaryTitleEn: "When this card is most useful",
    summaryBodyZh: "当你已经开始觉得“只是教我怎么念，还不够”，这张卡最有用。它会把练习、经典和概念重新收回同一条路径里。",
    summaryBodyEn: "It becomes most useful when you begin to feel that being told only how to recite is no longer enough. It gathers practice, scripture, and concepts back into one path.",
    href: "/buddhist-concepts",
    ctaZh: "继续看佛学基本概念",
    ctaEn: "Open the concepts hub",
  },
];

const practiceFoundations = [
  {
    titleZh: "先让念佛轻一点，才能让它留下来",
    titleEn: "Make recitation light enough to stay",
    descriptionZh: "对初学者来说，最稳的起点通常不是一开始就追求很多遍数，而是每天先留一个真实的小时段，让心里愿意再回来一次。",
    descriptionEn: "For beginners, the steadiest beginning is usually not a large count at once, but one real daily window that leaves the heart willing to return once more tomorrow.",
  },
  {
    titleZh: "先定一句佛号，再决定要不要慢慢加别的方法",
    titleEn: "Choose one recited phrase before adding more methods",
    descriptionZh: "可以先以一句佛号做主线，再让听诵、阅读、记录或短时静坐做辅助。先有主线，再谈扩展，通常更容易相续。",
    descriptionEn: "Let one recited phrase become the main line first, then allow listening, reading, notes, or short sitting to support it. Once the main line exists, expansion becomes much steadier.",
  },
  {
    titleZh: "念佛真正有力的时候，不是数量大，而是愿意回来",
    titleEn: "Recitation gains force not through size alone, but through willingness to return",
    descriptionZh: "真正重要的，不只是今天念了多少，而是散掉以后还能不能回来、明天还愿不愿意继续。能相续，力量才慢慢长出来。",
    descriptionEn: "What matters most is not only how much was recited today, but whether you can return after scattering and remain willing to continue tomorrow. Strength grows gradually through continuity.",
  },
] as const;

const firstWeekSteps = [
  {
    titleZh: "第一步：晨起先留两三分钟一句佛号",
    titleEn: "Step 1: Give the morning two or three minutes of one phrase",
    descriptionZh: "先不用排满。晨起只留一句佛号或一轮轻声念，就足够让一天开始时有一个回返点。入口够轻，比较容易相续。",
    descriptionEn: "There is no need to fill the schedule immediately. One phrase or one soft round of recitation in the morning is enough to give the day a return point. A light doorway is easier to keep alive.",
  },
  {
    titleZh: "第二步：白天只加一个最容易实现的默念时刻",
    titleEn: "Step 2: Add one easy moment of silent recitation during the day",
    descriptionZh: "通勤、步行、排队或工作转场时，只要有一个最容易做到的默念点，就足够让念佛开始进入生活，而不是只停在早晚两段。",
    descriptionEn: "A commute, walk, queue, or transition between tasks can each carry one silent recitation point. That is enough to let nianfo begin entering life rather than living only in morning and evening blocks.",
  },
  {
    titleZh: "第三步：晚间用一句记录或一小段导读轻轻收住",
    titleEn: "Step 3: Close the evening with one note or a short guide section",
    descriptionZh: "晚间不用再做很重。只要看见今天有没有回来过、哪一刻最容易散，再补一句记录或一小段导读，念佛的节奏就更容易真的留下来。",
    descriptionEn: "The evening does not need another heavy layer. Notice whether you returned today, where the rhythm scattered most easily, then add one note or a short guide section. That is often enough for the rhythm to remain real.",
  },
] as const;

const commonMistakes = [
  {
    titleZh: "一开始就把念佛排成很重的数量任务",
    titleEn: "Turning recitation into a heavy counting task from day one",
    descriptionZh: "如果入口太重，功课很容易两三天后就断掉。更稳的方向，是先让一句佛号和一个固定时段真的留得下来。",
    descriptionEn: "When the doorway is too heavy, the routine often breaks within a few days. A steadier direction is to let one phrase and one fixed window actually stay alive first.",
  },
  {
    titleZh: "只在早晚念，白天完全没有回返点",
    titleEn: "Reciting only morning and evening with no daytime return point",
    descriptionZh: "早晚当然重要，但如果白天完全没有任何回念的机会，念佛就比较难慢慢回到说话、做事和待人处事里。",
    descriptionEn: "Morning and evening matter, but without any daytime return point recitation has a harder time re-entering speech, work, and relationship.",
  },
  {
    titleZh: "中断几天以后，就把自己判成不适合念佛",
    titleEn: "Missing a few days and deciding you are not suited to nianfo",
    descriptionZh: "多数时候不是不适合，而是起点太重。中断以后把节奏缩小一点重新开始，通常比责备自己更有帮助。",
    descriptionEn: "Most often the issue is not unsuitability, but that the starting rhythm was too heavy. After interruption, restarting with a smaller rhythm is usually more helpful than self-blame.",
  },
] as const;

const relatedPaths = [
  {
    href: "/practice-guide",
    labelZh: "修行方法总览",
    labelEn: "Practice Guide",
    titleZh: "先回到更完整的修行方法地图。",
    titleEn: "Return to the broader map of beginner practice methods.",
    descriptionZh: "如果你还在看念佛、禅修、听诵、阅读和记录怎样彼此配合，可以先回到总览页。",
    descriptionEn: "Return to the overview first if you are still mapping how recitation, meditation, listening, reading, and notes support one another.",
  },
  {
    href: "/daily-practice",
    labelZh: "日常功课怎么安排",
    labelEn: "Daily Practice",
    titleZh: "把晨起、白天和晚间的轻量功课慢慢接起来。",
    titleEn: "Connect a lighter rhythm across morning, daytime, and evening.",
    descriptionZh: "如果你已经知道想念佛，但更想先把第一周功课排稳，这一页会更具体。",
    descriptionEn: "This page is more concrete if you already know recitation matters to you and now want the first week of routine to stabilize.",
  },
  {
    href: "/beginner-sutra-recommendations",
    labelZh: "初学者佛经推荐",
    labelEn: "Beginner Sutra Picks",
    titleZh: "先把入口经典选清楚，念佛的节奏也会一起变清楚。",
    titleEn: "Clarify the entry text first and the rhythm of recitation usually becomes clearer too.",
    descriptionZh: "如果你已经知道想从经典进入，却卡在《阿弥陀经》、观音圣号或其他入口更适合哪一种，这一页会更具体。",
    descriptionEn: "This page is more specific if you know scripture is your doorway but still need to distinguish whether the Amitabha Sutra, Guanyin recitation, or another text fits best.",
  },
  {
    href: "/sutra-listening",
    labelZh: "听诵和读经怎么配合",
    labelEn: "Listening and Reading",
    titleZh: "把听诵、阅读和一句佛号放回同一条线里。",
    titleEn: "Place listening, reading, and one recited phrase back onto the same line.",
    descriptionZh: "如果你已经开始听经，却还不知道怎样把熟悉感接回一句佛号和日常节奏，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you have begun listening to scripture but still need to reconnect that familiarity to one living phrase and a daily rhythm.",
  },
  {
    href: "/what-is-bodhicitta",
    labelZh: "菩提心是什么意思",
    labelEn: "What Bodhicitta Means",
    titleZh: "把“为什么念佛”放回更宽的发心里。",
    titleEn: "Return the reason for recitation to a wider aspiration.",
    descriptionZh: "如果你已经发现自己不只是在找方法，而是在问“为什么继续走这条路”，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you have begun asking not only how to practice, but why you want to keep walking the path.",
  },
  {
    href: "/buddhist-concepts",
    labelZh: "佛学基本概念",
    labelEn: "Buddhist Concepts",
    titleZh: "先回到一张更完整的概念地图，再决定该继续看哪一页。",
    titleEn: "Return to a wider concepts map before choosing which page needs attention next.",
    descriptionZh: "如果你已经发现自己并不只是缺念佛方法，而是总被因果、菩提心、六度、空性这些词挡住，这一页会更适合先打开。",
    descriptionEn: "Open this first if you have begun to see that the issue is not only method, but repeated friction around karma, bodhicitta, the six paramitas, and emptiness.",
  },
  {
    href: "/download",
    labelZh: "下载入口",
    labelEn: "Download",
    titleZh: "把提醒、听诵和简单记录放进生活里。",
    titleEn: "Bring reminders, listening, and simple notes into daily life.",
    descriptionZh: "准备借助 Fabushi 承接听诵、提醒和简短记录时，可以直接查看下载入口。",
    descriptionEn: "Go straight to downloads when you are ready to use Fabushi for listening, reminders, and simple notes.",
  },
] as const;

const faqItems = [
  {
    questionZh: "念佛入门是不是一定要先定很多遍数？",
    questionEn: "Does beginning nianfo require a large fixed count right away?",
    answerZh: "不一定。对初学者来说，更稳的起点通常不是先定很大的数量，而是先让一句佛号在一天里真的留得下来。晨起两三分钟、白天一个短默念点、晚间一小段回顾，往往比一开始排很多更容易相续。",
    answerEn: "Not necessarily. For beginners, the steadier beginning is usually not a large count, but letting one phrase truly stay alive during the day. Two or three minutes in the morning, one short daytime return, and a light evening review often continue more reliably than a heavy routine from day one.",
  },
  {
    questionZh: "念佛和日常功课是什么关系？",
    questionEn: "How does recitation fit with a daily practice routine?",
    answerZh: "念佛很适合作为日常功课里最轻、最容易留下来的主线之一。它可以放在晨起、白天和晚间的小时段里，再由听诵、阅读或一条简短记录做辅助。先让一句佛号活下来，整条功课路径通常也会跟着稳起来。",
    answerEn: "Recitation is well suited to become one of the lightest and most sustainable main lines inside a daily routine. It can sit in small morning, daytime, and evening windows while listening, reading, or one short note acts as support. When one phrase stays alive, the wider routine often steadies with it.",
  },
  {
    questionZh: "如果我想从《阿弥陀经》或观音圣号进入，第一周该怎么接？",
    questionEn: "If I want to begin through the Amitabha Sutra or Guanyin recitation, how should the first week connect?",
    answerZh: "更稳的方式通常不是一下安排很多，而是先让同一条入口连续出现几天。晨起先听一小段或轻声念一句，白天回到同一段内容或一句佛号，晚间再读一小段导读或留一句记录。先让入口稳定，再决定要不要慢慢加深。",
    answerEn: "A steadier way is usually not to schedule many things at once, but to let the same doorway return for a few days in a row. Listen briefly or recite softly in the morning, return to the same line or phrase during the day, then read a short guide section or leave one note at night. Stabilize the doorway before deepening it.",
  },
  {
    questionZh: "如果中断了几天，是不是就不适合念佛？",
    questionEn: "If I miss a few days, does that mean recitation is not right for me?",
    answerZh: "通常不是。多数时候更像是入口太重、节奏太满，才会很快断掉。中断以后，把功课缩小一点重新开始，往往比责备自己更有帮助。真正重要的不是从不间断，而是断掉以后愿不愿意再回来。",
    answerEn: "Usually not. Most often the doorway was simply too heavy or the rhythm too full. After interruption, restarting with a smaller version is often more helpful than self-blame. What matters most is not never breaking the rhythm, but being willing to return after it breaks.",
  },
  {
    questionZh: "念佛为什么不只是重复一句话？",
    questionEn: "Why is recitation more than repeating a phrase?",
    answerZh: "如果念佛只剩数量，很容易变成任务。更稳的方向，是让一句佛号慢慢回到愿心、耐心、说话做事和待人处事里。这样它就不只是口头上的重复，而会慢慢变成帮助自己清醒、柔软和持续回来的练习。",
    answerEn: "When recitation becomes only a count, it easily turns into a task. A steadier direction is to let one phrase return gradually to aspiration, patience, speech, conduct, and relationship. Then it becomes more than repetition and starts turning into a practice that supports clarity, softness, and return.",
  },
] as const;

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "念佛入门",
    "念佛怎么开始",
    "初学者念佛",
    "念佛方法",
    "阿弥陀经",
    "观音圣号",
    "日常功课",
    "听诵和读经怎么配合",
    "菩提心是什么意思",
    "因果是什么意思",
    "六度分别是什么",
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

function NianfoCard({ item }: { item: NianfoCardItem }) {
  return (
    <article className={`nianfo-card nianfo-tone-${item.tone}`}>
      <div className="nianfo-card-visual" aria-hidden="true">
        <span className="nianfo-card-symbol">
          <LocalizedText zh={item.visualZh} en={item.visualEn} />
        </span>
        <small>
          <LocalizedText zh={item.labelZh} en={item.labelEn} />
        </small>
      </div>
      <div className="nianfo-card-copy">
        <p className="nianfo-card-kicker">
          <LocalizedText zh={item.eyebrowZh} en={item.eyebrowEn} />
        </p>
        <h3>
          <LocalizedText zh={item.titleZh} en={item.titleEn} />
        </h3>
        <p>
          <LocalizedText zh={item.bodyZh} en={item.bodyEn} />
        </p>
      </div>
      <div className="nianfo-card-summary">
        <p className="nianfo-card-stage">
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
        <a className="nianfo-card-link" href={siteHref(item.href)}>
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

export default function NianfoGuidePage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: "念佛入门怎么开始",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
        about: [
          "念佛入门",
          "念佛怎么开始",
          "初学者念佛",
          "阿弥陀经",
          "观音圣号",
          "日常功课",
          "菩提心",
          "因果",
          "六度",
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
            name: "念佛入门怎么开始",
            item: pageUrl,
          },
        ],
      },
      {
        "@type": "ItemList",
        name: "念佛入门卡牌：起步节奏",
        itemListElement: starterCards.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.labelZh,
          url: siteUrl(item.href ?? "/nianfo-guide"),
          description: item.summaryBodyZh,
        })),
      },
      {
        "@type": "ItemList",
        name: "念佛入门卡牌：经典接回念佛",
        itemListElement: bridgeCards.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.labelZh,
          url: siteUrl(item.href ?? "/nianfo-guide"),
          description: item.summaryBodyZh,
        })),
      },
      {
        "@type": "ItemList",
        name: "念佛入门卡牌：概念回路",
        itemListElement: conceptCards.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.labelZh,
          url: siteUrl(item.href ?? "/nianfo-guide"),
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
            <LocalizedText zh="念佛入门怎么开始" en="Beginning Nianfo" />
          </p>
          <h1>
            <LocalizedText
              zh="先让一句佛号轻轻留在晨起、白天和晚间，念佛才更容易真的进入生活。"
              en="Let one phrase of recitation settle lightly across morning, daytime, and evening so it can truly enter daily life."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="念佛入门不必一开始就排很多。先让一句佛号、一个短时段和一个白天回返点真的留下来，再慢慢把经典入口、日常功课和更深的发心接上去。"
              en="Beginning nianfo does not require a heavy routine from day one. Let one phrase, one short time window, and one daytime return point stay alive first, then connect scripture, daily rhythm, and deeper aspiration gradually."
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
              zh="这页从第一版就用静态卡牌摘要入口，不靠翻转，先帮你判断当前最适合从哪一步开始。"
              en="This page uses static card summaries from the first version onward, without flip interaction, so you can see clearly which next step fits best now."
            />
          </h2>
          <p className="nianfo-card-note">
            <LocalizedText
              zh="卡牌保留入口感和可扫描性，但关键信息都直接展开，避免把正文和下一步藏进交互里。"
              en="The cards keep scan-friendly entry points, but all key information stays directly visible instead of hiding core guidance behind interaction."
            />
          </p>
        </div>
        <div className="nianfo-card-grid">
          {starterCards.map((item) => (
            <NianfoCard key={item.labelEn} item={item} />
          ))}
        </div>
      </section>

      <section className="band alt feature-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="经典接回念佛" en="Scripture Bridges" />
          </p>
          <h2>
            <LocalizedText
              zh="把“从哪部经典进、听诵怎样接回一句佛号”这些真实问题，直接收进念佛入口里。"
              en="Bring the real questions of which text to enter through and how listening returns to one living phrase directly into the recitation doorway itself."
            />
          </h2>
        </div>
        <div className="nianfo-card-grid">
          {bridgeCards.map((item) => (
            <NianfoCard key={item.labelEn} item={item} />
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="概念回路" en="Concept Bridges" />
          </p>
          <h2>
            <LocalizedText
              zh="练着练着又回到因果、菩提心和六度，往往不是岔开，而是念佛开始变深。"
              en="When recitation keeps returning to karma, bodhicitta, and the six paramitas, the path is often deepening rather than drifting."
            />
          </h2>
        </div>
        <div className="nianfo-card-grid">
          {conceptCards.map((item) => (
            <NianfoCard key={item.labelEn} item={item} />
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
              zh="很多人不是不愿意念佛，而是一开始就把念佛想得太重。"
              en="Many people are not unwilling to begin recitation. They simply imagine it as too heavy at the start."
            />
          </h2>
        </div>
        <div className="article-body">
          <p>
            <LocalizedText
              zh="一说到念佛，很多人脑中立刻会出现数量、遍数和很完整的功课表，好像不做到很多，就算不上真正开始。可多数初学者真正遇到的困难，并不是不知道念什么，而是入口太重，几天以后反而不愿意再回来。"
              en="When people hear recitation practice, many immediately imagine counts, rounds, and a full formal schedule, as if anything less could not count as a real beginning. Yet for most beginners, the difficulty is not not knowing what to recite, but the heaviness of the entry, which makes returning after a few days much harder."
            />
          </p>
          <p>
            <LocalizedText
              zh="比较稳的起点，通常不是第一天就排很满，而是先让一句佛号和一个固定时段留下来。晨起、白天和晚间只要各有一点点真实回返点，念佛就比较容易从“记得做一项功课”慢慢变成“心里愿意回来的一条路”。"
              en="A steadier beginning is usually not a full first day, but allowing one phrase and one stable time window to stay alive. When morning, daytime, and evening each carry even a small real return point, recitation can slowly shift from a task to remember into a path the heart is willing to return to."
            />
          </p>
          <p>
            <LocalizedText
              zh="很多人真正卡住的，还不是“要不要念”，而是“如果我想从《阿弥陀经》、观音圣号或听诵开始，第一周该怎样接才不会太重”。这并不是岔题，而是念佛真正开始落地时最自然会出现的问题。把经典入口、听诵和一句佛号接回同一条线，入口才比较容易稳下来。"
              en="What often becomes the real obstacle is not whether to recite, but how the first week should connect if the doorway begins through the Amitabha Sutra, Guanyin recitation, or listening. This is not a detour. It is the natural question that appears once recitation starts trying to land in real life. Reconnecting scripture, listening, and one phrase into the same line makes the doorway much steadier."
            />
          </p>
          <p>
            <LocalizedText
              zh="念佛真正有力的时候，也不只是数量上去了。随着晨起、白天和晚间慢慢有了回返点，人会开始看见：很多急躁、判断和执着，并没有想象中那样固定。功课越回到这里，念佛就越不只是重复，而是在帮助自己多一点清醒、柔软和愿意继续走下去的方向。"
              en="Recitation becomes powerful not only when the count rises. As morning, daytime, and evening slowly gain return points, people begin seeing that impatience, judgment, and grasping are less fixed than they appeared. The more practice returns here, the less recitation becomes mere repetition and the more it supports clarity, softness, and a willingness to continue the path."
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
              zh="先把念佛入门最稳的三个基本判断放好。"
              en="Set the three steadier judgments for beginning nianfo first."
            />
          </h2>
        </div>
        <div className="definition-grid">
          {practiceFoundations.map((item) => (
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
            <LocalizedText zh="第一周安排" en="First Week" />
          </p>
          <h2>
            <LocalizedText
              zh="先用三步把念佛排轻一点，再决定要不要慢慢加深。"
              en="Use three steps to keep the first week of recitation light, then decide whether it should deepen."
            />
          </h2>
        </div>
        <div className="compare-grid">
          {firstWeekSteps.map((item) => (
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
              zh="先避开几个最容易让念佛变重、变断的误区。"
              en="Avoid the patterns that most easily make recitation too heavy or too fragile."
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
              en="Follow the doorway that fits your present need into the more specific next page."
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
              zh="先回答初学者最容易在念佛上卡住的几个问题。"
              en="Answer the questions beginners most often get stuck on when beginning recitation."
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
          <a className="secondary-action" href={siteHref("/daily-practice")}>
            <LocalizedText zh="继续看日常功课怎么安排" en="Continue to the daily practice guide" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
