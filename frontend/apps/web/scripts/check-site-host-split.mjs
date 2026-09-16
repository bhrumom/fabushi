import assert from "node:assert/strict";
import worker from "../../../official-site-worker.js";

const assetRequests = [];
const env = {
  ASSETS: {
    async fetch(request) {
      const url = new URL(request.url);
      assetRequests.push(url.toString());
      return new Response(url.pathname, { status: 200 });
    },
  },
};

async function bodyFor(url) {
  const response = await worker.fetch(new Request(url), env);
  return { response, body: await response.text() };
}

{
  const { response, body } = await bodyFor("https://ombhrum.com/");
  assert.equal(response.status, 200);
  assert.equal(body, "/");
}

{
  const { response, body } = await bodyFor("https://web.ombhrum.com/");
  assert.equal(response.status, 200);
  assert.equal(body, "/web/");
}

{
  const response = await worker.fetch(new Request("https://web.ombhrum.com/web/?from=legacy"), env);
  assert.equal(response.status, 308);
  assert.equal(response.headers.get("location"), "https://web.ombhrum.com/?from=legacy");
}

{
  const response = await worker.fetch(new Request("https://fabushi.ombhrum.com/download/?channel=stable"), env);
  assert.equal(response.status, 308);
  assert.equal(response.headers.get("location"), "https://ombhrum.com/download/?channel=stable");
}

assert.ok(assetRequests.includes("https://ombhrum.com/"));
assert.ok(assetRequests.includes("https://web.ombhrum.com/web/"));
console.log("Official site/Web host split checks passed.");
