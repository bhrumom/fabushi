export interface ForumSection {
  slug: string;
  titleZh: string;
  titleEn: string;
  summaryZh: string;
  summaryEn: string;
  guidanceZh: string;
  guidanceEn: string;
}

export interface StarterThread {
  slug: string;
  titleZh: string;
  titleEn: string;
  sectionZh: string;
  sectionEn: string;
  descriptionZh: string;
  descriptionEn: string;
}

export interface GovernanceSignal {
  titleZh: string;
  titleEn: string;
  descriptionZh: string;
  descriptionEn: string;
}

export interface LaunchStep {
  titleZh: string;
  titleEn: string;
  descriptionZh: string;
  descriptionEn: string;
}

export interface ForumThread {
  slug: string;
  sectionSlug: string;
  titleZh: string;
  titleEn: string;
  summaryZh: string;
  summaryEn: string;
  authorZh: string;
  authorEn: string;
  roleZh: string;
  roleEn: string;
  publishedLabelZh: string;
  publishedLabelEn: string;
  lastActivityZh: string;
  lastActivityEn: string;
  repliesCount: number;
  followsCount: number;
  bookmarksCount: number;
  tagsZh: string[];
  tagsEn: string[];
  featuredReasonZh: string;
  featuredReasonEn: string;
  openingPostZh: string[];
  openingPostEn: string[];
  takeawaysZh: string[];
  takeawaysEn: string[];
  replyPromptsZh: string[];
  replyPromptsEn: string[];
}

export const FORUM_SECTIONS: ForumSection[] = [
  {
    slug: "newcomer-path",
    titleZh: "新手起步",
    titleEn: "Newcomer Path",
    summaryZh: "给第一次接触佛法的人一个能放心提问、能被温和接住的入口。",
    summaryEn: "A gentle place for first questions, where newcomers can ask openly and be guided with care.",
    guidanceZh: "适合提出“先读什么、先练什么、先建立什么日常节奏”这一类起步问题。",
    guidanceEn: "Best for questions about where to begin, what to read first, and how to build a first daily rhythm.",
  },
  {
    slug: "sutra-study",
    titleZh: "经论研读",
    titleEn: "Sutra Study",
    summaryZh: "围绕经典、次第、名相与出处做可追溯的讨论，不鼓励断章取义。",
    summaryEn: "A traceable discussion area for sutras, commentaries, terminology, and references.",
    guidanceZh: "鼓励贴出经论出处、上下文和不同理解路径，帮助长期沉淀。",
    guidanceEn: "Members are encouraged to include sources, context, and interpretive paths so knowledge can accumulate.",
  },
  {
    slug: "meditation-practice",
    titleZh: "禅修问答",
    titleEn: "Meditation Practice",
    summaryZh: "聚焦坐禅、散乱、昏沉、节奏、陪练与复盘，把经验说清楚。",
    summaryEn: "Focused on sitting practice, distraction, dullness, rhythm, group sessions, and thoughtful review.",
    guidanceZh: "适合讨论练习感受，但避免把个人状态直接包装成权威结论。",
    guidanceEn: "Personal experience is welcome, but it should not be presented as final authority.",
  },
  {
    slug: "practice-journal",
    titleZh: "修学日志",
    titleEn: "Practice Journal",
    summaryZh: "允许长期记录自己的愿心、障碍、调整与回看，形成真实修学轨迹。",
    summaryEn: "A space for long-term logs of vows, obstacles, adjustments, and reflection.",
    guidanceZh: "强调持续与诚实记录，而不是表演式打卡。",
    guidanceEn: "The emphasis is on steady, honest reflection rather than performative check-ins.",
  },
  {
    slug: "group-practice",
    titleZh: "共修与地区",
    titleEn: "Group Practice",
    summaryZh: "连接线上共修、线下地区交流与时区组织，让关系真正沉下来。",
    summaryEn: "Connect online groups, regional circles, and timezone-based practice rhythms.",
    guidanceZh: "后续会逐步扩展成按地区、语言和主题组织的社区网络。",
    guidanceEn: "This section can later expand into a community network organized by region, language, and theme.",
  },
  {
    slug: "knowledge-archive",
    titleZh: "资料整理",
    titleEn: "Knowledge Archive",
    summaryZh: "把高质量回答、精华串和专题索引整理成可反复引用的知识页。",
    summaryEn: "Turn high-quality answers, curated threads, and topic indexes into reusable knowledge pages.",
    guidanceZh: "这是论坛避免只剩时间线噪音的关键区域。",
    guidanceEn: "This is how the forum avoids becoming a stream of noise.",
  },
];

