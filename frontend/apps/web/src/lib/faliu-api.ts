export interface CbetaWorkIndexItem {
  work: string;
  title: string;
  juans: string[];
}

export interface CbetaWorkInfo {
  work: string;
  category?: string;
  orig_category?: string;
  title: string;
  byline?: string;
  creators?: string;
  time_dynasty?: string;
  time_from?: number | null;
  time_to?: number | null;
  juan?: number;
  juan_start?: number;
  juan_end?: number;
}

export interface CbetaTocNode {
  title?: string;
  juan?: string | number;
  lb?: string;
  file?: string;
  type?: string;
  n?: string | number;
  isFolder?: boolean;
  children?: CbetaTocNode[];
}

export interface CbetaJuanDetail {
  work: string;
  juan: string;
  html: string;
  title: string;
  byline?: string;
  category?: string;
  toc: CbetaTocNode[];
  totalJuans: string[];
}

export interface ContentStats {
  likeCount: number;
  commentCount: number;
}

export interface AppComment {
  id: number;
  contentId: string;
  content: string;
  createdAt: string;
  parentId?: number | null;
  likeCount: number;
  username?: string | null;
  nickname?: string | null;
  avatar?: string | null;
  mainPractice?: string | null;
}

const CBETA_API_ROOT = "https://cbdata.dila.edu.tw/stable";
const APP_API_ROOT = "https://api.ombhrum.com/api";
const CBETA_PROXY_ROOT = "/api/cbeta";
const APP_PROXY_ROOT = "/api/app";

function buildUrl(base: string, path: string, params?: Record<string, string | number | undefined>) {
  const url = new URL(path, `${base}/`);

  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value === undefined || value === null || value === "") {
        continue;
      }

      url.searchParams.set(key, String(value));
    }
  }

  return url.toString();
}

function buildRelativeUrl(base: string, path: string, params?: Record<string, string | number | undefined>) {
  const normalizedBase = base.replace(/\/+$/g, "");
  const normalizedPath = path.replace(/^\/+/g, "");
  const query = new URLSearchParams();

  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value === undefined || value === null || value === "") {
        continue;
      }

      query.set(key, String(value));
    }
  }

  const suffix = query.toString();
  return `${normalizedBase}/${normalizedPath}${suffix ? `?${suffix}` : ""}`;
}

function isBrowserRuntime() {
  return typeof window !== "undefined";
}

function cbetaUrls(path: string, params?: Record<string, string | number | undefined>) {
  const directUrl = buildUrl(CBETA_API_ROOT, path, params);

  if (!isBrowserRuntime()) {
    return [directUrl];
  }

  return [buildRelativeUrl(CBETA_PROXY_ROOT, path, params), directUrl];
}

function appUrls(path: string, params?: Record<string, string | number | undefined>) {
  const directUrl = buildUrl(APP_API_ROOT, path, params);

  if (!isBrowserRuntime()) {
    return [directUrl];
  }

  return [buildRelativeUrl(APP_PROXY_ROOT, path, params), directUrl];
}

async function fetchJson<T>(urls: string | string[]): Promise<T> {
  const candidates = Array.isArray(urls) ? urls : [urls];
  let lastError: unknown = null;

  for (const url of candidates) {
    try {
      const response = await fetch(url, {
        headers: {
          Accept: "application/json",
        },
      });

      if (!response.ok) {
        lastError = new Error(`Request failed: ${response.status}`);
        continue;
      }

      return (await response.json()) as T;
    } catch (cause) {
      lastError = cause;
    }
  }

  if (lastError instanceof Error) {
    throw lastError;
  }

  throw new Error("Request failed");
}

async function postJson<T>(urls: string | string[], body: unknown): Promise<T> {
  const candidates = Array.isArray(urls) ? urls : [urls];
  let lastError: unknown = null;

  for (const url of candidates) {
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify(body),
      });

      if (!response.ok) {
        lastError = new Error(`Request failed: ${response.status}`);
        continue;
      }

      return (await response.json()) as T;
    } catch (cause) {
      lastError = cause;
    }
  }

  if (lastError instanceof Error) {
    throw lastError;
  }

  throw new Error("Request failed");
}

