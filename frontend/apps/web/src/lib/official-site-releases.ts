const iosTestFlightPublicUrl = process.env.NEXT_PUBLIC_IOS_TESTFLIGHT_PUBLIC_URL?.trim() || "";
const iosAppStoreUrl = "https://apps.apple.com/cn/app/%E5%A4%A7%E4%B9%98/id6758606957";
const configuredReleaseApiBaseUrl =
  process.env.NEXT_PUBLIC_OFFICIAL_SITE_RELEASE_API_BASE_URL?.trim() ||
  process.env.NEXT_PUBLIC_FABUSHI_API_BASE_URL?.trim() ||
  process.env.NEXT_PUBLIC_API_BASE_URL?.trim() ||
  "https://api.ombhrum.com";

export interface OfficialSiteMirrorLink {
  label: string;
  href: string;
}

export interface OfficialSiteChannel {
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
  mirrorLinks: OfficialSiteMirrorLink[];
  note?: string;
  releasePageHref?: string;
}

export interface OfficialSiteScreenshots {
  "global-dharma"?: string | null;
  "start-meditation"?: string | null;
  "immersive-meditation"?: string | null;
  "main-sutra"?: string | null;
  "group-practice"?: string | null;
  "global-ranking"?: string | null;
  "global-donation"?: string | null;
  "global-donation-leaderboard"?: string | null;
  capturedAt?: string;
}

export interface OfficialSiteReleaseEntry {
  tag: string;
  title: string;
  publishedAt: string;
  htmlUrl: string;
  summary: string[];
}

export interface OfficialSiteReleaseCollection {
  betaChannels: OfficialSiteChannel[];
  stableChannels: OfficialSiteChannel[];
  screenshots: OfficialSiteScreenshots;
  releases: OfficialSiteReleaseEntry[];
  notes: string[];
}

export const FALLBACK_SCREENSHOTS: Record<string, string> = {
  "global-dharma": "/product/global-dharma.png",
  "start-meditation": "/product/start-meditation.png",
  "immersive-meditation": "/product/immersive-meditation.png",
  "main-sutra": "/product/main-sutra.png",
  "group-practice": "/product/group-practice.png",
  "global-ranking": "/product/global-ranking.png",
  "global-donation": "/product/global-donation.png",
  "global-donation-leaderboard": "/product/global-donation-leaderboard.png",
};

const CHANNEL_ORDER: Array<Pick<OfficialSiteChannel, "audience" | "platform">> = [
  { audience: "beta", platform: "Android" },
  { audience: "beta", platform: "iOS" },
  { audience: "stable", platform: "Android" },
  { audience: "stable", platform: "iOS" },
];

const IOS_STABLE_CHANNEL: OfficialSiteChannel = {
  platform: "iOS",
  audience: "stable",
  status: "App Store 已上架",
  title: "iOS 正式版",
  description: "已在 App Store 上架，适合 iPhone 和 iPad 用户直接安装。",
  primaryLabel: "在 App Store 下载",
  primaryHref: iosAppStoreUrl,
  version: "1.0",
  publishedAt: "2026-06-01",
  updateSummary: [
    "iOS 1.0 正式版已在 App Store 发布。",
    "中国大陆可售状态已完成备案信息同步。",
  ],
  mirrorLinks: [],
  note: "点击后会打开 Apple App Store 页面。",
};

const DEFAULT_STABLE_CHANNELS: OfficialSiteChannel[] = [
  {
    platform: "Android",
    audience: "stable",
    status: "待人工验证",
    title: "Android 正式版",
    description: "正式版会在人工验收通过后开放，适合首次安装和转发。",
    primaryLabel: "等待正式版上线",
    primaryHref: "/contact",
    updateSummary: [
      "当前官网还没有挂出已经过人工验证的正式版安装包。",
      "验证完成后，这里会切换为可公开下载的正式版入口。",
    ],
    mirrorLinks: [],
    note: "正式版上线后，这里会显示已经同步到 Cloudflare 的下载地址。",
  },
  IOS_STABLE_CHANNEL,
];

function trimTrailingSlash(value: string) {
  return value.endsWith("/") ? value.slice(0, -1) : value;
}

function buildReleaseApiUrl() {
  return `${trimTrailingSlash(configuredReleaseApiBaseUrl)}/api/site/releases`;
}

function isTestFlightJoinUrl(href: string): boolean {
  return href.includes("testflight.apple.com");
}

function uniqueLines(items: string[], limit = 4): string[] {
  const seen = new Set<string>();
  const lines: string[] = [];
  for (const item of items) {
    const normalized = item.trim();
    if (!normalized) continue;
    const key = normalized.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    lines.push(normalized);
    if (lines.length >= limit) break;
  }
  return lines;
}