export const FORUM_THREADS: ForumThread[] = [
  {
    slug: "first-year-stability",
    sectionSlug: "newcomer-path",
    titleZh: "学佛第一年，先稳定什么最重要？",
    titleEn: "In the first year, what is most important to stabilize?",
    summaryZh: "与其一开始同时抓很多法门，不如先把愿心、作息、听闻和最基础的练习节奏稳下来。",
    summaryEn: "Instead of trying too many practices at once, stabilize aspiration, daily rhythm, listening, and one basic practice first.",
    authorZh: "净行",
    authorEn: "Jing Xing",
    roleZh: "论坛发起帖",
    roleEn: "Forum seed thread",
    publishedLabelZh: "首批引导话题",
    publishedLabelEn: "Seed discussion",
    lastActivityZh: "最近整理：起步节奏清单",
    lastActivityEn: "Latest update: starter rhythm checklist",
    repliesCount: 18,
    followsCount: 42,
    bookmarksCount: 27,
    tagsZh: ["新手", "作息", "起步"],
    tagsEn: ["newcomer", "daily rhythm", "beginning"],
    featuredReasonZh: "适合作为新手欢迎区的第一条常驻讨论。",
    featuredReasonEn: "A strong anchor thread for the newcomer welcome area.",
    openingPostZh: [
      "很多人学佛的第一年，最大的困难不是信息不够，而是同时抓太多，结果什么都不稳。今天想邀请大家一起讨论：如果只能先稳定三件事，你会选什么？为什么？",
      "我自己的判断是，第一优先通常不是“立刻进入很多高强度练习”，而是先把愿心、作息、听闻和一个最基础的日常练习放稳。这样后面读经、持诵、禅修或参加共修时，才有真正能持续的土壤。",
      "欢迎大家结合自己的路径来分享，但尽量说清楚适用对象：是面向完全零基础的新手，还是已经开始固定听经、诵经或禅修的人。",
    ],
    openingPostEn: [
      "In the first year of practice, the biggest problem is often not a lack of information but trying too many things at once. If you could stabilize only three things first, what would they be, and why?",
      "My own view is that the first priority is usually not intense practice volume, but a steady aspiration, daily rhythm, listening habit, and one basic repeatable practice. That creates soil for later sutra study, chanting, meditation, or group practice.",
      "Please share from your own path, but note who your advice is for: someone completely new, or someone who has already begun a stable routine of listening, recitation, or meditation.",
    ],
    takeawaysZh: [
      "先稳节奏，再谈扩展，不要让起步阶段变成堆任务。",
      "建议回复时写明自己的起点，避免把个人路径说成唯一标准。",
      "后续可以把高质量回复整理成“新手第一年节奏建议”。",
    ],
    takeawaysEn: [
      "Stabilize rhythm before expansion so the first stage does not become a pile of tasks.",
      "Replies should state the speaker's starting point instead of presenting one path as universal.",
      "Strong responses can later become a newcomer first-year rhythm guide.",
    ],
    replyPromptsZh: [
      "如果是完全零基础的人，你会建议先固定什么？",
      "你走过弯路后，最希望早点稳定下来的是什么？",
      "哪些建议看似积极，但其实容易让新手失去节奏？",
    ],
    replyPromptsEn: [
      "For a complete beginner, what would you ask them to stabilize first?",
      "Looking back, what do you wish you had made steady earlier?",
      "Which well-meant suggestions actually make beginners lose their rhythm?",
    ],
  },
  {
    slug: "how-to-ask-while-reading-sutras",
    sectionSlug: "sutra-study",
    titleZh: "读经时遇到看不懂的名相，应该怎样提问？",
    titleEn: "How should we ask about terms we do not understand in sutra reading?",
    summaryZh: "好问题不是只贴一个词，而是把出处、上下文和自己的理解一起带出来，这样讨论才更能沉淀。",
    summaryEn: "A good question brings the term, the source passage, surrounding context, and the reader's current understanding together.",
    authorZh: "闻思",
    authorEn: "Wen Si",
    roleZh: "经论研读发起帖",
    roleEn: "Sutra study seed thread",
    publishedLabelZh: "首批引导话题",
    publishedLabelEn: "Seed discussion",
    lastActivityZh: "最近整理：提问模板已加入",
    lastActivityEn: "Latest update: question template added",
    repliesCount: 11,
    followsCount: 31,
    bookmarksCount: 36,
    tagsZh: ["名相", "出处", "提问方式"],
    tagsEn: ["terminology", "sources", "asking well"],
    featuredReasonZh: "这类提问方式会直接影响论坛的长期知识质量。",
    featuredReasonEn: "The way people ask here will shape the forum's long-term knowledge quality.",
    openingPostZh: [
      "经论研读区很容易出现一种情况：有人只贴一个名相，然后问“这是什么意思？”这样的提问当然真实，但如果没有出处和上下文，回答也很容易发散，甚至互相误解。",
      "我想先做一个更适合论坛长期沉淀的提问范式：至少附上经论出处、前后文、自己目前的理解，以及你卡住的具体点。这样别人不只是来“给答案”，而是能一起帮助厘清语境。",
      "欢迎大家补充：对于新手来说，怎样的提问模板既不会太重，又能明显提高讨论质量？",
    ],
    openingPostEn: [
      "In sutra study, a common pattern is that someone posts a single term and asks, 'What does this mean?' The question is sincere, but without source and context, the replies often scatter or misunderstand each other.",
      "I want to propose a forum-friendly question format: include the source text, nearby context, your current understanding, and the exact point where you got stuck. Then people can clarify the frame instead of only dropping answers.",
      "Please add to this: what kind of question template stays light enough for beginners while still raising the quality of discussion?",
    ],
    takeawaysZh: [
      "提问要尽量把出处、上下文和卡点一起带出来。",
      "论坛后续可以把常见提问模板做成固定置顶说明。",
      "好的提问本身就是知识沉淀的起点。",
    ],
    takeawaysEn: [
      "Questions should carry source, context, and the exact point of confusion.",
      "The forum can later turn common question formats into pinned guidance.",
      "A well-formed question is already the start of knowledge archiving.",
    ],
    replyPromptsZh: [
      "你见过最有帮助的一种读经提问方式是什么？",
      "哪些补充信息最值得作为固定字段？",
      "怎样避免把提问门槛抬得太高，让新手不敢开口？",
    ],
    replyPromptsEn: [
      "What is the most helpful sutra-reading question format you have seen?",
      "Which extra details deserve to become standard fields?",
      "How do we keep the bar helpful without making beginners afraid to ask?",
    ],
  },
  {
    slug: "working-with-distraction-and-dullness",
    sectionSlug: "meditation-practice",
    titleZh: "禅修里最常见的散乱和昏沉，大家怎么处理？",
    titleEn: "How do people work with distraction and dullness in meditation?",
    summaryZh: "把散乱和昏沉说得具体一些：发生在什么时候、前后做了什么、如何复盘，比空泛谈体验更有帮助。",
    summaryEn: "It helps more to describe when distraction or dullness appears, what came before it, and how you reviewed it than to speak vaguely about states.",
    authorZh: "清照",
    authorEn: "Qing Zhao",
    roleZh: "禅修问答发起帖",
    roleEn: "Meditation seed thread",
    publishedLabelZh: "首批引导话题",
    publishedLabelEn: "Seed discussion",
    lastActivityZh: "最近整理：复盘提示已补充",
    lastActivityEn: "Latest update: review prompts added",
    repliesCount: 23,
    followsCount: 38,
    bookmarksCount: 33,
    tagsZh: ["禅修", "散乱", "昏沉"],
    tagsEn: ["meditation", "distraction", "dullness"],
    featuredReasonZh: "这是最容易活跃、也最需要降噪的一类主题。",
    featuredReasonEn: "This topic will likely become active quickly and needs grounded framing from the start.",
    openingPostZh: [
      "散乱和昏沉几乎是每个练习者都会遇到的，但论坛里如果只说“我今天状态不好”，其实很难互相帮助。真正有用的分享，往往会把练习前的状态、练习中的变化和结束后的复盘说清楚。",
      "我建议这个串先聚焦在实践层面：你通常在什么情况下更容易散乱？昏沉来时，你会怎么调整坐姿、呼吸、时长或作息？哪些调整对你有效，哪些只是暂时掩盖问题？",
      "也想提醒一点：欢迎谈经验，但尽量不要把短期体感包装成深层境界判断。这样论坛会更稳，也更适合真正互相帮助。",
    ],
    openingPostEn: [
      "Almost every practitioner meets distraction and dullness, but a post that only says 'I had a bad session' gives others little to work with. The most helpful sharing usually explains the preconditions, what changed during the sit, and how the session was reviewed afterward.",
      "I suggest keeping this thread practical first: when are you more likely to become distracted, what adjustments do you make in posture, breathing, duration, or routine, and which changes actually help?",
      "One more note: personal experience is welcome, but please avoid framing short-term sensations as deep attainment claims. That keeps the forum steadier and more useful.",
    ],
    takeawaysZh: [
      "把问题落到练习前、中、后的复盘细节里。",
      "讨论应优先帮助调整节奏，而不是放大体验感。",
      "后续可以把高质量回复沉淀成“散乱 / 昏沉处理索引”。",
    ],
    takeawaysEn: [
      "Ground the conversation in before, during, and after-practice review details.",
      "The goal is to help adjustment and rhythm, not dramatize experience.",
      "Strong replies can later become an index for working with distraction and dullness.",
    ],
    replyPromptsZh: [
      "你最常见的散乱触发点是什么？",
      "哪些调整帮助你从昏沉里出来，而不是只是硬撑？",
      "怎样描述自己的体验，才能更容易得到有效帮助？",
    ],
    replyPromptsEn: [
      "What most often triggers distraction for you?",
      "Which adjustments help you emerge from dullness instead of just enduring it?",
      "How can someone describe a session so others can actually help?",
    ],
  },
  {
    slug: "honest-practice-journal",
    sectionSlug: "practice-journal",
    titleZh: "怎样写修学日志，既真实又不流于自我表演？",
    titleEn: "How can a practice journal stay honest without turning into performance?",
    summaryZh: "修学日志不只是记录“我做了什么”，更重要的是记下愿心、节奏、障碍和调整，这样回看才真的有用。",
    summaryEn: "A practice journal becomes useful when it records aspiration, rhythm, obstacles, and adjustments, not just a list of completed actions.",
    authorZh: "持灯",
    authorEn: "Chi Deng",
    roleZh: "修学日志发起帖",
    roleEn: "Practice journal seed thread",
    publishedLabelZh: "首批引导话题",
    publishedLabelEn: "Seed discussion",
    lastActivityZh: "最近整理：日志模板草案",
    lastActivityEn: "Latest update: journal template draft",
    repliesCount: 9,
    followsCount: 26,
    bookmarksCount: 41,
    tagsZh: ["日志", "复盘", "长期记录"],
    tagsEn: ["journal", "review", "long-term record"],
    featuredReasonZh: "这会影响论坛能否形成长期可回看的修学轨迹。",
    featuredReasonEn: "This determines whether the forum can support long-term, reviewable practice paths.",
    openingPostZh: [
      "修学日志区如果只剩“今天打卡了什么”，很快就会变成一种表演压力。可如果什么都不记，很多真正重要的变化又会在几周后完全想不起来。",
      "我想邀请大家一起讨论：一条健康的修学日志，最少应该包含哪些部分？比如今天的发心、做了什么、遇到什么障碍、怎么调整，以及接下来准备观察什么。",
      "如果你已经有稳定记录的经验，也欢迎分享你后来删掉了哪些“看起来很积极、实际没帮助”的记录习惯。",
    ],
    openingPostEn: [
      "If the practice journal area becomes only a list of check-ins, it quickly creates performance pressure. But if nothing is recorded, many meaningful changes disappear from memory within weeks.",
      "I want to ask: what is the minimum healthy structure of a practice journal? For example, today's aspiration, what was done, what obstacle appeared, how it was adjusted, and what to watch next.",
      "If you already keep a stable journal, please share which habits looked diligent but later turned out not to help.",
    ],
    takeawaysZh: [
      "日志要帮助回看和调整，而不是制造展示压力。",
      "推荐围绕发心、节奏、障碍、调整四项来写。",
      "后续可把优质模板沉淀成固定写作引导。",
    ],
    takeawaysEn: [
      "A journal should support review and adjustment rather than performance pressure.",
      "A useful base format centers on aspiration, rhythm, obstacles, and adjustment.",
      "Strong templates can later become stable writing guidance for the forum.",
    ],
    replyPromptsZh: [
      "你记录日志时，最想在几周后回看到什么？",
      "哪些内容值得保留，哪些内容容易变成自我展示？",
      "如果论坛给一个默认模板，你最希望它提醒你写哪一项？",
    ],
    replyPromptsEn: [
      "When you review a journal weeks later, what do you most want to see?",
      "Which kinds of notes are worth keeping, and which drift into self-display?",
      "If the forum offered a default template, what would you most want it to prompt?",
    ],
  },
];

