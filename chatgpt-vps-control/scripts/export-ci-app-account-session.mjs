#!/usr/bin/env node
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, resolve, sep } from "node:path";

const MAX_SESSION_BYTES = 64 * 1024;
const MAX_LIFETIME_SECONDS = 5 * 60 * 60;

function required(name) {
  const value = String(process.env[name] || "").trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

function privateActionsPath(value, runnerTemp, name) {
  const path = resolve(value);
  const root = resolve(runnerTemp);
  if (!path.startsWith(`${root}${sep}`)) {
    throw new Error(`${name} must live under RUNNER_TEMP.`);
  }
  return path;
}

function validCredential(value) {
  return value.length >= 24 && value.length <= 16 * 1024 && !/\s/u.test(value);
}

function isProtectedActionsTestDeviceId(value) {
  return /^gha-[0-9]+-[0-9]+-(?:interactive|ios-app|macos-app)$/u.test(value);
}

if (process.env.GITHUB_ACTIONS !== "true") {
  throw new Error("CI application sessions can be exported only inside GitHub Actions.");
}

const runnerTemp = required("RUNNER_TEMP");
const sourcePath = privateActionsPath(required("FABUSHI_ACCOUNT_SESSION_FILE"), runnerTemp, "FABUSHI_ACCOUNT_SESSION_FILE");
const outputPath = privateActionsPath(required("FABUSHI_CI_ACCOUNT_SESSION_FILE"), runnerTemp, "FABUSHI_CI_ACCOUNT_SESSION_FILE");
if (sourcePath === outputPath) throw new Error("The source and application session paths must differ.");

const deviceId = required("DEVICE_ID");
const runId = required("GITHUB_RUN_ID");
const runAttempt = required("GITHUB_RUN_ATTEMPT");
if (!isProtectedActionsTestDeviceId(deviceId)) {
  throw new Error("DEVICE_ID must be a protected GitHub Actions test device id.");
}
if (!/^[0-9]+$/u.test(runId) || !/^[0-9]+$/u.test(runAttempt)) {
  throw new Error("GitHub run identity is invalid.");
}

const sourceText = await readFile(sourcePath, "utf8");
if (Buffer.byteLength(sourceText) > MAX_SESSION_BYTES) throw new Error("Fabushi account session is too large.");
const source = JSON.parse(sourceText);
const accessToken = String(source?.accessToken || "").trim();
const refreshToken = String(source?.refreshToken || "").trim();
const tokenType = String(source?.tokenType || "Bearer");
const sourceDeviceId = String(source?.deviceId || "").trim();
const username = String(source?.username || source?.user?.username || "").trim();
const userId = String(source?.userId || source?.user?.id || "").trim();
const nestedUserId = String(source?.user?.id || "").trim();
const expiresAt = Number(source?.accessTokenExpiresAt || 0);
const now = Math.floor(Date.now() / 1000);

if (!validCredential(accessToken) || !validCredential(refreshToken)) {
  throw new Error("The ordinary Fabushi account session is incomplete.");
}
if (tokenType !== "Bearer" || sourceDeviceId !== deviceId || !username || !userId || nestedUserId !== userId) {
  throw new Error("The ordinary Fabushi account identity is inconsistent.");
}
if (!Number.isSafeInteger(expiresAt)
    || expiresAt <= now + 30
    || expiresAt > now + MAX_LIFETIME_SECONDS) {
  throw new Error("The Fabushi access token is not valid for a bounded CI session.");
}
if (source?.ciRunner === true || source?.provider === "github-actions") {
  throw new Error("Expected an ordinary refreshable Fabushi account session.");
}

// `ciRunner` and the `ci-runner:` session prefix are retained as wire-compatibility
// markers for existing consumers. They describe a bounded GitHub Actions session;
// they do not grant device-gateway ownership. The launched App registers that gateway.
const exported = {
  accessToken,
  tokenType: "Bearer",
  accessTokenExpiresAt: expiresAt,
  sessionId: `ci-runner:${runId}:${runAttempt}`,
  deviceId,
  username,
  userId,
  user: source.user,
  provider: "github-actions",
  ciRunner: true,
};

await mkdir(dirname(outputPath), { recursive: true, mode: 0o700 });
const temporary = `${outputPath}.${process.pid}.tmp`;
await writeFile(temporary, `${JSON.stringify(exported, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
await rename(temporary, outputPath);
process.stdout.write("Exported a bounded refresh-token-free Fabushi application session.\n");