function normalizeChannel(input: unknown): OfficialSiteChannel | null {
  if (!input || typeof input !== "object") {
    return null;
  }

  const channel = input as Record<string, unknown>;
  if (
    (channel.platform !== "Android" && channel.platform !== "iOS") ||
    (channel.audience !== "beta" && channel.audience !== "stable") ||
    typeof channel.status !== "string" ||
    typeof channel.title !== "string" ||
    typeof channel.description !== "string" ||
    typeof channel.primaryLabel !== "string" ||
    typeof channel.primaryHref !== "string"
  ) {
    return null;
  }

  return {
    platform: channel.platform as OfficialSiteChannel["platform"],
    audience: channel.audience as OfficialSiteChannel["audience"],
    status: channel.status as string,
    title: channel.title as string,
    description: channel.description as string,
    primaryLabel: channel.primaryLabel as string,
    primaryHref: channel.primaryHref as string,
    version: typeof channel.version === "string" && channel.version.length > 0 ? channel.version : undefined,
    publishedAt:
      typeof channel.publishedAt === "string" && channel.publishedAt.length > 0 ? channel.publishedAt : undefined,
    updateSummary: uniqueLines(
      Array.isArray(channel.updateSummary)
        ? channel.updateSummary.filter((item): item is string => typeof item === "string")
        : [],
    ),
    mirrorLinks: Array.isArray(channel.mirrorLinks)
      ? channel.mirrorLinks
          .filter((item): item is Record<string, unknown> => typeof item === "object" && item !== null)
          .map((item) => ({
            label: typeof item.label === "string" ? item.label : "",
            href: typeof item.href === "string" ? item.href : "",
          }))
          .filter((item) => item.href.length > 0)
      : [],
    note: typeof channel.note === "string" && channel.note.length > 0 ? channel.note : undefined,
    releasePageHref:
      typeof channel.releasePageHref === "string" && channel.releasePageHref.length > 0
        ? channel.releasePageHref
        : undefined,
  };
}

function normalizeScreenshots(input: unknown): OfficialSiteScreenshots | undefined {
  if (!input || typeof input !== "object") return undefined;
  const obj = input as Record<string, unknown>;
  const screenshots: OfficialSiteScreenshots = {};
  let hasAny = false;
  for (const key of Object.keys(FALLBACK_SCREENSHOTS)) {
    const value = obj[key];
    if (typeof value === "string" && value.length > 0) {
      screenshots[key as keyof OfficialSiteScreenshots] = value;
      hasAny = true;
    }
  }
  if (typeof obj.capturedAt === "string" && obj.capturedAt.length > 0) {
    screenshots.capturedAt = obj.capturedAt;
    hasAny = true;
  }
  return hasAny ? screenshots : undefined;
}

function normalizeReleaseEntries(input: unknown): OfficialSiteReleaseEntry[] {
  if (!Array.isArray(input)) return [];
  return input
    .filter((item): item is Record<string, unknown> => typeof item === "object" && item !== null)
    .map((item) => ({
      tag: typeof item.tag === "string" ? item.tag : "",
      title: typeof item.title === "string" ? item.title : typeof item.tag === "string" ? item.tag : "",
      publishedAt: typeof item.publishedAt === "string" ? item.publishedAt : "",
      htmlUrl: typeof item.htmlUrl === "string" ? item.htmlUrl : "",
      summary: uniqueLines(
        Array.isArray(item.summary)
          ? item.summary.filter((value): value is string => typeof value === "string")
          : [],
      ),
    }))
    .filter((entry) => entry.tag.length > 0);
}

function normalizeReleaseCollectionRecord(data: Record<string, unknown>): OfficialSiteReleaseCollection {
  const channels = Array.isArray(data.channels)
    ? data.channels.map(normalizeChannel).filter((item): item is OfficialSiteChannel => item !== null)
    : [];
  const betaChannels =
    Array.isArray(data.betaChannels) && data.betaChannels.length > 0
      ? data.betaChannels.map(normalizeChannel).filter((item): item is OfficialSiteChannel => item !== null)
      : channels.filter((channel) => channel.audience === "beta");
  const stableChannels =
    Array.isArray(data.stableChannels) && data.stableChannels.length > 0
      ? data.stableChannels.map(normalizeChannel).filter((item): item is OfficialSiteChannel => item !== null)
      : channels.filter((channel) => channel.audience === "stable");

  return {
    betaChannels,
    stableChannels,
    screenshots: normalizeScreenshots(data.screenshots) ?? {},
    releases: normalizeReleaseEntries(data.releases),
    notes: Array.isArray(data.notes) ? data.notes.filter((item): item is string => typeof item === "string") : [],
  };
}

