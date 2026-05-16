import forumContent from "../data/forum-content.json";
import type {
  CreateForumReplyInput,
  CreateForumThreadInput,
  ForumModerationEvent,
  ForumReply,
  ForumRepository,
  ForumRuntimeStatus,
  ForumSection,
  ForumSnapshot,
  ForumThread,
  ForumThreadDetail,
} from "./forum-data";
import { ForumWriteUnavailableError } from "./forum-data";

interface ForumContentStore {
  sections: ForumSection[];
  threads: ForumThread[];
  replies: ForumReply[];
}

function getDefaultThreadRoleLabel(sectionSlug: string) {
  switch (sectionSlug) {
    case "newcomer-path":
      return "新手提问者";
    case "sutra-study":
      return "经论研读者";
    case "meditation-practice":
      return "练习反馈者";
    case "knowledge-archive":
      return "资料整理者";
    default:
      return "论坛提问者";
  }
}

function getDefaultThreadGuidanceSignal(sectionSlug: string) {
  switch (sectionSlug) {
    case "newcomer-path":
      return "请优先结合当前节奏给一条最容易开始的下一步建议。";
    case "sutra-study":
      return "请优先补出处、上下文和当前理解，再继续讨论名相。";
    case "meditation-practice":
      return "请优先结合练习前状态与结束后复盘来回应。";
    case "knowledge-archive":
      return "请优先说明这条内容为什么值得长期沉淀和复用。";
    default:
      return "请继续结合提问者当前阶段给出具体、可执行的回应。";
  }
}

function getDefaultReplyGuidanceSignal(sectionSlug?: string) {
  switch (sectionSlug) {
    case "newcomer-path":
      return "请先接住楼主当前阶段，再补一条最容易执行的起步建议。";
    case "sutra-study":
      return "请尽量围绕出处、上下文和当前理解继续回应。";
    case "meditation-practice":
      return "请优先结合练习条件、变化和复盘给出反馈。";
    case "knowledge-archive":
      return "请优先说明这条补充是否适合整理进长期资料。";
    default:
      return "请继续结合楼主当前阶段给出具体回应。";
  }
}

function normalizeThread(thread: ForumThread): ForumThread {
  return {
    ...thread,
    authorRoleLabel:
      typeof thread.authorRoleLabel === "string" && thread.authorRoleLabel.trim().length > 0
        ? thread.authorRoleLabel.trim()
        : getDefaultThreadRoleLabel(thread.sectionSlug),
    guidanceSignal:
      typeof thread.guidanceSignal === "string" && thread.guidanceSignal.trim().length > 0
        ? thread.guidanceSignal.trim()
        : getDefaultThreadGuidanceSignal(thread.sectionSlug),
  };
}

function normalizeReply(reply: ForumReply, thread?: ForumThread): ForumReply {
  return {
    ...reply,
    guidanceSignal:
      typeof reply.guidanceSignal === "string" && reply.guidanceSignal.trim().length > 0
        ? reply.guidanceSignal.trim()
        : getDefaultReplyGuidanceSignal(thread?.sectionSlug),
  };
}

function describeSeedModerationSummary(thread: ForumThread) {
  if (thread.knowledgeStage === "candidate") {
    return "种子主题已发布，并标记为候选资料，后续适合继续整理。";
  }

  return "种子主题已发布，当前仍处于讨论沉淀阶段。";
}

function buildSeedModerationEvents(threads: ForumThread[]): ForumModerationEvent[] {
  return threads.map((thread) => ({
    id: `seed-thread-published-${thread.slug}`,
    threadSlug: thread.slug,
    eventType: "thread-published",
    actorLabel: "论坛种子内容",
    summary: describeSeedModerationSummary(thread),
    createdAt: thread.publishedAt,
  }));
}

const content = forumContent as ForumContentStore;

export function createSeedForumRepository(): ForumRepository {
  const sections = content.sections;
  const threads = content.threads.map(normalizeThread);
  const threadBySlug = new Map(threads.map((thread) => [thread.slug, thread]));
  const replies = content.replies.map((reply) => normalizeReply(reply, threadBySlug.get(reply.threadSlug)));
  const moderationEvents = buildSeedModerationEvents(threads);

  const getSectionBySlug = (slug: string) => sections.find((section) => section.slug === slug);
  const getThreadBySlug = (slug: string) => threads.find((thread) => thread.slug === slug);
  const getThreadsBySection = (sectionSlug: string) => threads.filter((thread) => thread.sectionSlug === sectionSlug);
  const getRepliesByThreadSlug = (threadSlug: string) => replies.filter((reply) => reply.threadSlug === threadSlug);
  const getModerationEventsByThreadSlug = (threadSlug: string) =>
    moderationEvents.filter((event) => event.threadSlug === threadSlug);

  const getThreadDetailBySlug = (slug: string): ForumThreadDetail | undefined => {
    const thread = getThreadBySlug(slug);

    if (!thread) {
      return undefined;
    }

    return {
      thread,
      section: getSectionBySlug(thread.sectionSlug),
      replies: getRepliesByThreadSlug(thread.slug),
      moderationEvents: getModerationEventsByThreadSlug(thread.slug),
      source: "seed-json",
      generatedAt: new Date().toISOString(),
    };
  };

  const getSnapshot = (): ForumSnapshot => ({
    sections: sections.map((section) => {
      const sectionThreads = getThreadsBySection(section.slug);
      const replyCount = sectionThreads.reduce((total, thread) => total + getRepliesByThreadSlug(thread.slug).length, 0);

      return {
        ...section,
        threadCount: sectionThreads.length,
        replyCount,
      };
    }),
    threads,
    replies,
    moderationEvents,
    generatedAt: new Date().toISOString(),
    source: "seed-json",
  });

  const getRuntimeStatus = (): ForumRuntimeStatus => ({
    service: "forum",
    dataSource: "seed-json",
    persistenceMode: "seed-only",
    databaseConfigured: Boolean(process.env.FORUM_DATABASE_URL?.trim()),
    writesEnabled: false,
    counts: {
      sections: sections.length,
      threads: threads.length,
      replies: replies.length,
      moderationEvents: moderationEvents.length,
    },
    generatedAt: new Date().toISOString(),
  });

  const createThread = (_input: CreateForumThreadInput): ForumThreadDetail => {
    throw new ForumWriteUnavailableError("Thread creation is only available when FORUM_DATA_SOURCE=sqlite.");
  };

  const createReply = (_input: CreateForumReplyInput): ForumThreadDetail => {
    throw new ForumWriteUnavailableError("Reply creation is only available when FORUM_DATA_SOURCE=sqlite.");
  };

  return {
    dataSource: "seed-json",
    persistenceMode: "seed-only",
    getSections: () => sections,
    getThreads: () => threads,
    getReplies: () => replies,
    getModerationEvents: () => moderationEvents,
    getSectionBySlug,
    getThreadBySlug,
    getThreadsBySection,
    getRepliesByThreadSlug,
    getModerationEventsByThreadSlug,
    getThreadDetailBySlug,
    getSnapshot,
    getRuntimeStatus,
    createThread,
    createReply,
  };
}
