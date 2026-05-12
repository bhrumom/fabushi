const officialSiteReleaseRepo = process.env.NEXT_PUBLIC_OFFICIAL_SITE_RELEASE_REPO?.trim() || "bhrum/fabushi";
const iosTestFlightPublicUrl = process.env.NEXT_PUBLIC_IOS_TESTFLIGHT_PUBLIC_URL?.trim() || "";
const RELEASES_API_URL = `https://api.github.com/repos/${officialSiteReleaseRepo}/releases?per_page=8`;

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

interface OfficialSiteReleaseAssetState {
  channels: OfficialSiteChannel[];
  notes?: string[];
  generatedAt?: string;
}

export interface OfficialSiteReleaseCollection {
  betaChannels: OfficialSiteChannel[];
  stableChannels: OfficialSiteChannel[];
  notes: string[];
}

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
    const response = await fetch(url);

    if (!response.ok) {
      return null;
    }

    return await response.text();
  } catch {
    return null;
  }
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

  return lines.length > 0 ? lines.slice(0, 6) : [fallback];
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

  const updateSummary = Array.isArray(channel.updateSummary)
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
    updateSummary,
    mirrorLinks,
    note: typeof channel.note === "string" && channel.note.length > 0 ? channel.note : undefined,
    releasePageHref:
      typeof channel.releasePageHref === "string" && channel.releasePageHref.length > 0
        ? channel.releasePageHref
        : undefined,
  };
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

  return {
    channels,
    notes,
    generatedAt:
      typeof state.generatedAt === "string" && state.generatedAt.length > 0 ? state.generatedAt : undefined,
  };
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
    const primaryHref = uploaded && iosTestFlightPublicUrl ? iosTestFlightPublicUrl : release.html_url;
    channels.push({
      platform: "iOS",
      audience: "beta",
      status: uploaded ? "TestFlight 构建已上传" : "等待 TestFlight 可加入",
      title: "iOS TestFlight Beta",
      description:
        uploaded && iosTestFlightPublicUrl
          ? "iOS beta 已经上传到 TestFlight，点击即可打开公开加入页面。"
          : uploaded
            ? "iOS beta 已经上传到 TestFlight。公开加入链接开放后可直接加入。"
          : "iOS beta 会在 TestFlight 上传成功后自动补到官网入口。",
      primaryLabel: uploaded && iosTestFlightPublicUrl ? "加入 iOS TestFlight" : uploaded ? "查看 Beta 发布说明" : "等待 TestFlight 开放",
      primaryHref,
      version: testFlightStatus.build_number || release.tag_name,
      publishedAt: testFlightStatus.uploaded_at || release.published_at || undefined,
      updateSummary: summary,
      mirrorLinks: [],
      note:
        testFlightStatus.reason === "app_store_connect_credentials_not_configured"
          ? "当前仓库还没有配置 App Store Connect 上传凭据。"
          : uploaded && iosTestFlightPublicUrl
            ? "点击后会打开 Apple TestFlight 的公开加入页面。"
          : uploaded
            ? "一旦公开 TestFlight 加入链接被同步进发布资产，这里会自动切成可直接加入。"
            : "当前还没有可公开加入的 TestFlight 入口。",
      releasePageHref: release.html_url,
    });
  }

  return {
    channels,
    notes: [
      "Android Beta 会优先显示最新 APK。",
      "iOS TestFlight 可加入时会显示直接入口。",
      "国内访问较慢时，可以优先尝试页面里给出的镜像下载入口。",
    ],
  };
}

export async function getReleaseCollectionClient(): Promise<OfficialSiteReleaseCollection> {
  try {
    const res = await fetch("/api/releases.json");
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    return {
      betaChannels: (data.betaChannels ?? []).map(normalizeChannel).filter(Boolean) as OfficialSiteChannel[],
      stableChannels: (data.stableChannels ?? []).map(normalizeChannel).filter(Boolean) as OfficialSiteChannel[],
      notes: Array.isArray(data.notes) ? data.notes : [],
    };
  } catch {
    return { betaChannels: [], stableChannels: [], notes: [] };
  }
}

export async function getOfficialSiteReleaseCollection(): Promise<OfficialSiteReleaseCollection> {
  const releases = (await fetchJson<GitHubRelease[]>(RELEASES_API_URL)) ?? [];
  const publishedReleases = releases.filter((release) => !release.draft);

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
    betaChannels: betaState?.channels ?? [],
    stableChannels: stableState?.channels?.length ? stableState.channels : DEFAULT_STABLE_CHANNELS,
    notes:
      betaState?.notes?.length
        ? betaState.notes
        : [
            "当前 Beta 入口会先显示公开发布记录里的可用信息。",
            "TestFlight 公共加入链接开放后会显示直接入口。",
          ],
  };
}
