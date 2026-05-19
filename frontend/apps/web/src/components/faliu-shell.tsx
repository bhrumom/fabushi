"use client";

import { useDeferredValue, useEffect, useMemo, useState } from "react";
import { LocalizedText } from "./localized-text";
import { siteHref } from "../lib/site-url";
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

type TabKey = "featured" | "prajna" | "pureland" | "lotus" | "huayan" | "zen";

interface WorkCardItem {
  work: string;
  title: string;
  juans: string[];
  info?: CbetaWorkInfo | null;
}

const TAB_CONFIG: Array<{
  key: TabKey;
  labelZh: string;
  labelEn: string;
  hintZh: string;
  hintEn: string;
  featured: string[];
  tokens: string[];
}> = [
  {
    key: "featured",
    labelZh: "精选",
    labelEn: "Featured",
    hintZh: "先看适合直接进入阅读的几部常见佛典。",
    hintEn: "Start with a few approachable works that open quickly into reading.",
    featured: ["T0365", "T0251", "T0262", "T0279", "T0261", "T0278", "T0235", "T0236", "T0270"],
    tokens: [],
  },
  {
    key: "prajna",
    labelZh: "般若",
    labelEn: "Prajna",
    hintZh: "围绕般若、金刚、心经等主题聚合。",
    hintEn: "Grouped around Prajna, Diamond, and Heart Sutra themes.",
    featured: [],
    tokens: ["般若", "金剛", "金刚", "心經", "心经"],
  },
  {
    key: "pureland",
    labelZh: "净土",
    labelEn: "Pure Land",
    hintZh: "以无量寿、阿弥陀、观经相关佛典为主。",
    hintEn: "Centered on Amitabha, Infinite Life, and Visualization Sutra works.",
    featured: [],
    tokens: ["無量壽", "无量寿", "阿彌陀", "阿弥陀", "觀無量壽", "观无量寿"],
  },
  {
    key: "lotus",
    labelZh: "法华",
    labelEn: "Lotus",
    hintZh: "聚焦法华系统与相关注疏。",
    hintEn: "Focused on the Lotus Sutra tradition and related commentaries.",
    featured: [],
    tokens: ["法華", "法华", "妙法蓮華", "妙法莲华"],
  },
  {
    key: "huayan",
    labelZh: "华严",
    labelEn: "Huayan",
    hintZh: "适合想直接切入华严体系的人。",
    hintEn: "A direct entry into the Huayan corpus.",
    featured: [],
    tokens: ["華嚴", "华严"],
  },
  {
    key: "zen",
    labelZh: "禅门",
    labelEn: "Zen",
    hintZh: "偏向坛经、公案与禅宗相关文本。",
    hintEn: "More oriented toward Chan texts, platform teachings, and koan material.",
    featured: [],
    tokens: ["壇經", "坛经", "禪", "禅", "祖師", "祖师"],
  },
];

const CARD_LIMIT = 12;

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
    title: info?.title ?? item.title,
    juans: item.juans,
    info,
  };
}

