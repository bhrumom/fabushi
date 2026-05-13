interface DownloadHrefMirrorLink {
  href: string;
}

interface DownloadHrefChannel {
  platform: "Android" | "iOS";
  primaryHref: string;
  mirrorLinks: DownloadHrefMirrorLink[];
}

export type DownloadRegion = "domestic" | "global" | "unknown";

export function isDomesticCountryCode(countryCode: string | null | undefined) {
  return countryCode?.trim().toUpperCase() === "CN";
}

export function getDownloadHrefForRegion(channel: DownloadHrefChannel, region: DownloadRegion) {
  if (channel.platform === "Android" && region === "domestic") {
    const mirrorHref = channel.mirrorLinks.find((item) => item.href.trim().length > 0)?.href;
    if (mirrorHref) {
      return mirrorHref;
    }
  }

  return channel.primaryHref;
}
