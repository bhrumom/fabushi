"use client";

import { Check, ExternalLink, Plus } from "lucide-react";
import { useEffect, useState } from "react";
import { siteHref } from "../../lib/site-url";
import styles from "./marketplace.module.css";

const INSTALLED_KEY = "fabushi.installed-miniapps";
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
  const [installed, setInstalled] = useState(false);

  useEffect(() => {
    setInstalled(readList(INSTALLED_KEY).includes(appId));
  }, [appId]);

  const install = () => {
    const next = [...new Set([...readList(INSTALLED_KEY), appId])];
    window.localStorage.setItem(INSTALLED_KEY, JSON.stringify(next));
    setInstalled(true);
    window.dispatchEvent(new CustomEvent("fabushi:marketplace-installed", { detail: { ids: next } }));
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
        disabled={installed}
        aria-label={installed ? `${appName} 已安装` : `安装 ${appName}`}
      >
        {installed ? <Check /> : <Plus />}
        {installed ? "已加入我的应用" : "安装应用"}
      </button>
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
