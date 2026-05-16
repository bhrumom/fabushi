import { createSeedForumRepository } from "./forum-seed-repository";

export type ForumDataSource = "seed-json";
export type ForumPersistenceMode = "seed-only";
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

export interface ForumSectionSummary extends ForumSection {
  threadCount: number;
  replyCount: number;
}

export interface ForumThreadDetail {
  thread: ForumThread;
  section?: ForumSection;
  replies: ForumReply[];
  source: ForumDataSource;
  generatedAt: string;
}

export interface ForumSnapshot {
  sections: ForumSectionSummary[];
  threads: ForumThread[];
  replies: ForumReply[];
  generatedAt: string;
  source: ForumDataSource;
}

export interface ForumRuntimeStatus {
  service: "forum";
  dataSource: ForumDataSource;
  persistenceMode: ForumPersistenceMode;
  databaseConfigured: boolean;
  counts: {
    sections: number;
    threads: number;
    replies: number;
  };
  generatedAt: string;
}

export interface ForumRepository {
  dataSource: ForumDataSource;
  persistenceMode: ForumPersistenceMode;
  getSections(): ForumSection[];
  getThreads(): ForumThread[];
  getReplies(): ForumReply[];
  getSectionBySlug(slug: string): ForumSection | undefined;
  getThreadBySlug(slug: string): ForumThread | undefined;
  getThreadsBySection(sectionSlug: string): ForumThread[];
  getRepliesByThreadSlug(threadSlug: string): ForumReply[];
  getThreadDetailBySlug(slug: string): ForumThreadDetail | undefined;
  getSnapshot(): ForumSnapshot;
  getRuntimeStatus(): ForumRuntimeStatus;
}

const forumRepository = createSeedForumRepository();

export const FORUM_DATA_SOURCE = forumRepository.dataSource;
export const FORUM_PERSISTENCE_MODE = forumRepository.persistenceMode;

export function getSectionBySlug(slug: string) {
  return forumRepository.getSectionBySlug(slug);
}

export function getThreadBySlug(slug: string) {
  return forumRepository.getThreadBySlug(slug);
}

export function getThreadsBySection(sectionSlug: string) {
  return forumRepository.getThreadsBySection(sectionSlug);
}

export function getRepliesByThreadSlug(threadSlug: string) {
  return forumRepository.getRepliesByThreadSlug(threadSlug);
}

export function getThreadDetailBySlug(slug: string) {
  return forumRepository.getThreadDetailBySlug(slug);
}

export function getForumSnapshot() {
  return forumRepository.getSnapshot();
}

export function getForumRuntimeStatus() {
  return forumRepository.getRuntimeStatus();
}
