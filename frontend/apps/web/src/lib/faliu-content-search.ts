import { normalizeCbetaQuery, type CbetaWorkInfo } from "./faliu-api";

const CBETA_API_ROOT = "https://api.cbetaonline.cn";
const CBETA_PROXY_ROOT = "/api/cbeta";
const CONTENT_SEARCH_ENDPOINTS = ["search/fulltext", "search/content", "search/all_in_one"] as const;

export interface CbetaContentSearchResult extends CbetaWorkInfo {
  matchSnippet: string;
  matchSource: "content";
}

type RawContentResult = Record<string, unknown>;

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

async function fetchJson<T>(urls: string[]): Promise<T> {
  let lastError: unknown = null;

  for (const url of urls) {
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

function getString(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function getNumber(value: unknown) {
  if (typeof value === "number") {
    return value;
  }

  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }

  return undefined;
}

function stripSearchHtml(value: string) {
  return value
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
}

function trimSnippet(value: string) {
  const normalized = stripSearchHtml(value);

  if (normalized.length <= 90) {
    return normalized;
  }

  return `${normalized.slice(0, 90)}...`;
}

function collectResults(data: unknown): RawContentResult[] {
  const value = data as Record<string, unknown> | null;

  if (!value || typeof value !== "object") {
    return [];
  }

  const directResults = value.results;
  if (Array.isArray(directResults)) {
    return directResults.filter((item): item is RawContentResult => Boolean(item) && typeof item === "object");
  }

  const nestedResults = directResults as Record<string, unknown> | null;
  if (nestedResults && Array.isArray(nestedResults.docs)) {
    return nestedResults.docs.filter((item): item is RawContentResult => Boolean(item) && typeof item === "object");
  }

  const response = value.response as Record<string, unknown> | null;
  if (response && Array.isArray(response.docs)) {
    return response.docs.filter((item): item is RawContentResult => Boolean(item) && typeof item === "object");
  }

  const docs = value.docs;
  if (Array.isArray(docs)) {
    return docs.filter((item): item is RawContentResult => Boolean(item) && typeof item === "object");
  }

  return [];
}

function pickFirstString(item: RawContentResult, keys: string[]) {
  for (const key of keys) {
    const value = item[key];

    if (Array.isArray(value)) {
      const first = value.map(getString).find(Boolean);
      if (first) {
        return first;
      }
    }

    const stringValue = getString(value);
    if (stringValue) {
      return stringValue;
    }
  }

  return "";
}

function pickFirstNumber(item: RawContentResult, keys: string[]) {
  for (const key of keys) {
    const numberValue = getNumber(item[key]);
    if (numberValue !== undefined) {
      return numberValue;
    }
  }

  return undefined;
}

function normalizeContentResult(item: RawContentResult): CbetaContentSearchResult | null {
  const work = pickFirstString(item, ["work", "work_id", "workId", "sutra", "id"]);
  const snippet = trimSnippet(
    pickFirstString(item, ["kwic", "highlight", "snippet", "content", "text", "body", "p", "linehead"]),
  );

  if (!work || !snippet) {
    return null;
  }

  const title = pickFirstString(item, ["title", "work_title", "workTitle", "sutra_name", "book", "name"]) || work;
  const juan = pickFirstNumber(item, ["juan", "juan_num", "juanNum", "卷"]) ?? 1;

  return {
    work,
    title,
    byline: pickFirstString(item, ["byline", "creators", "creator"]),
    creators: pickFirstString(item, ["creators", "creator"]),
    time_dynasty: pickFirstString(item, ["time_dynasty", "dynasty"]),
    juan,
    matchSnippet: snippet,
    matchSource: "content",
  };
}

export async function searchWorksByContent(query: string, start = 0, rows = 24): Promise<CbetaContentSearchResult[]> {
  const terms = Array.from(new Set([query.trim(), normalizeCbetaQuery(query)].filter(Boolean)));
  const requests = terms.flatMap((term) =>
    CONTENT_SEARCH_ENDPOINTS.map((endpoint) =>
      fetchJson<unknown>(cbetaUrls(endpoint, { q: term, start, rows, field: "content" })),
    ),
  );
  const responses = await Promise.allSettled(requests);
  const seen = new Set<string>();
  const results: CbetaContentSearchResult[] = [];

  for (const response of responses) {
    if (response.status !== "fulfilled") {
      continue;
    }

    for (const item of collectResults(response.value)) {
      const normalized = normalizeContentResult(item);

      if (!normalized) {
        continue;
      }

      const key = `${normalized.work}:${normalized.juan ?? 1}:${normalized.matchSnippet}`;
      if (seen.has(key)) {
        continue;
      }

      seen.add(key);
      results.push(normalized);

      if (results.length >= rows) {
        return results;
      }
    }
  }

  return results;
}
