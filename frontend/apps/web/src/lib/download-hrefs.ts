interface DownloadHrefMirrorLink {
  label?: string;
  href: string;
}

interface DownloadHrefChannel {
  platform: "Android" | "iOS";
  primaryHref: string;
  mirrorLinks: DownloadHrefMirrorLink[];
  audience?: "beta" | "stable";
}

export interface DownloadFallbackLink {
  label: string;
  href: string;
  kind: "mirror" | "worker";
}

export type DownloadRegion = "domestic" | "global" | "unknown";

const ANDROID_BETA_WORKER_FALLBACK_HREF = "/downloads/android-beta.apk";
const ANDROID_BETA_WORKER_FALLBACK_LABEL = "Worker 兜底 / Worker fallback";

export function isDomesticCountryCode(countryCode: string | null | undefined) {
  return countryCode?.trim().toUpperCase() === "CN";
}

function normalizeHref(href: string | null | undefined) {
  return typeof href === "string" ? href.trim() : "";
}

function canUseAndroidWorkerFallback(channel: DownloadHrefChannel) {
  return channel.platform === "Android" && channel.audience === "beta";
}

export function getAndroidWorkerFallbackHref(channel: DownloadHrefChannel) {
  if (!canUseAndroidWorkerFallback(channel)) {
    return "";
  }

  return ANDROID_BETA_WORKER_FALLBACK_HREF;
}

export function getDownloadFallbackLinks(channel: DownloadHrefChannel): DownloadFallbackLink[] {
  const links: DownloadFallbackLink[] = [];
  const seen = new Set<string>();
  const primaryHref = normalizeHref(channel.primaryHref);

  const pushLink = (label: string, href: string, kind: DownloadFallbackLink["kind"]) => {
    const normalizedHref = normalizeHref(href);
    if (!normalizedHref || normalizedHref === primaryHref || seen.has(normalizedHref)) {
      return;
    }

    seen.add(normalizedHref);
    links.push({
      label,
      href: normalizedHref,
      kind,
    });
  };

  channel.mirrorLinks.forEach((item, index) => {
    pushLink(item.label?.trim() || `备用镜像 ${index + 1}`, item.href, "mirror");
  });

  pushLink(ANDROID_BETA_WORKER_FALLBACK_LABEL, getAndroidWorkerFallbackHref(channel), "worker");

  return links;
}

export function getDownloadHrefForRegion(channel: DownloadHrefChannel, _region: DownloadRegion) {
  if (channel.platform === "Android") {
    return normalizeHref(channel.primaryHref) || getDownloadFallbackLinks(channel)[0]?.href || "";
  }

  return normalizeHref(channel.primaryHref);
}
