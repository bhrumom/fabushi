import { mkdirSync } from "node:fs";
import path from "node:path";
import { DatabaseSync } from "node:sqlite";
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
import { ForumInputError } from "./forum-data";

interface ForumContentStore {
  sections: ForumSection[];
  threads: ForumThread[];
  replies: ForumReply[];
}

interface SqliteSectionRow {
  slug: string;
  name: string;
  description: string;
  moderation_focus: string;
  posting_prompt: string;
}

interface SqliteThreadRow {
  slug: string;
  section_slug: string;
  title: string;
  summary: string;
  author: string;
  author_role_label?: string | null;
  guidance_signal?: string | null;
  published_at: string;
  last_activity: string;
  reply_count: number;
  follow_count: number;
  bookmark_count: number;
  tags_json: string;
  opening_post_json: string;
  takeaways_json: string;
  moderation_state: ForumThread["moderationState"];
  knowledge_stage: ForumThread["knowledgeStage"];
}

interface SqliteReplyRow {
  id: string;
  thread_slug: string;
  author: string;
  role_label: string;
  guidance_signal?: string | null;
  published_at: string;
  moderation_state: ForumReply["moderationState"];
  trust_signal: string;
  body_json: string;
}

interface SqliteModerationEventRow {
  id: string;
  thread_slug: string;
  reply_id: string | null;
  event_type: ForumModerationEvent["eventType"];
  actor_label: string;
  summary: string;
  created_at: string;
}

const seedContent = forumContent as ForumContentStore;
const DEFAULT_DATABASE_URL = "file:./data/forum.db";

function parseJsonArray(value: string): string[] {
  const parsed = JSON.parse(value) as unknown;
  return Array.isArray(parsed) ? parsed.map((item) => String(item)) : [];
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

function getDefaultReplyRoleLabel() {
  return "论坛参与者";
}

function getDefaultReplyTrustSignal() {
  return "新提交回复，等待更多互动后再判断是否适合沉淀。";
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
    roleLabel:
      typeof reply.roleLabel === "string" && reply.roleLabel.trim().length > 0
        ? reply.roleLabel.trim()
        : getDefaultReplyRoleLabel(),
    guidanceSignal:
      typeof reply.guidanceSignal === "string" && reply.guidanceSignal.trim().length > 0
        ? reply.guidanceSignal.trim()
        : getDefaultReplyGuidanceSignal(thread?.sectionSlug),
    trustSignal:
      typeof reply.trustSignal === "string" && reply.trustSignal.trim().length > 0
        ? reply.trustSignal.trim()
        : getDefaultReplyTrustSignal(),
  };
}

function describeSeedModerationSummary(thread: ForumThread) {
  if (thread.knowledgeStage === "candidate") {
    return "种子主题已发布，并标记为候选资料，后续适合继续整理。";
  }

  return "种子主题已发布，当前仍处于讨论沉淀阶段。";
}

function describeThreadCreationSummary(sectionSlug: string) {
  if (sectionSlug === "newcomer-path") {
    return "新主题已发布，并进入新手起步引导队列，后续可继续补充适用对象与已尝试方法。";
  }

  return "新主题已发布，后续可根据互动质量继续补充治理判断和资料沉淀。";
}

function describeReplyCreationSummary(sectionSlug: string) {
  if (sectionSlug === "newcomer-path") {
    return "新回复已写入时间线，适合后续继续补充适用对象与已尝试方法。";
  }

  return "新回复已写入时间线，等待更多互动后再判断是否适合沉淀。";
}

function mapSection(row: SqliteSectionRow): ForumSection {
  return {
    slug: row.slug,
    name: row.name,
    description: row.description,
    moderationFocus: row.moderation_focus,
    postingPrompt: row.posting_prompt,
  };
}

function mapThread(row: SqliteThreadRow): ForumThread {
  return {
    slug: row.slug,
    sectionSlug: row.section_slug,
    title: row.title,
    summary: row.summary,
    author: row.author,
    authorRoleLabel:
      typeof row.author_role_label === "string" && row.author_role_label.trim().length > 0
        ? row.author_role_label.trim()
        : getDefaultThreadRoleLabel(row.section_slug),
    guidanceSignal:
      typeof row.guidance_signal === "string" && row.guidance_signal.trim().length > 0
        ? row.guidance_signal.trim()
        : getDefaultThreadGuidanceSignal(row.section_slug),
    publishedAt: row.published_at,
    lastActivity: row.last_activity,
    replyCount: Number(row.reply_count),
    followCount: Number(row.follow_count),
    bookmarkCount: Number(row.bookmark_count),
    tags: parseJsonArray(row.tags_json),
    openingPost: parseJsonArray(row.opening_post_json),
    takeaways: parseJsonArray(row.takeaways_json),
    moderationState: row.moderation_state,
    knowledgeStage: row.knowledge_stage,
  };
}

