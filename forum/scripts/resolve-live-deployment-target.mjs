#!/usr/bin/env node

import { writeFile } from "node:fs/promises";

function parseBoolean(value, key) {
  if (value === undefined || value === null || value === "") {
    return undefined;
  }

  if (value === "true") {
    return true;
  }

  if (value === "false") {
    return false;
  }

  if (value === true || value === false) {
    return value;
  }

  throw new Error(`Expected ${key} to be true or false, received: ${value}`);
}

function normalizeUrl(value) {
  return value ? value.replace(/\/$/, "") : "";
}

function createPayload(target) {
  return JSON.stringify(target, null, 2);
}

function buildBundledLiveTarget(target) {
  return {
    forumUrl: target.forumUrl,
    deploymentStage: target.deploymentStage,
    publicBaseUrl: target.publicBaseUrl,
    writesEnabled: target.writesEnabled,
    requiresAccessCode: target.requiresAccessCode,
    exerciseWriteFlow: target.exerciseWriteFlow,
  };
}

function buildSkipNextStepLines(target) {
  return [
    "### How to unblock",
    "",
    "If the target host has not booted the forum yet, start with the combined rollout helper:",
    "",
    "```bash",
    target.recommendedRolloutCommand,
    "```",
    "",
    "Once the forum is reachable at its real preview or production URL, sync that verified target back to the hourly checks:",
    "",
    "```bash",
    target.recommendedHandoffCommand,
    "```",
    "",
    "If the target host is production and `.env.deploy` already sets `FORUM_PUBLIC_BASE_URL`, the shorter deploy-env-driven path is:",
    "",
    "```bash",
    target.recommendedProductionRolloutCommand,
    "```",
    "",
    "If that production host is already running and only the hourly target still needs syncing, you can also use:",
    "",
    "```bash",
    target.recommendedProductionHandoffCommand,
    "```",
    "",
    "That generic rollout command can scaffold `.env.deploy`, validate the deploy posture, bring the compose stack up, wait for health, and smoke-check the runtime.",
    "That generic handoff command re-validates `.env.deploy`, smoke-checks the live runtime, and syncs `FORUM_LIVE_TARGET` back to `bhrumom/fabushi`.",
    "For production, the shorter commands above can stay fully deploy-env driven once `.env.deploy` already declares the final `FORUM_PUBLIC_BASE_URL`.",
    "With `--apply-github-live-target true`, writable preview can also sync `FORUM_LIVE_WRITE_ACCESS_CODE`.",
    "",
    "If you want a one-off verification before saving hourly config, run this workflow manually with the same forum URL and posture inputs.",
    `Guide: ${target.nextStepGuidePath}`,
  ];
}

function buildReadySaveLines(target) {
  return [
    "",
    "### Save for hourly checks",
    "",
    "If this verified runtime should become the standing hourly target, save the bundled payload below into the repository variable `FORUM_LIVE_TARGET`:",
    "",
    "```json",
    JSON.stringify(target.bundledTarget, null, 2),
    "```",
    target.requiresAccessCode
      ? "Keep the repository secret `FORUM_LIVE_WRITE_ACCESS_CODE` aligned with the preview write gate too."
      : "No `FORUM_LIVE_WRITE_ACCESS_CODE` secret update is required for this posture.",
  ];
}

function buildSummaryLines(target) {
  if (target.skip) {
    return [
      "## Live forum target",
      "",
      "- status: skipped",
      `- reason: ${target.reason}`,
      `- missing config: ${target.missingConfig.join(", ")}`,
      `- guide: ${target.nextStepGuidePath}`,
      "",
      ...buildSkipNextStepLines(target),
    ];
  }

  return [
    "## Live forum target",
    "",
    "- status: ready to check",
    `- forum_url: ${target.forumUrl}`,
    `- deployment_stage: ${target.deploymentStage}`,
    `- public_base_url: ${target.publicBaseUrl || "(empty)"}`,
    `- writes_enabled: ${String(target.writesEnabled)}`,
    `- requires_access_code: ${String(target.requiresAccessCode)}`,
    `- exercise_write_flow: ${String(target.exerciseWriteFlow)}`,
    `- request_timeout_ms: ${target.requestTimeoutMs}`,
    ...target.warnings.map((warning) => `- warning: ${warning}`),
    ...buildReadySaveLines(target),
  ];
}

