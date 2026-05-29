const CBETA_PROXY_ROUTE = /^\/api\/cbeta\/(.+)$/;
const APP_PROXY_ROUTE = /^\/api\/app\/(.+)$/;
const CBETA_API_BASE = "http://144.24.17.21.sslip.io:3000";
const APP_API_BASE = "https://api.ombhrum.com/api";
const OFFICIAL_SITE_HOST = "fabushi.ombhrum.com";
const ROOT_DOMAIN_REDIRECT_HOSTS = new Set(["ombhrum.com"]);
const RELEASES_JSON_ROUTE = "/api/releases.json";
const RELEASES_JSON_R2_OBJECT = {
  key: "api/releases.json",
  contentType: "application/json; charset=utf-8",
};
const ANDROID_R2_DOWNLOADS = new Map([
  [
    "/downloads/android/fabushi-android-beta.apk",
    {
      key: "downloads/android/fabushi-android-beta.apk",
      filename: "fabushi-android-beta.apk",
    },
  ],
  [
    "/downloads/android/fabushi-android-stable.apk",
    {
      key: "downloads/android/fabushi-android-stable.apk",
      filename: "fabushi-android-stable.apk",
    },
  ],
]);
const CBETA_FALLBACK_WORKS = [
  { work: "T0365", title: "佛說觀無量壽佛經", juan: 1, juans: ["1"], byline: "宋 畺良耶舍譯" },
  { work: "T0251", title: "般若波羅蜜多心經", juan: 1, juans: ["1"], byline: "唐 玄奘譯" },
  { work: "T0235", title: "金剛般若波羅蜜經", juan: 1, juans: ["1"], byline: "後秦 鳩摩羅什譯" },
  { work: "T0262", title: "妙法蓮華經", juan: 7, juans: createJuanList(7), byline: "姚秦 鳩摩羅什譯" },
  { work: "T0279", title: "大方廣佛華嚴經", juan: 80, juans: createJuanList(80), byline: "唐 實叉難陀譯" },
  { work: "T0366", title: "佛說阿彌陀經", juan: 1, juans: ["1"], byline: "姚秦 鳩摩羅什譯" },
  { work: "T0001", title: "長阿含經", juan: 22, juans: createJuanList(22), byline: "後秦 佛陀耶舍共竺佛念譯" },
  { work: "T0099", title: "雜阿含經", juan: 50, juans: createJuanList(50), byline: "劉宋 求那跋陀羅譯" },
  { work: "T0220", title: "大般若波羅蜜多經", juan: 600, juans: createJuanList(600), byline: "唐 玄奘譯" },
  { work: "T0374", title: "大般涅槃經", juan: 40, juans: createJuanList(40), byline: "北涼 曇無讖譯" },
  { work: "T0261", title: "大乘理趣六波羅蜜多經", juan: 10, juans: createJuanList(10), byline: "唐 般若譯" },
  { work: "T0278", title: "大方廣佛華嚴經", juan: 60, juans: createJuanList(60), byline: "東晉 佛馱跋陀羅譯" },
];

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (ROOT_DOMAIN_REDIRECT_HOSTS.has(url.hostname.toLowerCase())) {
      return redirectToOfficialSite(url);
    }

    const androidDownload = ANDROID_R2_DOWNLOADS.get(url.pathname);
    const cbetaMatch = url.pathname.match(CBETA_PROXY_ROUTE);
    const appMatch = url.pathname.match(APP_PROXY_ROUTE);

    if (url.pathname === RELEASES_JSON_ROUTE) {
      return serveReleaseStateR2Object(request, env, RELEASES_JSON_R2_OBJECT);
    }

    if (androidDownload) {
      return serveAndroidR2Download(request, env, androidDownload);
    }

    if (cbetaMatch) {
      return proxyCbetaRequest(request, cbetaMatch[1]);
    }

    if (appMatch) {
      return proxyApiRequest(request, APP_API_BASE, appMatch[1], ["GET", "POST", "HEAD", "OPTIONS"]);
    }

    return env.ASSETS.fetch(request);
  },
};

function createJuanList(count) {
  return Array.from({ length: count }, (_, index) => String(index + 1));
}

