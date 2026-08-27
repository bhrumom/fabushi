import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const webRoot = resolve(import.meta.dirname, "..");
const read = (relativePath) => readFileSync(resolve(webRoot, relativePath), "utf8");

const marketplace = read("src/lib/marketplace.ts");
const discovery = read("src/lib/ai-discovery.ts");
const webMcp = read("src/components/marketplace/marketplace-webmcp.tsx");
const sitemap = read("src/app/sitemap.ts");
const robots = read("src/app/robots.ts");
const appPage = read("src/app/apps/[slug]/page.tsx");

const appSlugs = [...marketplace.matchAll(/^    slug: "([^"]+)",$/gm)].map((match) => match[1]);
const answerSlugs = [...discovery.matchAll(/^    slug: "([^"]+)",$/gm)].map((match) => match[1]);

assert.ok(appSlugs.length >= 8, "the canonical Marketplace catalog must expose all public Mini Apps");
assert.equal(new Set(appSlugs).size, appSlugs.length, "Marketplace app slugs must be unique");
assert.equal(new Set(answerSlugs).size, answerSlugs.length, "answer intent slugs must be unique");
assert.deepEqual(
  new Set([...discovery.matchAll(/recommendedAppSlug: "([^"]+)"/g)].map((match) => match[1])),
  new Set(appSlugs),
  "answer intents must cover every catalog app exactly through catalog references",
);

for (const relativePath of [
  "src/app/ai/apps.json/route.ts",
  "src/app/ai/apps/[file]/route.ts",
  "src/app/ai/content.json/route.ts",
  "src/app/ai/answers.json/route.ts",
  "src/app/llms.txt/route.ts",
  "src/app/llms-full.txt/route.ts",
  "src/app/answers/[slug]/page.tsx",
]) {
  assert.ok(existsSync(resolve(webRoot, relativePath)), `missing AI discovery route: ${relativePath}`);
}

assert.match(discovery, /from "\.\/marketplace"/, "AI discovery must derive from the canonical catalog");
assert.match(discovery, /fabushi\.ai-discovery\.v1/, "AI feeds must expose a versioned schema");
assert.match(discovery, /#app/, "app entities must use a stable #app identifier");
assert.match(appPage, /appEntityId\(app\)/, "app JSON-LD must use the shared stable entity helper");
assert.match(appPage, /"WebApplication"/, "app JSON-LD must identify the web application surface");

for (const tool of ["recommend_fabushi_app", "get_app_capabilities"]) {
  assert.match(webMcp, new RegExp(`name: "${tool}"`), `WebMCP is missing ${tool}`);
}
assert.match(webMcp, /serializeAppForAi/, "WebMCP discovery must reuse the machine app serializer");

for (const bot of ["OAI-SearchBot", "ChatGPT-User", "Googlebot", "Bingbot"]) {
  assert.match(robots, new RegExp(bot), `robots must explicitly allow ${bot}`);
}

assert.match(sitemap, /fabushiAnswerIntents/, "answer pages must be generated from the answer registry");
assert.match(sitemap, /\/answers\//, "answer pages must be present in sitemap");
assert.match(sitemap, /\/ai\/apps\.json/, "AI machine indexes must be present in sitemap");
assert.match(sitemap, /\.slug}\.json/, "per-app machine records must be present in sitemap");

console.log(
  `AI discovery contract passed: ${appSlugs.length} apps, ${answerSlugs.length} answers, stable feeds and WebMCP tools.`,
);
