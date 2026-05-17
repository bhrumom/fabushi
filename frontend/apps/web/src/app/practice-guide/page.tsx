import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/practice-guide");
const pageTitle = `修行方法总览 | ${brand.name}`;
const pageDescription =
  "面向初学者梳理学佛修行可以从哪些方法开始：禅修、经文听诵、阅读、念佛与日常记录如何配合，先读什么佛经更合适、听诵怎样接回阅读，以及怎样把《心经》《阿弥陀经》《普门品》《金刚经》的入口接进第一周练习节奏。";

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

const scripturePracticePaths = [
  {
    href: "/beginner-sutra-recommendations",
    labelZh: "先读什么佛经",
    labelEn: "Choose a First Sutra",
    titleZh: "如果你已经想从经典进入，先把《心经》《阿弥陀经》《普门品》《金刚经》哪一部更适合作为起点单独理清。",
    titleEn: "If scripture already feels like your doorway, first clarify which of the Heart Sutra, Amitabha Sutra, Universal Gate Chapter, or Diamond Sutra fits best as the starting point.",
    descriptionZh: "很多人练习迟迟开始不了，不是因为不知道方法，而是先卡在“到底该从哪部经进”。先把起点选清楚，练习节奏会更容易真正落下来。",
    descriptionEn: "Many people cannot settle into practice not because they lack methods, but because they are still stuck on which scripture should come first. Once the entry point is clearer, the rhythm of practice usually becomes easier to keep alive.",
  },
  {
    href: "/sutra-listening",
    labelZh: "听诵和读经怎么配合",
    labelEn: "Listening and Reading",
    titleZh: "如果你已经开始听经，下一步把通勤里的听诵、安静时的阅读和一句记录接成同一条线。",
    titleEn: "If you have already begun listening to sutras, the next step is to connect commute listening, quieter reading, and one short note into the same line of practice.",
    descriptionZh: "对很多初学者来说，真正的卡点不是“要不要听”，而是听了以后怎样回到文字、怎样不让经典只停在背景声音里。",
    descriptionEn: "For many beginners, the real friction is not whether to listen, but how listening returns to the text and keeps scripture from remaining only background sound.",
  },
  {
    href: "/daily-practice",
    labelZh: "经典怎样接回日常功课",
    labelEn: "Return Sutras to Daily Practice",
    titleZh: "如果你已经知道要练什么，下一步先把《阿弥陀经》、听诵、念佛或短段阅读放进晨起、白天和晚间。",
    titleEn: "If you already know what to practice, the next step is to place the Amitabha Sutra, listening, recitation, or short reading into morning, daytime, and evening rhythm.",
    descriptionZh: "很多人不是不知道要做什么，而是不知道怎样让经典入口真的留在生活里。先把最轻的一日节奏排出来，会比继续停在方法清单里更稳。",
    descriptionEn: "Many people do not lack methods. They lack a way to let a scripture doorway remain alive inside ordinary life. Building the lightest daily rhythm first is steadier than remaining inside a methods list alone.",
  },
] as const;

