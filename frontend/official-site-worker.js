const ANDROID_DOWNLOAD_ROUTE = /\/downloads\/android-(beta|stable)\.apk$/i;
const DEFAULT_RELEASE_REPO = "bhrumom/fabushi";
const GITHUB_API_BASE = "https://api.github.com";
const DEFAULT_MIRROR_BASES = [
  {
    label: "国内镜像 1",
    prefix: "https://mirror.ghproxy.com/https://github.com/",
  },
  {
    label: "国内镜像 2",
    prefix: "https://ghfast.top/https://github.com/",
  },
  {
    label: "国内镜像 3",
    prefix: "https://gh-proxy.com/https://github.com/",
  },
];

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const match = url.pathname.match(ANDROID_DOWNLOAD_ROUTE);

    if (match) {
      return handleAndroidDownload(request, env, match[1]);
    }

    return env.ASSETS.fetch(request);
  },
};

async function handleAndroidDownload(request, env, audience) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: {
        Allow: "GET, HEAD",
      },
    });
  }

  const channel = await loadAndroidChannel(request, env, audience);
  if (!channel) {
    return renderDownloadFailure(
      request,
      audience,
      [],
      404,
      "当前还没有同步到可用的 Android 下载源。",
      "No Android download source is currently synced.",
    );
  }

  const sources = collectCandidateSources(channel);
  for (const source of sources) {
    try {
      const upstreamRequest = new Request(source.href, request);
      const upstreamResponse = await fetch(upstreamRequest);
      if (!upstreamResponse.ok) {
        continue;
      }

      return buildDownloadResponse(upstreamResponse, getDownloadFilename(channel, audience, source.href));
    } catch {
      continue;
    }
  }

  return renderDownloadFailure(
    request,
    audience,
    sources,
    502,
    "官网已经依次尝试 GitHub 原始地址和镜像源，但这一刻都没有成功响应。",
    "The official site tried the GitHub source and every mirror, but none responded successfully right now.",
  );
}

async function loadAndroidChannel(request, env, audience) {
  if (audience === "beta") {
    const latestReleaseChannel = await loadLatestReleaseAndroidChannel(env);
    if (latestReleaseChannel) {
      return latestReleaseChannel;
    }
  }

  return loadSyncedAndroidChannel(request, env, audience);
}

async function loadSyncedAndroidChannel(request, env, audience) {
  try {
    const releaseStateResponse = await env.ASSETS.fetch(new Request(new URL("/api/releases.json", request.url)));
    if (!releaseStateResponse.ok) {
      return null;
    }

    const releaseState = await releaseStateResponse.json();
    const key = audience === "stable" ? "stableChannels" : "betaChannels";
    const channels = Array.isArray(releaseState?.[key]) ? releaseState[key] : [];
    return channels.find((channel) => channel?.platform === "Android") ?? null;
  } catch {
    return null;
  }
}

async function loadLatestReleaseAndroidChannel(env) {
  try {
    const releaseRepo = getReleaseRepo(env);
    const response = await fetch(`${GITHUB_API_BASE}/repos/${releaseRepo}/releases/latest`, {
      headers: {
        Accept: "application/vnd.github+json",
      },
    });

    if (!response.ok) {
      return null;
    }

    const release = await response.json();
    if (!release || release.draft || !Array.isArray(release.assets)) {
      return null;
    }

    const apkAssets = release.assets.filter(isApkAsset);
    const apkAsset = apkAssets.find((asset) => asset.name.toLowerCase().includes("arm64")) ?? apkAssets[0];
    if (!apkAsset?.browser_download_url) {
      return null;
    }

    return {
      platform: "Android",
      audience: "beta",
      status: "Beta 自动同步",
      title: "Android Beta",
      description: "官网会优先读取最新 GitHub Release 的 Android 安装包。",
      primaryLabel: "下载 Android Beta",
      primaryHref: apkAsset.browser_download_url,
      version: typeof release.tag_name === "string" ? release.tag_name : undefined,
      publishedAt: typeof release.published_at === "string" ? release.published_at : undefined,
      updateSummary: [],
      mirrorLinks: buildMirrorLinks(apkAsset.browser_download_url, env),
      note: "如果同步快照还没刷新，官网会直接回退到最新 release 安装包。",
      releasePageHref: typeof release.html_url === "string" ? release.html_url : undefined,
    };
  } catch {
    return null;
  }
}

