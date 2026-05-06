const RELEASES_API_URL = "https://api.github.com/repos/bhrumom/fabushi/releases?per_page=8";

const DEFAULT_MIRROR_BASES = [
  {
    label: "GitHub 镜像 1",
    prefix: "https://mirror.ghproxy.com/https://github.com/",
  },
  {
    label: "GitHub 镜像 2",
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
    description: "正式版会在人工验收通过后，通过手动 GitHub Action 发布到官网。",
    primaryLabel: "等待正式版上线",
    primaryHref: "/contact",
    updateSummary: [
      "当前官网还没有挂出已经过人工验证的正式版安装包。",
      "验证完成后，维护者可以通过手动 GitHub Action 把指定 release 发布为官网正式版。",
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
        revalidate: 300,
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
        revalidate: 300,
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
      status: "GitHub Release Beta",
      title: "Android Beta",
      description: "直接使用最新 GitHub Release 的 APK 安装包，发布后官网会自动跟到这个入口。",
      primaryLabel: "下载 Android Beta",
      primaryHref: apkAsset.browser_download_url,
      version: release.tag_name,
      publishedAt: release.published_at ?? undefined,
      updateSummary: summary,
      mirrorLinks: buildMirrorLinks(apkAsset.browser_download_url),
      note: "如镜像暂时不可用，请改用 GitHub 原始下载链接。",
      releasePageHref: release.html_url,
    });
  }

  const testFlightStatus = await loadTestFlightStatus(release);
  if (testFlightStatus) {
    const uploaded = testFlightStatus.status === "uploaded";
    channels.push({
      platform: "iOS",
      audience: "beta",
      status: uploaded ? "TestFlight 构建已上传" : "等待 TestFlight 可加入",
      title: "iOS TestFlight Beta",
      description:
        uploaded
          ? "iOS beta 已经上传到 TestFlight。下一次 beta 同步工作流完成后，这里会显示直接加入链接。"
          : "iOS beta 会在 TestFlight 上传成功后自动补到官网入口。",
      primaryLabel: uploaded ? "查看 Beta 发布说明" : "等待 TestFlight 开放",
      primaryHref: release.html_url,
      version: testFlightStatus.build_number || release.tag_name,
      publishedAt: testFlightStatus.uploaded_at || release.published_at || undefined,
      updateSummary: summary,
      mirrorLinks: [],
      note:
        testFlightStatus.reason === "app_store_connect_credentials_not_configured"
          ? "当前仓库还没有配置 App Store Connect 上传凭据。"
          : uploaded
            ? "一旦公开 TestFlight 加入链接被同步进发布资产，这里会自动切成可直接加入。"
            : "当前还没有可公开加入的 TestFlight 入口。",
      releasePageHref: release.html_url,
    });
  }

  return {
    channels,
    notes: [
      "Android beta 下载入口会优先读取最新 GitHub Release 的 APK 资产。",
      "iOS beta 会在 TestFlight 上传状态成功后，随官网同步资产一起显示。",
      "国内访问 GitHub 较慢时，可以优先尝试页面里给出的镜像下载入口。",
    ],
  };
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
            "当前官网还没有拿到最新 beta 的同步资产，页面会先回退到 GitHub Release 基本信息。",
            "TestFlight 公共加入链接需要在发布同步工作流里配置后，才能直接显示在官网。",
          ],
  };
}
