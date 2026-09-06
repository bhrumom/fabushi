import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createServer } from "node:http";
import { mkdtemp, readFile, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import test from "node:test";

const execFileAsync = promisify(execFile);
const script = new URL("../scripts/renew-ci-app-account-session.mjs", import.meta.url);

async function listen(server) {
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  return server.address().port;
}

async function close(server) {
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
}

test("renews the private source session and atomically reprojects a refresh-token-free App-owned session", async () => {
  const directory = await mkdtemp(join(tmpdir(), "fabushi-ci-renew-session-"));
  const sourcePath = join(directory, "ordinary.json");
  const outputPath = join(directory, "application.json");
  const now = Math.floor(Date.now() / 1000);
  const oldAccessToken = "a".repeat(64);
  const oldRefreshToken = "r".repeat(64);
  const newAccessToken = "b".repeat(64);
  const newRefreshToken = "s".repeat(64);
  await writeFile(sourcePath, JSON.stringify({
    accessToken: oldAccessToken,
    refreshToken: oldRefreshToken,
    tokenType: "Bearer",
    accessTokenExpiresAt: now + 120,
    refreshTokenExpiresAt: now + 3600,
    sessionId: "ordinary-session",
    deviceId: "gha-12345-1-macos-app",
    username: "test-user",
    userId: "42",
    user: { id: "42", username: "test-user" },
    provider: "official",
    ciRunner: false,
  }));

  let refreshBody = null;
  const server = createServer(async (request, response) => {
    if (request.method !== "POST" || request.url !== "/api/auth/refresh") {
      response.writeHead(404).end();
      return;
    }
    const chunks = [];
    for await (const chunk of request) chunks.push(chunk);
    refreshBody = JSON.parse(Buffer.concat(chunks).toString("utf8"));
    response.writeHead(200, { "Content-Type": "application/json" });
    response.end(JSON.stringify({
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
      tokenType: "Bearer",
      accessTokenExpiresAt: now + 900,
      refreshTokenExpiresAt: now + 7200,
      sessionId: "ordinary-session",
      deviceId: "gha-12345-1-macos-app",
      username: "test-user",
      userId: "42",
      user: { id: "42", username: "test-user" },
      provider: "official",
      ciRunner: false,
    }));
  });
  const port = await listen(server);
  try {
    const { stdout } = await execFileAsync(process.execPath, [script.pathname], {
      env: {
        ...process.env,
        GITHUB_ACTIONS: "true",
        RUNNER_TEMP: directory,
        GITHUB_RUN_ID: "12345",
        GITHUB_RUN_ATTEMPT: "1",
        DEVICE_ID: "gha-12345-1-macos-app",
        FABUSHI_API_BASE_URL: `http://127.0.0.1:${port}`,
        FABUSHI_ACCOUNT_SESSION_FILE: sourcePath,
        FABUSHI_CI_ACCOUNT_SESSION_FILE: outputPath,
      },
    });
    assert.match(stdout, /Renewed bounded refresh-token-free Fabushi application session/u);
  } finally {
    await close(server);
  }

  assert.deepEqual(refreshBody, { refreshToken: oldRefreshToken, deviceId: "gha-12345-1-macos-app" });
  const source = JSON.parse(await readFile(sourcePath, "utf8"));
  assert.equal(source.accessToken, newAccessToken);
  assert.equal(source.refreshToken, newRefreshToken);
  const exported = JSON.parse(await readFile(outputPath, "utf8"));
  assert.equal(exported.accessToken, newAccessToken);
  assert.equal(exported.accessTokenExpiresAt, now + 900);
  assert.equal(exported.provider, "github-actions");
  assert.equal(exported.ciRunner, true);
  assert.equal(exported.sessionId, "ci-runner:12345:1");
  assert.equal(exported.deviceId, "gha-12345-1-macos-app");
  assert.equal(exported.refreshToken, undefined);
  assert.equal((await stat(outputPath)).mode & 0o077, 0);
});