export const STARTER_THREADS: StarterThread[] = FORUM_THREADS.map((thread) => {
  const section = FORUM_SECTIONS.find((item) => item.slug === thread.sectionSlug);

  return {
    slug: thread.slug,
    titleZh: thread.titleZh,
    titleEn: thread.titleEn,
    sectionZh: section?.titleZh ?? thread.sectionSlug,
    sectionEn: section?.titleEn ?? thread.sectionSlug,
    descriptionZh: thread.summaryZh,
    descriptionEn: thread.summaryEn,
  };
});

export const GOVERNANCE_SIGNALS: GovernanceSignal[] = [
  {
    titleZh: "优先引导，不先争胜",
    titleEn: "Guide before debating",
    descriptionZh: "对新手问题先帮助厘清背景与语境，不鼓励靠压制感建立权威。",
    descriptionEn: "Beginner questions should be met with context and guidance, not dominance.",
  },
  {
    titleZh: "引用请尽量给出处",
    titleEn: "Cite when possible",
    descriptionZh: "涉及经典、祖师语录或关键佛法判断时，尽量附上经论出处，减少误传。",
    descriptionEn: "When discussing key dharma claims or quotations, include sources whenever possible.",
  },
  {
    titleZh: "错误信息要温和纠偏",
    titleEn: "Correct gently",
    descriptionZh: "论坛会建立纠偏机制，但处理方式应以澄清和帮助理解为主，而不是羞辱。",
    descriptionEn: "The forum should correct harmful inaccuracies, but with clarity rather than humiliation.",
  },
  {
    titleZh: "精华要能沉淀成知识",
    titleEn: "Turn highlights into knowledge",
    descriptionZh: "高质量讨论不应只留在时间线里，后续会进入专题索引和资料整理区。",
    descriptionEn: "Strong discussions should not vanish in the feed; they should become part of the archive.",
  },
];

