#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import { resolve, sep } from "node:path";
import { createFabushiAccountSessionStore } from "../lib/fabushi-account-session.js";

function privateActionsPath(value, runnerTemp, name) {
  const path = resolve(String(value || "").trim());
  const root = resolve(String(runnerTemp || "").trim());
  if (!path.startsWith(`${root}${sep}`)) {
    throw new Error(`${name} must live under RUNNER_TEMP.`);
  }
  return path;
}

if (process.env.GITHUB_ACTIONS !== "true") {
  throw new Error("CI application sessions can be renewed only inside GitHub Actions.");
}
const runnerTemp = String(process.env.RUNNER_TEMP || "").trim();
if (!runnerTemp) throw new Error("RUNNER_TEMP is required.");
const sessionPath = privateActionsPath(process.env.FABUSHI_ACCOUNT_SESSION_FILE, runnerTemp, "FABUSHI_ACCOUNT_SESSION_FILE");
const appSessionPath = privateActionsPath(process.env.FABUSHI_CI_ACCOUNT_SESSION_FILE, runnerTemp, "FABUSHI_CI_ACCOUNT_SESSION_FILE");
if (sessionPath === appSessionPath) {
  throw new Error("The private source and bounded application session paths must differ.");
}

const store = createFabushiAccountSessionStore({
  sessionPath,
  baseUrl: process.env.FABUSHI_API_BASE_URL,
});
const current = await store.read();
if (current.ciRunner || !current.refreshToken) {
  throw new Error("Expected a private ordinary refreshable Fabushi account session.");
}
const refreshed = await store.refresh(current);
await import("./export-ci-app-account-session.mjs");

const exported = JSON.parse(await readFile(appSessionPath, "utf8"));
if (exported.refreshToken !== undefined
    || exported.ciRunner !== true
    || exported.provider !== "github-actions"
    || String(exported.deviceId || "") !== String(refreshed.deviceId || "")
    || String(exported.accessToken || "") !== String(refreshed.accessToken || "")) {
  throw new Error("Renewed CI application session failed its bounded projection contract.");
}
const expiresAt = Number(exported.accessTokenExpiresAt || 0);
if (!Number.isSafeInteger(expiresAt) || expiresAt <= Math.floor(Date.now() / 1000) + 30) {
  throw new Error("Renewed CI application session has no usable bounded lifetime.");
}
process.stdout.write(`Renewed bounded refresh-token-free Fabushi application session until ${new Date(expiresAt * 1000).toISOString()}.\n`);
