"use client";

import type { AnchorHTMLAttributes } from "react";
import { getDownloadHrefForRegion } from "../lib/download-hrefs";
import { siteHref } from "../lib/site-url";

interface DownloadLinkChannel {
  platform: "Android" | "iOS";
  primaryHref: string;
  mirrorLinks: { href: string }[];
  audience?: "beta" | "stable";
}

type DownloadLinkProps = Omit<AnchorHTMLAttributes<HTMLAnchorElement>, "href"> & {
  channel: DownloadLinkChannel;
};

export function DownloadLink({ channel, ...props }: DownloadLinkProps) {
  const href = siteHref(getDownloadHrefForRegion(channel, "unknown"));
  return <a {...props} href={href} />;
}
