import { readFile } from "node:fs/promises";
import path from "node:path";

const officialSiteReleaseRepo = process.env.NEXT_PUBLIC_OFFICIAL_SITE_RELEASE_REPO?.trim() || "bhrumom/fabushi";
const iosTestFlightPublicUrl = process.env.NEXT_PUBLIC_IOS_TESTFLIGHT_PUBLIC_URL?.trim() || "";
const RELEASES_API_URL = `https://api.github.com/repos/${officialSiteReleaseRepo}/releases?per_page=8`;
const PERSISTED_RELEASES_PATH = path.join(process.cwd(), "public", "api", "releases.json");

const DEFAULT_MIRROR_BASES = [
  {
    label: "国内镜像 1",
    prefix: "https://mirror.ghproxy.com/https://github.com/",
  },
  {
    label: "国内镜像 2",
    prefix: "https://ghfast.top/https://github.com/",
  },
] as const;

const TECHNICAL_RELEASE_LINE_PATTERN =
  /(^pr\s*#\d+)|\b(ci|workflow|checkout|token|sha|commit|submodule|api|github|dispatch|globals\.css|page\.tsx|framer-motion|bentocard)\b|^\[(x| )\]/i;

const RELEASE_SUMMARY_RULES = [
  {
    pattern: /ui\/ux|bento|design|layout|hero section|spotlight hover|scroll reveal|floating screenshots|dark theme/i,
    text: "Improved the website interface and browsing experience.",
  },
  {
    pattern: /cache|stale|refresh/i,
    text: "Reduced cases where older content stayed visible after an update.",
  },
  {
    pattern: /android|apk|mirror/i,
    text: "Improved Android download reliability and install guidance.",
  },
  {
    pattern: /ios|testflight/i,
    text: "Improved iOS testing access and release readiness.",
  },
  {
    pattern: /sync|release publish|release state|latest release|immutable release|published/i,
    text: "Made update delivery and version syncing more reliable.",
  },
  {
    pattern: /screenshot|preview/i,
    text: "Updated product previews and release details.",
  },
] as const;

type GitHubReleaseAsset = {
  name: string;
  browser_download_url: string;
};

type GitHubRelease = {
  tag_name: string;
  name: string | null;
  body: string | null;
  html_url: string;
  published_at: string | null;
  assets: GitHubReleaseAsset[];
  draft: boolean;
};

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

interface OfficialSiteReleaseAssetState {
  channels: OfficialSiteChannel[];
  screenshots?: OfficialSiteScreenshots;
  releases?: OfficialSiteReleaseEntry[];
  notes?: string[];
  generatedAt?: string;
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
    note: "正式版上线后，这里会显示 APK 原始下载地址和面向国内用户的镜像链接。",
  },
];

async function fetchJson<T>(url: string): Promise<T | null> {
  try {
    const response = await fetch(url, {
      headers: {
        Accept: "application/vnd.github+json",
      },
      next: {
        revalidate: 600,
      },
    });

    if (!response.ok) {
      return null;
    }

    return (await response.json()) as T;
  } catch {
    return null;
  }
}

async function fetchText(url: string): Promise<string | null> {
  try {
    const response = await fetch(url, {
      next: {
        revalidate: 600,
      },
    });

    if (!response.ok) {
      return null;
    }

    return await response.text();
  } catch {
    return null;
  }
}

