"use client";

import type { CSSProperties } from "react";
import { useDeferredValue, useEffect, useMemo, useState } from "react";
import { LocalizedText } from "./localized-text";
import { siteHref } from "../lib/site-url";
import { CARD_LIMIT, FALIU_TABS, type FaliuTabKey } from "../lib/faliu-config";
import {
  buildCbetaContentId,
  fetchAllWorks,
  fetchBatchStats,
  fetchComments,
  fetchJuanDetail,
  fetchWorkInfo,
  searchWorksByTitle,
  type AppComment,
  type CbetaJuanDetail,
  type CbetaWorkIndexItem,
  type CbetaWorkInfo,
  type ContentStats,
} from "../lib/faliu-api";
import styles from "./faliu-shell.module.css";

export interface FaliuInitialData {
  initialWorks?: CbetaWorkIndexItem[];
  initialWorkInfo?: Record<string, CbetaWorkInfo | null>;
  initialStats?: Record<string, ContentStats>;
}

interface WorkCardItem {
  work: string;
  title: string;
  juans: string[];
  info?: CbetaWorkInfo | null;
}

const SIDE_NAV_ITEMS = [
  { href: "/faliu", labelZh: "精选", labelEn: "Featured", mark: "法", active: true },
  { href: "/sutra-guide", labelZh: "推荐", labelEn: "Guide", mark: "荐" },
  { href: "/sutra-listening", labelZh: "听经", labelEn: "Listen", mark: "听" },
  { href: "/daily-practice", labelZh: "修行", labelEn: "Practice", mark: "修" },
  { href: "/community", labelZh: "社区", labelEn: "Community", mark: "众" },
  { href: "/download", labelZh: "下载", labelEn: "Download", mark: "下" },
] as const;

const TOP_ACTIONS = [
  { href: "/download", labelZh: "客户端", labelEn: "App", mark: "下" },
  { href: "/faq", labelZh: "说明", labelEn: "FAQ", mark: "问" },
  { href: "/contact", labelZh: "联系", labelEn: "Contact", mark: "信" },
] as const;

const COVER_PALETTES = [
  { a: "#13251f", b: "#d4a64a", c: "#f4efe1", ink: "#fff8e7" },
  { a: "#182236", b: "#3fb7a4", c: "#f1c15d", ink: "#f8fbff" },
  { a: "#2a1817", b: "#c45844", c: "#f7d17a", ink: "#fff4e8" },
  { a: "#142735", b: "#77c0d8", c: "#e8bd6b", ink: "#f5fbff" },
  { a: "#261c2b", b: "#9bc27f", c: "#f0d36c", ink: "#fff7ee" },
  { a: "#1e2419", b: "#d78b56", c: "#b8d9ce", ink: "#fff9ed" },
];

function dedupeWorks(items: CbetaWorkIndexItem[]) {
  const seen = new Set<string>();
  const next: CbetaWorkIndexItem[] = [];

  for (const item of items) {
    if (seen.has(item.work)) {
      continue;
    }

    seen.add(item.work);
    next.push(item);
  }

  return next;
}

function normalizeWorkCard(item: CbetaWorkIndexItem, info?: CbetaWorkInfo | null): WorkCardItem {
  return {
    work: item.work,
    title: stripTags(info?.title ?? item.title),
    juans: item.juans,
    info,
  };
}

function flattenVisibleJuans(items: CbetaWorkIndexItem[]) {
  return items.map((item) => ({
    contentId: buildCbetaContentId(item.work, item.juans[0] ?? "1"),
    work: item.work,
    juan: item.juans[0] ?? "1",
  }));
}

function stripTags(value: string) {
  return value.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
}

function formatStats(value: number) {
  if (value >= 10000) {
    return `${(value / 10000).toFixed(1)}万`;
  }

  return `${value}`;
}

function formatCommentDate(value: string) {
  if (!value) {
    return "";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toISOString().slice(0, 10);
}

function getHash(value: string) {
  let hash = 0;

  for (let index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.charCodeAt(index)) >>> 0;
  }

  return hash;
}