function parseBundledTarget(rawValue) {
  if (!rawValue?.trim()) {
    return {};
  }

  let parsed;

  try {
    parsed = JSON.parse(rawValue);
  } catch (error) {
    throw new Error(`FORUM_LIVE_TARGET must be valid JSON: ${error instanceof Error ? error.message : String(error)}`);
  }

  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("FORUM_LIVE_TARGET must decode to a JSON object.");
  }

  return {
    forumUrl: typeof parsed.forumUrl === "string" ? parsed.forumUrl : parsed.FORUM_LIVE_URL,
    deploymentStage:
      typeof parsed.deploymentStage === "string" ? parsed.deploymentStage : parsed.FORUM_LIVE_DEPLOYMENT_STAGE,
    publicBaseUrl:
      typeof parsed.publicBaseUrl === "string" ? parsed.publicBaseUrl : parsed.FORUM_LIVE_PUBLIC_BASE_URL,
    writesEnabled:
      typeof parsed.writesEnabled === "boolean"
        ? parsed.writesEnabled
        : parseBoolean(parsed.FORUM_LIVE_WRITES_ENABLED, "FORUM_LIVE_TARGET.FORUM_LIVE_WRITES_ENABLED"),
    requiresAccessCode:
      typeof parsed.requiresAccessCode === "boolean"
        ? parsed.requiresAccessCode
        : parseBoolean(
            parsed.FORUM_LIVE_REQUIRES_ACCESS_CODE,
            "FORUM_LIVE_TARGET.FORUM_LIVE_REQUIRES_ACCESS_CODE",
          ),
    exerciseWriteFlow:
      typeof parsed.exerciseWriteFlow === "boolean"
        ? parsed.exerciseWriteFlow
        : parseBoolean(
            parsed.FORUM_LIVE_EXERCISE_WRITE_FLOW,
            "FORUM_LIVE_TARGET.FORUM_LIVE_EXERCISE_WRITE_FLOW",
          ),
  };
}

function resolveConfigValue({ bundledValue, envValue, normalize = (value) => value }) {
  if (bundledValue !== undefined) {
    return normalize(bundledValue);
  }

  return normalize(envValue);
}

