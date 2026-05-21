const CBETA_PROXY_ROUTE = /^\/api\/cbeta\/(.+)$/;
const APP_PROXY_ROUTE = /^\/api\/app\/(.+)$/;
const CBETA_API_BASE = "https://api.cbetaonline.cn";
const APP_API_BASE = "https://api.ombhrum.com/api";
const OFFICIAL_SITE_HOST = "fabushi.ombhrum.com";
const ROOT_DOMAIN_REDIRECT_HOSTS = new Set(["ombhrum.com"]);

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (ROOT_DOMAIN_REDIRECT_HOSTS.has(url.hostname.toLowerCase())) {
      return redirectToOfficialSite(url);
    }

    const cbetaMatch = url.pathname.match(CBETA_PROXY_ROUTE);
    const appMatch = url.pathname.match(APP_PROXY_ROUTE);

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
