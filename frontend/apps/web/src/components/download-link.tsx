"use client";

import { useEffect, useState, type AnchorHTMLAttributes } from "react";
import {
  getDownloadHrefForRegion,
  isDomesticCountryCode,
  type DownloadRegion,
} from "../lib/download-hrefs";
import { siteHref } from "../lib/site-url";

interface DownloadLinkChannel {
  platform: "Android" | "iOS";
  primaryHref: string;
  mirrorLinks: { href: string }[];
}

type DownloadLinkProps = Omit<AnchorHTMLAttributes<HTMLAnchorElement>, "href"> & {
  channel: DownloadLinkChannel;
};

let cachedRegion: DownloadRegion | null = null;
let pendingRegion: Promise<DownloadRegion> | null = null;

async function detectDownloadRegion(): Promise<DownloadRegion> {
  if (cachedRegion) {
    return cachedRegion;
  }

  if (!pendingRegion) {
    pendingRegion = fetchCloudflareTraceRegion().then((region) => {
      cachedRegion = region;
      return region;
    });
  }

  return pendingRegion;
}

async function fetchCloudflareTraceRegion(): Promise<DownloadRegion> {
  const controller = new AbortController();
  const timeoutId = window.setTimeout(() => controller.abort(), 1800);

  try {
    const response = await fetch("/cdn-cgi/trace", {
      cache: "no-store",
      signal: controller.signal,
    });

    if (!response.ok) {
      return "unknown";
    }

    const trace = await response.text();
    const countryCode = trace
      .split("\n")
      .find((line) => line.startsWith("loc="))
      ?.slice("loc=".length);

    if (isDomesticCountryCode(countryCode)) {
      return "domestic";
    }

    return countryCode ? "global" : "unknown";
  } catch {
    return "unknown";
  } finally {
    window.clearTimeout(timeoutId);
  }
}

export function DownloadLink({ channel, ...props }: DownloadLinkProps) {
  const [region, setRegion] = useState<DownloadRegion>("unknown");
  const { onClick, ...anchorProps } = props;

  useEffect(() => {
    if (channel.platform !== "Android" || channel.mirrorLinks.length === 0) {
      return;
    }

    let isActive = true;

    detectDownloadRegion().then((nextRegion) => {
      if (isActive) {
        setRegion(nextRegion);
      }
    });

    return () => {
      isActive = false;
    };
  }, []);

  const href = siteHref(getDownloadHrefForRegion(channel, region));
  const handleClick: AnchorHTMLAttributes<HTMLAnchorElement>["onClick"] = (event) => {
    onClick?.(event);

    if (event.defaultPrevented || region !== "unknown" || channel.platform !== "Android" || channel.mirrorLinks.length === 0) {
      return;
    }

    event.preventDefault();
    detectDownloadRegion().then((nextRegion) => {
      const nextHref = siteHref(getDownloadHrefForRegion(channel, nextRegion));
      setRegion(nextRegion);
      window.location.assign(nextHref);
    });
  };

  return <a {...anchorProps} href={href} onClick={handleClick} />;
}
