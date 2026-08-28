const ARTIFACT_PATH = /^e2e\/marketplace\/[0-9]+-[0-9]+\/plugin\.tar\.gz$/;

function response(status, message, extraHeaders = {}) {
  return new Response(message, {
    status,
    headers: {
      'content-type': 'text/plain; charset=utf-8',
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
      ...extraHeaders,
    },
  });
}

export default {
  async fetch(request, env) {
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return response(405, 'method not allowed', { allow: 'GET, HEAD' });
    }

    let key;
    try {
      key = decodeURIComponent(new URL(request.url).pathname.replace(/^\/+/, ''));
    } catch {
      return response(400, 'invalid artifact path');
    }
    if (!ARTIFACT_PATH.test(key)) return response(404, 'artifact not found');

    const object = await env.ARTIFACTS.get(key);
    if (!object) return response(404, 'artifact not found');

    const headers = new Headers();
    object.writeHttpMetadata?.(headers);
    if (object.httpEtag) headers.set('etag', object.httpEtag);
    if (Number.isFinite(object.size)) headers.set('content-length', String(object.size));
    headers.set('content-type', headers.get('content-type') || 'application/gzip');
    headers.set('cache-control', 'public, max-age=31536000, immutable');
    headers.set('access-control-allow-origin', '*');
    headers.set('x-content-type-options', 'nosniff');

    return new Response(request.method === 'HEAD' ? null : object.body, { status: 200, headers });
  },
};
