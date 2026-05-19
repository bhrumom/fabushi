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
const APP_API_ROOT = "https://api.ombhrum.com";

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

async function fetchJson<T>(url: string): Promise<T> {
  const response = await fetch(url, {
    headers: {
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(`Request failed: ${response.status}`);
  }

  return (await response.json()) as T;
}

export function buildCbetaContentId(work: string, juan: string) {
  return `cbeta:${work}:${juan}`;
}

export async function fetchAllWorks(): Promise<CbetaWorkIndexItem[]> {
  return fetchJson<CbetaWorkIndexItem[]>(buildUrl(CBETA_API_ROOT, "download/all-works.json"));
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
  }>(buildUrl(CBETA_API_ROOT, "search/title", { q: query, start, rows }));

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
  const data = await fetchJson<{ results?: CbetaWorkInfo[] }>(buildUrl(CBETA_API_ROOT, "works", { work }));
  return data.results?.[0] ?? null;
}

export async function fetchJuanDetail(work: string, juan: string): Promise<CbetaJuanDetail | null> {
  const data = await fetchJson<{
    results?: Array<{ html?: string; juan?: string | number }>;
    work_info?: CbetaWorkInfo;
    toc?: { mulu?: CbetaTocNode[]; juan?: CbetaTocNode[] };
  }>(buildUrl(CBETA_API_ROOT, "juans", { work, juan, work_info: 1, toc: 1 }));

  const html = data.results?.[0]?.html;
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

  const response = await fetch(buildUrl(APP_API_ROOT, "api/content/batch-stats"), {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({ contentIds }),
  });

  if (!response.ok) {
    return {};
  }

  const data = (await response.json()) as {
    stats?: Record<string, { likeCount?: number; commentCount?: number }>;
  };

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
  }>(buildUrl(APP_API_ROOT, "api/comments", { contentId, page: 1, pageSize: 30 }));

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
