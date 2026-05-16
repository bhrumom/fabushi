import { mkdirSync } from "node:fs";
import path from "node:path";
import { DatabaseSync } from "node:sqlite";
import forumContent from "../data/forum-content.json";
import type {
  CreateForumThreadInput,
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
  published_at: string;
  moderation_state: ForumReply["moderationState"];
  trust_signal: string;
  body_json: string;
}

const seedContent = forumContent as ForumContentStore;
const DEFAULT_DATABASE_URL = "file:./data/forum.db";

function parseJsonArray(value: string): string[] {
  const parsed = JSON.parse(value) as unknown;
  return Array.isArray(parsed) ? parsed.map((item) => String(item)) : [];
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
    roleLabel: row.role_label,
    publishedAt: row.published_at,
    moderationState: row.moderation_state,
    trustSignal: row.trust_signal,
    body: parseJsonArray(row.body_json),
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
      published_at TEXT NOT NULL,
      moderation_state TEXT NOT NULL,
      trust_signal TEXT NOT NULL,
      body_json TEXT NOT NULL,
      FOREIGN KEY (thread_slug) REFERENCES forum_threads(slug)
    );
  `);
}

function seedDatabaseIfEmpty(database: DatabaseSync) {
  const countRow = database.prepare("SELECT COUNT(*) AS count FROM forum_sections").get() as { count: number };

  if (Number(countRow.count) > 0) {
    return;
  }

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
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  const insertReply = database.prepare(`
    INSERT INTO forum_replies (
      id,
      thread_slug,
      author,
      role_label,
      published_at,
      moderation_state,
      trust_signal,
      body_json
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
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

    for (const thread of seedContent.threads) {
      insertThread.run(
        thread.slug,
        thread.sectionSlug,
        thread.title,
        thread.summary,
        thread.author,
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
    }

    for (const reply of seedContent.replies) {
      insertReply.run(
        reply.id,
        reply.threadSlug,
        reply.author,
        reply.roleLabel,
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

export function createSqliteForumRepository(): ForumRepository {
  const databasePath = resolveSqliteDatabasePath(process.env.FORUM_DATABASE_URL?.trim() || DEFAULT_DATABASE_URL);
  ensureDatabaseDirectory(databasePath);

  const database = new DatabaseSync(databasePath);
  database.exec("PRAGMA foreign_keys = ON");
  initializeSchema(database);
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

  const getThreadDetailBySlug = (slug: string): ForumThreadDetail | undefined => {
    const thread = getThreadBySlug(slug);

    if (!thread) {
      return undefined;
    }

    return {
      thread,
      section: getSectionBySlug(thread.sectionSlug),
      replies: getRepliesByThreadSlug(thread.slug),
      source: "sqlite",
      generatedAt: new Date().toISOString(),
    };
  };

  const getSnapshot = (): ForumSnapshot => {
    const sections = getSections();
    const threads = getThreads();
    const replies = getReplies();

    return {
      sections: sections.map((section) => {
        const sectionThreads = threads.filter((thread) => thread.sectionSlug === section.slug);
        const replyCount = sectionThreads.reduce((total, thread) => total + replies.filter((reply) => reply.threadSlug === thread.slug).length, 0);

        return {
          ...section,
          threadCount: sectionThreads.length,
          replyCount,
        };
      }),
      threads,
      replies,
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
          (SELECT COUNT(*) FROM forum_replies) AS replies
      `)
      .get() as { sections: number; threads: number; replies: number };

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

    if (openingPost.length === 0) {
      throw new ForumInputError("Thread openingPost must contain at least one non-empty paragraph.");
    }

    database.prepare(`
      INSERT INTO forum_threads (
        slug,
        section_slug,
        title,
        summary,
        author,
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
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      slug,
      input.sectionSlug,
      input.title,
      input.summary,
      input.author,
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

    const createdDetail = getThreadDetailBySlug(slug);

    if (!createdDetail) {
      throw new Error("Created thread could not be reloaded from sqlite storage.");
    }

    return createdDetail;
  };

  return {
    dataSource: "sqlite",
    persistenceMode: "sqlite-file",
    getSections,
    getThreads,
    getReplies,
    getSectionBySlug,
    getThreadBySlug,
    getThreadsBySection,
    getRepliesByThreadSlug,
    getThreadDetailBySlug,
    getSnapshot,
    getRuntimeStatus,
    createThread,
  };
}
