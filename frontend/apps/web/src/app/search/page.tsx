import type { Metadata } from "next";
import { Suspense } from "react";
import { MarketplaceSearch } from "../../components/marketplace/marketplace-search";
import styles from "../../components/marketplace/marketplace.module.css";
import { siteUrl } from "../../lib/site-url";

const searchUrl = siteUrl("/search");

export const metadata: Metadata = {
  title: "搜索应用与内容 | Fabushi 应用市场",
  description: "搜索 Fabushi Mini App、能力、指南、模板、内容集和工作流，并直接打开具体应用或内容入口。",
  alternates: { canonical: searchUrl },
  robots: {
    index: false,
    follow: true,
  },
  openGraph: {
    title: "搜索应用与内容 | Fabushi 应用市场",
    description: "搜索 Fabushi Mini App、能力、指南、模板、内容集和工作流。",
    url: searchUrl,
    siteName: "Fabushi 应用市场",
    locale: "zh_CN",
    type: "website",
  },
};

function SearchFallback() {
  return (
    <div className={styles.searchPage}>
      <main className={styles.searchPageInner}>
        <div className={styles.emptyState}>
          <span className={styles.emptyStateIcon}>法</span>
          <h2>正在准备搜索</h2>
          <p>应用和内容索引会在页面载入后立即可用。</p>
        </div>
      </main>
    </div>
  );
}

export default function SearchPage() {
  return (
    <Suspense fallback={<SearchFallback />}>
      <MarketplaceSearch />
    </Suspense>
  );
}
