#!/usr/bin/env node
import { mkdir, rename, writeFile } from "node:fs/promises";
import { isAbsolute, join, resolve } from "node:path";

const directoryValue = String(process.env.FABUSHI_CI_SESSION_DIR || "").trim();
if (process.env.GITHUB_ACTIONS !== "true") throw new Error("This status writer is restricted to GitHub Actions.");
if (!directoryValue || !isAbsolute(directoryValue)) throw new Error("FABUSHI_CI_SESSION_DIR must be an absolute path.");
const directory = resolve(directoryValue);
const runnerTemp = resolve(String(process.env.RUNNER_TEMP || ""));
if (!runnerTemp || (directory !== runnerTemp && !directory.startsWith(`${runnerTemp}/`))) {
  throw new Error("FABUSHI_CI_SESSION_DIR must be inside RUNNER_TEMP.");
}

const [phaseValue, messageValue, appReadyValue = "false", appExecutableValue = ""] = process.argv.slice(2);
const phase = String(phaseValue || "").trim();
const message = String(messageValue || "").trim();
if (!/^[a-z0-9][a-z0-9-]{0,99}$/u.test(phase)) throw new Error("phase is invalid");
if (!message || message.length > 2_000) throw new Error("message must contain 1-2000 characters");
const deviceId = String(process.env.DEVICE_ID || "").trim();
const serverUrl = String(process.env.GITHUB_SERVER_URL || "https://github.com").replace(/\/$/u, "");
const repository = String(process.env.GITHUB_REPOSITORY || "").trim();
const runId = String(process.env.GITHUB_RUN_ID || "").trim();
const runUrl = repository && runId ? `${serverUrl}/${repository}/actions/runs/${runId}` : "";
const payload = {
  phase,
  message,
  appReady: appReadyValue === "true",
  appExecutable: String(appExecutableValue || "").slice(0, 1_000),
  deviceId: deviceId.slice(0, 128),
  runUrl,
  updatedAt: new Date().toISOString(),
};
await mkdir(directory, { recursive: true, mode: 0o700 });
const target = join(directory, "status.json");
const temporary = join(directory, `status.${process.pid}.${Date.now()}.tmp`);
await writeFile(temporary, `${JSON.stringify(payload, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
await rename(temporary, target);
console.log(`${phase}: ${message}`);
