import forumContent from "../data/forum-content.json";

export type ForumModerationState = "published" | "needs-review" | "archived";
export type ForumKnowledgeStage = "discussion" | "candidate" | "archived";

export interface ForumSection {
  slug: string;
  name: string;
  description: string;
  moderationFocus: string;
  postingPrompt: string;
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
  moderationState: ForumModerationState;
  knowledgeStage: ForumKnowledgeStage;
}

export interface ForumReply {
  id: string;
  threadSlug: string;
  author: string;
  roleLabel: string;
  publishedAt: string;
  moderationState: ForumModerationState;
  trustSignal: string;
  body: string[];
}

interface ForumContentStore {
  sections: ForumSection[];
  threads: ForumThread[];
  replies: ForumReply[];
}

const content = forumContent as ForumContentStore;

export const FORUM_SECTIONS: ForumSection[] = content.sections;
export const FORUM_THREADS: ForumThread[] = content.threads;
export const FORUM_REPLIES: ForumReply[] = content.replies;

export function getSectionBySlug(slug: string) {
  return FORUM_SECTIONS.find((section) => section.slug === slug);
}

export function getThreadBySlug(slug: string) {
  return FORUM_THREADS.find((thread) => thread.slug === slug);
}

export function getThreadsBySection(sectionSlug: string) {
  return FORUM_THREADS.filter((thread) => thread.sectionSlug === sectionSlug);
}

export function getRepliesByThreadSlug(threadSlug: string) {
  return FORUM_REPLIES.filter((reply) => reply.threadSlug === threadSlug);
}

export function getThreadDetailBySlug(slug: string) {
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
}

export function getForumSnapshot() {
  return {
    sections: FORUM_SECTIONS.map((section) => {
      const threads = getThreadsBySection(section.slug);
      const replyCount = threads.reduce((total, thread) => total + getRepliesByThreadSlug(thread.slug).length, 0);

      return {
        ...section,
        threadCount: threads.length,
        replyCount,
      };
    }),
    threads: FORUM_THREADS,
    replies: FORUM_REPLIES,
    generatedAt: new Date().toISOString(),
    source: "seed-json",
  };
}
