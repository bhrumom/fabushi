#!/usr/bin/env node
import { createHash } from "node:crypto";
import { resolve, sep } from "node:path";
import { createFabushiAccountSessionStore } from "../lib/fabushi-account-session.js";

const username = String(process.env.FABUSHI_CI_TEST_USERNAME || "").trim();
const password = String(process.env.FABUSHI_CI_TEST_PASSWORD || "");
const deviceId = String(process.env.DEVICE_ID || "").trim();

function isProtectedActionsTestDeviceId(value) {
  return /^gha-[0-9]+-[0-9]+-(?:interactive|ios-app|macos-app|windows-app)$/u.test(value);
}

function privateActionsSessionPath(value, runnerTemp) {
  const rawPath = String(value || "").trim();
  const rawRoot = String(runnerTemp || "").trim();
  if (!rawPath || !rawRoot) {
    throw new Error("Fabushi account session must live under RUNNER_TEMP.");
  }
  const path = resolve(rawPath);
  const root = resolve(rawRoot);
  if (!path.startsWith(`${root}${sep}`)) {
    throw new Error("Fabushi account session must live under RUNNER_TEMP.");
  }
  return path;
}

if (!username || !password) {
  throw new Error("FABUSHI_CI_TEST_USERNAME and FABUSHI_CI_TEST_PASSWORD are required.");
}
if (!isProtectedActionsTestDeviceId(deviceId)) {
  throw new Error("DEVICE_ID must be a protected GitHub Actions test device id.");
}
const sessionPath = privateActionsSessionPath(process.env.FABUSHI_ACCOUNT_SESSION_FILE, process.env.RUNNER_TEMP);

const store = createFabushiAccountSessionStore({
  sessionPath,
  baseUrl: process.env.FABUSHI_API_BASE_URL,
});
const session = await store.login({ username, password, deviceId });
if (!session.userId || String(session.user?.id || "") !== String(session.userId)) {
  throw new Error("Fabushi account login returned an inconsistent user identity.");
}
if (session.deviceId !== deviceId || !session.refreshToken) {
  throw new Error("Fabushi account login did not return a normal refreshable device session.");
}
const accountRef = createHash("sha256").update(String(session.userId)).digest("hex").slice(0, 16);
process.stdout.write(`Fabushi protected CI test account authenticated as account reference ${accountRef}.\n`);