function isApkAsset(asset) {
  return Boolean(
    asset &&
      typeof asset.name === "string" &&
      asset.name.endsWith(".apk") &&
      typeof asset.browser_download_url === "string",
  );
}

function getReleaseRepo(env) {
  if (typeof env?.OFFICIAL_SITE_RELEASE_REPO === "string" && env.OFFICIAL_SITE_RELEASE_REPO.trim()) {
    return env.OFFICIAL_SITE_RELEASE_REPO.trim();
  }

  return DEFAULT_RELEASE_REPO;
}

function buildMirrorLinks(primaryHref, env) {
  if (!primaryHref.startsWith("https://github.com/")) {
    return [];
  }

  const path = primaryHref.slice("https://github.com/".length);
  return getMirrorBases(env).map((item) => ({
    label: item.label,
    href: `${item.prefix}${path}`,
  }));
}

function getMirrorBases(env) {
  const rawMirrorBases =
    typeof env?.OFFICIAL_SITE_GITHUB_MIRROR_BASES === "string" ? env.OFFICIAL_SITE_GITHUB_MIRROR_BASES : "";
  const configuredMirrors = rawMirrorBases
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [label, prefix] = line.split("|");
      if (!label || !prefix) {
        return null;
      }

      return {
        label: label.trim(),
        prefix: prefix.trim(),
      };
    })
    .filter(Boolean);

  return configuredMirrors.length > 0 ? configuredMirrors : DEFAULT_MIRROR_BASES;
}

function collectCandidateSources(channel) {
  const unique = [];
  const candidates = [
    {
      label: "GitHub 原始下载",
      href: channel?.primaryHref,
      kind: "primary",
    },
    ...(Array.isArray(channel?.mirrorLinks)
      ? channel.mirrorLinks.map((item, index) => ({
          label: item?.label || `备用镜像 ${index + 1}`,
          href: item?.href,
          kind: "mirror",
        }))
      : []),
  ];

  for (const candidate of candidates) {
    if (typeof candidate?.href !== "string") {
      continue;
    }

    const href = candidate.href.trim();
    if (!href || unique.some((item) => item.href === href)) {
      continue;
    }

    unique.push({
      label: candidate.label,
      href,
      kind: candidate.kind,
    });
  }

  return unique;
}

