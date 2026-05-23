interface DownloadHrefChannel {
  platform: "Android" | "iOS";
  primaryHref: string;
  audience?: "beta" | "stable";
}

export type DownloadRegion = "domestic" | "global" | "unknown";

export function isDomesticCountryCode(countryCode: string | null | undefined) {
  return countryCode?.trim().toUpperCase() === "CN";
}

function normalizeHref(href: string | null | undefined) {
  return typeof href === "string" ? href.trim() : "";
}

export function getDownloadHrefForRegion(channel: DownloadHrefChannel, _region: DownloadRegion) {
  return normalizeHref(channel.primaryHref);
}