function normalizeReleaseSummaryLine(line: string): string {
  return line
    .replace(/`/g, "")
    .replace(/^pr\s*#\d+:\s*/i, "")
    .replace(/^\[(x| )\]\s*/i, "")
    .replace(/\s+/g, " ")
    .trim();
}

function buildFallbackReleaseSummary(title: string): string[] {
  const normalizedTitle = title.toLowerCase();

  if (normalizedTitle.includes("ios") || normalizedTitle.includes("testflight")) {
    return [
      "Improved iOS testing access and release readiness.",
      "Refined how the latest version details are presented.",
    ];
  }

  if (normalizedTitle.includes("android") || normalizedTitle.includes("apk")) {
    return [
      "Improved Android download reliability and install guidance.",
      "Refined how the latest version details are presented.",
    ];
  }

  return [
    "Improved the download experience and version details.",
    "Refined overall stability and page presentation.",
  ];
}

function mapReleaseLineToUserFacing(line: string): string | null {
  const normalized = normalizeReleaseSummaryLine(line);
  if (!normalized) {
    return null;
  }

  for (const rule of RELEASE_SUMMARY_RULES) {
    if (rule.pattern.test(normalized)) {
      return rule.text;
    }
  }

  if (TECHNICAL_RELEASE_LINE_PATTERN.test(normalized)) {
    return null;
  }

  return normalized;
}

function sanitizeReleaseSummaries(lines: string[], fallback: string): string[] {
  const seen = new Set<string>();
  const summary: string[] = [];

  for (const line of lines) {
    const userFacingLine = mapReleaseLineToUserFacing(line);
    if (!userFacingLine) {
      continue;
    }

    const key = userFacingLine.toLowerCase();
    if (seen.has(key)) {
      continue;
    }

    seen.add(key);
    summary.push(userFacingLine);
  }

  return summary.length > 0 ? summary.slice(0, 4) : buildFallbackReleaseSummary(fallback);
}

function extractUpdateSummary(body: string | null | undefined, fallback: string): string[] {
  const content = body ?? "";
  const sectionMatch = content.match(/## Included changes([\s\S]*?)(?:\n## |$)/);
  const source = sectionMatch?.[1] ?? content;
  const lines = source
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.startsWith("- "))
    .map((line) => line.replace(/^-\s*/, "").trim())
    .filter(Boolean);

  return sanitizeReleaseSummaries(lines, fallback);
}

function buildMirrorLinks(primaryHref: string): OfficialSiteMirrorLink[] {
  if (!primaryHref.startsWith("https://github.com/")) {
    return [];
  }

  const path = primaryHref.slice("https://github.com/".length);
  return DEFAULT_MIRROR_BASES.map((item) => ({
    label: item.label,
    href: `${item.prefix}${path}`,
  }));
}

function buildReleaseEntries(releases: GitHubRelease[]): OfficialSiteReleaseEntry[] {
  return releases
    .filter((release) => !release.draft)
    .slice(0, 5)
    .map((release) => ({
      tag: release.tag_name,
      title: release.name?.trim() || release.tag_name,
      publishedAt: release.published_at ?? "",
      htmlUrl: release.html_url,
      summary: extractUpdateSummary(release.body, release.name ?? release.tag_name),
    }))
    .filter((entry) => entry.tag.length > 0);
}

function isTestFlightJoinUrl(href: string): boolean {
  return href.includes("testflight.apple.com");
}

function applyConfiguredIosTestFlightChannel(channel: OfficialSiteChannel): OfficialSiteChannel {
  if (channel.platform !== "iOS" || channel.audience !== "beta" || !iosTestFlightPublicUrl) {
    return channel;
  }

  if (isTestFlightJoinUrl(channel.primaryHref)) {
    return channel;
  }

  const pointsToReleasePage =
    !channel.primaryHref ||
    channel.primaryHref.startsWith("https://github.com/") ||
    channel.primaryHref.startsWith("/releases") ||
    channel.primaryHref === channel.releasePageHref;

  if (!pointsToReleasePage) {
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

  const rawSummary = Array.isArray(channel.updateSummary)
    ? channel.updateSummary.filter((item): item is string => typeof item === "string" && item.length > 0)
    : [];

  const mirrorLinks = Array.isArray(channel.mirrorLinks)
    ? channel.mirrorLinks
        .filter(
          (item): item is OfficialSiteMirrorLink =>
            Boolean(item) &&
            typeof item === "object" &&
            typeof (item as OfficialSiteMirrorLink).label === "string" &&
            typeof (item as OfficialSiteMirrorLink).href === "string",
        )
        .map((item) => ({ label: item.label, href: item.href }))
    : [];

  return {
    platform: channel.platform as OfficialSiteChannel["platform"],
    audience: channel.audience as OfficialSiteChannel["audience"],
    status: channel.status,
    title: channel.title,
    description: channel.description,
    primaryLabel: channel.primaryLabel,
    primaryHref: channel.primaryHref,
    version: typeof channel.version === "string" && channel.version.length > 0 ? channel.version : undefined,
    publishedAt:
      typeof channel.publishedAt === "string" && channel.publishedAt.length > 0 ? channel.publishedAt : undefined,
    updateSummary: sanitizeReleaseSummaries(rawSummary, channel.title),
    mirrorLinks,
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
      summary: sanitizeReleaseSummaries(
        Array.isArray(item.summary)
          ? item.summary.filter((s): s is string => typeof s === "string" && s.length > 0)
          : [],
        typeof item.title === "string" ? item.title : typeof item.tag === "string" ? item.tag : "Latest update",
      ),
    }))
    .filter((entry) => entry.tag.length > 0);
}

function normalizeState(input: unknown): OfficialSiteReleaseAssetState | null {
  if (!input || typeof input !== "object") {
    return null;
  }

  const state = input as Record<string, unknown>;
  if (!Array.isArray(state.channels)) {
    return null;
  }

  const channels = state.channels.map(normalizeChannel).filter((item): item is OfficialSiteChannel => item !== null);
  const notes = Array.isArray(state.notes)
    ? state.notes.filter((item): item is string => typeof item === "string" && item.length > 0)
    : [];
  const screenshots = normalizeScreenshots(state.screenshots);
  const releases = normalizeReleaseEntries(state.releases);

  return {
    channels,
    screenshots,
    releases,
    notes,
    generatedAt:
      typeof state.generatedAt === "string" && state.generatedAt.length > 0 ? state.generatedAt : undefined,
  };
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

async function loadPersistedReleaseCollection(): Promise<OfficialSiteReleaseCollection | null> {
  try {
    const content = await readFile(PERSISTED_RELEASES_PATH, "utf-8");
    return normalizeReleaseCollectionRecord(JSON.parse(content) as Record<string, unknown>);
  } catch {
    return null;
  }
}

async function loadStateAsset(
  release: GitHubRelease,
  assetName: "OFFICIAL_SITE_RELEASE_STATE.json" | "OFFICIAL_SITE_STABLE_RELEASE_STATE.json",
): Promise<OfficialSiteReleaseAssetState | null> {
  const asset = release.assets.find((item) => item.name === assetName);
  if (!asset) {
    return null;
  }

  const payload = await fetchJson<unknown>(asset.browser_download_url);
  return normalizeState(payload);
}

async function loadTestFlightStatus(release: GitHubRelease): Promise<Record<string, string> | null> {
  const asset = release.assets.find((item) => item.name === "TESTFLIGHT_UPLOAD_STATUS.txt");
  if (!asset) {
    return null;
  }

  const content = await fetchText(asset.browser_download_url);
  if (!content) {
    return null;
  }

  const status: Record<string, string> = {};
  for (const line of content.split("\n")) {
    const separatorIndex = line.indexOf("=");
    if (separatorIndex <= 0) {
      continue;
    }

    const key = line.slice(0, separatorIndex).trim();
    const value = line.slice(separatorIndex + 1).trim();
    if (key) {
      status[key] = value;
    }
  }

  return status;
}

async function buildFallbackBetaState(release: GitHubRelease): Promise<OfficialSiteReleaseAssetState> {
  const summary = extractUpdateSummary(release.body, release.name ?? release.tag_name);
  const channels: OfficialSiteChannel[] = [];
  const apkAsset = release.assets.find((item) => item.name.endsWith(".apk"));

  if (apkAsset) {
    channels.push({
      platform: "Android",
      audience: "beta",
      status: "Beta 自动同步",
      title: "Android Beta",
      description: "最新 Android 测试包，适合尽快体验新版本并反馈问题。",
      primaryLabel: "下载 Android Beta",
      primaryHref: apkAsset.browser_download_url,
      version: release.tag_name,
      publishedAt: release.published_at ?? undefined,
      updateSummary: summary,
      mirrorLinks: buildMirrorLinks(apkAsset.browser_download_url),
      note: "如镜像暂时不可用，请使用原始下载链接。",
      releasePageHref: release.html_url,
    });
  }

  const testFlightStatus = await loadTestFlightStatus(release);
  if (testFlightStatus) {
    const uploaded = testFlightStatus.status === "uploaded";
    const publicJoinHref = iosTestFlightPublicUrl || testFlightStatus.public_url || testFlightStatus.public_link;
    const primaryHref = uploaded && publicJoinHref ? publicJoinHref : release.html_url;
    channels.push({
      platform: "iOS",
      audience: "beta",
      status: uploaded ? "TestFlight 已开放" : "等待 TestFlight 可加入",
      title: "iOS TestFlight Beta",
      description:
        uploaded && publicJoinHref
          ? "iOS beta 已经上传到 TestFlight，点击即可打开公开加入页面。"
          : uploaded
            ? "iOS beta 已经上传到 TestFlight。公开加入链接同步后可直接加入。"
            : "iOS beta 会在 TestFlight 上传成功后自动补到官网入口。",
      primaryLabel: uploaded ? "下载 iOS 测试版" : "等待 iOS 测试版开放",
      primaryHref,
      version: testFlightStatus.build_number || release.tag_name,
      publishedAt: testFlightStatus.uploaded_at || release.published_at || undefined,
      updateSummary: summary,
      mirrorLinks: [],
      note:
        testFlightStatus.reason === "app_store_connect_credentials_not_configured"
          ? "当前仓库还没有配置 App Store Connect 上传凭据。"
          : uploaded && publicJoinHref
            ? "点击后会打开 Apple TestFlight 的公开加入页面。"
            : uploaded
              ? "已经同步到发布记录，公开 TestFlight 加入链接配置后这里会自动切成直达入口。"
              : "当前还没有可公开加入的 TestFlight 入口。",
      releasePageHref: release.html_url,
    });
  }

  return {
    channels,
    releases: buildReleaseEntries([release]),
    notes: [
      "Android Beta 会优先显示最新 APK。",
      "iOS TestFlight 可加入时会显示直接入口。",
      "国内访问较慢时，可以优先尝试页面里给出的镜像下载入口。",
    ],
  };
}

export async function getReleaseCollectionClient(): Promise<OfficialSiteReleaseCollection> {
  try {
    const res = await fetch("/api/releases.json", {
      next: {
        revalidate: 300,
      },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as Record<string, unknown>;
    const collection = normalizeReleaseCollectionRecord(data);
    return {
      ...collection,
      betaChannels: applyConfiguredIosTestFlightChannels(collection.betaChannels),
    };
  } catch {
    return { betaChannels: [], stableChannels: [], screenshots: {}, releases: [], notes: [] };
  }
}

export async function getOfficialSiteReleaseCollection(): Promise<OfficialSiteReleaseCollection> {
  const persistedCollection = await loadPersistedReleaseCollection();
  const releases = (await fetchJson<GitHubRelease[]>(RELEASES_API_URL)) ?? [];
  const publishedReleases = releases.filter((release) => !release.draft);
  const fallbackReleaseEntries = buildReleaseEntries(publishedReleases);

  const betaRelease = publishedReleases[0] ?? null;
  const syncedBetaState = betaRelease
    ? await loadStateAsset(betaRelease, "OFFICIAL_SITE_RELEASE_STATE.json")
    : null;
  const betaState = betaRelease
    ? syncedBetaState && syncedBetaState.channels.length > 0
      ? syncedBetaState
      : await buildFallbackBetaState(betaRelease)
    : null;

  const stableRelease =
    publishedReleases.find((release) =>
      release.assets.some((asset) => asset.name === "OFFICIAL_SITE_STABLE_RELEASE_STATE.json"),
    ) ?? null;
  const stableState = stableRelease
    ? await loadStateAsset(stableRelease, "OFFICIAL_SITE_STABLE_RELEASE_STATE.json")
    : null;

  return {
    betaChannels: applyConfiguredIosTestFlightChannels(
      mergeChannels(betaState?.channels ?? [], persistedCollection?.betaChannels ?? []),
    ),
    stableChannels: mergeChannels(
      stableState?.channels?.length ? stableState.channels : DEFAULT_STABLE_CHANNELS,
      persistedCollection?.stableChannels ?? [],
    ),
    screenshots: betaState?.screenshots ?? persistedCollection?.screenshots ?? {},
    releases:
      betaState?.releases?.length
        ? betaState.releases
        : persistedCollection?.releases?.length
          ? persistedCollection.releases
          : fallbackReleaseEntries,
    notes:
      betaState?.notes?.length
        ? betaState.notes
        : persistedCollection?.notes?.length
          ? persistedCollection.notes
          : [
              "当前 Beta 入口会先显示公开发布记录里的可用信息。",
              "TestFlight 公共加入链接开放后会显示直接入口。",
            ],
  };
}
