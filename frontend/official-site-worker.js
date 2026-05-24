const CBETA_PROXY_ROUTE = /^\/api\/cbeta\/(.+)$/;
const APP_PROXY_ROUTE = /^\/api\/app\/(.+)$/;
const CBETA_API_BASE = "https://api.cbetaonline.cn";
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
      return proxyApiRequest(request, CBETA_API_BASE, cbetaMatch[1], ["GET", "HEAD", "OPTIONS"]);
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
