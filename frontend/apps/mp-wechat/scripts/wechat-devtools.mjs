#!/usr/bin/env node
import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const appRoot = resolve(__dirname, "..");
const distRoot = resolve(appRoot, "dist");
const action = process.argv[2] || "open";

const cliCandidates = [
  process.env.WECHAT_DEVTOOLS_CLI,
  "/Applications/wechatwebdevtools.app/Contents/MacOS/cli",
  "/Applications/WeChatwebdevtools.app/Contents/MacOS/cli",
].filter(Boolean);

function findCli() {
  return cliCandidates.find((candidate) => existsSync(candidate));
}

function ensureDist() {
  if (!existsSync(distRoot)) {
    console.error("Missing dist/. Run npm run build:weapp first.");
    process.exit(1);
  }
}

function ensureCli() {
  const cli = findCli();
  if (!cli) {
    console.error(
      "WeChat DevTools CLI was not found. Set WECHAT_DEVTOOLS_CLI to the cli executable path.",
    );
    process.exit(1);
  }
  return cli;
}

if (action === "check") {
  ensureDist();
  const cli = ensureCli();
  console.log(`WeChat DevTools CLI: ${cli}`);
  console.log(`Project root: ${appRoot}`);
  process.exit(0);
}

if (!["open", "preview"].includes(action)) {
  console.error(`Unsupported action: ${action}`);
  process.exit(1);
}

ensureDist();
const cli = ensureCli();
const result = spawnSync(cli, [action, "--project", appRoot], {
  stdio: "inherit",
});

process.exit(result.status ?? 1);