function mapReply(row: SqliteReplyRow): ForumReply {
  return {
    id: row.id,
    threadSlug: row.thread_slug,
    author: row.author,
    roleLabel:
      typeof row.role_label === "string" && row.role_label.trim().length > 0
        ? row.role_label.trim()
        : getDefaultReplyRoleLabel(),
    guidanceSignal:
      typeof row.guidance_signal === "string" && row.guidance_signal.trim().length > 0
        ? row.guidance_signal.trim()
        : getDefaultReplyGuidanceSignal(),
    publishedAt: row.published_at,
    moderationState: row.moderation_state,
    trustSignal:
      typeof row.trust_signal === "string" && row.trust_signal.trim().length > 0
        ? row.trust_signal.trim()
        : getDefaultReplyTrustSignal(),
    body: parseJsonArray(row.body_json),
  };
}

function mapModerationEvent(row: SqliteModerationEventRow): ForumModerationEvent {
  return {
    id: row.id,
    threadSlug: row.thread_slug,
    replyId: row.reply_id ?? undefined,
    eventType: row.event_type,
    actorLabel: row.actor_label,
    summary: row.summary,
    createdAt: row.created_at,
  };
}

function resolveSqliteDatabasePath(databaseUrl: string): string {
  const trimmedUrl = databaseUrl.trim();

  if (!trimmedUrl) {
    throw new Error("FORUM_DATABASE_URL cannot be empty when FORUM_DATA_SOURCE=sqlite.");
  }

  const withoutPrefix = trimmedUrl.startsWith("file:") ? trimmedUrl.slice(5) : trimmedUrl;

  if (!withoutPrefix) {
    throw new Error("FORUM_DATABASE_URL must point to a sqlite file path.");
  }

  if (withoutPrefix === ":memory:") {
    return withoutPrefix;
  }

  const normalizedPath = withoutPrefix.startsWith("//") ? withoutPrefix.slice(2) : withoutPrefix;

  return path.isAbsolute(normalizedPath)
    ? normalizedPath
    : path.resolve(process.cwd(), normalizedPath);
}

function ensureDatabaseDirectory(databasePath: string) {
  if (!databasePath || databasePath === ":memory:") {
    return;
  }

  mkdirSync(path.dirname(databasePath), { recursive: true });
}

function slugifyTitle(title: string): string {
  const normalized = title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

  if (normalized) {
    return normalized;
  }

  return `thread-${Date.now().toString(36)}`;
}

function initializeSchema(database: DatabaseSync) {
  database.exec(`
    CREATE TABLE IF NOT EXISTS forum_sections (
      slug TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT NOT NULL,
      moderation_focus TEXT NOT NULL,
      posting_prompt TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS forum_threads (
      slug TEXT PRIMARY KEY,
      section_slug TEXT NOT NULL,
      title TEXT NOT NULL,
      summary TEXT NOT NULL,
      author TEXT NOT NULL,
      author_role_label TEXT NOT NULL DEFAULT '论坛提问者',
      guidance_signal TEXT NOT NULL DEFAULT '请继续结合提问者当前阶段给出具体、可执行的回应。',
      published_at TEXT NOT NULL,
      last_activity TEXT NOT NULL,
      reply_count INTEGER NOT NULL DEFAULT 0,
      follow_count INTEGER NOT NULL DEFAULT 0,
      bookmark_count INTEGER NOT NULL DEFAULT 0,
      tags_json TEXT NOT NULL,
      opening_post_json TEXT NOT NULL,
      takeaways_json TEXT NOT NULL,
      moderation_state TEXT NOT NULL,
      knowledge_stage TEXT NOT NULL,
      FOREIGN KEY (section_slug) REFERENCES forum_sections(slug)
    );

    CREATE TABLE IF NOT EXISTS forum_replies (
      id TEXT PRIMARY KEY,
      thread_slug TEXT NOT NULL,
      author TEXT NOT NULL,
      role_label TEXT NOT NULL,
      guidance_signal TEXT NOT NULL DEFAULT '请继续结合楼主当前阶段给出具体回应。',
      published_at TEXT NOT NULL,
      moderation_state TEXT NOT NULL,
      trust_signal TEXT NOT NULL,
      body_json TEXT NOT NULL,
      FOREIGN KEY (thread_slug) REFERENCES forum_threads(slug)
    );

    CREATE TABLE IF NOT EXISTS forum_moderation_events (
      id TEXT PRIMARY KEY,
      thread_slug TEXT NOT NULL,
      reply_id TEXT,
      event_type TEXT NOT NULL,
      actor_label TEXT NOT NULL,
      summary TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (thread_slug) REFERENCES forum_threads(slug),
      FOREIGN KEY (reply_id) REFERENCES forum_replies(id)
    );
  `);
}

