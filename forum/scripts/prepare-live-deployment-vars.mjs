#!/usr/bin/env node

import { readFile } from "node:fs/promises";

function parseArgs(argv) {
  const parsed = {
    "deploy-env-path": ".env.deploy",
    "exercise-write-flow": "false",
    format: "env",
    "github-repo": "",
  };

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

function parseBoolean(value, key) {
  if (value === undefined || value === null || value === "") {
    return false;
  }

  if (value === "true") {
    return true;
  }

  if (value === "false") {
    return false;
  }

  throw new Error(`Expected ${key} to be true or false, received: ${value}`);
}

function normalizeUrl(value) {
  return value ? value.replace(/\/$/, "") : "";
}

function parseDotEnv(content) {
  const values = {};

  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();

    if (!line || line.startsWith("#")) {
      continue;
    }

    const separatorIndex = line.indexOf("=");
    if (separatorIndex === -1) {
      throw new Error(`Expected KEY=VALUE line in deploy env file, received: ${rawLine}`);
    }

    const key = line.slice(0, separatorIndex).trim();
    const value = line.slice(separatorIndex + 1).trim();
    values[key] = value;
  }

  return values;
}

function buildLiveTarget({ forumUrl, deployEnv, exerciseWriteFlow }) {
  const deploymentStage = deployEnv.FORUM_DEPLOYMENT_STAGE?.trim() || "preview";
  if (deploymentStage !== "preview" && deploymentStage !== "production") {
    throw new Error(
      `Expected FORUM_DEPLOYMENT_STAGE in deploy env to be preview or production, received: ${deploymentStage}`,
    );
  }

  const writesEnabled = parseBoolean(deployEnv.FORUM_ENABLE_WRITES ?? "false", "FORUM_ENABLE_WRITES");
  const requiresAccessCode = writesEnabled && Boolean((deployEnv.FORUM_WRITE_ACCESS_CODE || "").trim());
  const publicBaseUrl = normalizeUrl(deployEnv.FORUM_PUBLIC_BASE_URL?.trim() || "");

  if (exerciseWriteFlow && deploymentStage !== "preview") {
    throw new Error("exercise_write_flow can only be enabled for preview deployments.");
  }

  if (exerciseWriteFlow && !writesEnabled) {
    throw new Error("exercise_write_flow=true requires FORUM_ENABLE_WRITES=true in the deploy env file.");
  }

  return {
    FORUM_LIVE_URL: normalizeUrl(forumUrl),
    FORUM_LIVE_DEPLOYMENT_STAGE: deploymentStage,
    FORUM_LIVE_PUBLIC_BASE_URL: publicBaseUrl,
    FORUM_LIVE_WRITES_ENABLED: String(writesEnabled),
    FORUM_LIVE_REQUIRES_ACCESS_CODE: String(requiresAccessCode),
    FORUM_LIVE_EXERCISE_WRITE_FLOW: String(exerciseWriteFlow),
  };
}

function buildBundledLiveTarget(liveTarget) {
  return {
    forumUrl: liveTarget.FORUM_LIVE_URL,
    deploymentStage: liveTarget.FORUM_LIVE_DEPLOYMENT_STAGE,
    publicBaseUrl: liveTarget.FORUM_LIVE_PUBLIC_BASE_URL,
    writesEnabled: liveTarget.FORUM_LIVE_WRITES_ENABLED === "true",
    requiresAccessCode: liveTarget.FORUM_LIVE_REQUIRES_ACCESS_CODE === "true",
    exerciseWriteFlow: liveTarget.FORUM_LIVE_EXERCISE_WRITE_FLOW === "true",
  };
}

function quoteForSingleQuotedShell(value) {
  return value.replace(/'/g, "'\"'\"'");
}

function buildGithubRepoArg(githubRepo) {
  if (!githubRepo) {
    return "";
  }

  return ` --repo '${quoteForSingleQuotedShell(githubRepo)}'`;
}

function renderEnvFormat(liveTarget) {
  return Object.entries(liveTarget)
    .map(([key, value]) => `${key}=${value}`)
    .join("\n");
}

function renderJsonFormat(liveTarget) {
  return JSON.stringify(buildBundledLiveTarget(liveTarget), null, 2);
}

function renderGithubCliFormat(liveTarget, deployEnv, githubRepo) {
  const repoArg = buildGithubRepoArg(githubRepo);
  const lines = Object.entries(liveTarget).map(
    ([key, value]) => `gh variable set ${key} --body '${quoteForSingleQuotedShell(value)}'${repoArg}`,
  );

  if (liveTarget.FORUM_LIVE_REQUIRES_ACCESS_CODE === "true") {
    const accessCode = (deployEnv.FORUM_WRITE_ACCESS_CODE || "").trim();

    lines.push("");
    lines.push("# Run this once if the preview write gate is enabled for the live target.");
    lines.push(`gh secret set FORUM_LIVE_WRITE_ACCESS_CODE --body '${quoteForSingleQuotedShell(accessCode)}'${repoArg}`);
  }

  return lines.join("\n");
}

function renderGithubCliBundledFormat(liveTarget, deployEnv, githubRepo) {
  const repoArg = buildGithubRepoArg(githubRepo);
  const bundledTargetJson = JSON.stringify(buildBundledLiveTarget(liveTarget));
  const lines = [
    `gh variable set FORUM_LIVE_TARGET --body '${quoteForSingleQuotedShell(bundledTargetJson)}'${repoArg}`,
  ];

  if (liveTarget.FORUM_LIVE_REQUIRES_ACCESS_CODE === "true") {
    const accessCode = (deployEnv.FORUM_WRITE_ACCESS_CODE || "").trim();

    lines.push("");
    lines.push("# Run this once if the preview write gate is enabled for the live target.");
    lines.push(`gh secret set FORUM_LIVE_WRITE_ACCESS_CODE --body '${quoteForSingleQuotedShell(accessCode)}'${repoArg}`);
  }

  return lines.join("\n");
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const forumUrl = normalizeUrl(args["forum-url"]?.trim() || "");

  if (!forumUrl) {
    throw new Error("Missing required --forum-url.");
  }

  const format = args.format?.trim() || "env";
  if (!["env", "json", "github-cli", "github-cli-bundled"].includes(format)) {
    throw new Error(`Expected --format to be env, json, github-cli, or github-cli-bundled, received: ${format}`);
  }

  const exerciseWriteFlow = parseBoolean(args["exercise-write-flow"], "exercise_write_flow");
  const githubRepo = args["github-repo"]?.trim() || "";

  const deployEnvContent = await readFile(args["deploy-env-path"], "utf-8");
  const deployEnv = parseDotEnv(deployEnvContent);
  const liveTarget = buildLiveTarget({ forumUrl, deployEnv, exerciseWriteFlow });

  if (format === "github-cli") {
    console.log(renderGithubCliFormat(liveTarget, deployEnv, githubRepo));
    return;
  }

  if (format === "github-cli-bundled") {
    console.log(renderGithubCliBundledFormat(liveTarget, deployEnv, githubRepo));
    return;
  }

  if (format === "json") {
    console.log(renderJsonFormat(liveTarget));
    return;
  }

  console.log(renderEnvFormat(liveTarget));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});