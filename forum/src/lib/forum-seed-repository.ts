import forumContent from "../data/forum-content.json";
import type {
  CreateForumReplyInput,
  CreateForumThreadInput,
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

const content = forumContent as ForumContentStore;

export function createSeedForumRepository(): ForumRepository {
  const sections = content.sections;
  const threads = content.threads;
  const replies = content.replies;

  const getSectionBySlug = (slug: string) => sections.find((section) => section.slug === slug);
  const getThreadBySlug = (slug: string) => threads.find((thread) => thread.slug === slug);
  const getThreadsBySection = (sectionSlug: string) => threads.filter((thread) => thread.sectionSlug === sectionSlug);
  const getRepliesByThreadSlug = (threadSlug: string) => replies.filter((reply) => reply.threadSlug === threadSlug);

  const getThreadDetailBySlug = (slug: string): ForumThreadDetail | undefined => {
    const thread = getThreadBySlug(slug);

    if (!thread) {
      return undefined;
    }

    return {
      thread,
      section: getSectionBySlug(thread.sectionSlug),
      replies: getRepliesByThreadSlug(thread.slug),
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
    getSectionBySlug,
    getThreadBySlug,
    getThreadsBySection,
    getRepliesByThreadSlug,
    getThreadDetailBySlug,
    getSnapshot,
    getRuntimeStatus,
    createThread,
    createReply,
  };
}
