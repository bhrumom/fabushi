#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

function parseArgs(argv) {
  const parsed = {
    "deploy-env-path": ".env.deploy",
    "exercise-write-flow": "false",
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

function buildExpectedRuntime({ forumUrl, deployEnv, exerciseWriteFlow }) {
  const deploymentStage = deployEnv.FORUM_DEPLOYMENT_STAGE?.trim() || "preview";
  if (deploymentStage !== "preview" && deploymentStage !== "production") {
    throw new Error(
      `Expected FORUM_DEPLOYMENT_STAGE in deploy env to be preview or production, received: ${deploymentStage}`,
    );
  }

  const writesEnabled = parseBoolean(deployEnv.FORUM_ENABLE_WRITES ?? "false", "FORUM_ENABLE_WRITES");
  const writeAccessCode = (deployEnv.FORUM_WRITE_ACCESS_CODE || "").trim();
  const requiresAccessCode = writesEnabled && Boolean(writeAccessCode);
  const publicBaseUrl = normalizeUrl(deployEnv.FORUM_PUBLIC_BASE_URL?.trim() || "");

  if (exerciseWriteFlow && deploymentStage !== "preview") {
    throw new Error("exercise_write_flow can only be enabled for preview deployments.");
  }

  if (exerciseWriteFlow && !writesEnabled) {
    throw new Error("exercise_write_flow=true requires FORUM_ENABLE_WRITES=true in the deploy env file.");
  }

  return {
    forumUrl: normalizeUrl(forumUrl),
    deploymentStage,
    publicBaseUrl,
    writesEnabled,
    requiresAccessCode,
    exerciseWriteFlow,
    writeAccessCode,
  };
}

function runCheckScript(expectedRuntime, args) {
  const scriptDir = dirname(fileURLToPath(import.meta.url));
  const checkScriptPath = join(scriptDir, "check-deployment-contract.mjs");
  const commandArgs = [
    checkScriptPath,
    "--url",
    expectedRuntime.forumUrl,
    "--deployment-stage",
    expectedRuntime.deploymentStage,
    "--public-base-url",
    expectedRuntime.publicBaseUrl,
    "--writes-enabled",
    String(expectedRuntime.writesEnabled),
    "--requires-access-code",
    String(expectedRuntime.requiresAccessCode),
    "--exercise-write-flow",
    String(expectedRuntime.exerciseWriteFlow),
  ];

  if (args["request-timeout-ms"]) {
    commandArgs.push("--request-timeout-ms", args["request-timeout-ms"]);
  }

  if (args["report-path"]) {
    commandArgs.push("--report-path", args["report-path"]);
  }

  if (expectedRuntime.exerciseWriteFlow && expectedRuntime.requiresAccessCode) {
    commandArgs.push("--write-access-code", expectedRuntime.writeAccessCode);
  }

  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, commandArgs, {
      stdio: "inherit",
      env: process.env,
    });

    child.on("error", reject);
    child.on("exit", (code, signal) => {
      if (signal) {
        reject(new Error(`Deployment smoke check exited via signal: ${signal}`));
        return;
      }

      if (code !== 0) {
        reject(new Error(`Deployment smoke check exited with code ${code}.`));
        return;
      }

      resolve();
    });
  });
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const forumUrl = normalizeUrl(args["forum-url"]?.trim() || "");

  if (!forumUrl) {
    throw new Error("Missing required --forum-url.");
  }

  const exerciseWriteFlow = parseBoolean(args["exercise-write-flow"], "exercise_write_flow");
  const deployEnvContent = await readFile(args["deploy-env-path"], "utf-8");
  const deployEnv = parseDotEnv(deployEnvContent);
  const expectedRuntime = buildExpectedRuntime({ forumUrl, deployEnv, exerciseWriteFlow });

  await runCheckScript(expectedRuntime, args);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});