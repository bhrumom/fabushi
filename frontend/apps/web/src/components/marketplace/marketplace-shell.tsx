"use client";

import {
  AppWindow,
  BookOpen,
  Check,
  ChevronRight,
  Code2,
  Compass,
  Download,
  ExternalLink,
  Home,
  Layers3,
  Package,
  Plus,
  Search,
  ShieldCheck,
  Sparkles,
  User,
  X,
} from "lucide-react";
import { type FormEvent, useEffect, useMemo, useRef, useState } from "react";
import {
  MARKETPLACE_CATEGORY_LABELS,
  getMarketplaceApp,
  marketplaceApps,
  searchMarketplace,
  type MarketplaceApp,
  type MarketplaceCategory,
} from "../../lib/marketplace";
import { siteHref } from "../../lib/site-url";
import { AppIcon } from "./app-icon";
import styles from "./marketplace.module.css";

const INSTALLED_KEY = "fabushi.installed-miniapps";
const RECENT_KEY = "fabushi.marketplace.recent-apps.v1";

type MarketplaceSection = "discover" | "installed" | "content";

const categoryOrder: readonly MarketplaceCategory[] = [
  "featured",
  "automation",
  "content",
  "practice",
  "developer",
  "system",
];

function readStringArray(key: string): string[] {
  try {
    const parsed = JSON.parse(window.localStorage.getItem(key) ?? "[]");
    return Array.isArray(parsed) ? parsed.filter((item): item is string => typeof item === "string") : [];
  } catch {
    return [];
  }
}

