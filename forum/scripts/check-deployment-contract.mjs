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

async function request(target, init = {}, expectedStatus = 200) {
  const allowedStatuses = Array.isArray(expectedStatus) ? expectedStatus : [expectedStatus];
  const response = await fetch(target, {
    redirect: "follow",
    ...init,
  });
  const body = await response.text();

  expect(allowedStatuses.includes(response.status), `Request failed for ${target}`, {
    status: response.status,
    body,
    expectedStatus: allowedStatuses,
  });

  return {
    body,
    headers: response.headers,
    status: response.status,
  };
}

async function fetchJson(target, init = {}, expectedStatus = 200) {
  const response = await request(
    target,
    {
      headers: {
        accept: "application/json",
        ...(init.headers ?? {}),
      },
      ...init,
    },
    expectedStatus,
  );

  try {
    return {
      ...response,
      json: JSON.parse(response.body),
    };
  } catch (error) {
    throw new Error(`Expected JSON from ${target}: ${error}`);
  }
}

function createThreadPayload(runId) {
  return {
    sectionSlug: "newcomer-path",
    title: `Live deployment smoke ${runId}`,
    author: "Live deployment check",
    authorRoleLabel: "Preview cohort tester",
    guidanceSignal: "Please confirm the smallest next step appears in live readback.",
    summary: "This thread verifies the deployed forum write path before broader rollout.",
    tags: ["live-smoke", "preview"],
    openingPost: [
      "This thread is created by the live deployment smoke check to verify thread creation, page readback, and moderation timeline persistence.",
    ],
  };
}

function createReplyPayload() {
  return {
    author: "Live reply check",
    roleLabel: "Preview reply verifier",
    guidanceSignal: "Please surface one concrete next step in the live thread detail.",
    trustSignal: "Written by the live deployment smoke check to verify reply persistence.",
    body: [
      "This reply verifies that the deployed forum can persist and read back a new response.",
    ],
  };
}

