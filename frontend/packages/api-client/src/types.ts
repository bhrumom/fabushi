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