function contentTypeLabel(type: MarketplaceApp["content"][number]["type"]) {
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

function AppFeedCard({
  app,
  installed,
  onInstall,
  onOpen,
  onPreview,
}: {
  app: MarketplaceApp;
  installed: boolean;
  onInstall: (app: MarketplaceApp) => void;
  onOpen: (app: MarketplaceApp) => void;
  onPreview: (app: MarketplaceApp) => void;
}) {
  return (
    <article className={styles.appCard}>
      <AppIcon label={app.icon} tone={app.tone} />
      <div className={styles.appCardBody}>
        <div className={styles.appCardHeader}>
          <div className={styles.appTitleRow}>
            <div className={styles.appNameLine}>
              <a href={siteHref(`/apps/${app.slug}`)}>{app.name}</a>
              {app.verified ? (
                <span className={styles.verified} title="已验证开发者" aria-label="已验证开发者">
                  <Check />
                </span>
              ) : null}
            </div>
            <div className={styles.developerLine}>
              {app.developer} · {MARKETPLACE_CATEGORY_LABELS[app.category]}
            </div>
          </div>
        </div>
        <p className={styles.appDescription}>{app.subtitle}</p>
        <div className={styles.appMeta}>
          <span className={styles.metaChip}>
            <ShieldCheck /> 权限透明
          </span>
          <span className={styles.metaChip}>
            <AppWindow /> Mini App
          </span>
          {app.tags.slice(0, 2).map((tag) => (
            <span key={tag} className={styles.metaChip}>{tag}</span>
          ))}
        </div>
        <div className={styles.appCardActions}>
          {installed ? (
            <a
              className={styles.primaryButton}
              href={siteHref(`/miniapps/${app.id}`)}
              onClick={() => onOpen(app)}
            >
              打开 <ExternalLink />
            </a>
          ) : (
            <button className={styles.primaryButton} type="button" onClick={() => onInstall(app)}>
              安装 <Download />
            </button>
          )}
          <button className={styles.secondaryButton} type="button" onClick={() => onPreview(app)}>
            快速预览
          </button>
          <a className={styles.ghostButton} href={siteHref(`/apps/${app.slug}`)}>
            详情 <ChevronRight />
          </a>
        </div>
      </div>
    </article>
  );
}

export function MarketplaceShell() {
  const [section, setSection] = useState<MarketplaceSection>("discover");
  const [category, setCategory] = useState<MarketplaceCategory>("featured");
  const [query, setQuery] = useState("");
  const [installedIds, setInstalledIds] = useState<string[]>([]);
  const [recentIds, setRecentIds] = useState<string[]>([]);
  const [previewId, setPreviewId] = useState<string | null>(null);
  const searchRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setInstalledIds(readStringArray(INSTALLED_KEY));
    setRecentIds(readStringArray(RECENT_KEY));

    const params = new URLSearchParams(window.location.search);
    const requestedCategory = params.get("category");
    if (requestedCategory && categoryOrder.includes(requestedCategory as MarketplaceCategory)) {
      setCategory(requestedCategory as MarketplaceCategory);
    }
    const requestedQuery = params.get("q")?.trim();
    if (requestedQuery) setQuery(requestedQuery);
  }, []);

  useEffect(() => {
    if (!previewId) return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") setPreviewId(null);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [previewId]);

  const results = useMemo(() => searchMarketplace(query), [query]);
  const installedSet = useMemo(() => new Set(installedIds), [installedIds]);
  const previewApp = previewId ? getMarketplaceApp(previewId) : undefined;

  const visibleApps = useMemo(() => {
    let apps = results.apps;
    if (!query.trim()) {
      if (category === "featured") apps = apps.filter((app) => app.featured);
      else apps = apps.filter((app) => app.category === category);
    }
    if (section === "installed") apps = apps.filter((app) => installedSet.has(app.id));
    return apps;
  }, [category, installedSet, query, results.apps, section]);

  const showContent = section === "content" || Boolean(query.trim());
  const visibleContent = results.content.slice(0, query.trim() ? 12 : 8);
  const recentApps = recentIds
    .map((id) => getMarketplaceApp(id))
    .filter((app): app is MarketplaceApp => Boolean(app))
    .slice(0, 4);

  const saveInstalled = (ids: string[]) => {
    const unique = [...new Set(ids)];
    setInstalledIds(unique);
    window.localStorage.setItem(INSTALLED_KEY, JSON.stringify(unique));
    window.dispatchEvent(new CustomEvent("fabushi:marketplace-installed", { detail: { ids: unique } }));
  };

  const installApp = (app: MarketplaceApp) => {
    saveInstalled([...installedIds, app.id]);
  };

  const markOpened = (app: MarketplaceApp) => {
    const next = [app.id, ...recentIds.filter((id) => id !== app.id)].slice(0, 8);
    setRecentIds(next);
    window.localStorage.setItem(RECENT_KEY, JSON.stringify(next));
  };

  const submitSearch = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const normalized = query.trim();
    if (!normalized) {
      searchRef.current?.focus();
      return;
    }
    window.location.assign(siteHref(`/search?q=${encodeURIComponent(normalized)}`));
  };

  const focusSearch = () => {
    setSection("discover");
    window.setTimeout(() => searchRef.current?.focus(), 0);
  };

  const sectionTitle = query.trim()
    ? `“${query.trim()}”的搜索结果`
    : section === "installed"
      ? "我的应用"
      : section === "content"
        ? "内容与工作流"
        : category === "featured"
          ? "本周精选"
          : MARKETPLACE_CATEGORY_LABELS[category];

  return (
    <div className={styles.shell}>
      <div className={styles.desktopGrid}>
        <aside className={styles.leftRail} aria-label="主导航">
          <a className={styles.brand} href={siteHref("/")} aria-label="Fabushi 应用市场首页">
            <span className={styles.brandMark}>法</span>
            <span className={styles.brandText}>
              <strong>Fabushi</strong>
              <small>Mini App Market</small>
            </span>
          </a>

          <nav className={styles.navList}>
            <button
              className={`${styles.navButton} ${section === "discover" ? styles.navButtonActive : ""}`}
              type="button"
              onClick={() => setSection("discover")}
            >
              <Home /> <span>发现</span>
            </button>
            <button className={styles.navButton} type="button" onClick={focusSearch}>
              <Search /> <span>搜索</span>
            </button>
            <button
              className={`${styles.navButton} ${section === "installed" ? styles.navButtonActive : ""}`}
              type="button"
              onClick={() => setSection("installed")}
            >
              <Package /> <span>我的应用</span>
            </button>
            <button
              className={`${styles.navButton} ${section === "content" ? styles.navButtonActive : ""}`}
              type="button"
              onClick={() => setSection("content")}
            >
              <BookOpen /> <span>内容入口</span>
            </button>
            <a className={styles.navLink} href={siteHref("/miniapps/bot-father/commerce")}>
              <Code2 /> <span>开发者中心</span>
            </a>
          </nav>

          <a className={styles.launchButton} href={siteHref("/app")}>打开大乘</a>

          <a className={styles.profileCard} href={siteHref("/app")}>
            <span className={styles.avatar}>普</span>
            <span className={styles.profileCopy}>
              <strong>我的 Fabushi</strong>
              <small>{installedIds.length} 个已安装应用</small>
            </span>
          </a>
        </aside>

        <main className={styles.mainColumn}>
          <header className={styles.stickyHeader}>
            <span className={styles.headerTitle}>
              <strong>应用市场</strong>
              <small>发现、安装、立即运行</small>
            </span>
            <span className={styles.headerActions}>
              <a className={styles.iconButton} href={siteHref("/miniapps/bot-father/commerce")} aria-label="开发者中心">
                <Plus />
              </a>
              <a className={styles.iconButton} href={siteHref("/app")} aria-label="个人中心">
                <User />
              </a>
            </span>
          </header>

          <section className={styles.hero}>
            <p className={styles.heroEyebrow}>Apps that become tools</p>
            <h1>安装一个应用，立即多一种能力。</h1>
            <p>
              像 Telegram Mini App 一样点开即用；像 Shopify App Store 一样可发现、可比较、可分发；每条内容都有独立搜索入口。
            </p>
            <div className={styles.heroBadges}>
              <span className={styles.heroBadge}><Sparkles /> 即开即用</span>
              <span className={styles.heroBadge}><ShieldCheck /> 权限逐项确认</span>
              <span className={styles.heroBadge}><Layers3 /> WebMCP 可发现</span>
            </div>
          </section>

          <form className={styles.searchForm} role="search" onSubmit={submitSearch}>
            <Search />
            <input
              ref={searchRef}
              className={styles.searchInput}
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="搜索应用、能力、指南或工作流"
              aria-label="搜索 Fabushi 应用与内容"
            />
            {query ? (
              <button className={styles.searchClear} type="button" aria-label="清除搜索" onClick={() => setQuery("")}>
                <X />
              </button>
            ) : null}
          </form>

          {section !== "content" ? (
            <nav className={styles.categoryBar} aria-label="应用分类">
              {categoryOrder.map((item) => (
                <button
                  key={item}
                  className={`${styles.categoryButton} ${category === item ? styles.categoryButtonActive : ""}`}
                  type="button"
                  onClick={() => {
                    setCategory(item);
                    setSection("discover");
                    window.history.replaceState(
                      null,
                      "",
                      item === "featured" ? siteHref("/") : siteHref(`/?category=${item}`),
                    );
                  }}
                >
                  {MARKETPLACE_CATEGORY_LABELS[item]}
                </button>
              ))}
            </nav>
          ) : null}

          <div className={styles.sectionHeader}>
            <div>
              <h2>{sectionTitle}</h2>
              <p>
                {section === "installed"
                  ? `${visibleApps.length} 个应用已加入你的工作台`
                  : query.trim()
                    ? `${visibleApps.length} 个应用，${visibleContent.length} 条内容`
                    : "应用运行在 Fabushi 的统一 Mini App 容器中"}
              </p>
            </div>
            {query.trim() ? <a className={styles.sectionLink} href={siteHref(`/search?q=${encodeURIComponent(query.trim())}`)}>完整搜索</a> : null}
          </div>

          {section !== "content" ? (
            visibleApps.length ? (
              <div className={styles.appFeed}>
                {visibleApps.map((app) => (
                  <AppFeedCard
                    key={app.id}
                    app={app}
                    installed={installedSet.has(app.id)}
                    onInstall={installApp}
                    onOpen={markOpened}
                    onPreview={(candidate) => setPreviewId(candidate.id)}
                  />
                ))}
              </div>
            ) : (
              <div className={styles.emptyState}>
                <span className={styles.emptyStateIcon}><Package /></span>
                <h2>{section === "installed" ? "还没有安装应用" : "没有找到匹配应用"}</h2>
                <p>{section === "installed" ? "从精选应用开始，安装后就会出现在这里。" : "换一个关键词或分类试试。"}</p>
                {section === "installed" ? (
                  <button className={styles.primaryButton} type="button" onClick={() => setSection("discover")}>发现应用</button>
                ) : null}
              </div>
            )
          ) : null}

          {showContent ? (
            <>
              <div className={styles.sectionHeader}>
                <div>
                  <h2>内容级入口</h2>
                  <p>指南、模板和工作流都能被搜索并直达</p>
                </div>
              </div>
              {visibleContent.length ? (
                <div className={styles.contentFeed}>
                  {visibleContent.map(({ app, item }) => (
                    <article key={`${app.id}:${item.id}`} className={styles.contentCard}>
                      <span className={styles.contentType}><BookOpen /></span>
                      <div>
                        <h3>
                          <a href={siteHref(`/apps/${app.slug}/content/${item.id}`)}>{item.title}</a>
                        </h3>
                        <p>{item.summary}</p>
                        <div className={styles.contentMeta}>
                          {app.name} · {contentTypeLabel(item.type)} · {item.readingMinutes} 分钟
                        </div>
                      </div>
                    </article>
                  ))}
                </div>
              ) : (
                <div className={styles.emptyState}>
                  <span className={styles.emptyStateIcon}><BookOpen /></span>
                  <h2>没有找到匹配内容</h2>
                  <p>尝试搜索具体主题、应用名、指南或工作流。</p>
                </div>
              )}
            </>
          ) : null}
        </main>

        <aside className={styles.rightRail} aria-label="发现更多">
          <div className={styles.sideSearch}>
            <form className={styles.searchForm} role="search" onSubmit={submitSearch}>
              <Search />
              <input
                className={styles.searchInput}
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="搜索市场"
                aria-label="搜索市场"
              />
            </form>
          </div>

          {recentApps.length ? (
            <section className={styles.sidePanel}>
              <header className={styles.sidePanelHeader}>
                <h2>最近打开</h2>
                <p>在网页、桌面与移动端继续</p>
              </header>
              {recentApps.map((app) => (
                <a
                  key={app.id}
                  className={styles.trendingItem}
                  href={siteHref(`/miniapps/${app.id}`)}
                  onClick={() => markOpened(app)}
                >
                  <span className={styles.trendingCopy}>
                    <small>Mini App</small>
                    <strong>{app.name}</strong>
                    <span>{app.subtitle}</span>
                  </span>
                  <AppIcon label={app.icon} tone={app.tone} size="small" />
                </a>
              ))}
            </section>
          ) : null}

          <section className={styles.sidePanel}>
            <header className={styles.sidePanelHeader}>
              <h2>正在流行</h2>
              <p>基于市场内容、更新频率与功能完整度</p>
            </header>
            {marketplaceApps.slice(0, 5).map((app, index) => (
              <a key={app.id} className={styles.trendingItem} href={siteHref(`/apps/${app.slug}`)}>
                <span className={styles.trendingCopy}>
                  <small>{index + 1} · {MARKETPLACE_CATEGORY_LABELS[app.category]}</small>
                  <strong>{app.name}</strong>
                  <span>{app.tags.slice(0, 2).join(" · ")}</span>
                </span>
                <AppIcon label={app.icon} tone={app.tone} size="small" />
              </a>
            ))}
          </section>

          <section className={styles.sidePanel}>
            <header className={styles.sidePanelHeader}>
              <h2>发布你的 Mini App</h2>
              <p>提交应用资料、权限说明、内容入口与运行地址，通过同一身份覆盖网页和客户端。</p>
            </header>
            <div style={{ padding: "0 16px 16px" }}>
              <a className={styles.primaryButton} href={siteHref("/miniapps/bot-father/commerce")}>
                进入开发者中心 <Code2 />
              </a>
            </div>
          </section>

          <footer className={styles.sideFooter}>
            <a href={siteHref("/privacy")}>隐私</a>
            <a href={siteHref("/contact")}>支持</a>
            <a href={siteHref("/download")}>客户端下载</a>
            <a href={siteHref("/search")}>内容搜索</a>
            <span>© 2026 Fabushi</span>
          </footer>
        </aside>
      </div>

      <nav className={styles.mobileNav} aria-label="移动端导航">
        <button
          className={`${styles.mobileNavButton} ${section === "discover" ? styles.mobileNavButtonActive : ""}`}
          type="button"
          onClick={() => setSection("discover")}
        >
          <Compass /> 发现
        </button>
        <button className={styles.mobileNavButton} type="button" onClick={focusSearch}>
          <Search /> 搜索
        </button>
        <button
          className={`${styles.mobileNavButton} ${section === "installed" ? styles.mobileNavButtonActive : ""}`}
          type="button"
          onClick={() => setSection("installed")}
        >
          <Package /> 应用
        </button>
        <a className={styles.mobileNavButton} href={siteHref("/app")}>
          <User /> 我的
        </a>
      </nav>

      {previewApp ? (
        <div className={styles.previewBackdrop} role="presentation" onMouseDown={(event) => {
          if (event.currentTarget === event.target) setPreviewId(null);
        }}>
          <section className={styles.previewPanel} role="dialog" aria-modal="true" aria-labelledby="preview-title">
            <div className={styles.previewTop}>
              <button className={styles.iconButton} type="button" aria-label="关闭预览" onClick={() => setPreviewId(null)}>
                <X />
              </button>
            </div>
            <div className={styles.previewHero}>
              <AppIcon label={previewApp.icon} tone={previewApp.tone} size="large" />
              <div>
                <h2 id="preview-title">{previewApp.name}</h2>
                <p>{previewApp.subtitle}</p>
              </div>
            </div>
            <section className={styles.previewSection}>
              <h3>关于这个应用</h3>
              <p>{previewApp.description}</p>
            </section>
            <section className={styles.previewSection}>
              <h3>核心体验</h3>
              <div className={styles.highlightList}>
                {previewApp.highlights.map((highlight) => (
                  <article key={highlight.title} className={styles.highlightItem}>
                    <strong>{highlight.title}</strong>
                    <p>{highlight.description}</p>
                  </article>
                ))}
              </div>
            </section>
            <section className={styles.previewSection}>
              <h3>权限与价格</h3>
              <p>{previewApp.permissions.join("；")}。</p>
              <div className={styles.appMeta}>
                <span className={styles.metaChip}>{previewApp.pricing.label}</span>
                <span className={styles.metaChip}>v{previewApp.version}</span>
                <span className={styles.metaChip}>{previewApp.content.length} 个内容入口</span>
              </div>
            </section>
            <div className={styles.previewActions}>
              <a className={styles.secondaryButton} href={siteHref(`/apps/${previewApp.slug}`)}>
                完整详情
              </a>
              {installedSet.has(previewApp.id) ? (
                <a
                  className={styles.primaryButton}
                  href={siteHref(`/miniapps/${previewApp.id}`)}
                  onClick={() => markOpened(previewApp)}
                >
                  打开应用 <ExternalLink />
                </a>
              ) : (
                <button className={styles.primaryButton} type="button" onClick={() => installApp(previewApp)}>
                  安装应用 <Download />
                </button>
              )}
            </div>
          </section>
        </div>
      ) : null}
    </div>
  );
}