async function verifyPreviewWriteFlow({ forumUrl, expectedRequiresAccessCode, writeAccessCode }) {
  const runId = new Date().toISOString().replace(/[^0-9]/g, "").slice(0, 14);
  const threadPayload = createThreadPayload(runId);

  if (expectedRequiresAccessCode) {
    const deniedCreate = await fetchJson(
      `${forumUrl}/api/threads`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        body: JSON.stringify(threadPayload),
      },
      403,
    );

    expect(
      typeof deniedCreate.json.error === "string" && deniedCreate.json.error.toLowerCase().includes("write access code"),
      "thread creation without a write access code should be rejected before live writes run",
      deniedCreate.json,
    );
  }

  const createPayload = {
    ...threadPayload,
    ...(writeAccessCode ? { writeAccessCode } : {}),
  };
  const createdThread = await fetchJson(
    `${forumUrl}/api/threads`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: JSON.stringify(createPayload),
    },
    201,
  );

  expect(createdThread.json.source === "sqlite", "created thread should be backed by sqlite", createdThread.json);
  expect(createdThread.json.thread.sectionSlug === threadPayload.sectionSlug, "thread section mismatch", createdThread.json);
  expect(createdThread.json.thread.title === threadPayload.title, "thread title mismatch", createdThread.json);
  expect(createdThread.json.thread.author === threadPayload.author, "thread author mismatch", createdThread.json);
  expect(
    createdThread.json.thread.authorRoleLabel === threadPayload.authorRoleLabel,
    "thread authorRoleLabel mismatch",
    createdThread.json,
  );
  expect(
    createdThread.json.thread.guidanceSignal === threadPayload.guidanceSignal,
    "thread guidanceSignal mismatch",
    createdThread.json,
  );
  expect(
    createdThread.json.moderationEvents.at(-1)?.eventType === "thread-created",
    "thread creation should append a moderation event",
    createdThread.json,
  );

  const threadSlug = createdThread.json.thread.slug;
  expect(Boolean(threadSlug), "thread slug should be returned after live thread creation", createdThread.json);

  const threadDetail = await fetchJson(`${forumUrl}/api/thread/${threadSlug}`);
  expect(threadDetail.json.source === "sqlite", "thread detail should resolve from sqlite", threadDetail.json);
  expect(threadDetail.json.thread.slug === threadSlug, "thread detail slug mismatch", threadDetail.json);
  expect(threadDetail.json.thread.author === threadPayload.author, "thread detail author mismatch", threadDetail.json);
  expect(
    threadDetail.json.moderationEvents.at(-1)?.eventType === "thread-created",
    "thread detail should expose the creation moderation event",
    threadDetail.json,
  );

  const threadListPage = await request(`${forumUrl}/threads`);
  expect(threadListPage.body.includes(threadPayload.title), "thread list HTML should include the created thread title", {
    threadTitle: threadPayload.title,
    snippet: threadListPage.body.slice(0, 6000),
  });
  expect(threadListPage.body.includes(threadPayload.author), "thread list HTML should include the created thread author", {
    author: threadPayload.author,
    snippet: threadListPage.body.slice(0, 6000),
  });
  expect(
    threadListPage.body.includes(threadPayload.authorRoleLabel),
    "thread list HTML should include the created thread role label",
    {
      roleLabel: threadPayload.authorRoleLabel,
      snippet: threadListPage.body.slice(0, 6000),
    },
  );
  expect(
    threadListPage.body.includes(threadPayload.guidanceSignal),
    "thread list HTML should include the created thread guidance signal",
    {
      guidanceSignal: threadPayload.guidanceSignal,
      snippet: threadListPage.body.slice(0, 6000),
    },
  );

  const threadDetailPageBeforeReply = await request(`${forumUrl}/threads/${threadSlug}`);
  expect(
    threadDetailPageBeforeReply.body.includes(threadPayload.title),
    "thread detail HTML should include the created thread title",
    {
      threadTitle: threadPayload.title,
      snippet: threadDetailPageBeforeReply.body.slice(0, 7000),
    },
  );
  expect(
    threadDetailPageBeforeReply.body.includes(threadPayload.guidanceSignal),
    "thread detail HTML should include the thread guidance signal",
    {
      guidanceSignal: threadPayload.guidanceSignal,
      snippet: threadDetailPageBeforeReply.body.slice(0, 7000),
    },
  );
  expect(
    threadDetailPageBeforeReply.body.includes("审核时间线"),
    "thread detail HTML should expose the moderation timeline block",
    {
      snippet: threadDetailPageBeforeReply.body.slice(0, 7000),
    },
  );

  const replyPayload = createReplyPayload();
  const createdReply = await fetchJson(
    `${forumUrl}/api/thread/${threadSlug}/replies`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: JSON.stringify({
        ...replyPayload,
        ...(writeAccessCode ? { writeAccessCode } : {}),
      }),
    },
    201,
  );

  expect(createdReply.json.source === "sqlite", "created reply should be backed by sqlite", createdReply.json);
  expect(createdReply.json.thread.slug === threadSlug, "reply response slug mismatch", createdReply.json);
  expect(createdReply.json.thread.replyCount >= 1, "reply count should increase after live reply creation", createdReply.json);
  expect(createdReply.json.thread.lastActivity === "刚刚回复", "lastActivity should reflect a new reply", createdReply.json);
  expect(createdReply.json.replies.at(-1)?.author === replyPayload.author, "reply author mismatch", createdReply.json);
  expect(createdReply.json.replies.at(-1)?.roleLabel === replyPayload.roleLabel, "reply roleLabel mismatch", createdReply.json);
  expect(
    createdReply.json.replies.at(-1)?.guidanceSignal === replyPayload.guidanceSignal,
    "reply guidanceSignal mismatch",
    createdReply.json,
  );
  expect(
    createdReply.json.replies.at(-1)?.trustSignal === replyPayload.trustSignal,
    "reply trustSignal mismatch",
    createdReply.json,
  );
  expect(
    createdReply.json.moderationEvents.at(-1)?.eventType === "reply-created",
    "reply creation should append a moderation event",
    createdReply.json,
  );

  const threadDetailAfterReply = await fetchJson(`${forumUrl}/api/thread/${threadSlug}`);
  expect(
    threadDetailAfterReply.json.replies.at(-1)?.author === replyPayload.author,
    "thread detail should include the live reply author",
    threadDetailAfterReply.json,
  );
  expect(
    threadDetailAfterReply.json.moderationEvents.at(-1)?.eventType === "reply-created",
    "thread detail should expose the reply moderation event",
    threadDetailAfterReply.json,
  );

  const threadDetailPageAfterReply = await request(`${forumUrl}/threads/${threadSlug}`);
  expect(
    threadDetailPageAfterReply.body.includes(replyPayload.author),
    "thread detail HTML should include the live reply author",
    {
      author: replyPayload.author,
      snippet: threadDetailPageAfterReply.body.slice(0, 9000),
    },
  );
  expect(
    threadDetailPageAfterReply.body.includes(replyPayload.roleLabel),
    "thread detail HTML should include the live reply role label",
    {
      roleLabel: replyPayload.roleLabel,
      snippet: threadDetailPageAfterReply.body.slice(0, 9000),
    },
  );
  expect(
    threadDetailPageAfterReply.body.includes(replyPayload.guidanceSignal),
    "thread detail HTML should include the live reply guidance signal",
    {
      guidanceSignal: replyPayload.guidanceSignal,
      snippet: threadDetailPageAfterReply.body.slice(0, 9000),
    },
  );

  return {
    threadSlug,
    threadTitle: threadPayload.title,
    replyAuthor: replyPayload.author,
  };
}