function getChannelKey(channel: Pick<OfficialSiteChannel, "audience" | "platform">): string {
  return `${channel.audience}:${channel.platform}`;
}

function mergeChannels(primary: OfficialSiteChannel[], fallback: OfficialSiteChannel[]): OfficialSiteChannel[] {
  const merged = new Map<string, OfficialSiteChannel>();

  for (const channel of fallback) {
    merged.set(getChannelKey(channel), channel);
  }

  for (const channel of primary) {
    merged.set(getChannelKey(channel), channel);
  }

  const orderedChannels = CHANNEL_ORDER.map((channel) => merged.get(getChannelKey(channel))).filter(
    (channel): channel is OfficialSiteChannel => Boolean(channel),
  );
  const seenKeys = new Set(orderedChannels.map((channel) => getChannelKey(channel)));
  const remainingChannels = Array.from(merged.values()).filter((channel) => !seenKeys.has(getChannelKey(channel)));

  return [...orderedChannels, ...remainingChannels];
}

function applyConfiguredIosTestFlightChannel(channel: OfficialSiteChannel): OfficialSiteChannel {
  if (channel.platform !== "iOS" || channel.audience !== "beta" || !iosTestFlightPublicUrl) {
    return channel;
  }

  if (isTestFlightJoinUrl(channel.primaryHref)) {
    return channel;
  }

  return {
    ...channel,
    status: channel.status.includes("TestFlight") ? channel.status : "TestFlight 已开放",
    description: "iOS beta 已经配置为通过 Apple TestFlight 分发，点击即可打开公开加入页面。",
    primaryLabel: "下载 iOS 测试版",
    primaryHref: iosTestFlightPublicUrl,
    note: "点击后会打开 Apple TestFlight 的公开加入页面。",
  };
}

function applyConfiguredIosTestFlightChannels(channels: OfficialSiteChannel[]): OfficialSiteChannel[] {
  return channels.map((channel) => applyConfiguredIosTestFlightChannel(channel));
}

function applyIosStableAppStoreChannel(channel: OfficialSiteChannel): OfficialSiteChannel {
  if (channel.platform !== "iOS" || channel.audience !== "stable") {
    return channel;
  }

  return {
    ...channel,
    ...IOS_STABLE_CHANNEL,
    mirrorLinks: channel.mirrorLinks.length > 0 ? channel.mirrorLinks : IOS_STABLE_CHANNEL.mirrorLinks,
    releasePageHref: channel.releasePageHref,
  };
}

function applyIosStableAppStoreChannels(channels: OfficialSiteChannel[]): OfficialSiteChannel[] {
  return channels.map((channel) => applyIosStableAppStoreChannel(channel));
}

async function fetchOfficialSiteReleaseCollectionFromCloudflare(isClient: boolean): Promise<OfficialSiteReleaseCollection | null> {
  const url = buildReleaseApiUrl();

  try {
    const response = await fetch(
      url,
      isClient
        ? {
            headers: {
              Accept: "application/json",
            },
          }
        : {
            headers: {
              Accept: "application/json",
            },
            next: {
              revalidate: 300,
            },
          },
    );

    if (!response.ok) {
      return null;
    }

    const data = (await response.json()) as Record<string, unknown>;
    return normalizeReleaseCollectionRecord(data);
  } catch {
    return null;
  }
}

function buildFallbackCollection(): OfficialSiteReleaseCollection {
  return {
    betaChannels: [],
    stableChannels: DEFAULT_STABLE_CHANNELS,
    screenshots: {},
    releases: [],
    notes: [
      "官网版本说明正在从 Cloudflare 版本策略同步。",
      "如果当前没有显示版本列表，稍后刷新即可看到最新结果。",
    ],
  };
}

function finalizeCollection(collection: OfficialSiteReleaseCollection): OfficialSiteReleaseCollection {
  return {
    betaChannels: applyConfiguredIosTestFlightChannels(collection.betaChannels),
    stableChannels: applyIosStableAppStoreChannels(mergeChannels(collection.stableChannels, DEFAULT_STABLE_CHANNELS)),
    screenshots: collection.screenshots,
    releases: collection.releases,
    notes: collection.notes,
  };
}

export async function getReleaseCollectionClient(): Promise<OfficialSiteReleaseCollection> {
  const collection = await fetchOfficialSiteReleaseCollectionFromCloudflare(true);
  return finalizeCollection(collection ?? buildFallbackCollection());
}

export async function getOfficialSiteReleaseCollection(): Promise<OfficialSiteReleaseCollection> {
  const collection = await fetchOfficialSiteReleaseCollectionFromCloudflare(false);
  return finalizeCollection(collection ?? buildFallbackCollection());
}
