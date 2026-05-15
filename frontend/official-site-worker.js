const ANDROID_DOWNLOAD_ROUTE = /\/downloads\/android-(beta|stable)\.apk$/i;

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
    return renderDownloadFailure(request, audience, [], 404, "当前还没有同步到可用的 Android 下载源。", "No Android download source is currently synced.");
  }

  const sources = collectCandidateSources(channel);
  for (const source of sources) {
    try {
      const upstreamRequest = new Request(source, request);
      const upstreamResponse = await fetch(upstreamRequest);
      if (!upstreamResponse.ok) {
        continue;
      }

      return buildDownloadResponse(upstreamResponse, getDownloadFilename(channel, audience, source));
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

function collectCandidateSources(channel) {
  const unique = [];
  const candidates = [channel?.primaryHref, ...(Array.isArray(channel?.mirrorLinks) ? channel.mirrorLinks.map((item) => item?.href) : [])];

  for (const candidate of candidates) {
    if (typeof candidate !== "string") {
      continue;
    }

    const href = candidate.trim();
    if (!href || unique.includes(href)) {
      continue;
    }

    unique.push(href);
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
  const sourceLinks = sources.length
    ? sources
        .map((source, index) => `<li><a href="${escapeHtml(source)}">备用源 ${index + 1}</a></li>`)
        .join("")
    : "";

  const body = `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Android 下载暂时不可用</title>
    <style>
      body {
        margin: 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background: #0f172a;
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
      a {
        color: #7dd3fc;
      }
      ul {
        padding-left: 20px;
      }
    </style>
  </head>
  <body>
    <main>
      <h1>Android ${escapeHtml(audience)} download is temporarily unavailable</h1>
      <p>${escapeHtml(messageZh)}</p>
      <p>${escapeHtml(messageEn)}</p>
      <p><a href="${escapeHtml(downloadPageHref)}">返回下载页 / Back to download page</a></p>
      ${sourceLinks ? `<ul>${sourceLinks}</ul>` : ""}
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
