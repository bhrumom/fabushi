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

  throw new Error(`Expected ${key} to be true or false, received: ${value}`);
}

function normalizeUrl(value) {
  return value ? value.replace(/\/$/, "") : "";
}

function createPayload(target) {
  return JSON.stringify(target, null, 2);
}

function buildSummaryLines(target) {
  if (target.skip) {
    return [
      "## Live forum target",
      "",
      "- status: skipped",
      `- reason: ${target.reason}`,
      "- next config: set FORUM_LIVE_URL and the related FORUM_LIVE_* repository variables before expecting hourly checks to hit a real target",
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
  ];
}

async function main() {
  const source = process.env.FORUM_LIVE_SOURCE || "scheduled";
  const forumUrl = normalizeUrl(process.env.FORUM_LIVE_URL?.trim() || "");

  if (!forumUrl) {
    const skippedTarget = {
      source,
      skip: true,
      reason: "No forum URL configured for scheduled live deployment checks.",
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

  const deploymentStage = process.env.FORUM_LIVE_DEPLOYMENT_STAGE?.trim() || "preview";
  if (deploymentStage !== "preview" && deploymentStage !== "production") {
    throw new Error(`Expected FORUM_LIVE_DEPLOYMENT_STAGE to be preview or production, received: ${deploymentStage}`);
  }

  const writesEnabled = parseBoolean(process.env.FORUM_LIVE_WRITES_ENABLED ?? "false", "FORUM_LIVE_WRITES_ENABLED") ?? false;
  const requiresAccessCode =
    parseBoolean(process.env.FORUM_LIVE_REQUIRES_ACCESS_CODE ?? "false", "FORUM_LIVE_REQUIRES_ACCESS_CODE") ?? false;
  const exerciseWriteFlow =
    parseBoolean(process.env.FORUM_LIVE_EXERCISE_WRITE_FLOW ?? "false", "FORUM_LIVE_EXERCISE_WRITE_FLOW") ?? false;

  const publicBaseUrl = normalizeUrl(process.env.FORUM_LIVE_PUBLIC_BASE_URL?.trim() || "");
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