export function buildCbetaContentId(work: string, juan: string) {
  return `cbeta:${work}:${juan}`;
}

export async function fetchAllWorks(): Promise<CbetaWorkIndexItem[]> {
  return fetchJson<CbetaWorkIndexItem[]>(cbetaUrls("download/all-works.json"));
}

export async function searchWorksByTitle(query: string, start = 0, rows = 24): Promise<CbetaWorkInfo[]> {
  const data = await fetchJson<{
    results?: Array<{
      work?: string;
      content?: string;
      byline?: string;
      juan?: number;
      time_dynasty?: string;
    }>;
  }>(cbetaUrls("search/title", { q: query, start, rows }));

  return (data.results ?? []).flatMap((item) => {
    if (!item.work || !item.content) {
      return [];
    }

    return [
      {
        work: item.work,
        title: item.content,
        byline: item.byline,
        juan: item.juan,
        time_dynasty: item.time_dynasty,
      },
    ];
  });
}

export async function fetchWorkInfo(work: string): Promise<CbetaWorkInfo | null> {
  const data = await fetchJson<{ results?: CbetaWorkInfo[] }>(cbetaUrls("works", { work }));
  return data.results?.[0] ?? null;
}

export async function fetchJuanDetail(work: string, juan: string): Promise<CbetaJuanDetail | null> {
  const data = await fetchJson<{
    results?: Array<string | { html?: string; juan?: string | number }>;
    work_info?: CbetaWorkInfo;
    toc?: { mulu?: CbetaTocNode[]; juan?: CbetaTocNode[] };
  }>(cbetaUrls("juans", { work, juan, work_info: 1, toc: 1 }));

  const firstResult = data.results?.[0];
  const html = typeof firstResult === "string" ? firstResult : firstResult?.html;
  const workInfo = data.work_info;

  if (!html || !workInfo) {
    return null;
  }

  return {
    work,
    juan,
    html,
    title: workInfo.title,
    byline: workInfo.byline,
    category: workInfo.category,
    toc: [...(data.toc?.juan ?? []), ...(data.toc?.mulu ?? [])],
    totalJuans: [],
  };
}

export async function fetchBatchStats(contentIds: string[]): Promise<Record<string, ContentStats>> {
  if (contentIds.length === 0) {
    return {};
  }

  const data = await postJson<{
    stats?: Record<string, { likeCount?: number; commentCount?: number }>;
  }>(appUrls("content/batch-stats"), { contentIds });

  const entries = Object.entries(data.stats ?? {});
  const mapped: Record<string, ContentStats> = {};

  for (const [contentId, value] of entries) {
    mapped[contentId] = {
      likeCount: value.likeCount ?? 0,
      commentCount: value.commentCount ?? 0,
    };
  }

  return mapped;
}

export async function fetchComments(contentId: string): Promise<AppComment[]> {
  const data = await fetchJson<{
    comments?: Array<{
      id: number;
      content_id?: string;
      video_id?: string;
      content?: string;
      created_at?: string;
      parent_id?: number | null;
      like_count?: number;
      username?: string | null;
      nickname?: string | null;
      avatar?: string | null;
      main_practice?: string | null;
    }>;
  }>(appUrls("comments", { contentId, page: 1, pageSize: 30 }));

  return (data.comments ?? []).map((item) => ({
    id: item.id,
    contentId: item.content_id ?? item.video_id ?? contentId,
    content: item.content ?? "",
    createdAt: item.created_at ?? "",
    parentId: item.parent_id,
    likeCount: item.like_count ?? 0,
    username: item.username,
    nickname: item.nickname,
    avatar: item.avatar,
    mainPractice: item.main_practice,
  }));
}
