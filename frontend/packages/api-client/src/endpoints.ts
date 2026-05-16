export const API_BASE_URL = process.env.NEXT_PUBLIC_FABUSHI_API_BASE_URL ?? "https://flutter.ombhrum.com";

export const endpoints = {
  health: "/health",
  leaderboard: "/api/leaderboard",
  practiceLeaderboard: "/api/leaderboard/practice",
  login: "/api/auth/login",
  register: "/api/auth/register",
  sendVerificationCode: "/api/auth/send-verification-code",
  userInfo: "/api/auth/user-info",
  forumThreads: "/api/community/threads",
  forumThread: (slug: string) => `/api/community/thread/${encodeURIComponent(slug)}`,
} as const;
