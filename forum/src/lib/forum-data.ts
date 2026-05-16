import { createSeedForumRepository } from "./forum-seed-repository";
import { createSqliteForumRepository } from "./forum-sqlite-repository";

export type ForumDataSource = "seed-json" | "sqlite";
export type ForumPersistenceMode = "seed-only" | "sqlite-file";
export type ForumModerationState = "published" | "needs-review" | "archived";
export type ForumKnowledgeStage = "discussion" | "candidate" | "archived";
export type ForumModerationEventType = "thread-published" | "thread-created" | "reply-created";

const TRUE_VALUES = new Set(["1", "true", "yes", "on"]);
const FALSE_VALUES = new Set(["0", "false", "no", "off"]);

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
  authorRoleLabel: string;
  guidanceSignal: string;
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
  guidanceSignal: string;
  publishedAt: string;
  moderationState: ForumModerationState;
  trustSignal: string;
  body: string[];
}

export interface ForumModerationEvent {
  id: string;
  threadSlug: string;
  replyId?: string;
  eventType: ForumModerationEventType;
  actorLabel: string;
  summary: string;
  createdAt: string;
}

export interface ForumSectionSummary extends ForumSection {
  threadCount: number;
  replyCount: number;
}

export interface ForumThreadDetail {
  thread: ForumThread;
  section?: ForumSection;
  replies: ForumReply[];
  moderationEvents: ForumModerationEvent[];
  source: ForumDataSource;
  generatedAt: string;
}

export interface ForumSnapshot {
  sections: ForumSectionSummary[];
  threads: ForumThread[];
  replies: ForumReply[];
  moderationEvents: ForumModerationEvent[];
  generatedAt: string;
  source: ForumDataSource;
}

export interface CreateForumThreadInput {
  sectionSlug: string;
  title: string;
  summary: string;
  author: string;
  authorRoleLabel: string;
  guidanceSignal: string;
  tags: string[];
  openingPost: string[];
}

export interface CreateForumReplyInput {
  threadSlug: string;
  author: string;
  roleLabel: string;
  guidanceSignal: string;
  trustSignal: string;
  body: string[];
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
    moderationEvents: number;
  };
  generatedAt: string;
}

export class ForumWriteUnavailableError extends Error {
  constructor(message = "Forum writes are not enabled for the current runtime.") {
    super(message);
    this.name = "ForumWriteUnavailableError";
  }
}

export class ForumWriteAccessDeniedError extends Error {
  constructor(message = "This runtime requires a valid write access code before accepting new threads or replies.") {
    super(message);
    this.name = "ForumWriteAccessDeniedError";
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
  getModerationEvents(): ForumModerationEvent[];
  getSectionBySlug(slug: string): ForumSection | undefined;
  getThreadBySlug(slug: string): ForumThread | undefined;
  getThreadsBySection(sectionSlug: string): ForumThread[];
  getRepliesByThreadSlug(threadSlug: string): ForumReply[];
  getModerationEventsByThreadSlug(threadSlug: string): ForumModerationEvent[];
  getThreadDetailBySlug(slug: string): ForumThreadDetail | undefined;
  getSnapshot(): ForumSnapshot;
  getRuntimeStatus(): ForumRuntimeStatus;
  createThread(input: CreateForumThreadInput): ForumThreadDetail;
  createReply(input: CreateForumReplyInput): ForumThreadDetail;
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

function resolveForumWritesEnabled(dataSource: ForumDataSource): boolean {
  if (dataSource !== "sqlite") {
    return false;
  }

  const configuredFlag = process.env.FORUM_ENABLE_WRITES?.trim().toLowerCase();

  if (!configuredFlag) {
    return false;
  }

  if (TRUE_VALUES.has(configuredFlag)) {
    return true;
  }

  if (FALSE_VALUES.has(configuredFlag)) {
    return false;
  }

  throw new Error(`Unsupported FORUM_ENABLE_WRITES: ${process.env.FORUM_ENABLE_WRITES}`);
}

function resolveForumWriteAccessCode(dataSource: ForumDataSource): string {
  if (dataSource !== "sqlite") {
    return "";
  }

  return process.env.FORUM_WRITE_ACCESS_CODE?.trim() ?? "";
}

function getWriteUnavailableMessage(dataSource: ForumDataSource) {
  if (dataSource === "sqlite") {
    return "Forum writes are disabled for the current sqlite runtime. Set FORUM_ENABLE_WRITES=true to allow thread and reply creation.";
  }

  return "Forum writes are only available when FORUM_DATA_SOURCE=sqlite and FORUM_ENABLE_WRITES=true.";
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

export function getModerationEventsByThreadSlug(threadSlug: string) {
  return forumRepository.getModerationEventsByThreadSlug(threadSlug);
}

export function getThreadDetailBySlug(slug: string) {
  return forumRepository.getThreadDetailBySlug(slug);
}

export function getForumSnapshot() {
  return forumRepository.getSnapshot();
}

export function getForumRuntimeStatus() {
  const runtimeStatus = forumRepository.getRuntimeStatus();
  const writesEnabled = resolveForumWritesEnabled(runtimeStatus.dataSource);

  return {
    ...runtimeStatus,
    writesEnabled,
    requiresAccessCode: writesEnabled && Boolean(resolveForumWriteAccessCode(runtimeStatus.dataSource)),
  };
}

export function assertForumWriteAccessCode(value: unknown) {
  if (!resolveForumWritesEnabled(forumRepository.dataSource)) {
    return;
  }

  const configuredCode = resolveForumWriteAccessCode(forumRepository.dataSource);

  if (!configuredCode) {
    return;
  }

  if (typeof value !== "string" || value.trim() !== configuredCode) {
    throw new ForumWriteAccessDeniedError();
  }
}

export function createForumThread(input: CreateForumThreadInput) {
  if (!resolveForumWritesEnabled(forumRepository.dataSource)) {
    throw new ForumWriteUnavailableError(getWriteUnavailableMessage(forumRepository.dataSource));
  }

  return forumRepository.createThread(input);
}

export function createForumReply(input: CreateForumReplyInput) {
  if (!resolveForumWritesEnabled(forumRepository.dataSource)) {
    throw new ForumWriteUnavailableError(getWriteUnavailableMessage(forumRepository.dataSource));
  }

  return forumRepository.createReply(input);
}
