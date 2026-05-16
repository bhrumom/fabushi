#!/usr/bin/env node

function parseArgs(argv) {
  const parsed = {};

  for (let index = 0; index < argv.length; index += 1) {
    const part = argv[index];

    if (!part.startsWith("--")) {
      throw new Error(`Unexpected argument: ${part}`);
    }

    const key = part.slice(2);
    const value = argv[index + 1];

    if (value === undefined || value.startsWith("--")) {
      throw new Error(`Missing value for --${key}`);
    }

    parsed[key] = value;
    index += 1;
  }

  return parsed;
}

function normalizeUrl(value) {
  return value.replace(/\/$/, "");
}

function parseBoolean(value, key) {
  if (value === undefined || value === "") {
    return undefined;
  }

  if (value === "true") {
    return true;
  }

  if (value === "false") {
    return false;
  }

  throw new Error(`Expected --${key} to be true or false, received: ${value}`);
}

function expect(condition, message, details) {
  if (!condition) {
    if (details === undefined) {
      throw new Error(message);
    }

    throw new Error(`${message}\n${JSON.stringify(details, null, 2)}`);
  }
}

async function fetchJson(target) {
  const response = await fetch(target, {
    headers: {
      accept: "application/json",
    },
    redirect: "follow",
  });

  const body = await response.text();
  expect(response.ok, `Request failed for ${target}`, {
    status: response.status,
    body,
  });

  try {
    return JSON.parse(body);
  } catch (error) {
    throw new Error(`Expected JSON from ${target}: ${error}`);
  }
}

async function fetchText(target) {
  const response = await fetch(target, {
    redirect: "follow",
  });
  const body = await response.text();

  expect(response.ok, `Request failed for ${target}`, {
    status: response.status,
    body,
  });

  return {
    body,
    headers: response.headers,
  };
}

const args = parseArgs(process.argv.slice(2));
const forumUrl = normalizeUrl(args.url ?? "");
const deploymentStage = args["deployment-stage"];
const publicBaseUrl = args["public-base-url"] ? normalizeUrl(args["public-base-url"]) : "";
const expectedWritesEnabled = parseBoolean(args["writes-enabled"], "writes-enabled");
const expectedRequiresAccessCode = parseBoolean(args["requires-access-code"], "requires-access-code");

expect(Boolean(forumUrl), "--url is required");
expect(
  deploymentStage === "preview" || deploymentStage === "production",
  "--deployment-stage must be preview or production",
  { deploymentStage },
);

const expectedIndexingEnabled = deploymentStage === "production" && Boolean(publicBaseUrl);

const health = await fetchJson(`${forumUrl}/api/health`);
const status = await fetchJson(`${forumUrl}/api/status`);
const robots = await fetchText(`${forumUrl}/robots.txt`);
const threadList = await fetchText(`${forumUrl}/threads`);
const threadListHtml = threadList.body.toLowerCase();
const robotsText = robots.body;

expect(health.service === "forum", "health service should be forum", health);
expect(health.ready === true, "health ready should be true", health);
expect(health.deploymentStage === deploymentStage, "health deployment stage mismatch", health);
expect(health.indexingEnabled === expectedIndexingEnabled, "health indexingEnabled mismatch", {
  expectedIndexingEnabled,
  health,
});
expect(
  health.publicBaseUrlConfigured === Boolean(publicBaseUrl),
  "health publicBaseUrlConfigured mismatch",
  {
    expected: Boolean(publicBaseUrl),
    health,
  },
);

expect(status.service === "forum", "status service should be forum", status);
expect(status.deploymentStage === deploymentStage, "status deployment stage mismatch", status);
expect(status.indexingEnabled === expectedIndexingEnabled, "status indexingEnabled mismatch", {
  expectedIndexingEnabled,
  status,
});

