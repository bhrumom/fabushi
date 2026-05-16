export interface ForumSection {
  slug: string;
  name: string;
  description: string;
  moderationFocus: string;
}

export interface ForumThread {
  slug: string;
  sectionSlug: string;
  title: string;
  summary: string;
  author: string;
  publishedAt: string;
  lastActivity: string;
  replyCount: number;
  followCount: number;
  bookmarkCount: number;
  tags: string[];
  openingPost: string[];
  takeaways: string[];
}

export const FORUM_SECTIONS: ForumSection[] = [
  {
    slug: "newcomer-path",
    name: "新手起步",
    description: "给第一次认真接触佛法的人一个可提问、可被接住、也能慢慢建立节奏的入口。",
    moderationFocus: "优先温和纠偏，避免把个人经验包装成唯一标准。",
  },
  {
    slug: "sutra-study",
    name: "经论研读",
    description: "围绕经典出处、上下文和术语理解展开可追溯讨论，让内容能长期沉淀。",
    moderationFocus: "鼓励带出处和上下文，减少断章取义。",
  },
  {
    slug: "meditation-practice",
    name: "禅修问答",
    description: "聚焦坐禅、散乱、昏沉、练习节奏和复盘，把经验说具体。",
    moderationFocus: "欢迎经验分享，但避免境界化表达和权威化断言。",
  },
  {
    slug: "knowledge-archive",
    name: "资料整理",
    description: "把高质量回答、专题串和稳定共识沉淀成可重复引用的知识页。",
    moderationFocus: "优先整理长期价值高、引用清楚、适合再次访问的内容。",
  },
];

export const FORUM_THREADS: ForumThread[] = [
  {
    slug: "first-year-stability",
    sectionSlug: "newcomer-path",
    title: "学佛第一年，先稳定什么最重要？",
    summary: "先把愿心、作息、听闻和一个最基础的练习节奏稳下来，比一开始抓很多法门更关键。",
    author: "净行",
    publishedAt: "2026-05-16",
    lastActivity: "最近整理：起步节奏清单",
    replyCount: 18,
    followCount: 42,
    bookmarkCount: 27,
    tags: ["新手", "作息", "起步"],
    openingPost: [
      "很多人学佛的第一年，不是信息太少，而是同时抓太多，结果什么都没有稳住。",
      "如果只能先稳定三件事，我更倾向于愿心、作息和一个能长期重复的基础练习。这样后面接读经、持诵、禅修或共修时，脚下才有地。",
      "欢迎大家结合自己的经历来讲，但尽量说清楚适用对象：是完全零基础的人，还是已经开始有固定日常的人。"
    ],
    takeaways: [
      "先稳节奏，再谈扩展。",
      "建议回复时写明自己的起点，避免把个人路径说成唯一答案。",
      "这类高质量回复后续适合沉淀为新手欢迎资料。"
    ],
  },
  {
    slug: "how-to-ask-while-reading-sutras",
    sectionSlug: "sutra-study",
    title: "读经时遇到看不懂的名相，应该怎样提问？",
    summary: "好问题不只是贴一个词，而是把出处、上下文和自己的理解一起带出来。",
    author: "闻思",
    publishedAt: "2026-05-16",
    lastActivity: "最近整理：读经提问模板",
    replyCount: 11,
    followCount: 31,
    bookmarkCount: 36,
    tags: ["名相", "出处", "提问方式"],
    openingPost: [
      "经论研读区最怕只剩一句“这是什么意思？”，因为没有出处和上下文时，回答很容易发散。",
      "我建议论坛从一开始就鼓励更好的提问格式：至少附上经论出处、前后文、自己目前的理解，以及卡住的具体点。",
      "这样别人不是只来扔答案，而是能一起把语境理清楚。"
    ],
    takeaways: [
      "带出处、带上下文、带当前理解。",
      "好的提问本身就是知识沉淀的起点。",
      "后续可以把提问模板做成固定置顶说明。"
    ],
  },
  {
    slug: "working-with-distraction-and-dullness",
    sectionSlug: "meditation-practice",
    title: "禅修里最常见的散乱和昏沉，大家怎么处理？",
    summary: "把练习前状态、练习中的变化和结束后的复盘讲具体，比泛泛谈体验更有帮助。",
    author: "清照",
    publishedAt: "2026-05-16",
    lastActivity: "最近整理：复盘提示补充",
    replyCount: 23,
    followCount: 38,
    bookmarkCount: 33,
    tags: ["禅修", "散乱", "昏沉"],
    openingPost: [
      "散乱和昏沉几乎人人都会遇到，但如果只说“我今天状态不好”，别人其实帮不上太多。",
      "更有用的分享，往往会把练习前的身心状态、练习中的变化，以及结束后的复盘都讲清楚。",
      "欢迎谈经验，但尽量不要把短期体感包装成深层境界判断。"
    ],
    takeaways: [
      "论坛需要具体经验，而不是空泛体验形容。",
      "复盘维度可以包括作息、坐姿、时长和呼吸。",
      "这类话题活跃度高，治理边界要从第一天就明确。"
    ],
  },
  {
    slug: "what-deserves-the-archive-first",
    sectionSlug: "knowledge-archive",
    title: "论坛早期最值得优先沉淀成资料页的内容是什么？",
    summary: "不是所有热门讨论都值得归档，真正优先的是可反复帮助新人的结构化内容。",
    author: "常住编辑",
    publishedAt: "2026-05-16",
    lastActivity: "最近整理：归档标准草案",
    replyCount: 7,
    followCount: 19,
    bookmarkCount: 22,
    tags: ["精华", "归档", "资料页"],
    openingPost: [
      "如果论坛想长期有价值，就不能只靠时间线往前滚。",
      "早期最值得沉淀的，往往不是最热闹的串，而是能反复帮助新人的结构化回答，比如起步路径、常见误区、读经提问模板和稳定练习建议。",
      "这条讨论的目的，是先把“什么值得沉淀”这件事说清楚。"
    ],
    takeaways: [
      "可复用、可引用、可减少重复答疑的内容优先。",
      "归档标准应同时考虑正确性、清晰度和长期访问价值。",
      "后续适合接精华标记和资料页生成流程。"
    ],
  },
];

export function getSectionBySlug(slug: string) {
  return FORUM_SECTIONS.find((section) => section.slug === slug);
}

export function getThreadBySlug(slug: string) {
  return FORUM_THREADS.find((thread) => thread.slug === slug);
}

export function getThreadsBySection(sectionSlug: string) {
  return FORUM_THREADS.filter((thread) => thread.sectionSlug === sectionSlug);
}

export function getForumSnapshot() {
  return {
    sections: FORUM_SECTIONS.map((section) => ({
      ...section,
      threadCount: getThreadsBySection(section.slug).length,
    })),
    threads: FORUM_THREADS,
    generatedAt: new Date().toISOString(),
    source: "seed",
  };
}