export const LAUNCH_STEPS: LaunchStep[] = [
  {
    titleZh: "阶段一：论坛公开入口",
    titleEn: "Phase 1: Public entry",
    descriptionZh: "先把板块结构、讨论主题、治理原则和产品方向公开出来，建立清晰预期。",
    descriptionEn: "Publish the forum structure, starter topics, governance principles, and product direction.",
  },
  {
    titleZh: "阶段二：基础互动",
    titleEn: "Phase 2: Core interaction",
    descriptionZh: "补上发帖、回复、引用、收藏和关注，让社区开始形成最小讨论闭环。",
    descriptionEn: "Add posting, replies, quotes, bookmarks, and follows to form the first discussion loop.",
  },
  {
    titleZh: "阶段三：审核与新手引导",
    titleEn: "Phase 3: Moderation and onboarding",
    descriptionZh: "引入版规、纠偏、欢迎流程和板块引导，保护讨论质量与秩序。",
    descriptionEn: "Introduce moderation, correction flows, welcoming steps, and clearer board guidance.",
  },
  {
    titleZh: "阶段四：知识沉淀",
    titleEn: "Phase 4: Knowledge archive",
    descriptionZh: "将优质问答、精选串和长期专题沉淀成知识页，真正形成论坛资产。",
    descriptionEn: "Convert great Q&A, curated threads, and long-term topics into durable knowledge pages.",
  },
];

export function getForumSectionBySlug(slug: string) {
  return FORUM_SECTIONS.find((item) => item.slug === slug) ?? null;
}

export function getForumThreadBySlug(slug: string) {
  return FORUM_THREADS.find((item) => item.slug === slug) ?? null;
}

export function getForumThreadsBySection(sectionSlug: string) {
  return FORUM_THREADS.filter((item) => item.sectionSlug === sectionSlug);
}
