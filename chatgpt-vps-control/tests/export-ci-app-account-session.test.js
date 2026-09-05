import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdtemp, readFile, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import test from "node:test";

const execFileAsync = promisify(execFile);
const script = new URL("../scripts/export-ci-app-account-session.mjs", import.meta.url);

test("exports a bounded refresh-token-free application session for an App-owned macOS Actions device", async () => {
  const directory = await mkdtemp(join(tmpdir(), "fabushi-ci-app-session-"));
  const sourcePath = join(directory, "ordinary.json");
  const outputPath = join(directory, "application.json");
  const expiresAt = Math.floor(Date.now() / 1000) + 60 * 60;
  await writeFile(sourcePath, JSON.stringify({
    accessToken: "a".repeat(64),
    refreshToken: "r".repeat(64),
    tokenType: "Bearer",
    accessTokenExpiresAt: expiresAt,
    refreshTokenExpiresAt: expiresAt + 60 * 60,
    sessionId: "ordinary-session",
    deviceId: "gha-12345-1-macos-app",
    username: "test-user",
    userId: "42",
    user: { id: "42", username: "test-user" },
    provider: "official",
    ciRunner: false,
  }));

  await execFileAsync(process.execPath, [script.pathname], {
    env: {
      ...process.env,
      GITHUB_ACTIONS: "true",
      RUNNER_TEMP: directory,
      GITHUB_RUN_ID: "12345",
      GITHUB_RUN_ATTEMPT: "1",
      DEVICE_ID: "gha-12345-1-macos-app",
      FABUSHI_ACCOUNT_SESSION_FILE: sourcePath,
      FABUSHI_CI_ACCOUNT_SESSION_FILE: outputPath,
    },
  });

  const exported = JSON.parse(await readFile(outputPath, "utf8"));
  assert.equal(exported.provider, "github-actions");
  assert.equal(exported.ciRunner, true);
  assert.equal(exported.sessionId, "ci-runner:12345:1");
  assert.equal(exported.deviceId, "gha-12345-1-macos-app");
  assert.equal(exported.accessTokenExpiresAt, expiresAt);
  assert.equal(exported.refreshToken, undefined);
  assert.equal((await stat(outputPath)).mode & 0o077, 0);
});

test("rejects export outside GitHub Actions", async () => {
  const directory = await mkdtemp(join(tmpdir(), "fabushi-ci-app-session-reject-"));
  await assert.rejects(
    execFileAsync(process.execPath, [script.pathname], {
      env: { ...process.env, GITHUB_ACTIONS: "false", RUNNER_TEMP: directory },
    }),
    /CI application sessions can be exported only inside GitHub Actions/u,
  );
});