function tableHasColumn(database: DatabaseSync, tableName: string, columnName: string) {
  const rows = database.prepare(`PRAGMA table_info(${tableName})`).all() as Array<{ name: string }>;
  return rows.some((row) => row.name === columnName);
}

function ensureSchemaCompatibility(database: DatabaseSync) {
  if (!tableHasColumn(database, "forum_threads", "author_role_label")) {
    database.exec(
      "ALTER TABLE forum_threads ADD COLUMN author_role_label TEXT NOT NULL DEFAULT '论坛提问者'",
    );
  }

  if (!tableHasColumn(database, "forum_threads", "guidance_signal")) {
    database.exec(
      "ALTER TABLE forum_threads ADD COLUMN guidance_signal TEXT NOT NULL DEFAULT '请继续结合提问者当前阶段给出具体、可执行的回应。'",
    );
  }

  if (!tableHasColumn(database, "forum_replies", "guidance_signal")) {
    database.exec(
      "ALTER TABLE forum_replies ADD COLUMN guidance_signal TEXT NOT NULL DEFAULT '请继续结合楼主当前阶段给出具体回应。'",
    );
  }
}

function seedDatabaseIfEmpty(database: DatabaseSync) {
  const countRow = database.prepare("SELECT COUNT(*) AS count FROM forum_sections").get() as { count: number };

  if (Number(countRow.count) > 0) {
    return;
  }

  const normalizedThreads = seedContent.threads.map(normalizeThread);
  const threadBySlug = new Map(normalizedThreads.map((thread) => [thread.slug, thread]));
  const normalizedReplies = seedContent.replies.map((reply) => normalizeReply(reply, threadBySlug.get(reply.threadSlug)));

  const insertSection = database.prepare(`
    INSERT INTO forum_sections (slug, name, description, moderation_focus, posting_prompt)
    VALUES (?, ?, ?, ?, ?)
  `);
  const insertThread = database.prepare(`
    INSERT INTO forum_threads (
      slug,
      section_slug,
      title,
      summary,
      author,
      author_role_label,
      guidance_signal,
      published_at,
      last_activity,
      reply_count,
      follow_count,
      bookmark_count,
      tags_json,
      opening_post_json,
      takeaways_json,
      moderation_state,
      knowledge_stage
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  const insertReply = database.prepare(`
    INSERT INTO forum_replies (
      id,
      thread_slug,
      author,
      role_label,
      guidance_signal,
      published_at,
      moderation_state,
      trust_signal,
      body_json
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  const insertModerationEvent = database.prepare(`
    INSERT INTO forum_moderation_events (
      id,
      thread_slug,
      reply_id,
      event_type,
      actor_label,
      summary,
      created_at
    )
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);

  database.exec("BEGIN");

  try {
    for (const section of seedContent.sections) {
      insertSection.run(
        section.slug,
        section.name,
        section.description,
        section.moderationFocus,
        section.postingPrompt,
      );
    }

    for (const thread of normalizedThreads) {
      insertThread.run(
        thread.slug,
        thread.sectionSlug,
        thread.title,
        thread.summary,
        thread.author,
        thread.authorRoleLabel,
        thread.guidanceSignal,
        thread.publishedAt,
        thread.lastActivity,
        thread.replyCount,
        thread.followCount,
        thread.bookmarkCount,
        JSON.stringify(thread.tags),
        JSON.stringify(thread.openingPost),
        JSON.stringify(thread.takeaways),
        thread.moderationState,
        thread.knowledgeStage,
      );

      insertModerationEvent.run(
        `seed-thread-published-${thread.slug}`,
        thread.slug,
        null,
        "thread-published",
        "论坛种子内容",
        describeSeedModerationSummary(thread),
        thread.publishedAt,
      );
    }

    for (const reply of normalizedReplies) {
      insertReply.run(
        reply.id,
        reply.threadSlug,
        reply.author,
        reply.roleLabel,
        reply.guidanceSignal,
        reply.publishedAt,
        reply.moderationState,
        reply.trustSignal,
        JSON.stringify(reply.body),
      );
    }

    database.exec("COMMIT");
  } catch (error) {
    database.exec("ROLLBACK");
    throw error;
  }
}

function nextThreadSlug(database: DatabaseSync, title: string): string {
  const baseSlug = slugifyTitle(title);
  const existingThread = database.prepare("SELECT slug FROM forum_threads WHERE slug = ? LIMIT 1");

  if (!existingThread.get(baseSlug)) {
    return baseSlug;
  }

  let suffix = 2;

  while (existingThread.get(`${baseSlug}-${suffix}`)) {
    suffix += 1;
  }

  return `${baseSlug}-${suffix}`;
}

function nextReplyId(database: DatabaseSync, threadSlug: string): string {
  const baseId = `reply-${threadSlug}-${Date.now().toString(36)}`;
  const existingReply = database.prepare("SELECT id FROM forum_replies WHERE id = ? LIMIT 1");

  if (!existingReply.get(baseId)) {
    return baseId;
  }

  let suffix = 2;

  while (existingReply.get(`${baseId}-${suffix}`)) {
    suffix += 1;
  }

  return `${baseId}-${suffix}`;
}

function nextModerationEventId(database: DatabaseSync, threadSlug: string, eventType: ForumModerationEvent["eventType"]): string {
  const baseId = `event-${eventType}-${threadSlug}-${Date.now().toString(36)}`;
  const existingEvent = database.prepare("SELECT id FROM forum_moderation_events WHERE id = ? LIMIT 1");

  if (!existingEvent.get(baseId)) {
    return baseId;
  }

  let suffix = 2;

  while (existingEvent.get(`${baseId}-${suffix}`)) {
    suffix += 1;
  }

  return `${baseId}-${suffix}`;
}

export function createSqliteForumRepository(): ForumRepository {
  const databasePath = resolveSqliteDatabasePath(process.env.FORUM_DATABASE_URL?.trim() || DEFAULT_DATABASE_URL);
  ensureDatabaseDirectory(databasePath);

  const database = new DatabaseSync(databasePath);
  database.exec("PRAGMA foreign_keys = ON");
  initializeSchema(database);
  ensureSchemaCompatibility(database);
  seedDatabaseIfEmpty(database);

  const getSections = (): ForumSection[] => {
    const rows = database
      .prepare("SELECT slug, name, description, moderation_focus, posting_prompt FROM forum_sections ORDER BY name ASC")
      .all() as unknown as SqliteSectionRow[];

    return rows.map(mapSection);
  };

  const getThreads = (): ForumThread[] => {
    const rows = database
      .prepare(`
        SELECT
          slug,
          section_slug,
          title,
          summary,
          author,
          author_role_label,
          guidance_signal,
          published_at,
          last_activity,
          reply_count,
          follow_count,
          bookmark_count,
          tags_json,
          opening_post_json,
          takeaways_json,
          moderation_state,
          knowledge_stage
        FROM forum_threads
        ORDER BY published_at DESC, slug DESC
      `)
      .all() as unknown as SqliteThreadRow[];

    return rows.map(mapThread);
  };

  const getReplies = (): ForumReply[] => {
    const rows = database
      .prepare(`
        SELECT
          id,
          thread_slug,
          author,
          role_label,
          guidance_signal,
          published_at,
          moderation_state,
          trust_signal,
          body_json
        FROM forum_replies
        ORDER BY published_at ASC, id ASC
      `)
      .all() as unknown as SqliteReplyRow[];

    return rows.map(mapReply);
  };

  const getModerationEvents = (): ForumModerationEvent[] => {
    const rows = database
      .prepare(`
        SELECT
          id,
          thread_slug,
          reply_id,
          event_type,
          actor_label,
          summary,
          created_at
        FROM forum_moderation_events
        ORDER BY created_at ASC, id ASC
      `)
      .all() as unknown as SqliteModerationEventRow[];

    return rows.map(mapModerationEvent);
  };

  const getSectionBySlug = (slug: string): ForumSection | undefined => {
    const row = database
      .prepare("SELECT slug, name, description, moderation_focus, posting_prompt FROM forum_sections WHERE slug = ? LIMIT 1")
      .get(slug) as SqliteSectionRow | undefined;

    return row ? mapSection(row) : undefined;
  };

  const getThreadBySlug = (slug: string): ForumThread | undefined => {
    const row = database
      .prepare(`
        SELECT
          slug,
          section_slug,
          title,
          summary,
          author,
          author_role_label,
          guidance_signal,
          published_at,
          last_activity,
          reply_count,
          follow_count,
          bookmark_count,
          tags_json,
          opening_post_json,
          takeaways_json,
          moderation_state,
          knowledge_stage
        FROM forum_threads
        WHERE slug = ?
        LIMIT 1
      `)
      .get(slug) as SqliteThreadRow | undefined;

    return row ? mapThread(row) : undefined;
  };

  const getThreadsBySection = (sectionSlug: string): ForumThread[] => {
    const rows = database
      .prepare(`
        SELECT
          slug,
          section_slug,
          title,
          summary,
          author,
          author_role_label,
          guidance_signal,
          published_at,
          last_activity,
          reply_count,
          follow_count,
          bookmark_count,
          tags_json,
          opening_post_json,
          takeaways_json,
          moderation_state,
          knowledge_stage
        FROM forum_threads
        WHERE section_slug = ?
        ORDER BY published_at DESC, slug DESC
      `)
      .all(sectionSlug) as unknown as SqliteThreadRow[];

    return rows.map(mapThread);
  };

  const getRepliesByThreadSlug = (threadSlug: string): ForumReply[] => {
    const rows = database
      .prepare(`
        SELECT
          id,
          thread_slug,
          author,
          role_label,
          guidance_signal,
          published_at,
          moderation_state,
          trust_signal,
          body_json
        FROM forum_replies
        WHERE thread_slug = ?
        ORDER BY published_at ASC, id ASC
      `)
      .all(threadSlug) as unknown as SqliteReplyRow[];

    return rows.map(mapReply);
  };

  const getModerationEventsByThreadSlug = (threadSlug: string): ForumModerationEvent[] => {
    const rows = database
      .prepare(`
        SELECT
          id,
          thread_slug,
          reply_id,
          event_type,
          actor_label,
          summary,
          created_at
        FROM forum_moderation_events
        WHERE thread_slug = ?
        ORDER BY created_at ASC, id ASC
      `)
      .all(threadSlug) as unknown as SqliteModerationEventRow[];

    return rows.map(mapModerationEvent);
  };

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
      source: "sqlite",
      generatedAt: new Date().toISOString(),
    };
  };

  const getSnapshot = (): ForumSnapshot => {
    const sections = getSections();
    const threads = getThreads();
    const replies = getReplies();
    const moderationEvents = getModerationEvents();

    return {
      sections: sections.map((section) => {
        const sectionThreads = threads.filter((thread) => thread.sectionSlug === section.slug);
        const replyCount = sectionThreads.reduce(
          (total, thread) => total + replies.filter((reply) => reply.threadSlug === thread.slug).length,
          0,
        );

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
      source: "sqlite",
    };
  };

  const getRuntimeStatus = (): ForumRuntimeStatus => {
    const countsRow = database
      .prepare(`
        SELECT
          (SELECT COUNT(*) FROM forum_sections) AS sections,
          (SELECT COUNT(*) FROM forum_threads) AS threads,
          (SELECT COUNT(*) FROM forum_replies) AS replies,
          (SELECT COUNT(*) FROM forum_moderation_events) AS moderation_events
      `)
      .get() as { sections: number; threads: number; replies: number; moderation_events: number };

    return {
      service: "forum",
      dataSource: "sqlite",
      persistenceMode: "sqlite-file",
      databaseConfigured: true,
      writesEnabled: true,
      counts: {
        sections: Number(countsRow.sections),
        threads: Number(countsRow.threads),
        replies: Number(countsRow.replies),
        moderationEvents: Number(countsRow.moderation_events),
      },
      generatedAt: new Date().toISOString(),
    };
  };

  const createThread = (input: CreateForumThreadInput): ForumThreadDetail => {
    const section = getSectionBySlug(input.sectionSlug);

    if (!section) {
      throw new ForumInputError(`Forum section "${input.sectionSlug}" does not exist.`);
    }

    const slug = nextThreadSlug(database, input.title);
    const createdAt = new Date().toISOString();
    const openingPost = input.openingPost.filter((paragraph) => paragraph.trim().length > 0);
    const authorRoleLabel = input.authorRoleLabel.trim() || getDefaultThreadRoleLabel(input.sectionSlug);
    const guidanceSignal = input.guidanceSignal.trim() || getDefaultThreadGuidanceSignal(input.sectionSlug);

    if (openingPost.length === 0) {
      throw new ForumInputError("Thread openingPost must contain at least one non-empty paragraph.");
    }

    database.exec("BEGIN");

    try {
      database.prepare(`
        INSERT INTO forum_threads (
          slug,
          section_slug,
          title,
          summary,
          author,
          author_role_label,
          guidance_signal,
          published_at,
          last_activity,
          reply_count,
          follow_count,
          bookmark_count,
          tags_json,
          opening_post_json,
          takeaways_json,
          moderation_state,
          knowledge_stage
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        slug,
        input.sectionSlug,
        input.title,
        input.summary,
        input.author,
        authorRoleLabel,
        guidanceSignal,
        createdAt,
        "刚刚创建",
        0,
        0,
        0,
        JSON.stringify(input.tags),
        JSON.stringify(openingPost),
        JSON.stringify([]),
        "published",
        "discussion",
      );

      database.prepare(`
        INSERT INTO forum_moderation_events (
          id,
          thread_slug,
          reply_id,
          event_type,
          actor_label,
          summary,
          created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run(
        nextModerationEventId(database, slug, "thread-created"),
        slug,
        null,
        "thread-created",
        "系统记录",
        describeThreadCreationSummary(input.sectionSlug),
        createdAt,
      );

      database.exec("COMMIT");
    } catch (error) {
      database.exec("ROLLBACK");
      throw error;
    }

    const createdDetail = getThreadDetailBySlug(slug);

    if (!createdDetail) {
      throw new Error("Created thread could not be reloaded from sqlite storage.");
    }

    return createdDetail;
  };

  const createReply = (input: CreateForumReplyInput): ForumThreadDetail => {
    const thread = getThreadBySlug(input.threadSlug);

    if (!thread) {
      throw new ForumInputError(`Forum thread "${input.threadSlug}" does not exist.`);
    }

    const body = input.body.filter((paragraph) => paragraph.trim().length > 0);
    const roleLabel = input.roleLabel.trim() || getDefaultReplyRoleLabel();
    const guidanceSignal = input.guidanceSignal.trim() || getDefaultReplyGuidanceSignal(thread.sectionSlug);
    const trustSignal = input.trustSignal.trim() || getDefaultReplyTrustSignal();

    if (body.length === 0) {
      throw new ForumInputError("Reply body must contain at least one non-empty paragraph.");
    }

    const replyId = nextReplyId(database, input.threadSlug);
    const createdAt = new Date().toISOString();

    database.exec("BEGIN");

    try {
      database.prepare(`
        INSERT INTO forum_replies (
          id,
          thread_slug,
          author,
          role_label,
          guidance_signal,
          published_at,
          moderation_state,
          trust_signal,
          body_json
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        replyId,
        input.threadSlug,
        input.author,
        roleLabel,
        guidanceSignal,
        createdAt,
        "published",
        trustSignal,
        JSON.stringify(body),
      );

      database.prepare(`
        UPDATE forum_threads
        SET
          reply_count = reply_count + 1,
          last_activity = ?
        WHERE slug = ?
      `).run("刚刚回复", input.threadSlug);

      database.prepare(`
        INSERT INTO forum_moderation_events (
          id,
          thread_slug,
          reply_id,
          event_type,
          actor_label,
          summary,
          created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run(
        nextModerationEventId(database, input.threadSlug, "reply-created"),
        input.threadSlug,
        replyId,
        "reply-created",
        "系统记录",
        describeReplyCreationSummary(thread.sectionSlug),
        createdAt,
      );

      database.exec("COMMIT");
    } catch (error) {
      database.exec("ROLLBACK");
      throw error;
    }

    const updatedDetail = getThreadDetailBySlug(input.threadSlug);

    if (!updatedDetail) {
      throw new Error("Updated thread could not be reloaded from sqlite storage after reply creation.");
    }

    return updatedDetail;
  };

  return {
    dataSource: "sqlite",
    persistenceMode: "sqlite-file",
    getSections,
    getThreads,
    getReplies,
    getModerationEvents,
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
