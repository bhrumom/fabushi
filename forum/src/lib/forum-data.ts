import { createSeedForumRepository } from "./forum-seed-repository";
import { createSqliteForumRepository } from "./forum-sqlite-repository";

export type ForumDataSource = "seed-json" | "sqlite";
export type ForumPersistenceMode = "seed-only" | "sqlite-file";
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

export interface CreateForumThreadInput {
  sectionSlug: string;
  title: string;
  summary: string;
  author: string;
  tags: string[];
  openingPost: string[];
}

export interface ForumRuntimeStatus {
  service: "forum";
  dataSource: ForumDataSource;
  persistenceMode: ForumPersistenceMode;
  databaseConfigured: boolean;
  writesEnabled: boolean;
  counts: {
    sections: number;
    threads: number;
    replies: number;
  };
  generatedAt: string;
}

export class ForumWriteUnavailableError extends Error {
  constructor(message = "Forum writes are not enabled for the current data source.") {
    super(message);
    this.name = "ForumWriteUnavailableError";
  }
}

export class ForumInputError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ForumInputError";
  }
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
  createThread(input: CreateForumThreadInput): ForumThreadDetail;
}

function resolveForumDataSource(): ForumDataSource {
  const configuredSource = process.env.FORUM_DATA_SOURCE?.trim();

  if (!configuredSource || configuredSource === "seed-json") {
    return "seed-json";
  }

  if (configuredSource === "sqlite") {
    return "sqlite";
  }

  throw new Error(`Unsupported FORUM_DATA_SOURCE: ${configuredSource}`);
}

function createForumRepository(): ForumRepository {
  const dataSource = resolveForumDataSource();

  if (dataSource === "sqlite") {
    return createSqliteForumRepository();
  }

  return createSeedForumRepository();
}

const forumRepository = createForumRepository();

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

export function createForumThread(input: CreateForumThreadInput) {
  return forumRepository.createThread(input);
}
