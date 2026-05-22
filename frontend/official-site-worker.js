const CBETA_PROXY_ROUTE = /^\/api\/cbeta(?:\/(.*))?$/;
const APP_PROXY_ROUTE = /^\/api\/app\/(.+)$/;
const DEFAULT_CBETA_UPSTREAM_BASE = "https://api.cbetaonline.cn";
const APP_API_BASE = "https://api.ombhrum.com/api";
const OFFICIAL_SITE_HOST = "fabushi.ombhrum.com";
const ROOT_DOMAIN_REDIRECT_HOSTS = new Set(["ombhrum.com"]);
const CBETA_MIRROR_PREFIX = "cbeta-api";
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

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (ROOT_DOMAIN_REDIRECT_HOSTS.has(url.hostname.toLowerCase())) {
      return redirectToOfficialSite(url);
    }

    const androidDownload = ANDROID_R2_DOWNLOADS.get(url.pathname);
    const cbetaMatch = url.pathname.match(CBETA_PROXY_ROUTE);
    const appMatch = url.pathname.match(APP_PROXY_ROUTE);

    if (androidDownload) {
      return serveAndroidR2Download(request, env, androidDownload);
    }

    if (cbetaMatch) {
      return proxyCbetaApiRequest(request, env, ctx, cbetaMatch[1] ?? "");
    }

    if (appMatch) {
      return proxyApiRequest(request, APP_API_BASE, appMatch[1], ["GET", "POST", "HEAD", "OPTIONS"]);
    }

    return env.ASSETS.fetch(request);
  },
};

function redirectToOfficialSite(url) {
  const redirectUrl = new URL(url.toString());
  redirectUrl.protocol = "https:";
  redirectUrl.host = OFFICIAL_SITE_HOST;
  return Response.redirect(redirectUrl.toString(), 308);
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

function normalizeBaseUrl(value, fallback) {
  const candidate = `${value || fallback}`.trim() || fallback;
  return candidate.replace(/\/+$/g, "");
}

function buildCanonicalQuery(searchParams) {
  return Array.from(searchParams.entries())
    .sort(([leftKey, leftValue], [rightKey, rightValue]) => {
      if (leftKey === rightKey) {
        return leftValue.localeCompare(rightValue);
      }
      return leftKey.localeCompare(rightKey);
    })
    .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(value)}`)
    .join("&");
}

function buildCbetaMirrorKey(pathname, searchParams) {
  const normalizedPath = pathname.replace(/^\/+|\/+$/g, "") || "index";
  const canonicalQuery = buildCanonicalQuery(searchParams);
  return canonicalQuery
    ? `${CBETA_MIRROR_PREFIX}/${normalizedPath}?${canonicalQuery}`
    : `${CBETA_MIRROR_PREFIX}/${normalizedPath}`;
}

function buildCbetaUpstreamUrl(base, pathname, searchParams) {
  const upstreamUrl = new URL(pathname.replace(/^\/+/, ""), `${base}/`);
  const canonicalQuery = buildCanonicalQuery(searchParams);
  upstreamUrl.search = canonicalQuery;
  return upstreamUrl;
}

function applySanitizedProxyHeaders(sourceHeaders, extras = {}) {
  const headers = new Headers(sourceHeaders);
  headers.delete("Content-Encoding");
  headers.delete("Content-Length");
  headers.delete("Set-Cookie");

  for (const [key, value] of Object.entries(extras)) {
    if (!value) {
      continue;
    }
    headers.set(key, value);
  }

  return headers;
}

async function readMirrorObject(bucket, key, method) {
  if (!bucket) {
    return null;
  }

  if (method === "HEAD" && typeof bucket.head === "function") {
    return bucket.head(key);
  }

  if (typeof bucket.get === "function") {
    return bucket.get(key);
  }

  return null;
}

async function writeMirrorObject(bucket, key, response) {
  if (!bucket || response.status !== 200 || response.bodyUsed || typeof bucket.put !== "function") {
    return;
  }

  const contentType = response.headers.get("Content-Type") || "application/json; charset=utf-8";
  const cacheControl = response.headers.get("Cache-Control") || "public, max-age=86400";
  const body = await response.arrayBuffer();

  await bucket.put(key, body, {
    httpMetadata: {
      contentType,
      cacheControl,
    },
    customMetadata: {
      source: "upstream-fill",
      mirroredAt: new Date().toISOString(),
    },
  });
}

function buildMirrorResponse(object, method) {
  const headers = new Headers();
  object.writeHttpMetadata?.(headers);
  headers.set("Cache-Control", headers.get("Cache-Control") || "public, max-age=86400");
  headers.set("Content-Length", String(object.size));
  headers.set("X-Fabushi-Cbeta-Source", "r2-mirror");

  const etag = object.httpEtag || (object.etag ? `"${object.etag}"` : "");
  if (etag) {
    headers.set("ETag", etag);
  }

  return new Response(method === "HEAD" ? null : object.body, {
    status: 200,
    headers,
  });
}

async function proxyCbetaApiRequest(request, env, ctx, upstreamPath) {
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

  const requestUrl = new URL(request.url);
  const mirrorKey = buildCbetaMirrorKey(upstreamPath, requestUrl.searchParams);
  const mirrorBucket = env?.CBETA_MIRROR;
  const mirroredObject = await readMirrorObject(mirrorBucket, mirrorKey, request.method);

  if (mirroredObject) {
    return buildMirrorResponse(mirroredObject, request.method);
  }

  const upstreamBase = normalizeBaseUrl(env?.CBETA_UPSTREAM_BASE, DEFAULT_CBETA_UPSTREAM_BASE);
  if (!upstreamBase) {
    return new Response("CBETA mirror is not populated yet.", {
      status: 503,
      headers: {
        "Cache-Control": "no-store",
      },
    });
  }

  const upstreamUrl = buildCbetaUpstreamUrl(upstreamBase, upstreamPath, requestUrl.searchParams);
  const headers = new Headers(request.headers);
  headers.set("Accept", request.headers.get("Accept") || "application/json");
  headers.delete("Host");
  headers.delete("Cookie");

  const upstreamResponse = await fetch(upstreamUrl.toString(), {
    method: request.method,
    headers,
    redirect: "follow",
  });

  const responseHeaders = applySanitizedProxyHeaders(upstreamResponse.headers, {
    "X-Fabushi-Cbeta-Source": "upstream-fill",
    "X-Fabushi-Cbeta-Key": mirrorKey,
  });
  const response = new Response(upstreamResponse.body, {
    status: upstreamResponse.status,
    statusText: upstreamResponse.statusText,
    headers: responseHeaders,
  });

  if (request.method === "GET" && upstreamResponse.ok && mirrorBucket) {
    ctx?.waitUntil?.(writeMirrorObject(mirrorBucket, mirrorKey, response.clone()));
  }

  return response;
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
  const upstreamUrl = new URL(upstreamPath.replace(/^\/+/, ""), `${upstreamBase}/`);
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