const conceptBridgeSteps = [
  {
    titleZh: "因果：为什么修行方法一断再断，常常会回到习惯和结果这层问题",
    titleEn: "Karma: why broken rhythm often returns to habit and result",
    descriptionZh: "很多人练着练着会发现，真正卡住的不是不知道做什么，而是同样的急躁、拖延和起伏总在重复。这时回到因果，会更容易看见方法为什么需要相续，而不是只靠一时热情。",
    descriptionEn: "Many people discover that the real obstacle is not knowing what to do, but watching the same impatience, delay, and fluctuation repeat. Returning to karma helps explain why methods need continuity instead of depending on temporary enthusiasm.",
  },
  {
    titleZh: "菩提心与六度：为什么方法不只是技巧，而会慢慢长成待人处事的方向",
    titleEn: "Bodhicitta and the six paramitas: why methods become more than technique",
    descriptionZh: "如果修行方法只是让自己舒服一点，它很容易变成任务清单。回到菩提心和六度，会更容易看见禅修、听诵、念佛和记录，怎样慢慢长成更宽的发心、忍耐与待人处事。",
    descriptionEn: "If methods are only about feeling better, they can quickly shrink into tasks. Returning to bodhicitta and the six paramitas helps show how meditation, listening, recitation, and notes can widen into aspiration, patience, and conduct.",
  },
  {
    titleZh: "空性与概念总览：为什么练习越往前走，越需要一张更完整的理解地图",
    titleEn: "Emptiness and the concepts hub: why practice needs a wider map as it matures",
    descriptionZh: "练习一段时间以后，很多人会开始卡在“我是不是又把功课抓得太死”或“这些概念彼此到底怎么连起来”。这时先回到佛学基本概念总览，再决定是继续看空性、因果还是六度，通常比在方法页里硬撑更稳。",
    descriptionEn: "After some time, many people start asking whether they are gripping the routine too tightly or how the concepts actually connect. Returning to the concepts hub first, then moving into emptiness, karma, or the six paramitas, is often steadier than forcing the answer to stay inside a methods page alone.",
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
    href: "/beginner-sutra-recommendations",
    labelZh: "初学者佛经推荐",
    labelEn: "Beginner Sutra Picks",
    titleZh: "先把“先读哪部经”这一步理清，练习方法才更容易落地。",
    titleEn: "Clarify which sutra to begin with before the practice rhythm asks too many questions at once.",
    descriptionZh: "如果你已经知道自己想从经典进入，但卡在《心经》《阿弥陀经》《普门品》还是《金刚经》更适合作为起点，这一页会更适合先打开。",
    descriptionEn: "Open this first if you already know scripture is the doorway but still need to choose between the Heart Sutra, Amitabha Sutra, Universal Gate Chapter, or Diamond Sutra.",
  },
  {
    href: "/sutra-listening",
    labelZh: "听诵和读经怎么配合",
    labelEn: "Listening and Reading",
    titleZh: "把通勤里的听诵、安静时的阅读和一条记录接回同一条练习线。",
    titleEn: "Reconnect listening on the move, reading in quiet moments, and one short note inside the same practice line.",
    descriptionZh: "如果你已经开始听经，却还不知道怎样把它接回阅读、念佛和记录，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you have already begun listening to sutras but still need to reconnect it with reading, recitation, and notes.",
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
    href: "/buddhist-concepts",
    labelZh: "佛学基本概念",
    labelEn: "Buddhist Concepts",
    titleZh: "先回到一张更完整的概念地图，再决定自己卡在哪个概念上。",
    titleEn: "Return to a wider concepts map before choosing which concept needs attention now.",
    descriptionZh: "如果你已经发现自己不是缺方法，而是总被因果、菩提心、六度、空性这些词反复卡住，这一页会更适合先打开。",
    descriptionEn: "Open this first if you have started to see that the problem is not a lack of methods, but repeated friction around karma, bodhicitta, the six paramitas, or emptiness.",
  },
  {
    href: "/what-is-karma",
    labelZh: "因果是什么意思",
    labelEn: "What Karma Means",
    titleZh: "把习惯、选择和结果怎样慢慢形成先放清楚。",
    titleEn: "Clarify how habit, choice, and result gradually take shape together.",
    descriptionZh: "如果你已经发现自己最常卡在“为什么知道应该修，却总是留不住节奏”，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if your main friction has become why you know you should practice but still cannot keep the rhythm alive.",
  },
  {
    href: "/what-is-bodhicitta",
    labelZh: "菩提心是什么意思",
    labelEn: "What Bodhicitta Means",
    titleZh: "把“为什么修、愿意把这条路带向哪里”先放清楚。",
    titleEn: "Clarify why you practice and what direction you want the path to grow toward.",
    descriptionZh: "如果你想知道修行方法为什么不只是在练技巧，而要和发心一起长出来，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you want to see why practice methods are more than technique and need to grow together with aspiration.",
  },
  {
    href: "/what-are-the-six-paramitas",
    labelZh: "六度分别是什么",
    labelEn: "Six Paramitas",
    titleZh: "把修行方法为什么不只是在练技能说清楚。",
    titleEn: "See why practice methods are not only techniques but also a wider training of life.",
    descriptionZh: "如果你想知道布施、持戒、忍辱、精进、禅定和般若怎样回到练习方式和待人处事里，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you want to see how generosity, discipline, patience, diligence, meditation, and wisdom return to actual practice methods and ordinary conduct.",
  },
  {
    href: "/what-is-emptiness",
    labelZh: "空性怎么理解",
    labelEn: "How to Understand Emptiness",
    titleZh: "把“少一点抓得太死”慢慢接回练习方式。",
    titleEn: "Return the loosening of rigid grasping to actual practice methods.",
    descriptionZh: "如果你想知道空性为什么不是离生活很远的概念，而会影响禅修、念佛、听诵和待人处事，这一页会更适合继续往下看。",
    descriptionEn: "This is the better next page if you want to see why emptiness is not remote from life, but can reshape meditation, recitation, listening, and ordinary conduct.",
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
    questionZh: "如果我想从佛经开始，先读哪部经，再怎样接回练习？",
    questionEn: "If I want to begin from scripture, which sutra should come first and how should it return to practice?",
    answerZh: "很多初学者更稳的起点，不是一张固定书单，而是先看自己当下更需要方向、安定，还是慈悲与愿心。常见入口如《心经》《阿弥陀经》《普门品》《金刚经》，各自适合承接不同问题。选定一部以后，再把听诵、短段阅读和一句记录接回第一周节奏，会比只停在“看推荐”更容易真正开始。",
    answerEn: "For many beginners, the steadier start is not a rigid list but a better match between the present need and the first text. Common gateways such as the Heart Sutra, Amitabha Sutra, Universal Gate Chapter, and Diamond Sutra each fit different questions. Once one text is chosen, reconnect it to the first week through listening, short reading, and one small note.",
  },
  {
    questionZh: "听诵、读经和念佛怎么排进第一周，才不会一下太重？",
    questionEn: "How can listening, reading, and recitation fit into the first week without becoming too heavy?",
    answerZh: "更稳的安排通常是先定一个最轻的主线，例如晨起听一段经文，或每天念佛几分钟，再配一个辅助动作，例如晚间读一小段导读或留一句记录。先让一条线活下来，比一开始同时做很多更容易持续。",
    answerEn: "A steadier arrangement is usually one light main line, such as listening to one short passage in the morning or reciting for a few minutes each day, then one support action such as reading a short guide at night or leaving one note. Let one line stay alive before trying to do many things together.",
  },
  {
    questionZh: "因果是什么意思，和修行方法有什么关系？",
    questionEn: "What does karma have to do with actual practice methods?",
    answerZh: "如果不知道因果怎样和习惯、选择、结果连在一起，修行方法很容易只剩下一阵一阵的热情。回到因果，会更容易看见：今天怎么说话、怎么安排时间、断掉以后有没有回来，这些看起来很小的动作，正是在慢慢形成后面的结果。",
    answerEn: "When karma is separated from habit, choice, and result, practice methods can shrink into bursts of enthusiasm. Returning to karma helps show how speech, time, and whether you come back after a break are already shaping later results.",
  },
  {
    questionZh: "菩提心是什么意思，和修行方法有什么关系？",
    questionEn: "What does bodhicitta have to do with actual practice methods?",
    answerZh: "如果没有发心，修行方法很容易只剩技巧和任务。更稳的方向，是让禅修、听诵、阅读、念佛和记录，慢慢回到“我为什么学、愿意把这条路带向哪里”这件事上。这样方法才不只是让自己舒服一点，也会开始长出更宽的方向。",
    answerEn: "Without aspiration, practice methods can shrink into technique and task. A steadier direction is to let meditation, listening, reading, recitation, and notes return to the question of why you practice and what direction you want the path to grow toward. Then methods become more than self-soothing and begin to open into a wider intention.",
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
    questionZh: "空性怎么理解，和修行方法有什么关系？",
    questionEn: "How does understanding emptiness relate to actual practice methods?",
    answerZh: "如果把空性理解成离生活很远的高深义理，修行就容易只剩方法清单。更稳的方向，是先看见很多情绪、判断和习惯并没有想象中那样固定，这样禅修、听诵、念佛和记录就不只是为了完成任务，而是在帮助自己少一点抓得太死。",
    answerEn: "If emptiness is treated as distant doctrine, practice can shrink into a checklist of methods. A steadier direction is to notice that many emotions, judgments, and habits are less fixed than they seem, so meditation, listening, recitation, and notes become ways of loosening rigid grasping instead of merely finishing tasks.",
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
    "先读什么佛经",
    "初学者佛经推荐",
    "听诵和读经怎么配合",
    "佛学基本概念",
    "因果是什么意思",
    "菩提心是什么意思",
    "日常功课",
    "六度分别是什么",
    "空性怎么理解",
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
        about: [
          "修行方法",
          "学佛修行",
          "因果",
          "佛学基本概念",
          "菩提心",
          "日常功课",
          "空性理解",
          "先读什么佛经",
          "经文听诵",
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
        "@type": "ItemList",
        name: "经典入口如何接回练习",
        itemListElement: scripturePracticePaths.map((item, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: item.labelZh,
          url: siteUrl(item.href),
          description: item.descriptionZh,
        })),
      },
      {
        "@type": "ItemList",
        name: "修行方法和概念之间的桥接路径",
        itemListElement: conceptBridgeSteps.map((item, index) => ({
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
              zh="很多人到了这里以后，问题会从“我要不要练”慢慢变成“如果想从经典开始，先读哪部经更合适”“听诵以后怎样接回阅读”“《阿弥陀经》、念佛和日常功课又该怎么排进第一周”。这些问题看起来像是在换题，其实正说明方法页已经走到了真正会落地的地方。先把经典入口和练习节奏接上，方法才不只是一张总览。"
              en="At this point, many questions shift from whether to practice at all into which sutra should come first, how listening returns to reading, or how the Amitabha Sutra, recitation, and a first-week routine can fit together. These are not detours. They show that the methods page has arrived at the point where practice becomes real. Once scripture doorways reconnect with rhythm, a methods page becomes more than an overview."
            />
          </p>
          <p>
            <LocalizedText
              zh="修行方法最后不只是在练几种技能。随着节奏慢慢稳定，人也会开始看见：很多急躁、执着和判断，并没有想象中那样固定，这也是为什么菩提心、六度和空性会和方法页放在同一条路上。方法越回到这里，练习就越不只是完成任务，而是在帮助自己少一点抓得太死。"
              en="Practice methods are not only a set of techniques. As the rhythm steadies, people often begin to see that agitation, attachment, and judgment are less fixed than they seem. This is why bodhicitta, the six paramitas, and emptiness belong on the same path as method pages. The more practice returns here, the less it becomes task-completion and the more it helps loosen rigid grasping."
            />
          </p>
          <p>
            <LocalizedText
              zh="很多人练到这里以后，还会开始问：为什么我明明知道要修，节奏却总是断？为什么方法一多就又只剩任务感？为什么做着做着又会回到因果、菩提心、六度、空性这些概念？这通常不是跑题，而是说明方法页已经开始把人带到更深一点的理解层了。先回到佛学基本概念总览，再决定自己更该继续看哪一张概念页，往往会比只在方法页里硬撑更稳。"
              en="At this point many people begin to ask why the rhythm keeps breaking even when they know they should practice, why methods turn back into tasks when they multiply, or why the path keeps returning to karma, bodhicitta, the six paramitas, and emptiness. This is usually not a distraction. It often means the methods page has already carried the reader into a deeper layer of understanding. Returning to the concepts hub first, then choosing the concept page that matches the friction, is often steadier than forcing everything to remain inside a methods page alone."
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
            <LocalizedText zh="经典接回练习" en="Scripture Into Practice" />
          </p>
          <h2>
            <LocalizedText
              zh="把“先读哪部经、怎样听、怎样接回功课”这些真实问题，直接收进练习路径里。"
              en="Bring the real questions of which sutra to start with, how to listen, and how to return scripture to practice directly into the path."
            />
          </h2>
        </div>
        <div className="editorial-list">
          {scripturePracticePaths.map((item) => (
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

      <section className="band feature-band">
        <div className="section-heading tight">
          <p>
            <LocalizedText zh="回到概念" en="Return to Concepts" />
          </p>
          <h2>
            <LocalizedText
              zh="练着练着又回到因果、菩提心、六度和空性，往往不是岔开，而是路径开始变深。"
              en="When practice keeps returning to karma, bodhicitta, the six paramitas, and emptiness, the path is often deepening rather than drifting."
            />
          </h2>
        </div>
        <div className="feature-grid">
          {conceptBridgeSteps.map((item) => (
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
          <a className="secondary-action" href={siteHref("/beginner-sutra-recommendations")}>
            <LocalizedText zh="继续看初学者佛经推荐" en="Continue to Beginner Sutra Picks" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
