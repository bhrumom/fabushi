interface DownloadHrefMirrorLink {
  href: string;
}

interface DownloadHrefChannel {
  platform: "Android" | "iOS";
  primaryHref: string;
  mirrorLinks: DownloadHrefMirrorLink[];
  audience?: "beta" | "stable";
}

export type DownloadRegion = "domestic" | "global" | "unknown";

export function isDomesticCountryCode(countryCode: string | null | undefined) {
  return countryCode?.trim().toUpperCase() === "CN";
}

function getAndroidDownloadProxyHref(channel: DownloadHrefChannel) {
  const audience = channel.audience === "stable" ? "stable" : "beta";
  return `/downloads/android-${audience}.apk`;
}

export function getDownloadHrefForRegion(channel: DownloadHrefChannel, _region: DownloadRegion) {
  if (channel.platform === "Android") {
    return getAndroidDownloadProxyHref(channel);
  }

  return channel.primaryHref;
}