function getByline(info?: CbetaWorkInfo | null) {
  return stripTags(info?.byline ?? info?.creators ?? "CBETA 佛典") || "CBETA 佛典";
}

function getTranslator(info?: CbetaWorkInfo | null) {
  const creators = stripTags(info?.creators ?? "");

  if (creators) {
    return creators.endsWith("譯") || creators.endsWith("译") ? creators : `${creators} 譯`;
  }

  const byline = stripTags(info?.byline ?? "");
  return byline || "譯者見 CBETA";
}

function getCoverStyle(item: WorkCardItem): CSSProperties {
  const seed = getHash(`${item.title}:${getTranslator(item.info)}:${item.work}`);
  const palette = COVER_PALETTES[seed % COVER_PALETTES.length];
  const angle = 128 + (seed % 42);

  return {
    "--cover-a": palette.a,
    "--cover-b": palette.b,
    "--cover-c": palette.c,
    "--cover-ink": palette.ink,
    "--cover-angle": `${angle}deg`,
  } as CSSProperties;
}

function getCategoryLabel(info?: CbetaWorkInfo | null, fallback?: string) {
  const category = stripTags(info?.category ?? info?.orig_category ?? "");
  return category ? category.split(/[，,]/)[0] : fallback ?? "CBETA";
}