const args = parseArgs(process.argv.slice(2));
const forumUrl = normalizeUrl(args.url ?? "");
const deploymentStage = args["deployment-stage"];
const publicBaseUrl = args["public-base-url"] ? normalizeUrl(args["public-base-url"]) : "";
const expectedWritesEnabled = parseBoolean(args["writes-enabled"], "writes-enabled");
const expectedRequiresAccessCode = parseBoolean(args["requires-access-code"], "requires-access-code");
const exerciseWriteFlow = parseBoolean(args["exercise-write-flow"], "exercise-write-flow") ?? false;
const writeAccessCode = args["write-access-code"]?.trim() || process.env.FORUM_WRITE_ACCESS_CODE?.trim() || "";

expect(Boolean(forumUrl), "--url is required");
expect(
  deploymentStage === "preview" || deploymentStage === "production",
  "--deployment-stage must be preview or production",
  { deploymentStage },
);

const expectedIndexingEnabled = deploymentStage === "production" && Boolean(publicBaseUrl);

const health = await fetchJson(`${forumUrl}/api/health`);
const status = await fetchJson(`${forumUrl}/api/status`);
const robots = await request(`${forumUrl}/robots.txt`);
const threadList = await request(`${forumUrl}/threads`);
const threadListHtml = threadList.body.toLowerCase();
const robotsText = robots.body;

expect(health.json.service === "forum", "health service should be forum", health.json);
expect(health.json.ready === true, "health ready should be true", health.json);
expect(health.json.deploymentStage === deploymentStage, "health deployment stage mismatch", health.json);
expect(health.json.indexingEnabled === expectedIndexingEnabled, "health indexingEnabled mismatch", {
  expectedIndexingEnabled,
  health: health.json,
});
expect(
  health.json.publicBaseUrlConfigured === Boolean(publicBaseUrl),
  "health publicBaseUrlConfigured mismatch",
  {
    expected: Boolean(publicBaseUrl),
    health: health.json,
  },
);

expect(status.json.service === "forum", "status service should be forum", status.json);
expect(status.json.deploymentStage === deploymentStage, "status deployment stage mismatch", status.json);
expect(status.json.indexingEnabled === expectedIndexingEnabled, "status indexingEnabled mismatch", {
  expectedIndexingEnabled,
  status: status.json,
});

if (publicBaseUrl) {
  expect(status.json.publicBaseUrl === publicBaseUrl, "status publicBaseUrl mismatch", {
    expected: publicBaseUrl,
    status: status.json,
  });
} else {
  expect(!status.json.publicBaseUrl, "status publicBaseUrl should be empty when no public base URL is expected", status.json);
}

if (expectedWritesEnabled !== undefined) {
  expect(health.json.writesEnabled === expectedWritesEnabled, "health writesEnabled mismatch", {
    expectedWritesEnabled,
    health: health.json,
  });
  expect(status.json.writesEnabled === expectedWritesEnabled, "status writesEnabled mismatch", {
    expectedWritesEnabled,
    status: status.json,
  });
}

if (expectedRequiresAccessCode !== undefined) {
  expect(health.json.requiresAccessCode === expectedRequiresAccessCode, "health requiresAccessCode mismatch", {
    expectedRequiresAccessCode,
    health: health.json,
  });
  expect(status.json.requiresAccessCode === expectedRequiresAccessCode, "status requiresAccessCode mismatch", {
    expectedRequiresAccessCode,
    status: status.json,
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

let liveWriteVerification = null;

if (exerciseWriteFlow) {
  expect(deploymentStage === "preview", "--exercise-write-flow is only supported for preview runtimes.", {
    deploymentStage,
  });
  expect(expectedWritesEnabled === true, "--exercise-write-flow requires --writes-enabled=true.", {
    expectedWritesEnabled,
  });

  if (expectedRequiresAccessCode) {
    expect(Boolean(writeAccessCode), "A write access code is required to exercise the live preview write flow. Pass --write-access-code or set FORUM_WRITE_ACCESS_CODE.");
  }

  liveWriteVerification = await verifyPreviewWriteFlow({
    forumUrl,
    expectedRequiresAccessCode: expectedRequiresAccessCode === true,
    writeAccessCode,
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
      exerciseWriteFlow,
      liveWriteVerification,
    },
    null,
    2,
  ),
);
