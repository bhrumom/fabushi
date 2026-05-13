"use client";

import { useEffect, useState } from "react";
import { DownloadLink } from "./download-link";

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

function getRecommendedTitle(platform: DetectedPlatform): string {
  switch (platform) {
    case "android":
      return "推荐 Android Beta";
    case "ios":
      return "推荐 iOS TestFlight";
    default:
      return "";
  }
}

function matchesPlatform(channel: DownloadChannel, platform: DetectedPlatform): boolean {
  if (platform === "android") return channel.platform === "Android";
  if (platform === "ios") return channel.platform === "iOS";
  return false;
}

export function DownloadClient({ channels }: { channels: DownloadChannel[] }) {
  const [platform, setPlatform] = useState<DetectedPlatform>("other");
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setPlatform(detectPlatform());
    setMounted(true);
  }, []);

  const recommended = platform !== "other" ? channels.filter((ch) => matchesPlatform(ch, platform)) : [];
  const recommendedTitle = getRecommendedTitle(platform);

  if (!mounted) {
    return <div className="platform-strip">{renderAllChannels(channels)}</div>;
  }

  if (recommended.length === 0) {
    return <div className="platform-strip">{renderAllChannels(channels)}</div>;
  }

  return (
    <>
      {recommendedTitle && (
        <div className="recommended-banner">
          <span>为你推荐</span>
          <span>{recommendedTitle}</span>
        </div>
      )}
      <div className="platform-strip recommended-first">
        {recommended.map((channel) => (
          <DownloadLink
            key={`${channel.audience}-${channel.platform}`}
            className="platform-row recommended"
            channel={channel}
          >
            <div>
              <span className="platform-name">
                {channel.title}
                <sup className="recommended-tag">推荐</sup>
              </span>
              <p>{channel.description}</p>
            </div>
            <div className="platform-meta">
              <strong>{channel.status}</strong>
              <span>{channel.primaryLabel}</span>
            </div>
          </DownloadLink>
        ))}
        <div className="section-divider">
          <span>全部下载入口</span>
        </div>
        {renderAllChannels(channels)}
      </div>
    </>
  );
}

function renderAllChannels(channels: DownloadChannel[]) {
  return channels.map((channel) => (
    <DownloadLink
      key={`${channel.audience}-${channel.platform}`}
      className="platform-row"
      channel={channel}
    >
      <div>
        <span className="platform-name">{channel.title}</span>
        <p>{channel.description}</p>
      </div>
      <div className="platform-meta">
        <strong>{channel.status}</strong>
        <span>{channel.primaryLabel}</span>
      </div>
    </DownloadLink>
  ));
}