function redirectToOfficialSite(url) {
  const redirectUrl = new URL(url.toString());
  redirectUrl.protocol = "https:";
  redirectUrl.host = OFFICIAL_SITE_HOST;
  return Response.redirect(redirectUrl.toString(), 308);
}

async function serveReleaseStateR2Object(request, env, objectConfig) {
  const allowedMethods = ["GET", "HEAD", "OPTIONS"];
  if (!allowedMethods.includes(request.method)) {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: {
        Allow: "GET, HEAD",
      },
    });
  }

  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        Allow: "GET, HEAD",
      },
    });
  }

  const bucket = env?.OFFICIAL_SITE_R2;
  if (!bucket || typeof bucket.get !== "function" || typeof bucket.head !== "function") {
    return new Response("Release state storage is not configured.", {
      status: 503,
      headers: {
        "Cache-Control": "no-store",
      },
    });
  }

  const object = request.method === "HEAD" ? await bucket.head(objectConfig.key) : await bucket.get(objectConfig.key);
  if (!object) {
    return new Response("Release state not found.", {
      status: 404,
      headers: {
        "Cache-Control": "no-store",
      },
    });
  }

  const headers = new Headers();
  object.writeHttpMetadata?.(headers);
  headers.set("Content-Type", headers.get("Content-Type") || objectConfig.contentType);
  headers.set("Cache-Control", "no-store");
  headers.set("Content-Length", String(object.size));
  headers.set("X-Fabushi-R2-Release-State", "official-site");

  const etag = object.httpEtag || (object.etag ? `"${object.etag}"` : "");
  if (etag) {
    headers.set("ETag", etag);
  }

  return new Response(request.method === "HEAD" ? null : object.body, {
    status: 200,
    headers,
  });
}

async function serveAndroidR2Download(request, env, download) {
  const allowedMethods = ["GET", "HEAD", "OPTIONS"];
  if (!allowedMethods.includes(request.method)) {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: {
        Allow: "GET, HEAD",
      },
    });
  }

  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        Allow: "GET, HEAD",
      },
    });
  }

  const bucket = env?.OFFICIAL_SITE_R2;
  if (!bucket || typeof bucket.get !== "function" || typeof bucket.head !== "function") {
    return new Response("Download storage is not configured.", {
      status: 503,
      headers: {
        "Cache-Control": "no-store",
      },
    });
  }

  const object = request.method === "HEAD" ? await bucket.head(download.key) : await bucket.get(download.key);
  if (!object) {
    return new Response("Android package not found.", {
      status: 404,
      headers: {
        "Cache-Control": "no-store",
      },
    });
  }

  const headers = new Headers();
  object.writeHttpMetadata?.(headers);
  headers.set("Content-Type", headers.get("Content-Type") || "application/vnd.android.package-archive");
  headers.set(
    "Content-Disposition",
    `attachment; filename="${download.filename}"; filename*=UTF-8''${encodeURIComponent(download.filename)}`,
  );
  headers.set("Cache-Control", "no-store");
  headers.set("Content-Length", String(object.size));
  headers.set("X-Fabushi-R2-Download", "official-site");

  const etag = object.httpEtag || (object.etag ? `"${object.etag}"` : "");
  if (etag) {
    headers.set("ETag", etag);
  }

  return new Response(request.method === "HEAD" ? null : object.body, {
    status: 200,
    headers,
  });
}

async function proxyCbetaRequest(request, upstreamPath) {
  if (upstreamPath === "download/all-works.json") {
    return jsonResponse(
      CBETA_FALLBACK_WORKS.map(({ work, title, juans }) => ({ work, title, juans })),
      { "X-Fabushi-Cbeta-Fallback": "all-works" },
    );
  }

  if (upstreamPath === "search/title") {
    return proxyCbetaSearchRequest(request, upstreamPath);
  }

  return proxyApiRequest(request, CBETA_API_BASE, upstreamPath, ["GET", "HEAD", "OPTIONS"]);
}