async function main() {
  const source = process.env.FORUM_LIVE_SOURCE || "scheduled";
  const bundledTarget = parseBundledTarget(process.env.FORUM_LIVE_TARGET || "");
  const forumUrl = normalizeUrl(
    resolveConfigValue({
      bundledValue: bundledTarget.forumUrl,
      envValue: process.env.FORUM_LIVE_URL?.trim() || "",
      normalize: (value) => (typeof value === "string" ? normalizeUrl(value.trim()) : ""),
    }),
  );

  if (!forumUrl) {
    const skippedTarget = {
      source,
      skip: true,
      reason: "No forum URL configured for scheduled live deployment checks.",
      missingConfig: ["FORUM_LIVE_TARGET or FORUM_LIVE_URL"],
      nextStepGuidePath: "forum/DEPLOY.md",
      recommendedRolloutCommand: [
        "cd forum",
        "pnpm rollout:deploy-env -- \\",
        "  --deploy-env-path .env.deploy \\",
        "  --scaffold-if-missing true",
      ].join("\n"),
      recommendedHandoffCommand: [
        "cd forum",
        "pnpm handoff:live-target -- \\",
        "  --forum-url https://forum-preview.example.com \\",
        "  --deploy-env-path .env.deploy \\",
        "  --apply-github-live-target true",
      ].join("\n"),
      recommendedProductionRolloutCommand: [
        "cd forum",
        "pnpm rollout:deploy-env -- \\",
        "  --deploy-env-path .env.deploy \\",
        "  --apply-github-live-target true",
      ].join("\n"),
      recommendedProductionHandoffCommand: [
        "cd forum",
        "pnpm handoff:live-target -- \\",
        "  --deploy-env-path .env.deploy \\",
        "  --apply-github-live-target true",
      ].join("\n"),
      repositoryConfigTargets: ["FORUM_LIVE_TARGET"],
      optionalSecretTargets: ["FORUM_LIVE_WRITE_ACCESS_CODE"],
    };

    if (process.env.FORUM_LIVE_TARGET_PATH) {
      await writeFile(process.env.FORUM_LIVE_TARGET_PATH, `${createPayload(skippedTarget)}\n`, "utf-8");
    }

    if (process.env.GITHUB_STEP_SUMMARY) {
      await writeFile(process.env.GITHUB_STEP_SUMMARY, `${buildSummaryLines(skippedTarget).join("\n")}\n`, {
        encoding: "utf-8",
        flag: "a",
      });
    }

    return;
  }

  const deploymentStage = resolveConfigValue({
    bundledValue: bundledTarget.deploymentStage,
    envValue: process.env.FORUM_LIVE_DEPLOYMENT_STAGE?.trim() || "preview",
    normalize: (value) => (typeof value === "string" ? value.trim() || "preview" : "preview"),
  });
  if (deploymentStage !== "preview" && deploymentStage !== "production") {
    throw new Error(`Expected FORUM_LIVE_DEPLOYMENT_STAGE to be preview or production, received: ${deploymentStage}`);
  }

  const writesEnabled =
    resolveConfigValue({
      bundledValue: bundledTarget.writesEnabled,
      envValue: parseBoolean(process.env.FORUM_LIVE_WRITES_ENABLED ?? "false", "FORUM_LIVE_WRITES_ENABLED") ?? false,
    }) ?? false;
  const requiresAccessCode =
    resolveConfigValue({
      bundledValue: bundledTarget.requiresAccessCode,
      envValue:
        parseBoolean(process.env.FORUM_LIVE_REQUIRES_ACCESS_CODE ?? "false", "FORUM_LIVE_REQUIRES_ACCESS_CODE") ??
        false,
    }) ?? false;
  const exerciseWriteFlow =
    resolveConfigValue({
      bundledValue: bundledTarget.exerciseWriteFlow,
      envValue:
        parseBoolean(process.env.FORUM_LIVE_EXERCISE_WRITE_FLOW ?? "false", "FORUM_LIVE_EXERCISE_WRITE_FLOW") ??
        false,
    }) ?? false;

  const publicBaseUrl = normalizeUrl(
    resolveConfigValue({
      bundledValue: bundledTarget.publicBaseUrl,
      envValue: process.env.FORUM_LIVE_PUBLIC_BASE_URL?.trim() || "",
      normalize: (value) => (typeof value === "string" ? normalizeUrl(value.trim()) : ""),
    }),
  );
  const writeAccessCode = process.env.FORUM_LIVE_WRITE_ACCESS_CODE?.trim() || "";
  const requestTimeoutMs = Number.parseInt(process.env.FORUM_LIVE_REQUEST_TIMEOUT_MS || "15000", 10);

  if (!Number.isFinite(requestTimeoutMs) || requestTimeoutMs <= 0) {
    throw new Error(
      `Expected FORUM_LIVE_REQUEST_TIMEOUT_MS to be a positive integer, received: ${process.env.FORUM_LIVE_REQUEST_TIMEOUT_MS}`,
    );
  }

  if (requiresAccessCode && !writesEnabled) {
    throw new Error("FORUM_LIVE_REQUIRES_ACCESS_CODE=true requires FORUM_LIVE_WRITES_ENABLED=true.");
  }

  if (exerciseWriteFlow && deploymentStage !== "preview") {
    throw new Error("FORUM_LIVE_EXERCISE_WRITE_FLOW=true is only supported for preview runtimes.");
  }

  if (exerciseWriteFlow && !writesEnabled) {
    throw new Error("FORUM_LIVE_EXERCISE_WRITE_FLOW=true requires FORUM_LIVE_WRITES_ENABLED=true.");
  }

  if (exerciseWriteFlow && requiresAccessCode && !writeAccessCode) {
    throw new Error(
      "FORUM_LIVE_EXERCISE_WRITE_FLOW=true with FORUM_LIVE_REQUIRES_ACCESS_CODE=true requires secret FORUM_LIVE_WRITE_ACCESS_CODE.",
    );
  }

  const warnings = [];

  if (process.env.FORUM_LIVE_TARGET?.trim()) {
    warnings.push("live checks are reading the bundled FORUM_LIVE_TARGET variable; keep it aligned with the deploy env.");
  }

  if (deploymentStage === "preview" && publicBaseUrl) {
    warnings.push("preview checks received FORUM_LIVE_PUBLIC_BASE_URL; indexing still stays off until production mode.");
  }

  if (deploymentStage === "production" && !publicBaseUrl) {
    warnings.push("production checks are running without FORUM_LIVE_PUBLIC_BASE_URL, so the live forum is expected to stay noindex.");
  }

  const resolvedTarget = {
    source,
    skip: false,
    forumUrl,
    deploymentStage,
    publicBaseUrl,
    writesEnabled,
    requiresAccessCode,
    exerciseWriteFlow,
    requestTimeoutMs,
    warnings,
    bundledTarget: buildBundledLiveTarget({
      forumUrl,
      deploymentStage,
      publicBaseUrl,
      writesEnabled,
      requiresAccessCode,
      exerciseWriteFlow,
    }),
    repositoryConfigTargets: ["FORUM_LIVE_TARGET"],
    optionalSecretTargets: requiresAccessCode ? ["FORUM_LIVE_WRITE_ACCESS_CODE"] : [],
  };

  if (process.env.FORUM_LIVE_TARGET_PATH) {
    await writeFile(process.env.FORUM_LIVE_TARGET_PATH, `${createPayload(resolvedTarget)}\n`, "utf-8");
  }

  if (process.env.GITHUB_STEP_SUMMARY) {
    await writeFile(process.env.GITHUB_STEP_SUMMARY, `${buildSummaryLines(resolvedTarget).join("\n")}\n`, {
      encoding: "utf-8",
      flag: "a",
    });
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});