"use client";

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { normalizeCbetaQuery } from "../lib/faliu-api";

const CBETA_API_ROOT = "https://api.cbetaonline.cn";
const CBETA_PROXY_ROOT = "/api/cbeta";
const MAX_SYNONYM_SUGGESTIONS = 8;
const MIN_QUERY_LENGTH = 2;

type CbetaSynonymResponse = {
  results?: string[];
};

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

function cbetaSynonymUrls(query: string) {
  const params = { q: query };
  return [buildRelativeUrl(CBETA_PROXY_ROOT, "search/synonym", params), buildUrl(CBETA_API_ROOT, "search/synonym", params)];
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

async function fetchCbetaSynonyms(query: string) {
  const terms = Array.from(new Set([query.trim(), normalizeCbetaQuery(query)].filter(Boolean)));
  const blockedTerms = new Set(terms.map((term) => normalizeCbetaQuery(term).toLowerCase()));
  const responses = await Promise.allSettled(
    terms.map((term) => fetchJson<CbetaSynonymResponse>(cbetaSynonymUrls(term))),
  );
  const seen = new Set<string>();
  const suggestions: string[] = [];

  for (const response of responses) {
    if (response.status !== "fulfilled") {
      continue;
    }

    for (const item of response.value.results ?? []) {
      const synonym = item.trim();
      const normalized = normalizeCbetaQuery(synonym).toLowerCase();

      if (!synonym || blockedTerms.has(normalized) || seen.has(normalized)) {
        continue;
      }

      seen.add(normalized);
      suggestions.push(synonym);

      if (suggestions.length >= MAX_SYNONYM_SUGGESTIONS) {
        return suggestions;
      }
    }
  }

  return suggestions;
}

function setNativeInputValue(input: HTMLInputElement, value: string) {
  const descriptor = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value");

  if (descriptor?.set) {
    descriptor.set.call(input, value);
  } else {
    input.value = value;
  }
}

export function FaliuSynonymEnhancer() {
  const [host, setHost] = useState<HTMLFormElement | null>(null);
  const [input, setInput] = useState<HTMLInputElement | null>(null);
  const [query, setQuery] = useState("");
  const [suggestions, setSuggestions] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    const formElement = document.querySelector<HTMLFormElement>('section[aria-label="法流"] form');
    const inputElement = formElement?.querySelector<HTMLInputElement>('input[aria-label="搜索佛典"]');

    if (!formElement || !inputElement) {
      return;
    }

    if (!formElement.style.position) {
      formElement.style.position = "relative";
    }

    const handleInput = () => {
      setQuery(inputElement.value.trim());
    };

    setHost(formElement);
    setInput(inputElement);
    handleInput();
    inputElement.addEventListener("input", handleInput);

    return () => {
      inputElement.removeEventListener("input", handleInput);
    };
  }, []);

  useEffect(() => {
    const nextQuery = query.trim();

    if (nextQuery.length < MIN_QUERY_LENGTH) {
      setSuggestions([]);
      setIsLoading(false);
      return;
    }

    let cancelled = false;
    const timeout = window.setTimeout(() => {
      setIsLoading(true);
      fetchCbetaSynonyms(nextQuery)
        .then((items) => {
          if (!cancelled) {
            setSuggestions(items);
          }
        })
        .catch(() => {
          if (!cancelled) {
            setSuggestions([]);
          }
        })
        .finally(() => {
          if (!cancelled) {
            setIsLoading(false);
          }
        });
    }, 260);

    return () => {
      cancelled = true;
      window.clearTimeout(timeout);
    };
  }, [query]);

  function searchWithSynonym(synonym: string) {
    if (!input || !host) {
      return;
    }

    setSuggestions([]);
    setQuery(synonym);
    setNativeInputValue(input, synonym);
    input.dispatchEvent(new Event("input", { bubbles: true }));
    input.dispatchEvent(new Event("change", { bubbles: true }));

    window.setTimeout(() => {
      if (typeof host.requestSubmit === "function") {
        host.requestSubmit();
      } else {
        host.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
      }
    }, 0);
  }

  if (!host || (!isLoading && suggestions.length === 0)) {
    return null;
  }

  return createPortal(
    <div
      role="listbox"
      aria-label="近义词建议"
      style={{
        position: "absolute",
        top: "calc(100% + 8px)",
        left: 0,
        right: 0,
        zIndex: 30,
        display: "grid",
        gap: 10,
        padding: "12px 14px",
        border: "1px solid rgba(255, 255, 255, 0.14)",
        borderRadius: 14,
        background: "rgba(8, 16, 24, 0.96)",
        boxShadow: "0 18px 46px rgba(0, 0, 0, 0.36)",
        backdropFilter: "blur(14px)",
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          gap: 12,
          color: "rgba(255, 255, 255, 0.64)",
          fontSize: "0.82rem",
          lineHeight: 1.4,
        }}
      >
        <span>近义词建议</span>
        <span>{isLoading ? "正在查找..." : "点击后自动搜索"}</span>
      </div>

      {suggestions.length > 0 ? (
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
          {suggestions.map((item) => (
            <button
              key={item}
              type="button"
              role="option"
              onMouseDown={(event) => event.preventDefault()}
              onClick={() => searchWithSynonym(item)}
              style={{
                minHeight: 34,
                padding: "0 12px",
                border: "1px solid rgba(232, 189, 107, 0.28)",
                borderRadius: 999,
                background: "rgba(232, 189, 107, 0.12)",
                color: "#fff7e3",
                fontWeight: 760,
                cursor: "pointer",
              }}
            >
              {item}
            </button>
          ))}
        </div>
      ) : null}
    </div>,
    host,
  );
}
