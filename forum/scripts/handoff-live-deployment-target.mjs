#!/usr/bin/env node

import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

function parseArgs(argv) {
  const parsed = {
    "deploy-env-path": ".env.deploy",
    "exercise-write-flow": "false",
    format: "github-cli-bundled",
    "apply-github-live-target": "false",
    "github-repo": "bhrumom/fabushi",
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

function runNodeScript(scriptName, scriptArgs, options = {}) {
  const scriptDir = dirname(fileURLToPath(import.meta.url));
  const scriptPath = join(scriptDir, scriptName);
  const captureStdout = options.captureStdout === true;
  const stdio = captureStdout ? ["inherit", "pipe", "inherit"] : "inherit";

  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [scriptPath, ...scriptArgs], {
      stdio,
      env: process.env,
    });

    let stdout = "";

    if (captureStdout && child.stdout) {
      child.stdout.setEncoding("utf8");
      child.stdout.on("data", (chunk) => {
        stdout += chunk;
      });
    }

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

      resolve(stdout);
    });
  });
}

function runShellCommand(command) {
  return new Promise((resolve, reject) => {
    const child = spawn("sh", ["-lc", command], {
      stdio: "inherit",
      env: process.env,
    });

    child.on("error", reject);
    child.on("exit", (code, signal) => {
      if (signal) {
        reject(new Error(`Shell command exited via signal: ${signal}`));
        return;
      }

      if (code !== 0) {
        reject(new Error(`Shell command exited with code ${code}: ${command}`));
        return;
      }

      resolve();
    });
  });
}

async function runCommandBlock(commandBlock) {
  for (const rawLine of commandBlock.split(/\r?\n/)) {
    const line = rawLine.trim();

    if (!line || line.startsWith("#")) {
      continue;
    }

    await runShellCommand(line);
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const forumUrl = normalizeUrl(args["forum-url"]?.trim() || "");

  if (!forumUrl) {
    throw new Error("Missing required --forum-url.");
  }

  const format = args.format?.trim() || "github-cli-bundled";
  if (!["env", "json", "github-cli", "github-cli-bundled"].includes(format)) {
    throw new Error(`Expected --format to be env, json, github-cli, or github-cli-bundled, received: ${format}`);
  }

  const exerciseWriteFlow = parseBoolean(args["exercise-write-flow"], "exercise_write_flow");
  const applyGithubLiveTarget = parseBoolean(args["apply-github-live-target"], "apply_github_live_target");
  const githubRepo = args["github-repo"]?.trim() || "";

  if (applyGithubLiveTarget && !githubRepo) {
    throw new Error("--apply-github-live-target true requires --github-repo.");
  }

  const sharedArgs = ["--deploy-env-path", args["deploy-env-path"]];
  const smokeArgs = [
    "--forum-url",
    forumUrl,
    ...sharedArgs,
    "--exercise-write-flow",
    String(exerciseWriteFlow),
  ];

  if (args["request-timeout-ms"]) {
    smokeArgs.push("--request-timeout-ms", args["request-timeout-ms"]);
  }

  if (args["report-path"]) {
    smokeArgs.push("--report-path", args["report-path"]);
  }

  const preparedOutputs = new Map();
  async function getPreparedOutput(outputFormat) {
    if (preparedOutputs.has(outputFormat)) {
      return preparedOutputs.get(outputFormat);
    }

    const prepareArgs = [
      "--forum-url",
      forumUrl,
      ...sharedArgs,
      "--exercise-write-flow",
      String(exerciseWriteFlow),
      "--format",
      outputFormat,
      "--github-repo",
      githubRepo,
    ];
    const output = await runNodeScript("prepare-live-deployment-vars.mjs", prepareArgs, {
      captureStdout: true,
    });
    preparedOutputs.set(outputFormat, output);
    return output;
  }

  console.log("== Deploy env preflight ==");
  await runNodeScript("validate-deploy-env.mjs", sharedArgs);

  console.log("\n== Deployed runtime smoke check ==");
  await runNodeScript("smoke-deployment-from-env.mjs", smokeArgs);

  console.log("\n== Hourly live target handoff ==");
  const preparedOutput = await getPreparedOutput(format);
  process.stdout.write(preparedOutput.endsWith("\n") ? preparedOutput : `${preparedOutput}\n`);

  if (!applyGithubLiveTarget) {
    return;
  }

  console.log("\n== GitHub live target sync ==");
  const applyCommandBlock = format === "github-cli-bundled" ? preparedOutput : await getPreparedOutput("github-cli-bundled");
  if (format !== "github-cli-bundled") {
    process.stdout.write(applyCommandBlock.endsWith("\n") ? applyCommandBlock : `${applyCommandBlock}\n`);
  }

  await runCommandBlock(applyCommandBlock);
  console.log(`Applied FORUM_LIVE_TARGET to GitHub repo ${githubRepo}.`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});