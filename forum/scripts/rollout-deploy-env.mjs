#!/usr/bin/env node

import { readFile, access } from "node:fs/promises";
import { constants as fsConstants } from "node:fs";
import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { parseDotEnv } from "./parse-deploy-env.mjs";

function parseArgs(argv) {
  const parsed = {
    "deploy-env-path": ".env.deploy",
    "compose-file": "docker-compose.deploy.yml",
    detach: "true",
    "handoff-live-target": "auto",
    "exercise-write-flow": "false",
    "apply-github-live-target": "false",
    "github-repo": "bhrumom/fabushi",
    "scaffold-if-missing": "false",
    "scaffold-preset": "read-only-preview",
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

function parseInteger(value, key) {
  if (value === undefined || value === null || value === "") {
    return undefined;
  }

  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`Expected ${key} to be a positive integer, received: ${value}`);
  }

  return parsed;
}

function normalizeUrl(value) {
  return value ? value.replace(/\/$/, "") : "";
}

function validateHandoffMode(value) {
  if (value === "auto" || value === "true" || value === "false") {
    return value;
  }

  throw new Error(`Expected --handoff-live-target to be auto, true, or false, received: ${value}`);
}

function sleep(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function runNodeScript(scriptName, scriptArgs) {
  const scriptDir = dirname(fileURLToPath(import.meta.url));
  const scriptPath = join(scriptDir, scriptName);

  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [scriptPath, ...scriptArgs], {
      stdio: "inherit",
      env: process.env,
    });

    child.on("error", reject);
    child.on("exit", (code, signal) => {
      if (signal) {
        reject(new Error(`${scriptName} exited via signal: ${signal}`));
        return;
      }

      if (code !== 0) {
        reject(new Error(`${scriptName} exited with code ${code}.`));
        return;
      }

      resolve();
    });
  });
}

function runDockerComposeUp({ deployEnvPath, composeFile, detach, composeProjectName }) {
  const args = ["compose", "--env-file", deployEnvPath, "-f", composeFile, "up"];
  if (detach) {
    args.push("-d");
  }

  return new Promise((resolve, reject) => {
    const child = spawn("docker", args, {
      stdio: "inherit",
      env: {
        ...process.env,
        ...(composeProjectName ? { COMPOSE_PROJECT_NAME: composeProjectName } : {}),
      },
    });

    child.on("error", reject);
    child.on("exit", (code, signal) => {
      if (signal) {
        reject(new Error(`docker compose up exited via signal: ${signal}`));
        return;
      }

      if (code !== 0) {
        reject(new Error(`docker compose up exited with code ${code}.`));
        return;
      }

      resolve();
    });
  });
}

async function deployEnvExists(deployEnvPath) {
  try {
    await access(deployEnvPath, fsConstants.F_OK);
    return true;
  } catch {
    return false;
  }
}

function buildScaffoldArgs(args, deployEnvPath) {
  const scaffoldArgs = ["--deploy-env-path", deployEnvPath, "--preset", args["scaffold-preset"]];
  const passthroughKeys = [
    "forum-image",
    "forum-port",
    "forum-data-dir",
    "deploy-check-url",
    "data-source",
    "writes-enabled",
    "write-access-code",
    "deployment-stage",
    "public-base-url",
  ];

  for (const key of passthroughKeys) {
    const value = args[key];
    if (value === undefined || value === null || value === "") {
      continue;
    }

    scaffoldArgs.push(`--${key}`, value);
  }

  return scaffoldArgs;
}

async function loadDeployEnv(deployEnvPath) {
  const deployEnvContent = await readFile(deployEnvPath, "utf-8");
  return parseDotEnv(deployEnvContent);
}