if (publicBaseUrl) {
  expect(status.publicBaseUrl === publicBaseUrl, "status publicBaseUrl mismatch", {
    expected: publicBaseUrl,
    status,
  });
} else {
  expect(!status.publicBaseUrl, "status publicBaseUrl should be empty when no public base URL is expected", status);
}

if (expectedWritesEnabled !== undefined) {
  expect(health.writesEnabled === expectedWritesEnabled, "health writesEnabled mismatch", {
    expectedWritesEnabled,
    health,
  });
  expect(status.writesEnabled === expectedWritesEnabled, "status writesEnabled mismatch", {
    expectedWritesEnabled,
    status,
  });
}

if (expectedRequiresAccessCode !== undefined) {
  expect(health.requiresAccessCode === expectedRequiresAccessCode, "health requiresAccessCode mismatch", {
    expectedRequiresAccessCode,
    health,
  });
  expect(status.requiresAccessCode === expectedRequiresAccessCode, "status requiresAccessCode mismatch", {
    expectedRequiresAccessCode,
    status,
  });
}

const stageHeader = threadList.headers.get("x-forum-deployment-stage");
const indexingHeader = threadList.headers.get("x-forum-indexing-enabled");
const publicBaseUrlHeader = threadList.headers.get("x-forum-public-base-url");
const robotsTagHeader = threadList.headers.get("x-robots-tag");

expect(stageHeader === deploymentStage, "page deployment stage header mismatch", {
  expected: deploymentStage,
  actual: stageHeader,
});
expect(indexingHeader === String(expectedIndexingEnabled), "page indexing header mismatch", {
  expected: String(expectedIndexingEnabled),
  actual: indexingHeader,
});

if (publicBaseUrl) {
  expect(publicBaseUrlHeader === publicBaseUrl, "page public base URL header mismatch", {
    expected: publicBaseUrl,
    actual: publicBaseUrlHeader,
  });
} else {
  expect(!publicBaseUrlHeader, "page public base URL header should be empty", {
    actual: publicBaseUrlHeader,
  });
}

if (expectedIndexingEnabled) {
  expect(!robotsTagHeader, "x-robots-tag should be absent when indexing is enabled", {
    robotsTagHeader,
  });
  expect(robotsText.includes("Allow: /"), "robots.txt should allow crawling", {
    robotsText,
  });
  expect(robotsText.includes(`Host: ${publicBaseUrl}`), "robots.txt Host should match expected public base URL", {
    publicBaseUrl,
    robotsText,
  });
  expect(!robotsText.includes("Disallow: /"), "robots.txt should not disallow crawling", {
    robotsText,
  });
  expect(threadListHtml.includes("index, follow"), "thread list HTML should be indexable", {
    snippet: threadList.body.slice(0, 4000),
  });
  expect(threadListHtml.includes(publicBaseUrl.toLowerCase()), "thread list HTML should include the configured public base URL", {
    publicBaseUrl,
    snippet: threadList.body.slice(0, 4000),
  });
  expect(!threadListHtml.includes("noindex"), "thread list HTML should not include noindex metadata", {
    snippet: threadList.body.slice(0, 4000),
  });
} else {
  expect(
    robotsTagHeader?.toLowerCase().includes("noindex") ?? false,
    "x-robots-tag should keep preview/noindex deployments private",
    { robotsTagHeader },
  );
  expect(robotsText.includes("Disallow: /"), "robots.txt should disallow crawling", {
    robotsText,
  });
  expect(threadListHtml.includes("noindex"), "thread list HTML should include noindex metadata", {
    snippet: threadList.body.slice(0, 4000),
  });
}

console.log(
  JSON.stringify(
    {
      ok: true,
      forumUrl,
      deploymentStage,
      indexingEnabled: expectedIndexingEnabled,
      publicBaseUrl: publicBaseUrl || null,
      writesEnabled: expectedWritesEnabled ?? null,
      requiresAccessCode: expectedRequiresAccessCode ?? null,
    },
    null,
    2,
  ),
);