function flattenVisibleJuans(items: WorkCardItem[]) {
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

export function FaliuShell() {
  const [activeTab, setActiveTab] = useState<TabKey>("featured");
  const [works, setWorks] = useState<CbetaWorkIndexItem[]>([]);
  const [workInfoMap, setWorkInfoMap] = useState<Record<string, CbetaWorkInfo | null>>({});
  const [statsMap, setStatsMap] = useState<Record<string, ContentStats>>({});
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState<WorkCardItem | null>(null);
  const [selectedDetail, setSelectedDetail] = useState<CbetaJuanDetail | null>(null);
  const [selectedComments, setSelectedComments] = useState<AppComment[]>([]);
  const [selectedJuan, setSelectedJuan] = useState("1");
  const [isBootLoading, setIsBootLoading] = useState(true);
  const [isSearchLoading, setIsSearchLoading] = useState(false);
  const [isDetailLoading, setIsDetailLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const deferredQuery = useDeferredValue(query.trim());

  useEffect(() => {
    let cancelled = false;

    async function bootstrap() {
      try {
        setIsBootLoading(true);
        const allWorks = await fetchAllWorks();

        if (cancelled) {
          return;
        }

        setWorks(allWorks);
        setError(null);
      } catch (cause) {
        if (cancelled) {
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

  const activeTabConfig = TAB_CONFIG.find((item) => item.key === activeTab) ?? TAB_CONFIG[0];

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

    const matched = works.filter((item) =>
      activeTabConfig.tokens.some((token) => item.title.includes(token)),
    );

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
            title: item.title,
            juans: [String(item.juan ?? 1)],
          })),
        );

        setWorks((current) => {
          const merged = [...normalized, ...current];
          return dedupeWorks(merged);
        });

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
      const [detail, comments, stats] = await Promise.all([
        fetchJuanDetail(item.work, juan),
        fetchComments(buildCbetaContentId(item.work, juan)),
        fetchBatchStats([buildCbetaContentId(item.work, juan)]),
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
    <section className={`band ${styles.band}`}>
      <div className={styles.shell}>
        <div className={styles.topbar}>
          <div className={styles.searchWrap}>
            <label className={styles.searchBox}>
              <span className={styles.searchIcon} aria-hidden="true">
                Search
              </span>
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="搜索经名、经号或关键词"
                aria-label="搜索佛典"
              />
            </label>
            <p className={styles.searchHint}>
              <LocalizedText
                zh="输入 3 个字以上会直接调用 CBETA 题名搜索。"
                en="Queries with 3 or more characters call the CBETA title search directly."
              />
            </p>
          </div>
          <a className={styles.downloadLink} href={siteHref("/download")}>
            <LocalizedText zh="下载 App" en="Download App" />
          </a>
        </div>

        <div className={styles.tabRow} role="tablist" aria-label="法流分类">
          {TAB_CONFIG.map((item) => {
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

        <div className={styles.introRow}>
          <div>
            <h2 className={styles.sectionTitle}>
              <LocalizedText zh={activeTabConfig.labelZh} en={activeTabConfig.labelEn} />
            </h2>
            <p className={styles.sectionHint}>
              <LocalizedText zh={activeTabConfig.hintZh} en={activeTabConfig.hintEn} />
            </p>
          </div>
          <div className={styles.metaNote}>
            <span>CBETA API</span>
            <span>App Stats</span>
            <span>Read Flow</span>
          </div>
        </div>

        {error ? <p className={styles.errorBox}>{error}</p> : null}

        {isBootLoading ? (
          <div className={styles.stateBox}>
            <LocalizedText zh="正在接入法流数据…" en="Loading the Faloo data surface..." />
          </div>
        ) : null}

        {!isBootLoading && visibleCards.length === 0 ? (
          <div className={styles.stateBox}>
            <LocalizedText zh="这一组暂时没有可展示的佛典。" en="No matching works are available in this slice yet." />
          </div>
        ) : null}

        <div className={styles.feedGrid}>
          {visibleCards.map((item) => {
            const firstJuan = item.juans[0] ?? "1";
            const stats = statsMap[buildCbetaContentId(item.work, firstJuan)] ?? { likeCount: 0, commentCount: 0 };
            const info = item.info;
            return (
              <article key={item.work} className={styles.feedCard}>
                <button type="button" className={styles.cardButton} onClick={() => void openDetail(item, firstJuan)}>
                  <div className={styles.cardHeader}>
                    <span className={styles.cardTag}>{info?.category ?? item.work}</span>
                    <span className={styles.cardCanon}>{item.work}</span>
                  </div>
                  <h3>{item.title}</h3>
                  <p className={styles.byline}>{info?.byline ?? "CBETA 佛典"}</p>
                  <dl className={styles.cardFacts}>
                    <div>
                      <dt>卷次</dt>
                      <dd>{item.juans.length}</dd>
                    </div>
                    <div>
                      <dt>点赞</dt>
                      <dd>{formatStats(stats.likeCount)}</dd>
                    </div>
                    <div>
                      <dt>评论</dt>
                      <dd>{formatStats(stats.commentCount)}</dd>
                    </div>
                  </dl>
                  <p className={styles.cardMeta}>
                    {info?.time_dynasty ? `${info.time_dynasty} · ` : ""}
                    {item.juans.length > 1 ? `共 ${item.juans.length} 卷` : `第 ${firstJuan} 卷`}
                  </p>
                </button>
              </article>
            );
          })}
        </div>

        {isSearchLoading ? (
          <p className={styles.loadingLine}>
            <LocalizedText zh="正在补充题名搜索结果…" en="Pulling more title search results..." />
          </p>
        ) : null}
      </div>

      {selected ? (
        <div className={styles.modalBackdrop} role="presentation" onClick={() => setSelected(null)}>
          <div className={styles.modal} role="dialog" aria-modal="true" onClick={(event) => event.stopPropagation()}>
            <div className={styles.modalHeader}>
              <div>
                <p className={styles.modalEyebrow}>{selected.work}</p>
                <h3>{selected.title}</h3>
                <p className={styles.modalByline}>{selected.info?.byline ?? "CBETA 佛典"}</p>
              </div>
              <button type="button" className={styles.closeButton} onClick={() => setSelected(null)} aria-label="关闭">
                X
              </button>
            </div>

            <div className={styles.modalMeta}>
              <span>Like {formatStats(selectedStats.likeCount)}</span>
              <span>Comments {formatStats(selectedStats.commentCount)}</span>
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
                    <LocalizedText zh="正文载入中…" en="Loading the text..." />
                  </div>
                ) : null}

                {!isDetailLoading && selectedDetail ? (
                  <div
                    className={styles.readerHtml}
                    dangerouslySetInnerHTML={{ __html: selectedDetail.html }}
                  />
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