function sanitizeFilenamePart(value) {
  return String(value ?? "")
    .trim()
    .replace(/[^A-Za-z0-9._-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

function extractSourceFilename(source) {
  try {
    const url = new URL(source);
    const lastSegment = url.pathname.split("/").filter(Boolean).pop();
    if (lastSegment && lastSegment.endsWith(".apk")) {
      return lastSegment;
    }
  } catch {
    // Ignore filename parsing failures and fall back to the channel metadata.
  }

  return "";
}

function extractVariant(sourceFilename) {
  if (!sourceFilename) {
    return "";
  }

  const normalized = sourceFilename.toLowerCase();
  if (normalized.includes("arm64")) {
    return "arm64";
  }
  if (normalized.includes("armv7")) {
    return "armv7";
  }
  if (normalized.includes("universal")) {
    return "universal";
  }
  if (normalized.includes("x86_64")) {
    return "x86_64";
  }

  return "";
}

function getDownloadFilename(channel, audience, source) {
  const fallbackName = `fabushi-android-${audience}.apk`;
  const sourceFilename = extractSourceFilename(source);
  const version = sanitizeFilenamePart(channel?.version);

  if (version) {
    const parts = ["fabushi", "android", sanitizeFilenamePart(audience)];
    const variant = sanitizeFilenamePart(extractVariant(sourceFilename));
    if (variant && variant !== audience) {
      parts.push(variant);
    }
    parts.push(version);
    return `${parts.join("-")}.apk`;
  }

  return sourceFilename || fallbackName;
}

function buildDownloadResponse(upstreamResponse, filename) {
  const headers = new Headers(upstreamResponse.headers);
  headers.set("Cache-Control", "no-store");
  headers.set("Content-Type", headers.get("Content-Type") || "application/vnd.android.package-archive");
  headers.set("Content-Disposition", `attachment; filename="${filename}"; filename*=UTF-8''${encodeURIComponent(filename)}`);

  return new Response(upstreamResponse.body, {
    status: upstreamResponse.status,
    headers,
  });
}

function renderDownloadFailure(request, audience, sources, status, messageZh, messageEn) {
  const downloadPageHref = new URL("/download/", request.url).toString();
  const primarySource = sources.find((item) => item.kind === "primary") ?? null;
  const mirrorSources = sources.filter((item) => item.kind === "mirror");
  const primaryAction = primarySource
    ? `<a class="primary-download" href="${escapeHtml(primarySource.href)}">${escapeHtml(primarySource.label)} / Original download</a>`
    : "";
  const sourceLinks = mirrorSources.length
    ? mirrorSources
        .map(
          (source) =>
            `<a class="mirror-link" href="${escapeHtml(source.href)}">${escapeHtml(source.label)} / Mirror download</a>`,
        )
        .join("")
    : "";

  const body = `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Android 下载暂时不可用</title>
    <style>
      :root {
        color-scheme: dark;
      }
      body {
        margin: 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background: radial-gradient(circle at top, #1f2937 0%, #0f172a 58%, #020617 100%);
        color: #e2e8f0;
      }
      main {
        max-width: 720px;
        margin: 0 auto;
        padding: 48px 24px 64px;
      }
      h1 {
        margin-bottom: 12px;
        font-size: 32px;
      }
      p {
        line-height: 1.7;
      }
      .actions,
      .mirrors {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        margin-top: 20px;
      }
      .primary-download,
      .mirror-link,
      .back-link {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-height: 48px;
        padding: 0 18px;
        border-radius: 999px;
        text-decoration: none;
        font-weight: 600;
      }
      .primary-download {
        background: linear-gradient(135deg, #f7d774 0%, #d4af37 100%);
        color: #1f2937;
        box-shadow: 0 10px 24px rgba(212, 175, 55, 0.28);
      }
      .mirror-link {
        background: rgba(255, 255, 255, 0.08);
        border: 1px solid rgba(255, 255, 255, 0.14);
        color: #f8fafc;
      }
      .back-link {
        margin-top: 28px;
        background: transparent;
        border: 1px solid rgba(125, 211, 252, 0.35);
        color: #7dd3fc;
      }
      .hint {
        margin-top: 18px;
        color: #cbd5e1;
      }
    </style>
  </head>
  <body>
    <main>
      <h1>Android ${escapeHtml(audience)} download is temporarily unavailable</h1>
      <p>${escapeHtml(messageZh)}</p>
      <p>${escapeHtml(messageEn)}</p>
      ${primaryAction ? `<div class="actions">${primaryAction}</div>` : ""}
      ${sourceLinks ? `<div class="mirrors">${sourceLinks}</div>` : ""}
      <p class="hint">如原始下载较慢，可改用备用镜像继续安装。 If the original download is slow, try one of the mirror links.</p>
      <a class="back-link" href="${escapeHtml(downloadPageHref)}">返回下载页 / Back to download page</a>
    </main>
  </body>
</html>`;

  return new Response(body, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