async function waitForLocalHealth(deployEnv, requestTimeoutMs) {
  const port = deployEnv.FORUM_PORT?.trim() || "3000";
  const healthUrl = `http://127.0.0.1:${port}/api/health`;
  const timeoutMs = requestTimeoutMs ?? 5000;

  let lastError = null;

  for (let attempt = 1; attempt <= 10; attempt += 1) {
    try {
      const response = await fetch(healthUrl, {
        redirect: "follow",
        signal: AbortSignal.timeout(timeoutMs),
      });

      if (response.ok) {
        console.log(`Health probe ready at ${healthUrl} after attempt ${attempt}.`);
        return;
      }

      const body = await response.text();
      lastError = new Error(`Health probe returned ${response.status}: ${body}`);
    } catch (error) {
      lastError = error;
    }

    await sleep(3000);
  }

  throw new Error(
    `Timed out waiting for local health probe ${healthUrl}: ${lastError instanceof Error ? lastError.message : String(lastError)}`,
  );
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const deployEnvPath = args["deploy-env-path"];
  const composeFile = args["compose-file"];
  const detach = parseBoolean(args.detach, "detach");
  const handoffMode = validateHandoffMode(args["handoff-live-target"]?.trim() || "auto");
  const exerciseWriteFlow = parseBoolean(args["exercise-write-flow"], "exercise_write_flow");
  const applyGithubLiveTarget = parseBoolean(args["apply-github-live-target"], "apply_github_live_target");
  const githubRepo = args["github-repo"]?.trim() || "";
  const composeProjectName = args["compose-project-name"]?.trim() || "";
  const explicitForumUrl = normalizeUrl(args["forum-url"]?.trim() || "");
  const requestTimeoutMs = parseInteger(args["request-timeout-ms"], "request_timeout_ms");
  const scaffoldIfMissing = parseBoolean(args["scaffold-if-missing"], "scaffold_if_missing");

  if (handoffMode === "false" && applyGithubLiveTarget) {
    throw new Error("--apply-github-live-target true requires handoff-live-target to stay enabled.");
  }

  if (applyGithubLiveTarget && !githubRepo) {
    throw new Error("--apply-github-live-target true requires --github-repo.");
  }

  if (!(await deployEnvExists(deployEnvPath))) {
    if (!scaffoldIfMissing) {
      throw new Error(
        `Deploy env file ${deployEnvPath} does not exist. Re-run with --scaffold-if-missing true or create the file first.`,
      );
    }

    console.log("== Scaffold deploy env ==");
    await runNodeScript("scaffold-deploy-env.mjs", buildScaffoldArgs(args, deployEnvPath));
    console.log("");
  }

  const deployEnv = await loadDeployEnv(deployEnvPath);
  const deployCheckUrl = normalizeUrl(deployEnv.FORUM_DEPLOY_CHECK_URL?.trim() || "");
  const handoffUrl = explicitForumUrl || deployCheckUrl;

  const sharedArgs = ["--deploy-env-path", deployEnvPath];

  console.log("== Deploy env preflight ==");
  await runNodeScript("validate-deploy-env.mjs", sharedArgs);

  console.log("\n== Deploy compose up ==");
  await runDockerComposeUp({ deployEnvPath, composeFile, detach, composeProjectName });

  console.log("\n== Wait for local health probe ==");
  await waitForLocalHealth(deployEnv, requestTimeoutMs);

  console.log("\n== Deployed runtime smoke check ==");
  const smokeArgs = [...sharedArgs, "--exercise-write-flow", String(exerciseWriteFlow)];
  if (explicitForumUrl) {
    smokeArgs.push("--forum-url", explicitForumUrl);
  }
  if (requestTimeoutMs) {
    smokeArgs.push("--request-timeout-ms", String(requestTimeoutMs));
  }
  if (args["report-path"]) {
    smokeArgs.push("--report-path", args["report-path"]);
  }
  await runNodeScript("smoke-deployment-from-env.mjs", smokeArgs);

  if (handoffMode === "false") {
    return;
  }

  if (!handoffUrl) {
    if (handoffMode === "true") {
      throw new Error(
        "Handoff requires either --forum-url or FORUM_DEPLOY_CHECK_URL in the deploy env file.",
      );
    }

    console.log("\n== Hourly live target handoff ==");
    console.log(
      "Skipping handoff because neither --forum-url nor FORUM_DEPLOY_CHECK_URL is available yet. Re-run with the real preview or production URL once it exists.",
    );
    return;
  }

  console.log("\n== Hourly live target handoff ==");
  const handoffArgs = [...sharedArgs, "--exercise-write-flow", String(exerciseWriteFlow)];
  if (explicitForumUrl) {
    handoffArgs.push("--forum-url", explicitForumUrl);
  }
  if (requestTimeoutMs) {
    handoffArgs.push("--request-timeout-ms", String(requestTimeoutMs));
  }
  if (args["report-path"]) {
    handoffArgs.push("--report-path", args["report-path"]);
  }
  if (args.format) {
    handoffArgs.push("--format", args.format);
  }
  if (applyGithubLiveTarget) {
    handoffArgs.push("--apply-github-live-target", "true");
  }
  if (githubRepo) {
    handoffArgs.push("--github-repo", githubRepo);
  }

  await runNodeScript("handoff-live-deployment-target.mjs", handoffArgs);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});