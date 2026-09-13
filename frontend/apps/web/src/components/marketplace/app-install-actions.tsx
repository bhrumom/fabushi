"use client";

import { Check, Download, ExternalLink, Plus, RefreshCw } from "lucide-react";
import { useEffect, useState } from "react";
import {
  installMarketplaceApp,
  marketplaceAppInstallAction,
  marketplaceInstallActionLabel,
  readMarketplaceInstallRecords,
  subscribeMarketplaceInstallState,
} from "../../lib/marketplace-install-state";
import { siteHref } from "../../lib/site-url";
import styles from "./marketplace.module.css";

const RECENT_KEY = "fabushi.marketplace.recent-apps.v1";

function readList(key: string): string[] {
  try {
    const value = JSON.parse(window.localStorage.getItem(key) ?? "[]");
    return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
  } catch {
    return [];
  }
}

export function AppInstallActions({ appId, appName }: { appId: string; appName: string }) {
  const [installedRecords, setInstalledRecords] = useState(() => readMarketplaceInstallRecords());

  useEffect(() => {
    setInstalledRecords(readMarketplaceInstallRecords());
    return subscribeMarketplaceInstallState(setInstalledRecords);
  }, []);

  const installed = installedRecords[appId];
  const action = marketplaceAppInstallAction(appId, installed);
  const install = () => {
    if (action === "current" || action === "blocked" || action === "unavailable") return;
    const record = installMarketplaceApp(appId);
    if (record) setInstalledRecords(readMarketplaceInstallRecords());
  };

  const markOpened = () => {
    const recent = readList(RECENT_KEY);
    const next = [appId, ...recent.filter((id) => id !== appId)].slice(0, 8);
    window.localStorage.setItem(RECENT_KEY, JSON.stringify(next));
  };

  return (
    <>
      <button
        className={styles.detailPrimary}
        type="button"
        onClick={install}
        disabled={action === "current" || action === "blocked" || action === "unavailable"}
        aria-label={`${marketplaceInstallActionLabel(action)} ${appName}`}
      >
        {action === "current" ? <Check /> : action === "update" || action === "reinstall" ? <RefreshCw /> : action === "unavailable" ? <Plus /> : <Download />}
        {action === "current" ? "已安装 · 最新" : marketplaceInstallActionLabel(action)}
      </button>
      {installed ? (
        <small className={styles.detailHint}>
          GitHub {installed.version} · SHA-256 {installed.artifactSha256 ? installed.artifactSha256.slice(0, 12) : "待校验"}
        </small>
      ) : null}
      <a
        className={styles.detailSecondary}
        href={siteHref(`/miniapps/${appId}`)}
        onClick={markOpened}
      >
        立即打开 <ExternalLink />
      </a>
    </>
  );
}
