const env = typeof process !== "undefined" ? process.env : (globalThis as any).process?.env;

// Packaged clients use the production Mahayana Platform control-plane origin.
// Development may override this to the workers.dev deployment through the same
// MAHAYANA/Fabushi API environment used by the native FeatureHost.
export const API_BASE_URL =
  env?.NEXT_PUBLIC_MAHAYANA_API_BASE_URL ??
  env?.NEXT_PUBLIC_FABUSHI_API_BASE_URL ??
  "https://api.ombhrum.com";

export const endpoints = {
  health: "/health",

  // Canonical browser-first account flow. Login proves identity only; durable
  // provider capabilities are connected separately after authentication.
  browserAuthStart: "/api/auth/browser/start",
  browserAuthAttempt: (attemptId: string) =>
    `/api/auth/browser/attempts/${encodeURIComponent(attemptId)}`,
  browserAuthCancel: (attemptId: string) =>
    `/api/auth/browser/attempts/${encodeURIComponent(attemptId)}/cancel`,
  browserAuthReopen: (attemptId: string) =>
    `/api/auth/browser/attempts/${encodeURIComponent(attemptId)}/reopen`,
  oauthProviders: "/api/auth/oauth/providers",
  authRefresh: "/api/auth/refresh",
  authUserInfo: "/api/auth/user-info",
  authLogout: "/api/auth/logout",
  authJwks: "/v1/auth/jwks.json",

  aiUsage: "/v1/ai/usage",
  workspaces: "/v1/workspaces",
  conversations: "/v1/conversations",
  directConversation: "/v1/conversations/direct",
  conversationMessages: (conversationId: string) =>
    `/v1/conversations/${encodeURIComponent(conversationId)}/messages`,
  marketplacePlugins: "/v1/marketplace/plugins",
  purchases: "/v1/purchases",

  // Compatibility only. New UI must use browserAuthStart rather than creating
  // additional direct-login flows.
  login: "/api/auth/login",
  register: "/api/auth/browser/portal?mode=register",
  userInfo: "/api/auth/user-info",
  forumThreads: "/api/community/threads",
  forumThread: (slug: string) => `/api/community/thread/${encodeURIComponent(slug)}`,
} as const;
