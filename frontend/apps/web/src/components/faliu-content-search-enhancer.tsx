"use client";

import { useEffect, useMemo, useState } from "react";
import { createPortal } from "react-dom";
import { searchWorksByContent, type CbetaContentSearchResult } from "../lib/faliu-content-search";

const MIN_QUERY_LENGTH = 2;
const CONTENT_ROWS = 12;

function getSearchInput() {
  return document.querySelector<HTMLInputElement>('section[aria-label="法流"] input[aria-label="搜索佛典"]');
}

function getMainPane() {
  return document.querySelector<HTMLElement>('section[aria-label="法流"] > div');
}

function getFeedGrid() {
  return document.querySelector<HTMLElement>('section[aria-label="法流"] div[class*="feedGrid"]');
}

function getCurrentQuery(fallback = "") {
  const input = getSearchInput();

  if (input?.value.trim()) {
    return input.value.trim();
  }

  return new URLSearchParams(window.location.search).get("q")?.trim() ?? fallback;
}

function hasVisibleTitleCards() {
  return (getFeedGrid()?.querySelectorAll("article").length ?? 0) > 0;
}

export function FaliuContentSearchEnhancer() {
  const [query, setQuery] = useState("");
  const [host, setHost] = useState<HTMLElement | null>(null);
  const [results, setResults] = useState<CbetaContentSearchResult[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [shouldShowFallback, setShouldShowFallback] = useState(false);

  useEffect(() => {
    const mainPane = getMainPane();
    const input = getSearchInput();

    if (!mainPane || !input) {
      return;
    }

    const syncState = () => {
      setHost(mainPane);
      setQuery(getCurrentQuery());
      window.setTimeout(() => setShouldShowFallback(!hasVisibleTitleCards()), 340);
    };

    const observer = new MutationObserver(() => {
      window.setTimeout(() => setShouldShowFallback(!hasVisibleTitleCards()), 60);
    });

    observer.observe(mainPane, { childList: true, subtree: true });
    input.addEventListener("input", syncState);
    input.form?.addEventListener("submit", syncState);
    window.addEventListener("popstate", syncState);
    syncState();

    return () => {
      observer.disconnect();
      input.removeEventListener("input", syncState);
      input.form?.removeEventListener("submit", syncState);
      window.removeEventListener("popstate", syncState);
    };
  }, []);

  useEffect(() => {
    const nextQuery = query.trim();

    if (nextQuery.length < MIN_QUERY_LENGTH) {
      setResults([]);
      setIsLoading(false);
      return;
    }

    let cancelled = false;
    const timeout = window.setTimeout(() => {
      setIsLoading(true);
      searchWorksByContent(nextQuery, 0, CONTENT_ROWS)
        .then((items) => {
          if (!cancelled) {
            setResults(items);
          }
        })
        .catch(() => {
          if (!cancelled) {
            setResults([]);
          }
        })
        .finally(() => {
          if (!cancelled) {
            setIsLoading(false);
          }
        });
    }, 420);

    return () => {
      cancelled = true;
      window.clearTimeout(timeout);
    };
  }, [query]);

  const visibleResults = useMemo(() => results.slice(0, CONTENT_ROWS), [results]);

  if (!host || query.trim().length < MIN_QUERY_LENGTH || (!shouldShowFallback && !isLoading)) {
    return null;
  }

  return createPortal(
    <section
      aria-label="正文搜索结果"
      style={{
        margin: "0 0 24px",
        padding: "18px",
        border: "1px solid rgba(255, 255, 255, 0.1)",
        borderRadius: 14,
        background: "rgba(255, 255, 255, 0.045)",
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "baseline",
          justifyContent: "space-between",
          gap: 12,
          marginBottom: 16,
        }}
      >
        <div>
          <strong style={{ color: "#ffffff", fontSize: "1rem" }}>标题未命中，正在搜索正文</strong>
          <p style={{ margin: "6px 0 0", color: "rgba(255, 255, 255, 0.58)", lineHeight: 1.5 }}>
            下面显示的是正文命中的片段，片段放在卡片图片下方，方便确认搜到了什么内容。
          </p>
        </div>
        <span style={{ color: "rgba(255, 255, 255, 0.54)", fontSize: "0.86rem" }}>
          {isLoading ? "搜索中..." : `${visibleResults.length} 条`}
        </span>
      </div>

      {visibleResults.length > 0 ? (
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
            gap: "22px 18px",
          }}
        >
          {visibleResults.map((item) => (
            <article key={`${item.work}:${item.juan}:${item.matchSnippet}`} style={{ minWidth: 0 }}>
              <div
                style={{
                  position: "relative",
                  display: "grid",
                  placeItems: "center",
                  aspectRatio: "16 / 9",
                  overflow: "hidden",
                  borderRadius: 8,
                  background:
                    "linear-gradient(135deg, rgba(25, 228, 220, 0.26), transparent 48%), linear-gradient(180deg, #142735, #0d1622)",
                  boxShadow: "0 18px 42px rgba(0, 0, 0, 0.3)",
                  color: "#f5fbff",
                  textAlign: "center",
                  padding: 18,
                }}
              >
                <div style={{ display: "grid", gap: 8 }}>
                  <span style={{ color: "#e8bd6b", fontWeight: 900, fontSize: "0.86rem" }}>{item.work}</span>
                  <h2
                    style={{
                      display: "-webkit-box",
                      WebkitLineClamp: 2,
                      WebkitBoxOrient: "vertical",
                      margin: 0,
                      overflow: "hidden",
                      fontFamily: '"Noto Serif SC", "Songti SC", serif',
                      fontSize: "clamp(1.25rem, 2vw, 1.9rem)",
                      lineHeight: 1.16,
                    }}
                  >
                    {item.title}
                  </h2>
                  <span style={{ color: "rgba(255, 255, 255, 0.7)", fontSize: "0.86rem" }}>第 {item.juan ?? 1} 卷</span>
                </div>
              </div>

              <p style={{ margin: "12px 0 0", color: "rgba(255, 255, 255, 0.94)", fontWeight: 780, lineHeight: 1.42 }}>
                {item.title}
              </p>
              <p style={{ margin: "8px 0 0", color: "rgba(255, 255, 255, 0.56)", fontSize: "0.9rem", lineHeight: 1.6 }}>
                正文命中：{item.matchSnippet}
              </p>
            </article>
          ))}
        </div>
      ) : !isLoading ? (
        <p style={{ margin: 0, color: "rgba(255, 255, 255, 0.58)", lineHeight: 1.65 }}>
          正文也暂时没有找到匹配片段。
        </p>
      ) : null}
    </section>,
    host,
  );
}
