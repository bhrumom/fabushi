import type {
  ForumSectionSummary,
  ForumThreadDetail,
  ForumThreadListItem,
  ForumThreadResponse,
  ForumThreadsResponse,
} from "@fabushi/api-client";
import {
  FORUM_SECTIONS,
  FORUM_THREADS,
  getForumSectionBySlug,
  getForumThreadBySlug,
} from "./community";

function mapForumSectionSummary(section: (typeof FORUM_SECTIONS)[number]): ForumSectionSummary {
  return {
    slug: section.slug,
    titleZh: section.titleZh,
    titleEn: section.titleEn,
    summaryZh: section.summaryZh,
    summaryEn: section.summaryEn,
    guidanceZh: section.guidanceZh,
    guidanceEn: section.guidanceEn,
  };
}

function mapForumThreadListItem(thread: (typeof FORUM_THREADS)[number]): ForumThreadListItem {
  const section = getForumSectionBySlug(thread.sectionSlug);

  return {
    slug: thread.slug,
    sectionSlug: thread.sectionSlug,
    sectionTitleZh: section?.titleZh ?? thread.sectionSlug,
    sectionTitleEn: section?.titleEn ?? thread.sectionSlug,
    titleZh: thread.titleZh,
    titleEn: thread.titleEn,
    summaryZh: thread.summaryZh,
    summaryEn: thread.summaryEn,
    authorZh: thread.authorZh,
    authorEn: thread.authorEn,
    roleZh: thread.roleZh,
    roleEn: thread.roleEn,
    publishedLabelZh: thread.publishedLabelZh,
    publishedLabelEn: thread.publishedLabelEn,
    lastActivityZh: thread.lastActivityZh,
    lastActivityEn: thread.lastActivityEn,
    repliesCount: thread.repliesCount,
    followsCount: thread.followsCount,
    bookmarksCount: thread.bookmarksCount,
    tagsZh: thread.tagsZh,
    tagsEn: thread.tagsEn,
    featuredReasonZh: thread.featuredReasonZh,
    featuredReasonEn: thread.featuredReasonEn,
  };
}

function mapForumThreadDetail(thread: (typeof FORUM_THREADS)[number]): ForumThreadDetail {
  return {
    ...mapForumThreadListItem(thread),
    openingPostZh: thread.openingPostZh,
    openingPostEn: thread.openingPostEn,
    takeawaysZh: thread.takeawaysZh,
    takeawaysEn: thread.takeawaysEn,
    replyPromptsZh: thread.replyPromptsZh,
    replyPromptsEn: thread.replyPromptsEn,
  };
}

export function getForumSectionSummaries(): ForumSectionSummary[] {
  return FORUM_SECTIONS.map(mapForumSectionSummary);
}

export function getForumThreadListItems(): ForumThreadListItem[] {
  return FORUM_THREADS.map(mapForumThreadListItem);
}

export function getForumThreadsResponse(): ForumThreadsResponse {
  return {
    source: "seed",
    generatedAt: new Date().toISOString(),
    sections: getForumSectionSummaries(),
    threads: getForumThreadListItems(),
  };
}

export function getForumThreadResponse(slug: string): ForumThreadResponse | null {
  const thread = getForumThreadBySlug(slug);

  if (!thread) {
    return null;
  }

  const section = getForumSectionBySlug(thread.sectionSlug);

  return {
    source: "seed",
    generatedAt: new Date().toISOString(),
    section: section ? mapForumSectionSummary(section) : null,
    thread: mapForumThreadDetail(thread),
  };
}
