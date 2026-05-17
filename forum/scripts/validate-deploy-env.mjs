#!/usr/bin/env node

import { readFile } from "node:fs/promises";

import { parseDotEnv } from "./parse-deploy-env.mjs";

function parseArgs(argv) {
  const parsed = {
    "deploy-env-path": ".env.deploy",
    format: "summary",
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

function buildLocalSmokeUrl(port) {
  return normalizeUrl(`http://127.0.0.1:${port}`);
}

function buildDeployPosture({ deployEnvPath, deployEnv }) {
  const deploymentStage = deployEnv.FORUM_DEPLOYMENT_STAGE?.trim() || "preview";
  if (deploymentStage !== "preview" && deploymentStage !== "production") {
    throw new Error(
      `Expected FORUM_DEPLOYMENT_STAGE in deploy env to be preview or production, received: ${deploymentStage}`,
    );
  }

  const dataSource = deployEnv.FORUM_DATA_SOURCE?.trim() || "sqlite";
  if (dataSource !== "sqlite" && dataSource !== "seed-json") {
    throw new Error(`Expected FORUM_DATA_SOURCE in deploy env to be sqlite or seed-json, received: ${dataSource}`);
  }

  const image = deployEnv.FORUM_IMAGE?.trim() || "ghcr.io/bhrumom/fabushi-forum:main";
  const port = deployEnv.FORUM_PORT?.trim() || "3000";
  const dataDir = deployEnv.FORUM_DATA_DIR?.trim() || "./data";
  const deployCheckUrl = normalizeUrl(deployEnv.FORUM_DEPLOY_CHECK_URL?.trim() || "");
  const defaultSmokeUrl = deployCheckUrl || buildLocalSmokeUrl(port);
  const publicBaseUrl = normalizeUrl(deployEnv.FORUM_PUBLIC_BASE_URL?.trim() || "");
  const writesEnabled = parseBoolean(deployEnv.FORUM_ENABLE_WRITES ?? "false", "FORUM_ENABLE_WRITES");
  const writeAccessCode = (deployEnv.FORUM_WRITE_ACCESS_CODE || "").trim();
  const requiresAccessCode = writesEnabled && Boolean(writeAccessCode);

  const warnings = [];

  if (!deployCheckUrl) {
    warnings.push(
      `FORUM_DEPLOY_CHECK_URL is empty, so handoff helpers still require an explicit --forum-url. smoke:deploy-env will fall back to ${defaultSmokeUrl} on the target host.`,
    );
  }

  if (deploymentStage === "preview" && publicBaseUrl) {
    warnings.push("preview deploy env sets FORUM_PUBLIC_BASE_URL; the runtime will still stay noindex until production mode.");
  }

  if (deploymentStage === "production" && !publicBaseUrl) {
    warnings.push("production deploy env omits FORUM_PUBLIC_BASE_URL, so the runtime will still behave as noindex.");
  }

  if (!writesEnabled && writeAccessCode) {
    warnings.push(
      "FORUM_WRITE_ACCESS_CODE is set while writes are disabled; the shared preview gate will stay inactive until FORUM_ENABLE_WRITES=true.",
    );
  }

  if (deploymentStage === "production" && writesEnabled) {
    warnings.push(
      "production deploy env keeps writes enabled; confirm moderation and access posture before exposing a public indexed runtime.",
    );
  }

  if (dataSource !== "sqlite") {
    warnings.push("deploy compose currently defaults to sqlite durable storage; confirm this alternative data source is intentional.");
  }

  return {
    status: "ready",
    deployEnvPath,
    image,
    port,
    dataDir,
    deployCheckUrl,
    defaultSmokeUrl,
    dataSource,
    deploymentStage,
    publicBaseUrl,
    writesEnabled,
    requiresAccessCode,
    warnings,
  };
}

function renderSummary(posture) {
  return [
    "## Deploy env posture",
    "",
    "- status: ready to deploy",
    `- deploy_env_path: ${posture.deployEnvPath}`,
    `- image: ${posture.image}`,
    `- port: ${posture.port}`,
    `- data_dir: ${posture.dataDir}`,
    `- deploy_check_url: ${posture.deployCheckUrl || "(empty)"}`,
    `- default_smoke_url: ${posture.defaultSmokeUrl}`,
    `- data_source: ${posture.dataSource}`,
    `- deployment_stage: ${posture.deploymentStage}`,
    `- public_base_url: ${posture.publicBaseUrl || "(empty)"}`,
    `- writes_enabled: ${String(posture.writesEnabled)}`,
    `- requires_access_code: ${String(posture.requiresAccessCode)}`,
    ...posture.warnings.map((warning) => `- warning: ${warning}`),
  ].join("\n");
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const format = args.format?.trim() || "summary";

  if (format !== "summary" && format !== "json") {
    throw new Error(`Expected --format to be summary or json, received: ${format}`);
  }

  const deployEnvPath = args["deploy-env-path"];
  const deployEnvContent = await readFile(deployEnvPath, "utf-8");
  const deployEnv = parseDotEnv(deployEnvContent);
  const posture = buildDeployPosture({ deployEnvPath, deployEnv });

  if (format === "json") {
    console.log(`${JSON.stringify(posture, null, 2)}`);
    return;
  }

  console.log(renderSummary(posture));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});