export function FaliuShell({
  initialWorks = [],
  initialWorkInfo = {},
  initialStats = {},
}: FaliuInitialData) {
  const [activeTab, setActiveTab] = useState<FaliuTabKey>("all");
  const [works, setWorks] = useState<CbetaWorkIndexItem[]>(initialWorks);
  const [workInfoMap, setWorkInfoMap] = useState<Record<string, CbetaWorkInfo | null>>(initialWorkInfo);
  const [statsMap, setStatsMap] = useState<Record<string, ContentStats>>(initialStats);
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState<WorkCardItem | null>(null);
  const [selectedDetail, setSelectedDetail] = useState<CbetaJuanDetail | null>(null);
  const [selectedComments, setSelectedComments] = useState<AppComment[]>([]);
  const [selectedJuan, setSelectedJuan] = useState("1");
  const [isBootLoading, setIsBootLoading] = useState(initialWorks.length === 0);
  const [isSearchLoading, setIsSearchLoading] = useState(false);
  const [isDetailLoading, setIsDetailLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const deferredQuery = useDeferredValue(query.trim());

  useEffect(() => {
    let cancelled = false;

    async function bootstrap() {
      try {
        if (works.length === 0) {
          setIsBootLoading(true);
        }

        const allWorks = await fetchAllWorks();

        if (cancelled) {
          return;
        }

        setWorks((current) => dedupeWorks([...current, ...allWorks]));
        setError(null);
      } catch (cause) {
        if (cancelled || works.length > 0) {
          return;
        }

        const message = cause instanceof Error ? cause.message : "法流数据加载失败";
        setError(message);
      } finally {
        if (!cancelled) {
          setIsBootLoading(false);
        }
      }
    }

    void bootstrap();

    return () => {
      cancelled = true;
    };
  }, []);

  const activeTabConfig = FALIU_TABS.find((item) => item.key === activeTab) ?? FALIU_TABS[0];

  const filteredWorks = useMemo(() => {
    if (works.length === 0) {
      return [];
    }

    if (deferredQuery.length >= 2) {
      const lowered = deferredQuery.toLowerCase();
      return works
        .filter((item) => item.title.toLowerCase().includes(lowered) || item.work.toLowerCase().includes(lowered))
        .slice(0, CARD_LIMIT);
    }

    if (activeTabConfig.featured.length > 0) {
      const set = new Set(activeTabConfig.featured);
      return works.filter((item) => set.has(item.work)).slice(0, CARD_LIMIT);
    }

    const matched = works.filter((item) => activeTabConfig.tokens.some((token) => item.title.includes(token)));
    return matched.slice(0, CARD_LIMIT);
  }, [activeTabConfig, deferredQuery, works]);

  useEffect(() => {
    let cancelled = false;

    async function hydrateCards() {
      if (filteredWorks.length === 0) {
        return;
      }

      const missing = filteredWorks.filter((item) => !(item.work in workInfoMap));
      const visibleJuans = flattenVisibleJuans(filteredWorks);
      const missingContentIds = visibleJuans.filter((item) => !(item.contentId in statsMap));

      if (missing.length === 0 && missingContentIds.length === 0) {
        return;
      }

      try {
        const [infos, stats] = await Promise.all([
          missing.length > 0 ? Promise.all(missing.map((item) => fetchWorkInfo(item.work))) : Promise.resolve([]),
          missingContentIds.length > 0
            ? fetchBatchStats(missingContentIds.map((item) => item.contentId))
            : Promise.resolve({}),
        ]);

        if (cancelled) {
          return;
        }

        if (infos.length > 0) {
          setWorkInfoMap((current) => {
            const next = { ...current };
            for (let index = 0; index < missing.length; index += 1) {
              next[missing[index].work] = infos[index];
            }
            return next;
          });
        }

        if (Object.keys(stats).length > 0) {
          setStatsMap((current) => ({ ...current, ...stats }));
        }
      } catch {
        if (!cancelled) {
          setError("部分法流数据暂时没能补齐，请稍后再试。");
        }
      }
    }

    void hydrateCards();

    return () => {
      cancelled = true;
    };
  }, [filteredWorks, statsMap, workInfoMap]);

  useEffect(() => {
    if (deferredQuery.length < 3) {
      setIsSearchLoading(false);
      return;
    }

    let cancelled = false;

    async function runRemoteSearch() {
      try {
        setIsSearchLoading(true);
        const results = await searchWorksByTitle(deferredQuery, 0, CARD_LIMIT);

        if (cancelled) {
          return;
        }

        const normalized = dedupeWorks(
          results.map((item) => ({
            work: item.work,
            title: stripTags(item.title),
            juans: [String(item.juan ?? 1)],
          })),
        );

        setWorks((current) => dedupeWorks([...normalized, ...current]));
        setWorkInfoMap((current) => {
          const next = { ...current };
          for (const item of results) {
            next[item.work] = item;
          }
          return next;
        });
      } catch {
        if (!cancelled) {
          setError("搜索暂时失败，请稍后再试。");
        }
      } finally {
        if (!cancelled) {
          setIsSearchLoading(false);
        }
      }
    }

    void runRemoteSearch();

    return () => {
      cancelled = true;
    };
  }, [deferredQuery]);

  const visibleCards = useMemo(
    () => filteredWorks.map((item) => normalizeWorkCard(item, workInfoMap[item.work])),
    [filteredWorks, workInfoMap],
  );

  async function openDetail(item: WorkCardItem, juan: string) {
    setSelected(item);
    setSelectedJuan(juan);
    setIsDetailLoading(true);
    setSelectedDetail(null);
    setSelectedComments([]);

    try {
      const contentId = buildCbetaContentId(item.work, juan);
      const [detail, comments, stats] = await Promise.all([
        fetchJuanDetail(item.work, juan),
        fetchComments(contentId),
        fetchBatchStats([contentId]),
      ]);

      setSelectedDetail(detail);
      setSelectedComments(comments);
      setStatsMap((current) => ({ ...current, ...stats }));
      setError(null);
    } catch {
      setSelectedDetail(null);
      setError("正文载入失败，请稍后重试。");
    } finally {
      setIsDetailLoading(false);
    }
  }

  const selectedStats = selected
    ? statsMap[buildCbetaContentId(selected.work, selectedJuan)] ?? { likeCount: 0, commentCount: 0 }
    : { likeCount: 0, commentCount: 0 };

  return (
    <section className={styles.appShell} aria-label="法流">
      <aside className={styles.sidebar}>
        <a className={styles.brand} href={siteHref("/")}>
          <span className={styles.brandMark}>法</span>
          <span>
            <strong>
              <LocalizedText zh="法布施" en="Fabushi" />
            </strong>
            <small>
              <LocalizedText zh="CBETA 法流" en="CBETA Faloo" />
            </small>
          </span>
        </a>

        <nav className={styles.sideNav} aria-label="法流导航">
          {SIDE_NAV_ITEMS.map((item) => (
            <a
              key={item.href}
              className={"active" in item && item.active ? styles.activeSideItem : styles.sideItem}
              href={siteHref(item.href)}
            >
              <span aria-hidden="true">{item.mark}</span>
              <LocalizedText zh={item.labelZh} en={item.labelEn} />
            </a>
          ))}
        </nav>

        <a className={styles.installPanel} href={siteHref("/download")}>
          <span className={styles.installMark}>法</span>
          <span>
            <strong>
              <LocalizedText zh="下载 APP" en="Download App" />
            </strong>
            <small>
              <LocalizedText zh="手机随时看更方便" en="Read anywhere" />
            </small>
          </span>
        </a>
      </aside>

      <div className={styles.mainPane}>
        <header className={styles.topbar}>
          <form className={styles.searchBox} onSubmit={(event) => event.preventDefault()}>
            <span className={styles.searchGlyph} aria-hidden="true" />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="搜索你感兴趣的经名"
              aria-label="搜索佛典"
            />
            <button type="submit">
              <LocalizedText zh="搜索" en="Search" />
            </button>
          </form>

          <div className={styles.actionRow}>
            {TOP_ACTIONS.map((item) => (
              <a key={item.href} className={styles.actionButton} href={siteHref(item.href)}>
                <span aria-hidden="true">{item.mark}</span>
                <small>
                  <LocalizedText zh={item.labelZh} en={item.labelEn} />
                </small>
              </a>
            ))}
          </div>
        </header>

        <div className={styles.tabRow} role="tablist" aria-label="法流分类">
          {FALIU_TABS.map((item) => {
            const isActive = item.key === activeTab;
            return (
              <button
                key={item.key}
                type="button"
                role="tab"
                aria-selected={isActive}
                className={isActive ? styles.activeTab : styles.tab}
                onClick={() => {
                  setActiveTab(item.key);
                  setQuery("");
                }}
              >
                <LocalizedText zh={item.labelZh} en={item.labelEn} />
              </button>
            );
          })}
        </div>

        {error ? <p className={styles.errorBox}>{error}</p> : null}

        {isBootLoading ? (
          <div className={styles.stateBox}>
            <LocalizedText zh="正在接入法流数据..." en="Loading Faloo..." />
          </div>
        ) : null}

        {!isBootLoading && visibleCards.length === 0 ? (
          <div className={styles.stateBox}>
            <LocalizedText zh="这一组暂时没有可展示的佛典。" en="No matching works are available yet." />
          </div>
        ) : null}

        <div className={styles.feedGrid}>
          {visibleCards.map((item) => {
            const firstJuan = item.juans[0] ?? "1";
            const stats = statsMap[buildCbetaContentId(item.work, firstJuan)] ?? { likeCount: 0, commentCount: 0 };
            const byline = getByline(item.info);
            return (
              <article key={item.work} className={styles.feedCard}>
                <button type="button" className={styles.coverButton} onClick={() => void openDetail(item, firstJuan)}>
                  <div className={styles.cover} style={getCoverStyle(item)}>
                    <div className={styles.coverTexture} aria-hidden="true" />
                    <div className={styles.coverTopline}>
                      <span>{getCategoryLabel(item.info, item.work)}</span>
                      <span>{item.work}</span>
                    </div>
                    <div className={styles.coverCenter}>
                      <span>{item.work}</span>
                      <h2>{item.title}</h2>
                      <p>{getTranslator(item.info)}</p>
                    </div>
                    <div className={styles.coverBottom}>
                      <span>赞 {formatStats(stats.likeCount)}</span>
                      <span>{item.juans.length > 1 ? `${item.juans.length} 卷` : `第 ${firstJuan} 卷`}</span>
                    </div>
                  </div>
                </button>
                <button type="button" className={styles.titleButton} onClick={() => void openDetail(item, firstJuan)}>
                  {item.title}
                </button>
                <p className={styles.cardMeta}>
                  <span>@ CBETA</span>
                  <span>{item.info?.time_dynasty ? `${item.info.time_dynasty} · ${byline}` : byline}</span>
                </p>
              </article>
            );
          })}
        </div>

        {isSearchLoading ? (
          <p className={styles.loadingLine}>
            <LocalizedText zh="正在补充题名搜索结果..." en="Pulling more title results..." />
          </p>
        ) : null}
      </div>

      <div className={styles.floatRail} aria-hidden="true">
        <span>目</span>
        <span>文</span>
        <span>评</span>
      </div>

      {selected ? (
        <div className={styles.modalBackdrop} role="presentation" onClick={() => setSelected(null)}>
          <div className={styles.modal} role="dialog" aria-modal="true" onClick={(event) => event.stopPropagation()}>
            <div className={styles.modalHeader}>
              <div>
                <p className={styles.modalEyebrow}>{selected.work}</p>
                <h3>{selected.title}</h3>
                <p className={styles.modalByline}>{getByline(selected.info)}</p>
              </div>
              <button type="button" className={styles.closeButton} onClick={() => setSelected(null)} aria-label="关闭">
                X
              </button>
            </div>

            <div className={styles.modalMeta}>
              <span>赞 {formatStats(selectedStats.likeCount)}</span>
              <span>评论 {formatStats(selectedStats.commentCount)}</span>
              <span>卷次 {selectedJuan}</span>
            </div>

            <div className={styles.modalTabs}>
              {selected.juans.slice(0, 12).map((juan) => (
                <button
                  key={juan}
                  type="button"
                  className={juan === selectedJuan ? styles.activeJuanButton : styles.juanButton}
                  onClick={() => void openDetail(selected, juan)}
                >
                  第 {juan} 卷
                </button>
              ))}
            </div>

            <div className={styles.modalBody}>
              <section className={styles.readerPanel}>
                {isDetailLoading ? (
                  <div className={styles.readerState}>
                    <LocalizedText zh="正文载入中..." en="Loading the text..." />
                  </div>
                ) : null}

                {!isDetailLoading && selectedDetail ? (
                  <div className={styles.readerHtml} dangerouslySetInnerHTML={{ __html: selectedDetail.html }} />
                ) : null}

                {!isDetailLoading && !selectedDetail ? (
                  <div className={styles.readerState}>
                    <LocalizedText zh="暂时没有拿到这一卷正文。" en="This juan is not available right now." />
                  </div>
                ) : null}
              </section>

              <aside className={styles.sidePanel}>
                <section className={styles.infoPanel}>
                  <h4>目录</h4>
                  {selectedDetail?.toc && selectedDetail.toc.length > 0 ? (
                    <div className={styles.tocList}>
                      {selectedDetail.toc.slice(0, 18).map((node, index) => (
                        <div key={`${node.lb ?? node.title ?? index}`} className={styles.tocItem}>
                          <strong>{node.title ?? "未命名节点"}</strong>
                          {node.lb ? <span>{node.lb}</span> : null}
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className={styles.mutedText}>这一卷暂未返回目录结构。</p>
                  )}
                </section>

                <section className={styles.infoPanel}>
                  <h4>评论</h4>
                  {selectedComments.length > 0 ? (
                    <div className={styles.commentList}>
                      {selectedComments.map((comment) => (
                        <article key={comment.id} className={styles.commentItem}>
                          <div className={styles.commentMeta}>
                            <strong>{comment.nickname || comment.username || "法布施用户"}</strong>
                            <span>{formatCommentDate(comment.createdAt)}</span>
                          </div>
                          <p>{stripTags(comment.content)}</p>
                          {comment.mainPractice ? <small>主修功课：{comment.mainPractice}</small> : null}
                        </article>
                      ))}
                    </div>
                  ) : (
                    <p className={styles.mutedText}>这条佛典内容还没有同步到可展示的评论。</p>
                  )}
                </section>
              </aside>
            </div>
          </div>
        </div>
      ) : null}
    </section>
  );
}
