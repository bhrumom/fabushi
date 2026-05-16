export interface LeaderboardEntry {
  username: string;
  displayName: string;
  avatar: string | null;
  totalBytes: number;
  followerCount: number;
  followingCount: number;
  isFollowing: boolean;
}

export interface LeaderboardResponse {
  leaderboard: LeaderboardEntry[];
  type: "global" | "practice";
  cached?: boolean;
}

export interface VerificationCodePayload {
  email: string;
  type: "register" | "forgot";
}

export interface ForumSectionSummary {
  slug: string;
  titleZh: string;
  titleEn: string;
  summaryZh: string;
  summaryEn: string;
  guidanceZh: string;
  guidanceEn: string;
}

export interface ForumThreadListItem {
  slug: string;
  sectionSlug: string;
  sectionTitleZh: string;
  sectionTitleEn: string;
  titleZh: string;
  titleEn: string;
  summaryZh: string;
  summaryEn: string;
  authorZh: string;
  authorEn: string;
  roleZh: string;
  roleEn: string;
  publishedLabelZh: string;
  publishedLabelEn: string;
  lastActivityZh: string;
  lastActivityEn: string;
  repliesCount: number;
  followsCount: number;
  bookmarksCount: number;
  tagsZh: string[];
  tagsEn: string[];
  featuredReasonZh: string;
  featuredReasonEn: string;
}

export interface ForumThreadDetail extends ForumThreadListItem {
  openingPostZh: string[];
  openingPostEn: string[];
  takeawaysZh: string[];
  takeawaysEn: string[];
  replyPromptsZh: string[];
  replyPromptsEn: string[];
}

export interface ForumThreadsResponse {
  source: "seed";
  generatedAt: string;
  sections: ForumSectionSummary[];
  threads: ForumThreadListItem[];
}

export interface ForumThreadResponse {
  source: "seed";
  generatedAt: string;
  section: ForumSectionSummary | null;
  thread: ForumThreadDetail;
}
