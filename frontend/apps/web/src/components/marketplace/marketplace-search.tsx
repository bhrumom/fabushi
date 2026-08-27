"use client";

import {
  ArrowLeft,
  BookOpen,
  Check,
  ChevronRight,
  Download,
  ExternalLink,
  Package,
  Search,
  X,
} from "lucide-react";
import { type FormEvent, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import {
  MARKETPLACE_CATEGORY_LABELS,
  searchMarketplace,
  type MarketplaceApp,
  type MarketplaceContentItem,
} from "../../lib/marketplace";
import { siteHref } from "../../lib/site-url";
import { AppIcon } from "./app-icon";
import styles from "./marketplace.module.css";

const INSTALLED_KEY = "fabushi.installed-miniapps";
const RECENT_KEY = "fabushi.marketplace.recent-apps.v1";

function readList(key: string): string[] {
  try {
    const parsed = JSON.parse(window.localStorage.getItem(key) ?? "[]");
    return Array.isArray(parsed) ? parsed.filter((item): item is string => typeof item === "string") : [];
  } catch {
    return [];
  }
}

function contentTypeLabel(type: MarketplaceContentItem["type"]) {
  switch (type) {
    case "guide":
      return "指南";
    case "template":
      return "模板";
    case "collection":
      return "内容集";
    case "workflow":
      return "工作流";
    case "release":
      return "版本说明";
  }
}

export function MarketplaceSearch() {
  const searchParams = useSearchParams();
  const initialQuery = searchParams.get("q")?.trim() ?? "";
  const [query, setQuery] = useState(initialQuery);
  const [submittedQuery, setSubmittedQuery] = useState(initialQuery);
  const [installedIds, setInstalledIds] = useState<string[]>([]);

  useEffect(() => {
    setInstalledIds(readList(INSTALLED_KEY));
  }, []);

  useEffect(() => {
    const nextQuery = searchParams.get("q")?.trim() ?? "";
    setQuery(nextQuery);
    setSubmittedQuery(nextQuery);
  }, [searchParams]);

  const results = useMemo(() => searchMarketplace(submittedQuery), [submittedQuery]);
  const installedSet = useMemo(() => new Set(installedIds), [installedIds]);

  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const normalized = query.trim();
    setSubmittedQuery(normalized);
    const href = normalized ? siteHref(`/search?q=${encodeURIComponent(normalized)}`) : siteHref("/search");
    window.history.replaceState(null, "", href);
  };

  const install = (app: MarketplaceApp) => {
    const next = [...new Set([...installedIds, app.id])];
    setInstalledIds(next);
    window.localStorage.setItem(INSTALLED_KEY, JSON.stringify(next));
    window.dispatchEvent(new CustomEvent("fabushi:marketplace-installed", { detail: { ids: next } }));
  };

  const markOpened = (app: MarketplaceApp) => {
    const recent = readList(RECENT_KEY);
    const next = [app.id, ...recent.filter((id) => id !== app.id)].slice(0, 8);
    window.localStorage.setItem(RECENT_KEY, JSON.stringify(next));
  };

  const hasResults = results.apps.length > 0 || results.content.length > 0;

  return (
    <div className={styles.searchPage}>
      <main className={styles.searchPageInner}>
        <header className={styles.searchPageHeader}>
          <a className={styles.iconButton} href={siteHref("/")} aria-label="返回应用市场">
            <ArrowLeft />
          </a>
          <form className={styles.searchForm} role="search" onSubmit={submit}>
            <Search />
            <input
              className={styles.searchInput}
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="搜索应用、能力、指南、模板或工作流"
              autoFocus
              aria-label="搜索 Fabushi 应用和内容"
            />
            {query ? (
              <button className={styles.searchClear} type="button" aria-label="清除搜索" onClick={() => setQuery("")}>
                <X />
              </button>
            ) : null}
          </form>
        </header>

        <section className={styles.searchSummary}>
          <h1>{submittedQuery ? `“${submittedQuery}”的搜索结果` : "搜索 Fabushi"}</h1>
          <p>
            {submittedQuery
              ? `${results.apps.length} 个应用，${results.content.length} 条内容级入口`
              : "输入应用名、功能、主题或工作流关键词。每条内容都可以直接打开。"}
          </p>
        </section>

        {results.apps.length ? (
          <>
            <div className={styles.sectionHeader}>
              <div>
                <h2>应用</h2>
                <p>比较资料后安装，或直接打开试用</p>
              </div>
            </div>
            <div className={styles.appFeed}>
              {results.apps.map((app) => (
                <article key={app.id} className={styles.appCard}>
                  <AppIcon label={app.icon} tone={app.tone} />
                  <div className={styles.appCardBody}>
                    <div className={styles.appNameLine}>
                      <a href={siteHref(`/apps/${app.slug}`)}>{app.name}</a>
                      {app.verified ? <span className={styles.verified}><Check /></span> : null}
                    </div>
                    <div className={styles.developerLine}>
                      {app.developer} · {MARKETPLACE_CATEGORY_LABELS[app.category]}
                    </div>
                    <p className={styles.appDescription}>{app.subtitle}</p>
                    <div className={styles.appMeta}>
                      {app.tags.slice(0, 3).map((tag) => (
                        <span key={tag} className={styles.metaChip}>{tag}</span>
                      ))}
                    </div>
                    <div className={styles.appCardActions}>
                      {installedSet.has(app.id) ? (
                        <a
                          className={styles.primaryButton}
                          href={siteHref(`/miniapps/${app.id}`)}
                          onClick={() => markOpened(app)}
                        >
                          打开 <ExternalLink />
                        </a>
                      ) : (
                        <button className={styles.primaryButton} type="button" onClick={() => install(app)}>
                          安装 <Download />
                        </button>
                      )}
                      <a className={styles.secondaryButton} href={siteHref(`/apps/${app.slug}`)}>
                        查看详情 <ChevronRight />
                      </a>
                    </div>
                  </div>
                </article>
              ))}
            </div>
          </>
        ) : null}

        {results.content.length ? (
          <>
            <div className={styles.sectionHeader}>
              <div>
                <h2>内容</h2>
                <p>从搜索结果直接进入具体指南、模板和工作流</p>
              </div>
            </div>
            <div className={styles.contentFeed}>
              {results.content.map(({ app, item }) => (
                <article key={`${app.id}:${item.id}`} className={styles.contentCard}>
                  <span className={styles.contentType}><BookOpen /></span>
                  <div>
                    <h3><a href={siteHref(`/apps/${app.slug}/content/${item.id}`)}>{item.title}</a></h3>
                    <p>{item.summary}</p>
                    <div className={styles.contentMeta}>
                      {app.name} · {contentTypeLabel(item.type)} · {item.readingMinutes} 分钟 · {item.updatedAt}
                    </div>
                  </div>
                </article>
              ))}
            </div>
          </>
        ) : null}

        {!hasResults ? (
          <div className={styles.emptyState}>
            <span className={styles.emptyStateIcon}>{submittedQuery ? <Search /> : <Package />}</span>
            <h2>{submittedQuery ? "没有找到匹配结果" : "从一个关键词开始"}</h2>
            <p>
              {submittedQuery
                ? "尝试更短的关键词、应用名称、功能名称或内容主题。"
                : "例如：WebMCP、内容发布、心经、磁盘清理、授权范围。"}
            </p>
          </div>
        ) : null}
      </main>
    </div>
  );
}
