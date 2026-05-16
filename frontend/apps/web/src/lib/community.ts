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

export const STARTER_THREADS: StarterThread[] = [
  {
    titleZh: "学佛第一年，先稳定什么最重要？",
    titleEn: "In the first year, what is most important to stabilize?",
    sectionZh: "新手起步",
    sectionEn: "Newcomer Path",
    descriptionZh: "把“先听闻、先持诵、先禅修、先建立作息”几条常见起步路径摆在一起讨论。",
    descriptionEn: "A starter thread comparing common first-year paths: listening, chanting, meditation, and daily rhythm.",
  },
  {
    titleZh: "读经时遇到看不懂的名相，应该怎样提问？",
    titleEn: "How should we ask about terms we do not understand in sutra reading?",
    sectionZh: "经论研读",
    sectionEn: "Sutra Study",
    descriptionZh: "鼓励附上经文出处、前后文和自己的理解，再请他人帮助辨析。",
    descriptionEn: "Encourages members to bring the source passage, surrounding context, and their current understanding.",
  },
  {
    titleZh: "禅修里最常见的散乱和昏沉，大家怎么处理？",
    titleEn: "How do people work with distraction and dullness in meditation?",
    sectionZh: "禅修问答",
    sectionEn: "Meditation Practice",
    descriptionZh: "以实践层面的复盘和互助为主，不把短期状态神秘化。",
    descriptionEn: "A practical review thread that keeps short-term states grounded instead of mystical.",
  },
  {
    titleZh: "怎样写修学日志，既真实又不流于自我表演？",
    titleEn: "How can a practice journal stay honest without turning into performance?",
    sectionZh: "修学日志",
    sectionEn: "Practice Journal",
    descriptionZh: "首批会给出推荐模板，帮助用户记录发心、节奏、障碍和回顾。",
    descriptionEn: "The first release will include a suggested format for vows, rhythm, obstacles, and review.",
  },
];

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