async function proxyCbetaSearchRequest(request, upstreamPath) {
  const upstreamResponse = await proxyApiRequest(request, CBETA_API_BASE, upstreamPath, ["GET", "HEAD", "OPTIONS"]);

  if (request.method !== "GET" || upstreamResponse.status !== 200) {
    return upstreamResponse;
  }

  const upstreamText = await upstreamResponse.text();
  let upstreamData = null;

  try {
    upstreamData = JSON.parse(upstreamText);
  } catch {
    return fallbackSearchResponse(request, { reason: "invalid-json" });
  }

  if (Array.isArray(upstreamData?.results) && upstreamData.results.length > 0 && !upstreamData.error) {
    return jsonResponse(upstreamData, copyProxyHeaders(upstreamResponse.headers));
  }

  const fallback = buildFallbackSearchData(request, upstreamData);
  return jsonResponse(fallback, {
    ...copyProxyHeaders(upstreamResponse.headers),
    "X-Fabushi-Cbeta-Fallback": "search-title",
  });
}

function fallbackSearchResponse(request, detail) {
  return jsonResponse(buildFallbackSearchData(request, detail), {
    "X-Fabushi-Proxy": "official-site",
    "X-Fabushi-Cbeta-Fallback": "search-title",
  });
}

function buildFallbackSearchData(request, upstreamData) {
  const url = new URL(request.url);
  const query = (url.searchParams.get("q") || "").trim().toLowerCase();
  const rows = Number.parseInt(url.searchParams.get("rows") || "24", 10);
  const start = Number.parseInt(url.searchParams.get("start") || "0", 10);
  const matched = query
    ? CBETA_FALLBACK_WORKS.filter((item) => {
        const haystack = `${item.work} ${item.title} ${item.byline}`.toLowerCase();
        return haystack.includes(query);
      })
    : CBETA_FALLBACK_WORKS;
  const results = matched.slice(start, start + (Number.isFinite(rows) ? rows : 24)).map((item) => ({
    work: item.work,
    content: item.title,
    byline: item.byline,
    juan: 1,
  }));

  return {
    query_string: url.searchParams.get("q") || "",
    num_found: matched.length,
    total_term_hits: matched.length,
    results,
    fallback: true,
    upstream_error: upstreamData?.error || upstreamData?.reason || null,
  };
}

function copyProxyHeaders(headers) {
  return {
    "Cache-Control": headers.get("Cache-Control") || "no-store",
    "X-Fabushi-Proxy": headers.get("X-Fabushi-Proxy") || "official-site",
  };
}

function jsonResponse(data, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Fabushi-Proxy": "official-site",
      ...extraHeaders,
    },
  });
}

async function proxyApiRequest(request, upstreamBase, upstreamPath, allowedMethods) {
  if (!allowedMethods.includes(request.method)) {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: {
        Allow: allowedMethods.filter((method) => method !== "OPTIONS").join(", "),
      },
    });
  }

  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        Allow: allowedMethods.filter((method) => method !== "OPTIONS").join(", "),
      },
    });
  }

  const requestUrl = new URL(request.url);
  const upstreamUrl = new URL(upstreamPath.replace(/^\/+/g, ""), `${upstreamBase}/`);
  upstreamUrl.search = requestUrl.search;

  const headers = new Headers(request.headers);
  headers.set("Accept", request.headers.get("Accept") || "application/json");
  headers.delete("Host");
  headers.delete("Cookie");

  const upstreamResponse = await fetch(upstreamUrl.toString(), {
    method: request.method,
    headers,
    body: request.method === "GET" || request.method === "HEAD" ? undefined : request.body,
    redirect: "follow",
  });
  const responseHeaders = new Headers(upstreamResponse.headers);

  responseHeaders.delete("Content-Encoding");
  responseHeaders.delete("Content-Length");
  responseHeaders.delete("Set-Cookie");
  responseHeaders.set("X-Fabushi-Proxy", "official-site");

  if (upstreamBase === APP_API_BASE) {
    responseHeaders.set("Cache-Control", "no-store");
  }

  return new Response(upstreamResponse.body, {
    status: upstreamResponse.status,
    statusText: upstreamResponse.statusText,
    headers: responseHeaders,
  });
}
