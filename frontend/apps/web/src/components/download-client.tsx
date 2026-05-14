"use client";

import { useEffect, useState } from "react";
import { DownloadLink } from "./download-link";
import { LocalizedText } from "./localized-text";
import { useSiteLocale } from "./locale-provider";

export interface DownloadChannel {
  platform: "Android" | "iOS";
  audience: "beta" | "stable";
  status: string;
  title: string;
  description: string;
  primaryLabel: string;
  primaryHref: string;
  version?: string;
  publishedAt?: string;
  updateSummary: string[];
  mirrorLinks: { label: string; href: string }[];
  note?: string;
  releasePageHref?: string;
}

type DetectedPlatform = "android" | "ios" | "other";

function detectPlatform(): DetectedPlatform {
  if (typeof navigator === "undefined") return "other";
  const ua = navigator.userAgent.toLowerCase();
  if (/android/.test(ua)) return "android";
  if (/iphone|ipad|ipod/.test(ua)) return "ios";
  if (/macintosh/.test(ua) && "maxTouchPoints" in navigator && navigator.maxTouchPoints > 1) return "ios";
  return "other";
}

function getRecommendedTitle(platform: DetectedPlatform, locale: "zh" | "en"): string {
  switch (platform) {
    case "android":
      return locale === "zh" ? "推荐 Android 测试版" : "Recommended Android Beta";
    case "ios":
      return locale === "zh" ? "推荐 iOS 测试版" : "Recommended iOS Beta";
    default:
      return "";
  }
}

function matchesPlatform(channel: DownloadChannel, platform: DetectedPlatform): boolean {
  if (platform === "android") return channel.platform === "Android";
  if (platform === "ios") return channel.platform === "iOS";
  return false;
}

function formatPublishedAt(value?: string) {
  if (!value) return null;

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;

  return date.toISOString().slice(0, 10);
}

function getChannelActionCopy(channel: DownloadChannel) {
  if (channel.audience === "stable" && channel.primaryHref.startsWith("/contact")) {
    return {
      zh: "查看状态",
      en: "View status",
    };
  }

  if (channel.platform === "iOS") {
    return {
      zh: channel.audience === "beta" ? "下载 iOS 测试版" : "下载 iOS 正式版",
      en: channel.audience === "beta" ? "Download iOS Beta" : "Download iOS Stable",
    };
  }

  return {
    zh: channel.audience === "beta" ? "下载 Android 测试版" : "下载 Android 正式版",
    en: channel.audience === "beta" ? "Download Android Beta" : "Download Android Stable",
  };
}

function ChannelCard({ channel, recommended = false }: { channel: DownloadChannel; recommended?: boolean }) {
  const publishedAt = formatPublishedAt(channel.publishedAt);
  const actionCopy = getChannelActionCopy(channel);
  const summary = channel.updateSummary.slice(0, 2);

  return (
    <DownloadLink className={recommended ? "platform-row recommended detailed" : "platform-row detailed"} channel={channel}>
      <div>
        <span className="platform-name">
          {channel.title}
          {recommended ? <sup className="recommended-tag"><LocalizedText zh="推荐" en="Top" /></sup> : null}
        </span>
        <p>{channel.description}</p>
        {(channel.version || publishedAt) && (
          <div className="platform-detail-line">
            {channel.version ? <span>v{channel.version}</span> : null}
            {publishedAt ? <span>{publishedAt}</span> : null}
          </div>
        )}
        {summary.length > 0 && (
          <ul className="platform-summary-list">
            {summary.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        )}
      </div>
      <div className="platform-meta">
        <strong>{channel.status}</strong>
        <span>
          <LocalizedText zh={actionCopy.zh} en={actionCopy.en} />
        </span>
      </div>
    </DownloadLink>
  );
}

export function DownloadClient({ channels }: { channels: DownloadChannel[] }) {
  const { locale } = useSiteLocale();
  const [platform, setPlatform] = useState<DetectedPlatform>("other");
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setPlatform(detectPlatform());
    setMounted(true);
  }, []);

  const recommended = platform !== "other" ? channels.filter((ch) => matchesPlatform(ch, platform)) : [];
  const recommendedTitle = getRecommendedTitle(platform, locale);

  if (!mounted || recommended.length === 0) {
    return <div className="platform-strip">{renderAllChannels(channels)}</div>;
  }

  return (
    <>
      {recommendedTitle && (
        <div className="recommended-banner">
          <span>
            <LocalizedText zh="为你推荐" en="Recommended" />
          </span>
          <span>{recommendedTitle}</span>
        </div>
      )}
      <div className="platform-strip recommended-first">
        {recommended.map((channel) => (
          <ChannelCard key={`${channel.audience}-${channel.platform}-recommended`} channel={channel} recommended />
        ))}
        <div className="section-divider">
          <span>
            <LocalizedText zh="全部下载入口" en="All download options" />
          </span>
        </div>
        {renderAllChannels(channels)}
      </div>
    </>
  );
}

function renderAllChannels(channels: DownloadChannel[]) {
  return channels.map((channel) => (
    <ChannelCard key={`${channel.audience}-${channel.platform}`} channel={channel} />
  ));
}
